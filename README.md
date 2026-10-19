# muse-harness — CLEARER Engineering Harness for Muse Code

<p align="center">
  <img src="img/CLEARER-MUSE.jpg" alt="Filosofia CLEARER: Engenharia de Precisão sob Incerteza — Evidência antes de Afirmação" width="100%">
</p>

<p align="center">
  <strong>Disciplina verificável sobre talento presumido.</strong><br>
  <em>Verified discipline over presumed talent.</em>
</p>

<p align="center">
  <a href="#-português-pt-br">Português (PT-BR)</a> ·
  <a href="#-english-en-us">English (EN-US)</a> ·
  <a href="docs/CREATE-PROFILE.md">Guide</a> ·
  <a href="HANDOFF.md">Handoff</a>
</p>

---

## 🇧🇷 Português (PT-BR)

Casa canônica dos **profiles harness do Muse Code**: metodologia de engenharia
empacotada como plugin nativo — protocolo CLEARER, rigor por ambiente, contrato
de resposta com evidências e economia de tokens — instalável em qualquer projeto.

> **Evidência antes de afirmação.** Nenhuma conclusão avança sem artefato
> observável. Qualidade é propriedade do processo, não heroísmo individual.

### Os 7 pilares (ver imagem acima)

| # | Pilar | Na prática |
|---|-------|------------|
| 1 | Orientação a evidências, não autoridade | Código é fonte da verdade; `OBSERVED / INFERRED / UNKNOWN` |
| 2 | Risco calibrado | Risk Dial `LOW / MEDIUM / HIGH`; checkpoints em áreas críticas |
| 3 | Ambiente declarado | Branch + `APP_ENV`/`CEH_ENV` + `.env*`; fail-closed (`ALLOW / ASK / DENY`) |
| 4 | Escopo disciplinado | Fronteiras explícitas; sem refatoração oportunista |
| 5 | Gestão por exceção | Fluxo autônomo; humano só ante ambiguidade real, `DENY` ou risco `HIGH` |
| 6 | Verificação independente | Testes do repo + `diff-audit` do próprio diff antes de entregar |
| 7 | Melhoria contínua como rotina | Falhas viram gates permanentes (ADRs, hooks, regressões) |

### O profile `clearer-muse` v0.10.0

| Capacidade | Estado |
|------------|--------|
| Dispatcher `clearer` (ciclo + Risk Dial + contrato) | ativo |
| Addon `token-economy` (tetos 8k/4k/2k/1k, compressão, higiene) | ativo |
| Addon `code-minimalism` (ordem nativo→mínimo, marcação `ponytail:`) | opt-in |
| Addon `debugging` (5 gates bloqueantes, relatório lesson-ready) | opt-in |
| Hook `safety-gate` (`PreToolUse`, veredito vinculante) | ativo |
| Motor CEH v2.1.2 vendorizado (`hooks/vendor/ceh/`, sha em `VENDOR.md`) | ativo |
| 15 skills (incl. `clearer-bugfix`, `conselho-seniores` opt-in) | ativo |
| Suíte do profile 9/9 + smoke-eval 16/16 (`tests/run-all-tests.sh`) | ativo |
| Profile pessoal `muse-ceh` v0.2.1 (dispatcher, sem hook próprio) | ativo |
| Trava Pre-Push CI Gate (tolerância zero + Certificado de Voo) | ativo |
| Runtime & CI Strategy Awareness (`RUNTIME_MODE` + `ci-cmd`) | ativo |
| Invariantes System One (7, em `clearer-review`/`clearer-audit`) | ativo |
| Heartbeat 25s p/ testes async (`scripts/heartbeat.sh`) | ativo |
| Endosso Context7 (fatos externos, provado fim-a-fim) | operacional |
| Segredos no repo | zero (só `${VAR}`, chave no host) |

### Estrutura

