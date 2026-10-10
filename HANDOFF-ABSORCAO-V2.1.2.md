# HANDOFF — Absorção CEH v2.1.2 (`muse-harness` v0.9.0, branch `dev-absorcao-ceh-v2.1.2`)

Data: 2026-10-10. Upstream: `antigravity-clearer-engineering-harness` @ `76eaf76`
(`main`, tag v2.1.2). Motor local: v1.3.1 (`6fc5a07`, bundle `6db34ff9…`) →
v2.1.2 (bundle `39db9e70…`, 23 `.py`). Suite: 6/6 → 9/9 PASS.

## Commits (6, ordem de aterrissagem)

| # | Hash | Unidade |
|---|---|---|
| F1 | `7ccb4ba` | re-vendor motor + adapter dual sobre `MuseAdapter` (indivisível) |
| F2.1 | `922eee8` | contrato dual D1–D10 + evidência E19 |
| F2.2 | `b40613d` | 7 provas R1–R7 RED/GREEN |
| F2.3 | `c21958e` | conformidade K01–K13 + H6 vivo |
| F3 | `3448778` | redact no conselho + doc-audit homes |
| F4.1 | este HANDOFF | (este arquivo) |

## Evidências por fase (comando → resultado OBSERVED)

- **F0.1**: `run-all-tests.sh` → 6/6 PASS (baseline pré-trabalho).
- **F0.2 (E19)**: wrapper-passthrough temporário no hook do cache → 12 disparos
  reais (5 bash, 5 submit_reminder_decision, 2 write_file); canário
  `{"decision":"block"}` → `tool blocked by hook` (bash E write_file);
  canário advisory `CEH-SAFETY DENY` → chamada EXECUTADA (gap provado).
  Prova: `docs/temp_implementation/evidence/e19-muse-protocol/` (log redigido
  via `sed` em `session_id`/`tool_use_id`/`turn_id`).
- **F1**: `git archive 76eaf76 … | tar -x` + `diff -r` → VENDOR-SYNC-IDENTICAL;
  suite pós-rewrite → 6/6 PASS de primeira (tokens C2/C3/C11 preservados).
- **F2.1**: `test_dual_contract.sh` → 10/10 (stdout/stderr separados); 7/7.
- **F2.2**: GREEN `7/7` no HEAD × RED `0/7` no clone `/tmp/red-check` @ `b4302e4`
  (bundle `6db34ff9…` conferido); 8/8. Correção honesta no caminho: R6
  planejado (`RM -rf /`) passou no v1.3.1 → trocado por `FIND / -delete`
  (bypass real: old=allow, new=deny CATASTROPHIC).
- **F2.3**: `test_conformance_muse.sh` → 13/13; H6 vivo
  (`CEH_UPSTREAM_DIR=/tmp/ceh-upstream`) → 6/6; 9/9. Correção honesta: K05
  planejado com `/tmp/x` em prod esperava deny, mas `/tmp/` é atalho S1
  seguro por desenho nos dois motores → trocado por `rm -rf config/`.
- **F3**: smoke 12 → 14 (`smoke-conselho-redact` com stub hermético +
  `smoke-docaudit-home-regex`); 9/9.

## Decisões (com motivo)

1. **Re-vendoring integral, não porte seletivo**: novo `hook_context.py`
   removeu 4/5 funções que o adapter importava; retalhar criaria fork divergente.
2. **Contrato dual** (JSON stdout + `CEH-SAFETY` stderr): E19 provou que só o
   JSON impõe; stderr preserva a trilha auditável e os testes antigos (2>&1).
3. **Legados preservados, `toolCall` fail-closed**: payloads `Bash/Write/Edit`
   capitalizados e `{command}` continuam funcionando (C6–C10 verdes); envelope
   antigravity vira block mecânico (era advisory).
4. **`package.py` gerador NÃO adotado**: não carrega D1–D3, legados, evals nem
   doc pt-BR. Reavaliar quando amadurecer.
5. **`evidence_report.py` upstream (6 linhas) NÃO portado**: delta 1/1 local já
   resolve o layout Muse e E15 passa — reuso do que existe (Ponytail).
