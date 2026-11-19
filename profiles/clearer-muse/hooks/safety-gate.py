#!/usr/bin/env python3
"""safety-gate.py — Host adapter Muse sobre motor `ceh_core` + `adapters` vendored.

Integração absorção-0.9.0: o veredito é calculado pelo motor vendored em
`hooks/vendor/ceh/` (CEH v2.3.1, ref `4db20b7`). Este arquivo é o adapter
do host Muse: roteamento de formato + controles compensatórios locais
documentados em `VENDOR.md` (formas executáveis alternativas, caminhos
sensíveis e comando dinâmico não inspecionável).

Contrato dual (sonda E19: runtime executa o hook do cache, decide pelo stdout):
- stdout: JSON nativo — `{}` (allow) ou `{"decision": "block", "reason"}` (deny/ask),
  exit SEMPRE 0 no caminho de hook (enforcement mecânico).
- stderr: UMA linha `CEH-SAFETY <ALLOW|WARN|DENY> <ambiente> :: <motivo>` como
  trilha auditável (contrato antigo preservado; `ask` vira `WARN` + 2 alertas).
- `--check "<cmd>" [--env E] [--cwd D]` (alias `--command`): delega ao CLI do
  motor (JSON + exit 0/1/2).
- Payloads nativos Muse (`tool_name` minúsculo + `model_provider`/`turn_id`, E19):
  parse/render via `adapters/muse.py` upstream.
- Legados (`command`, `input.command`, `tool_input.command`/`file_path` em nomes
  capitalizados, string bruta): avaliados localmente com o mesmo contrato dual.
"""
from __future__ import annotations

import importlib.util
import io
import json
import os
import re
import shlex
import sys
from contextlib import contextmanager
from pathlib import Path
from typing import Any

HOOKS_DIR = Path(__file__).resolve().parent
VENDOR_DIR = HOOKS_DIR / "vendor" / "ceh"

# Não poluir o vendor com __pycache__ (o canonical-diff.sh compara -r).
sys.dont_write_bytecode = True

sys.path.insert(0, str(VENDOR_DIR))

try:
    from ceh_core.engine import (  # noqa: E402
        Decision,
        Request,
        evaluate,
        evaluate_command,
        is_protected_target,
    )
    from ceh_core.environment import detect_environment  # noqa: E402
    from adapters.muse import MuseAdapter  # noqa: E402

    _spec = importlib.util.spec_from_file_location(
        "ceh_safety_gate", VENDOR_DIR / "safety-gate.py"
    )
    _ceh_gate = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(_ceh_gate)
    _MUSE = MuseAdapter()
    ENGINE_OK = True
    ENGINE_ERR = ""
except Exception as exc:  # motor ausente/quebrado: fail-closed no main
    ENGINE_OK = False
    ENGINE_ERR = str(exc)


def _first_line(reason: str) -> str:
    return next((ln for ln in reason.splitlines() if ln.strip()), "")


def _verdict_line(decision: str, env: str, reason: str) -> str:
    verdict = {"allow": "ALLOW", "ask": "WARN", "deny": "DENY"}.get(decision, "DENY")
    return f"CEH-SAFETY {verdict} {env} :: {_first_line(reason)}"


def _emit(decision: str, env: str, reason: str) -> int:
    """Contrato dual: JSON nativo no stdout, trilha CEH-SAFETY no stderr. Exit 0."""
    first = _first_line(reason)
    if decision == "allow":
        payload: dict[str, Any] = {}
    else:
        payload = {"decision": "block", "reason": first}
    sys.stdout.write(json.dumps(payload, ensure_ascii=False))
    sys.stdout.flush()
    sys.stderr.write(_verdict_line(decision, env, reason) + "\n")
    sys.stderr.flush()
    return 0


def _warn_reason(reason: str) -> str:
    return (
        "exige 2 alertas (1/2 impacto, 2/2 backup+rollback): " + _first_line(reason)
    )


@contextmanager
def _in_cwd(target: Path | str | None):
    """Avalia sob chdir (fiel ao hook_context upstream), restaurando depois."""
    if target is None:
        yield
        return
    original = os.getcwd()
    try:
        os.chdir(target)
        yield
    finally:
        try:
            os.chdir(original)
        except OSError:
            pass


