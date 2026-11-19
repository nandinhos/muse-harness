#!/usr/bin/env python3
"""session_cost.py — Custo real de sessões Muse a partir do session.jsonl.

Lê os eventos `model_completed` (payload_type=runtime.session) gravados pelo
host e agrega por modelo. A métrica oficial é o custo NOVO:

    custo_real = (input_tokens - cached_tokens) + output_tokens

`input_tokens` bruto NÃO é custo: em sessões longas >95% é prompt cache
re-lido a cada passo. Somar o bruto superestima o gasto em até ~40x
(incidente 2026-11-18: 98,8M brutos vs. ~2,0M novos numa sessão).

Uso:
  python3 scripts/session_cost.py <session.jsonl> [--json]
  python3 scripts/session_cost.py <dir-de-sessao> [--json]  # inclui subagent/

Exits: 0 ok; 2 caminho ausente/ilegível ou sem eventos de modelo.
Linhas inválidas são ignoradas (nunca quebram o relatório).
"""

import json
import sys
from collections import defaultdict
from pathlib import Path


def _iter_records(path: Path):
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(obj, dict) and isinstance(obj.get("children"), list):
            for child in obj["children"]:
                raw = child.get("record_json") if isinstance(child, dict) else None
                if not isinstance(raw, str):
                    continue
                try:
                    yield json.loads(raw)
                except json.JSONDecodeError:
                    continue
        elif isinstance(obj, dict):
            yield obj


def _usage_from_record(rec):
    if rec.get("payload_type") != "runtime.session":
        return None
    payload = rec.get("payload") or {}
    event = payload.get("event") or {}
    if event.get("kind") != "model_completed":
        return None
    usage = event.get("usage") or {}
    if not isinstance(usage, dict):
        return None
    def _int(key):
        val = usage.get(key)
        return val if isinstance(val, int) and not isinstance(val, bool) and val >= 0 else 0
    cached = _int("cached_tokens") or _int("cache_read_tokens")
    return {
        "model": str(event.get("model") or "unknown"),
        "input": _int("input_tokens"),
        "cached": cached,
        "output": _int("output_tokens"),
        "reasoning": _int("reasoning_tokens"),
    }


def aggregate(paths):
    by_model = defaultdict(lambda: {"steps": 0, "input": 0, "cached": 0, "output": 0, "reasoning": 0})
    total_steps = 0
    max_input_step = 0
    last_input = 0
    for path in paths:
        for rec in _iter_records(path):
            hit = _usage_from_record(rec)
            if hit is None:
                continue
            bucket = by_model[hit["model"]]
            bucket["steps"] += 1
            bucket["input"] += hit["input"]
            bucket["cached"] += hit["cached"]
            bucket["output"] += hit["output"]
            bucket["reasoning"] += hit["reasoning"]
            total_steps += 1
            max_input_step = max(max_input_step, hit["input"])
            last_input = hit["input"]
    models = {}
    for model, b in sorted(by_model.items()):
        real_input = b["input"] - b["cached"]
        models[model] = {
            **b,
            "real_input": real_input,
            "real_cost": real_input + b["output"],
        }
    totals = {
        "steps": total_steps,
        "input": sum(b["input"] for b in by_model.values()),
        "cached": sum(b["cached"] for b in by_model.values()),
        "output": sum(b["output"] for b in by_model.values()),
        "reasoning": sum(b["reasoning"] for b in by_model.values()),
    }
    totals["real_input"] = totals["input"] - totals["cached"]
    totals["real_cost"] = totals["real_input"] + totals["output"]
    totals["cache_ratio"] = (round(totals["cached"] / totals["input"], 4)
                             if totals["input"] else 0.0)
    return {
        "files": len(paths),
        "steps": total_steps,
        "max_input_step": max_input_step,
        "last_input_step": last_input,
        "by_model": models,
        "totals": totals,
    }


def collect_paths(target: Path):
    if target.is_file():
        return [target]
    if target.is_dir():
        found = sorted(target.rglob("session.jsonl"))
        return found
    return []


def main(argv=None) -> int:
    args = [a for a in (argv if argv is not None else sys.argv[1:])]
    as_json = "--json" in args
    args = [a for a in args if a != "--json"]
    if len(args) != 1:
        print("uso: session_cost.py <session.jsonl|dir> [--json]", file=sys.stderr)
        return 2
    paths = collect_paths(Path(args[0]))
    if not paths:
        return 2
    agg = aggregate(paths)
    if agg["steps"] == 0:
        return 2
    if as_json:
        print(json.dumps(agg, ensure_ascii=False, sort_keys=True))
        return 0
    t = agg["totals"]
    print(f"arquivos={agg['files']} steps={agg['steps']} "
          f"max_input_step={agg['max_input_step']} last_input_step={agg['last_input_step']}")
    for model, b in agg["by_model"].items():
        print(f"modelo={model} steps={b['steps']} input={b['input']} "
              f"cached={b['cached']} real_input={b['real_input']} "
              f"output={b['output']} reasoning={b['reasoning']} real_cost={b['real_cost']}")
    print(f"TOTAL input={t['input']} cached={t['cached']} "
          f"cache_ratio={t['cache_ratio']} real_input={t['real_input']} "
          f"output={t['output']} real_cost={t['real_cost']}")
    print("custo_real=(input-cached)+output  # input bruto NAO e custo (cache relido por passo)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
