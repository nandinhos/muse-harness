---
description: Executa o ciclo CLEARER sobre o escopo informado
argument-hint: <objetivo + arquivos/area>
---

Execute o ciclo CLEARER (skill `clearer`) sobre `$ARGUMENTS`:

1. Identifique o ambiente (`DEV`/`HOMOLOGACAO`/`PRODUCAO`) com evidência e declare o Risk Dial (`LOW`/`MEDIUM`/`HIGH`).
2. `MEDIUM`: rode `INSPECT → PLAN → IMPLEMENT → TEST → REVIEW → AUDIT → REPORT` em turno único; `HIGH`: decomponha em papéis via subagentes nativos e peça checkpoint antes de mutar.
3. Testes reais da área tocada (`bash scripts/test-runner.sh`; ou canônico da stack); saídas verbosas por `scripts/compress-output.sh`.
4. Entregue o Response Contract (Resultado, Ambiente, Alterações, Evidências, Testes, Validação, Pendências, Confiança) com classes `OBSERVED`/`INFERRED`/`UNKNOWN`.
5. Rotas: `clearer-feature` (nova funcionalidade) · `debugging` (bug, 5 gates) · `clearer-refactor` (baseline verde) · `clearer-review` (diff adversarial) · `clearer-test` (contrato COMMAND/EXIT/STATUS) · `clearer-audit` (claims) · `clearer-map` (read-only) · `learned-lesson` (memória) · `clearer-rules` (normativo) · `clearer-adhd` (hiperfoco, opt-in).
