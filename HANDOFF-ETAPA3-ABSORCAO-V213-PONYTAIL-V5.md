# HANDOFF — Etapa 3: Absorção CEH v2.1.3 + Ponytail v5 no porte Muse

| Campo | Valor |
|---|---|
| Status | **EXECUTADO** — Fases 1–5 commitadas na branch da etapa; Fase 6 (validação final + ativação) registrada ao final deste arquivo. Push/promoção aguardam `go` separado |
| Fonte (read-only) | Oficial `nandinhos/antigravity-clearer-engineering-harness`, delta `316c0e1..origin/main` (`550848a`): 6 commits sem merge, 30 arquivos |
| Último marco absorvido | Etapa 2 (M1–M4, oficial `459d15a`+`316c0e1`) → porte `7f31fa6`, release v0.10.0 (`ef13379`) |
| Base desta etapa | `origin/main` do muse-harness em `ef13379` (checkout local está em `c00c06e`/v0.9.0 — fast-forward é o passo 0) |
| Governança | Oficial só no Antigravity (Muse = read-only lá); esta etapa é exclusiva do Muse. Teto local **V2** |
| Deriva instalada | Plugins ativos: `clearer-muse` 0.9.0 e `muse-ceh` 0.2.0; fonte já é 0.10.0/0.2.1. Um único `plugins update` + restart ao final desta etapa resolve tudo |

## Baseline OBSERVED (worktree destacada em `ef13379`, 2026-10-22)

| Prova | Comando | Resultado |
|---|---|---|
| Suíte do profile | `bash profiles/clearer-muse/tests/run-all-tests.sh` (da raiz do repo) | exit 0, **9/9**, 135 asserts (16+15+16+16+28+6+18+7+13) |
| Meta-eval | `bash evals/run.sh` | exit 0, 16/16 |
| Manifest | `muse plugins validate profiles/clearer-muse` | válido, 15 skills, 2 commands, 1 hook, diagnostics=0 |
| Vendor (C13) | sha256 do bundle em `hooks/vendor/ceh/` | `39db9e70…` = valor em `VENDOR.md` (ref `76eaf76`, CEH v2.1.2) |

Armadilhas OBSERVED na sessão de análise (valem para a execução):

- Rodar a suíte de outro cwd reprova `smoke-doc-audit-*`: o `doc-audit` resolve a raiz pelo git do cwd. Sempre rodar da raiz do muse-harness.
- O `safety-gate` reprova quoting complexo (`${...}` em aspas) fail-closed: comandos compostos vão em arquivo `.sh`, nunca inline multi-linha.

## Delta oficial não absorvido — classificação arquivo a arquivo

