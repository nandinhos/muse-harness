#!/usr/bin/env python3
"""safety-gate.py — Host adapter Muse sobre motor `ceh_core` + `adapters` vendored.

Integração absorção-0.9.0: o veredito é calculado pelo motor vendored em
`hooks/vendor/ceh/` (CEH v2.1.2, ref `76eaf76`). Este arquivo contém ZERO
lógica de regra — só roteamento de formato para o protocolo nativo do Muse.

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


# ---------------------------------------------------------------------------
# Caminho nativo: payload Muse (E19) via adapters/muse.py upstream
# ---------------------------------------------------------------------------


def _handle_native(payload: dict[str, Any]) -> int:
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
            dec: Decision = evaluate(req)
        else:
            d, r, e, _u = evaluate_command(
                req.command, explicit_env=req.explicit_env, base_cwd=req.cwd
            )
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
    ti = payload.get("tool_input")
    ti = ti if isinstance(ti, dict) else {}
    raw = ti.get("workdir") or payload.get("cwd")
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
    ti = payload.get("tool_input")
    ti = ti if isinstance(ti, dict) else {}
    cmd = ti.get("command")
    if isinstance(cmd, str) and cmd.strip():
        return ("terminal", tool, cmd)
    path = ti.get("path") or ti.get("file_path")
    if isinstance(path, str) and path.strip():
        return ("file", tool, path.strip())
    cmd = payload.get("command")
    if not isinstance(cmd, str):
        nested = payload.get("input")
        cmd = nested.get("command") if isinstance(nested, dict) else None
    if isinstance(cmd, str) and cmd.strip():
        return ("terminal", tool, cmd)
    for key in ("file_path", "path"):
        val = payload.get(key)
        if isinstance(val, str) and val.strip():
            return ("file", tool, val.strip())
    if tool or ti or payload.get("cwd") is not None:
        return ("none", tool, "")
    return ("malformed", "", "envelope JSON sem ferramenta identificável")


def _legacy_terminal(cmd: str, explicit_env: str | None, eval_cwd: Path,
                     force_deny_push: bool) -> int:
    if force_deny_push and re.search(r"\bgit\s+push\b", cmd):
        return _emit(
            "deny",
            "production",
            "[CEH PRE-PUSH CI GATE] Push bloqueado: "
            "repositório de destino não resolvido a partir do hook.",
        )
    decision, reason, env, _use_case = evaluate_command(
        cmd, explicit_env, base_cwd=eval_cwd
    )
    if decision == "ask":
        reason = _warn_reason(reason)
    return _emit(decision, env, reason)


def _legacy_file(target: str, explicit_env: str | None, eval_cwd: Path) -> int:
    env, _ev = _detect_env(explicit_env, "", eval_cwd)
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
        _ceh_gate.main()  # delega: JSON + exit 0/1/2 do motor (--env/--cwd inclusos)
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
            return _handle_payload(as_payload)
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
    return _handle_payload(payload)


if __name__ == "__main__":
    sys.exit(main())
