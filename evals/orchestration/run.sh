#!/usr/bin/env bash
# run.sh — E2E da orquestracao por tiers (criterio pre-registrado em CRITERIA.md).
# Uso: bash evals/orchestration/run.sh   (offline; exit 0 = APROVA)
set -u
exec python3 "$(cd "$(dirname "$0")" && pwd)/run_eval.py" "$@"
