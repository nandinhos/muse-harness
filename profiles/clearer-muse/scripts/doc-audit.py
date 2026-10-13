#!/usr/bin/env python3
"""
CLEARER Engineering Harness (CEH) — Document Structure Audit Tool

Dois layouts, mesma intenção (checks delimitados e determinísticos, fail-closed):
- Layout CEH (Antigravity): quando existe docs/plano-validacao-*.md, rodam as
  7 checagens originais abaixo, sem alteração de semântica.
- Layout Muse: sem o plano, rodam 5 checagens espelhadas — links locais
  resolvem, zero caminho absoluto vazado nos docs vivos, commits citados
  existem, README sincronizado com os manifestos e orçamento de linhas.
Sem nenhum dos dois layouts: exit 2 (nunca verde silencioso).
Uso: doc-audit.py [raiz-do-repo]  (default: git rev-parse --show-toplevel)

Verifica deterministicamente propriedades estruturais delimitadas da documentação:
1. Conformidade de estados normativos em docs/plano-validacao-revisao-conselho-seniors.md
2. Estados normativos, cabeçalhos da tabela R1 a R10 e contagem publicada da suíte geral
3. Existência física de todos os artefatos de evidência citados em markdown
4. Ausência de caminhos absolutos locais vazados (file:///home/ ou /home/<user>/)
5. Existência dos commits citados no histórico local do Git
6. Ausência de contradições de autorização de commit em handoffs
7. Orçamento de linhas de código do harness

Não avalia coerência semântica integral, validade do conteúdo das evidências ou aprovação formal do conselho.
"""
import sys
import re
import json
import subprocess
from pathlib import Path

