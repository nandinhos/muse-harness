# HANDOFF — Etapa 4: Abstração Antigravity → perfil Muse (CEH v2.3.1 + Orquestração)

| Campo | Valor |
|---|---|
| Status | **EM EXECUÇÃO** — `go` dado pelo goal da sessão (executar plano completo, testar, E2E) |
| Origem do plano | Sessão 2026-11-17 (`01a1e958…`), workflow 4 repos + plano D1–D6/F0–F9; recuperado do log Muse após perda do checkout (kernel WSL) e consolidado com a classificação arquivo a arquivo de 2026-11-18 |
| Fontes (read-only) | `antigravity-clearer-engineering-harness` v2.3.1 (`4db20b7`), `antigravity-harness-enhancements` v3.5.0 (`85351c6`) + pin `7318f93` da branch `dev-security-opt-01-p01` (`abc63dc`), `benchmark-antigravity` v0.13.0 (`2fe6cf1`) |
| Último marco absorvido | Etapa 3: CEH v2.1.3 + Ponytail v5 (`550848a`) → v0.11.0 (`e3662d0`), **não publicado** (remoto em `ef13379`) |
| Base desta etapa | Branch `dev-absorcao-v213-ponytail-v5` @ `e3662d0`, worktree limpa |
| Governança | Oficial só no Antigravity (Muse = read-only lá); teto local **V2**; push/promoção = autorização separada |

## Baseline OBSERVED (2026-11-18, antes de qualquer edição)

| Prova | Comando | Resultado |
|---|---|---|
| Suíte do profile | `bash profiles/clearer-muse/tests/run-all-tests.sh` | exit 0, **9/9**, 150 asserts (Etapa 3) |
| Meta-eval | `bash evals/run.sh` | exit 0, 16/16, WALL 3s |
| Git | `git status` / `ls-remote` | limpo; local 5 commits à frente do remoto (`ef13379`) |

## Abstração em 3 camadas (regra de porte da etapa)

O harness de origem tem essência agnóstica com camadas amarradas ao Google
Antigravity. Toda peça do pack é classificada antes de tocar código; só a
primeira camada viaja:

- **Agnóstica (PORTA):** motor `ceh_core` (re-vendor), System One **offline**
  determinístico, regra 15 zero-zombie/confinamento, `git_inspect.py`
  declarativo, schema de telemetria JSONL mascarado, tiers de orquestração
  T0–T4 com re-planning triggers, `ceh-drift` (condicional a não duplicar o
  `doc-audit`).
- **Adapter Muse (TRADUZ):** `rules/` → skills sob demanda; `hooks.json` →
  manifesto com 1 hook `PreToolUse`; dispatcher `agy` → adapter fino sobre
  `adapters/muse.py`; agentes Antigravity → subagentes/workflows Muse;
  compressão de terminal → skill `token-economy` + `compress-output.sh`.
- **Antigravity-only (NÃO PORTA):** matchers `agy` de escrita, instalação em
  `~/.gemini`, context-mode (`ctx_*`), Gemini Decisions **online**,
  `RequestFeedback`/artifacts, sync p/ Windows, RULE-OPT-01 (teto de
  24.000 B `always_on` inexistente no Muse: `clearer-rules` tem 6.635 B),
  telemetria multi-terminal sincronizada (sem consumidor aqui).

## Delta oficial não absorvido — classificação

Delta `550848a..4db20b7`: 32 commits, 30 arquivos (+2.872/−274), medido por
`git diff --name-status` no clone oficial (OBSERVED).

