---
name: clearer-feature
description: Implementação de funcionalidade pelo protocolo CLEARER (INSPECT→REQUIREMENTS→IMPACT→PLAN→IMPLEMENT→TEST→REVIEW→AUDIT). Portado de clearer-engineering/skills/clearer-feature.
---

# CLEARER Feature (Muse)

Conduz especificação, implementação e validação de funcionalidade com blast radius mínimo. Sem dependência Antigravity (`agy`, `~/.gemini`); scripts referenciados são os deste profile.

## Fluxo (turno único quando requisitos definidos)

```text
INSPECT → REQUIREMENTS → IMPACT → PLAN → IMPLEMENT → TEST → REVIEW → AUDIT & REPORT
```

Pause só ante ambiguidade sem resposta no repo ou `WARN`/`DENY` do safety-gate.

### 1. Inspect

1. `bash scripts/detect-project.sh` (stack + ambiente, OBSERVED).
2. `git status --short` + `git branch --show-current`.
3. Localize arquivos e testes da área afetada (grep cirúrgico, sem dumps integrais).

### 2. Requirements & Boundaries

- **Concrete Goal**: o que a funcionalidade faz (aceite observável).
- **Explicit Boundaries**: dentro/fora expressos. Sem refatoração oportunista.
- **Contratos**: APIs, tipos, tabelas a preservar intactos.

### 3. Impact Map

Arquivos a criar/editar, dependências afetadas, blast radius estimado (nº arquivos/linhas).

### 4. Plan

Objetivo técnico, fluxo de dados, símbolos novos, tipagem estrita e defensiva (nulos, erros, limites), estratégia de testes.

### 5. Implement

Clean Code/SOLID/tipagem estrita. Sem `any`/`mixed` sem validação. Menor diff funcional.

### 6. Test

Crie/atualize testes comportamentais (happy + unhappy + bordas). Execute a suíte real:

```bash
bash scripts/test-runner.sh
```

Registre COMMAND, EXIT CODE, RESULT (executados/passaram/falharam/ignorados). Em repo com CI, a suíte canônica integral é pré-requisito p/ push (nunca só filtro parcial).

### 7. Review

```bash
bash scripts/diff-audit.sh
```

Sem regressões, markers de conflito, logs soltos, quebras de contrato ou lookups novos com testes congeladores desatualizados.

### 8. Audit & Report

Response Contract: Resultado, Ambiente, Alterações, Evidências, Testes, Validação, Pendências, Confiança. Classes `OBSERVED`/`INFERRED`/`UNKNOWN`; nunca afirme "testado/sem regressão" sem log.
