#!/usr/bin/env bash
# run.sh — smoke-eval do CLEARER Engineering Harness (piloto).
# Executa a TABELA DE DECISÃO real do safety-gate e contratos de exit code.
# Regra do conselho: só tokens estruturados do contrato
# (CEH-SAFETY ALLOW|WARN|DENY <env>, exit codes). Nenhum grep em prosa livre.
# Fail-closed (ADR-004): hook ausente = VERMELHO de infra, nunca verde silencioso.
# Uso: bash evals/run.sh   (cwd: raiz do repo; offline; <60s)
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/profiles/clearer-muse/hooks/safety-gate.py"
DIFFSH="$ROOT/profiles/clearer-muse/scripts/canonical-diff.sh"
PASS=0; FAIL=0; FAILED_LIST=""

# --- fail-closed de infra (deriva A) ---
if [[ ! -x "$HOOK" && ! -f "$HOOK" ]]; then
  echo "INFRA-FAIL: hook ausente ou ilegível: $HOOK (gate silenciosamente ausente é pior que sessão brickada — ADR-004)"
  exit 1
fi

# gate <nome> <env-setup> <comando> <tokens-esperados...>
# env-setup: "prod" | "staging" | "branch" (branch atual do repo, sem overrides)
gate() {
  local name="$1" setup="$2" cmd="$3"; shift 3
  local out rc ok=1
  case "$setup" in
    prod)    out="$(env -i PATH="$PATH" CEH_ENV=production python3 "$HOOK" "$cmd" 2>&1)"; rc=$? ;;
    staging) out="$(env -i PATH="$PATH" CEH_ENV=staging python3 "$HOOK" "$cmd" 2>&1)"; rc=$? ;;
    branch)  out="$(cd "$ROOT" && env -u CEH_ENV -u APP_ENV -u NODE_ENV PATH="$PATH" python3 "$HOOK" "$cmd" 2>&1)"; rc=$? ;;
  esac
  for tok in "$@"; do
    [[ "$out" == *"$tok"* ]] || ok=0
  done
  [[ "$rc" -eq 0 ]] || ok=0
  if [[ "$ok" -eq 1 ]]; then PASS=$((PASS+1)); echo "PASS $name";
  else FAIL=$((FAIL+1)); FAILED_LIST="$FAILED_LIST $name"; echo "FAIL $name :: out=[$out] rc=$rc"; fi
}

START=$SECONDS

# F1: DENY canônico — push --force em produção
gate "F1-deny-push-force-prod" prod "git push --force" \
  "CEH-SAFETY DENY production" "git push --force"
# F2: forma equivalente mantém o veredito (anti-paráfrase maliciosa)
gate "F2-deny-push-f-prod" prod "git push -f origin main" \
  "CEH-SAFETY DENY production"
# F3: catastrófico nega em qualquer ambiente, com motivo estruturado
gate "F3-deny-catastrofico" prod "rm -rf /" \
  "CEH-SAFETY DENY" "bloqueio catastrofico"
# F4: mesmo comando na branch dev (sem override) = ALLOW development + benigno verde
gate "F4-allow-push-force-dev" branch "git push --force" \
  "CEH-SAFETY ALLOW development"
gate "F4b-allow-benigno-dev" branch "git status" \
  "CEH-SAFETY ALLOW development"
# F5: sem comando identificável = fallback estruturado, exit 0
gate "F5-fallback-sem-comando" prod "" \
  "CEH-SAFETY ALLOW production" "sem comando identificavel"
# F6: staging = WARN com os 2 alertas (contrato ASK)
gate "F6-warn-staging" staging "git push --force" \
  "CEH-SAFETY WARN staging" "2 alertas"
# F7: canonical-diff.sh com destino inexistente = exit 2 (contrato de uso)
if "$DIFFSH" /caminho/inexistente-xyz >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); FAILED_LIST="$FAILED_LIST F7-diff-exit2"; echo "FAIL F7-diff-exit2 :: exit 0, esperado 2"
else
  rc=$?
  if [[ "$rc" -eq 2 ]]; then PASS=$((PASS+1)); echo "PASS F7-diff-exit2";
  else FAIL=$((FAIL+1)); FAILED_LIST="$FAILED_LIST F7-diff-exit2"; echo "FAIL F7-diff-exit2 :: exit $rc, esperado 2"; fi
fi
# F8: largura da tabela — migrate:fresh em produção (padrão artisan que nenhum
# gate automatizado atual exercita; barra do agent)
gate "F8-deny-migrate-fresh-prod" prod "php artisan migrate:fresh" \
  "CEH-SAFETY DENY production" "migrate:fresh"

WALL=$((SECONDS-START))
echo "---"
echo "PASS=$PASS FAIL=$FAIL WALL=${WALL}s$([ -n "$FAILED_LIST" ] && echo " FAILED:$FAILED_LIST")"
if [[ "$WALL" -ge 60 ]]; then echo "TETO-FAIL: parede >= 60s"; exit 1; fi
[[ "$FAIL" -eq 0 ]]
