#!/usr/bin/env bash
# run-all-tests.sh — Agregador canônico da suíte do profile clearer-muse.
# Soma: smoke-eval do gate (evals/run.sh) + contrato CEH-SAFETY + smoke de
# scripts + contrato do motor ceh_core vendored (handoff-060 §6).
# Emite contagem agregada; exit != 0 em qualquer falha (sem falso-verde).
# Uso: bash profiles/clearer-muse/tests/run-all-tests.sh (cwd: raiz do repo; offline)
set -u

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TDIR="$ROOT/profiles/clearer-muse/tests"
TOTAL_FAIL=0

echo "=== [CEH run-all-tests] $ROOT | $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="

echo "--- [1/4] evals/run.sh (smoke-eval canônico) ---"
if bash "$ROOT/evals/run.sh"; then echo "[PASS] evals/run.sh";
else echo "[FAIL] evals/run.sh"; TOTAL_FAIL=$((TOTAL_FAIL+1)); fi

echo "--- [2/4] test_safety_contract.sh ---"
if bash "$TDIR/test_safety_contract.sh"; then echo "[PASS] safety-contract";
else echo "[FAIL] safety-contract"; TOTAL_FAIL=$((TOTAL_FAIL+1)); fi

echo "--- [3/4] test_scripts_smoke.sh ---"
if bash "$TDIR/test_scripts_smoke.sh"; then echo "[PASS] scripts-smoke";
else echo "[FAIL] scripts-smoke"; TOTAL_FAIL=$((TOTAL_FAIL+1)); fi

echo "--- [4/4] test_ceh_core_contract.sh ---"
if bash "$TDIR/test_ceh_core_contract.sh"; then echo "[PASS] ceh-core-contract";
else echo "[FAIL] ceh-core-contract"; TOTAL_FAIL=$((TOTAL_FAIL+1)); fi

echo "==="
if [[ "$TOTAL_FAIL" -eq 0 ]]; then echo "STATUS: PASS (4/4 suítes)"; exit 0;
else echo "STATUS: FAIL ($TOTAL_FAIL/4 suítes com falha)"; exit 1; fi