```text
profiles/clearer-muse/        # cópia canônica: skills, commands, hooks, scripts, manifest
  skills/{clearer,clearer-feature,clearer-bugfix,clearer-refactor,clearer-review,
    clearer-test,clearer-audit,clearer-map,clearer-rules,clearer-adhd,token-economy,
    code-minimalism,debugging,conselho-seniores,learned-lesson}/   # 15 skills
  commands/{clearer.md,token-report.md}
  hooks/{safety-gate.py (adapter fino),vendor/ceh/ (motor CEH v2.1.2)}
  scripts/{canonical-diff.sh,ceh-help.sh,compress-output.sh,conselho-seniores.sh,
    detect-project.sh,diff-audit.sh,doc-audit.py,doc-audit.sh,evidence-report.sh,
    evidence_report.py,heartbeat.sh,preflight.sh,setup-branches.sh,task-monitor.sh,
    test-runner.sh,token-budget.py}                                 # 16 arquivos
  tests/{run-all-tests.sh + 8 suítes de contrato/regressão}
profiles/muse-ceh/              # dispatcher pessoal v0.2.1 (skill + comando + teste, sem hook)
docs/CREATE-PROFILE.md        # guia: criar um profile harness do zero
templates/mcp.json            # base MCP (só `${VAR}`, sem segredos)
adr/001…005                   # decisões: Context7, lições, minimalismo, hook órfão, governança CEH
evals/                        # smoke-eval do safety-gate (16 asserts, CRITERIA.md pré-registrado)
img/CLEARER-MUSE.jpg          # filosofia em uma imagem
HANDOFF.md                    # handoff canônico (os HANDOFF-*.md são registros históricos)
install.sh / uninstall.sh     # instalação local ou remota (clone da branch dev)
LICENSE                       # MIT
```

### Rigor por ambiente

| Branch | Ambiente | Rigor |
|--------|----------|-------|
| `dev*` | desenvolvimento | `ALLOW` (destrutivos p/ correção, com rollback) |
| `staging`/`homolog*` | homologação | `ASK` (blast radius + backup verificados) |
| `main` | produção | `DENY` (wipe, `reset --hard`, `push --force`, `rm -rf`…) |

Fluxo de promoção deste repo: `dev` → `main` (clássico), sempre fast-forward, sem
force; `scripts/setup-branches.sh` também cria a topologia enterprise
`dev` → `staging` → `main` em outros projetos.

### Início rápido

```bash
# 1. Sanidade
python3 -c "import json; json.load(open('profiles/clearer-muse/.muse-plugin/plugin.json'))"
# 2. Instale (local) ou aponte a fonte instalada p/ profiles/clearer-muse e reinicie
./install.sh --scope user          # ou: muse plugins update clearer-muse (restart: ADR-004)
# 3. Suíte completa do profile (esperado: 9/9 PASS, exit 0)
bash profiles/clearer-muse/tests/run-all-tests.sh
# 4. Anti-deriva
profiles/clearer-muse/scripts/canonical-diff.sh [<destino>]
```

Detalhes: [guia](docs/CREATE-PROFILE.md) · [handoff](HANDOFF.md).

### Regras deste repo

- Nenhum segredo commitado (varredura `sk-*`/`Bearer` antes de cada push).
- PT-BR nos docs; commits `feat|fix|docs|…` (≤72 chars, sem `Co-Authored-By`).
- Toda afirmação técnica com fonte: arquivo, comando+saída ou teste.

---

## 🇺🇸 English (EN-US)

Canonical home of **Muse Code harness profiles**: engineering methodology
packaged as a native plugin — CLEARER protocol, per-environment rigor,
evidence-backed response contract, and token economy — installable in any project.

> **Evidence before assertion.** No conclusion advances without an observable
> artifact. Quality is a property of the process, not individual heroism.

### The 7 pillars (see image above)

| # | Pillar | In practice |
|---|--------|-------------|
| 1 | Evidence-driven, not authority-driven | Code is the source of truth; `OBSERVED / INFERRED / UNKNOWN` |
| 2 | Calibrated risk | `LOW / MEDIUM / HIGH` Risk Dial; checkpoints for critical areas |
| 3 | Declared environment | Branch + `APP_ENV`/`CEH_ENV` + `.env*`; fail-closed (`ALLOW / ASK / DENY`) |
| 4 | Disciplined scope | Explicit boundaries; no opportunistic refactoring |
| 5 | Management by exception | Autonomous flow; human paged only on real ambiguity, `DENY`, or `HIGH` risk |
| 6 | Independent verification | Repo tests + self `diff-audit` before delivery |
| 7 | Continuous improvement as routine | Failures become permanent gates (ADRs, hooks, regressions) |

