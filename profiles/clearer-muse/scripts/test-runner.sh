#!/usr/bin/env bash
# test-runner.sh — Runner determinístico com contrato auditável (porte de clearer-engineering/scripts/test-runner.sh).
# Uso: bash scripts/test-runner.sh [comando...]   (exit = exit da suíte)
# - Despacha para Docker/Sail quando containers ativos; degrada p/ host nativo
#   com aviso explícito quando desligados (nunca falso-verde).
# - Emite o Certificado de Voo `.ceh/last-ci-run.json` exigido pelo Pre-Push CI Gate.
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
# --- Runtime adapter: Docker ativo despacha; parado degrada com aviso ---
ACTIVE_SERVICES=""
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  if [[ -f docker-compose.yml || -f docker-compose.yaml || -f compose.yaml || -f compose.yml ]]; then
    ACTIVE_SERVICES=$(docker compose ps --services --filter "status=running" 2>/dev/null || true)
  fi
fi
if [[ -n "$ACTIVE_SERVICES" ]]; then
  if [[ ! "$CMD" =~ (docker|docker-compose|sail) ]]; then
    if [[ " $ACTIVE_SERVICES " =~ " laravel.test " ]]; then
      if [[ -f vendor/bin/sail ]]; then CMD="./vendor/bin/sail test";
      else CMD="docker compose exec -T laravel.test $CMD"; fi
    elif [[ " $ACTIVE_SERVICES " =~ " app " ]]; then
      CMD="docker compose exec -T app $CMD";
    else FIRST=$(echo "$ACTIVE_SERVICES" | head -n 1); CMD="docker compose exec -T $FIRST $CMD"; fi
    echo "[CEH RUNTIME ADAPTER] containers ativos -> despachando via Docker ($CMD)"
  fi
elif [[ -f docker-compose.yml || -f docker-compose.yaml || -f compose.yaml || -f compose.yml ]]; then
  echo "[CEH RUNTIME ADAPTER] containers desligados -> executando no host nativo (degradacao explicita, sem falso-verde)"
fi
echo "COMMAND: $CMD"
set +e; $CMD; CODE=$?; set -e
echo "EXIT CODE: $CODE"
[[ $CODE -eq 0 ]] && echo "STATUS: PASS" || echo "STATUS: FAIL"
# --- Certificado de Voo p/ o Pre-Push CI Gate (commit exato + exit 0) ---
if mkdir -p .ceh 2>/dev/null && [[ -d .ceh ]]; then
  COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "untracked")
  STATUS="FAIL"; [[ $CODE -eq 0 ]] && STATUS="PASS"
  cat > .ceh/last-ci-run.json <<EOF
{
  "commit_hash": "$COMMIT",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "command": "$CMD",
  "status": "$STATUS",
  "exit_code": $CODE
}
EOF
fi
exit $CODE