| Arquivo oficial | Lote | Classe | Destino no porte Muse |
|---|---|---|---|
| `scripts/evidence_report.py` | fixes 19/10 | **ADAPTAR** | `profiles/clearer-muse/scripts/evidence_report.py` (`inspect_integrations`) |
| `tests/test_evidence_report.py` | fixes 19/10 | **ADAPTAR** | casos novos em `tests/test_evidence_contract.sh` (E29+) |
| `tests/run-fast-tests.sh` | fixes 19/10 | NÃO PORTAR | porte não tem suíte fast; timing sub-segundo sem consumidor |
| `scripts/test-runner.sh` | v2.1.3 | **ADAPTAR** | `profiles/clearer-muse/scripts/test-runner.sh` (estrutura própria, 108 linhas ≠ 188 do oficial — nunca sobrescrever) |
| `scripts/detect-project.sh` | v2.1.3 | **ADAPTAR** | idem, versão resumida do porte |
| `scripts/doc-audit.py` | v2.1.3 | **ADAPTAR** | check de frontmatter só p/ `skills/*/SKILL.md` (`name:`+`description:`); `rules/` e `trigger:` não existem no Muse |
| `rules/AGENTS.md` | v2.1.3 + v5 | **ADAPTAR** | `skills/clearer-rules/SKILL.md` §4 (escada v5) + dispatcher (Heurística 12, sem duplicar texto) |
| `rules/coding-policy.md` | v2.1.3 + v5 | **ADAPTAR** | `clearer-rules` §4 (convenção `shortcut:`) |
| `rules/git-safety.md` | v2.1.3 | **ADAPTAR** | nova seção em `clearer-rules` (padrão de commit pt-BR canônico) |
| `skills/clearer-review/SKILL.md` | v5 | **ADAPTAR** | `skills/clearer-review/SKILL.md`: § callers fora do diff + finding em 4 partes + desfecho lean |
| `skills/clearer/SKILL.md` | v2.1.3 | NÃO PORTAR | `RequestFeedback`/`ask_question` são do Antigravity; em HOMOLOGAÇÃO o Muse já converte `ask`→`block` no hook (v0.9.0/E19) |
| `skills/clearer-feature/SKILL.md` | v2.1.3 | NÃO PORTAR | idem (`implementation_plan.md` com `RequestFeedback`) |
| `agents/reviewer/agent.md` | v5 | NÃO PORTAR | Muse não suporta família `agents`; a semântica aterrissa em `clearer-review` |
| `scripts/adapters/antigravity.py` | v2.1.3 | **RE-VENDOR** | único drift do bundle vendorizado (+5/−1, texto `ask_question` no adapter Antigravity — inerte no Muse, adapter ativo é `muse.py`) |
| `hooks.json` | v2.1.3 | NÃO PORTAR | porte usa `command: ["python3", "hooks/safety-gate.py"]` no manifest, resolvido pelo runtime Muse |
| `config/aliases.sh`, `scripts/rc_aliases.py`, `scripts/ceh-help.sh` (aliases) | v2.1.3 | NÃO PORTAR | porte não tem sistema de aliases nem `ceh-doctor`/`ceh-report`; `ceh-help.sh` local já lista os scripts reais |
| `plugin.json` (2.1.3), `tests/test_content_schema.py` | v2.1.3 | NÃO PORTAR | semver próprio do porte; validação de frontmatter vai ao `doc-audit`, não a suíte nova |
| `docs/coding_standards.md`, `docs/installation.md`, `docs/skills_and_commands.md`, handoff-086, manifest Onda 4 | v2.1.3/v5 | NÃO PORTAR | docs do host Antigravity sem equivalente; o conteúdo normativo já entra via `clearer-rules` |
| `CHANGELOG.md`, `HANDOFF.md`, `README*.md`, `clearer-engineering/README.md` | v2.1.3/v5 | DOC | espelhar em `README.md` + `HANDOFF.md` do porte na fase de release |

## Divergências que o plano precisa resolver (não copiar)

1. **`inspect_integrations` do porte valida menos que o oficial pós-fix.** Hoje: `plugin.json` não-dict vira `hooks=[]` silencioso; `.mcp.json` não-dict/`mcpServers` não-dict são ignorados; `parts[0]` do comando do hook nunca é validado; executável MCP relativo só é buscado no cwd (não junto ao arquivo). Os fixes oficiais `2d7b5f5`/`f9a22ed` fecham exatamente isso — adaptar às fontes Muse (`plugin.json` com `command` em lista; `shlex` + salto de prefixos `ENV=` só onde o comando é string; bit `+x` só p/ executável direto, nunca p/ script via interpretador). Preservar o delta local `detect_env()`.
2. **Marcador de atalho divergente.** Oficial v5 canoniza `// shortcut: <teto>, <gatilho>`; o addon `code-minimalism` do porte usa `ponytail:` sem teto/gatilho. Proposta: adotar `shortcut:` como canônico nas duas skills e registrar `ponytail:` como legado aceito na leitura.
3. **Escada Ponytail em dois lugares e versões.** `clearer-rules` §4 resume a escada antiga (5 perguntas); `code-minimalism` tem ordem própria de 4 itens. Proposta: escada v5 de 7 degraus mora **só** em `clearer-rules` §4; `code-minimalism` passa a referenciá-la (sem duplicar — regra da Etapa 2).
4. **Formato de finding.** Porte usa 5 bullets (Arquivo/Problema/Impacto/Evidência/Correção); v5 usa 4 partes numeradas (O que é/Problema/Correção/Se ignorarmos) + encerramento (Veredito, Potencial Lean, Não Verificado). Substituir no `clearer-review`, mantendo os 7 checks System One e as severidades atuais.
5. **Proibição de inline multi-linha.** A justificativa oficial (`permission_grant_store.go`) é do Antigravity; no Muse a regra equivalente se justifica pelo fail-closed do `safety-gate` p/ quoting complexo (OBSERVED nesta análise). Portar a regra com a justificativa local, em `clearer-rules`.

## Plano de adequação (fases sequenciais; parar no primeiro vermelho)

### Fase 0 — Sincronizar e baseline (sem edição de conteúdo)