### The `clearer-muse` profile v0.10.0

| Capability | Status |
|------------|--------|
| `clearer` dispatcher (cycle + Risk Dial + contract) | enabled |
| `token-economy` addon (8k/4k/2k/1k budgets, compression, hygiene) | enabled |
| `code-minimalism` addon (native→minimal order, `ponytail:` marks) | opt-in |
| `debugging` addon (5 blocking gates, lesson-ready report) | opt-in |
| `safety-gate` hook (`PreToolUse`, binding verdict) | enabled |
| Vendored CEH v2.1.2 engine (`hooks/vendor/ceh/`, sha in `VENDOR.md`) | enabled |
| 15 skills (incl. opt-in `clearer-bugfix`, `conselho-seniores`) | enabled |
| Profile suite 9/9 + smoke-eval 16/16 (`tests/run-all-tests.sh`) | enabled |
| Personal `muse-ceh` v0.2.1 profile (dispatcher, no own hook) | enabled |
| Pre-Push CI Gate (zero tolerance + Flight Certificate) | enabled |
| Runtime & CI Strategy Awareness (`RUNTIME_MODE` + `ci-cmd`) | enabled |
| System One invariants (7, in `clearer-review`/`clearer-audit`) | enabled |
| 25s heartbeat for async tests (`scripts/heartbeat.sh`) | enabled |
| Context7 endorsement (external facts, proven end-to-end) | operational |
| Secrets in repo | zero (`${VAR}` only, key lives on host) |

### Layout

Same tree as above: `profiles/clearer-muse/` (canonical source, 15 skills,
16 script files, 9-suite `tests/`), `profiles/muse-ceh/` (personal dispatcher
v0.2.1), `docs/`, `templates/mcp.json`, `adr/001–005`, `evals/` (16 asserts),
`img/CLEARER-MUSE.jpg`, `HANDOFF.md`, `install.sh`, `LICENSE` (MIT).

### Rigor per environment

| Branch | Environment | Rigor |
|--------|-------------|-------|
| `dev*` | development | `ALLOW` (destructive ops for fixes, with rollback) |
| `staging`/`homolog*` | staging | `ASK` (blast radius + verified backup) |
| `main` | production | `DENY` (wipes, `reset --hard`, `push --force`, `rm -rf`…) |

Promotion flow in this repo: `dev` → `main` (classic), always fast-forward,
never force; `scripts/setup-branches.sh` also creates the enterprise
`dev` → `staging` → `main` topology for other projects.

### Quickstart

```bash
# 1. Sanity
python3 -c "import json; json.load(open('profiles/clearer-muse/.muse-plugin/plugin.json'))"
# 2. Install locally or point the installed source at profiles/clearer-muse, then restart
./install.sh --scope user          # or: muse plugins update clearer-muse (restart: ADR-004)
# 3. Full profile suite (expected: 9/9 PASS, exit 0)
bash profiles/clearer-muse/tests/run-all-tests.sh
# 4. Anti-drift
profiles/clearer-muse/scripts/canonical-diff.sh [<target>]
```

Details: [guide](docs/CREATE-PROFILE.md) · [handoff](HANDOFF.md).

### Assumptions & gaps

- Assumes Muse Code loads plugins from the registered source at boot
  (observed via `installed.json`); `npx -y @upstash/context7-mcp` is taken as
  the official Context7 server distribution.
- Local plugin (re)install uses the official `muse plugins install|update`
  CLI (wrapped by `install.sh`, observed working); the exact anonymous
  Context7 quota remains unknown — assumed limited.

---

*PT-BR é o idioma canônico deste repo; a seção em inglês é tradução fiel.*
*PT-BR is this repo's canonical language; the English section is a faithful translation.*
