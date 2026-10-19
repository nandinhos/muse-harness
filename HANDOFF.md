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
| `profiles/clearer-muse/` (68 arquivos rastreados) | canônico v0.9.0: 15 skills, 2 commands, hook `safety-gate` (adapter sobre o motor CEH v2.1.2 vendorizado em `hooks/vendor/ceh/`), 16 scripts, suíte `tests/` 9/9 |
| `profiles/muse-ceh/` | dispatcher pessoal v0.2.1 (skill + comando + teste, `hooks=0`; ver `HANDOFF-muse-ceh.md`) |
| `docs/CREATE-PROFILE.md` | guia de criação de profile (anatomia, 7 passos, segredos, checklist, riscos) |
| `templates/mcp.json` | base MCP só com `context7` + `${CONTEXT7_API_KEY}` (sem segredo) |
| `adr/001…005` | Context7, lições, minimalismo (ponytail), hook órfão no update, governança CEH |
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
