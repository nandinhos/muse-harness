---
description: Emite relatorio estimado de gasto de tokens da tarefa
argument-hint: [arquivos ou logs para auditar]
---

Relatório de economia de tokens (skill `token-economy`):

1. Rode `python3 scripts/token-budget.py $ARGUMENTS` (ou, sem argumentos, estime os maiores artefatos lidos/gerados na tarefa atual).
2. Liste quais saídas foram comprimidas (`scripts/compress-output.sh` ou `rtk`) e o volume omitido em cada uma.
3. Compare com os tetos (8k/leitura, 4k/saída comprimida, 2k/evidence pack) e aponte estouros com justificativa `OBSERVED` ou ação de higiene pendente.
