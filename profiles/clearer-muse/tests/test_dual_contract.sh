#!/usr/bin/env bash
# test_dual_contract.sh — Contrato dual do adapter Muse (sonda E19).
# stdout: JSON nativo do runtime ({} allow / {"decision":"block"} deny+ask), exit 0.
# stderr: trilha auditável CEH-SAFETY <ALLOW|WARN|DENY> <env> :: <motivo>.
# Captura SEPARADA por stream (nada de 2>&1): cada assert prova a stream certa.
# Uso: bash profiles/clearer-muse/tests/test_dual_contract.sh (cwd: raiz; offline)
set -u

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$ROOT/profiles/clearer-muse/hooks/safety-gate.py"
PASS=0; FAIL=0; FAILED_LIST=""

ok()  { PASS=$((PASS+1)); echo "PASS $1"; }
bad() { FAIL=$((FAIL+1)); FAILED_LIST="$FAILED_LIST $1"; echo "FAIL $1 :: $2"; }

[[ -f "$HOOK" ]] || { echo "INFRA-FAIL: hook ausente: $HOOK"; exit 1; }

TMPD=$(mktemp -d)
git -C "$TMPD" init -q -b dev 2>/dev/null
git -C "$TMPD" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init 2>/dev/null

# run <nome> <rc> <stdout-tok> <stderr-tok> -- <comando...>  (stdin via STDIN_PAYLOAD)
run() {
  local name="$1" want_rc="$2" want_out="$3" want_err="$4"; shift 4
  [[ "$1" == "--" ]] && shift
  local out err rc ok=1 errf
  errf="$(mktemp)"
  if [[ -n "${STDIN_PAYLOAD:-}" ]]; then
    out="$(printf '%s' "$STDIN_PAYLOAD" | "$@" 2>"$errf")"; rc=$?
  else
    out="$("$@" 2>"$errf")"; rc=$?
  fi
  err="$(cat "$errf")"; rm -f "$errf"
  [[ "$rc" -eq "$want_rc" ]] || ok=0
  [[ "$out" == *"$want_out"* ]] || ok=0
  [[ "$err" == *"$want_err"* ]] || ok=0
  if [[ "$ok" -eq 1 ]]; then ok "$name";
  else bad "$name" "rc=$rc stdout=[$out] stderr=[$err]"; fi
  unset STDIN_PAYLOAD
}

# --- D1/D2/D3: forma argv (legado terminal) é dual ---
run "D1-argv-allow-dual" 0 '{}' 'CEH-SAFETY ALLOW development' -- \
  bash -c "cd \"$TMPD\" && env -u CEH_ENV -u APP_ENV -u NODE_ENV python3 \"$HOOK\" \"git status\""
run "D2-argv-deny-dual" 0 '"decision": "block"' 'CEH-SAFETY DENY' -- \
  bash -c "cd \"$TMPD\" && env -u CEH_ENV -u APP_ENV -u NODE_ENV python3 \"$HOOK\" \"rm -rf /\""
run "D3-argv-warn-dual" 0 '"decision": "block"' 'CEH-SAFETY WARN staging' -- \
  env -i PATH="$PATH" CEH_ENV=staging python3 "$HOOK" "git reset --hard"

# --- D4/D5: payload nativo Muse via stdin (forma E19) ---
STDIN_PAYLOAD='{"tool_name":"bash","tool_input":{"command":"rm -rf /","workdir":"/tmp"},"model_provider":"meta","turn_id":"t","cwd":"/tmp"}' \
run "D4-native-bash-deny" 0 '"decision": "block"' 'CEH-SAFETY DENY' -- \
  env -i PATH="$PATH" python3 "$HOOK"
STDIN_PAYLOAD='{"tool_name":"bash","tool_input":{"command":"git status","workdir":"'"$TMPD"'"},"model_provider":"meta","turn_id":"t","cwd":"'"$TMPD"'"}' \
run "D5-native-bash-allow" 0 '{}' 'CEH-SAFETY ALLOW development' -- \
  env -i PATH="$PATH" python3 "$HOOK"

# --- D6/D7: escrita nativa e ferramenta desconhecida (fail-closed mecânico) ---
STDIN_PAYLOAD='{"tool_name":"write_file","tool_input":{"path":".ceh/x"},"model_provider":"meta","turn_id":"t","cwd":"'"$TMPD"'"}' \
run "D6-native-write-ceh-deny" 0 '"decision": "block"' 'G9' -- \
  env -i PATH="$PATH" python3 "$HOOK"
STDIN_PAYLOAD='{"tool_name":"write_file","tool_input":{"path":"src/app.php"},"model_provider":"meta","turn_id":"t","cwd":"'"$TMPD"'"}' \
run "D6b-native-write-normal-allow" 0 '{}' 'CEH-SAFETY ALLOW' -- \
  env -i PATH="$PATH" python3 "$HOOK"
STDIN_PAYLOAD='{"tool_name":"frobnicate","tool_input":{},"model_provider":"meta","turn_id":"t","cwd":"/tmp"}' \
run "D7-native-unknowntool-block" 0 '"decision": "block"' 'CEH-SAFETY DENY' -- \
  env -i PATH="$PATH" python3 "$HOOK"

# --- D8: legado {command} também é dual ---
STDIN_PAYLOAD='{"command":"git status"}' \
run "D8-legado-dual" 0 '{}' 'CEH-SAFETY ALLOW' -- \
  bash -c "cd \"$TMPD\" && env -u CEH_ENV -u APP_ENV -u NODE_ENV python3 \"$HOOK\""

# --- D10: malformado = block mecânico (o fix E19: antes era só advisory) ---
STDIN_PAYLOAD='{"toolCall": "xx"}' \
run "D10-malformado-block" 0 '"decision": "block"' 'CEH-SAFETY DENY production' -- \
  env -i PATH="$PATH" python3 "$HOOK"

# --- D11/D12 (conselho F4.2): legado fail-closed p/ tipos errados ---
STDIN_PAYLOAD='{"tool_name":"Bash","tool_input":"rm -rf /","cwd":"/tmp"}' \
run "D11-legacy-nondict-block" 0 '"decision": "block"' 'CEH-SAFETY DENY production' -- \
  env -i PATH="$PATH" python3 "$HOOK"
STDIN_PAYLOAD='{"tool_name":"Bash","tool_input":{"command":["rm","-rf","/"]},"cwd":"/tmp"}' \
run "D12-legacy-listcmd-block" 0 '"decision": "block"' 'CEH-SAFETY DENY production' -- \
  env -i PATH="$PATH" python3 "$HOOK"

# --- D13/D14 (conselho F4.2): tráfego real quente (E19: 42% reminder) ---
STDIN_PAYLOAD='{"tool_name":"submit_reminder_decision","tool_input":{"decision":"none"},"model_provider":"meta","turn_id":"t","cwd":"/tmp"}' \
run "D13-reminder-allow" 0 '{}' 'CEH-SAFETY ALLOW' -- \
  env -i PATH="$PATH" python3 "$HOOK"
STDIN_PAYLOAD='{"tool_name":"edit_file","tool_input":{"path":".ceh/x"},"model_provider":"meta","turn_id":"t","cwd":"'"$TMPD"'"}' \
run "D14-edit-ceh-deny" 0 '"decision": "block"' 'G9' -- \
  env -i PATH="$PATH" python3 "$HOOK"

rm -rf "$TMPD"
echo "---"
echo "DUAL-CONTRACT: PASS=$PASS FAIL=$FAIL$([ -n "$FAILED_LIST" ] && echo " [$FAILED_LIST]" || true)"
[[ "$FAIL" -eq 0 ]]
