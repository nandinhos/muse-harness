#!/usr/bin/env python3
"""telemetry_report.py — Agregador offline do event-log (Etapa 4, F2).

Lê o JSONL gravado por `telemetry_log.py` e resume: contagens por decisão
e ferramenta, latência p50/p95 e tokens por fonte rotulada. Linhas
inválidas são contadas (`invalidos=`), nunca quebram o relatório.
Uso: `python3 scripts/telemetry_report.py <eventos.jsonl> [--json]`.
Exits: 0 ok; 2 arquivo ausente/ilegível.
"""

import json
import sys
from collections import Counter
from pathlib import Path


def percentile(sorted_vals, pct):
    if not sorted_vals:
        return None
    idx = max(0, min(len(sorted_vals) - 1,
                     int(round(pct / 100 * len(sorted_vals) + 0.5)) - 1))
    return sorted_vals[idx]


_DECISIONS = {"allow", "deny", "ask", "overwrite", "shadow", "info"}
_TOKEN_SOURCES = {"api", "estimated_chars4"}


def _valid_event(rec) -> bool:
    if not isinstance(rec, dict):
        return False
    if not isinstance(rec.get("decision"), str) \
            or rec["decision"] not in _DECISIONS:
        return False
    if not isinstance(rec.get("tool"), str) or not rec["tool"]:
        return False
    latency = rec.get("latency_ms")
    if latency is not None:
        if isinstance(latency, bool) or not isinstance(latency, (int, float)):
            return False
        if latency != latency or latency in (float("inf"), float("-inf")):
            return False
        if latency < 0:
            return False
    tokens = rec.get("tokens")
    source = rec.get("token_source")
    if tokens is None:
        return source is None
    return (isinstance(tokens, int) and not isinstance(tokens, bool)
            and tokens >= 0 and isinstance(source, str)
            and source in _TOKEN_SOURCES)


def aggregate(path: Path) -> dict:
    events, invalid = [], 0
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            invalid += 1
            continue
        if _valid_event(rec):
            events.append(rec)
        else:
            invalid += 1
    lat = sorted(e["latency_ms"] for e in events
                 if e.get("latency_ms") is not None)
    tokens = Counter()
    for e in events:
        if e.get("tokens") is not None:
            tokens[e["token_source"]] += e["tokens"]
    return {
        "eventos": len(events),
        "invalidos": invalid,
        "decisoes": dict(Counter(e["decision"] for e in events)),
        "ferramentas": dict(Counter(e.get("tool", "?") for e in events)),
        "latency_ms": {"p50": percentile(lat, 50), "p95": percentile(lat, 95)},
        "tokens": dict(tokens),
    }


def main(argv=None) -> int:
    args = [a for a in (argv if argv is not None else sys.argv[1:])]
    as_json = "--json" in args
    args = [a for a in args if a != "--json"]
    if len(args) != 1:
        return 2
    path = Path(args[0])
    if not path.is_file():
        return 2
    try:
        agg = aggregate(path)
    except OSError:
        return 2
    if as_json:
        print(json.dumps(agg, ensure_ascii=False, sort_keys=True))
        return 0
    dec = " ".join(f"{k}={v}" for k, v in sorted(agg["decisoes"].items()))
    tok = " ".join(f"{k}={v}" for k, v in sorted(agg["tokens"].items()))
    print(f"eventos={agg['eventos']} invalidos={agg['invalidos']}")
    print(f"decisoes: {dec or '-'}")
    print(f"latency_ms p50={agg['latency_ms']['p50']} "
          f"p95={agg['latency_ms']['p95']}")
    print(f"tokens: {tok or '-'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
