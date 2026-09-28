# HANDOFF — Integração do motor `ceh_core` (handoff-060) no `clearer-muse` v0.7.0

> Para o agente que assumir em `/home/nandodev/projects/muse-harness`.
> Origem (só-leitura, NÃO mexer): `/home/nandodev/projects/clearer-engineering-harness/`
> (`staging` == `origin/staging` @ `525da48`; vendor extraído da ref validada `1b26e10`).

## 1. O que foi feito (branch `dev`, NÃO commitado)

Integração agnóstica multi-harness (handoff-060, Opção B vendored). Manifest
`0.6.0` → `0.7.0`.

| Entrega | Arquivos |
|---|---|
| Motor vendored (13 arquivos, byte-identical) | `hooks/vendor/ceh/{ceh_core/,safety-gate.py,hook_context.py}` + `VENDOR.md` (sha `c43c8be4…`) |
| Adapter fino do host (zero regra; contrato `CEH-SAFETY` + exit 0 mantido; `--check` delega com exit 0/1/2) | `hooks/safety-gate.py` (reescrito) |
| Runner emite `canonical_verified` + lê `.ceh/config.json` do HEAD + suprime cert com worktree suja | `scripts/test-runner.sh` |
| F4 hermético (sandbox sem CI), F4c novo (dev+CI sem cert → DENY), F10/F11 (fixture canônica + refspec `dev`) | `evals/run.sh` |
| Contrato handoff §6 + stdin/G9/CC1/fail-closed (12 asserts) | `tests/test_ceh_core_contract.sh` (novo; [4/4] em `run-all-tests.sh`) |
| Proveniência CEH v1.3.0 + schema do cert + fecha-furo force-push | `skills/clearer-rules/SKILL.md` |

## 2. Decisões que precisam de ciência (não reverter sem ler)

1. **F4 mudou de cenário (não de intenção)**: o motor aplica o Pre-Push CI Gate
   a TODO push em repo com CI, inclusive `--force` (PR-08/G7). O F4 antigo
   dependia do furo do gate antigo (force-push isento) + estado do próprio
   repo. F4 agora é hermético (sandbox sem CI → ALLOW); o cenário antigo virou
   F4c (dev+CI sem cert → DENY). Trocar de volta = reabrir o furo.
2. **CC1**: fork bomb `:(){ :|:& };:` retorna `allow` no motor puro (lexer
   fragmenta; OBSERVED dev e production). O adapter aplica
   `CATASTROPHIC_PATTERNS` do próprio motor na linha bruta antes de delegar.
   Zero lógica duplicada. Remover quando o upstream corrigir.
3. **Modo hook segue consultivo (exit 0)**: protocolo de bloqueio do Muse não
   é documentado; o veredito via transcript continua vinculante pela skill
   `clearer`. Só `--check` usa exit 0/1/2.
4. **Passthrough para ferramentas sem comando/alvo** (leituras): o hook do
   Muse não tem matcher por ferramenta; fail-closed total negaria `Read`.

## 3. Estado verificado (OBSERVED 2026-09-28)

- [x] `bash profiles/clearer-muse/tests/run-all-tests.sh` → 4/4 verdes (53 asserts: 16+13+12+12)
- [x] `bash evals/run.sh` 3× verde (2s/2s/3s, baseline CRITERIA)
- [x] `bash -n` nos `.sh` alterados + `git diff --check` + sem `__pycache__` no vendor
- [ ] Commitar em PT-BR + push (seguir convenção do repo)
- [ ] Reinstalar plugin (`./install.sh` ou `muse plugins`) + **restart da sessão**
- [ ] `bash profiles/clearer-muse/scripts/canonical-diff.sh` → IDÊNTICO

## 4. Backlog (fora deste escopo)

- Runner não copia `.ceh/last-ci-run.log` (D3/`evidence_report.py` não portado).
- Reportar fork-bomb-allow ao CEH upstream (remover CC1 após correção).
- `diff-audit.sh`/`ceh-help.sh` seguem adaptações (CEH intocado neles desde o port).
