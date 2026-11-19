#!/usr/bin/env bash
# uninstall.sh — Remove o clearer-muse (plugin + aliases ceh-*).
# Uso: ./uninstall.sh [--yes]
set -euo pipefail
ASSUME_YES=0
[[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]] && ASSUME_YES=1

PLUGIN_LIST=""
REMOVE_ALIASES=1
command -v muse >/dev/null 2>&1 && PLUGIN_LIST="$(muse plugins list 2>/dev/null || true)"
if grep -q "clearer-muse" <<< "$PLUGIN_LIST"; then
  REMOVE=0
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    REMOVE=1
  elif [[ -t 0 ]]; then
    read -rp "Remover o plugin clearer-muse do Muse? [s/N] " ans
    [[ "$ans" == [sSyY]* ]] && REMOVE=1
  fi
  if [[ "$REMOVE" -eq 1 ]]; then
    muse plugins remove clearer-muse || { echo "[ERRO] falha ao remover clearer-muse; aliases preservados." >&2; exit 1; }
  else
    REMOVE_ALIASES=0
    echo "plugin mantido; aliases preservados."
  fi
fi

RC_FILES="${RC_FILES:-$HOME/.bashrc $HOME/.zshrc}"
[[ "$REMOVE_ALIASES" -eq 1 ]] || { echo "desinstalação interrompida sem alterações."; exit 0; }
for rc in $RC_FILES; do
  [[ -f "$rc" ]] || continue
  python3 - "$rc" <<'PYEOF'
import os, re, stat, sys, tempfile
p = sys.argv[1]
c = open(p, "rb").read().decode("utf-8", "surrogateescape")
c2 = re.sub(r"# BEGIN CLEARER-MUSE ALIASES.*?# END CLEARER-MUSE ALIASES(?:\r?\n)?", "", c, flags=re.DOTALL)
if c2 != c:
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(os.path.abspath(p)), prefix=".clearer-muse-")
    try:
        with os.fdopen(fd, "wb") as fh:
            fh.write(c2.encode("utf-8", "surrogateescape"))
        os.chmod(tmp, stat.S_IMODE(os.stat(p).st_mode))
        os.replace(tmp, p)
    except BaseException:
        try: os.unlink(tmp)
        except OSError: pass
        raise
    print(f"aliases removidos de {p}")
PYEOF
done
echo "desinstalação concluída."
