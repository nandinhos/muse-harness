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
# --- 7. Runtime & CI Strategy Awareness (RUNTIME_MODE + comandos canonicos do CI) ---
IN_CONTAINER=0; DOCKER_UP=0; ACTIVE_SVC=""
[[ -f /.dockerenv ]] && IN_CONTAINER=1
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  DOCKER_UP=1
  if [[ -f docker-compose.yml || -f docker-compose.yaml || -f compose.yaml || -f compose.yml ]]; then
    ACTIVE_SVC=$(docker compose ps --services --filter "status=running" 2>/dev/null || true)
  fi
fi
if [[ $IN_CONTAINER -eq 1 ]]; then RUNTIME_MODE="IN_CONTAINER";
elif [[ -n "$ACTIVE_SVC" ]]; then RUNTIME_MODE="DOCKER_ACTIVE";
elif [[ -f docker-compose.yml || -f docker-compose.yaml || -f compose.yaml || -f compose.yml ]]; then RUNTIME_MODE="DOCKER_STOPPED";
else RUNTIME_MODE="NATIVE_HOST"; fi
echo "runtime: $RUNTIME_MODE${ACTIVE_SVC:+ ($ACTIVE_SVC)}"
CI_CMDS=$(grep -hE '^[[:space:]]*run:[[:space:]]*.*(test|pest|phpunit|pytest)' .github/workflows/*.yml .github/workflows/*.yaml .gitlab-ci.yml 2>/dev/null | sed -e 's/^[[:space:]]*run:[[:space:]]*//' | sort -u | tr '\n' ';' || true)
[[ -n "$CI_CMDS" ]] && echo "ci-cmd: $CI_CMDS"
if [[ "$RUNTIME_MODE" == "DOCKER_ACTIVE" ]]; then
  echo "local-exec: docker compose exec -T <svc> <cmd> (ou ./vendor/bin/sail test p/ laravel.test)"
elif [[ "$RUNTIME_MODE" == "DOCKER_STOPPED" ]]; then
  echo "local-exec: containers desligados -> host nativo (ou 'docker compose up -d')"
fi
