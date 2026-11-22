#!/usr/bin/env python3
"""ceh-dispatch.py — Dispatcher deterministico do padrao CLEARER (sem prompt).

Substitui a analise que o loader fazia ao catalogar skills: nenhuma descricao
de skill entra no contexto de abertura. Este script (codigo, offline) resolve
o padrao estabelecido a partir da tarefa em texto puro:

  ambiente  -> ceh_core.environment.detect_environment (branch/env/.env);
               LOW leitura: skipped (nao-verificado), sem subprocess —
               ambiente so ao mutar (MEDIUM/HIGH) ou com --with-env
  Risk Dial -> route_classify.classify sobre routing.json (sinais declarados)
  rota      -> primeira entrada de `rotas` em routing.json cujos sinais casam;
               devolve apenas id + caminho do arquivo de referencia. O corpo
               do SKILL.md so e lido se o operador abrir esse 1 arquivo.
  guardrail -> hook safety-gate (PreToolUse), unico item do loader.

Uso: python3 scripts/ceh-dispatch.py --task "..." [--cwd DIR]
Saida: 1 linha JSON. Exits: 0 ok; 2 tarefa/config invalida.
"""
import argparse
import json
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
PROFILE = SCRIPTS.parent
ROUTING = PROFILE / "skills" / "clearer-orchestration" / "routing.json"
VENDOR = PROFILE / "hooks" / "vendor" / "ceh"

sys.path.insert(0, str(SCRIPTS))
sys.path.insert(0, str(VENDOR))

CICLOS = {
    "LOW": ["EXECUTE", "REPORT"],
    "MEDIUM": ["INSPECT", "PLAN", "IMPLEMENT", "TEST", "REVIEW",
               "AUDIT", "REPORT"],
    "HIGH": ["INSPECT", "PLAN", "CHECKPOINT", "IMPLEMENT", "TEST",
             "REVIEW", "AUDIT", "REPORT"],
}
CONTRATO = ["Resultado", "Ambiente", "Alteracoes", "Evidencias", "Testes",
            "Validacao", "Pendencias", "Confianca"]


def detect_env(cwd: Path):
    try:
        from ceh_core.environment import detect_environment
        return detect_environment(target_dir=cwd)
    except Exception:
        import os
        import subprocess
        for var in ("CEH_ENV", "APP_ENV", "NODE_ENV"):
            val = os.environ.get(var, "").lower()
            if val:
                env = ("production" if "prod" in val else
                       "staging" if "stag" in val or "homolog" in val
                       else "development")
                return env, f"{var}={val}"
        try:
            branch = subprocess.run(
                ["git", "branch", "--show-current"], cwd=cwd,
                capture_output=True, text=True, timeout=5).stdout.strip()
        except Exception:
            branch = ""
        if branch in ("main", "master"):
            return "production", f"branch {branch}"
        if branch.startswith(("staging", "homolog")):
            return "staging", f"branch {branch}"
        return "development", f"branch {branch or 'no-git'}"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="ceh-dispatch.py")
    ap.add_argument("--task", required=True)
    ap.add_argument("--cwd", default=".")
    ap.add_argument("--with-env", action="store_true",
                    help="forca detect de ambiente mesmo em LOW")
    args = ap.parse_args(argv)
    if not args.task.strip():
        return 2
    try:
        cfg = json.loads(ROUTING.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return 2
    try:
        from route_classify import classify, load_config, norm
        signals = load_config(ROUTING)
        if signals is None:
            return 2
        risco = classify(args.task, signals)
    except Exception:
        return 2
    texto = norm(args.task)
    rota = {"skill": "clearer", "arquivo": "skills/clearer/SKILL.md"}
    for cand in cfg.get("rotas") or []:
        sinais = [norm(str(s)) for s in cand.get("sinais") or []]
        if sinais and any(s in texto for s in sinais):
            rota = {"skill": cand.get("skill"), "arquivo": cand.get("arquivo")}
            break
    classe = risco["classe"]
    # Ambiente sob demanda (SKILL.md §1): LOW leitura nao detecta;
    # MEDIUM/HIGH mutam, entao o safety-gate precisa do ambiente.
    if classe == "LOW" and not args.with_env:
        ambiente, evidencia = "nao-verificado", "skipped: LOW leitura, sem detect"
    else:
        ambiente, evidencia = detect_env(Path(args.cwd))
    print(json.dumps({
        "ambiente": ambiente,
        "evidencia_ambiente": evidencia,
        "risk": classe,
        "tier": risco["tier"],
        "sinais": risco["sinais"],
        "ciclo": CICLOS[classe],
        "rota": rota["skill"],
        "arquivo_referencia": rota["arquivo"],
        "guardrail": "safety-gate:PreToolUse",
        "contrato": CONTRATO,
        "loader_prompt": False,
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
