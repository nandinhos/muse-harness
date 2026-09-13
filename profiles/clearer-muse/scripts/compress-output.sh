#!/usr/bin/env bash
# compress-output.sh — Wrapper de compressão de saída (addon token-economy).
# Uso: scripts/compress-output.sh <comando...>
# Executa o comando, preserva o exit code, colapsa linhas consecutivas
# repetidas e imprime head+tail com a contagem do omitido. Equivale ao papel
# do RTK no CEH quando o binário `rtk` não está no PATH.
set -u

HEAD_LINES="${CEH_COMPRESS_HEAD:-40}"
TAIL_LINES="${CEH_COMPRESS_TAIL:-40}"

if [[ $# -eq 0 ]]; then
  echo "uso: compress-output.sh <comando...>" >&2
  exit 1
fi

out="$(mktemp)"; uniq_out="$(mktemp)"
trap 'rm -f "$out" "$uniq_out"' EXIT

set +e
"$@" >"$out" 2>&1
code=$?
set -e

uniq -c "$out" | sed -E 's/^ +([0-9]+) /\1x /' > "$uniq_out"
total=$(wc -l < "$out" | tr -d ' ')
shown=$((HEAD_LINES + TAIL_LINES))

echo "=== [compress-output] exit=$code linhas=$total ==="
if [[ "$total" -le "$shown" ]]; then
  cat "$uniq_out"
else
  head -n "$HEAD_LINES" "$uniq_out"
  omitted=$((total - shown))
  echo "... [${omitted} linha(s) omitida(s) — reexecute sem o wrapper p/ saída bruta] ..."
  tail -n "$TAIL_LINES" "$uniq_out"
fi
exit "$code"