| Item oficial | Classe | Destino no porte Muse |
|---|---|---|
| `scripts/ceh_core/push.py` (`is_tree_identical`) | **RE-VENDOR** | motor vendorizado (F5) — cert de árvore idêntica no Pre-Push Gate |
| `scripts/adapters/antigravity.py` (cwd/`git -C`) | **RE-VENDOR** | inerte no Muse; item de auditoria p/ `muse.py` (F5) |
| `rules/AGENTS.md` regra 15 + `coding-policy.md` §7 (v2.2.0) | **ADAPTAR** | `skills/clearer-rules` (texto, F5) |
| `scripts/test-runner.sh`, `detect-project.sh` | **ADAPTAR** | porte semântico, nunca colar (F5) |
| `scripts/ceh-drift.sh` (novo, 189 l) | **ADAPTAR*** | `scripts/` se não duplicar `doc-audit` (decisão F6) |
| `scripts/ceh_decisions.py` (novo, 1286 l) | **ADAPTAR (subconjunto)** | só `FALLBACK_OFFLINE` determinístico como `system_one.py` (D2, F6); API Gemini fora |
| `scripts/ceh-stop-guard.py` (novo, 224 l) | **ADAPTAR*** | contrato de fechamento em script + skill; evento `Stop` do host é `UNKNOWN` (F6) |
| `hooks.json`, `install.sh`, aliases, `plugin.json` oficial | NÃO PORTAR | host Antigravity; porte usa manifesto Muse |
| RULE-OPT-01 (compactação −51%) | NÃO PORTAR | problema inexistente no Muse (acima) |
| Enhancements: dispatcher/Elo 3 `overwrite` (pin `7318f93`) | **AUDITAR** | F4: fail-closed + capacidade de `overwrite` no host (`UNKNOWN`) |
| Enhancements: `git_inspect.py` (OPT-004) | **ADAPTAR** | `scripts/` + referência no `token-economy` (F2) |
| Enhancements: telemetria JSONL (3.080 ev.; overwrite=3) | **ADAPTAR (schema)** | event-log próprio mascarado (F2); sync multi-terminal fora |
| Benchmark: E2E-08/HOOK-OPT/RULE-OPT | **EVIDÊNCIA** | desenho do A/B da F8; números são Gemini/`agy`, confiança 0.85 (auditoria do lab) |

## Decisões D1–D6 (da sessão de 2026-11-17, mantidas)

- **D1** Publicar o 0.11.0 antes de absorver — um delta por gate. (`go` ≠ push.)
- **D2** System One só offline, pinado na v2.3.1 (fix `criteria` em lista incluído).
- **D3** `overwrite` só atrás de telemetria própria (3/3.080 upstream = não provado).
- **D4** Stop-guard traduzido e fail-closed.
- **D5** Promoção só com número pré-registrado: N≥10/célula, 0 BLOCKER perdido.
- **D6** Wonder Full decide/revisa, Spark 1.3 executa código, Ember fora de código.

## Fases (parar no primeiro vermelho; commit atômico por fase)

- **F-doc — Persistir antes de tudo.** Este handoff + `HANDOFF.md` §11,
  commit só-docs. Lição da perda de 2026-11-17/18: plano nasce versionado.
- **F0 — Certificado do 0.11.0.** Suíte + Certificado de Voo no HEAD.
  Push/promoção exigem pedido explícito de publicação (D1).
- **F1 — Critério pré-registrado.** Corpus congelado LOW/MEDIUM/HIGH em
  `evals/orchestration/` (`CRITERIA.md` + `corpus.tsv`) antes de rodar braços.
- **F2 — Telemetria primeiro.** `scripts/telemetry_log.py` (append mascarado)
  + `scripts/telemetry_report.py` (agregador offline) + `scripts/git_inspect.py`
  adaptado (token `api` × `estimated_chars4` rotulado). Casos no smoke.
- **F3 — Roteador em shadow.** Skill `clearer-orchestration` + `routing.json`
  (tiers T0–T4 mapeados do Risk Dial, gates, re-planning triggers) +
  `scripts/route_classify.py` shadow (só registra na telemetria, nunca decide).
- **F4 — Auditoria do pin `7318f93`.** Ler o caminho de falha do lazy-load
  (`_SAFETY_GATE_AVAILABLE=False`); provar a capacidade real do host Muse
  p/ `overwrite` de args; o invariante local (import/erro = deny) ganha caso
  na suíte de safety. Sem promessa de ganho (D3).
