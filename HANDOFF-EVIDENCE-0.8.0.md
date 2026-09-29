# HANDOFF — Veredito calculado + paridade de host (`clearer-muse` v0.8.0)

> Para o agente que assumir em `/home/nandodev/projects/muse-harness` após restart.
> Origem do porte (só-leitura, NÃO mexer): `/home/nandodev/projects/clearer-engineering-harness/`
> (`staging` == `origin/staging` @ `525da48`; CEH v1.3.0, ref `1b26e10`).

## 1. O que foi feito (branch `dev`, NÃO commitado — 9 edições + 3 criações)

Mitigação P0–P3 p/ paridade de comportamento/filosofia com o harness Antigravity.
Manifest `0.7.0` → `0.8.0`.

| Entrega | Arquivos |
|---|---|
| P0: evidence-report canônico (Invariante 6) | `scripts/evidence_report.py` (novo; delta 1/1: gate em `../hooks/`) + `scripts/evidence-report.sh` (wrapper byte-idêntico ao upstream) |
| P0: D3 + cert de evals | `scripts/test-runner.sh` (captura + `cp last-ci-run.log`), `evals/run.sh` (emite `last-evals-run.json`, schema upstream), `.gitignore` (+2 linhas) |
| P0: regra cognitiva | `skills/clearer-rules/SKILL.md` (§7 Veredito calculado — **só carrega após restart**) |
| P0/P3: suítes novas | `tests/test_evidence_contract.sh` (17 asserts), `tests/test_host_parity.sh` (6 asserts), `tests/run-all-tests.sh` (→ 6/6) |
| P1: vendor auditável | `hooks/vendor/ceh/VENDOR.md` (método + sha `d89128dc…`), `tests/test_ceh_core_contract.sh` (+C13) |
| P2: issue fork-bomb | draft em `/tmp/ceh-forkbomb-issue.md` (NÃO abrir sem o humano; some se a máquina reiniciar — recriar pelo §4 se perdido) |

## 2. Decisões que precisam de ciência (não reverter sem ler)

1. **D1 markers**: Muse `rc=1+BLOCKER` vs upstream `rc=0+WARNING`. Divergência deliberada — Muse é mais fail-closed; o `diff-audit` é gate de review aqui. Pinado em H3/H6.
2. **D2/D3**: fora-de-repo `rc=2` (vs 1) e conteúdo do `ceh-help` (scripts do profile vs aliases `agy-*`) — adaptações de host previstas no handoff-060 Passo 2.
3. **`__pycache__/` no `.gitignore`**: espelha o upstream; o `evidence-report` compila o adapter ao rodar e sujava a tree.
4. **Evals sem `--base`**: `last-evals-run.json` não tem guarda de worktree suja — fiel ao upstream (o cert descreve o HEAD, não a sujeira).

## 3. Sequência de validação pós-restart (rodar nesta ordem)

```bash
# 0. Sessão nova: confirmar skill §7 carregada (responda: deve citar Invariante 6)
#    Pergunte ao agente: "qual a §7 do clearer-rules?"
# 1. Higiene (tudo exit 0)
git status --short  # esperado: 9 M + 4 ?? (3 do profile + este HANDOFF), nenhum __pycache__
git diff --check
bash profiles/clearer-muse/scripts/canonical-diff.sh  # esperado: IDÊNTICO
# 2. Suíte integral (exit 0, ~10s)
bash profiles/clearer-muse/tests/run-all-tests.sh  # esperado: STATUS: PASS (6/6 suítes), 77 asserts, 0 FAIL
# 3. Dogfood do veredito calculado (antes do commit: worktree suja => honesto)
bash profiles/clearer-muse/scripts/evidence-report.sh  # esperado: **NAO_VERIFICADO**, suíte PASS, evals 16/16 APROVA
# 4. Commit + push (convenção pt-BR, sem Co-Authored-By)
git add -A && git commit -m "feat (clearer-muse): porta evidence-report com veredito calculado e paridade de host (v0.8.0)" && git push origin dev
# 5. Pós-commit: certificar a tree limpa e fechar o ciclo
bash profiles/clearer-muse/scripts/test-runner.sh "bash evals/run.sh"  # emite Certificado de Voo no HEAD
bash profiles/clearer-muse/scripts/evidence-report.sh --strict  # esperado: exit 0 (sem claims => VERIFICADO/MEDIA)
```

## 4. Backlog (fora deste escopo)

- Abrir a issue P2 no upstream (conteúdo: repro `--check ':(){ :|:& };:'` → `allow` exit 0; causa provável `lexer.py::split_shell_pipeline` fragmenta antes de casar `CATASTROPHIC_PATTERNS`; CC1 será removido após o fix).
- Re-vendar `ceh_core` + remover CC1 quando o upstream corrigir.
- Auditoria cláusula a cláusula dos 7 `rules/*.md` upstream vs `clearer-rules/SKILL.md` (§7 cobre o invariante crítico; resto é refinamento).
- `rc_aliases.py` não portado por desenho (aliases `agy-*` são específicos do Antigravity).
