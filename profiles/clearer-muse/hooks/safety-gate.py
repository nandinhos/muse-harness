#!/usr/bin/env python3
"""safety-gate.py — Host adapter Muse sobre o motor de políticas `ceh_core`.

Integração handoff-060 (Opção B, vendored): o veredito é calculado pelo motor
vendored em `hooks/vendor/ceh/` (CEH v1.3.0, ref `1b26e10`). Este arquivo contém
ZERO lógica de regra — só adaptação de formato para o protocolo nativo do Muse.

- `--check "<cmd>" [--env E]`: delega ao CLI do motor (JSON + exit 0/1/2).
- `argv[1]` (comando) ou JSON no stdin (PreToolUse): avalia e emite UMA linha
  `CEH-SAFETY <ALLOW|WARN|DENY> <ambiente> :: <motivo>`, exit SEMPRE 0
  (contrato consultivo: veredito via transcript, tratado como vinculante
  pela skill `clearer`; `ask` do motor vira `WARN` com os 2 alertas).
- Payloads aceitos no stdin: formatos CEH (`toolCall`, `tool_input`/`tool_name`,
  `cwd`) e legados Muse (`command`, `input.command`, string bruta).
- CC1 (compensatório, ver `vendor/ceh/VENDOR.md`): `CATASTROPHIC_PATTERNS` do
  próprio motor aplicados na linha bruta antes de delegar, pois o lexer FSM
  fragmenta pipelines e o fork bomb não casaria em nenhum fragmento.
"""

import importlib.util
import io
import json
import os
import re
import sys
from pathlib import Path

HOOKS_DIR = Path(__file__).resolve().parent
VENDOR_DIR = HOOKS_DIR / "vendor" / "ceh"

# Não poluir o vendor com __pycache__ (o canonical-diff.sh compara -r).
sys.dont_write_bytecode = True

sys.path.insert(0, str(VENDOR_DIR))

try:
    from ceh_core.environment import detect_environment
    from ceh_core.rules import CATASTROPHIC_PATTERNS
    import hook_context

    _spec = importlib.util.spec_from_file_location(
        "ceh_safety_gate", VENDOR_DIR / "safety-gate.py"
    )
    _ceh_gate = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(_ceh_gate)
    evaluate_command = _ceh_gate.evaluate_command
    ENGINE_OK = True
    ENGINE_ERR = ""
except Exception as exc:  # motor ausente/quebrado: fail-closed no main
    ENGINE_OK = False
    ENGINE_ERR = str(exc)


def _verdict_line(decision: str, env: str, reason: str) -> str:
    first = next((ln for ln in reason.splitlines() if ln.strip()), "")
    verdict = {"allow": "ALLOW", "ask": "WARN", "deny": "DENY"}.get(decision, "DENY")
    return f"CEH-SAFETY {verdict} {env} :: {first}"


def _detect_env(explicit_env, cmd_line: str, target_dir: Path):
    try:
        return detect_environment(explicit_env, cmd_line, target_dir=target_dir)
    except Exception:
        return explicit_env or "production", "falha na detecção (fail-closed)"


def _cc1_catastrophic(raw_cmd: str, explicit_env, eval_cwd: Path):
    """CC1: padrões catastróficos do motor sobre a linha bruta. Retorna a linha
    de veredito ou None."""
    for pattern, desc in CATASTROPHIC_PATTERNS:
        if re.search(pattern, raw_cmd, re.IGNORECASE):
            env, ev = _detect_env(explicit_env, raw_cmd, eval_cwd)
            return f"CEH-SAFETY DENY {env} :: bloqueio catastrofico: {desc} ({ev})"
    return None


def _inside_plugin(path: Path) -> bool:
    try:
        path.relative_to(HOOKS_DIR.parent)
        return True
    except ValueError:
        return False


def _resolve_eval_context(payload: dict):
    """Devolve (eval_cwd, explicit_env, force_deny_push). Sem localização no
    payload, herda o cwd (comportamento legado) exceto dentro do plugin
    (P0/G6: fail-closed para production)."""
    target_dir, explicit_env, force_deny_push = hook_context.resolve_hook_target(payload)
    if target_dir is not None:
        return target_dir, explicit_env, force_deny_push
    cwd = Path.cwd()
    if _inside_plugin(cwd.resolve()):
        return cwd, "production", True
    return cwd, None, False


