#!/usr/bin/env python3
"""route_classify.py — Classificador shadow de tarefas por tier (Etapa 4, F3).

Determinístico e offline: casa sinais declarados em `routing.json` contra o
texto da tarefa (normalizado sem acentos) e emite `{classe, tier, sinais,
modo}` em JSON. Modo **shadow**: com `--telemetry`, registra o palpite no
event-log (`decision=shadow`) — quem executa continua sendo o baseline do
dispatcher; este script nunca decide nem bloqueia trabalho (D3/D5).
Uso: `python3 scripts/route_classify.py --task "..." [--config routing.json]
[--telemetry eventos.jsonl]`. Exits: 0 classificou; 2 config/entrada inválida.
"""

import argparse
import json
import sys
import unicodedata
from pathlib import Path

DEFAULT_CONFIG = (Path(__file__).resolve().parent.parent
                  / "skills" / "clearer-orchestration" / "routing.json")
REQUIRED_KEYS = ("high_signals", "medium_complex_signals", "medium_signals",
                 "low_t0_signals", "low_signals")


def norm(text: str) -> str:
    decomposed = unicodedata.normalize("NFKD", text.lower())
    return "".join(c for c in decomposed if not unicodedata.combining(c))


def load_config(path: Path):
    try:
        cfg = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(cfg, dict) or any(
            not isinstance(cfg.get(k), list) or not cfg[k]
            for k in REQUIRED_KEYS):
        return None
    return {k: [norm(str(s)) for s in cfg[k]] for k in REQUIRED_KEYS} | {
        "modo": str(cfg.get("modo", "shadow"))}


def classify(task: str, signals: dict) -> dict:
    text = norm(task)
    hit = lambda group: [s for s in signals[group] if s in text]

    def first_pos(group):
        positions = [text.find(s) for s in signals[group] if s in text]
        return min(positions) if positions else None

    high = hit("high_signals")
    if high:
        return {"classe": "HIGH", "tier": "T4", "sinais": high}

    # Fora de HIGH, o verbo/escopo que aparece primeiro arbitra LOW vs
    # MEDIUM: "corrigir typo no endpoint" é LOW; "implementar endpoint"
    # continua MEDIUM. Sinais complexos só elevam uma tarefa MEDIUM.
    medium_pos = first_pos("medium_signals")
    low_pos = min(
        [p for p in (first_pos("low_t0_signals"),
                     first_pos("low_signals")) if p is not None],
        default=None)
    if low_pos is not None and (medium_pos is None or low_pos <= medium_pos):
        low0 = hit("low_t0_signals")
        low0_pos = first_pos("low_t0_signals")
        low1_pos = first_pos("low_signals")
        if low0 and (low1_pos is None or low0_pos <= low1_pos):
            return {"classe": "LOW", "tier": "T0", "sinais": low0}
        return {"classe": "LOW", "tier": "T1", "sinais": hit("low_signals")}
    complex_ = hit("medium_complex_signals")
    if medium_pos is not None and complex_:
        return {"classe": "MEDIUM", "tier": "T3", "sinais": complex_}
    medium = hit("medium_signals")
    if medium:
        return {"classe": "MEDIUM", "tier": "T2", "sinais": medium}
    if complex_:
        return {"classe": "MEDIUM", "tier": "T3", "sinais": complex_}
    return {"classe": "MEDIUM", "tier": "T2", "sinais": ["default-sem-sinal"]}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="route_classify.py")
    ap.add_argument("--task", required=True)
    ap.add_argument("--config", default=str(DEFAULT_CONFIG))
    ap.add_argument("--telemetry", default=None)
    args = ap.parse_args(argv)

    signals = load_config(Path(args.config))
    if signals is None or not args.task.strip():
        return 2
    result = classify(args.task, signals)
    result["modo"] = signals["modo"]
    print(json.dumps(result, ensure_ascii=False))
    if args.telemetry:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import telemetry_log
        rc = telemetry_log.main([
            "--file", args.telemetry, "--tool", "route_classify",
            "--decision", "shadow", "--rule", result["tier"],
            "--note", args.task[:200]])
        if rc != 0:
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
