#!/usr/bin/env python3
"""system_one.py — System One OFFLINE determinístico sobre o diff (Etapa 4, F6).

Subconjunto agnóstico do `ceh_decisions.py` oficial (D2): só o caminho
`FALLBACK_OFFLINE` — sem rede, sem chave, sem API Gemini. Perguntas atômicas
de espaço fechado (SIM/NAO), cada uma com scorer determinístico sobre os
bytes do diff (certeza 1.0 = padrão físico presente/ausente; a semântica
continua do revisor humano/T4). A agregação é código, não opinião.

Uso: `python3 scripts/system_one.py [diff-audit] [--diff-file F] [--human]
[--strict]`. Sem `--diff-file`, lê `git diff HEAD` do repo corrente.
Exits: 0 ok (consultivo); 1 com `--strict` se houver segredo provável;
2 entrada inválida.
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

_AUTH_RE = re.compile(
    r"(?i)\b(auth|login|logout|session|password|passwd|permission|"
    r"authorize|authentication|credential|oauth|jwt)\b")
_MIGRATION_RE = re.compile(
    r"(?i)(^|/)(migrations?|schema)(\.|/)|\b(CREATE|ALTER|DROP)\s+(TABLE|"
    r"DATABASE|SCHEMA|COLUMN)\b|\bmigrate(:fresh|:reset)?\b")
_SECRET_VALUE_RE = re.compile(
    r"sk-[A-Za-z0-9_\-]{16,}|gh[pousr]_[A-Za-z0-9]{16,}|"
    r"github_pat_[A-Za-z0-9_]{16,}|AKIA[0-9A-Z]{12,}|"
    r"xox[baprs]-[A-Za-z0-9\-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|"
    r"(api[_-]?key|client[_-]?secret|access[_-]?token)\s*[:=]\s*"
    r"[\"'][^\"'\s]{12,}[\"']", re.I)
_GATE_RE = re.compile(
    r"(?i)(\.github/workflows/|\.gitlab-ci\.yml|(^|/)hooks?/|\.ceh/|"
    r"safety-gate|plugin\.json)")
_TEST_PATH_RE = re.compile(r"(?i)(^|/)(tests?|__tests__|spec)/|test_[^/]+$|"
                           r"\.test\.|\.spec\.")


def parse_diff(text: str):
    """(arquivos, linhas_adicionadas_sem_header) a partir de um diff unificado."""
    files, added = [], []
    old_path = None
    for line in text.splitlines():
        if line.startswith("--- "):
            old_path = line[4:].strip().removeprefix("a/")
        elif line.startswith("+++ "):
            new_path = line[4:].strip().removeprefix("b/")
            chosen = old_path if new_path == "/dev/null" else new_path
            if chosen and chosen != "/dev/null":
                files.append(chosen)
            old_path = None
        elif line.startswith("+") and not line.startswith("+++"):
            added.append(line[1:])
    return files, added


def _flatten_hits(matches):
    flat = []
    for match in matches:
        if isinstance(match, tuple):
            flat.extend(part for part in match if part)
        elif match:
            flat.append(match)
    return flat


def _q(pid, pergunta, hits):
    return {"id": pid, "pergunta": pergunta,
            "resposta": "SIM" if hits else "NAO", "certeza": 1.0,
            "evidencia": sorted(set(hits))[:5]}


def evaluate(diff_text: str) -> dict:
    files, added = parse_diff(diff_text)
    corpus_paths = "\n".join(files)
    corpus_added = "\n".join(added)
    compact_added = re.sub(r"[\"'\\\s]+", "", corpus_added)
    perguntas = [
        _q("toca_auth", "O diff toca autenticacao/sessao/permissao?",
           _flatten_hits(_AUTH_RE.findall(corpus_paths))
           + _flatten_hits(_AUTH_RE.findall(corpus_added))),
        _q("toca_migracao", "O diff toca migracao/schema de dados?",
           _flatten_hits(_MIGRATION_RE.findall(corpus_paths))
           + _flatten_hits(_MIGRATION_RE.findall(corpus_added))),
        _q("segredo_provavel", "Ha valor com forma de segredo nas linhas novas?",
           ["padrao-segredo"] if (_SECRET_VALUE_RE.search(corpus_added)
                                  or _SECRET_VALUE_RE.search(compact_added))
           else []),
        _q("toca_gate_ci", "O diff toca CI, hooks ou certificados?",
           [f for f in files if _GATE_RE.search(f)]),
        _q("inclui_teste", "O diff inclui ou altera testes?",
           [f for f in files if _TEST_PATH_RE.search(f)]),
        _q("blast_grande", "Blast radius grande (>8 arquivos ou >400 linhas)?",
           [f"{len(files)} arquivos/{len(added)} linhas"]
           if len(files) > 8 or len(added) > 400 else []),
    ]
    by_id = {p["id"]: p["resposta"] for p in perguntas}
    if by_id["segredo_provavel"] == "SIM":
        rec = "BLOQUEAR: segredo provavel no diff; remover e rotacionar"
    elif "SIM" in (by_id["toca_auth"], by_id["toca_migracao"],
                   by_id["toca_gate_ci"]):
        rec = "revisao T4 obrigatoria antes de aprovar"
    elif by_id["blast_grande"] == "SIM":
        rec = "dividir o diff em unidades menores"
    elif by_id["inclui_teste"] == "NAO" and files:
        rec = "sem sinais de risco; considerar teste para a mudanca"
    else:
        rec = "sem sinais deterministicos de risco"
    return {"modo": "FALLBACK_OFFLINE", "perguntas": perguntas,
            "arquivos": len(files), "linhas_adicionadas": len(added),
            "recomendacao": rec}


MAX_DIFF_BYTES = 5_000_000


def read_diff(diff_file):
    if diff_file:
        try:
            path = Path(diff_file)
            if path.stat().st_size > MAX_DIFF_BYTES:
                return None
            return path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            return None
    try:
        res = subprocess.run(["git", "diff", "HEAD"], capture_output=True,
                             timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if res.returncode != 0 or len(res.stdout) > MAX_DIFF_BYTES:
        return None
    return res.stdout.decode("utf-8", errors="replace")


def main(argv=None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if argv and argv[0] == "diff-audit":  # compat com a chamada do upstream
        argv = argv[1:]
    ap = argparse.ArgumentParser(prog="system_one.py")
    ap.add_argument("--diff-file", default=None)
    ap.add_argument("--human", action="store_true")
    ap.add_argument("--strict", action="store_true")
    args = ap.parse_args(argv)

    diff_text = read_diff(args.diff_file)
    if diff_text is None:
        return 2
    result = evaluate(diff_text)
    if args.human:
        print("System One offline (deterministico, sem rede):")
        for p in result["perguntas"]:
            print(f"  {p['id']}: {p['resposta']} (certeza {p['certeza']:.1f})")
        print(f"  recomendacao: {result['recomendacao']}")
    else:
        print(json.dumps(result, ensure_ascii=False))
    secret = any(p["id"] == "segredo_provavel" and p["resposta"] == "SIM"
                 for p in result["perguntas"])
    return 1 if (args.strict and secret) else 0


if __name__ == "__main__":
    sys.exit(main())
