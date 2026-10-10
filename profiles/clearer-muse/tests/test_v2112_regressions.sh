#!/usr/bin/env bash
# test_v2112_regressions.sh — Provas de capacidade CEH v2.1.2 (absorção 0.9.0).
# Cada R-assert é diferencial: FAIL no motor v1.3.1 (matriz RED registrada no
# HANDOFF da absorção) e PASS no motor v2.1.2 vendored. Via --check do motor
# (JSON + exit codes), hermético em mktemp, offline.
# Uso: bash profiles/clearer-muse/tests/test_v2112_regressions.sh (cwd: raiz)
set -u

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$ROOT/profiles/clearer-muse/hooks/safety-gate.py"
VENDOR="$ROOT/profiles/clearer-muse/hooks/vendor/ceh"
PASS=0; FAIL=0; FAILED_LIST=""

ok()  { PASS=$((PASS+1)); echo "PASS $1"; }
bad() { FAIL=$((FAIL+1)); FAILED_LIST="$FAILED_LIST $1"; echo "FAIL $1 :: $2"; }

[[ -f "$HOOK" ]] || { echo "INFRA-FAIL: hook ausente: $HOOK"; exit 1; }

# chk <nome> <exit> <tokens...> -- <args do --check...> (cwd via CHK_CWD)
chk() {
  local name="$1" want_rc="$2"; shift 2
  local toks=() args=() sep=0
  for a in "$@"; do
    if [[ "$a" == "--" ]]; then sep=1; continue; fi
    if [[ "$sep" -eq 0 ]]; then toks+=("$a"); else args+=("$a"); fi
  done
  local out rc ok=1 here="${CHK_CWD:-/tmp}"
  out="$(cd "$here" && env -i PATH="$PATH" ${CHK_ENV:+CEH_ENV="$CHK_ENV"} python3 "$HOOK" "${args[@]}" 2>&1)"; rc=$?
  [[ "$rc" -eq "$want_rc" ]] || ok=0
  for tok in "${toks[@]}"; do [[ "$out" == *"$tok"* ]] || ok=0; done
  if [[ "$ok" -eq 1 ]]; then ok "$name"; else bad "$name" "rc=$rc out=[$(echo "$out" | head -c 250)]"; fi
  unset CHK_CWD CHK_ENV
}

# --- R1 (CA1): redirecionamento colado em .ceh/ = DENY ---
chk "R1-ca1-glued-redirect-deny" 2 '"decision": "deny"' 'G9/AL1' -- \
  --check "echo x >.ceh/a"

# --- R2 (CC2): symlink relativo p/ .ceh/ resolvido contra cwd = DENY ---
T2=$(mktemp -d); mkdir -p "$T2/.ceh"; ln -s .ceh "$T2/link"
CHK_CWD="$T2" chk "R2-cc2-symlink-ceh-deny" 2 '"decision": "deny"' 'G9/AL1' -- \
  --check "echo x > link/a" --cwd "$T2"
rm -rf "$T2"

# --- R3 (H062-B1): docker com flags globais antes do subcomando = DENY em prod ---
CHK_ENV=production chk "R3-docker-globalopts-deny" 2 '"decision": "deny"' 'INFRASTRUCTURE' -- \
  --check "docker --context evil volume rm foo" --env production

# --- R4 (push fail-closed): push.default exótico sem refspec = DENY mesmo com cert válido ---
T4=$(mktemp -d)
git -C "$T4" init -q -b dev 2>/dev/null
git -C "$T4" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init 2>/dev/null
mkdir -p "$T4/.github/workflows" "$T4/.ceh"
printf 'name: ci\non: [push]\njobs:\n  t:\n    runs-on: ubuntu-latest\n    steps:\n      - run: true\n' > "$T4/.github/workflows/ci.yml"
H4=$(git -C "$T4" rev-parse HEAD)
printf '{"commit_hash":"%s","timestamp":"2026-10-10T00:00:00Z","command":"bash evals/run.sh","canonical_verified":true,"status":"PASS","exit_code":0}' "$H4" > "$T4/.ceh/last-ci-run.json"
git -C "$T4" config push.default matching
CHK_CWD="$T4" chk "R4-pushdefault-failclosed-deny" 2 '"decision": "deny"' 'FAIL_CLOSED' -- \
  --check "git push" --cwd "$T4"
rm -rf "$T4"

# --- R5 (F10): rm -rf em arquivo único com -r perde o atalho (staging = ASK) ---
T5=$(mktemp -d); mkdir -p "$T5/rel"; touch "$T5/rel/file.txt"
CHK_CWD="$T5" CHK_ENV=staging chk "R5-rm-recursive-ask" 1 '"decision": "ask"' -- \
  --check "rm -rf rel/file.txt" --env staging --cwd "$T5"
rm -rf "$T5"

# --- R6 (case-insensitive): FIND maiúsculo não evade = DENY catastrófico ---
# (RM -rf / já era bloqueado na v1.3.1; o bypass real era via find/rm dispatch.)
chk "R6-uppercase-find-deny" 2 '"decision": "deny"' 'CATASTROPHIC' -- \
  --check "FIND / -delete"

# --- R7 (redact): segredos e homes redigidos antes de envio externo ---
R7OUT="$(cd /tmp && env -i PATH="$PATH" python3 -c "
import sys; sys.path.insert(0, '$VENDOR')
from ceh_core.redact import redact_payload
print(redact_payload('key=ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdef dir=/home/alice/proj'))
" 2>&1)"; R7RC=$?
if [[ "$R7RC" -eq 0 && "$R7OUT" == *'REDACTED_GIT_TOKEN'* && "$R7OUT" != *'ghp_ABC'* && "$R7OUT" != *'/home/alice'* ]]; then ok "R7-redact-secrets";
else bad "R7-redact-secrets" "rc=$R7RC out=[$R7OUT]"; fi

echo "---"
echo "V2112-REGRESSIONS: PASS=$PASS FAIL=$FAIL$([ -n "$FAILED_LIST" ] && echo " [$FAILED_LIST]" || true)"
[[ "$FAIL" -eq 0 ]]
