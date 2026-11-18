#!/usr/bin/env python3
"""git_inspect.py — Inspeção declarativa de Git em JSON (Etapa 4, F2).

Adaptação do utilitário OPT-004 do enhancements: uma chamada parametrizada
substitui scripts ad-hoc de histórico, com saída JSON curta e estável.
Uso: `python3 scripts/git_inspect.py --repo PATH [--limit N] [--grep TXT]`.
Exits: 0 ok; 1 repo inválido/erro do git (JSON com `error` preenchido).
"""

import argparse
import json
import subprocess
import sys


def inspect(repo: str, limit: int, grep) -> dict:
    base = {"repo": repo, "commits": [], "error": None}
    try:
        probe = subprocess.run(
            ["git", "-C", repo, "rev-parse", "--git-dir"],
            capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired) as exc:
        base["error"] = f"git indisponivel: {exc.__class__.__name__}"
        return base
    if probe.returncode != 0:
        base["error"] = "nao e um repositorio git"
        return base
    cmd = ["git", "-C", repo, "log", f"-n{limit}",
           "--pretty=format:%h|%an|%ad|%s", "--date=short"]
    if grep:
        cmd.extend(["--grep", grep])
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired) as exc:
        base["error"] = f"git log falhou: {exc.__class__.__name__}"
        return base
    if res.returncode != 0:
        base["error"] = res.stderr.strip()[:200] or "git log falhou"
        return base
    for line in res.stdout.splitlines():
        parts = line.split("|", 3)
        if len(parts) == 4:
            base["commits"].append({
                "hash": parts[0], "author": parts[1],
                "date": parts[2], "subject": parts[3]})
    return base


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="git_inspect.py")
    ap.add_argument("--repo", required=True)
    ap.add_argument("--limit", type=int, default=15)
    ap.add_argument("--grep", default=None)
    args = ap.parse_args(argv)
    if args.limit < 1 or args.limit > 500:
        print(json.dumps({"repo": args.repo, "commits": [],
                          "error": "limit fora de 1..500"}))
        return 1
    out = inspect(args.repo, args.limit, args.grep)
    print(json.dumps(out, ensure_ascii=False))
    return 0 if out["error"] is None else 1


if __name__ == "__main__":
    sys.exit(main())
