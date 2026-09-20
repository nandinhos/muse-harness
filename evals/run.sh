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

# F9: Pre-Push CI Gate — push sem certificado em repo com CI = DENY
TMPREP=$(mktemp -d)
git -C "$TMPREP" init -q 2>/dev/null
git -C "$TMPREP" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init 2>/dev/null
mkdir -p "$TMPREP/.github/workflows"
printf 'name: ci\non: [push]\njobs:\n  t:\n    runs-on: ubuntu-latest\n    steps:\n      - run: ./vendor/bin/pest\n' > "$TMPREP/.github/workflows/ci.yml"
F9OUT="$(cd "$TMPREP" && env -i PATH="$PATH" python3 "$HOOK" "git push origin dev" 2>&1)"; F9RC=$?
if [[ "$F9OUT" == *"CEH-SAFETY DENY"* && "$F9OUT" == *"PRE-PUSH CI GATE"* && "$F9RC" -eq 0 ]]; then PASS=$((PASS+1)); echo "PASS F9-deny-push-sem-cert";
else FAIL=$((FAIL+1)); FAILED_LIST="$FAILED_LIST F9-deny-push-sem-cert"; echo "FAIL F9-deny-push-sem-cert :: out=[$F9OUT] rc=$F9RC"; fi
# F10: certificado valido no HEAD = ALLOW
HEADH=$(git -C "$TMPREP" rev-parse HEAD 2>/dev/null)
mkdir -p "$TMPREP/.ceh"
printf '{"commit_hash": "%s", "timestamp": "2026-01-01T00:00:00Z", "command": "./vendor/bin/pest", "status": "PASS", "exit_code": 0}' "$HEADH" > "$TMPREP/.ceh/last-ci-run.json"
F10OUT="$(cd "$TMPREP" && env -i PATH="$PATH" python3 "$HOOK" "git push origin dev" 2>&1)"; F10RC=$?
if [[ "$F10OUT" == *"CEH-SAFETY ALLOW"* && "$F10RC" -eq 0 ]]; then PASS=$((PASS+1)); echo "PASS F10-allow-push-com-cert";
else FAIL=$((FAIL+1)); FAILED_LIST="$FAILED_LIST F10-allow-push-com-cert"; echo "FAIL F10-allow-push-com-cert :: out=[$F10OUT] rc=$F10RC"; fi
# F11: certificado de outro commit (obsoleto) = DENY
git -C "$TMPREP" -c user.email=t@t -c user.name=t commit -q --allow-empty -m two 2>/dev/null
F11OUT="$(cd "$TMPREP" && env -i PATH="$PATH" python3 "$HOOK" "git push origin dev" 2>&1)"; F11RC=$?
if [[ "$F11OUT" == *"CEH-SAFETY DENY"* && "$F11OUT" == *"PRE-PUSH CI GATE"* && "$F11RC" -eq 0 ]]; then PASS=$((PASS+1)); echo "PASS F11-deny-cert-obsoleto";
else FAIL=$((FAIL+1)); FAILED_LIST="$FAILED_LIST F11-deny-cert-obsoleto"; echo "FAIL F11-deny-cert-obsoleto :: out=[$F11OUT] rc=$F11RC"; fi
rm -rf "$TMPREP"
# F12: detect-project emite runtime: (strategy awareness, offline)
DOUT="$(bash "$ROOT/profiles/clearer-muse/scripts/detect-project.sh" "$ROOT" 2>&1)"; DRC=$?
if [[ "$DOUT" == *"runtime:"* && "$DRC" -eq 0 ]]; then PASS=$((PASS+1)); echo "PASS F12-detect-runtime";
else FAIL=$((FAIL+1)); FAILED_LIST="$FAILED_LIST F12-detect-runtime"; echo "FAIL F12-detect-runtime :: out=[$DOUT] rc=$DRC"; fi
# F13: test-runner emite Certificado de Voo PASS p/ comando real exit 0
TMPRUN=$(mktemp -d)
(cd "$TMPRUN" && bash "$ROOT/profiles/clearer-muse/scripts/test-runner.sh" true >/dev/null 2>&1); T13RC=$?
if [[ "$T13RC" -eq 0 && -f "$TMPRUN/.ceh/last-ci-run.json" ]] && grep -q '"status": "PASS"' "$TMPRUN/.ceh/last-ci-run.json" 2>/dev/null; then PASS=$((PASS+1)); echo "PASS F13-runner-cert";
else FAIL=$((FAIL+1)); FAILED_LIST="$FAILED_LIST F13-runner-cert"; echo "FAIL F13-runner-cert :: rc=$T13RC"; fi
rm -rf "$TMPRUN"
# F14: heartbeat preserva exit 0 e marca done (cadencia 25s configuravel)
HOUT="$(bash "$ROOT/profiles/clearer-muse/scripts/heartbeat.sh" --interval 1 -- true 2>&1)"; HRC=$?
if [[ "$HOUT" == *"HEARTBEAT done"* && "$HRC" -eq 0 ]]; then PASS=$((PASS+1)); echo "PASS F14-heartbeat-exit";
else FAIL=$((FAIL+1)); FAILED_LIST="$FAILED_LIST F14-heartbeat-exit"; echo "FAIL F14-heartbeat-exit :: out=[$HOUT] rc=$HRC"; fi

WALL=$((SECONDS-START))
echo "---"
echo "PASS=$PASS FAIL=$FAIL WALL=${WALL}s$([ -n "$FAILED_LIST" ] && echo " FAILED:$FAILED_LIST")"
if [[ "$WALL" -ge 60 ]]; then echo "TETO-FAIL: parede >= 60s"; exit 1; fi
[[ "$FAIL" -eq 0 ]]
