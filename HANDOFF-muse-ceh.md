# HANDOFF — Perfil `muse-ceh` (continuidade em `/home/gacpac/projects/muse-harness`)

> **Atualização 2026-10-13 (v0.2.0, coexistência com hook único):** repo `muse-harness` sincronizado com o oficial em `acd0707` (`clearer-muse` 0.9.0, motor CEH v2.1.2 vendorizado, suíte 9/9). Plugin `clearer-muse` 0.9.0 instalado user-scope com hook `safety-gate` aprovado (`trusted_enabled`) e provado via `muse plugins hook test` (allow `{}` / block mecânico `rm -rf /`, bundle do cache `39db9e70…` idêntico ao `VENDOR.md`). O hook antigo do `muse-ceh` foi desativado (`reject` → `trusted_disabled`) e removido do manifesto: `muse-ceh` **0.2.0** é só dispatcher (skill + comando, `hooks=0`, instalado via `muse plugins update`), com a sonda `SAFE_DEV` registrada na skill (`rm -rf` em `logs/`, `anexosauti/`, `gmmpdf/`, `docpdf/`, `downloads/` = allow em DEV, deny em produção no motor novo). Teste do perfil: `bash profiles/muse-ceh/tests/test_manifest.sh`. Pendente: restart da sessão p/ carregar as 15 skills do `clearer-muse` + tarefa-canário; `muse-ceh` versionado neste repo desde a v0.2.1 (decisão do usuário; perfil enxuto, sem `hooks/` nem `scripts/` duplicados do canônico). Rollback: `muse plugins remove clearer-muse` + restaurar o hook no manifesto do `muse-ceh` (arquivo `hooks/safety-gate.py` removido na v0.2.1; recuperar da ref local `refs/tbh/recovery/before-discard/20261013T191608Z-84686`) + `update` + `approve muse-ceh:hook:safety-gate`.

> **Atualização 2026-09-29:** renomeado `skynet-clearer` → `muse-ceh` (decisão do usuário: é o profile do Muse; skynet-v2 desconsiderado). Plugin antigo removido, `muse-ceh` instalado user-scope + hook aprovado, aliases `muse-ceh`/`muse-ceh-yolo` no `~/.bashrc`. Pendente: restart + prova viva + commit.

> Para o agente que assumir na pasta do projeto. Ordem de leitura:
> `README.md` → `docs/CREATE-PROFILE.md` → este handoff → executar §4.

## 1. Contexto

Sessão anterior (root `skynet-v2-1`) analisou o
`antigravity-clearer-engineering-harness` e desenhou um perfil personalizado
(Fernando). O usuário corrigiu o escopo: o perfil pertence ao repo
[`muse-harness`](https://github.com/nandinhos/muse-harness.git) (casa canônica dos
profiles do Muse Code), como perfil irmão do `clearer-muse`, e NÃO ao skynet.
Nada foi escrito no skynet. Todo o trabalho está neste clone sandbox em `/tmp`
(não copiar nada de/para o skynet).

## 2. Estado atual (verificado)

| Item | Estado |
|---|---|
| Clone | `/tmp/muse-harness`, `git clone --depth 1`, commit `f39c1366106c34b1c82e89e4e99ea26dd73e9ff2`, branch `main` |
| `profiles/muse-ceh/` (7 arquivos, **untracked**) | manifest `muse-ceh` v0.1.0 (`schemaVersion: 1`), skill `muse-ceh` (dispatcher PT-BR), comando `muse-ceh-run`, hook `safety-gate.py`, scripts `compress-output.sh`/`token-budget.py`/`canonical-diff.sh` |
| Fidelidade | Hook e scripts portados do `clearer-muse` com cabeçalho de proveniência; únicas mudanças no gate: docstring + `SAFE_DEV` (`logs/`, `anexosauti/`, `gmmpdf/`, `docpdf/`, `downloads/`); regras `DESTRUCTIVE` intactas |
| Decisão de escopo | Regras de negócio do skynet (ex.: `FinancialCalculator`) ficaram FORA, conforme `CREATE-PROFILE.md` §3 — o perfil carrega só metodologia + rigor por ambiente + âncoras de stack |
| Destino | `/home/gacpac/projects/muse-harness/` existe e está **vazia**; sessão anterior não tem escrita lá (sandbox read-only) |

## 3. Validação já executada (evidência)

- `json.load` do `plugin.json`: OK (`muse-ceh` v0.1.0); todos os paths de skills/commands resolvem.
- `py_compile` no hook e `token-budget.py`: exit 0. `bash -n` nos 3 scripts: exit 0.
- Gate funcional: `echo hello` → `CEH-SAFETY ALLOW`; `rm -rf /` → `DENY`; `git push --force origin main` → `DENY` (detectou branch `main`; fail-closed correto).
- Varredura de segredos (`sk-*`, `Bearer`) em `profiles/muse-ceh/`: limpa.
- `git status`: só `?? profiles/muse-ceh/`. Nenhum commit feito (aguardando decisão do usuário).

## 4. Próximos passos (executar nesta ordem)

1. **Levar para o destino** (o agente desta sessão não escreve fora do sandbox — rodar no terminal do usuário):
   `cp -r /tmp/muse-harness/. /home/gacpac/projects/muse-harness/ && ls /home/gacpac/projects/muse-harness/profiles/`
2. **Reabrir a sessão com root em `/home/gacpac/projects/muse-harness`** (pré-requisito p/ editar, registrar plugin e commitar).
3. **Sanidade** (guia §7): `find profiles/muse-ceh -type f | sort` (esperado: 7 arquivos) + `python3 -c "import json; json.load(open('profiles/muse-ceh/.muse-plugin/plugin.json'))"`.
4. **Registrar a fonte instalada** apontando para `profiles/muse-ceh` e **reiniciar a sessão** (skills/MCP só sobem no boot; ver HANDOFF.md §4 do repo).
5. **Prova viva**: no 1º turno pós-restart, a skill `muse-ceh` deve declarar ambiente + Risk Dial sem ser perguntada; rodar tarefa pequena exigindo Response Contract completo.
6. **Versionar**: commit PT-BR (`feat(profile): adiciona muse-ceh v0.1.0`, ≤72 chars, sem `Co-Authored-By`) + push `main` (varrer segredos antes, regra do repo).

## 5. Pendências e riscos conhecidos

- [x] Aliases `muse-ceh` (`muse`) / `muse-ceh-yolo` (`muse --yolo`) criados no `~/.bashrc` em 2026-09-29 (aprovado pelo usuário; paridade com `agy-ceh`, sem `--agent` no Muse).
- Fase B do plano original (vendorizar `ceh_core/`, `PreToolUse` em `.claude/hooks.json`) NÃO foi feita — decidir se entra neste repo ou morre aqui.
- `README.md` e `HANDOFF.md` do repo NÃO foram alterados (adicionar linha do novo perfil é decisão do usuário).
