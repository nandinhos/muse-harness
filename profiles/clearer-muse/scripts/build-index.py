#!/usr/bin/env python3
"""build-index.py — Gera o indice tagueado sob demanda do profile clearer-muse.

Fonte unica: o filesystem do profile (`skills/*/SKILL.md`, `commands/*.md`,
`hooks/safety-gate.py`, `scripts/*`). O loader (`plugin.json`) registra ZERO
skills/comandos — so o hook de codigo — portanto o indice nao le o manifest:
ele localiza por tag o arquivo de referencia para leitura explicita de 1 item.

Uso:
  python3 scripts/build-index.py            # regenera index.json + INDEX.md
  python3 scripts/build-index.py --check    # exit 1 se o indice estiver stale

Exits: 0 ok; 1 stale (--check); 2 fonte ausente/ilegivel.
"""
import json
import sys
from pathlib import Path

PROFILE = Path(__file__).resolve().parent.parent
OUT_JSON = PROFILE / "index.json"
OUT_MD = PROFILE / "INDEX.md"

# Tags por objetivo (roteamento sob demanda). Chave: id da skill/comando/hook
# ou nome do script sem extensao. Item sem entrada recebe a tag do seu tipo.
TAGS = {
    "clearer": ["dispatcher", "ciclo", "risk-dial", "entrada"],
    "clearer-feature": ["feature", "funcionalidade", "implementacao"],
    "clearer-bugfix": ["bug", "erro", "regressao", "debug"],
    "debugging": ["bug", "erro", "regressao", "debug"],
    "clearer-refactor": ["refactor", "refatoracao", "sem-mudar-comportamento"],
    "clearer-review": ["review", "revisao", "diff", "adversarial"],
    "clearer-test": ["teste", "test", "execucao-auditavel"],
    "clearer-audit": ["auditoria", "claims", "evidencia"],
    "clearer-map": ["mapa", "codebase", "read-only", "exploracao"],
    "clearer-rules": ["regras", "normativo", "ambiente", "ci"],
    "clearer-orchestration": ["orquestracao", "tiers", "roteamento", "subagentes"],
    "clearer-adhd": ["hiperfoco", "resposta-direta", "opt-in"],
    "code-minimalism": ["minimalismo", "diff-minimo", "opt-in"],
    "conselho-seniores": ["banca", "multi-modelo", "decisao", "opt-in"],
    "learned-lesson": ["licao", "memoria", "aprendizado"],
    "token-economy": ["tokens", "economia", "contexto", "custo"],
    "clearer-run": ["comando", "ciclo", "entrada"],
    "token-report": ["comando", "tokens", "custo", "relatorio"],
    "safety-gate": ["guardrail", "seguranca", "ambiente", "pre-tool-use"],
    "detect-project": ["ferramenta", "stack", "ambiente", "sob-demanda"],
    "preflight": ["ferramenta", "inspecao", "sob-demanda", "legado"],
    "session_cost": ["ferramenta", "tokens", "custo", "sessao"],
    "context-guard": ["ferramenta", "tokens", "contexto", "guarda"],
    "diff-audit": ["ferramenta", "diff", "review"],
    "test-runner": ["ferramenta", "teste", "canonico"],
    "route_classify": ["ferramenta", "orquestracao", "tiers", "shadow"],
    "ceh-dispatch": ["ferramenta", "dispatch", "risk-dial", "ambiente", "infra"],
}


def _frontmatter_desc(path: Path) -> str:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""
    for line in text.splitlines()[:12]:
        if line.startswith("description:"):
            return line.split(":", 1)[1].strip()
    return ""


def build() -> dict:
    itens = []

    def add(iid, tipo, rel, descricao=""):
        alvo = PROFILE / rel
        itens.append({
            "id": iid, "tipo": tipo, "caminho": rel,
            "tags": TAGS.get(iid, [tipo]),
            "acionamento": "sob-demanda-arquivo",
            "residente": False,
            "bytes": alvo.stat().st_size if alvo.is_file() else 0,
            "descricao": descricao,
        })

    skills_dir = PROFILE / "skills"
    if skills_dir.is_dir():
        for f in sorted(skills_dir.glob("*/SKILL.md")):
            add(f.parent.name, "skill", f"skills/{f.parent.name}/SKILL.md",
                _frontmatter_desc(f))
    commands_dir = PROFILE / "commands"
    if commands_dir.is_dir():
        for f in sorted(commands_dir.glob("*.md")):
            add(f.stem, "comando", f"commands/{f.name}", _frontmatter_desc(f))
    if (PROFILE / "hooks" / "safety-gate.py").is_file():
        add("safety-gate", "hook", "hooks/safety-gate.py",
            "Guardrail PreToolUse por ambiente (unico item do loader).")
    scripts = PROFILE / "scripts"
    if scripts.is_dir():
        for f in sorted(scripts.iterdir()):
            if f.is_file() and f.suffix in (".sh", ".py") and f.name != Path(__file__).name:
                iid = f.stem
                itens.append({
                    "id": iid,
                    "tipo": "ferramenta",
                    "caminho": f"scripts/{f.name}",
                    "tags": TAGS.get(iid, ["ferramenta", "sob-demanda"]),
                    "acionamento": "sob-demanda",
                    "residente": False,
                    "bytes": f.stat().st_size,
                    "descricao": "",
                })
    itens.sort(key=lambda i: (i["tipo"], i["id"]))
    return {
        "versao": 1,
        "gerado_por": "scripts/build-index.py (nao editar a mao; rode o gerador)",
        "regra": "loader com zero prompt (so hook); residente=false para tudo; ler 1 arquivo por vez via tags",
        "itens": itens,
    }


def render_md(idx: dict) -> str:
    linhas = [
        "# Indice tagueado — clearer-muse (sob demanda)",
        "",
        "Gerado por `scripts/build-index.py`. Nao editar a mao.",
        "Regra: nada residente; localizar por tag e carregar so o item escolhido.",
        "",
        "| id | tipo | tags | residente | caminho |",
        "|---|---|---|---|---|",
    ]
    for i in idx["itens"]:
        linhas.append(
            f"| `{i['id']}` | {i['tipo']} | {', '.join(i['tags'])} | "
            f"{'sim' if i['residente'] else 'nao'} | `{i['caminho']}` |"
        )
    linhas.append("")
    return "\n".join(linhas)


def main() -> int:
    idx = build()
    js = json.dumps(idx, indent=2, ensure_ascii=False) + "\n"
    md = render_md(idx)
    if "--check" in sys.argv:
        ok = (
            OUT_JSON.is_file() and OUT_JSON.read_text(encoding="utf-8") == js
            and OUT_MD.is_file() and OUT_MD.read_text(encoding="utf-8") == md
        )
        print("INDEX: OK" if ok else "INDEX: STALE (rode scripts/build-index.py)")
        return 0 if ok else 1
    OUT_JSON.write_text(js, encoding="utf-8")
    OUT_MD.write_text(md, encoding="utf-8")
    residentes = [i["id"] for i in idx["itens"] if i["residente"]]
    print(f"INDEX: {len(idx['itens'])} itens, residentes={residentes or 'nenhum'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
