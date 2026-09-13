#!/usr/bin/env python3
"""safety-gate.py — Safety Gate por ambiente para o plugin clearer-muse.

Porte do `safety-gate.py` do CLEARER Engineering Harness (Antigravity),
adaptado ao Muse e a este repositório (Laravel + Sail/Docker).

- Detecta o ambiente (development/staging/production) via variáveis
  (CEH_ENV/APP_ENV/NODE_ENV), arquivos `.env*` e branch Git atual.
- Remove prefixo `rtk ` antes de avaliar (imunidade a evasão via compressor).
- Entrada: `argv[1]` quando presente; senão, tenta JSON no stdin aceitando os
  campos `command`, `tool_input.command` ou `input.command`.
- Saída: linha de veredito `CEH-SAFETY <ALLOW|WARN|DENY> <ambiente> :: motivo`.
- Saída SEMPRE 0 (consultivo): o protocolo de bloqueio do hook do Muse não é
  documentado neste binário, então o veredito orienta o modelo via transcript
  e a skill `clearer` o trata como vinculante. Não inventa negação.
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

CATASTROPHIC = [
    (r"\brm\s+-[rRfF]*[rR][rRfF]*\s+/(?:\s|$)", "delecao recursiva de '/'"),
    (r"\brm\s+-[rRfF]*[rR][rRfF]*\s+~(?:\s|/|$)", "delecao recursiva de '~'"),
    (r"\bmkfs\b", "formatacao de filesystem"),
    (r"\bdd\s+if=.*of=/dev/", "escrita direta em disco via dd"),
    (r":\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:", "fork bomb"),
    (r"\bgcloud\s+projects\s+delete\b", "delecao de projeto GCP"),
]

SAFE_DEV = [
    r"\brm\s+-[rRfF]+\s+(?:/tmp/|tmp/|\.tmp/|scratch/|\.cache/|dist/|build/|storage/framework/cache/|coverage/)",
    r"\brm\s+-[rRfF]*[fF][rRfF]*\s+[a-zA-Z0-9_\-\./]+\.[a-zA-Z0-9]+(?:\s|$)",
    r"\bgit\s+(?:checkout|restore)\s+(?![\.\-]\s*$)[a-zA-Z0-9_\-\./]+(?:\s|$)",
]

DESTRUCTIVE = [
    (r"\bDROP\s+(?:DATABASE|SCHEMA|TABLE|VIEW)\b", "SQL destrutivo (DROP)"),
    (r"\bTRUNCATE(?:\s+TABLE)?\b", "SQL destrutivo (TRUNCATE)"),
    (r"\bDELETE\s+FROM\s+\w+\s*(?:;\s*$|$)", "DELETE sem WHERE"),
    (r"\b(?:artisan|php\s+artisan)\s+migrate:(?:fresh|reset)\b", "migration destrutiva (migrate:fresh/reset)"),
    (r"\b(?:artisan|php\s+artisan)\s+db:wipe\b", "db:wipe"),
    (r"\bgit\s+reset\s+--hard\b", "git reset --hard"),
    (r"\bgit\s+clean\s+-[a-zA-Z]*f", "git clean -f"),
    (r"\bgit\s+push\s+.*(?:--force|\+[a-zA-Z0-9_\-\./]+|(?<!\S)-f(?!\S))", "git push --force"),
    (r"\brm\s+-[rRfF]+", "remocao recursiva/forçada (rm -rf)"),
    (r"\bterraform\s+destroy\b", "terraform destroy"),
    (r"\bkubectl\s+delete\s+(?:namespace|ns|deployment|statefulset|svc|all)\b", "kubectl delete"),
    (r"\bdocker\s+system\s+prune\s+-a\b", "docker system prune -a"),
    (r"\b(?:npm|pnpm|yarn)\s+publish\b", "publicacao de pacote"),
]


def normalize_env(val: str) -> str | None:
    v = val.strip().lower()
    if any(t in v for t in ("prod", "live")):
        return "production"
    if any(t in v for t in ("stag", "homolog", "uat", "qa")):
        return "staging"
    if any(t in v for t in ("dev", "local", "test")):
        return "development"
    return None


def detect_env(cwd: Path) -> tuple[str, str]:
    for var in ("CEH_ENV", "APP_ENV", "NODE_ENV", "ENVIRONMENT", "ENV", "STAGE"):
        raw = os.environ.get(var, "")
        if raw:
            env = normalize_env(raw)
            if env:
                return env, f"variavel {var}={raw}"
    for name, env in ((".env.production", "production"), (".env.staging", "staging"), (".env.homolog", "staging")):
        if (cwd / name).exists():
            return env, f"arquivo {name} presente"
    env_file = cwd / ".env"
    if env_file.exists():
        try:
            for line in env_file.read_text().splitlines():
                m = re.match(r"^(?:CEH_ENV|APP_ENV|NODE_ENV|ENVIRONMENT|ENV|STAGE)=(.*)$", line.strip())
                if m:
                    env = normalize_env(m.group(1).strip().strip("\"'"))
                    if env:
                        return env, f".env ({line.split('=')[0]}={m.group(1)})"
        except OSError:
            pass
    try:
        res = subprocess.run(["git", "branch", "--show-current"], capture_output=True, text=True, timeout=2, cwd=cwd)
        branch = res.stdout.strip() if res.returncode == 0 else ""
        if branch:
            b = branch.lower()
            if b in ("main", "master", "production", "prod"):
                return "production", f"branch '{branch}'"
            if any(t in b for t in ("stag", "homolog", "uat", "qa")):
                return "staging", f"branch '{branch}'"
            return "development", f"branch '{branch}'"
    except Exception:
        pass
    return "development", "fallback (workspace local)"


def extract_command() -> str:
    if len(sys.argv) > 1:
        return sys.argv[1]
    try:
        raw = sys.stdin.read()
    except Exception:
        return ""
    if not raw.strip():
        return ""
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return raw
    if isinstance(payload, dict):
        for key in ("command",):
            if isinstance(payload.get(key), str):
                return payload[key]
        for key in ("tool_input", "input"):
            nested = payload.get(key)
            if isinstance(nested, dict) and isinstance(nested.get("command"), str):
                return nested["command"]
    return raw


def strip_rtk(cmd: str) -> str:
    return re.sub(r"^\s*rtk\s+", "", cmd)


def main() -> int:
    cwd = Path.cwd()
    command = strip_rtk(extract_command())
    env, evidence = detect_env(cwd)
    if not command:
        print(f"CEH-SAFETY ALLOW {env} :: sem comando identificavel ({evidence})")
        return 0
    for pattern, reason in CATASTROPHIC:
        if re.search(pattern, command):
            print(f"CEH-SAFETY DENY {env} :: bloqueio catastrofico: {reason} ({evidence})")
            return 0
    for pattern in SAFE_DEV:
        if re.search(pattern, command):
            print(f"CEH-SAFETY ALLOW {env} :: padrao seguro de dev ({evidence})")
            return 0
    for pattern, reason in DESTRUCTIVE:
        if re.search(pattern, command):
            if env == "production":
                print(f"CEH-SAFETY DENY {env} :: {reason} proibido em producao ({evidence})")
            elif env == "staging":
                print(
                    f"CEH-SAFETY WARN {env} :: {reason} exige 2 alertas: "
                    f"(1/2) blast radius em homologacao, (2/2) backup + rollback verificados ({evidence})"
                )
            else:
                print(f"CEH-SAFETY ALLOW {env} :: {reason} liberado p/ correcao com backup local ({evidence})")
            return 0
    print(f"CEH-SAFETY ALLOW {env} :: sem padrao destrutivo ({evidence})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
