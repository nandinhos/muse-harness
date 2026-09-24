---
name: clearer
description: Dispatcher do CLEARER Engineering Harness no Muse. Classifica ambiente e Risk Dial, roteia a tarefa pelo ciclo CLEARER e exige contrato de resposta com evidencias.
---

# Clearer Dispatcher (Muse)

Ponto de entrada do **CLEARER Engineering Harness (CEH)** adaptado ao Muse.
Portado de `antigravity-clearer-engineering-harness`: mesmo protocolo, sem
dependência do runtime Antigravity (`agy`, `~/.gemini`, hooks proprietários).

## 1. Identificação de ambiente (obrigatória antes de mutar)

Detecte com evidência (`git branch --show-current`, `APP_ENV`/`CEH_ENV`, `.env*`):

| Ambiente | Sinais neste repo | Rigor |
|---|---|---|
| `DEV` / `TEST` | branch `dev*`, `APP_ENV=local|testing`, `.env` local | `ALLOW`: destrutivos liberados p/ correção, com backup/rollback local. `DENY` mantido p/ catástrofes de SO (`rm -rf /`, fork bomb, `mkfs`, `dd of=/dev/`). |
| `HOMOLOGACAO` | branch `staging|homolog*`, `APP_ENV=staging`, `.env.staging` | `ASK`: 2 alertas explícitos — (1/2) blast radius no ambiente compartilhado, (2/2) backup executado + rollback verificado. |
| `PRODUCAO` | branch `main|master`, `APP_ENV=production` | `DENY`: `migrate:fresh`, `db:wipe`, `DROP/TRUNCATE`, `git reset --hard`, `push --force`, `rm -rf`, `terraform destroy`, `kubectl delete`, `docker system prune -a` são proibidos. |

O hook `safety-gate` emite o veredito no transcript; trate `WARN`/`DENY` dele como vinculante.

## 2. Risk Dial

- **LOW** (leitura, busca, rename local, docs): execução direta, contexto enxuto.
- **MEDIUM** (feature, bugfix, refactor, endpoint, regra de negócio — padrão): **execução contínua em turno único** `INSPECT → PLAN → IMPLEMENT → TEST → REVIEW → AUDIT → REPORT`, sem paradas artificiais.
- **HIGH** (auth core, pagamentos, concorrência, migração destrutiva, segurança): investigação profunda + subagentes nativos com papéis CEH (`investigator` read-only → `architect` plano → `implementer` → `test-engineer` → `reviewer` adversarial → `evidence-auditor`) + checkpoint humano.

O plugin não declara `agents` (família não suportada no Muse): os papéis são desempenhados via subagentes nativos da sessão, um papel por criança, com Evidence Pack entre eles.

## 3. Protocolo CLEARER (resumo operacional)

1. **C — Concrete Goal**: objetivo, aceite, arquivos envolvidos, restrições, condição de parada. Ambiguidade real de negócio → pare e pergunte.
2. **L — Load Context**: *inspect before edit*. Âncoras deste repo: `artisan`, `composer.json`, `routes/`, `app/`, `database/migrations`, `phpunit.xml`, `vendor/bin/pest`, `compose.yaml` / `vendor/bin/sail`, componentes Livewire 4.
3. **E — Explicit Boundaries**: escopo dentro/fora, contratos estáveis, blast radius mínimo. Sem refatoração oportunista nem feature especulativa.
4. **A — Anchors**: código, testes, schemas e migrations existentes prevalecem sobre hipótese do modelo.
5. **R — Response Contract**: Resultado, Ambiente, Alterações, Evidências, Testes, Validação, Pendências, Confiança.
6. **E — Evidence**: observação direta (comando + exit code + saída) sobre suposição. Proibido afirmar "corrigido/testado/sem regressão" sem comando e saída registrados.
7. **R — Review**: `diff-audit` do próprio diff antes de entregar.

## 4. Semântica de evidência (fail-closed)

- `OBSERVED`: comprovado por código lido, comando executado ou teste.
- `INFERRED`: conclusão razoável ainda não demonstrada.
- `UNKNOWN`: sem evidência — reporte como tal, nunca alucine arquivo, classe, método ou regra.

Gestão por exceção: só transfira ao humano (handoff) diante de (1) ambiguidade real, (2) `WARN`/`DENY` do safety-gate, (3) teste falhando após 1 auto-reparo fundamentado, ou (4) risco `HIGH`.

## 5. Roteamento de skills

| Objetivo | Skill |
|---|---|
| Nova funcionalidade | `clearer-feature` |
| Bug / erro / regressão | `clearer-bugfix` (canônica: 5 gates, RFC 2119) ou `debugging` (addon opt-in equivalente) |
| Refatoração sem mudar comportamento | `clearer-refactor` (baseline verde antes/depois) |
| Revisão adversarial de diff | `clearer-review` (7 checks SIM/NÃO, BLOCKER→INFO) |
| Execução auditável de testes | `clearer-test` (contrato COMMAND/EXIT/STATUS) |
| Auditoria de claims | `clearer-audit` (SUPPORTED/PARTIALLY/UNSUPPORTED) |
| Mapa read-only do codebase | `clearer-map` |
| Regras nucleares (env, CI gate, branches) | `clearer-rules` |
| Lição / memória técnica | `learned-lesson` (título≤80 + 4 seções) |
| Hiperfoco / resposta direta (opt-in) | `clearer-adhd` |
| Banca multi-modelo 360º (opt-in) | `conselho-seniores` (`scripts/conselho-seniores.sh`) |
| Auditoria estrutural de docs | `doc-audit` (`scripts/doc-audit.sh`, layout CEH) |
| Economia de tokens (opt-in) | `token-economy` + `code-minimalism` |

## 6. Compatibilidade DEVORQ deste repo

Response Contract alimenta `devorq verify`; commits seguem a convenção do projeto (pt-BR, prefixo `feat|fix|...`, sem `Co-Authored-By`); testes cobrem a área tocada (`vendor/bin/pest` ou `php artisan test`).

## 7. Endosso externo (Context7, opcional)

O núcleo é repo-aterrado: código, comando e teste. Context7 (MCP `context7`, ver `.mcp.json`) endossa SOMENTE fatos externos — comportamento de versão de framework/lib, API canônica upstream. Regras:
- Versão pinada sempre; sem pin, sem endosso.
- Upstream nunca sobrescreve Anchors: se o repo diverge do doc, o repo vence e a divergência vira achado (pin defasado, breaking change, customização local).
- Endosso sem confirmação executável local continua `INFERRED`.
- Sem MCP disponível, pule sem aviso e sem degradar o ciclo.

## 8. Lições aprendidas (persistência)

Todo incidente com causa provada DEVE sair do turno como barreira ou registro, nesta ordem de força: (1) teste de regressão, hook ou gate no repo; (2) runbook; (3) nota de lição no formato canônico — título ≤80, tipo (`error|lesson|best-practice`), stack, escopo + 4 seções (Sintoma, Causa Raiz, Solução Canônica, Regra de Prevenção). Pergunte ao humano antes de persistir em memória; o default é relatório de leitura.