def _detect_env(explicit_env: str | None, cmd_line: str, target_dir: Path):
    try:
        return detect_environment(explicit_env, cmd_line, target_dir=target_dir)
    except Exception:
        return explicit_env or "production", "falha na detecção (fail-closed)"


def _inside_plugin(path: Path) -> bool:
    try:
        path.relative_to(HOOKS_DIR.parent)
        return True
    except ValueError:
        return False


def _is_comment_only(cmd: str) -> bool:
    lines = [ln.strip() for ln in cmd.splitlines() if ln.strip()]
    return bool(lines) and all(ln.startswith("#") for ln in lines)


_DYNAMIC_HEAD_RE = re.compile(
    r"(?:^|[;&|]\s*)(?:[A-Za-z_][A-Za-z0-9_]*=\S+\s+)*[\"']?"
    r"\$(?:\{[A-Za-z_][A-Za-z0-9_]*\}|[A-Za-z_][A-Za-z0-9_]*)(?:[\"']|\s|$)")
_DYNAMIC_EVAL_RE = re.compile(
    r"(?:^|[;&|]\s*)(?:[A-Za-z_][A-Za-z0-9_]*=\S+\s+)*eval\b[^;&|]*\$")
_DYNAMIC_INTERP_RE = re.compile(
    r"(?i)\b(?:os\.(?:system|popen)|subprocess\.\w+|"
    r"child_process\.\w+|execSync|spawnSync|system)\s*\([^\n;]*"
    r"(?:os\.environ|environ\.get|process\.env|ENV\[|getenv\s*\()")


def _terminal_decision(cmd: str, explicit_env: str | None, eval_cwd: Path,
                       force_deny_push: bool) -> tuple[str, str, str, str]:
    """Avalia terminal sem emitir; exceções do motor viram deny (fail-closed)."""
    if _is_comment_only(cmd):
        env, ev = _detect_env(explicit_env, "", eval_cwd)
        return "allow", f"apenas comentário de shell ({ev})", env, "GENERAL"
    if (_DYNAMIC_HEAD_RE.search(cmd) or _DYNAMIC_EVAL_RE.search(cmd)
            or _DYNAMIC_INTERP_RE.search(cmd)):
        env, _ev = _detect_env(explicit_env, cmd, eval_cwd)
        return (
            "deny",
            "[CEH SAFETY GATE - FAIL-CLOSED] Comando dinâmico não "
            "inspecionável: valor executável resolvido só em runtime.",
            env,
            "DYNAMIC_UNINSPECTABLE",
        )
    if force_deny_push and re.search(r"\bgit\s+push\b", cmd):
        return (
            "deny",
            "[CEH PRE-PUSH CI GATE] Push bloqueado: "
            "repositório de destino não resolvido a partir do hook.",
            "production",
            "PRE_PUSH_CI",
        )
    try:
        return evaluate_command(cmd, explicit_env, base_cwd=eval_cwd)
    except Exception as exc:
        return (
            "deny",
            "[CEH SAFETY GATE - FAIL-CLOSED] Falha ao avaliar comando "
            f"({exc.__class__.__name__}).",
            explicit_env or "production",
            "SYSTEM_FAIL_CLOSED",
        )


_SENSITIVE_BASENAMES = {
    "auth.json", ".credentials.json", "credentials", ".netrc",
    "login data", "cookies",
}
_SENSITIVE_SUFFIXES = (".pem", ".key", ".p12", ".pfx")


def _is_sensitive_path(raw: str, cwd: Path) -> bool:
    """Caminhos de credencial conhecidos; só bloqueia lojas de segredo."""
    expanded = Path(os.path.expanduser(raw.strip().strip("'\"")))
    full = expanded if expanded.is_absolute() else cwd / expanded
    try:
        full = full.resolve(strict=False)
    except (OSError, RuntimeError):
        pass
    parts = [p.lower() for p in full.parts]
    base = parts[-1] if parts else ""
    if any(p in (".ssh", ".gnupg", ".aws") for p in parts):
        return True
    if base in _SENSITIVE_BASENAMES or base.startswith(
            ("id_rsa", "id_ed25519", "id_ecdsa", "id_dsa")):
        return True
    if base.endswith(_SENSITIVE_SUFFIXES):
        return True
    if base == ".env":
        return True
    if base.startswith(".env.") and not base.endswith(
            (".sample", ".example", ".template", ".dist")):
        return True
    return False


