# HANDOFF — Handoff-061 aplicado, aguardando retest pós-restart (`clearer-muse` v0.8.1)

> Para o agente que assumir em `/home/nandodev/projects/muse-harness` após restart.
> Origem do porte (só-leitura, NÃO mexer): `/home/nandodev/projects/clearer-engineering-harness/`
> (`main` @ `6fc5a07`; CEH v1.3.1, fix `2654e64`).

## 1. O que foi feito (branch `dev`, NÃO commitado — 9 edições + 2 criações)

Handoff 061 do upstream aplicado integralmente: re-vendoring CEH v1.3.1 + remoção CC1.
Manifest `0.8.0` → `0.8.1`.

| Entrega | Arquivos |
|---|---|
| Re-vendor motor 6fc5a07 | `hooks/vendor/ceh/safety-gate.py` (único com diff; `ceh_core/`+`hook_context.py` idênticos), `hooks/vendor/ceh/VENDOR.md` (ref+sha `6db34ff9…`, CC1→REMOVIDO) |
| CC1 removido + `--command` no host | `hooks/safety-gate.py` (função, call site, imports `re`/`CATASTROPHIC_PATTERNS`; delegação aceita `--check`/`--command`) |
| Expectativas engine-nativas | `tests/test_safety_contract.sh` (4 tokens→`CATASTROPHIC BLOCK`), `tests/test_ceh_core_contract.sh` (C11→engine-deny), `evals/run.sh` (F3) |
| Cobertura nova (handoff-061) | `tests/test_ceh_core_contract.sh` C14a/C14b (`--command`+`--cwd`, allow/deny) |
| Refs v1.3.1 | `skills/clearer-rules/SKILL.md`, `scripts/evidence_report.py` (só comentários; arquivos upstream inalterados), `.muse-plugin/plugin.json` (0.8.1) |
| Docs (turno anterior + resolução) | `docs/AUDIT-RULES-0.8.0.md` (novo), `docs/CEH-FORKBOMB-ISSUE-P2.md` (novo, marcada RESOLVIDA) |

## 2. Decisões que precisam de ciência (não reverter sem ler)

1. **Tokens `CATASTROPHIC BLOCK`**: as expectativas antigas (`bloqueio catastrofico`) eram texto do CC1;
   as falhas pós-remoção foram observadas (4+1+1, vereditos DENY corretos) antes de atualizar.
2. **Host aceita `--command`**: sem isso o flag cairia como comando literal; delegação repassa
   `--env`/`--cwd` ao motor. Modo hook (stdin/argv) segue exit 0 + linha `CEH-SAFETY` (adaptação Muse).
3. **`os`/`io` não usados no adapter**: pré-existentes, fora do escopo — não remover neste bloco.
4. **Issue P2 nunca aberta**: resolvida via handoff direto; doc preservado como registro.

## 3. Sequência pós-restart (rodar nesta ordem, depois emitir o handoff de resposta)

```bash
# 1. Higiene (tudo exit 0)
git status --short  # esperado: 9 M + 3 ?? (2 docs + este HANDOFF), nenhum __pycache__
git diff --check
# 2. Validação do handoff-061 item 3
python3 profiles/clearer-muse/hooks/safety-gate.py --check ':(){ :|:& };:'; echo "EXIT=$?"      # esperado: 2
python3 profiles/clearer-muse/hooks/safety-gate.py --command ':(){ :|:& };:'; echo "EXIT=$?"    # esperado: 2
# 3. Suíte integral (exit 0, ~10s)
bash profiles/clearer-muse/tests/run-all-tests.sh  # esperado: STATUS: PASS (6/6), ceh-core 15/15
# 4. Emitir o HANDOFF DE RESPOSTA ao upstream (bloco de texto p/ colar no agente Antigravity):
#    re-vendor OK + CC1 removido + evidências OBSERVED dos passos 2–3 + C13 sha + zero resíduos.
# 5. Só então (com OK humano): commit + push (pt-BR, sem Co-Authored-By), ex:
#    git add -A && git commit -m "feat (clearer-muse): re-venda motor CEH v1.3.1 e remove CC1 (v0.8.1)" && git push origin dev
# 6. Pós-commit: test-runner p/ Certificado de Voo + evidence-report --strict (exit 0),
#    e reinstalar o plugin (canonical-diff vai acusar deriva: cache instalado ainda é 0.8.0).
```

## 4. Backlog (fora deste bloco)

- Refinamentos R1/R2/R3 do `docs/AUDIT-RULES-0.8.0.md` (~5 linhas, commit `docs` futuro).
- `rc_aliases.py` não portado por desenho (aliases `agy-*` Antigravity-only).
