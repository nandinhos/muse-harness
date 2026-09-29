#!/usr/bin/env bash
# test_host_parity.sh — Paridade diff-audit/ceh-help Muse vs Antigravity (CEH v1.3.1).
# H1-H5 pinam o comportamento OBSERVED do porte em 2026-09-28; H6 compara ao vivo
# quando o checkout upstream existe (CEH_UPSTREAM_DIR, default: irmão do repo).
# Deltas deliberados de host (documentados, não gaps):
#   D1: markers => upstream rc=0+WARNING, Muse rc=1+BLOCKER (fail-closed mais forte).
#   D2: fora de repo => upstream rc=1, Muse rc=2 (código próprio p/ erro de infra).
#   D3: ceh-help => conteúdo difere por desenho (aliases agy-* vs scripts do profile).
# Uso: bash profiles/clearer-muse/tests/test_host_parity.sh (cwd: raiz; offline)
set -u

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCR="$ROOT/profiles/clearer-muse/scripts"
UP="${CEH_UPSTREAM_DIR:-$ROOT/../clearer-engineering-harness}/clearer-engineering/scripts"
PASS=0; FAIL=0; FAILED_LIST=""

ok()  { PASS=$((PASS+1)); echo "PASS $1"; }
bad() { FAIL=$((FAIL+1)); FAILED_LIST="$FAILED_LIST $1"; echo "FAIL $1 :: $2"; }

T=$(mktemp -d)
git -C "$T" init -q -b dev
git -C "$T" config user.email t@t.invalid; git -C "$T" config user.name t
git -C "$T" commit -q --allow-empty -m init

# --- H1: repo limpo => rc 0 + CLEAN (igual ao upstream) ---
(cd "$T" && bash "$SCR/diff-audit.sh" >/tmp/hp-h1.out 2>&1); R1=$?
if [[ "$R1" -eq 0 && "$(cat /tmp/hp-h1.out)" == *'Status: CLEAN'* ]]; then ok "H1-clean";
else bad "H1-clean" "rc=$R1 out=[$(head -c 200 /tmp/hp-h1.out)]"; fi

# --- H2: repo sujo => rc 0 + 3 seções + arquivo listado ---
echo x >> "$T/f"; git -C "$T" add f
(cd "$T" && bash "$SCR/diff-audit.sh" >/tmp/hp-h2.out 2>&1); R2=$?; O2="$(cat /tmp/hp-h2.out)"
if [[ "$R2" -eq 0 && "$O2" == *'1. Arquivos'* && "$O2" == *'2. Stat'* && "$O2" == *'3. Whitespace'* \
  && "$O2" == *'f'* ]]; then ok "H2-dirty";
else bad "H2-dirty" "rc=$R2 out=[$(echo "$O2" | head -c 200)]"; fi

# --- H3: markers => rc 1 + BLOCKER (D1: upstream dá 0+WARNING; Muse é fail-closed) ---
printf 'a\n<<<<<<< HEAD\nb\n=======\nc\n>>>>>>> x\n' > "$T/f"
(cd "$T" && bash "$SCR/diff-audit.sh" >/tmp/hp-h3.out 2>&1); R3=$?; O3="$(cat /tmp/hp-h3.out)"
if [[ "$R3" -eq 1 && "$O3" == *'BLOCKER: conflict markers no diff'* ]]; then ok "H3-markers-blocker";
else bad "H3-markers-blocker" "rc=$R3 out=[$(echo "$O3" | head -c 200)]"; fi
rm -rf "$T"

# --- H4: fora de repo => rc 2 + ERROR (D2: upstream dá rc 1) ---
N=$(mktemp -d)
(cd "$N" && bash "$SCR/diff-audit.sh" >/tmp/hp-h4.out 2>&1); R4=$?; O4="$(cat /tmp/hp-h4.out)"
if [[ "$R4" -eq 2 && "$O4" == *'ERROR: fora de repo git'* ]]; then ok "H4-nonrepo";
else bad "H4-nonrepo" "rc=$R4 out=[$(echo "$O4" | head -c 200)]"; fi
rm -rf "$N"

# --- H5: ceh-help do profile => rc 0 + identidade Muse + semântica do gate (D3) ---
bash "$SCR/ceh-help.sh" >/tmp/hp-h5.out 2>&1; R5=$?; O5="$(cat /tmp/hp-h5.out)"
if [[ "$R5" -eq 0 && "$O5" == *'CLEARER Muse Harness'* && "$O5" == *'SCRIPTS DO PROFILE'* \
  && "$O5" == *'DENY'* ]]; then ok "H5-help-muse";
else bad "H5-help-muse" "rc=$R5 out=[$(echo "$O5" | head -c 200)]"; fi

# --- H6: diferencial ao vivo contra o upstream (quando disponível) ---
if [[ -f "$UP/diff-audit.sh" && -f "$UP/ceh-help.sh" ]]; then
  T=$(mktemp -d)
  git -C "$T" init -q -b dev
  git -C "$T" config user.email t@t.invalid; git -C "$T" config user.name t
  git -C "$T" commit -q --allow-empty -m init
  (cd "$T" && bash "$UP/diff-audit.sh" >/dev/null 2>&1); URC=$?
  (cd "$T" && bash "$SCR/diff-audit.sh" >/dev/null 2>&1); MRC=$?
  echo base > "$T/f"; git -C "$T" add f
  printf 'm\n<<<<<<< h\nn\n=======\no\n>>>>>>> x\n' > "$T/f"
  (cd "$T" && bash "$UP/diff-audit.sh" 2>&1 | grep -q "WARNING: Merge conflict markers"); UWG=$?
  (cd "$T" && bash "$SCR/diff-audit.sh" >/dev/null 2>&1); MMK=$?
  N=$(mktemp -d)
  (cd "$N" && bash "$UP/diff-audit.sh" >/dev/null 2>&1); UNR=$?
  (cd "$N" && bash "$SCR/diff-audit.sh" >/dev/null 2>&1); MNR=$?
  bash "$UP/ceh-help.sh" >/dev/null 2>&1; UH=$?
  bash "$SCR/ceh-help.sh" >/dev/null 2>&1; MH=$?
  rm -rf "$T" "$N"
  if [[ "$URC" -eq 0 && "$MRC" -eq 0 && "$UWG" -eq 0 && "$MMK" -eq 1 \
    && "$UNR" -eq 1 && "$MNR" -eq 2 && "$UH" -eq 0 && "$MH" -eq 0 ]]; then ok "H6-live-diff";
  else bad "H6-live-diff" "clean=$URC/$MRC markers_warn=$UWG/muse_rc=$MMK nonrepo=$UNR/$MNR help=$UH/$MH"; fi
else
  ok "H6-live-diff-SKIP"
  echo "(H6: upstream ausente em $UP — só pinado H1-H5)"
fi

rm -f /tmp/hp-h1.out /tmp/hp-h2.out /tmp/hp-h3.out /tmp/hp-h4.out /tmp/hp-h5.out
echo "---"
echo "HOST-PARITY: PASS=$PASS FAIL=$FAIL$([ -n "$FAILED_LIST" ] && echo " [$FAILED_LIST]" || true)"
[[ "$FAIL" -eq 0 ]]
