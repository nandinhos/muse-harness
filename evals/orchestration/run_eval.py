#!/usr/bin/env python3
"""run_eval.py — E2E da orquestração contra o critério pré-registrado (F1/F8).

Critério (CRITERIA.md, escrito antes do classificador):
  1. HIGH 12/12 em T4 (um rebaixamento = BLOCKER, reprova sem média);
  2. acurácia global >= 90% (>=33/36 classe+tier exatos);
  3. 0 tarefa LOW em T4;
  4. determinismo: 3 passadas idênticas, cada uma <60s, offline;
  5. deriva: remover 1 sinal HIGH em cópia sandbox derruba >=1 HIGH de T4.
Mais o canário de telemetria shadow (3 eventos, agregador confere).
Saída no contrato COMMAND/EXIT/STATUS; exit 0 sse tudo aprova.
"""

import csv
import hashlib
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
SCR = ROOT / "profiles" / "clearer-muse" / "scripts"
CLASSIFY = SCR / "route_classify.py"
ROUTING = (ROOT / "profiles" / "clearer-muse" / "skills"
           / "clearer-orchestration" / "routing.json")

PASS = FAIL = 0
FAILED = []


def check(name, ok, detail=""):
    global PASS, FAIL
    if ok:
        PASS += 1
        print(f"PASS {name}")
    else:
        FAIL += 1
        FAILED.append(name)
        print(f"FAIL {name} :: {detail}")


def classify(task, config=None, telemetry=None):
    cmd = [sys.executable, str(CLASSIFY), "--task", task]
    if config:
        cmd += ["--config", str(config)]
    if telemetry:
        cmd += ["--telemetry", str(telemetry)]
    res = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
    if res.returncode != 0:
        return None
    return json.loads(res.stdout)


def corpus_pass(rows, config=None):
    out = []
    for r in rows:
        d = classify(r["tarefa"], config=config)
        out.append((r, d))
    return out


def main() -> int:
    rows = list(csv.DictReader(
        (HERE / "corpus.tsv").open(encoding="utf-8"), delimiter="\t"))

    # 4 (determinismo) roda junto: 3 passadas completas com relógio.
    passes, digests, walls = [], [], []
    for _ in range(3):
        t0 = time.monotonic()
        res = corpus_pass(rows)
        walls.append(time.monotonic() - t0)
        passes.append(res)
        blob = json.dumps([d for _, d in res], sort_keys=True)
        digests.append(hashlib.sha256(blob.encode()).hexdigest())
    check("F8-determinismo-3x", len(set(digests)) == 1 and max(walls) < 60,
          f"digests={len(set(digests))} walls={[round(w,1) for w in walls]}")

    res = passes[0]
    exact = sum(1 for r, d in res
                if d and d["classe"] == r["classe"] and d["tier"] == r["tier"])
    high = [(r, d) for r, d in res if r["classe"] == "HIGH"]
    high_t4 = sum(1 for _, d in high if d and d["tier"] == "T4")
    low_t4 = sum(1 for r, d in res
                 if r["classe"] == "LOW" and d and d["tier"] == "T4")
    misses = [f"{r['id']}:{d['classe']}/{d['tier']}!={r['classe']}/{r['tier']}"
              for r, d in res
              if not d or d["classe"] != r["classe"] or d["tier"] != r["tier"]]
    check("F8-high-intocavel", high_t4 == len(high) == 12,
          f"HIGH em T4: {high_t4}/12")
    check("F8-acuracia-90", exact >= 33, f"exatos={exact}/36 miss={misses}")
    check("F8-low-nunca-t4", low_t4 == 0, f"LOW em T4: {low_t4}")
    if misses:
        print(f"INFO misses (registrados, criterio nao ajustado): {misses}")

    # 5 deriva: copia sandbox sem um sinal HIGH portador deve derrubar HIGH.
    # 'autenticacao' e o unico sinal de H01 (OBSERVED na sonda F3); sinais
    # redundantes ('producao' etc.) sao defesa em profundidade e a remocao
    # deles corretamente nao derruba nada — a deriva mira sinal portador.
    cfg = json.loads(ROUTING.read_text(encoding="utf-8"))
    cfg["high_signals"] = [s for s in cfg["high_signals"]
                           if s != "autenticacao"]
    with tempfile.TemporaryDirectory() as tmp:
        drift_cfg = Path(tmp) / "routing-drift.json"
        drift_cfg.write_text(json.dumps(cfg), encoding="utf-8")
        dropped = 0
        for r, _ in high:
            d = classify(r["tarefa"], config=drift_cfg)
            if not d or d["tier"] != "T4":
                dropped += 1
    check("F8-deriva-detectada", dropped >= 1,
          f"HIGH derrubados sem 'autenticacao': {dropped}")

    # Canário de telemetria shadow: 3 classificações -> agregador confere.
    with tempfile.TemporaryDirectory() as tmp:
        log = Path(tmp) / "ev.jsonl"
        for r in rows[:3]:
            classify(r["tarefa"], telemetry=log)
        rep = subprocess.run(
            [sys.executable, str(SCR / "telemetry_report.py"), str(log),
             "--json"], capture_output=True, text=True, timeout=15)
        agg = json.loads(rep.stdout) if rep.returncode == 0 else {}
    check("F8-canario-telemetria",
          agg.get("eventos") == 3
          and agg.get("decisoes", {}).get("shadow") == 3,
          f"agg={agg}")

    total = PASS + FAIL
    print("---")
    print(f"ORCH-EVAL: PASS={PASS} FAIL={FAIL}"
          + (f" [{', '.join(FAILED)}]" if FAILED else ""))
    print("==========================================")
    print("COMMAND:   bash evals/orchestration/run.sh")
    print(f"EXIT CODE: {0 if FAIL == 0 else 1}")
    print(f"STATUS:    {'PASS' if FAIL == 0 else 'FAIL'}")
    print("==========================================")
    print(f"RESULTADO: Executados: {total} | Passaram: {PASS} | "
          f"Falharam: {FAIL} | Ignorados: 0")
    return 0 if FAIL == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