1. `git merge --ff-only origin/main` no checkout local (`c00c06e` → `ef13379`) e branch `dev-absorcao-v213-ponytail-v5` a partir dela.
2. Baseline verde da raiz do repo: `run-all-tests.sh` (9/9, 135), `evals/run.sh` (16/16), `muse plugins validate`. Vermelho aqui = reportar e parar.

### Fase 1 — Evidência: `inspect_integrations` (lote `2d7b5f5` + `f9a22ed`)

1. Adaptar `profiles/clearer-muse/scripts/evidence_report.py`:
   - `plugin.json` não-dict → entrada `pending` (hoje é silencioso).
   - Validar `parts[0]`: binário via `shutil.which`, ou caminho local existente (+`os.X_OK` quando executável direto); em comando string, `shlex.split` saltando prefixos `ENV=valor`.
   - MCP: arquivo não-dict e `mcpServers` não-dict → `pending`; executável local buscado também junto ao arquivo (`.mcp.json`/`templates/mcp.json`) e exigido `+x`.
2. Casos novos em `tests/test_evidence_contract.sh` (E29+), primeiro vermelho sem o fix, depois verde: (a) `parts[0]` ausente no PATH → `pending`/`FALHOU`; (b) `plugin.json` lista → `pending`; (c) `.mcp.json` lista → `pending`; (d) `mcpServers` lista → `pending`; (e) MCP sem `command` → `pending` (fecha pendência INFO da Etapa 2); (f) MCP local sem `+x` → `pending`; (g) prefixo `ENV=` em comando string válido → `validated`.
3. Commit atômico: `fix (evidencia): valida executavel e estrutura em inspect_integrations`.

### Fase 2 — Scripts v2.1.3 (lote `d7b8559`, só o portável)

1. `test-runner.sh` do porte: ignorar stub `"no test specified"` na detecção npm; ler `docker_service` de `.ceh/config.json` (do HEAD, mesmo canal do `canonical_test_command`); candidatos Compose `app|web|php|backend` no runtime adapter, preservando `laravel.test`/Sail e o fallback atual.
2. `detect-project.sh` do porte: escolher serviço primário (`app|web|php|backend`, senão o primeiro ativo) na linha `local-exec`.
3. `doc-audit.py` do porte: novo check — todo `profiles/*/skills/*/SKILL.md` (layout Muse) começa com frontmatter contendo `name:` e `description:`. Sem `trigger:` (Antigravity).
4. Provas: smoke existente + caso vermelho→verde do frontmatter quebrado (fixture temporária); `test_scripts_smoke.sh` verde sem perder asserts.
5. Commit atômico: `feat (scripts): absorve melhorias v2.1.3 de runner, detect e doc-audit`.

### Fase 3 — Re-vendor do motor (drift de 1 arquivo)

1. `git archive 550848a` dos paths de `VENDOR.md` no checkout oficial; conferir que o diff do bundle é só `adapters/antigravity.py` (+5/−1); copiar e atualizar ref + sha256 em `hooks/vendor/ceh/VENDOR.md`.
2. Provas: C13 (sha confere), `test_ceh_core_contract.sh`, `test_host_parity.sh`, `test_conformance_muse.sh` verdes. Alternativa rejeitada por ora: isenção via ADR — o procedimento de re-vendor já existe e o diff é mínimo.
3. Commit atômico: `chore (vendor): atualiza motor CEH vendorizado para 550848a`.

### Fase 4 — Ponytail v5 nas skills (lote `1926ac5`)

1. `skills/clearer-rules/SKILL.md` §4: escada de 7 degraus (incl. Degrau 7 = teste cirúrgico p/ lógica arriscada), inspeção de chamadores fora do diff, convenção `shortcut:` (teto + gatilho, `no-trigger` proibido), Ponytail Ultra. §3 (branches) já está no formato resumido v5 — não tocar. Nova seção curta: padrão de commit pt-BR (de `git-safety`) + proibição de inline multi-linha com justificativa Muse (divergência 5).
2. `skills/code-minimalism/SKILL.md`: remover a ordem própria e referenciar `clearer-rules` §4; marcador passa a `shortcut:` (legado `ponytail:` aceito na leitura).
3. `skills/clearer-review/SKILL.md`: nova seção de rastreio de código conectado (callers via busca no repo, carga esperada/races/N+1); finding em 4 partes substituindo o formato atual; encerramento com Veredito + Potencial Lean + Não Verificado. Manter invariantes System One e os 7 checks.
4. `skills/clearer/SKILL.md` (dispatcher): 1 linha da Heurística 12 (frase curta de progresso em cadeias >2 ferramentas) e atualizar a linha de proveniência do motor p/ v2.1.3/`550848a`. Sem duplicar a escada.
5. Commit atômico: `feat (ponytail): eleva regras e revisao do porte ao padrao v5`.