_EXEC_KEYS = {
    "command", "cmd", "commandline", "shell", "script", "code",
    "chars", "stdin", "exec", "executable",
}
_LIST_KEYS = {"args", "argv"}
_PATH_KEYS = {"path", "filepath", "targetfile", "filename", "file"}


def _norm_key(key: Any) -> str:
    return re.sub(r"[^a-z0-9]", "", str(key).lower())


def _collect_unknown_forms(value: Any, depth: int = 0,
                           ignore_keys: frozenset[str] = frozenset()):
    """Extrai (comandos, paths, malformado) de formas alternativas de tool."""
    commands: list[str] = []
    paths: list[str] = []
    malformed = False
    if depth > 6:
        return commands, paths, True
    if isinstance(value, dict):
        for raw_key, item in value.items():
            key = _norm_key(raw_key)
            if key in ignore_keys:
                continue
            if key in _EXEC_KEYS or key in _LIST_KEYS:
                if isinstance(item, str):
                    if item.strip():
                        commands.append(item)
                elif isinstance(item, list):
                    if item and all(isinstance(x, str) for x in item):
                        commands.append(shlex.join(item))
                    elif item:
                        malformed = True
                elif isinstance(item, dict):
                    sub_c, sub_p, sub_bad = _collect_unknown_forms(
                        item, depth + 1, ignore_keys)
                    commands += sub_c
                    paths += sub_p
                    malformed = malformed or sub_bad
                elif item is not None:
                    malformed = True
                continue
            if key in _PATH_KEYS:
                if isinstance(item, str):
                    if item.strip():
                        paths.append(item.strip())
                elif item is not None:
                    malformed = True
                continue
            sub_c, sub_p, sub_bad = _collect_unknown_forms(
                item, depth + 1, ignore_keys)
            commands += sub_c
            paths += sub_p
            malformed = malformed or sub_bad
    elif isinstance(value, list):
        for item in value:
            sub_c, sub_p, sub_bad = _collect_unknown_forms(
                item, depth + 1, ignore_keys)
            commands += sub_c
            paths += sub_p
            malformed = malformed or sub_bad
    return commands, paths, malformed


# ---------------------------------------------------------------------------
# Caminho nativo: payload Muse (E19) via adapters/muse.py upstream
# ---------------------------------------------------------------------------


