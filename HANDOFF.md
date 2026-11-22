# HANDOFF — Ativação e lapidação do harness em `muse-harness`

> **Handoff canônico deste repo é este arquivo**; os demais `HANDOFF-*.md` são registros históricos de entregas (0.4.0–0.9.0, `muse-ceh`), preservados para auditoria.

> Para o agente que assumir neste repo. Leia este arquivo primeiro, nesta ordem:
> README → docs/CREATE-PROFILE.md → adr/001 + 002 → este handoff → executar §4.

## 1. Contexto

O profile `clearer-muse` (CLEARER Engineering Harness) nasceu dentro do projeto
`events` (`<events>/plugins/clearer-muse/`, na máquina de origem) e foi promovido para
casa canônica aqui (`profiles/clearer-muse/`, cópia `diff -r` idêntica). O `events` foi
limpo da cópia vendored e passou a **usar** este canônico (ver §5). Remoto:
`https://github.com/nandinhos/muse-harness.git` (branches `dev` → `main`,
topologia clássica), com tudo publicado.

## 2. Estado atual (verificado)

| Item | Estado |
|---|---|
| `profiles/clearer-muse/` | canônico v0.13.0 (Etapa 4 + correções Codex + guarda de contexto/Elo3/dispatch sob demanda, `47c0821`): 16 skills, 2 commands, hook `safety-gate` (adapter sobre o motor CEH v2.3.1 vendorizado em `hooks/vendor/ceh/`, ref `4db20b7`), 27 scripts, suíte `tests/` 9/9 + E2E `evals/orchestration/` 6/6 |
| `profiles/muse-ceh/` | dispatcher pessoal v0.2.1 (skill + comando + teste, `hooks=0`; ver `HANDOFF-muse-ceh.md`) |
| `docs/CREATE-PROFILE.md` | guia de criação de profile (anatomia, 7 passos, segredos, checklist, riscos) |
| `templates/mcp.json` | base MCP só com `context7` + `${CONTEXT7_API_KEY}` (sem segredo) |
| `adr/001…010` | Context7, lições, minimalismo (ponytail), hook órfão no update, governança CEH, isenção declaration-only, orquestração/telemetria shadow, guarda de contexto (008), orçamento de input/Elo3 (009), aceitação dos resíduos Codex (010) |
| `LICENSE` / CI | MIT; GitHub Actions em `dev`+`main` (sintaxe + evals 16/16 + suíte 9/9) |
| Segredos | varredura limpa em todo o repo; chave real só em `~/.bashrc` do host (600) |
| `events` | sem `plugins/clearer-muse/`; `installed.json` reapontado para cá (ver §5) |

## 3. Objetivo da próxima sessão (lapidação)

Manter este repo como único ponto de evolução do harness. Imediato (ver §9):
`muse plugins update muse-ceh` (v0.2.1) no início da sessão + restart
(ADR-004) + tarefa-canário. Já resolvidos: MCP `context7` operacional (§7),
`systematic-debugging` como addon `debugging` (§7) e `diff -r` anti-deriva
(`canonical-diff.sh`).

## 4. Procedimento de ativação (executar nesta ordem)

1. **Sanidade**: `muse plugins validate profiles/clearer-muse` e
   `bash profiles/clearer-muse/tests/run-all-tests.sh` (esperado: válido,
   9/9 PASS, exit 0).
2. **Fonte instalada**: confirmar que a fonte do plugin `clearer-muse` na máquina
   aponta para `<checkout>/profiles/clearer-muse`
   (campo `source.path` do registro de plugins instalados). Se apontar para o
   `events`, atualizar (backup antes) e **reiniciar a sessão** — skills e MCP só
   sobem no boot.
3. **Skill viva**: no primeiro turno pós-restart, o dispatcher deve declarar ambiente
   + Risk Dial sem ser perguntado. Se não declarar, a fonte está errada — voltar ao passo 2.
4. **MCP Context7**: `export CONTEXT7_API_KEY` deve existir no host (só referência
   `${}` nos arquivos, nunca o valor). Teste funcional: busca de lib deve retornar
   200 com resultados; descartar a resposta. Sem chave, o servidor sobe com cota
   limitada — registrar como pendência, não como falha.
