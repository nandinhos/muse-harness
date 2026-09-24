#!/usr/bin/env bash
# run-all-tests.sh — Agregador canônico da suíte do profile clearer-muse.
# Soma: smoke-eval do gate (evals/run.sh) + contrato CEH-SAFETY + smoke de scripts.
# Emite contagem agregada; exit != 0 em qualquer falha (sem falso-verde).
# Uso: bash profiles/clearer-muse/tests/run-all-tests.sh (cwd: raiz do repo; offline)
set -u

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TDIR="$ROOT/profiles/clearer-muse/tests"
TOTAL_FAIL=0

echo "=== [CEH run-all-tests] $ROOT | $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="

echo "--- [1/3] evals/run.sh (smoke-eval canônico) ---"
if bash "$ROOT/evals/run.sh"; then echo "[PASS] evals/run.sh";
else echo "[FAIL] evals/run.sh"; TOTAL_FAIL=$((TOTAL_FAIL+1)); fi

echo "--- [2/3] test_safety_contract.sh ---"
if bash "$TDIR/test_safety_contract.sh"; then echo "[PASS] safety-contract";
else echo "[FAIL] safety-contract"; TOTAL_FAIL=$((TOTAL_FAIL+1)); fi

echo "--- [3/3] test_scripts_smoke.sh ---"
if bash "$TDIR/test_scripts_smoke.sh"; then echo "[PASS] scripts-smoke";
else echo "[FAIL] scripts-smoke"; TOTAL_FAIL=$((TOTAL_FAIL+1)); fi

echo "==="
if [[ "$TOTAL_FAIL" -eq 0 ]]; then echo "STATUS: PASS (3/3 suítes)"; exit 0;
else echo "STATUS: FAIL ($TOTAL_FAIL/3 suítes com falha)"; exit 1; fi
