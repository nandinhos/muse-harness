#!/usr/bin/env python3
"""stop-guard.py — Fechamento epistêmico de feature (Etapa 4, F6, D4).

Tradução do `ceh-stop-guard.py` oficial p/ o envelope Muse: sem evento
`Stop` do host, roda como verificação explícita de fechamento. Sem
`.ceh/feature.json` (ou com status encerrado) é no-op silencioso; com
feature ativa, exige que o texto de fechamento carregue o Response
Contract mínimo (resultado + evidência física) — fail-closed.

Uso: `python3 scripts/stop-guard.py [--repo DIR] [--response ARQUIVO]`
(sem `--response`, lê stdin quando há feature ativa).
Exits: 0 ok/no-op; 1 fechamento sem contrato; 2 feature.json inválido.
"""

import argparse
import json
import re
import sys
from pathlib import Path

_CLOSED = {"done", "closed", "concluida", "concluido", "encerrada"}
_RESULT_RE = re.compile(r"(?i)\b(RESULT|VERIFICADO|VERDICT|APROVA)\b")
_EVIDENCE_RE = re.compile(
    r"(?i)(OBSERVED|exit\s*(code)?\s*[=:]?\s*0\b|PASS\s*=|PASS \(|"
    r"\b\d+/9\b|suíte|suite)")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="stop-guard.py")
    ap.add_argument("--repo", default=".")
    ap.add_argument("--response", default=None)
    args = ap.parse_args(argv)

    feature_file = Path(args.repo) / ".ceh" / "feature.json"
    if not feature_file.is_file():
        return 0
    try:
        feature = json.loads(feature_file.read_text(encoding="utf-8"))
        if not isinstance(feature, dict):
            raise ValueError("feature.json nao-objeto")
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"[STOP-GUARD] feature.json invalido (fail-closed): {exc}",
              file=sys.stderr)
        return 2
    if str(feature.get("status", "")).lower() in _CLOSED:
        return 0

    if args.response:
        try:
            text = Path(args.response).read_text(encoding="utf-8",
                                                 errors="replace")
        except OSError:
            return 2
    elif not sys.stdin.isatty():
        text = sys.stdin.read()
    else:
        text = ""
    missing = []
    if not _RESULT_RE.search(text):
        missing.append("RESULT/veredito")
    if not _EVIDENCE_RE.search(text):
        missing.append("evidencia fisica (exit/PASS/OBSERVED)")
    if missing:
        print(f"[STOP-GUARD] Feature '{feature.get('name', '?')}' ativa sem "
              f"Response Contract completo; falta: {', '.join(missing)}.",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