5. **Prova de uso**: executar uma tarefa pequena (ex.: ler `docs/CREATE-PROFILE.md` e
   resumir) sob o ciclo do dispatcher, exigindo Response Contract completo.
6. **Versionar**: cada lapidação = commits atômicos PT-BR em `dev` → suíte 9/9 →
   Certificado de Voo (`test-runner.sh`) → push `dev` → CI verde → fast-forward
   `main` + push (nunca commit direto em `main`).

## 5. Como o `events` usa esta casa (não reverter)

- A cópia `events/plugins/clearer-muse/` foi **removida** (era untracked e idêntica).
- O registro de plugin instalado foi reapontado (com backup) para
  `profiles/clearer-muse` daqui — o `events` consome, não vendoriza.
- O `.mcp.json` do `events` mantém a entrada `context7` (wiring por projeto, com
  `${CONTEXT7_API_KEY}`) — isso é uso, não vestígio.
- Se algum dia o harness precisar de ajuste para o `events`: ajustar AQUI e promover
  por cópia verificada (`diff -r`), nunca editar direto lá.

## 6. Restrições ativas

- Nenhum segredo neste repo (padrão: `sk-*`, `Bearer <token>`, strings 32+ fora de
  `${VAR}`) — varrer antes de cada push.
- PT-BR nos docs; commits `docs|feat|fix` (≤72 chars, sem Co-Authored-By).
- Afirmações técnicas com fonte (arquivo, comando+saída ou teste).
- Lacuna honesta herdada: cota anônima do Context7 (ver CREATE-PROFILE §10); a
  (re)instalação local usa o CLI oficial `muse plugins install|update`
  (via `install.sh`, observado funcionando).

## 7. Pendências herdadas

- [x] Confirmar MCP `context7` operacional pós-restart (passo 4 acima).
  Prova 2026-09-13 pós-restart (OBSERVED, resposta descartada com `shred -u`):
  `initialize` ok; `tools/list` → `resolve-library-id,query-docs`;
  `resolve-library-id{libraryName+query}` → `/reactjs/react.dev` (1746 bytes);
  `query-docs` → 5056 bytes de docs reais. Chave só em shell interativo
  (`len=43`); `~/.bashrc` deduplicado para 1 linha `export` (600). Nota:
  `resolve-library-id` exige AMBOS `libraryName` e `query` (erros de validação
  observados com cada um isolado).
- [x] Versionar evoluções por commit — em dia (ver §9): topologia clássica
  `dev` → `main` publicada no remoto, promoção só por fast-forward.
- [x] Avaliar promoção das skills `systematic-debugging` / `durable-test-collateral`.
  Decisão em `dev` (v0.3.0): `systematic-debugging` vendored como addon opt-in
  `debugging` (corpo fiel, `cmp` OK); `durable-test-collateral` deliberadamente
  externo (bundled, auto-load) — ver guia §11.
- [x] Rotina `diff -r` canônico × instalações — entregue em `dev`:
  `profiles/clearer-muse/scripts/canonical-diff.sh` (exit 0 idêntico,
  1 deriva, 2 destino inválido; validado nos 3 casos).

## 8. Entrega v0.5.0 — 4 governanças CEH (2026-09-20, branch `dev`)

Porte aprovado e implementado em turno único: (1) trava Pre-Push CI Gate +
Certificado de Voo, (2) `RUNTIME_MODE` + `ci-cmd` + dispatch Docker/degradação,
(3) 7 invariantes System One, (4) heartbeat 25s. Smoke-eval F1–F14:
`PASS=15 FAIL=0 WALL=3s` (OBSERVED). Docs: README v0.5.0 + `adr/005`.
Pós-push: `muse plugins update clearer-muse` + restart (ADR-004).

## 9. Lapidação 2026-10-13 — débitos Ponytail + docs (OBSERVED)

Aplicadas as premissas do próprio harness (`code-minimalism`/ponytail,
Risk Dial, fail-closed, veredito calculado), em `dev`:

- Branch `dev` criada com `setup-branches.sh --classic` (o instalador remoto
  e o CI já a esperavam; `staging` removido dos gatilhos do CI).
