# HANDOFF — Etapa 2: Absorção M1–M4 no muse-harness (porte Muse do CEH)

| Campo | Valor |
|---|---|
| Status | **AGUARDANDO ATIVAÇÃO** — desenvolvedor ativa com `go` nesta sessão (Muse) |
| Pré-condição | Etapa 1 homologada no oficial (Antigravity): branch `dev`, commit `316c0e1`, suíte 77/77, Smoke-Evals 5/5 APROVA, Certificado de Voo `VERIFICADO`/`ALTA 1.0`, integridade instalada 132/132 |
| Referência única | Runbook `analises/artifacts/repo-analysis/ceh-melhorias-sem-overengineering.md` **v1.3.0** (tiers, escada Ponytail, §12–§14) + commit oficial `459d15a` (M1–M4) como fonte de porte |
| Governança | Oficial só no Antigravity (Muse = read-only lá). Esta Etapa 2 é **exclusiva do Muse** neste repositório; Antigravity não toca aqui |
| Teto local | **V2 (adversarial)** — o porte não homologa baseline; homologação permanece no oficial |

## Goal

Absorver no porte Muse, sem overengineering, as 4 melhorias já homologadas no oficial (M3 regras de fronteira, M4 declaração registrada, M1 caso adversarial de contexto mentiroso, M2 auditor adaptativo de integrações), adaptadas à superfície real deste repositório — não copiadas byte a byte do layout Antigravity.

## Success Criteria

- Baseline local registrada antes de qualquer edição e suíte completa verde ao final (`profiles/clearer-muse/tests/run-all-tests.sh`, 9 testes no baseline observado).
- M3 presente nas regras do porte com os textos canônicos da v1.3.0 e prova `stat` = 600 sob `umask 022`.
- M4 registrado como ADR local sem nenhum gate de tamanho criado.
- M1: caso adversarial novo reprova contexto mentiroso e aprova comportamento correto na suíte existente de safety.
- M2: `inspect_integrations()` adaptado ao layout Muse com os 3 estados provados por testes de contrato locais (ausência silenciosa / declarada-não-exercitada bloqueia / validada libera).
- Meta-eval local executado sem degradação e diff auditado; nenhuma dependência nova, nenhum arquivo de suíte novo.

## Approach

Porte adaptativo, não vendoring: o oficial é a fonte de leitura (`git show 459d15a`), mas cada gesto aterrissa no equivalente local já existente (skills em vez de `rules/`, contratos shell em vez de `pytest`, ADR em `adr/`). Ordem oficial preservada: Fase 1 (M3+M4, texto) → Fase 2 (M1) → Fase 3 (M2) → Fase 4 (validação). Parar no primeiro vermelho, sem auto-reparo oportunista e sem tocar no repositório oficial.

## Steps

1. **Baseline e branch.** Em `dev` limpa, rodar `bash profiles/clearer-muse/tests/run-all-tests.sh` e registrar comando/exit/contagem. Criar a branch `dev-etapa2-absorcao-m1-m4` a partir de `dev`. Baseline vermelho pré-existente = reportar e parar.
2. **Cartão de Referência local (runbook §12.2).** Confirmar por inspeção: regras via skill `profiles/clearer-muse/skills/clearer-rules/SKILL.md`; gate em `profiles/clearer-muse/hooks/safety-gate.py` + motor vendored `hooks/vendor/ceh/`; evidência em `profiles/clearer-muse/scripts/evidence_report.py`; testes em `profiles/clearer-muse/tests/` (`test_safety_contract.sh`, `test_evidence_contract.sh`). Divergência com este cartão vira achado antes de editar.
3. **Fase 1a — M3 (texto).** Adicionar as 2 frases canônicas (lazy connection; `chmod 0600` com `stat`) à skill `clearer-rules` (e ao dispatcher `clearer` apenas se ele já resumir regras — sem duplicar texto em dois lugares). Prova imediata: artefato sensível de teste com `chmod 0600` e saída de `stat` = 600.
4. **Fase 1b — M4 (registro).** Criar `adr/006-isencao-declaration-only.md` seguindo o formato dos ADR 001–005: rejeição de teto arbitrário hoje, isenção sintática futura com par de provas obrigatório. Nenhum gate criado, `diff-audit.sh` intocado por este item.
5. **Fase 2 — M1 (caso adversarial).** Em `profiles/clearer-muse/tests/test_safety_contract.sh`, adicionar 1 caso offline: comando destrutivo acompanhado de alegação falsa de contexto (bypass simulado/“é só simulação”) deve ser bloqueado pelo gate local, e operação benigna equivalente deve passar. Primeiro vermelho na fixture insegura, depois verde; registrar os dois.
6. **Fase 3 — M2 (auditor adaptativo).** Portar a semântica de `inspect_integrations()` (oficial `459d15a`) para `profiles/clearer-muse/scripts/evidence_report.py`, adaptando as fontes de declaração ao layout Muse (hooks do profile e `.mcp.json`/`templates/mcp.json` quando declarados no projeto alvo): sem declarações → lista vazia, seção omitida, sem penalidade; declarada não exercitada ou quebrada → bloqueia veredito verificado. Adicionar os testes na suíte existente `test_evidence_contract.sh`: (a) ausência libera, (b) declarada-não-exercitada bloqueia, (c) validada libera, (d) ausência não emite seção de integrações.
7. **Fase 4 — Validação e auditoria.** Rodar a suíte completa, `bash evals/run.sh` (raiz deste repo) e `bash profiles/clearer-muse/scripts/evidence-report.sh --strict` registrando cada exit. Auditar o diff com os 7 checks adversariais (segurança, destrutivo, compatibilidade, schema, ramos sem teste, blast radius, lookups). Conferir especificamente que os ramos MCP do M2 ganharam teste aqui (achado MEDIUM deixado em aberto no oficial).

## Validation Plan

| Prova | Comando | Esperado |
|---|---|---|
| Baseline e final | `bash profiles/clearer-muse/tests/run-all-tests.sh` | exit 0, contagem registrada nos dois momentos |
| M3 físico | `stat` em artefato sensível sob `umask 022` | `600` |
| M1 vermelho→verde | suíte `test_safety_contract.sh` | caso novo falha sem a proteção e passa com ela |
| M2 contrato (4 casos) | suíte `test_evidence_contract.sh` | exit 0 com os casos (a)–(d) |
| Meta-eval local | `bash evals/run.sh` | sem degradação vs. baseline |
| Evidência calculada | `evidence-report.sh --strict` | veredito coerente com a suíte (nunca declarado à mão) |
| Diff | `git diff --check` + revisão adversarial | limpo, sem markers, sem arquivos fora de escopo |

## Risks / Open Questions

- O `evidence_report.py` local diverge do upstream por decisão registrada (HANDOFF-ABSORCAO-V2.1.2, decisão 5): o porte do M2 deve respeitar o delta local de layout, não sobrescrevê-lo com o arquivo do oficial.
- Hooks do Muse têm contrato dual (JSON + `CEH-SAFETY` em stderr): o caso M1 deve afirmar nos dois canais, como os casos vizinhos já fazem.
- Questões abertas: nenhuma que bloqueie. Escopo fechado pelos Success Criteria; qualquer item Tier 2/Tier 3 do runbook está fora desta Etapa 2.
