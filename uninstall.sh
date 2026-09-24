#!/usr/bin/env bash
# uninstall.sh — Remove o clearer-muse (plugin + aliases ceh-*).
# Uso: ./uninstall.sh [--yes]
set -euo pipefail
ASSUME_YES=0
[[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]] && ASSUME_YES=1

if command -v muse >/dev/null 2>&1 && muse plugins list 2>/dev/null | grep -q "clearer-muse"; then
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    muse plugins remove clearer-muse || true
  else
    read -rp "Remover o plugin clearer-muse do Muse? [s/N] " ans
    [[ "$ans" == [sSyY]* ]] && muse plugins remove clearer-muse || echo "plugin mantido."
  fi
fi

RC_FILES="${RC_FILES:-$HOME/.bashrc $HOME/.zshrc}"
for rc in $RC_FILES; do
  [[ -f "$rc" ]] || continue
  python3 - "$rc" <<'PYEOF'
import re, sys
p = sys.argv[1]
c = open(p, encoding="utf-8").read()
c2 = re.sub(r"# BEGIN CLEARER-MUSE ALIASES.*?# END CLEARER-MUSE ALIASES\n?", "", c, flags=re.DOTALL)
if c2 != c:
    open(p, "w", encoding="utf-8").write(c2)
    print(f"aliases removidos de {p}")
PYEOF
done
echo "desinstalação concluída."
