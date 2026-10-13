#!/usr/bin/env bash
# test_manifest.sh — Contrato do perfil muse-ceh v0.2.1 (dispatcher sem hook).
# Uso: bash profiles/muse-ceh/tests/test_manifest.sh   (exit 0 = PASS)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
m = json.loads((root / ".muse-plugin/plugin.json").read_text())
assert m["name"] == "muse-ceh", m["name"]
assert m["version"] == "0.2.1", m["version"]
caps = m["capabilities"]
# Hook unico e o do clearer-muse: este perfil nao declara hook algum.
assert caps.get("hooks") == [], caps.get("hooks")
# ponytail: sem duplicar o canonico — hooks/ e scripts/ vivem no clearer-muse.
assert not (root / "hooks").exists(), "hooks/ duplicado do canonico"
assert not (root / "scripts").exists(), "scripts/ duplicado do canonico"
for group in ("skills", "commands"):
    for item in caps[group]:
        assert (root / item["path"]).is_file(), item["path"]
skill = (root / "skills/muse-ceh/SKILL.md").read_text()
assert "clearer-muse" in skill and "CEH v2.1.2" in skill
assert "anexosauti" in skill  # personalizacao PHP preservada
print("PASS muse-ceh manifest v0.2.1 (sem hook, paths ok, skill alinhada)")
PY
