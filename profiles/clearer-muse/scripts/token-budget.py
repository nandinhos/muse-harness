#!/usr/bin/env python3
"""token-budget.py — Estimador de tokens por artefato (addon token-economy).

Estima tokens como `chars // 4` (heurística pública e auditável, não medição
do modelo) e classifica cada entrada: `ok` (<= 8k), `fatie` (> 8k),
`resuma` (> 32k). Uso: `python3 scripts/token-budget.py <arquivo...> [--stdin]`.
"""

import os
import sys

OK_LIMIT = 8000
SPLIT_LIMIT = 32000


def classify(tokens: int) -> str:
    if tokens > SPLIT_LIMIT:
        return "resuma"
    if tokens > OK_LIMIT:
        return "fatie"
    return "ok"


def entry(label: str, chars: int) -> tuple[str, int, int, str]:
    tokens = chars // 4
    return (label, chars, tokens, classify(tokens))


def main() -> int:
    items: list[tuple[str, int, int, str]] = []
    args = [a for a in sys.argv[1:] if a != "--stdin"]
    for path in args:
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                items.append(entry(path, len(fh.read())))
        except OSError as exc:
            print(f"ERRO {path} :: {exc}")
    if "--stdin" in sys.argv[1:] and not sys.stdin.isatty():
        items.append(entry("<stdin>", len(sys.stdin.read())))
    if not items:
        print("uso: token-budget.py <arquivo...> [--stdin]")
        return 1
    total = 0
    for label, chars, tokens, verdict in items:
        total += tokens
        print(f"{verdict.upper():7} {tokens:8d} tok  {chars:9d} chars  {label}")
    print(f"TOTAL {total} tok estimados em {len(items)} artefato(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
