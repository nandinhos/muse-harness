#!/usr/bin/env bash
# ==============================================================================
# ceh-help.sh - Guia rapido do CLEARER Muse Harness (porte de
# clearer-engineering/scripts/ceh-help.sh, adaptado ao Muse e a este repo).
# ==============================================================================
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

cat << "EOF"
  +===================================================================+
  |    CLEARER Muse Harness — Guia Rapido                              |
  |         Evidence-Driven Engineering no Muse Code                    |
  +===================================================================+
EOF

echo ""
echo -e "${BOLD}${CYAN}SCRIPTS DO PROFILE (profiles/clearer-muse/scripts/):${NC}"
echo -e "  ${GREEN}detect-project.sh${NC}    : stack, ambiente (DEV/STAGING/PROD) e runtime Docker/Sail"
echo -e "  ${GREEN}test-runner.sh${NC}       : suite canonica + Certificado de Voo (.ceh/last-ci-run.json)"
echo -e "  ${GREEN}preflight.sh${NC}         : diagnostico de prontidao (git, toolchains, stack)"
echo -e "  ${GREEN}diff-audit.sh${NC}        : higiene do git diff antes de entregar"
echo -e "  ${GREEN}canonical-diff.sh${NC}    : diff canonico p/ review"
echo -e "  ${GREEN}doc-audit.sh${NC}         : auditoria estrutural da documentacao (layout CEH)"
echo -e "  ${GREEN}evidence-report.sh${NC}   : gerador de Evidence Report padronizado"
echo -e "  ${GREEN}setup-branches.sh${NC}    : topologia canonica (Enterprise 3-branch / Classico 2-branch)"
echo -e "  ${GREEN}task-monitor.sh${NC}      : monitor de tarefas com heartbeat de 25s"
echo -e "  ${GREEN}conselho-seniores.sh${NC} : banca multi-modelo (add-on opcional do desenvolvedor)"
echo -e "  ${GREEN}ceh-help.sh${NC}          : este guia"

echo ""
echo -e "${BOLD}${CYAN}NIVEIS DE RIGOR POR AMBIENTE (SAFETY GATE):${NC}"
echo -e "  ${GREEN}DEV (branch dev)${NC}       : ${BOLD}ALLOW${NC} — liberdade p/ testes e correcoes (com backup local)."
echo -e "  ${YELLOW}STAGING (homolog)${NC}      : ${BOLD}ASK (2 Alertas)${NC} — blast radius + backup/rollback verificados."
echo -e "  ${RED}PRODUCAO (main)${NC}        : ${BOLD}DENY${NC} — comandos destrutivos bloqueados."
echo -e "  ${RED}CATASTROFICO${NC}          : ${BOLD}DENY Absoluto${NC} — 'rm -rf /', fork bombs e mkfs em qualquer ambiente."

echo ""
echo -e "${BOLD}${CYAN}TOPOLOGIAS DE BRANCHES SUPORTADAS:${NC}"
echo -e "  ${BOLD}1. Modo Enterprise (3 branches)${NC}: dev -> staging -> main (esteiras formais)"
echo -e "  ${BOLD}2. Modo Classico (2 branches)${NC}  : dev -> main (agil, MVPs)"
echo -e "  ${BLUE}Derivacoes${NC}                       : partem sempre de dev/ (ex: dev/feature-x)"

echo ""
echo -e "${BOLD}${CYAN}SKILLS DO PROFILE:${NC}"
echo -e "  ${BLUE}clearer${NC}          : dispatcher geral e seletor de Risk Dial (LOW/MEDIUM/HIGH)"
echo -e "  ${BLUE}clearer-feature${NC}  : features orientadas a evidencias"
echo -e "  ${BLUE}clearer-bugfix${NC}   : workflow Root-Cause First (5 gates, RFC 2119)"
echo -e "  ${BLUE}debugging${NC}        : addon opt-in equivalente (usar um dos dois)"
echo -e "  ${BLUE}clearer-refactor${NC} : refatoracao segura com baseline"
echo -e "  ${BLUE}clearer-review${NC}   : revisao adversarial de diff"
echo -e "  ${BLUE}clearer-test${NC}     : testes deterministicos com evidencias"
echo -e "  ${BLUE}clearer-audit${NC}    : auditoria de claims (SUPPORTED/PARTIALLY/UNSUPPORTED)"
echo -e "  ${BLUE}clearer-map${NC}      : mapeamento read-only do repo"
echo -e "  ${BLUE}clearer-rules${NC}    : normativo (env, CI gate, branches, Ponytail, System One)"
echo -e "  ${BLUE}conselho-seniores${NC}: banca multi-modelo (add-on opcional)"
echo -e "  ${BLUE}clearer-adhd${NC}     : comunicacao executiva (opt-in)"
echo -e "  ${BLUE}token-economy${NC}    + ${BLUE}code-minimalism${NC}: higiene de contexto/tokens"

echo ""
echo -e "${BOLD}${CYAN}COMANDOS:${NC}"
echo -e "  ${BLUE}/clearer${NC} (ou /clearer <objetivo>) : ciclo CLEARER sobre o escopo"
echo -e "  ${BLUE}/token-report${NC}                     : relatorio de tokens da sessao"

echo ""
