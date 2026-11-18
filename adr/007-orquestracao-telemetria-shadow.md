# ADR 007 — Orquestração por tiers em shadow + telemetria local (Etapa 4)

## 1. Contexto

O ecossistema de origem (Antigravity) evoluiu p/ CEH v2.3.1 com camada
L1.5 (`ceh_decisions.py`, Gemini Decisions API), dispatcher com
`overwrite` determinístico de comandos (enhancements v3.5.0) e telemetria
multi-terminal — tudo medido pelo laboratório `benchmark-antigravity`
(E2E-08, HOOK-OPT-01/02/03; confiança rebaixada a 0.85 pela própria
auditoria do lab). Neste porte, o host Muse não expõe reescrita de args
por hook (contrato observado: `{}` / `{"decision":"block"}`), não há API
Gemini, e o dispatcher upstream tem caminho fail-open confirmado na
carga lazy do Elo 1 (auditoria F4 da Etapa 4). Absorver as peças como
estão traria dependência nova, host errado e um buraco de governança.

## 2. Decisão

1. **Tiers T0–T4 em shadow, não em decisão.** `routing.json` +
   `scripts/route_classify.py` classificam a tarefa (sinais do Risk Dial)
   e só registram (`decision=shadow`). HIGH força T4 sem exceção; sair do
   shadow exige o A/B pré-registrado de `evals/orchestration/CRITERIA.md`
   (N≥10/célula, 0 BLOCKER perdido) — ainda pendente, deliberadamente.
2. **Telemetria local e mascarada, sem sync.** `telemetry_log.py`
   (append JSONL com máscara fail-closed) + `telemetry_report.py`
   (agregador offline), fonte de token sempre rotulada (`api` ×
   `estimated_chars4`). Nenhum dado sai da máquina por este harness.
3. **System One só no subconjunto offline.** `system_one.py` implementa
   perguntas atômicas com scorers determinísticos (o `FALLBACK_OFFLINE`
   do upstream); o caminho online (Gemini Decisions) é rejeitado por
   dependência e por escopo exclusivo declarado do arquivo de origem.
4. **`overwrite` e dispatcher unificado rejeitados** até o host expor
   canal de reescrita de args e o upstream corrigir o fail-open da carga
   lazy (ou alguém provar o contrário com teste). A economia equivalente
   hoje é disciplina: `token-economy` + `compress-output.sh` + `rtk`.
5. **Stop-guard como verificação, não como hook.** Sem evento `Stop`
   confirmado no host, `stop-guard.py` valida o Response Contract sob
   demanda quando `.ceh/feature.json` existe; no-op fora disso.

## 3. Consequências

- Positivas: a abstração (planner↔executor, tiers, telemetria) entra sem
  dependência nova e sem prometer economia não medida aqui; o E2E
  pré-registrado (F8) prova o classificador no corpus congelado
  (HIGH 12/12, 35/36) mantendo o baseline como único executor.
- Negativas: o ganho de tokens do roteamento real fica adiado até o A/B
  vivo; sinais do classificador foram autorados com o corpus visível
  (limitação registrada na F8) — generalização só o A/B prova.

## 4. Alternativas Consideradas

- Portar `ceh_decisions.py` integral (1.286 linhas + API Gemini):
  dependência e escopo errados — rejeitada (item 3).
- Portar o dispatcher com Elo 3 e adaptar `overwrite` via outro canal:
  sem canal do host e com fail-open upstream — rejeitada (item 4).
- Roteamento real já, usando os números do lab Antigravity: evidência de
  outro host/modelo não autoriza decisão aqui — rejeitada (D5).
