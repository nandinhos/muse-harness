#!/usr/bin/env bash
# canonical-diff.sh — Rotina anti-deriva canônico × instalação (HANDOFF pendência 4).
# Uso: scripts/canonical-diff.sh [<caminho-instalado>]
# Sem argumento: lê source.path do registro installed.json do Muse.
# Exit 0 = idêntico; 1 = deriva detectada; 2 = uso/ambiente inválido.
set -u

CANON="$(cd "$(dirname "$0")/.." && pwd)"
REGISTRY="$HOME/.local/share/muse/plugins/installed.json"

if [[ $# -ge 1 ]]; then
  DEST="$1"
elif [[ -f "$REGISTRY" ]]; then
  DEST="$(python3 -c "import json;print(json.load(open('$REGISTRY'))['plugins']['clearer-muse']['source']['path'])")"
else
  echo "ERRO: informe o caminho instalado ou tenha $REGISTRY" >&2
  exit 2
fi

if [[ ! -d "$DEST" ]]; then
  echo "ERRO: destino inexistente: $DEST" >&2
  exit 2
fi

if diff -r "$CANON" "$DEST"; then
  echo "IDÊNTICO: canônico == $DEST"
else
  echo "DERIVA: diferenças acima entre canônico e $DEST" >&2
  exit 1
fi
