#!/usr/bin/env bash
# test_ceh_core_contract.sh — Contrato do motor ceh_core vendored + adapter Muse.
# C1-C4: os 4 smoke tests do handoff-060 §6 via --check (JSON + exit 0/1/2).
# C5-C12: modos do adapter (stdin CEH/legado, G9, CC1, fail-closed). Hermético.
# Uso: bash profiles/clearer-muse/tests/test_ceh_core_contract.sh (cwd: raiz; offline)
set -u

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$ROOT/profiles/clearer-muse/hooks/safety-gate.py"
PASS=0; FAIL=0; FAILED_LIST=""

ok()  { PASS=$((PASS+1)); echo "PASS $1"; }
bad() { FAIL=$((FAIL+1)); FAILED_LIST="$FAILED_LIST $1"; echo "FAIL $1 :: $2"; }

# chk <nome> <exit-esperado> <tokens...> -- <comando...>
chk() {
  local name="$1" want_rc="$2"; shift 2
  local toks=() args=() sep=0
  for a in "$@"; do
    if [[ "$a" == "--" ]]; then sep=1; continue; fi
    if [[ "$sep" -eq 0 ]]; then toks+=("$a"); else args+=("$a"); fi
  done
  local out rc ok=1
  out="$("${args[@]}" 2>&1)"; rc=$?
  [[ "$rc" -eq "$want_rc" ]] || ok=0
  for tok in "${toks[@]}"; do [[ "$out" == *"$tok"* ]] || ok=0; done
  if [[ "$ok" -eq 1 ]]; then ok "$name"; else bad "$name" "rc=$rc out=[$(echo "$out" | head -c 300)]"; fi
}

[[ -f "$HOOK" ]] || { echo "INFRA-FAIL: hook ausente: $HOOK"; exit 1; }

# --- Handoff-060 §6: CLI do motor (JSON + exit codes) ---
chk "C1-benigno-allow" 0 '"decision": "allow"' -- \
  env -i PATH="$PATH" python3 "$HOOK" --check "ls -la"
chk "C2-catastrofico-deny" 2 '"decision": "deny"' 'CATASTROPHIC' -- \
  env -i PATH="$PATH" python3 "$HOOK" --check "rm -rf /"
chk "C3-destrutivo-prod-deny" 2 '"decision": "deny"' 'PRODUCTION LOCK' -- \
  env -i PATH="$PATH" python3 "$HOOK" --check "rm -rf config/" --env production
chk "C5-staging-ask" 1 '"decision": "ask"' -- \
  env -i PATH="$PATH" python3 "$HOOK" --check "git reset --hard" --env staging

# --- C4: push sem certificado em repo com CI = DENY (sandbox hermético) ---
TMPC4=$(mktemp -d)
git -C "$TMPC4" init -q -b dev 2>/dev/null
git -C "$TMPC4" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init 2>/dev/null
mkdir -p "$TMPC4/.github/workflows"
printf 'name: ci\non: [push]\njobs:\n  t:\n    runs-on: ubuntu-latest\n    steps:\n      - run: ./vendor/bin/pest\n' > "$TMPC4/.github/workflows/ci.yml"
C4OUT="$(cd "$TMPC4" && env -i PATH="$PATH" python3 "$HOOK" --check "git push origin dev" 2>&1)"; C4RC=$?
if [[ "$C4OUT" == *'"decision": "deny"'* && "$C4OUT" == *'PRE-PUSH CI GATE'* && "$C4RC" -eq 2 ]]; then ok "C4-push-sem-cert-deny";
else bad "C4-push-sem-cert-deny" "rc=$C4RC out=[$(echo "$C4OUT" | head -c 300)]"; fi
rm -rf "$TMPC4"

# --- Adapter stdin: payload CEH (tool_input) ---
C6OUT="$(echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"},"cwd":"/tmp"}' | env -i PATH="$PATH" python3 "$HOOK" 2>&1)"; C6RC=$?
if [[ "$C6OUT" == *'CEH-SAFETY DENY'* && "$C6RC" -eq 0 ]]; then ok "C6-stdin-ceh-deny";
else bad "C6-stdin-ceh-deny" "rc=$C6RC out=[$C6OUT]"; fi

