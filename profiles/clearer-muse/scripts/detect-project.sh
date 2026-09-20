#!/usr/bin/env bash
# detect-project.sh — Detector de stack e ambiente (porte de clearer-engineering/scripts/detect-project.sh).
# Uso: bash scripts/detect-project.sh [dir]   (exit sempre 0; só leitura)
set -u
TARGET="${1:-$(pwd)}"
cd "$TARGET" || { echo "ERRO: dir inexistente: $TARGET" >&2; exit 2; }

ENV="development"; EVID="fallback (workspace local)"
for var in CEH_ENV APP_ENV NODE_ENV; do
  if [[ -n "${!var:-}" ]]; then
    v=$(echo "${!var}" | tr '[:upper:]' '[:lower:]')
    case "$v" in
      *prod*|*live*) ENV="production"; EVID="$var=${!var}" ;;
      *stag*|*homolog*|*uat*|*qa*) ENV="staging"; EVID="$var=${!var}" ;;
      *) ENV="development"; EVID="$var=${!var}" ;;
    esac
    break
  fi
done
BRANCH=$(git branch --show-current 2>/dev/null || echo "no-git")
[[ "$BRANCH" == main || "$BRANCH" == master ]] && [[ "$ENV" == "development" ]] && { ENV="production"; EVID="branch $BRANCH"; }
[[ "$BRANCH" == staging || "$BRANCH" == homolog* ]] && [[ "$ENV" == "development" ]] && { ENV="staging"; EVID="branch $BRANCH"; }

echo "=== [CEH detect-project] $TARGET ==="
echo "env: $ENV ($EVID) | branch: $BRANCH"
[[ -f composer.json ]] && echo "stack: php $(grep -o '"php": *"[^"]*"' composer.json 2>/dev/null | head -1) | pest: $([[ -f vendor/bin/pest ]] && echo yes || echo no) | artisan: $([[ -f artisan ]] && echo yes || echo no)"
[[ -f package.json ]] && echo "stack: node | test-script: $(grep -c '"test"' package.json 2>/dev/null)"
[[ -f pyproject.toml || -f requirements.txt ]] && echo "stack: python | pytest: $(command -v pytest >/dev/null 2>&1 && echo yes || echo no)"
[[ -f go.mod ]] && echo "stack: go"
[[ -d .github/workflows ]] && echo "ci: ${PWD}/.github/workflows ($(ls .github/workflows | tr '\n' ' '))"
echo "tests-dir: $([[ -d tests ]] && echo yes || echo no)"
