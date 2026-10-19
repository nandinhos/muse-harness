---
description: Executa o ciclo CLEARER (perfil muse-ceh) sobre o escopo informado
argument-hint: <objetivo + arquivos/area>
---

Execute o ciclo CLEARER (skill `muse-ceh`) sobre `$ARGUMENTS`. O `safety-gate` ativo é o do plugin `clearer-muse` (motor CEH v2.1.2, bloqueio mecânico): se uma ferramenta for bloqueada, reporte o motivo da linha `CEH-SAFETY` e não tente contornar o gate.

1. Identifique o ambiente (`DEV`/`HOMOLOGACAO`/`PRODUCAO`) com evidência e declare o Risk Dial (`LOW`/`MEDIUM`/`HIGH`).
2. `MEDIUM`: rode `INSPECT → PLAN → IMPLEMENT → TEST → REVIEW → AUDIT → REPORT` em turno único, com validação humana antes de finalizar; `HIGH`: decomponha em papéis via subagentes nativos e peça checkpoint antes de mutar.
3. Testes reais da área tocada (`tests/*.php` da área ou `npx playwright test` para e2e; `php -l` como sanidade); saídas verbosas por `profiles/clearer-muse/scripts/compress-output.sh`. Sem migrations: schema não é versionado.
4. Entregue o Response Contract (Resultado, Ambiente, Alterações, Evidências, Testes, Validação, Pendências, Confiança) com classes `OBSERVED`/`INFERRED`/`UNKNOWN`, em PT-BR.