def _handle_unknown_tool(payload: dict[str, Any], tool: str) -> int:
    """Despacho por forma (delta local D4): o runtime roteia TODAS as ferramentas
    pelo PreToolUse (E19 + pós-restart: read_file/read_skill também disparam).
    Bloquear ferramenta desconhecida quebra o harness (regressão v0.9.0), então:
    - com forma executável reconhecível (`command`, `cmd`, `chars`,
      `script`, `code`, `args`, aninhado em `input`, ...) → avaliada como
      terminal (fecha bypass via ferramentas futuras e `bash_input`);
    - forma executável/arquivo mal-tipada → malformado (fail-closed);
    - com alvo em `.ceh/` ou loja de credencial conhecida → block;
    - sem forma executável/arquivo (meta/leitura: read_skill, search, …) →
      passthrough ALLOW auditado.
    """
    ti_raw = payload.get("tool_input")
    if ti_raw is not None and not isinstance(ti_raw, dict):
        return _emit("deny", "production", "tool_input não-objeto (fail-closed)")
    ti = ti_raw if isinstance(ti_raw, dict) else {}
    # muse.workflow: `script` é JS de orquestração; cada tool filha volta
    # ao PreToolUse. Não avaliar esse campo como shell (falso positivo).
    ignore_keys = (frozenset({"script"})
                   if _norm_key(tool).endswith("workflow")
                   else frozenset())
    commands, paths, malformed = _collect_unknown_forms(ti, 0, ignore_keys)
    top_commands, top_paths, top_bad = _collect_unknown_forms(
        {k: v for k, v in payload.items() if k != "tool_input"},
        0, ignore_keys)
    commands += top_commands
    paths += top_paths
    malformed = malformed or top_bad
    if malformed:
        return _emit("deny", "production",
                     "forma executável/arquivo mal-tipada (fail-closed)")
    try:
        eval_cwd, explicit_env, force_deny_push = _MUSE.resolve_target(payload)
    except ValueError as exc:
        return _emit("deny", "production", f"alvo inválido (fail-closed): {exc}")
    cwd = eval_cwd if eval_cwd is not None else Path.cwd()
    for path in paths:
        env, _ev = _detect_env(explicit_env, "", cwd)
        if is_protected_target(path, cwd):
            return _emit(
                "deny", env,
                f"[CEH CERTIFICATE INTEGRITY - G9] Ferramenta '{tool}' tocando "
                f".ceh/ ({path}) sem semântica conhecida (fail-closed).",
            )
        if _is_sensitive_path(path, cwd):
            return _emit(
                "deny", env,
                f"[CEH SENSITIVE PATH] Ferramenta '{tool}' tocando loja "
                f"de credencial conhecida ({path}); acesso bloqueado.",
            )
    if commands:
        rank = {"allow": 1, "ask": 2, "deny": 3}
        chosen = None
        for cmd in commands:
            dec = _terminal_decision(
                cmd, explicit_env, cwd, force_deny_push)
            if chosen is None or rank.get(dec[0], 3) > rank.get(chosen[0], 3):
                chosen = dec
        decision, reason, env, _uc = chosen
        if decision == "ask":
            reason = _warn_reason(reason)
        return _emit(decision, env, reason)
    if paths:
        env, _ev = _detect_env(explicit_env, "", cwd)
        return _emit("allow", env, f"ferramenta não-coberta '{tool}' fora de .ceh/ (passthrough auditado)")
    env, ev = _detect_env(explicit_env, "", cwd)
    return _emit("allow", env, f"ferramenta não-coberta '{tool}' sem forma executável (passthrough auditado; {ev})")


def _handle_native(payload: dict[str, Any]) -> int:
    tool = str(payload.get("tool_name", "") or "").strip()
    if tool and tool not in _MUSE.SUPPORTED_TOOLS:
        return _handle_unknown_tool(payload, tool)
    try:
        req: Request = _MUSE.parse(payload)
    except ValueError as exc:
        resp, _ = _MUSE.render_error(str(exc), payload)
        return _emit("deny", "production", str(resp.get("reason", exc)))
    except Exception as exc:
        resp, _ = _MUSE.render_error(f"Falha ao avaliar payload do hook: {exc}", payload)
        return _emit("deny", "production", str(resp.get("reason", exc)))
    with _in_cwd(req.cwd):
        if req.target_paths:
            cwd = Path(req.cwd).resolve() if req.cwd else Path.cwd()
            sensitive = [p for p in req.target_paths
                         if not is_protected_target(p, cwd)
                         and _is_sensitive_path(p, cwd)]
            if sensitive:
                env, _ev = _detect_env(req.explicit_env, "", cwd)
                return _emit(
                    "deny", env,
                    "[CEH SENSITIVE PATH] Escrita em loja de credencial "
                    f"conhecida ({sensitive[0]}); acesso bloqueado.")
            try:
                dec: Decision = evaluate(req)
            except Exception as exc:
                return _emit(
                    "deny", "production",
                    "[CEH SAFETY GATE - FAIL-CLOSED] Falha ao avaliar "
                    f"alvo ({exc.__class__.__name__}).")
        else:
            cwd = Path(req.cwd).resolve() if req.cwd else Path.cwd()
            d, r, e, _u = _terminal_decision(
                req.command, req.explicit_env, cwd, False)
            dec = Decision(decision=d, reason=r, environment=e)
    reason = _warn_reason(dec.reason) if dec.decision == "ask" else dec.reason
    return _emit(dec.decision, dec.environment, reason)


# ---------------------------------------------------------------------------
# Caminho legado: formatos antigos e argv/stdin sem envelope Muse
# ---------------------------------------------------------------------------


