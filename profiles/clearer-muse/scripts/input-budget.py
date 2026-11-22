#!/usr/bin/env python3
"""input-budget.py — Teto auditavel de Input/turno (RULE-OPT-01).

Soma os bytes injetados por turno (regras always_on + arquivo aberto sob
demanda) e falha se qualquer arquivo passa do teto por arquivo ou se o
total passa do teto total. Estimativa de tokens = bytes/4 (INFERRED,
benchmark evaluation-standards: OBSERVED so via usage da API).

Defaults (benchmark RULE-OPT-01): teto total 22798B (~5700 tok), teto
por arquivo 24000B. Uso:
  python3 scripts/input-budget.py [--files A B ...] [--cwd DIR] [--json]
Exits: 0 dentro do teto; 1 acima do teto total; 2 arquivo ilegivel ou
acima do teto por arquivo (fail-closed).
"""
import argparse
import json
import sys
from pathlib import Path


def default_files(cwd: Path):
    home = Path.home()
    files = [home / ".claude" / "CLAUDE.md", cwd / "AGENTS.md"]
    return [f for f in files if f.is_file()]


def audit(files, ceiling_total: int, ceiling_file: int) -> dict:
    items = []
    total = 0
    over_file = []
    for f in files:
        try:
            size = Path(f).stat().st_size
        except OSError:
            return {"error": f"ilegivel: {f}", "items": [], "total_bytes": 0,
                    "ceiling_total": ceiling_total,
                    "ceiling_file": ceiling_file, "verdict": "BLOCK"}
        items.append({"path": str(f), "bytes": size})
        total += size
        if size > ceiling_file:
            over_file.append(str(f))
    if over_file:
        verdict = "BLOCK"
    elif total > ceiling_total:
        verdict = "OVER"
    else:
        verdict = "OK"
    return {"items": items, "total_bytes": total,
            "total_tokens_est": round(total / 4),
            "ceiling_total": ceiling_total, "ceiling_file": ceiling_file,
            "over_file": over_file, "verdict": verdict, "error": None}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="input-budget.py")
    ap.add_argument("--files", nargs="*", default=None)
    ap.add_argument("--cwd", default=".")
    ap.add_argument("--ceiling-total", type=int, default=22_798)
    ap.add_argument("--ceiling-file", type=int, default=24_000)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    files = ([Path(f) for f in args.files] if args.files
             else default_files(Path(args.cwd)))
    if not files:
        print("[INPUT-BUDGET] nenhum arquivo (fail-closed)", file=sys.stderr)
        return 2
    result = audit(files, args.ceiling_total, args.ceiling_file)
    if args.json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    elif result["error"]:
        print(f"[INPUT-BUDGET] BLOCK {result['error']}")
    else:
        print(f"[INPUT-BUDGET] {result['verdict']} "
              f"total={result['total_bytes']}B "
              f"(~{result['total_tokens_est']} tok) "
              f"teto={result['ceiling_total']}B")
    return {"OK": 0, "OVER": 1, "BLOCK": 2}[result["verdict"]]


if __name__ == "__main__":
    sys.exit(main())