- `muse-ceh` v0.2.1 versionado e enxugado: só skill + comando + teste
  (−292 linhas de `hooks/`/`scripts/` duplicados do canônico; gate novo em
  `tests/test_manifest.sh` barra a duplicação voltar).
- Documentação sincronizada com a v0.9.0 (15 skills, 16 scripts, evals
  16/16, topologia clássica) e `LICENSE` MIT adicionada.
- Provas: suíte 9/9 exit 0; Certificado de Voo em `9a30c42`
  (`canonical_verified: true`); `evidence-report.sh --strict` exit 0;
  CI do GitHub verde em `dev` (run 38457402693) e em `main` (38457531768)
  após fast-forward, sem force.
- Adiado com gatilho (`ponytail:`): script de re-vendor (procedimento já
  está em `VENDOR.md`), lint novo e ampliação do lexer do safety-gate
  (segurança é exceção ao minimalismo).
- `doc-audit.py` adaptado aos dois layouts: com o plano CEH roda as 7
  checagens originais sem alteração; sem ele, 5 checagens Muse (links,
  vazamentos, commits citados, README×manifestos, orçamento de linhas) e
  exit 2 sem layout algum — verde neste repo, vermelho provado em sandbox.
- Pendente: `muse plugins update muse-ceh` + restart no início da próxima
  sessão (ADR-004) e tarefa-canário do hook único.

## 10. Etapa 3 — CEH v2.1.3 + Ponytail v5 (release v0.11.0)

Execução do plano em `HANDOFF-ETAPA3-ABSORCAO-V213-PONYTAIL-V5.md` (branch
`dev-absorcao-v213-ponytail-v5`), fases com commit atômico e suíte 9/9 entre
elas: Fase 1 `inspect_integrations` validado (`0326eb1`); Fase 2 scripts
v2.1.3 — stub npm ignorado, `docker_service` do config, serviço primário no
detect, 6º check de frontmatter no `doc-audit` (`63bfe57`); Fase 3 re-vendor
p/ `550848a` — drift único em `adapters/antigravity.py`, novo sha
`dc75ccb9…` (`06345b1`); Fase 4 Ponytail v5 — escada de 7 degraus e
`shortcut:` em `clearer-rules` §4, `code-minimalism` referenciando-a,
finding em 4 partes + callers em `clearer-review`, Heurística 12 no
dispatcher (`a60e81b`). Fase 5 é este release; a Fase 6 (certificado,
evidence strict e `plugins update` dos dois profiles) fecha a etapa —
push/promoção seguem exigindo `go` separado.

## 11. Etapa 4 — Abstração v2.3.1 + Orquestração (release v0.12.0)

Plano e registro em `HANDOFF-ETAPA4-ABSTRACAO-V231-ORQUESTRACAO.md`:
abstração em 3 camadas (agnóstica / adapter Muse / Antigravity-only) do
pack CEH v2.3.1 + enhancements v3.5.0 (pin `7318f93`) + benchmark v0.13.0,
decisões D1–D6, fases F-doc→F9 com commit atômico e suíte entre elas.
Estado ao abrir a etapa: local `e3662d0` limpo, 5 commits à frente do
remoto (`ef13379`) — a Etapa 3 segue **não publicada** (D1: push exige
pedido explícito de publicação). Baseline OBSERVED: 9/9 + evals 16/16.
Nota de processo: a análise desta etapa nasceu na sessão de 2026-11-17 e
foi recuperada do log Muse após a perda do checkout — por isso a F-doc
versiona o plano antes de qualquer código.

**Publicada em 2026-11-18** (OBSERVED): promoção clássica `dev` → `main`
por fast-forward até `b4ef665` (16 commits: Etapas 3+4), push liberado
pelo Pre-Push CI Gate com Certificado de Voo do HEAD, CI verde nas duas
branches (runs 44389776562 na `dev` e 44389963878 na `main`, ambas
`success` em `b4ef665`). Veredito pós-promoção: `VERIFICADO` calculado.
Este parágrafo entra em commit docs posterior na `dev` (sem nova promoção
neste ciclo). Pendentes vivos: ver §12 (backlog).

## 12. Backlog (pendências abertas)