# --- Adapter stdin: payload legado {command} em repo dev ---
TMPDEV=$(mktemp -d)
git -C "$TMPDEV" init -q -b dev 2>/dev/null
git -C "$TMPDEV" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init 2>/dev/null
C7OUT="$(cd "$TMPDEV" && echo '{"command":"git status"}' | env -i PATH="$PATH" python3 "$HOOK" 2>&1)"; C7RC=$?
if [[ "$C7OUT" == *'CEH-SAFETY ALLOW development'* && "$C7RC" -eq 0 ]]; then ok "C7-stdin-legado-allow";
else bad "C7-stdin-legado-allow" "rc=$C7RC out=[$C7OUT]"; fi
rm -rf "$TMPDEV"

# --- G9: escrita em .ceh/ via ferramenta de arquivo = DENY; fora = ALLOW ---
C8OUT="$(echo '{"tool_name":"Write","tool_input":{"file_path":".ceh/last-ci-run.json"},"cwd":"/tmp"}' | env -i PATH="$PATH" python3 "$HOOK" 2>&1)"; C8RC=$?
if [[ "$C8OUT" == *'CEH-SAFETY DENY'* && "$C8OUT" == *'G9'* && "$C8RC" -eq 0 ]]; then ok "C8-g9-write-cert-deny";
else bad "C8-g9-write-cert-deny" "rc=$C8RC out=[$C8OUT]"; fi
C9OUT="$(echo '{"tool_name":"Edit","tool_input":{"file_path":"src/app.php"},"cwd":"/tmp"}' | env -i PATH="$PATH" python3 "$HOOK" 2>&1)"; C9RC=$?
if [[ "$C9OUT" == *'CEH-SAFETY ALLOW'* && "$C9RC" -eq 0 ]]; then ok "C9-write-normal-allow";
else bad "C9-write-normal-allow" "rc=$C9RC out=[$C9OUT]"; fi

# --- Ferramenta sem comando/alvo extraível = passthrough ALLOW (leituras) ---
C10OUT="$(echo '{"tool_name":"Read","tool_input":{},"cwd":"/tmp"}' | env -i PATH="$PATH" python3 "$HOOK" 2>&1)"; C10RC=$?
if [[ "$C10OUT" == *'CEH-SAFETY ALLOW'* && "$C10RC" -eq 0 ]]; then ok "C10-passthrough-allow";
else bad "C10-passthrough-allow" "rc=$C10RC out=[$C10OUT]"; fi

# --- CC1: fork bomb negado pelo adapter (motor puro permite; ver VENDOR.md) ---
TMPFB=$(mktemp -d)
C11OUT="$(cd "$TMPFB" && env -i PATH="$PATH" python3 "$HOOK" ':(){ :|:& };:' 2>&1)"; C11RC=$?
if [[ "$C11OUT" == *'CEH-SAFETY DENY'* && "$C11OUT" == *'bloqueio catastrofico'* && "$C11RC" -eq 0 ]]; then ok "C11-cc1-forkbomb-deny";
else bad "C11-cc1-forkbomb-deny" "rc=$C11RC out=[$C11OUT]"; fi
rm -rf "$TMPFB"

# --- Payload malformado = fail-closed DENY ---
C12OUT="$(echo '{"toolCall": "xx"}' | env -i PATH="$PATH" python3 "$HOOK" 2>&1)"; C12RC=$?
if [[ "$C12OUT" == *'CEH-SAFETY DENY'* && "$C12RC" -eq 0 ]]; then ok "C12-malformado-deny";
else bad "C12-malformado-deny" "rc=$C12RC out=[$C12OUT]"; fi

echo "---"
echo "CEH-CORE-CONTRACT: PASS=$PASS FAIL=$FAIL$([ -n "$FAILED_LIST" ] && echo " [$FAILED_LIST]" || true)"
[[ "$FAIL" -eq 0 ]]
