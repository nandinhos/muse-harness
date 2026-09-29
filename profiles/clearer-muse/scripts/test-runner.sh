#!/usr/bin/env bash
# test-runner.sh — Runner determinístico com contrato auditável (porte de clearer-engineering/scripts/test-runner.sh).
# Uso: bash scripts/test-runner.sh [comando...]   (exit = exit da suíte)
# - Despacha para Docker/Sail quando containers ativos; degrada p/ host nativo
#   com aviso explícito quando desligados (nunca falso-verde).
# - Emite o Certificado de Voo `.ceh/last-ci-run.json` exigido pelo Pre-Push CI Gate,
#   com `canonical_verified` (comando executado == suíte canônica pinada em
#   `.ceh/config.json` ou detectada). Só a suíte canônica autoriza `git push`.
# - Worktree suja => testes rodam, mas o certificado NÃO é emitido (o cert
#   precisa descrever o commit; fiel ao runner CEH v1.3.1).
# - Copia a saída bruta p/ `.ceh/last-ci-run.log` (D3), citada pelo evidence-report.
set -u
echo "=== [CEH test-runner] $(date -u +%Y-%m-%dT%H:%M:%SZ) | $PWD ==="
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
detect_cmd() {
  if [[ -f vendor/bin/pest ]]; then echo "./vendor/bin/pest";
  elif [[ -f vendor/bin/phpunit || -f phpunit.xml ]]; then echo "./vendor/bin/phpunit";
  elif [[ -f artisan ]]; then echo "php artisan test";
  elif [[ -f package.json ]] && grep -q '"test"' package.json 2>/dev/null; then
    if [[ -f pnpm-lock.yaml ]]; then echo "pnpm test";
    elif [[ -f yarn.lock ]]; then echo "yarn test"; else echo "npm test"; fi
  elif command -v pytest >/dev/null 2>&1 && [[ -d tests ]]; then echo "pytest";
  elif [[ -f go.mod ]]; then echo "go test ./...";
  else echo ""; fi
}
DETECTED_CMD=$(detect_cmd)
# --- Comando canônico: pinado em .ceh/config.json (lido do HEAD) ou detectado ---
CONFIG_CMD=""; CONFIG_OK=1
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [[ -f "$REPO_ROOT/.ceh/config.json" ]]; then
    if git cat-file -e "HEAD:.ceh/config.json" 2>/dev/null && git -C "$REPO_ROOT" diff --quiet HEAD -- .ceh/config.json 2>/dev/null; then
      CONFIG_CMD=$(git -C "$REPO_ROOT" show "HEAD:.ceh/config.json" 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin).get("canonical_test_command",""))' 2>/dev/null) || CONFIG_OK=0
    else CONFIG_OK=0; fi
  elif git cat-file -e "HEAD:.ceh/config.json" 2>/dev/null; then CONFIG_OK=0; fi
elif [[ -f "$REPO_ROOT/.ceh/config.json" ]]; then
  CONFIG_CMD=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("canonical_test_command",""))' "$REPO_ROOT/.ceh/config.json" 2>/dev/null) || CONFIG_OK=0
fi
# Precedência fiel ao CEH: override explícito > pinado no config > detectado.
if [[ $# -gt 0 ]]; then CMD="$*";
elif [[ -n "$CONFIG_CMD" ]]; then CMD="$CONFIG_CMD";
elif [[ -n "$DETECTED_CMD" ]]; then CMD="$DETECTED_CMD";
else echo "STATUS: NOT RUN (nenhum runner detectado)"; exit 3; fi
# --- Runtime adapter: Docker ativo despacha; parado degrada com aviso ---
PRE_DISPATCH_CMD="$CMD"
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
# --- Verificação canônica (comparação, não inspeção; fiel ao CEH PR-08) ---
CANONICAL_CMD="${CONFIG_CMD:-$DETECTED_CMD}"
CLEAN_RUN=$(echo "$PRE_DISPATCH_CMD" | sed -E 's/^[[:space:]]*rtk([[:space:]]+proxy)?[[:space:]]+//')
CANONICAL_VERIFIED=false
if [[ $CONFIG_OK -eq 0 ]]; then
  echo "[CEH WARNING] .ceh/config.json ausente do HEAD ou modificado. Este comando NÃO concederá certificado válido para git push."
elif [[ -n "$CANONICAL_CMD" && "$CLEAN_RUN" == "$CANONICAL_CMD" ]]; then
  CANONICAL_VERIFIED=true
else
  echo "[CEH WARNING] O comando '$PRE_DISPATCH_CMD' difere da suíte canônica ('${CANONICAL_CMD:-não detectada}')."
  echo "[CEH WARNING] Este comando NÃO concederá certificado válido de liberação para git push."
fi
# --- Worktree precisa estar limpa para o cert descrever o commit ---
WORKTREE_DIRTY=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  DIRTY_FILES=$(git -C "$REPO_ROOT" status --porcelain -- ':(top)' ':(top,exclude).ceh/last-ci-run.json' ':(top,exclude).ceh/last-ci-run.log' 2>/dev/null)
  if [[ -n "$DIRTY_FILES" ]]; then
    WORKTREE_DIRTY=1
    echo "[CEH WARNING] Worktree com alterações não commitadas. Os testes rodam, mas o certificado NÃO será emitido."
  fi
fi
echo "COMMAND: $CMD"
OUTPUT_FILE=$(mktemp)
set +e; $CMD >"$OUTPUT_FILE" 2>&1; CODE=$?; set -e
cat "$OUTPUT_FILE"
echo "EXIT CODE: $CODE"
[[ $CODE -eq 0 ]] && echo "STATUS: PASS" || echo "STATUS: FAIL"
# --- Certificado de Voo p/ o Pre-Push CI Gate (commit exato + exit 0 + canônico) ---
if [[ $WORKTREE_DIRTY -eq 0 ]] && mkdir -p "$REPO_ROOT/.ceh" 2>/dev/null && [[ -d "$REPO_ROOT/.ceh" ]]; then
  COMMIT=$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "untracked")
  STATUS="FAIL"; [[ $CODE -eq 0 ]] && STATUS="PASS"
  cat > "$REPO_ROOT/.ceh/last-ci-run.json" <<EOF
{
  "commit_hash": "$COMMIT",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "command": "$CMD",
  "canonical_verified": $CANONICAL_VERIFIED,
  "status": "$STATUS",
  "exit_code": $CODE
}
EOF
  cp "$OUTPUT_FILE" "$REPO_ROOT/.ceh/last-ci-run.log"  # D3: saída bruta citada pelo evidence-report
fi
rm -f "$OUTPUT_FILE"
exit $CODE
