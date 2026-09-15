# CRITÉRIO PRÉ-REGISTRADO — piloto smoke-eval (exigência do conselho)

Escrito ANTES de qualquer fixture. Ajustar o critério após ver o resultado
invalida o piloto (condição `claude` nº 1).

## APROVA (promover a gate permanente) sse TUDO abaixo for verdade

1. Baseline: 3 corridas seguidas de `evals/run.sh`, todas verdes, cada uma <60s,
   offline, sem LLM-judge.
2. Deriva A (histórica, ADR-004): hook `safety-gate.py` ausente → runner fica
   VERMELHO com mensagem de falha de infra (fail-closed; nunca verde silencioso).
3. Deriva B (silenciosa): enfraquecimento de 1 ponto em `normalize_env` →
   ≥1 fixture fica VERMELHA; após restaurar, volta ao verde.
4. Barra do `agent`: ≥1 fixture cobre regressão comportamental que nenhum gate
   automatizado atual executa (a tabela de decisão do hook nunca é exercitada
   por `canonical-diff.sh`, `token-budget.py` ou pelo hook vivo fora de sessão).
5. Zero `grep` sobre prosa livre: só tokens estruturados do contrato
   (`CEH-SAFETY ALLOW|WARN|DENY <env>`, exit codes).

## DESCARTA (ADR de descarte + remover `evals/`) se QUALQUER um falhar

- Baseline com vermelho, flake, ou qualquer corrida ≥60s.
- Deriva A ou B não detectada (eval verde com gate quebrado = teatro).
- Restauração não volta ao verde (fixture acoplada à deriva).
- Custo (tempo wall + tokens estimados) acima da soma dos gates atuais.

Decisão final: humana, após o relatório. Sem promoção automática (`muse`).
