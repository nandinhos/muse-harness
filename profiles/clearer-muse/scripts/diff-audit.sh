#!/usr/bin/env bash
# diff-audit.sh — Auditoria de diff e blast radius (porte de clearer-engineering/scripts/diff-audit.sh).
# Uso: bash scripts/diff-audit.sh   (exit 0 limpo; 1 com markers de conflito)
set -uo pipefail
echo "=== [CEH diff-audit] $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "ERROR: fora de repo git" >&2; exit 2; }
echo "Branch: $(git branch --show-current 2>/dev/null || echo detached)"
[[ -z "$(git status --porcelain)" ]] && { echo "Status: CLEAN"; exit 0; }
echo "--- 1. Arquivos ---"; git status --short
echo "--- 2. Stat ---"; git diff --stat HEAD 2>/dev/null || git diff --stat
echo "--- 3. Whitespace ---"; git diff --check HEAD 2>/dev/null || git diff --check || true
if git diff | grep -qE '^\+?(<<<<<<<|=======|>>>>>>>)'; then
  echo "BLOCKER: conflict markers no diff" >&2; exit 1
fi
echo "OK: sem conflict markers"