- [ ] **Fail-open do dispatcher do enhancements — verificação do
  mantenedor (em casa, host Antigravity).** Achado da F4:
  `hooks/hooks_dispatcher.py` pula o Elo 1 em silêncio se o motor CEH
  falha ao carregar (`main` 0.9.3-p0.1 l. 709; branch `7318f93` 0.9.4
  l. 841; `_SAFETY_GATE_ERROR` nunca é lido; telemetria grava `allow`).
  Classificação: `OBSERVED` por leitura de código, **suspeito de falso
  positivo até reprodução dinâmica**. Detalhe completo (cadeia, impacto,
  correção proposta, par de provas) em
  `HANDOFF-ETAPA4-ABSTRACAO-V231-ORQUESTRACAO.md` §F4; texto de issue
  entregue ao mantenedor (efêmero, fora do repo). Reprodução: sombra
  `hook_context.py` que levanta `ImportError` em cópia sandbox dos
  hooks + payloads benigno/destrutivo — destrutivo em prod precisa
  negar com import quebrado. **Próximo passo:** mantenedor reproduz em
  casa; confirmado → corrige no enhancements (deny nomeado
  `SAFETY GATE UNAVAILABLE`, espelhando o adapter Muse) e dá feedback
  aqui; refutado → registrar a evidência que refuta e fechar o item.
  Impacto neste porte: nenhum (fail-closed provado); a reavaliação do
  `overwrite` mecânico fica travada até este item fechar.
  **Preparado em 2026-11-22:** texto de issue/reprodução regenerado em
  `docs/ISSUE-FAILOPEN-ENHANCEMENTS.md`; aguarda reprodução do
  mantenedor — este item não fecha neste host.
- [ ] **A/B com modelos vivos do roteador shadow** — critério
  pré-registrado em `evals/orchestration/CRITERIA.md` (N≥10/célula,
  0 BLOCKER perdido). Sem esse número, `clearer-orchestration` continua
  só classificando/registrando; nenhuma economia pode ser afirmada.
- [x] **Resíduos da revisão externa Codex (2026-11-19) — ACEITOS**
  por `adr/010-aceitacao-residuos-codex.md` (2026-11-22): certificado
  sem assinatura (confiança local), execução dinâmica além dos padrões
  CC2 e leitura de segredos via shell como limites do gate estático, e
  troca de fonte no `install.sh` só via remove+install. Reabrir exige
  ADR nova com caso concreto reproduzido.
- [x] **Canário formal na sessão nova pós-restart — FECHADO**
  (2026-11-22): sessão `01a201c7` executou os 3 testes com veredito
  OBSERVED PASS 3/3, corroborado no `session.jsonl` dela: teste 1
  `CEH pronto.` isolado; teste 2 seq. 100
  `plugin:clearer-muse:safety-gate:2` com
  `[ELO3-ADVISORY: git log sem limite` na trilha; teste 3 via
  `ceh-dispatch.py` → LOW, `nao-verificado`, sem detect (ressalva
  registrada naquela sessão: pergunta de clarificação e `git status`
  antes do dispatch, sem violar o critério). Debug de origem:
  `pendencia-canario-pos-restart`; lição na KB DevMemory
  (`01a201b9-7299-7043-ade3-009fdb3057bb`).
- [x] **`muse-ceh` no host + restart + tarefa-canário do hook
  único** — pendência herdada do §9. **Parte executada em 2026-11-22:**
  `test_manifest.sh` PASS (v0.2.1, sem hook) e `muse plugins install
  profiles/muse-ceh` (não estava instalado; `update` não se aplicava)
  → `muse-ceh 0.2.1 enabled/active, hooks=0` (sem duplicar o hook do
  `clearer-muse`). **Fechado em 2026-11-22:** restart executado e
  canário na sessão `01a201c7` — todos os hook runs do log são
  `plugin:clearer-muse:safety-gate` (0 de `muse-ceh`), provando o
  hook único sem duplicação.

## 13. Revisão externa Codex — correções v0.12.1

