#!/usr/bin/env bash
# test_safety_contract.sh — Contrato CEH-SAFETY do safety-gate do profile.
# Porte ADAPTADO da safety matrix upstream: o gate Muse difere do Antigravity —
# sempre sai com exit 0 (consultivo) e emite UMA linha de veredito:
#   CEH-SAFETY <ALLOW|WARN|DENY> <ambiente> :: <motivo>
# Cada assert confere veredito + ambiente + exit 0 (falha silenciosa = FAIL).
# Uso: bash profiles/clearer-muse/tests/test_safety_contract.sh (cwd: raiz do repo; offline)
set -u

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$ROOT/profiles/clearer-muse/hooks/safety-gate.py"
PASS=0; FAIL=0; FAILED_LIST=""

# check <nome> <setup> <comando> <tokens...>
# setup: dev | staging | prod  (isola CEH_ENV/APP_ENV/NODE_ENV do chamador)
check() {
  local name="$1" setup="$2" cmd="$3"; shift 3
  local out rc ok=1
  case "$setup" in
    prod)    out="$(env -i PATH="$PATH" CEH_ENV=production python3 "$HOOK" "$cmd" 2>&1)"; rc=$? ;;
    staging) out="$(env -i PATH="$PATH" CEH_ENV=staging python3 "$HOOK" "$cmd" 2>&1)"; rc=$? ;;
    dev)     out="$(env -u CEH_ENV -u APP_ENV -u NODE_ENV PATH="$PATH" python3 "$HOOK" "$cmd" 2>&1)"; rc=$? ;;
  esac
  for tok in "$@"; do
    [[ "$out" == *"$tok"* ]] || ok=0
  done
  [[ "$rc" -eq 0 ]] || ok=0
  if [[ "$ok" -eq 1 ]]; then PASS=$((PASS+1)); echo "PASS $name";
  else FAIL=$((FAIL+1)); FAILED_LIST="$FAILED_LIST $name"; echo "FAIL $name :: out=[$out] rc=$rc"; fi
}

[[ -f "$HOOK" ]] || { echo "INFRA-FAIL: hook ausente: $HOOK"; exit 1; }

# --- DEV: liberdade com salvaguarda local ---
check "dev-safe-status"            dev "git status"                "CEH-SAFETY ALLOW" "development"
check "dev-scratch-cleanup"        dev "rm -rf scratch/temp"       "CEH-SAFETY ALLOW" "development"
check "dev-reset-hard-allow"       dev "git reset --hard HEAD~1"   "CEH-SAFETY ALLOW" "development"

# --- CATASTRÓFICO: DENY absoluto em qualquer ambiente ---
check "dev-catastrofico-rm-root"     dev "rm -rf /"           "CEH-SAFETY DENY" "bloqueio catastrofico"
check "staging-catastrofico-rm-root" staging "rm -rf /"       "CEH-SAFETY DENY" "bloqueio catastrofico"
check "prod-catastrofico-fork"       prod ':(){ :|:& };:'     "CEH-SAFETY DENY" "bloqueio catastrofico"
check "dev-catastrofico-fork"        dev ':(){ :|:& };:'      "CEH-SAFETY DENY" "bloqueio catastrofico"

# --- PRODUÇÃO: destrutivos bloqueados ---
check "prod-push-force"      prod "git push --force"         "CEH-SAFETY DENY" "production"
check "prod-migrate-fresh"   prod "php artisan migrate:fresh" "CEH-SAFETY DENY" "production"

# --- STAGING: destrutivo não-catastrófico exige 2 alertas ---
check "staging-reset-hard"  staging "git reset --hard HEAD~1" "CEH-SAFETY WARN" "staging" "1/2" "2/2"
check "staging-push-force"  staging "git push --force"        "CEH-SAFETY WARN" "staging" "1/2" "2/2"

# --- Imunidade a evasão via prefixo rtk ---
check "rtk-evasion-prod"  prod "rtk git push --force" "CEH-SAFETY DENY" "production"
check "rtk-safe"          dev "rtk git status"        "CEH-SAFETY ALLOW" "development"

echo "---"
echo "SAFETY-CONTRACT: PASS=$PASS FAIL=$FAIL$([ -n "$FAILED_LIST" ] && echo " [$FAILED_LIST]" || true)"
[[ "$FAIL" -eq 0 ]]