def _legacy_target(payload: dict[str, Any]) -> tuple[Path, str | None, bool]:
    """Resolve (eval_cwd, explicit_env, force_deny_push) sem depender do dispatcher.

    Sem localização no payload, herda o cwd (comportamento legado) exceto dentro
    do plugin (P0/G6: fail-closed para production).
    """
    ti_raw = payload.get("tool_input")
    ti = ti_raw if isinstance(ti_raw, dict) else {}
    raw = ti.get("workdir") or payload.get("cwd")
    if raw is not None and not isinstance(raw, str):
        return Path.cwd(), "production", True
    if isinstance(raw, str) and raw:
        cand = Path(os.path.expanduser(raw))
        if cand.is_absolute() and cand.is_dir():
            return cand.resolve(), None, False
        return Path.cwd(), "production", True
    cwd = Path.cwd()
    if _inside_plugin(cwd.resolve()):
        return cwd, "production", True
    return cwd, None, False


def _legacy_extract(payload: dict[str, Any]) -> tuple[str, str, str]:
    """Devolve (kind, tool, value): kind ∈ {terminal, file, none, malformed}."""
    if "toolCall" in payload:
        return ("malformed", "", "formato estrangeiro (toolCall Antigravity)")
    tool = str(payload.get("tool_name", "") or payload.get("tool", "") or "")
    # Fail-closed estrito (conselho F4.2): chave presente com tipo errado é
    # payload malformado (o hook_context antigo levantava ValueError aqui).
    ti_raw = payload.get("tool_input")
    if ti_raw is not None and not isinstance(ti_raw, dict):
        return ("malformed", "", "tool_input não-objeto (fail-closed)")
    ti = ti_raw if isinstance(ti_raw, dict) else {}
    if "command" in ti and not isinstance(ti["command"], str):
        return ("malformed", "", "tool_input.command não-string (fail-closed)")
    if ("path" in ti and not isinstance(ti["path"], str)) or (
        "file_path" in ti and not isinstance(ti["file_path"], str)
    ):
        return ("malformed", "", "tool_input.path não-string (fail-closed)")
    cmd = ti.get("command")
    if isinstance(cmd, str) and cmd.strip():
        return ("terminal", tool, cmd)
    path = ti.get("path") or ti.get("file_path")
    if isinstance(path, str) and path.strip():
        return ("file", tool, path.strip())
    if "command" in payload and not isinstance(payload["command"], str):
        return ("malformed", "", "command não-string (fail-closed)")
    cmd = payload.get("command")
    if cmd is None and "input" in payload and not isinstance(payload["input"], dict):
        return ("malformed", "", "input não-objeto (fail-closed)")
    if not isinstance(cmd, str):
        nested = payload.get("input")
        cmd = nested.get("command") if isinstance(nested, dict) else None
        if cmd is not None and not isinstance(cmd, str):
            return ("malformed", "", "input.command não-string (fail-closed)")
    if isinstance(cmd, str) and cmd.strip():
        return ("terminal", tool, cmd)
    for key in ("file_path", "path"):
        val = payload.get(key)
        if val is not None and not isinstance(val, str):
            return ("malformed", "", f"{key} não-string (fail-closed)")
        if isinstance(val, str) and val.strip():
            return ("file", tool, val.strip())
    if tool or ti or payload.get("cwd") is not None:
        return ("none", tool, "")
    return ("malformed", "", "envelope JSON sem ferramenta identificável")


def _legacy_terminal(cmd: str, explicit_env: str | None, eval_cwd: Path,
                     force_deny_push: bool) -> int:
    decision, reason, env, _use_case = _terminal_decision(
        cmd, explicit_env, eval_cwd, force_deny_push)
    if decision == "ask":
        reason = _warn_reason(reason)
    return _emit(decision, env, reason)