Duas passagens read-only do Muse (delta `ef13379..HEAD` e projeto
inteiro), cada alegação reverificada localmente antes de corrigir.
Corrigidos com teste vermelho→verde: formas executáveis alternativas e
`bash_input` no adapter, crash com comentário puro, execução dinâmica
estreita (CC2 em `VENDOR.md`), caminhos de credencial em ferramentas de
arquivo, máscara/agregador de telemetria, arbitragem do roteador,
`system_one` (migração/path), delimitadores do `git_inspect`,
integrações malformadas/symlink/wrapper `env`, timeout com kill-after,
certificado JSON atômico, consentimento/CRLF/modo em install/uninstall,
CI com permissões mínimas, actions pinadas e E2E de orquestração, e
timeouts de git em `evidence_report`/`doc-audit`.
**Refutados por reprodução:** bypass por `--git-dir`/`--work-tree`,
opções/URL/file de push e “tag antiga libera branch não testada” —
todas as variantes negam; tag antiga isolada é conteúdo certificado.
Veredito e resíduos: ver §12.

## 14. Guarda de contexto — incidente de consumo 2026-11-18 (ADR-008)

Auditoria dos `session.jsonl` provou: a sessão da Etapa 4 fez 367 passos
(39k→442k tok/passo), 98.824.410 input brutos dos quais 98% cache —
custo novo real ~2,18M. Mitigação entregue nesta branch (suíte 9/9):
`scripts/session_cost.py` (métrica oficial `(input−cached)+output` por
modelo, inclui subagentes), `scripts/context-guard.py` (WARN ≥150k/80
passos, BLOCK ≥300k/200 — exit 1/2; BLOCK na sessão do incidente), teto
duro de 16k chars no `compress-output.sh`, regras anti-duplicação de
subagentes (`clearer-orchestration`) e seção “Guarda de contexto” no
`token-economy` + `/token-report`. Decisão e limites: ADR-008.
Pendente original (orientação do mantenedor, 2026-11-19): ativar no host
e recalibrar os limiares com testes reais em sessão nova. **Fechada em
2026-11-22 (ver §15):** ativação no host e recalibração N=10 executadas;
os limiares (150k/300k, 80/200 passos) seguem como heurística do
incidente, sem endurecer — o teto operacional é o `last_input_step`.

## 15. Encerramento v0.13.0 — ativação e recalibração (2026-11-22)

Evolução entregue em `47c0821` (`feat (harness): dispatch sob demanda,
teto de input e Elo3 advisory`, v0.13.0): alias `muse-ceh-yolo` enxuto
nos dois rc (causa do dreno era o prompt imperativo que forçava
detect/preflight na abertura), plugin `clearer-muse` atualizado via
`muse plugins update` com hook `safety-gate` aprovado (hash
`aed1af53`), suíte 9/9 PASS (SCRIPTS-SMOKE 50/50).

Recalibração N=10 (ADR-009 §3): comandos delimitados = 0 advisories;
mediana real/step 27.624 em sessões curtas; teto operacional segue
sendo o `last_input_step` do `context-guard.py` (WARN 150k / BLOCK
300k), não uma média real/step única.

Testes OBSERVED nesta sessão (sessão `01a201a5`, 2026-11-22):

1. Abertura: resposta isolada `CEH pronto.`, sem ferramentas — PASS.
2. `git log --oneline` sem limite: ALLOW sem deny (`exit 0`, 65 linhas,
   `47c0821`…`4de6f7b`); trilha CEH-SAFETY no `session.jsonl` seq. 122
   (`plugin:clearer-muse:safety-gate:2`, `stderr`): `CEH-SAFETY ALLOW
   development :: … [ELO3-ADVISORY: git log sem limite — prefira
   git_inspect.py --limit ou compress-output.sh]` — PASS. Lição: o
   advisory vive no `stderr` do hook gravado no log da sessão, não no
   output da ferramenta devolvido ao modelo.
3. Dispatch LOW `corrigir typo`: nenhum detect executado, ambiente
   `nao-verificado` (via `ceh-dispatch.py`) — PASS.

Veredito dos testes: 3 PASS / 0 FALHA. Nenhuma pendência de
implementação de código permanece nesta evolução; o backlog do §12
(fail-open externo do enhancements, A/B vivo do roteador shadow e
resíduos da revisão Codex) segue aberto como item conhecido e
não-bloqueante. Adiados `ponytail:` do §9 permanecem com gatilho.
