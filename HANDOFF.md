# HANDOFF — Ativação e lapidação do harness em `muse-harness`

> Para o agente que assumir neste repo. Leia este arquivo primeiro, nesta ordem:
> README → docs/CREATE-PROFILE.md → adr/001 + 002 → este handoff → executar §4.

## 1. Contexto

O profile `clearer-muse` (CLEARER Engineering Harness) nasceu dentro do projeto
`events` (`/home/nandodev/projects/events/plugins/clearer-muse/`) e foi promovido para
casa canônica aqui (`profiles/clearer-muse/`, cópia `diff -r` idêntica). O `events` foi
limpo da cópia vendored e passou a **usar** este canônico (ver §5). Remoto:
`https://github.com/nandinhos/muse-harness.git` (`main`), com tudo publicado.

## 2. Estado atual (verificado)

| Item | Estado |
|---|---|
| `profiles/clearer-muse/` (8 arquivos) | canônico, inclui skills `clearer` (§1–7) + `token-economy`, commands, hook `safety-gate`, scripts, manifest v0.1.0 |
| `docs/CREATE-PROFILE.md` | guia de criação de profile (anatomia, 7 passos, segredos, checklist, riscos) |
| `templates/mcp.json` | base MCP só com `context7` + `${CONTEXT7_API_KEY}` (sem segredo) |
| `adr/001`, `adr/002` | Context7 como endosso; lições como etapa canônica |
| Segredos | varredura limpa em todo o repo; chave real só em `~/.bashrc` do host (600) |
| `events` | sem `plugins/clearer-muse/`; `installed.json` reapontado para cá (ver §5) |

## 3. Objetivo da próxima sessão (lapidação)

Tornar este o único ponto de evolução do harness: ativar o profile daqui, confirmar
MCP `context7` operacional e refinar (candidatos: skills `systematic-debugging` e
`durable-test-collateral` como primeira classe; `git init`-like versionamento por
melhoria; `diff -r` periódico contra cópias).

## 4. Procedimento de ativação (executar nesta ordem)

1. **Sanidade**: `find . -type f | sort` (esperado: 13 arquivos) + `python3 -c
   "json.load(open('profiles/clearer-muse/.muse-plugin/plugin.json')); json.load(open('templates/mcp.json'))"`.
2. **Fonte instalada**: confirmar que a fonte do plugin `clearer-muse` na máquina
   aponta para `/home/nandodev/projects/muse-harness/profiles/clearer-muse`
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
6. **Versionar**: cada lapidação = commit PT-BR neste repo + push `main`.

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
- Lacunas honestas herdadas: comando oficial de (re)instalação de plugin local e cota
  anônima do Context7 (ver CREATE-PROFILE §10).

## 7. Pendências herdadas

- [~] Confirmar MCP `context7` operacional pós-restart (passo 4 acima).
  Status `dev` 2026-09-13 (OBSERVED): chave presente em shell interativo
  (`bash -ic` → `set len=43`, valor nunca impresso); `~/.bashrc` tem 2 linhas
  `export` (última vence — remover a duplicada é opcional, fora do repo).
  Prova funcional plena (busca 200) exige sessão pós-restart — registrar então.
- [x] Versionar evoluções por commit — em dia: 2 commits em `main`
  (`a67f12a`, `4de6f7b`) + branches `dev` / `homologacao` criadas de `main`.
- [ ] Avaliar promoção das skills `systematic-debugging` / `durable-test-collateral`.
  (Em `dev` entrou primeiro `code-minimalism` opt-in, ADR 003.)
- [x] Rotina `diff -r` canônico × instalações — entregue em `dev`:
  `profiles/clearer-muse/scripts/canonical-diff.sh` (exit 0 idêntico,
  1 deriva, 2 destino inválido; validado nos 3 casos).
