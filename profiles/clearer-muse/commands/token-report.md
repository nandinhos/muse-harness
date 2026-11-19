---
description: Emite relatorio estimado de gasto de tokens da tarefa
argument-hint: [arquivos ou logs para auditar]
---

Relatório de economia de tokens (skill `token-economy`):

1. **Custo real da sessão** (métrica oficial, nunca o bruto): rode
   `python3 scripts/session_cost.py <session.jsonl>` — reporta por modelo
   `steps/input/cached/real_input/output/real_cost`, onde
   `real_cost = (input − cached) + output`. Somar `input_tokens` bruto
   superestima o gasto em até ~40× (cache relido por passo).
2. **Guarda de contexto:** rode
   `python3 scripts/context-guard.py --session <session.jsonl>`;
   `WARN`/`BLOCK` (exit 1/2) viram pendência explícita: fechar a etapa com
   handoff ≤1k tok e reiniciar a sessão.
3. Rode `python3 scripts/token-budget.py $ARGUMENTS` (ou, sem argumentos, estime os maiores artefatos lidos/gerados na tarefa atual).
4. Liste quais saídas foram comprimidas (`scripts/compress-output.sh` ou `rtk`) e o volume omitido em cada uma.
5. Compare com os tetos (8k/leitura, 4k/saída comprimida, 2k/evidence pack, 1k/handoff) e aponte estouros com justificativa `OBSERVED` ou ação de higiene pendente.
6. Obrigatório no fecho de tarefas que envolveram logs grandes ou múltiplos agentes; sem logs grandes, dispensável.
