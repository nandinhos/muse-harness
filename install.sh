#!/usr/bin/env bash
# ==============================================================================
# CLEARER Muse Harness — Instalador local (porte de install.sh do CEH
# Antigravity, adaptado ao Muse Code: `muse plugins` em vez de ~/.gemini).
# Uso local:  ./install.sh [--scope user|project] [--yes]
# Remoto:     curl -fsSL https://raw.githubusercontent.com/nandinhos/muse-harness/dev/install.sh | bash -s -- --scope user
# Por padrão pergunta antes de alterar ~/.bashrc/~/.zshrc. RC_FILES pode ser
# sobrescrito em testes (ex: RC_FILES="$TMP/rc" ./install.sh --yes).
# ==============================================================================
set -euo pipefail

SCOPE="user"
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --scope) shift; SCOPE="${1:-user}"; shift || true ;;
    --scope=*) SCOPE="${arg#--scope=}"; shift || true ;;
    --yes|-y) ASSUME_YES=1; shift || true ;;
    --help|-h) sed -n '2,9p' "$0"; exit 0 ;;
    -*) echo "[ERRO] argumento desconhecido: $arg" >&2; exit 2 ;;
    *) shift || true ;;
  esac
done

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[AVISO]${NC} $1"; }
fail()    { echo -e "${RED}[ERRO]${NC} $1"; exit 1; }

case "$SCOPE" in
  user|project) ;;
  *) echo "[ERRO] --scope invalido: $SCOPE (use user ou project)" >&2; exit 2 ;;
esac

# 1. Pré-requisitos
for cmd in git python3 bash muse; do
  command -v "$cmd" >/dev/null 2>&1 || fail "dependência ausente: $cmd"
done
success "pré-requisitos verificados (git, python3, bash, muse)."
command -v rtk >/dev/null 2>&1 \
  && success "'rtk' detectado (economia de tokens ativa)." \
  || info "opcional: 'rtk' ausente (https://github.com/rtk-ai/rtk)."

# 2. Localiza o bundle (repo local ou clone raso)
if [[ -f "$(dirname "$0")/profiles/clearer-muse/.muse-plugin/plugin.json" ]]; then
  SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
  PROFILE_DIR="$SOURCE_DIR/profiles/clearer-muse"
  info "usando bundle local: $PROFILE_DIR"
else
  TMP_CLONE="$(mktemp -d -t muse-harness-install-XXXXXX)"
  trap 'rm -rf "$TMP_CLONE"' EXIT
  git clone --depth 1 --branch dev https://github.com/nandinhos/muse-harness.git "$TMP_CLONE" -q \
    || fail "clone de nandinhos/muse-harness falhou"
  PROFILE_DIR="$TMP_CLONE/profiles/clearer-muse"
  SOURCE_DIR="$TMP_CLONE"
  success "bundle obtido via clone raso."
fi

# 3. Valida e instala/atualiza o plugin
muse plugins validate "$PROFILE_DIR" \
  || fail "bundle inválido (muse plugins validate; saída acima)."
success "bundle válido."
PLUGIN_LIST="$(muse plugins list 2>/dev/null || true)"
if grep -q "clearer-muse" <<< "$PLUGIN_LIST"; then
  muse plugins update clearer-muse || fail "falha ao atualizar clearer-muse."
  success "plugin clearer-muse atualizado pela fonte/escopo já registrados (--scope não é reaplicado em update)."
else
  muse plugins install "$PROFILE_DIR" --scope "$SCOPE" \
    || fail "falha ao instalar clearer-muse."
  success "plugin clearer-muse instalado (scope: $SCOPE)."
fi

# 4. Aliases idempotentes (pergunta antes, salvo --yes)
MARKER_BEGIN="# BEGIN CLEARER-MUSE ALIASES"
MARKER_END="# END CLEARER-MUSE ALIASES"
SCR="$PROFILE_DIR/scripts"
SCR_Q=$(printf '%q' "$SCR")
SOURCE_Q=$(printf '%q' "$SOURCE_DIR")
PROFILE_Q=$(printf '%q' "$PROFILE_DIR")
ALIAS_BLOCK="$MARKER_BEGIN
alias ceh-env='bash $SCR_Q/detect-project.sh .'
alias ceh-preflight='bash $SCR_Q/preflight.sh'
alias ceh-evals='bash $SOURCE_Q/evals/run.sh'
alias ceh-tests='bash $PROFILE_Q/tests/run-all-tests.sh'
alias ceh-branches='bash $SCR_Q/setup-branches.sh'
alias ceh-monitor='bash $SCR_Q/task-monitor.sh'
alias ceh-doc-audit='bash $SCR_Q/doc-audit.sh'
alias ceh-conselho='bash $SCR_Q/conselho-seniores.sh'
alias ceh-help='bash $SCR_Q/ceh-help.sh'
$MARKER_END"

RC_FILES="${RC_FILES:-$HOME/.bashrc $HOME/.zshrc}"
if [[ "$ASSUME_YES" -eq 0 ]]; then
  if [[ -t 0 ]]; then
    read -rp "Adicionar aliases ceh-* a $RC_FILES? [s/N] " ans
    [[ "$ans" == [sSyY]* ]] || { info "aliases ignorados por opção do usuário."; exit 0; }
  else
    info "aliases ignorados: sessão não interativa sem --yes; nenhum rc foi alterado."
    exit 0
  fi
fi
for rc in $RC_FILES; do
  [[ -f "$rc" ]] || continue
  python3 - "$rc" "$ALIAS_BLOCK" <<'PYEOF'
import os, re, stat, sys, tempfile
rc_path, block = sys.argv[1], sys.argv[2].strip()
b, e = "# BEGIN CLEARER-MUSE ALIASES", "# END CLEARER-MUSE ALIASES"
data = open(rc_path, "rb").read()
content = data.decode("utf-8", "surrogateescape")
nl = "\r\n" if b"\r\n" in data else "\n"
block = block.replace("\r\n", "\n").replace("\n", nl)
pat = re.compile(rf"{re.escape(b)}.*?{re.escape(e)}(?:\r?\n)?", re.DOTALL)
content = pat.sub(block + nl, content) if pat.search(content) else content.rstrip("\r\n") + nl + nl + block + nl
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(os.path.abspath(rc_path)), prefix=".clearer-muse-")
try:
    with os.fdopen(fd, "wb") as fh:
        fh.write(content.encode("utf-8", "surrogateescape"))
    os.chmod(tmp, stat.S_IMODE(os.stat(rc_path).st_mode))
    os.replace(tmp, rc_path)
except BaseException:
    try: os.unlink(tmp)
    except OSError: pass
    raise
print(f"aliases sincronizados em {rc_path}")
PYEOF
done
success "instalação concluída. Recarregue o shell (source ~/.bashrc)."
