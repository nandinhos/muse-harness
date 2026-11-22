#!/usr/bin/env python3
"""context-guard.py — Guarda de contexto de sessão (camada anti-inchaço).

Causa raiz do incidente 2026-11-18: sessão única sem reinício por etapa —
o histórico foi de 39k a 442k tokens e cada um dos 367 passos de LLM
re-enviou tudo. Este guardião lê o `session.jsonl` do host e classifica o
estado atual da sessão:

  OK    último passo < --warn-input (150k) e steps < --warn-steps (80)
  WARN  contexto ou passos acima do alerta: planeje o fechamento da etapa
  BLOCK contexto >= --block-input (300k) ou steps >= --block-steps (200):
        NÃO inicie etapa nova nesta sessão — feche com handoff (<=1k tok,
        skill token-economy) e reinicie. Continuar multiplica o custo de
        TODOS os passos seguintes.

É verificação explícita (mesmo padrão do stop-guard.py): o host Muse não
expõe evento de contexto ao hook `safety-gate`, então o gate roda no
fechamento de etapa / `/token-report`, nunca no caminho quente.

Uso: python3 scripts/context-guard.py --session <session.jsonl> [--json]
     [--warn-input N] [--block-input N] [--warn-steps N] [--block-steps N]
     python3 scripts/context-guard.py --last-input N --steps-count N [--json]
       (modo quente/sintetico: classifica sem ler sessao, p/ checagem a cada N tools)
Exits: 0 OK; 1 WARN; 2 BLOCK ou sessão ilegível/sem eventos (fail-closed).
"""

import argparse
import json
import sys
from pathlib import Path

# Reusa o parser do session_cost (mesma pasta); fallback se import falhar.
sys.path.insert(0, str(Path(__file__).resolve().parent))
try:
    from session_cost import aggregate, collect_paths  # noqa: E402
except Exception:  # pragma: no cover - import quebrado = fail-closed no main
    aggregate = None
    collect_paths = None


def classify(last_input: int, steps: int, warn_input: int, block_input: int,
             warn_steps: int, block_steps: int) -> str:
    if last_input >= block_input or steps >= block_steps:
        return "BLOCK"
    if last_input >= warn_input or steps >= warn_steps:
        return "WARN"
    return "OK"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="context-guard.py")
    ap.add_argument("--session")
    ap.add_argument("--last-input", type=int)
    ap.add_argument("--steps-count", type=int)
    ap.add_argument("--warn-input", type=int, default=150_000)
    ap.add_argument("--block-input", type=int, default=300_000)
    ap.add_argument("--warn-steps", type=int, default=80)
    ap.add_argument("--block-steps", type=int, default=200)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    # Caminho quente: numeros ja medidos (session_cost/usage) sem reler sessao.
    if args.last_input is not None and args.steps_count is not None:
        verdict = classify(args.last_input, args.steps_count,
                           args.warn_input, args.block_input,
                           args.warn_steps, args.block_steps)
        result = {
            "verdict": verdict, "steps": args.steps_count,
            "last_input_step": args.last_input,
            "max_input_step": args.last_input,
            "thresholds": {
                "warn_input": args.warn_input,
                "block_input": args.block_input,
                "warn_steps": args.warn_steps,
                "block_steps": args.block_steps,
            },
            "real_cost": None, "cache_ratio": None, "mode": "hot",
        }
        if args.json:
            print(json.dumps(result, ensure_ascii=False, sort_keys=True))
        else:
            print(f"[CONTEXT-GUARD] {verdict} steps={result['steps']} "
                  f"last_input={result['last_input_step']}")
        return {"OK": 0, "WARN": 1, "BLOCK": 2}[verdict]
    if not args.session:
        print("[CONTEXT-GUARD] --session obrigatoria sem --last-input/"
              "--steps-count (fail-closed)", file=sys.stderr)
        return 2

    if aggregate is None or collect_paths is None:
        print("[CONTEXT-GUARD] session_cost indisponivel (fail-closed)",
              file=sys.stderr)
        return 2
    paths = collect_paths(Path(args.session))
    if not paths:
        print("[CONTEXT-GUARD] sessao nao encontrada (fail-closed)",
              file=sys.stderr)
        return 2
    # Guarda avalia a sessão principal: maior arquivo = tronco da sessão.
    main_path = max(paths, key=lambda p: p.stat().st_size)
    agg = aggregate([main_path])
    if agg["steps"] == 0:
        print("[CONTEXT-GUARD] sem eventos de modelo (fail-closed)",
              file=sys.stderr)
        return 2

    verdict = classify(agg["last_input_step"], agg["steps"],
                       args.warn_input, args.block_input,
                       args.warn_steps, args.block_steps)
    result = {
        "verdict": verdict,
        "steps": agg["steps"],
        "last_input_step": agg["last_input_step"],
        "max_input_step": agg["max_input_step"],
        "thresholds": {
            "warn_input": args.warn_input, "block_input": args.block_input,
            "warn_steps": args.warn_steps, "block_steps": args.block_steps,
        },
        "real_cost": agg["totals"]["real_cost"],
        "cache_ratio": agg["totals"]["cache_ratio"],
    }
    if args.json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    elif verdict == "OK":
        print(f"[CONTEXT-GUARD] OK steps={result['steps']} "
              f"last_input={result['last_input_step']} "
              f"real_cost={result['real_cost']}")
    elif verdict == "WARN":
        print(f"[CONTEXT-GUARD] WARN steps={result['steps']} "
              f"last_input={result['last_input_step']}: planeje fechar a "
              "etapa; handoff <=1k tok e reinicie a sessao na proxima etapa.")
    else:
        print(f"[CONTEXT-GUARD] BLOCK steps={result['steps']} "
              f"last_input={result['last_input_step']}: NAO inicie etapa "
              "nova nesta sessao. Feche com handoff e reinicie — cada "
              "passo novo re-envia o historico inteiro.")
    return {"OK": 0, "WARN": 1, "BLOCK": 2}[verdict]


if __name__ == "__main__":
    sys.exit(main())
