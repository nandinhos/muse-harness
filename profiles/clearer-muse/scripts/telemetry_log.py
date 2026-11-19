#!/usr/bin/env python3
"""telemetry_log.py — Append mascarado de eventos de telemetria (Etapa 4, F2).

Grava 1 evento JSONL por invocação, append-only, sem rede. Todo texto livre
(`--note`, `--rule`) passa por máscara fail-closed: formatos de segredo
conhecidos, atribuições `chave=valor` sensíveis, tokens opacos longos e
caminhos de home são redigidos — valor não reconhecido como seguro não é
gravado em claro. Uso:

  python3 scripts/telemetry_log.py --file eventos.jsonl --tool muse.bash \
      --decision allow [--latency-ms N] [--rule R] [--note texto] \
      [--tokens N --token-source api|estimated_chars4]

Exits: 0 gravou; 2 entrada inválida (nada é escrito).
"""

import argparse
import datetime
import json
import re
import sys
from pathlib import Path

DECISIONS = {"allow", "deny", "ask", "overwrite", "shadow", "info"}
TOKEN_SOURCES = {"api", "estimated_chars4"}
TOOL_RE = re.compile(r"^[A-Za-z0-9_.\-]{1,80}$")

_SECRET_PATTERNS = [
    (re.compile(r"(?i)(aws[_-]?secret[_-]?access[_-]?key|client[_-]?secret|"
                r"private[_-]?key|password|passwd|secret|token|api[_-]?key|"
                r"authorization)\s*[:=]\s*([\"'])(?:\\.|(?!\2).)*\2"),
     r"\1=REDACTED"),
    (re.compile(r"\beyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\."
                r"[A-Za-z0-9_\-]{8,}\b"), "REDACTED_JWT"),
    (re.compile(r"(https?://[^\s/@:]+:)([^\s/@]+)(@)"),
     r"\1REDACTED\3"),
    (re.compile(r"(?<![A-Za-z0-9+/=])(?=[A-Za-z0-9+/=]{32,}"
                r"(?![A-Za-z0-9+/=]))(?=[A-Za-z0-9+/=]*[+/])"
                r"[A-Za-z0-9+/]{32,}={0,2}"), "REDACTED_TOKEN"),
    (re.compile(r"sk-[A-Za-z0-9_\-]{8,}"), "REDACTED_SK"),
    (re.compile(r"gh[pousr]_[A-Za-z0-9]{8,}"), "REDACTED_GH"),
    (re.compile(r"github_pat_[A-Za-z0-9_]{8,}"), "REDACTED_GH"),
    (re.compile(r"AKIA[0-9A-Z]{12,}"), "REDACTED_AWS"),
    (re.compile(r"xox[baprs]-[A-Za-z0-9\-]{8,}"), "REDACTED_SLACK"),
    (re.compile(r"(?i)bearer\s+\S+"), "Bearer REDACTED"),
    (re.compile(r"-----BEGIN[^-]*-----.*?-----END[^-]*-----", re.S),
     "REDACTED_PEM"),
    (re.compile(r"(?i)(aws[_-]?secret[_-]?access[_-]?key|client[_-]?secret|"
                r"private[_-]?key|password|passwd|secret|token|api[_-]?key|"
                r"authorization)\s*[:=]\s*(?:\w+\s+)?\S+"), r"\1=REDACTED"),
    (re.compile(r"\b[A-Za-z0-9_\-]{32,}\b"), "REDACTED_TOKEN"),
]
# Valor após palavra sensível em linguagem natural ("api key é X", "senha: X"):
# o token seguinte é o valor protegido; redigir é o default (fail-closed).
_KEYWORD_VALUE_RE = re.compile(
    r"(?i)\b(api[ _-]?key|senha|password|passwd|secret|token|chave|"
    r"credencial)\b([\s:=]{0,4}(?:é|e|is)?[\s:=]{0,4})([A-Za-z0-9_\-\.]{4,})")
# "senha do banco: X" — palavra sensível, até 3 palavras, dois-pontos, valor.
_KEYWORD_COLON_RE = re.compile(
    r"(?i)\b(api[ _-]?key|senha|password|passwd|secret|token|chave|"
    r"credencial)(\s+(?:\w+\s+){0,3}?\w+\s*:\s*)(\S+)")
_HOME_RE = re.compile(r"/(?:home|Users)/[\w.\-]+")


def mask(text: str) -> str:
    """Redige segredos e homes; na dúvida, redige (fail-closed)."""
    out = text
    for rx, repl in _SECRET_PATTERNS:
        out = rx.sub(repl, out)
    out = _KEYWORD_COLON_RE.sub(
        lambda m: f"{m.group(1)}{m.group(2)}REDACTED", out)
    out = _KEYWORD_VALUE_RE.sub(
        lambda m: f"{m.group(1)}{m.group(2)}REDACTED", out)
    return _HOME_RE.sub("~", out)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="telemetry_log.py")
    ap.add_argument("--file", required=True)
    ap.add_argument("--tool", required=True)
    ap.add_argument("--decision", required=True)
    ap.add_argument("--latency-ms", type=float, default=None)
    ap.add_argument("--rule", default=None)
    ap.add_argument("--note", default=None)
    ap.add_argument("--tokens", type=int, default=None)
    ap.add_argument("--token-source", default=None)
    args = ap.parse_args(argv)

    if args.decision not in DECISIONS or not TOOL_RE.match(args.tool):
        return 2
    if args.tokens is not None and args.token_source not in TOKEN_SOURCES:
        return 2
    if args.tokens is None and args.token_source is not None:
        return 2
    if args.latency_ms is not None and args.latency_ms < 0:
        return 2
    if args.tokens is not None and args.tokens < 0:
        return 2

    event = {
        "ts": datetime.datetime.now(datetime.timezone.utc).strftime(
            "%Y-%m-%dT%H:%M:%SZ"),
        "tool": args.tool,
        "decision": args.decision,
        "latency_ms": args.latency_ms,
        "rule": mask(args.rule) if args.rule else None,
        "tokens": args.tokens,
        "token_source": args.token_source,
        "note": mask(args.note) if args.note else None,
    }
    path = Path(args.file)
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(event, ensure_ascii=False) + "\n")
    except OSError:
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
