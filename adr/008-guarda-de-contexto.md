# ADR 008 — Guarda de contexto: custo real, reinício por etapa (incidente 2026-11-18)

## 1. Contexto

A sessão `01a1f018` (2026-11-18, Etapa 4) acumulou 367 passos de LLM em
12 intenções do usuário. O histórico cresceu de 39k para 442k tokens e
cada passo re-enviou tudo: 98.824.410 `input_tokens` brutos. Auditando o
`session.jsonl` do host, 96.824.328 (98%) eram `cached_tokens` — o gasto
novo real foi 2.000.082 input + 183.250 output (~2,18M). A telemetria que
soma o bruto superestima o custo em ~40× e gerou alarme desproporcional.

Amplificadores provados no mesmo log: loops editar→testar
(`bash` 215 + `edit_file` 134 chamadas), lane `tool_result` com média de
246 KB por prompt (saídas verbosas retidas no histórico), 20 subagentes
na sessão de 17/11 (~3,45M input bruto, maioria relendo o que o pai já
leu) e skills carregadas residentes no contexto até o fim da sessão.

## 2. Decisão

1. **Métrica oficial = custo real.** `scripts/session_cost.py` lê os
   eventos `model_completed` do `session.jsonl` e reporta, por modelo,
   `steps/input/cached/real_input/output/real_cost`, com
   `real_cost = (input − cached) + output`. Relatar o bruto como gasto é
   claim `UNSUPPORTED`. Aceita arquivo ou diretório de sessão (inclui
   `subagent/` recursivamente); sem eventos/ausente sai 2 (fail-closed).
2. **Reinício por etapa com guarda mecânica.** `scripts/context-guard.py`
   classifica a sessão pelo último passo e pelo nº de passos:
   `WARN` ≥150k tok ou ≥80 passos (exit 1), `BLOCK` ≥300k ou ≥200 passos
   (exit 2). Em `BLOCK`, não se inicia etapa nova na mesma sessão:
   fecha-se com handoff ≤1k tok e reinicia-se. Como o host não expõe
   evento de contexto ao `safety-gate`, o guardião é verificação
   explícita no fecho de etapa (mesmo padrão do `stop-guard.py`,
   ADR-007 item 5) — nunca no caminho quente do hook.
3. **Truncamento antes do histórico.** `scripts/compress-output.sh`
   ganha teto duro de caracteres (`CEH_COMPRESS_MAX_CHARS`, default
   16000 ≈ 4k tok, o teto de saída do `token-economy`): contagem de
   linhas não basta, linhas gigantes furavam o orçamento.
4. **Anti-duplicação de subagentes.** Evidence Pack passa a listar o que
   já foi inspecionado (`arquivo:linha`) e o filho não relê; investigação
   read-only usa `muse-spark-1.3`, `full` só decide/revisa (D6);
   pai em `BLOCK` não spawna. Regras na skill `clearer-orchestration`
   e na seção “Guarda de contexto” da skill `token-economy`.
5. **Regra, não hook novo.** Nenhum hook `PreToolUse` adicional: o
   `safety-gate` não recebe tamanho de histórico no payload, e um gate
   que não observa a variável que promete conter seria teatro. A camada
   executável é `session_cost.py` + `context-guard.py` + compressão,
   acionada por `/token-report` e pelo fecho de etapa.

## 3. Consequências

- Positivas: o próximo relatório de consumo nasce com a métrica certa
  (provado nos dados reais do incidente: bruto 98.824.410 → real
  2.183.332); o `BLOCK` teria disparado muito antes do passo 367; a
  saída de `bash` tem teto físico, não só recomendação.
- Negativas: os limiares (150k/300k, 80/200 passos) são heurística
  inicial deste incidente, não medição A/B — recalibrar com
  `session_cost.py` nas próximas etapas antes de endurecer. O guardião
  depende de invocação no fecho; sessão que ignora o fecho não é
  interrompida à força (limite do host, registrado).

## 4. Alternativas consideradas

- Hook `PreToolUse` estimando contexto pelo payload: o payload não
  carrega o histórico — estimativa seria fictícia. Rejeitada.
- Compactação automática de histórico pelo harness: o host é dono do
  histórico; reescrevê-lo por fora quebraria o cache. Rejeitada.
- Só documentar (“reinicie sessões”): era o estado anterior ao
  incidente e falhou. Rejeitada — regra sem instrumento não segura.