def _extract_terminal_command(payload: dict):
    """Extrai (tool_name, command) nos formatos CEH ou legados Muse."""
    if "toolCall" in payload or "tool_input" in payload or "tool_name" in payload:
        return hook_context.extract_hook_command(payload)  # pode levantar ValueError
    cmd = payload.get("command")
    if not isinstance(cmd, str):
        nested = payload.get("input")
        cmd = nested.get("command") if isinstance(nested, dict) else None
    tool = payload.get("tool") or payload.get("name") or ""
    return str(tool), cmd if isinstance(cmd, str) else ""


def _extract_file_target(payload: dict) -> str:
    target = hook_context.extract_file_write_target("", payload)
    if target:
        return target
    for key in ("file_path", "path"):
        val = payload.get(key)
        if isinstance(val, str) and val.strip():
            return val.strip()
    return ""


def _evaluate_terminal(cmd: str, explicit_env, eval_cwd: Path, force_deny_push: bool) -> str:
    if force_deny_push and hook_context.is_git_push_command(cmd):
        return (
            "CEH-SAFETY DENY production :: [CEH PRE-PUSH CI GATE] Push bloqueado: "
            "repositório de destino não resolvido a partir do hook."
        )
    cc1 = _cc1_catastrophic(cmd, explicit_env, eval_cwd)
    if cc1 is not None:
        return cc1
    decision, reason, env, _use_case = evaluate_command(
        cmd, explicit_env, base_cwd=eval_cwd
    )
    if decision == "ask":
        reason = (
            "exige 2 alertas (1/2 impacto, 2/2 backup+rollback): "
            + next((ln for ln in reason.splitlines() if ln.strip()), "")
        )
    return _verdict_line(decision, env, reason)


def _evaluate_file_write(target: str, explicit_env, eval_cwd: Path) -> str:
    env, _ev = _detect_env(explicit_env, "", eval_cwd)
    if hook_context.is_protected_cert_file(target, eval_cwd):
        return (
            f"CEH-SAFETY DENY {env} :: [CEH CERTIFICATE INTEGRITY - G9] "
            f"Tentativa de escrita em certificado de CI ({target}). "
            "Arquivos sob .ceh/ são imutáveis via ferramentas de escrita."
        )
    return f"CEH-SAFETY ALLOW {env} :: escrita fora de .ceh/ ({target})"


def _handle_payload(payload: dict) -> str:
    try:
        eval_cwd, explicit_env, force_deny_push = _resolve_eval_context(payload)
    except ValueError as exc:
        return f"CEH-SAFETY DENY production :: payload malformado (fail-closed): {exc}"
    try:
        _tool, cmd = _extract_terminal_command(payload)
    except ValueError as exc:
        return f"CEH-SAFETY DENY production :: payload malformado (fail-closed): {exc}"
    if cmd.strip():
        return _evaluate_terminal(cmd, explicit_env, eval_cwd, force_deny_push)
    target = _extract_file_target(payload)
    if target:
        return _evaluate_file_write(target, explicit_env, eval_cwd)
    env, ev = _detect_env(explicit_env, "", eval_cwd)
    return f"CEH-SAFETY ALLOW {env} :: sem comando identificavel ({ev})"


def main() -> int:
    if not ENGINE_OK:
        print(
            f"CEH-SAFETY DENY unknown :: motor ceh_core indisponível "
            f"(fail-closed): {ENGINE_ERR}"
        )
        return 0
    if len(sys.argv) > 1 and sys.argv[1] == "--check":
        _ceh_gate.main()  # delega: JSON + exit 0/1/2 do motor
        return 0
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        cwd = Path.cwd()
        if not cmd.strip():
            env, ev = _detect_env(None, "", cwd)
            print(f"CEH-SAFETY ALLOW {env} :: sem comando identificavel ({ev})")
            return 0
        print(_evaluate_terminal(cmd, None, cwd, False))
        return 0
    try:
        raw = sys.stdin.read()
    except Exception:
        raw = ""
    if not raw.strip():
        env, ev = _detect_env(None, "", Path.cwd())
        print(f"CEH-SAFETY ALLOW {env} :: sem comando identificavel ({ev})")
        return 0
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        print(_evaluate_terminal(raw, None, Path.cwd(), False))
        return 0
    if not isinstance(payload, dict):
        print(_evaluate_terminal(raw, None, Path.cwd(), False))
        return 0
    print(_handle_payload(payload))
    return 0


if __name__ == "__main__":
    sys.exit(main())
