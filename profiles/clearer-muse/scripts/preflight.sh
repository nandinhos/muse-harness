#!/usr/bin/env bash
# ==============================================================================
# preflight.sh - Inspecao SOB DEMANDA (legado): nunca executado na abertura
# da sessao. Ambiente e guardrails sao resolvidos pelo hook safety-gate
# (PreToolUse); use este script apenas quando uma decisao exige inspecao extra.
# ==============================================================================
set -euo pipefail

echo "=== [CEH Preflight Inspection] ==="
echo "Working Directory: $(pwd)"
echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""

# 1. Git Inspection
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    BRANCH=$(git branch --show-current 2>/dev/null || echo "HEAD detached")
    echo "[GIT] Active Branch: $BRANCH"
    
    MODIFIED_COUNT=$(git status --porcelain | wc -l | tr -d ' ')
    if [[ "$MODIFIED_COUNT" -gt 0 ]]; then
        echo "[GIT] Status: DIRTY ($MODIFIED_COUNT modified/untracked files)"
        echo "[GIT] Uncommitted files:"
        git status --short | head -n 15
        if [[ "$MODIFIED_COUNT" -gt 15 ]]; then
            echo "  ... and $((MODIFIED_COUNT - 15)) more"
        fi
    else
        echo "[GIT] Status: CLEAN (No uncommitted changes)"
    fi
else
    echo "[GIT] Warning: Not inside a git repository."
fi
echo ""

# 2. Environment / Tools check
echo "[TOOLS] Verifying runtime environment:"
for cmd in git bash python3 node npm composer docker; do
    if command -v "$cmd" >/dev/null 2>&1; then
        # Binario presente nao garante resposta (ex.: shim Docker sem
        # integracao WSL sai 1): sonda nao pode matar o preflight.
        VERSION=$("$cmd" --version 2>&1 | head -n 1) || VERSION=""
        if [[ -n "$VERSION" ]]; then
            echo "  - $cmd: AVAILABLE ($VERSION)"
        else
            echo "  - $cmd: PRESENT BUT NOT RESPONDING (--version falhou)"
        fi
    else
        echo "  - $cmd: NOT INSTALLED"
    fi
done
echo ""

# 3. Project-specific stack scan
if [[ -f "$(dirname "$0")/detect-project.sh" ]]; then
    "$(dirname "$0")/detect-project.sh" .
fi

echo "Preflight check completed successfully."