### Fase 5 — Release e docs (lotes `da0469e` + `75ed4f5`, espelho local)

1. Bump `profiles/clearer-muse/.muse-plugin/plugin.json` 0.10.0 → **0.11.0**; `muse-ceh` intocado (0.2.1).
2. `README.md` (PT+EN): versão, proveniência "CEH v2.1.3 + Ponytail v5 (`550848a`)", contagens reais pós-fases. `HANDOFF.md` §2 sincronizado. Este arquivo vira o registro da etapa (status → concluído, com evidências).
3. Commit atômico: `chore (release): prepara release v0.11.0 do clearer-muse`.

### Fase 6 — Validação final e ativação

| Prova | Comando | Esperado |
|---|---|---|
| Suíte completa | `bash profiles/clearer-muse/tests/run-all-tests.sh` | exit 0, 9/9, asserts = 135 + novos (registrar o N exato) |
| Meta-eval | `bash evals/run.sh` | exit 0, 16/16 |
| Certificado | `bash profiles/clearer-muse/scripts/test-runner.sh bash evals/run.sh` | `.ceh/last-ci-run.json` PASS no HEAD final, worktree limpa |
| Veredito calculado | `bash profiles/clearer-muse/scripts/evidence-report.sh --strict …` | `VERIFICADO` calculado, integrações `[validated]` |
| Diff | `git diff --check` + `scripts/diff-audit.sh` + revisão 7 checks | limpo, sem segredos, sem arquivo fora de escopo |
| Manifest | `muse plugins validate profiles/clearer-muse` | válido, diagnostics=0 |

Ativação (após aprovação dos commits, nunca antes): `muse plugins update clearer-muse` + `muse plugins update muse-ceh` e **restart da sessão** (ADR-004: hooks/skills só sobem no boot). Push/promoção `dev` → `main` só com `go` separado e Certificado de Voo do HEAD exato (Pre-Push CI Gate).

## Riscos e fora de escopo

- **Risco 1:** `test-runner.sh` e `detect-project.sh` do porte são reescritas enxutas — portar por semântica, jamais colar o arquivo oficial (188 linhas) por cima.
- **Risco 2:** mexer em `clearer-review` muda o comportamento do revisor; os evals não cobrem texto de skill — mitigação: canário manual pós-restart (uma revisão real exigindo finding em 4 partes).
- **Risco 3:** re-vendor muda o sha cobrado em C13; atualizar `VENDOR.md` no mesmo commit ou a suíte reprova (esperado e desejável).
- **Fora de escopo:** qualquer edição no repo oficial; `muse-ceh` além do sync de instalação; criar `CHANGELOG.md`, suíte fast ou sistema de aliases no porte (Ponytail Degrau 1); homologação V3 (continua no Antigravity).
- **Ponto de decisão residual:** versão 0.11.0 (proposto) e adoção de `shortcut:` como marcador canônico (divergência 2). `go` neste plano aceita ambos.

## Registro de execução (OBSERVED)

| Fase | Commit | Prova |
|---|---|---|
| 1 — `inspect_integrations` | `0326eb1` | contrato de evidência (E29+) dentro da suíte |
| 2 — scripts v2.1.3 | `63bfe57` | smoke 21/21 (5 asserts novos: npm stub, docker_service, detect, frontmatter ×2) |
| 3 — re-vendor `550848a` | `06345b1` | diff do extrato = 1 arquivo (`adapters/antigravity.py`, +5/−1); C13 sha `dc75ccb9…`; paridade 6/6, conformidade 13/13 |
| 4 — Ponytail v5 | `a60e81b` | suíte 9/9; `doc-audit` 6/6; manifesto válido |
| 5 — release 0.11.0 | (este commit) | suíte 9/9 com **150 asserts** (16+15+21+16+38+6+18+7+13 = baseline 135 + 5 da Fase 2 + 10 da Fase 1) |

Fase 6 executa sobre o HEAD deste release: meta-eval, Certificado de Voo,
`evidence-report.sh --strict`, `diff-audit` e a ativação
(`muse plugins update clearer-muse` + `muse plugins update muse-ceh` +
restart, ADR-004). Nenhum push foi feito nesta etapa.