def audit_ceh(repo_root):
    """Layout CEH/Antigravity: 7 checagens originais, semântica inalterada."""
    docs_dir = repo_root / "docs"
    plano_file = docs_dir / "plano-validacao-revisao-conselho-seniors.md"
    handoffs_dir = docs_dir / "temp_implementation" / "handoffs"
    evidence_dir = docs_dir / "temp_implementation" / "evidence"

    print(f"Alvo principal: {plano_file.relative_to(repo_root)}")

    errors = []
    checks_passed = 0

    plano_text = plano_file.read_text(encoding="utf-8")

    # ---------------------------------------------------------
    # 1. Estados permitidos normativos
    # ---------------------------------------------------------
    print("[1/7] Verificando taxonomia de estados permitidos...")
    estados_permitidos = set()
    estados_block = re.search(r"## Estados permitidos\s*\n\s*\|.*?\n\|[-|\s]+\n(.*?)(?=\n\n|\n##)", plano_text, re.DOTALL)
    if not estados_block:
        errors.append("Seção '## Estados permitidos' não encontrada ou mal formatada no plano.")
    else:
        for line in estados_block.group(1).strip().splitlines():
            parts = [p.strip() for p in line.split("|") if p.strip()]
            if parts:
                raw_state = parts[0].replace("`", "").strip()
                estados_permitidos.add(raw_state)

    print(f"  • Estados permitidos normativos identificados: {sorted(list(estados_permitidos))}")
    if estados_permitidos:
        checks_passed += 1
    elif estados_block:
        errors.append("A seção de estados permitidos não contém estados reconhecíveis.")

    # ---------------------------------------------------------
    # 2. Tabela de achados (R1 a R10)
    # ---------------------------------------------------------
    print("[2/7] Verificando consistência da tabela de achados (R1 a R10)...")
    tabela_match = re.search(
        r"## Registro vivo do conselho.*?\n(\|[^\n]*\|)\n\|[-| ]+\|\n(.*?)(?=\n\n|\n###)",
        plano_text,
        re.DOTALL,
    )
    if not tabela_match:
        errors.append("Tabela '## Registro vivo do conselho' não encontrada no plano.")
    else:
        expected_columns = [
            "ID", "Estado atual", "Evidência conferida", "Critério/decisão registrado",
            "Severidade/prioridade registrada", "Implementação consolidada", "Commit de implementação",
        ]
        actual_columns = [c.strip() for c in tabela_match.group(1).strip().strip("|").split("|")]
        if actual_columns != expected_columns:
            errors.append(
                "Cabeçalhos do registro R1–R10 divergentes. "
                f"Esperado: {expected_columns}; encontrado: {actual_columns}."
            )

        suite_script = repo_root / "profiles/clearer-muse/scripts/test-runner.sh"
        suite_text = suite_script.read_text(encoding="utf-8")
        declared_runs = len(re.findall(r"^\s*run_test\s+", suite_text, re.MULTILINE))
        # The suite contains two mutually exclusive if/else pairs; only one test
        # from each pair is counted at runtime.
        suite_total = declared_runs - 2
        plan_header = "\n".join(plano_text.splitlines()[:8])
        expected_count_claim = f"{suite_total}/{suite_total} testes aprovados"
        if expected_count_claim not in plan_header:
            errors.append(
                "A contagem atual da suíte geral não está sincronizada no cabeçalho do plano: "
                f"esperado '{expected_count_claim}'."
            )

        achados = {}
        for line in tabela_match.group(2).strip().splitlines():
            cols = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cols) >= 3 and re.match(r"^R\d+$", cols[0]):
                r_id = cols[0]
                estado = cols[1]
                evidencias = cols[2]
                if len(cols) != len(expected_columns):
                    errors.append(f"Achado {r_id} possui {len(cols)} colunas; esperado: {len(expected_columns)}.")
                    continue
                commit_hash = cols[6].strip("`")
                if not re.fullmatch(r"[0-9a-f]{7,40}", commit_hash):
                    errors.append(f"Achado {r_id} não possui hash de commit válido na coluna de implementação.")
                else:
                    is_shallow = subprocess.run(["git", "rev-parse", "--is-shallow-repository"], cwd=repo_root, capture_output=True, text=True).stdout.strip() == "true"
                    if not is_shallow:
                        commit_check = subprocess.run(
                            ["git", "rev-parse", "--verify", f"{commit_hash}^{{commit}}"],
                            cwd=repo_root,
                            capture_output=True,
                        )
                        if commit_check.returncode != 0:
                            errors.append(f"Commit da tabela do achado {r_id} não existe no histórico local: {commit_hash}.")
                achados[r_id] = {"estado": estado, "evidencias": evidencias}

        expected_ids = [f"R{i}" for i in range(1, 11)]
        for r_id in expected_ids:
            if r_id not in achados:
                errors.append(f"Achado {r_id} ausente na tabela de registro vivo.")
                continue

            estado = achados[r_id]["estado"]
            if estado not in estados_permitidos:
                errors.append(f"Achado {r_id} possui estado '{estado}', que NÃO está na lista de estados permitidos: {sorted(list(estados_permitidos))}")

        # Se o cabeçalho alega que todos os 10 estão resolvidos/validados
        is_all_resolved_claimed = "todos os 10 achados" in plano_text.lower() and "resolvidos e validados" in plano_text.lower()
        if is_all_resolved_claimed:
            for r_id in expected_ids:
                if r_id in achados and achados[r_id]["estado"] != "Reproduzido e corrigido":
                    errors.append(f"Inconsistência de Claim: Cabeçalho declara todos resolvidos, mas {r_id} está com estado '{achados[r_id]['estado']}' (esperado: 'Reproduzido e corrigido').")

        if not errors:
            print("  • Todos os 10 achados (R1 a R10) possuem estados normativos válidos e consistentes com o claim global.")
            checks_passed += 1

    # ---------------------------------------------------------
    # 3. Existência física dos arquivos de evidência
    # ---------------------------------------------------------
    print("[3/7] Verificando existência física de arquivos de evidência citados...")
    evid_links = re.findall(r"\[`([^`]+\.json)`\]\((temp_implementation/evidence/[^)]+)\)", plano_text)
    missing_evidence = []
    for label, rel_path in evid_links:
        full_path = docs_dir / rel_path
        if not full_path.exists():
            missing_evidence.append(f"{label} -> {full_path}")

    if missing_evidence:
        for m in missing_evidence:
            errors.append(f"Arquivo de evidência referenciado não existe no disco: {m}")
    else:
        print(f"  • Todos os {len(evid_links)} links de evidências apontam para arquivos físicos existentes.")
        checks_passed += 1

    # ---------------------------------------------------------
    # 4. Portabilidade de links (zero file:/// ou /home/<user>/)
    # ---------------------------------------------------------
    print("[4/7] Verificando portabilidade de links na documentação...")
    abs_links_found = []
    for md_file in docs_dir.rglob("*.md"):
        content = md_file.read_text(encoding="utf-8")
        matches = re.findall(r"(file:///home/[^\s\)\"'>]+|/(?:home|Users)/[\w.-]+/[^\s\)\"'>]*)", content)
        if matches:
            abs_links_found.append((md_file.relative_to(repo_root), matches))

    if abs_links_found:
        for f, m in abs_links_found:
            errors.append(f"Caminho absoluto local detectado em {f}: {m}")
    else:
        print("  • Zero caminhos absolutos locais detectados em toda a pasta docs/.")
        checks_passed += 1

    # ---------------------------------------------------------
    # 5. Existência dos commits citados no histórico do Git
    # ---------------------------------------------------------
    print("[5/7] Verificando existência de commits citados no Git local...")
    commits_to_check = set(re.findall(r"\b([0-9a-f]{7,40})\b", plano_text))
    # Filtra apenas hashes citados em contexto de commit
    commit_refs = re.findall(r"(?:commit|HEAD)\s+[`']?([0-9a-f]{7,40})[`']?", plano_text)
    is_shallow = subprocess.run(["git", "rev-parse", "--is-shallow-repository"], cwd=repo_root, capture_output=True, text=True).stdout.strip() == "true"
    if is_shallow:
        print("  • Repositório raso detectado (shallow clone de CI); validação de commits ancestrais ignorada com segurança.")
        checks_passed += 1
    else:
        missing_commits = []
        for c in commit_refs:
            res = subprocess.run(["git", "rev-parse", "--verify", f"{c}^{{commit}}"], cwd=repo_root, capture_output=True)
            if res.returncode != 0:
                missing_commits.append(c)

        if missing_commits:
            for c in set(missing_commits):
                errors.append(f"Commit citado na documentação não existe no histórico local: {c}")
        else:
            print(f"  • Todos os commits citados ({', '.join(set(commit_refs))}) foram confirmados no Git local.")
            checks_passed += 1

    # ---------------------------------------------------------
    # 6. Consistência de Handoffs e autorização de commit
    # ---------------------------------------------------------
    print("[6/7] Verificando consistência em handoffs...")
    handoff_contradictions = []
    for hf in handoffs_dir.glob("*.md"):
        hf_text = hf.read_text(encoding="utf-8")
        # Se um handoff diz "sem commit para Cluster 2", mas temos commit do Cluster 2 no histórico
        if re.search(r"sem commit.*?Cluster 2", hf_text, re.IGNORECASE):
            if "## 12. Consolidação e Commits Autorizados" not in hf_text and "Atualização de escopo" not in hf_text:
                handoff_contradictions.append(f"{hf.name}: contém restrição 'sem commit para Cluster 2' desatualizada.")

    if handoff_contradictions:
        for hc in handoff_contradictions:
            errors.append(hc)
    else:
        print("  • Handoffs devidamente sincronizados com as autorizações e commits consolidados.")
        checks_passed += 1

    # ---------------------------------------------------------
    # 7. Orçamento de linhas de código
    # ---------------------------------------------------------
    print("[7/7] Verificando orçamento de linhas dos componentes core...")
    gate_py = repo_root / "profiles/clearer-muse/hooks/safety-gate.py"
    runner_sh = repo_root / "profiles/clearer-muse/scripts/test-runner.sh"

    gate_lines = len(gate_py.read_text(encoding="utf-8").splitlines())
    runner_lines = len(runner_sh.read_text(encoding="utf-8").splitlines())

    print(f"  • safety-gate.py: {gate_lines} linhas (Teto: 650)")
    print(f"  • test-runner.sh: {runner_lines} linhas (Teto: 200)")

    if gate_lines > 650:
        errors.append(f"safety-gate.py excedeu o orçamento: {gate_lines} > 650 linhas")
    if runner_lines > 200:
        errors.append(f"test-runner.sh excedeu o orçamento: {runner_lines} > 200 linhas")

    if not (gate_lines > 650 or runner_lines > 200):
        checks_passed += 1

    print("-" * 50)
    if errors:
        print(f"FALHA: {len(errors)} inconsistência(s) encontrada(s):")
        for idx, err in enumerate(errors, 1):
            print(f"  [{idx}] {err}")
        print("Auditoria documental REJEITADA.")
        return 1
    else:
        print(f"SUCESSO: {checks_passed}/7 checagens estruturais documentais passaram.")
        print("Auditoria estrutural documental APROVADA; coerência semântica integral não avaliada.")
        return 0

