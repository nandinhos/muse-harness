# ADR 005 — Porte das 4 governanças do CEH Antigravity (v0.5.0)

## 1. Contexto

O `clearer-muse` v0.4.0 portou skills e scripts do CEH, mas 4 governanças
validadas na origem ficaram de fora: trava de CI no push, awareness de
runtime/CI, epistemologia System One e heartbeat async (pedido do mantenedor,
sessão `winter-fireball`, 2026-09-20).

## 2. Decisão

1. **Pre-Push CI Gate** (`hooks/safety-gate.py`): `git push` não-force em repo
   com `.github/workflows/` ou `.gitlab-ci.yml` exige `.ceh/last-ci-run.json`
   com `status:PASS`, `exit_code:0` e `commit_hash==HEAD` — senão `DENY`.
   Force push continua na trilha DESTRUCTIVE por ambiente.
2. **Runtime & CI Awareness** (`scripts/detect-project.sh`): emite `runtime:`
   (`NATIVE_HOST|DOCKER_ACTIVE|DOCKER_STOPPED|IN_CONTAINER`) e `ci-cmd:`
   (comandos de teste parseados dos workflows, só leitura).
3. **Dispatch/degradação** (`scripts/test-runner.sh`): containers ativos →
   despacha via Sail/compose; desligados → host nativo com aviso explícito
   (nunca falso-verde). Todo run real emite o Certificado de Voo.
4. **System One** (`clearer-review`, `clearer-audit`, `clearer-rules` §5): 7
   invariantes numerados como normativo; review/audit detalham, rules resume.
5. **Heartbeat** (`scripts/heartbeat.sh`, default 25s): envolve comandos
   async, preserva exit code; uso documentado em `clearer-test`.
6. Evals estendidos F9–F14 (gate sem cert/com cert/obsoleto, `runtime:`,
   certificado emitido, heartbeat). `CRITERIA.md` pré-registrado intocado.

## 3. Consequências

- Push neste repo (sem CI própria) não é afetado pelo gate — verificado:
  `ls .github/workflows` inexistente (OBSERVED).
- Bump do manifest `0.4.0` → `0.5.0`; pós-`plugins update`, restart exigido
  (ADR-004). Smoke-eval: `PASS=15 FAIL=0 WALL=3s` (OBSERVED 2026-09-20).
- Dispatch Sail real segue INFERRED (sem Docker ativo neste host p/ prova física).
