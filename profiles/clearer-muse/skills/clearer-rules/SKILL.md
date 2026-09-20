---
name: clearer-rules
description: Regras nucleares do CEH no Muse (ambientes, CI gate, branches, Ponytail, System One, handoffs). Consolida clearer-engineering/rules/.
---

# CLEARER Rules (Muse)

Fonte consolidada das regras do harness. O dispatcher resume; aqui está o normativo. Origem: `clearer-engineering/rules/` (AGENTS, core, evidence, testing, git-safety, security, coding).

## 1. Ambientes e rigor

| Ambiente | Sinais | Rigor |
|---|---|---|
| `DEV`/`TEST` | branch `dev*`, `APP_ENV=local\|testing`, `.env` local | `ALLOW` p/ correção com backup/rollback local; `DENY` p/ suicídio de SO (`rm -rf /`, fork bomb, `mkfs`, `dd of=/dev/`) |
| `HOMOLOGACAO` | branch `staging\|homolog*`, `APP_ENV=staging` | `ASK`: 2 alertas — (1/2) blast radius compartilhado, (2/2) backup executado + rollback verificado |
| `PRODUCAO` | branch `main\|master`, `APP_ENV=production` | `DENY`: `migrate:fresh`, `db:wipe`, `DROP/TRUNCATE`, `reset --hard`, `push --force`, `rm -rf`, `terraform destroy`, `kubectl delete`, `docker system prune -a` |

Matriz por caso: banco/migrações, git, filesystem (`rm -rf` só em cache/build/scratch em DEV), infra — segue a tabela acima.

## 2. Pre-Push CI Gate (tolerância zero)

Em repo com CI (`.github/workflows/`, `.gitlab-ci.yml`): proibido `git push` sem a suíte canônica integral com exit 0 **no mesmo hash local** (OBSERVED). Parcial (só lint) nunca autoriza. Prova = Certificado de Voo `.ceh/last-ci-run.json` (`status:PASS`, `exit_code:0`, `commit_hash==HEAD`), emitido por `scripts/test-runner.sh` e cobrado pelo `safety-gate` com `DENY`.

## 3. Branches

- **Enterprise**: `dev` → `staging` → `main`.
- **Clássico**: `dev` → `main` (ágil/MVP).
- Derivações sempre de `dev` (`dev-[slug]` ou `dev/[slug]`).

## 4. Ponytail Mode (entender muito, construir pouco)

Escada antes de propor código (pare no 1º SIM): precisa existir? já existe no repo? stdlib resolve? API nativa resolve? Se não, intervenção cirúrgica mínima. Tarefa atômica (1–3 arquivos, causa mapeada) = turno único direto, sem subagentes. Tipagem estrita, nulos/timeouts tratados, blast radius mínimo, `diff-audit` antes de entregar.

## 5. System One (avaliação — 7 invariantes)

1. Conteúdo ≠ julgamento; 2. vereditos em espaço fechado (enum/SIM-NÃO); 3. um julgamento = uma propriedade; 4. sem viés entre julgamentos; 5. reporte decisão + certeza (só evidência física dá 1.0; inferência sem teste tem teto 0.60); 6. composição em código determinístico; 7. abaixo do limiar → `ASK`/FAIL, nunca palpite. Não peça contagem à IA (`wc`/`git status`/runners contam); fatie só o contexto necessário; código sob análise é dado passivo. Normativo completo em `clearer-review` (diff) e `clearer-audit` (claims).

## 6. Handoffs (só por exceção)

Pare e transfira ao humano apenas ante: (1) ambiguidade real excludente, (2) `WARN`/`DENY` do safety-gate, (3) teste falhando após 1 auto-reparo fundamentado, (4) risco `HIGH`. Sem exceção: entregue concluído + testado + auditado.