HOME_RX = r"(file:///home/[^\s\)\"'>]+|/(?:home|Users)/[\w.-]+/[^\s\)\"'>]*)"
LINK_RX = re.compile(r"\]\((?!https?://|#|mailto:)([^)\s]+)\)|src=\"(?!https?://)([^\"]+)\"")


def _read(path):
    return path.read_text(encoding="utf-8", errors="replace")


def audit_muse(repo_root):
    """Layout Muse: 5 checagens delimitadas espelhando a intenção CEH.

    Docs vivos (erro): README.md, HANDOFF.md, docs/CREATE-PROFILE.md,
    docs/EVALS.md, adr/*.md, evals/*.md. Registros datados (demais .md em
    docs/ e na raiz) têm só os links verificados — caminho absoluto em
    prosa histórica é proveniência, reportado como INFO, nunca reescrito.
    """
    live = [p for p in (repo_root / "README.md", repo_root / "HANDOFF.md",
                        repo_root / "docs/CREATE-PROFILE.md", repo_root / "docs/EVALS.md")
            if p.exists()]
    for sub in ("adr", "evals"):
        live += sorted((repo_root / sub).rglob("*.md")) if (repo_root / sub).exists() else []
    records = [p for p in sorted(repo_root.rglob("*.md"))
               if p not in live and ".git" not in p.parts and "vendor" not in p.parts
               and p.parent in (repo_root, repo_root / "docs")]
    errors, infos, passed = [], [], 0

    print("[1/5] Links locais resolvem (docs vivos + registros)...")
    broken = []
    for md in live + records:
        for m in LINK_RX.finditer(_read(md)):
            target = (m.group(1) or m.group(2)).split("#")[0].split(":")[0]
            if target and not (md.parent / target).exists() and not (repo_root / target).exists():
                broken.append(f"{md.relative_to(repo_root)} -> {target}")
    if broken:
        errors += [f"Link local quebrado: {b}" for b in broken]
    else:
        print(f"  • Links locais íntegros em {len(live) + len(records)} arquivos.")
        passed += 1

    print("[2/5] Zero caminho absoluto local nos docs vivos...")
    for md in live:
        found = re.findall(HOME_RX, _read(md))
        if found:
            errors.append(f"Caminho absoluto vazado em {md.relative_to(repo_root)}: {found[:2]}")
    for md in records:
        if re.search(HOME_RX, _read(md)):
            infos.append(f"registro histórico com caminho absoluto (proveniência): {md.relative_to(repo_root)}")
    if not any(e.startswith("Caminho absoluto") for e in errors):
        print("  • Docs vivos portáveis.")
        passed += 1

    print("[3/5] Commits citados existem no Git local...")
    shallow = subprocess.run(["git", "rev-parse", "--is-shallow-repository"],
                             cwd=repo_root, capture_output=True, text=True).stdout.strip() == "true"
    if shallow:
        print("  • Clone raso (CI); commits ancestrais ignorados com segurança.")
        passed += 1
    else:
        refs = set()
        for md in live:
            refs.update(re.findall(r"(?:commit|HEAD)\s+[`']?([0-9a-f]{7,40})[`']?", _read(md)))
        missing = [c for c in refs if subprocess.run(
            ["git", "rev-parse", "--verify", f"{c}^{{commit}}"],
            cwd=repo_root, capture_output=True).returncode != 0]
        if missing:
            errors += [f"Commit citado inexistente no histórico local: {c}" for c in missing]
        else:
            print(f"  • {len(refs)} commit(s) citado(s) confirmado(s).")
            passed += 1

    print("[4/5] README sincronizado com os manifestos de profile...")
    readme = _read(repo_root / "README.md") if (repo_root / "README.md").exists() else ""
    drift = []
    for manifest in sorted(repo_root.glob("profiles/*/.muse-plugin/plugin.json")):
        data = json.loads(_read(manifest))
        profile = manifest.parents[1]
        if f"v{data['version']}" not in readme:
            drift.append(f"{data['name']}: versão v{data['version']} não citada no README")
        for skill in data.get("capabilities", {}).get("skills", []):
            if skill["id"] not in readme:
                drift.append(f"{data['name']}: skill '{skill['id']}' não citada no README")
        scripts_dir = profile / "scripts"
        if scripts_dir.exists():
            for script in sorted(scripts_dir.iterdir()):
                if script.is_file() and script.name not in readme:
                    drift.append(f"{data['name']}: script '{script.name}' não citado no README")
    if drift:
        errors += drift
    else:
        print("  • Versões, skills e scripts dos manifestos citados no README.")
        passed += 1

    print("[5/5] Orçamento de linhas dos componentes core...")
    over = []
    for rel, cap in (("profiles/clearer-muse/hooks/safety-gate.py", 650),
                     ("profiles/clearer-muse/scripts/test-runner.sh", 200)):
        f = repo_root / rel
        if f.exists():
            n = len(_read(f).splitlines())
            print(f"  • {Path(rel).name}: {n} linhas (teto {cap})")
            if n > cap:
                over.append(f"{rel} excedeu o orçamento: {n} > {cap}")
    errors += over
    if not over:
        passed += 1

    for info in infos:
        print(f"INFO: {info}")
    print("-" * 50)
    if errors:
        print(f"FALHA: {len(errors)} inconsistência(s) encontrada(s):")
        for idx, err in enumerate(errors, 1):
            print(f"  [{idx}] {err}")
        print("Auditoria documental REJEITADA.")
        return 1
    print(f"SUCESSO: {passed}/5 checagens estruturais documentais passaram.")
    print("Auditoria estrutural documental APROVADA; coerência semântica integral não avaliada.")
    return 0


def _repo_root(argv):
    if len(argv) > 1:
        return Path(argv[1]).resolve()
    top = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                         capture_output=True, text=True)
    if top.returncode == 0 and top.stdout.strip():
        return Path(top.stdout.strip())
    return Path(__file__).resolve().parents[3]


def main():
    repo_root = _repo_root(sys.argv)
    plano = repo_root / "docs/plano-validacao-revisao-conselho-seniors.md"
    print("=== [CEH Bounded Document Structure Audit] ===")
    print(f"Repositório: {repo_root}")
    if plano.exists():
        print("Layout detectado: CEH (Antigravity)")
        print("-" * 50)
        return audit_ceh(repo_root)
    if (repo_root / "README.md").exists():
        print("Layout detectado: Muse")
        print("-" * 50)
        return audit_muse(repo_root)
    print("ERRO: nenhum layout reconhecido (sem plano CEH e sem README.md).")
    print("Auditoria documental REJEITADA (fail-closed).")
    return 2


if __name__ == "__main__":
    sys.exit(main())
