# HANDOFF — Porte fiel CEH Antigravity → `clearer-muse` v0.4.0

> Para o agente que assumir em `/home/nandodev/projects/muse-harness`.
> Leia nesta ordem: este arquivo → `HANDOFF.md` → `docs/CREATE-PROFILE.md`.
> Origem do porte (só-leitura, NÃO mexer): `/home/nandodev/projects/clearer-engineering-harness/clearer-engineering/`.

## 1. O que foi feito (commit `c9325c4`, branch `dev`, NÃO publicado)

`feat (clearer-muse): porta fiel das 9 skills + scripts do CEH Antigravity`
15 arquivos, +566/−5. Manifest `0.3.0` → `0.4.0` (13 skills registradas).

| Entrega | Arquivos |
|---|---|
| 8 skills portadas | `skills/{clearer-feature,clearer-refactor,clearer-review,clearer-test,clearer-audit,clearer-map,clearer-adhd,learned-lesson}/SKILL.md` |
| Regras consolidadas | `skills/clearer-rules/SKILL.md` (env, Pre-Push CI Gate, branches, Ponytail, System One, handoffs) |
| Dispatcher | `skills/clearer/SKILL.md` §5 roteamento real (§§ renumeradas 6→8) |
| Scripts (exec) | `scripts/{detect-project,test-runner,diff-audit}.sh` |
| Comando | `commands/clearer.md` (rotas + test-runner) |

Decisão: bugfix NÃO duplicado — dispatcher roteia `bug → debugging` (equivalente 5 gates já vendored).

## 2. Estado verificado (OBSERVED, tudo exit 0)

- `plugin.json` parseável (13 skills); `bash -n` nos 3 scripts OK.
- `detect-project.sh` rodou real (`development`, branch `dev`); `diff-audit.sh` listou os alterados.
- `bash evals/run.sh` 3× verde (`PASS=9 FAIL=0`, ≤1s; `CRITERIA.md` intocado).
- Segredos: varredura limpa; `git diff --check` OK.

## 3. Pendências (continuar aqui, NÃO no repo Antigravity)

1. `git push` (commit só local; faça após revisar `git show c9325c4 --stat`).
2. Reiniciar a sessão p/ carregar as 9 skills novas (só sobem no boot).
3. Confirmar `source.path` do plugin instalado aponta p/ cá; rodar `scripts/canonical-diff.sh` contra cópias.
4. Fidelidade semântica das skills é INFERRED (inspeção vs CEH); smoke-eval cobre só safety-gate — considerar asserts p/ `test-runner.sh`/`diff-audit.sh`.
5. Próxima ação <2min: `git show c9325c4 --stat && bash evals/run.sh | tail -2`.
