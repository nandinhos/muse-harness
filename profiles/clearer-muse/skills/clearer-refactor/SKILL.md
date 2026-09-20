---
name: clearer-refactor
description: Refatoração segura pelo CLEARER (baseline verde→refactor→re-run→diff-audit). Portado de clearer-engineering/skills/clearer-refactor.
---

# CLEARER Refactor (Muse)

Refatoração sem mudança de comportamento externo. Proibido misturar feature nova no mesmo diff.

```text
BASELINE & CONTRACTS → TESTS BASELINE → REFACTOR → TESTS RE-RUN → DIFF AUDIT → REPORT
```

### 1. Baseline & Contracts

Localize a área; liste contratos públicos (assinaturas, interfaces, payloads, schemas) a preservar; verifique cobertura existente.

### 2. Tests Baseline

```bash
bash scripts/test-runner.sh
```

Suíte 100% verde antes de editar. Se vermelha, pare: baseline quebrado é exceção (handoff), não ponto de partida.

### 3. Refactor

Clean Code/SOLID: reduzir duplicação, extrair responsabilidades, fortalecer tipagem. Menor diff possível.

### 4. Re-run & Invariantes

```bash
bash scripts/test-runner.sh
```

Paridade exata com o baseline (mesmas contagens). Qualquer divergência = regressão: 1 auto-reparo fundamentado, depois handoff.

### 5. Diff Audit

```bash
bash scripts/diff-audit.sh
```

Sem alterações fora do escopo, ruído cosmético ou quebra de tipagem.

### 6. Report

Response Contract com paridade antes/depois comprovada (COMMAND + EXIT CODE + contagens dos dois runs).
