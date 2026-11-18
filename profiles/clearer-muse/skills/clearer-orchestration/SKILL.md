---
name: clearer-orchestration
description: Roteamento por tiers de modelo do CLEARER (shadow). Classifica a tarefa pelo Risk Dial em T0-T4, registra o palpite na telemetria e define gates de re-planejamento; HIGH nunca rebaixa de T4.
---

# Orquestração por Tiers (shadow)

Abstração do modelo planner↔executor para o host Muse: o dispatcher
`clearer` continua decidindo; esta skill **classifica e registra** — é a
camada de observação que precede qualquer roteamento real (critério
pré-registrado em `evals/orchestration/CRITERIA.md`).

## Tiers (Risk Dial → modelo)

| Classe | Tier | Quem executa | Exemplos |
|---|---|---|---|
| LOW | T0 | mecânico/barato | listar, explicar, histórico |
| LOW | T1 | leve | typo, 1 arquivo, causa mapeada |
| MEDIUM | T2 | executor de código (D6: Spark) | CRUD, refactor delimitado, testes |
| MEDIUM | T3 | executor forte | integrações, cache, filas, upload |
| HIGH | T4 | Wonder Full decide **e** revisa (D6) | auth, dinheiro, produção, concorrência |

Configuração viva: `routing.json` nesta skill (sinais por classe).
Classificador: `python3 scripts/route_classify.py --task "<tarefa>"
[--telemetry <eventos.jsonl>]` — emite JSON e, com telemetria, grava
`decision=shadow` mascarado.

## Regras invariantes

1. **HIGH nunca rebaixa.** Qualquer sinal HIGH força T4, sem média que
   compense; dúvida entre classes resolve para cima (fail-safe).
2. **Shadow até o número.** Sair do shadow exige o A/B pré-registrado
   (N≥10/célula, 0 BLOCKER perdido vs. baseline) — palpite do
   classificador não é decisão de modelo.
3. **D6:** Wonder Full decide/revisa; Spark executa código; modelo leve
   (Ember) fora de código. Revisão de diff é sempre T4.
4. **Sem definição global duplicada de agente** (lição v2.3.1): papéis
   vivem nesta skill e nos subagentes da sessão, nunca em cópia global
   que consuma orçamento de slots do host.

## Re-planning triggers (devolver ao planner)

- Teste vermelho após 1 ciclo de auto-reparo (regra do dispatcher).
- Sinal HIGH descoberto durante execução classificada menor → sobe p/ T4
  e re-planeja antes de mutar.
- Diff toca arquivo fora do Evidence Pack aprovado.
- Finding BLOCKER de review em qualquer classe.

## Evidence Pack (handoff entre tiers)

Campos mínimos ao delegar: objetivo em 1 frase, classe/tier com sinais,
arquivos inspecionados (`arquivo:linha`), testes que provam, riscos
abertos. Teto de higiene do `token-economy`: 2k tokens por pack.

## Receitas de workflow (planner ↔ executor)

Papéis são subagentes nativos da sessão (um papel por criança, nunca
definição global duplicada — regra 4). O planner é sempre T4; executores
nunca aprovam o próprio trabalho.

### HIGH (T4) — pipeline completo com checkpoint

```text
investigator (read-only) -> architect (plano) -> [checkpoint humano]
  -> implementer -> test-engineer -> reviewer (adversarial)
  -> evidence-auditor (claims x provas) -> planner decide
```

Use quando qualquer sinal HIGH disparar. O checkpoint precede a primeira
mutação; re-planning trigger devolve ao `architect`, nunca ao executor.

### MEDIUM (T2/T3) — map read-only paralelo + execução única

```text
planner fatia -> N investigadores read-only em paralelo (1 por pergunta)
  -> planner sintetiza -> 1 executor implementa -> suíte + review T4
```

Paralelismo só em leitura; escrita é serializada num único executor para
o diff continuar auditável em uma passada.

### Review — fan-out com síntese T4

```text
1 revisor por dimensão (seguranca | corretude | regressao) em paralelo
  -> sintese T4 deduplica, ordena por severidade e decide
```

Finding sem evidência (`arquivo:linha` ou comando) volta como
`UNSUPPORTED`, não como BLOCKER — System One vale dentro do fan-out.

### LOW (T0/T1) — sem orquestração

Turno único direto, sem subagentes (Ponytail): orquestrar tarefa atômica
custa mais tokens do que executa. O shadow só registra a classificação.