6. **Ata/pareceres do conselho NÃO redigidos**: escopo upstream PR-21 cobre
   inputs (`prompt_*`, `contexto`); pareceres são evidência do que o modelo disse.

## Desvios do plano (declarados)

- Branch `dev/absorcao-…` impossível (`refs/heads/dev` existe) → `dev-absorcao-ceh-v2.1.2`.
- F0 sem commit próprio: evidência E19 aterrissou com U2.1 (unidade de contrato).
- U2.1 somou testes novos em vez de reescrever os antigos (contrato antigo
  continua pinado via 2>&1; dual pinado com streams separadas). Mesma intenção,
  cobertura maior.
- R6 e K05 corrigidos (expectativa errada, código certo) — detalhe acima.

## Achados (não são gaps do trabalho; pedem decisão sua)

- **F-CERT-01**: `docs/temp_implementation/conselho/` (untracked, pré-existente,
  seu) faz `test-runner.sh` considerar a worktree suja → NENHUM Certificado de
  Voo pode ser emitido até você mover/remover o diretório. Consequência honesta:
  `evidence-report.sh --strict` não atinge VERIFICADO (cobre com
  PARTIALLY_SUPPORTED); a prova por fase é suite exit 0 + log registrado.
  Não mexemos no diretório (é seu) nem afrouxamos o gate (fail-closed é desenho).
- **F-CACHE-01**: o runtime executa o hook do CACHE (`plugins/cache/…`), não do
  `source.path`. Mudanças no repo só valem após reinstall/re-sync do plugin.
  `canonical-diff.sh` compara repo × `source.path` (= ele mesmo) — vacuo nesta
  instalação; o drift real é repo × cache. Follow-up proposto (fora deste plano):
  estender o script p/ comparar também o `cache_path` do `installed.json`.
- **Próximos passos usuais**: `git push` (só após F-CERT-01 resolvido, p/ o gate
  autorizar), reinstall do plugin p/ ativar o adapter novo, merge p/ `dev`.

## Adendo F4.2 — Conselho + mudança de contrato ask→block

- **Banca** (`/tmp/conselho-f42/out/`, trio agy+claude+muse sobre pack de 1104
  linhas): **HOMOLOGADO COM RESSALVAS** — agy HOMOLOGADO 0.98 (reafirmou
  F-CERT-01/F-CACHE-01), claude RESSALVAS 0.85 (sondas próprias no HEAD e no
  clone RED; 7 riscos), muse TIMEOUT.
- **Correções aplicadas** (commit F4.2, pós-banca): (1) legado fail-closed p/
  `tool_input`/`command`/`path` com tipo errado + D11/D12 (bug real: era
  `{}`+ALLOW, agora block); (2) D13 `submit_reminder_decision`→`{}` e D14
  `edit_file`→G9 (tráfego quente pinado); (3) `mktemp` nos err-files dos testes
  (hermeticidade concorrente); (4) `[AVISO CEH: N trechos redigidos]` no topo
  do contexto do conselho quando há substituição; (5) E19 reclassificada:
  lado-hook OBSERVED (log), lado-runtime PARTIALLY_SUPPORTED (transcript).
- **Mudança de contrato declarada**: `ask`→`block` mecânico em staging
  (coerente com upstream E1b; o runtime não tem "perguntar"). Os 2 alertas do
  protocolo passam a valer para ações fora do hook. Skill `clearer` atualizada.
- Total real de asserts novos: 36 (D14 + R7 + K13 + smoke 2), não 30.

## Reprodução

```bash
git checkout dev-absorcao-ceh-v2.1.2
bash profiles/clearer-muse/tests/run-all-tests.sh        # 9/9 PASS
CEH_UPSTREAM_DIR=/tmp/ceh-upstream bash profiles/clearer-muse/tests/test_host_parity.sh  # H6 vivo
# Matriz RED (requer o clone em /tmp/red-check @ b4302e4 + teste copiado):
cd /tmp/red-check && bash profiles/clearer-muse/tests/test_v2112_regressions.sh  # 0/7
```
