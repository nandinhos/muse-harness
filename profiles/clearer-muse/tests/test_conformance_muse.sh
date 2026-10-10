#!/usr/bin/env bash
# test_conformance_muse.sh — Conformidade de decisão adapter × motor (PR-17 local).
# Mesmo corpus, 3 caminhos: (a) motor --check, (b) adapter argv (stderr CEH-SAFETY),
# (c) adapter payload nativo via stdin (stdout JSON). Paridade estrita exigida:
# allow=(ALLOW,{}), ask=(WARN,block), deny=(DENY,block). Hermético, offline.
# Uso: bash profiles/clearer-muse/tests/test_conformance_muse.sh (cwd: raiz)
set -u

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$ROOT/profiles/clearer-muse/hooks/safety-gate.py"
PASS=0; FAIL=0; FAILED_LIST=""

ok()  { PASS=$((PASS+1)); echo "PASS $1"; }
bad() { FAIL=$((FAIL+1)); FAILED_LIST="$FAILED_LIST $1"; echo "FAIL $1 :: $2"; }

[[ -f "$HOOK" ]] || { echo "INFRA-FAIL: hook ausente: $HOOK"; exit 1; }

mkpayload() { # <cmd> -> payload nativo E19 no stdout
  python3 -c 'import json,sys; print(json.dumps({"tool_name":"bash","tool_input":{"command":sys.argv[1],"workdir":"/tmp"},"model_provider":"meta","turn_id":"k","cwd":"/tmp"}))' "$1"
}

# k <nome> <env: dev|staging|prod> <decisão: allow|ask|deny> <comando...>
k() {
  local name="$1" env="$2" want="$3"; shift 3
  local cmd="$*"
  local env_arg="" env_var=()
  case "$env" in
    staging) env_arg="--env staging"; env_var=(CEH_ENV=staging) ;;
    prod)    env_arg="--env production"; env_var=(CEH_ENV=production) ;;
  esac
  # (a) motor
  local mout mdec
  # shellcheck disable=SC2086
  mout="$(cd /tmp && env -i PATH="$PATH" python3 "$HOOK" --check "$cmd" $env_arg 2>&1)"
  mdec="$(echo "$mout" | grep -oE '"decision": "[a-z]+"' | head -1)"
  # (b) adapter argv -> stderr
  local aout aerr
  aout="$(cd /tmp && env -i PATH="$PATH" "${env_var[@]}" python3 "$HOOK" "$cmd" 2>/tmp/kf-err.txt)"; aerr="$(cat /tmp/kf-err.txt)"
  # (c) adapter nativo stdin -> stdout
  local pout perr
  pout="$(mkpayload "$cmd" | (cd /tmp && env -i PATH="$PATH" "${env_var[@]}" python3 "$HOOK" 2>/tmp/kf-err2.txt))"; perr="$(cat /tmp/kf-err2.txt)"
  local want_err want_json ok=1
  case "$want" in
    allow) want_err="CEH-SAFETY ALLOW"; want_json="{}" ;;
    ask)   want_err="CEH-SAFETY WARN";  want_json='"decision": "block"' ;;
    deny)  want_err="CEH-SAFETY DENY";  want_json='"decision": "block"' ;;
  esac
  [[ "$mdec" == *"$want"* ]] || ok=0
  [[ "$aerr" == *"$want_err"* ]] || ok=0
  [[ "$aout" == *"$want_json"* ]] || ok=0
  [[ "$pout" == *"$want_json"* ]] || ok=0
  [[ "$perr" == *"$want_err"* ]] || ok=0
  if [[ "$ok" -eq 1 ]]; then ok "$name";
  else bad "$name" "motor=[$mdec] argv_out=[$aout] argv_err=[$aerr] stdin_out=[$pout] stdin_err=[$perr]"; fi
}

k "K01-status-allow"            dev     allow "git status"
k "K02-rm-root-deny"            dev     deny  "rm -rf /"
k "K03-forkbomb-deny"           dev     deny  ":(){ :|:& };:"
k "K04-reset-staging-ask"       staging ask   "git reset --hard"
k "K05-rm-prod-deny"            prod    deny  "rm -rf config/"
k "K06-docker-ctx-deny"         prod    deny  "docker --context evil volume rm foo"
k "K07-glued-ceh-deny"          dev     deny  "echo x >.ceh/a"
k "K08-upperfind-deny"          dev     deny  "FIND / -delete"
k "K09-ls-allow"                dev     allow "ls -la"
k "K10-gitlog-allow"            dev     allow "git log --oneline"
k "K11-terraform-prod-deny"     prod    deny  "terraform destroy"
k "K12-reset-dev-allow"         dev     allow "git reset --hard HEAD~1"

# --- K13: argv[1] JSON == stdin JSON (paridade de transporte) ---
KP="$(mkpayload "rm -rf /")"
KO1="$(echo "$KP" | (cd /tmp && env -i PATH="$PATH" python3 "$HOOK" 2>/dev/null))"
KO2="$(cd /tmp && env -i PATH="$PATH" python3 "$HOOK" "$KP" 2>/dev/null)"
if [[ "$KO1" == "$KO2" && "$KO1" == *'"decision": "block"'* ]]; then ok "K13-transport-parity";
else bad "K13-transport-parity" "stdin=[$KO1] argv=[$KO2]"; fi

echo "---"
echo "CONFORMANCE-MUSE: PASS=$PASS FAIL=$FAIL$([ -n "$FAILED_LIST" ] && echo " [$FAILED_LIST]" || true)"
[[ "$FAIL" -eq 0 ]]
