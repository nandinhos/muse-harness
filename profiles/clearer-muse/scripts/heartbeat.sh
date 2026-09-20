#!/usr/bin/env bash
# heartbeat.sh — Heartbeat p/ testes e comandos assíncronos (cadência 25s, anti-idle).
# Uso: bash scripts/heartbeat.sh [--interval 25] -- <comando...>
#      bash scripts/heartbeat.sh --pid <pid> [--interval 25]
# Exit = exit do comando (modo --); imprime HEARTBEAT a cada intervalo com elapsed.
set -u
INTERVAL=25; PID=""; CMD=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval|-i) INTERVAL="$2"; shift 2 ;;
    --pid|-p) PID="$2"; shift 2 ;;
    --) shift; CMD=("$@"); break ;;
    *) CMD=("$@"); break ;;
  esac
done
START=$SECONDS
beat() { echo "[CEH HEARTBEAT ${SECONDS}s elapsed] $1"; }
if [[ -n "$PID" ]]; then
  while kill -0 "$PID" 2>/dev/null; do sleep "$INTERVAL"; beat "pid $PID ativo (elapsed $((SECONDS-START))s)"; done
  echo "[CEH HEARTBEAT done] pid $PID encerrou (elapsed $((SECONDS-START))s)"; exit 0
fi
[[ ${#CMD[@]} -eq 0 ]] && { echo "Uso: heartbeat.sh [--interval 25] -- <comando...>" >&2; exit 2; }
"${CMD[@]}" & CHILD=$!
while kill -0 "$CHILD" 2>/dev/null; do
  sleep "$INTERVAL" & SLP=$!
  wait "$SLP" 2>/dev/null || true
  kill -0 "$CHILD" 2>/dev/null && beat "'${CMD[*]}' em execucao (elapsed $((SECONDS-START))s)"
done
wait "$CHILD"; CODE=$?
echo "[CEH HEARTBEAT done] exit=$CODE elapsed=$((SECONDS-START))s :: ${CMD[*]}"
exit $CODE
