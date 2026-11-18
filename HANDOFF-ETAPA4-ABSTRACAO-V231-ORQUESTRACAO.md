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
| F-doc | _(este commit)_ | doc-audit na suíte |
