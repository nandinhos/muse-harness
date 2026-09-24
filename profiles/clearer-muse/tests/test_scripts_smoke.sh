#!/usr/bin/env bash
# test_scripts_smoke.sh — Smoke dos scripts portados do CEH (Fase 3).
# Garante que cada script executa com exit esperado sem efeitos no repo:
# topologias de branch rodam em sandbox /tmp; doc-audit deve falhar fechado
# (exit != 0) sem plano CEH; conselho roda só --list-available/--dry-run.
# Uso: bash profiles/clearer-muse/tests/test_scripts_smoke.sh (cwd: raiz do repo; offline)
set -u

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCR="$ROOT/profiles/clearer-muse/scripts"
PASS=0; FAIL=0; FAILED_LIST=""

ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
bad()  { FAIL=$((FAIL+1)); FAILED_LIST="$FAILED_LIST $1"; echo "FAIL $1 :: $2"; }

run_ok() { # <nome> <comando...>
  local name="$1"; shift
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [[ "$rc" -eq 0 ]]; then ok "$name"; else bad "$name" "rc=$rc out=[$(echo "$out" | head -c 200)]"; fi
}

# --- Scripts read-only devem sair 0 ---
run_ok "smoke-detect"    bash "$SCR/detect-project.sh" "$ROOT"
run_ok "smoke-preflight" bash "$SCR/preflight.sh"
run_ok "smoke-ceh-help"  bash "$SCR/ceh-help.sh"
run_ok "smoke-monitor"   bash "$SCR/task-monitor.sh"
run_ok "smoke-evidence"  bash "$SCR/evidence-report.sh"
run_ok "smoke-diff-audit" bash "$SCR/diff-audit.sh"
run_ok "smoke-gate-probe" python3 "$ROOT/profiles/clearer-muse/hooks/safety-gate.py" "git status"

# --- conselho: só modos seguros (sem invocar CLIs) ---
if bash "$SCR/conselho-seniores.sh" --list-available 2>&1 | grep -q "Quórum"; then
  ok "smoke-conselho-list"
else
  bad "smoke-conselho-list" "sem linha de quórum"
fi

# --- setup-branches em sandbox isolado (nunca no repo real) ---
for mode in --enterprise --classic; do
  TMP="$(mktemp -d)"
  git -C "$TMP" init -b main -q
  git -C "$TMP" config user.name T
  git -C "$TMP" config user.email t@t.l
  touch "$TMP/f"; git -C "$TMP" add f; git -C "$TMP" commit -qm i
  if bash "$SCR/setup-branches.sh" "$mode" "$TMP" >/dev/null 2>&1 \
     && git -C "$TMP" show-ref --verify --quiet refs/heads/dev; then
    if [[ "$mode" == "--enterprise" ]]; then
      git -C "$TMP" show-ref --verify --quiet refs/heads/staging \
        && ok "smoke-branches-enterprise" || bad "smoke-branches-enterprise" "sem staging"
    else
      git -C "$TMP" show-ref --verify --quiet refs/heads/staging \
        && bad "smoke-branches-classic" "staging inesperada" || ok "smoke-branches-classic"
    fi
  else
    bad "smoke-branches-${mode#--}" "setup falhou"
  fi
  rm -rf "$TMP"
done

# --- doc-audit: fail-closed sem plano CEH (exit != 0 é o PASS aqui) ---
if bash "$SCR/doc-audit.sh" >/dev/null 2>&1; then
  bad "smoke-doc-audit-failclosed" "saiu 0 sem plano (falso-verde)"
else
  ok "smoke-doc-audit-failclosed"
fi

# --- doc-audit resolve a raiz do repo (não profiles/) ---
if bash "$SCR/doc-audit.sh" 2>&1 | grep -q "Repositório: $ROOT$"; then
  ok "smoke-doc-audit-root"
else
  bad "smoke-doc-audit-root" "raiz incorreta"
fi

echo "---"
echo "SCRIPTS-SMOKE: PASS=$PASS FAIL=$FAIL$([ -n "$FAILED_LIST" ] && echo " [$FAILED_LIST]" || true)"
[[ "$FAIL" -eq 0 ]]
