#!/usr/bin/env bash
# test-runner.sh — Runner determinístico com contrato auditável (porte de clearer-engineering/scripts/test-runner.sh).
# Uso: bash scripts/test-runner.sh [comando...]   (exit = exit da suíte)
set -u
echo "=== [CEH test-runner] $(date -u +%Y-%m-%dT%H:%M:%SZ) | $PWD ==="
if [[ $# -gt 0 ]]; then CMD="$*";
elif [[ -f vendor/bin/pest ]]; then CMD="./vendor/bin/pest";
elif [[ -f vendor/bin/phpunit || -f phpunit.xml ]]; then CMD="./vendor/bin/phpunit";
elif [[ -f artisan ]]; then CMD="php artisan test";
elif [[ -f package.json ]] && grep -q '"test"' package.json 2>/dev/null; then
  [[ -f pnpm-lock.yaml ]] && CMD="pnpm test" || { [[ -f yarn.lock ]] && CMD="yarn test" || CMD="npm test"; }
elif command -v pytest >/dev/null 2>&1 && [[ -d tests ]]; then CMD="pytest";
elif [[ -f go.mod ]]; then CMD="go test ./...";
else echo "STATUS: NOT RUN (nenhum runner detectado)"; exit 3; fi
echo "COMMAND: $CMD"
set +e; $CMD; CODE=$?; set -e
echo "EXIT CODE: $CODE"
[[ $CODE -eq 0 ]] && echo "STATUS: PASS" || echo "STATUS: FAIL"
exit $CODE