- **F5 — Re-vendor v2.3.1 + scripts + regra 15.** Procedimento de
  `VENDOR.md` na ref `4db20b7`; conferir que o diff do bundle é só
  `push.py` + `adapters/antigravity.py`, sha novo no C13; caso novo:
  cert de árvore idêntica libera push, árvore diferente segue negando.
  Porte semântico de `test-runner`/`detect-project` se houver delta portável
  além do já absorvido; regra 15 em `clearer-rules`.
- **F6 — System One offline + stop-guard + drift.** `scripts/system_one.py`:
  perguntas atômicas de espaço fechado sobre o diff, scorers determinísticos
  (sem rede, sem chave), saída `--human` p/ `diff-audit.sh` (não-bloqueante).
  `scripts/stop-guard.py`: valida Response Contract do fechamento quando
  `.ceh/feature.json` existir; sem ele, no-op exit 0. `ceh-drift`: decisão
  registrada vs `doc-audit` antes de portar.
- **F7 — Workflows planner↔executor.** Receitas na skill de orquestração:
  pipeline HIGH (investigator→architect→implementer→test→review→auditor),
  map read-only paralelo, review fan-out com síntese T4; zero definição
  global duplicada de agente (lição v2.3.1).
- **F8 — E2E diferencial.** `evals/orchestration/run.sh`: corpus da F1 contra
  classificador (100% HIGH→T4), suíte diferencial do gate 0-regressão,
  canário de telemetria (overwrite não afirmado sem dado). A/B com modelos
  vivos N≥10/célula fica pré-registrado e pendente de execução dedicada.
- **F9 — Release.** ADR-007 (orquestração/telemetria), bump 0.12.0,
  README + este handoff fechados com evidências, reinstalação via
  `muse plugins update` (restart carrega). Push segue gate separado.

## Validation Plan

| Prova | Comando | Esperado |
|---|---|---|
| Suíte completa (por fase) | `bash profiles/clearer-muse/tests/run-all-tests.sh` | exit 0, 9/9, asserts ≥ 150 |
| Meta-eval | `bash evals/run.sh` | exit 0, 16/16 |
| E2E orquestração | `bash evals/orchestration/run.sh` | exit 0, critérios da F1 |
| Certificado | `bash profiles/clearer-muse/scripts/test-runner.sh bash evals/run.sh` | PASS no HEAD |
| Veredito calculado | `evidence-report.sh --strict` | coerente, nunca declarado |
| Manifesto | `muse plugins validate profiles/clearer-muse` | válido, diagnostics=0 |
| Diff | `git diff --check` + `diff-audit.sh` | limpo, sem segredos |

## Riscos / fora de escopo

- F4 depende de capacidade do host hoje `UNKNOWN`; resultado honesto pode ser
  "overwrite indisponível no Muse" — fica registrado, D3 preservada.
- Claims upstream (80/80, 138/138, −51,5%) são `declarados` até rodarem aqui.
- Fora: qualquer edição nos repos oficiais; push/promoção sem `go` de
  publicação; API Gemini; suíte fast; homologação V3 (Antigravity).
- Ponto de decisão residual: versão **0.12.0** e pin-ou-promoção de `7318f93`
  (vence na F4). O `go` desta execução aceita ambos como proposta.

## Registro de execução (OBSERVED)

| Fase | Commit | Prova |
|---|---|---|
| Baseline | `e3662d0` | 9/9 + 16/16 (acima) |
| F-doc | `03a420c` | 9/9; Certificado de Voo PASS no HEAD (F0) |
| F1 | `8bc224f` | corpus 36 (12/12/12) + critério pré-registrado |
| F2 | `51c6216` | smoke 25 asserts (+4); máscara sondada com variantes não enumeradas (0 vazamentos) |
| F3 | `a9e2a7c` | smoke 27 (+2); manifesto válido 16 skills; sonda do corpus 35/36, HIGH 12/12 (M08 registrado, sem ajuste de critério) |
| F4 | `4912ddb` | safety 16 (+1 fail-closed); achados abaixo |
| F5 | `897e70a` | ceh-core 19 (+C16a/b árvore idêntica, +C17 `git -C`); C13 sha `eed5a051…`; evals F11 corrigida p/ árvore distinta; timeouts em sondas docker |
| F6 | _(este commit)_ | smoke 30 (+3); `system_one.py` offline + `stop-guard.py`; decisão drift abaixo |

