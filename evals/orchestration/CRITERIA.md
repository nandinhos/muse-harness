# CRITÉRIO PRÉ-REGISTRADO — orquestração por tiers (Etapa 4, F1)

Escrito ANTES do classificador (F3) e de qualquer corrida do corpus.
Ajustar o critério após ver o resultado invalida a avaliação (D5).

## Desenho

- Corpus congelado: `corpus.tsv`, 36 tarefas (12 LOW, 12 MEDIUM, 12 HIGH),
  análogo às 36 sessões do E2E-08 do lab — mas o número que vale é o daqui.
- Linha A (baseline): tudo em Wonder Full (T4), comportamento atual do
  dispatcher `clearer`. Shadow (F3) só registra; nunca decide nesta etapa.
- Classificador avaliado: `scripts/route_classify.py` + `routing.json`
  (determinístico, offline, sem LLM-judge).

## APROVA (classificador apto a shadow permanente) sse TUDO for verdade

1. **HIGH intocável (BLOCKER):** 12/12 tarefas HIGH classificadas em `T4`.
   Um único rebaixamento de HIGH reprova, sem média que compense.
2. **Acurácia global ≥ 90%** (≥33/36 no tier esperado).
3. **Sem inflação silenciosa:** 0 tarefa LOW em `T4` (economia é o objetivo;
   classificador que manda tudo p/ T4 aprova no item 1 e reprova aqui).
4. **Determinismo:** 3 corridas seguidas de `run.sh` com saída idêntica,
   cada uma <60s, offline.
5. **Deriva detectada:** remover 1 sinal HIGH do `routing.json` em sandbox
   → `run.sh` VERMELHO; restaurar → verde. Eval verde com sinal removido
   = teatro, reprova.

## Promoção de braço vivo (fora desta etapa, pré-registrado)

Sair do shadow para roteamento real exige A/B com modelos vivos:

- N≥10 por célula (classe × braço), prompts do corpus sem edição.
- 0 BLOCKER perdido vs. linha A (revisão System One dos dois diffs).
- Economia afirmada só da telemetria F2 + `muse usage`, por classe,
  com fonte de token rotulada (`api` × `estimated_chars4`).
- Qualquer regressão despromove a classe inteira (nunca o caso isolado).

## DESCARTA se QUALQUER um falhar

- HIGH abaixo de T4, acurácia <90%, LOW em T4, ou flake entre corridas.
- Deriva do item 5 não detectada.
- Critério editado depois da primeira corrida do corpus.

Decisão final: humana, após o relatório da F8. Sem promoção automática.
