# ADR 002 — Lições como etapa canônica do harness

## 1. Contexto

Incidentes resolvidos (dashboard 500 por drift de schema, CI vermelho por helper
colidindo + Larastan) evaporavam no chat. A dinâmica `learned-lesson`/
`systematic-debugging` já produzia o formato (título ≤80, tipo/stack/escopo + 4 seções),
mas nada obrigava seu uso.

## 2. Decisão

Gravar na skill `clearer` §7 a ordem de força: (1) barreira executável no repo
(teste de regressão, hook, gate); (2) runbook; (3) nota de lição canônica — com
pergunta explícita antes de persistir em memória (default: relatório de leitura).

## 3. Consequências

- Positivas: todo incidente com causa provada sai do turno como barreira ou registro;
  reincidência passa a indicar falha da barreira, não azar.
- Negativas: custo de escrita por incidente; barreira mal desenhada vira atrito
  (rever gates que disparam em falso).

## 4. Alternativas Consideradas

- Só memória de sessão: evapora e não é auditável — rejeitada.
- Só runbook textual: sem execução, depende de disciplina humana — mantido como nível 2, não único.
