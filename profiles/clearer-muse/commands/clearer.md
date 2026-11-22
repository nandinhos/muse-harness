---
description: Executa o ciclo CLEARER sobre o escopo informado
argument-hint: <objetivo + arquivos/area>
---

Execute o ciclo CLEARER (skill `clearer`) sobre `$ARGUMENTS`:

1. Sem prompt no loader: rode `python3 scripts/ceh-dispatch.py --task "$ARGUMENTS"` — ele resolve ambiente, Risk Dial (`LOW`/`MEDIUM`/`HIGH`) e rota por código (sinais em `routing.json`); o guardrail é o `safety-gate` (`PreToolUse`). Abra só o `arquivo_referencia` devolvido, se precisar.
2. `MEDIUM`: rode `INSPECT → PLAN → IMPLEMENT → TEST → REVIEW → AUDIT → REPORT` em turno único; `HIGH`: decomponha em papéis via subagentes nativos e peça checkpoint antes de mutar.
3. Testes reais da área tocada (`bash scripts/test-runner.sh`; ou canônico da stack); saídas verbosas por `scripts/compress-output.sh`.
4. Entregue o Response Contract (Resultado, Ambiente, Alterações, Evidências, Testes, Validação, Pendências, Confiança) com classes `OBSERVED`/`INFERRED`/`UNKNOWN`.
5. Rotas: `clearer-feature` (nova funcionalidade) · `clearer-bugfix`/`debugging` (bug, 5 gates) · `clearer-refactor` (baseline verde) · `clearer-review` (diff adversarial) · `clearer-test` (contrato COMMAND/EXIT/STATUS) · `clearer-audit` (claims) · `clearer-map` (read-only) · `learned-lesson` (memória) · `clearer-rules` (normativo) · `conselho-seniores` (banca 360º, opt-in) · `clearer-adhd` (hiperfoco, opt-in).