def _legacy_file(target: str, explicit_env: str | None, eval_cwd: Path) -> int:
    env, _ev = _detect_env(explicit_env, "", eval_cwd)
    if not is_protected_target(target, eval_cwd) and _is_sensitive_path(
            target, eval_cwd):
        return _emit(
            "deny", env,
            "[CEH SENSITIVE PATH] Escrita em loja de credencial "
            f"conhecida ({target}); acesso bloqueado.")
    if is_protected_target(target, eval_cwd):
        return _emit(
            "deny",
            env,
            "[CEH CERTIFICATE INTEGRITY - G9] Tentativa de escrita em "
            f"certificado de CI ({target}). Arquivos sob .ceh/ são imutáveis "
            "via ferramentas de escrita.",
        )
    return _emit("allow", env, f"escrita fora de .ceh/ ({target})")


def _handle_legacy(payload: dict[str, Any]) -> int:
    eval_cwd, explicit_env, force_deny_push = _legacy_target(payload)
    kind, _tool, value = _legacy_extract(payload)
    if kind == "terminal":
        return _legacy_terminal(value, explicit_env, eval_cwd, force_deny_push)
    if kind == "file":
        return _legacy_file(value, explicit_env, eval_cwd)
    if kind == "none":
        env, ev = _detect_env(explicit_env, "", eval_cwd)
        return _emit("allow", env, f"sem comando identificavel ({ev})")
    return _emit("deny", "production", f"payload malformado (fail-closed): {value}")


def _handle_payload(payload: dict[str, Any]) -> int:
    if _MUSE.detect(payload):
        return _handle_native(payload)
    return _handle_legacy(payload)


def main() -> int:
    if not ENGINE_OK:
        sys.stdout.write(
            json.dumps(
                {"decision": "block", "reason": f"motor ceh_core indisponível: {ENGINE_ERR}"}
            )
        )
        sys.stdout.flush()
        sys.stderr.write(
            "CEH-SAFETY DENY unknown :: motor ceh_core indisponível "
            f"(fail-closed): {ENGINE_ERR}\n"
        )
        return 0
    if len(sys.argv) > 1 and sys.argv[1] in ("--check", "--command"):
        check_cmd = sys.argv[2] if len(sys.argv) > 2 else ""
        if _is_comment_only(check_cmd):
            print(json.dumps({
                "decision": "allow",
                "reason": "apenas comentário de shell",
                "environment": "development",
                "use_case": "GENERAL",
                "command": check_cmd,
            }, indent=2, ensure_ascii=False))
            return 0
        try:
            _ceh_gate.main()  # delega: JSON + exit 0/1/2 do motor
        except SystemExit:
            raise
        except Exception as exc:
            print(json.dumps({
                "decision": "deny",
                "reason": "[CEH SAFETY GATE - FAIL-CLOSED] Falha ao "
                          f"avaliar comando ({exc.__class__.__name__}).",
                "environment": "production",
                "use_case": "SYSTEM_FAIL_CLOSED",
                "command": check_cmd,
            }, indent=2, ensure_ascii=False))
            return 2
        return 0
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        try:
            as_payload = json.loads(cmd)
        except ValueError:
            as_payload = None
        if isinstance(as_payload, dict):
            # Harness passou o payload via argv: roteia p/ o handler de
            # payload em vez de avaliar o JSON como shell.
            try:
                return _handle_payload(as_payload)
            except Exception as exc:
                return _emit(
                    "deny", "production",
                    "[CEH SAFETY GATE - FAIL-CLOSED] Falha ao avaliar "
                    f"payload ({exc.__class__.__name__}).")
        if not cmd.strip():
            env, ev = _detect_env(None, "", Path.cwd())
            return _emit("allow", env, f"sem comando identificavel ({ev})")
        return _legacy_terminal(cmd, None, Path.cwd(), False)
    try:
        raw = sys.stdin.read()
    except Exception:
        raw = ""
    if not raw.strip():
        env, ev = _detect_env(None, "", Path.cwd())
        return _emit("allow", env, f"sem comando identificavel ({ev})")
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return _legacy_terminal(raw, None, Path.cwd(), False)
    if not isinstance(payload, dict):
        return _legacy_terminal(raw, None, Path.cwd(), False)
    try:
        return _handle_payload(payload)
    except Exception as exc:
        return _emit(
            "deny", "production",
            "[CEH SAFETY GATE - FAIL-CLOSED] Falha ao avaliar "
            f"payload ({exc.__class__.__name__}).")


if __name__ == "__main__":
    sys.exit(main())
