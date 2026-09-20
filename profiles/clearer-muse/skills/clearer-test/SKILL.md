---
name: clearer-test
description: Execução determinística de testes com contrato auditável (COMMAND/EXIT/STATUS). Portado de clearer-engineering/skills/clearer-test.
---

# CLEARER Test (Muse)

"Testado" só com suíte real executada e saída registrada. Sem fake pass.

## 1. Execução

```bash
bash scripts/test-runner.sh
```

Ou comando canônico da stack (`./vendor/bin/pest`, `php artisan test`, `npm test`, `pytest`, `go test ./...`). Saídas verbosas via `scripts/compress-output.sh` (preserva exit code).

## 2. Contrato de registro

```text
==========================================
COMMAND:   <comando exato>
EXIT CODE: <0 = sucesso>
STATUS:    <PASS | FAIL | NOT RUN>
==========================================
RESULTADO:
- Executados: <N> | Passaram: <N> | Falharam: <N> | Ignorados: <N>
```

## 3. Falhas

- `FAIL` (exit ≠ 0): reporte como FAIL com stack trace/asserção. 1 auto-reparo fundamentado; persistindo, handoff.
- `NOT RUN`: só com motivo técnico exato (dependência ausente, sem ambiente). Nunca converta em verde.
- Cobertura: happy + unhappy + nulos/vazios/limites; sem mocks que escondam integração real.