### F6 — Decisão `ceh-drift.sh`: NÃO portar (com gatilho)

O drift oficial faz (a) referências quebradas doc→arquivo e (b) alerta
temporal (código citado mudou depois do doc). A parte (a) já é coberta
pelo `doc-audit` (links locais, commits citados, README×manifestos); a
parte (b) é heurística de timestamp — doc correto não muda quando o
código muda legitimamente. Portar 189 linhas de bash duplicaria o
encanamento do `doc-audit`. **Gatilho de reavaliação:** se doc
desatualizada virar defeito observado, adicionar check ao `doc-audit.py`
existente — não script novo (`shortcut:` registrado aqui).

### F5 — Divergências deliberadas vs. upstream (registradas)

- **Fast-path de renovação de certificado NÃO portado:** o `test-runner`
  oficial passou a renovar o cert sem rodar testes quando a árvore é
  idêntica. Aqui o gate vendorizado já aceita o cert antigo p/ árvore
  idêntica (`is_tree_identical`), então renovar só falsificaria o campo
  `command`/`timestamp` de uma execução que não houve. Reavaliar apenas se
  algum consumidor exigir `cert == HEAD`, e aí com campo `promoted_from`
  explícito — nunca como corrida fingida.
- **Auditoria `muse.py` × `git -C`: sem lacuna.** Sonda comportamental
  (promovida a caso C17): `git -C <repoB-sem-cert> push` a partir de repo
  com cert válido é negado — o motor resolve o repo alvo do `-C`, não o
  cwd do payload. O fix análogo da v2.3.1 era do adapter Antigravity.

### F4 — Auditoria do pin `7318f93` (OBSERVED, corpo lido)

- **Fail-open confirmado no dispatcher upstream:** em
  `hooks/hooks_dispatcher.py@7318f93` (linha 841), se `_ensure_safety_gate()`
  falha no import lazy, **todo o Elo 1 (avaliação CEH por ambiente) é pulado
  em silêncio** e o fluxo segue p/ Elo 1.5/3, que podem liberar. A exceção
  *dentro* da avaliação é fail-closed (l. 863), mas a falha de carga não é.
  Mitigante parcial: padrões catastróficos lexicais do Elo 0 rodam antes.
  Perde-se governança por ambiente/pre-push sem nenhum sinal. **Decisão:
  não portar a arquitetura do dispatcher**; nosso adapter já nega com motor
  quebrado (`ENGINE_OK=False` → block dual), agora com caso mantido
  `engine-broken-failclosed`. Reportar ao upstream fica a critério do dono.
- **`overwrite` indisponível no contrato Muse atual:** o adapter vendorizado
  `adapters/muse.py` renderiza só `{}` / `{"decision":"block"}` (l. 133–145)
  e nenhum arquivo do porte conhece reescrita de args. Sem canal do host,
  Elo 3 mecânico não é portável nesta etapa — vale a disciplina em prosa do
  `token-economy` (D3 preservada; upstream tem 3 eventos `overwrite` em
  3.080, ou seja, nem lá está provado em produção).
- **Inspeção JS estática / strip `ENV=`:** a inspeção JS mira ferramentas
  `ctx_execute*` do Antigravity (inexistentes aqui; `node -e` chega como
  string de terminal avaliada pelo motor). O strip de prefixo `ENV=` em
  comando string já foi absorvido na Etapa 3 (`inspect_integrations`, caso
  g). Nada a portar na F4 além do registro.
