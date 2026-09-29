# AUDIT — rules/*.md upstream vs clearer-rules/SKILL.md (v0.8.0)

> Backlog do [HANDOFF-EVIDENCE-0.8.0](/home/nandodev/projects/muse-harness/HANDOFF-EVIDENCE-0.8.0.md) §4, item 3.
> Método: [clearer-audit](/home/nandodev/projects/muse-harness/profiles/clearer-muse/skills/clearer-audit/SKILL.md)
> (claims atômicos, espaço fechado, decisão + certeza). Auditoria de **cobertura documental**: cada claim
> pergunta se a cláusula upstream está **expressa em `clearer-rules/SKILL.md`**; a coluna "Profile" informa
> cobertura cruzada em outra skill/script do profile (não conta p/ o veredito estrito).

- Upstream: `/home/nandodev/projects/clearer-engineering-harness/clearer-engineering/rules/` (7 arquivos).
  Ref do porte: `staging @ 525da48` (CEH v1.3.0); verificado que `git diff 525da48..HEAD` sobre
  `rules/` é vazio (exit 0) — o auditado equivale ao HEAD atual (`main @ 3cffcfc`).
- Auditado: `profiles/clearer-muse/skills/clearer-rules/SKILL.md` (§1–§7, 44 linhas).
- Critério: `SUPPORTED` = cláusula expressa sem perda de dever (resumo fiel vale);
  `PARTIALLY_SUPPORTED` = resumida com perda de detalhe ou delegada com ponte explícita;
  `UNSUPPORTED` = ausente no arquivo (com nota de cobertura no profile ou by-design).
- Certeza: `1.0` = leitura física dos dois lados, citada como `arquivo:linha`.

## AGENTS.md

### Claim A1: "Tabela de ambientes DEV/HML/PROD com rigores está em clearer-rules §1"
- Status: SUPPORTED
- Certeza: 1.0
- Evidência: clearer-rules:12-16 (tabela ALLOW/ASK-2-alertas/DENY) vs AGENTS.md:12-16.

### Claim A2: "Matriz DB/migrações (fresh/wipe/DROP/TRUNCATE) está em clearer-rules §1"
- Status: SUPPORTED
- Certeza: 1.0
- Evidência: clearer-rules:16 (DENY em PRODUCAO) + clearer-rules:18 (matriz por caso) vs AGENTS.md:19.

### Claim A3: "Matriz git (reset/clean/force) + Pre-Push CI Gate está em clearer-rules"
- Status: SUPPORTED
- Certeza: 1.0
- Evidência: clearer-rules:16 (DENY `reset --hard`, `push --force`) + clearer-rules:20-22
  (gate tolerância zero + Certificado de Voo) vs AGENTS.md:20-22.

### Claim A4: "Matriz filesystem (rm -rf só cache/build/scratch em DEV) está em §1"
- Status: SUPPORTED
- Certeza: 1.0
- Evidência: clearer-rules:18 vs AGENTS.md:23.

### Claim A5: "Matriz infra (terraform/kubectl) está em §1"
- Status: SUPPORTED
- Certeza: 1.0
- Evidência: clearer-rules:16 (DENY + `docker system prune -a`, adaptação de host) vs AGENTS.md:24.

### Claim A6: "Topologias Enterprise/Clássico + derivações de dev estão em §3"
- Status: SUPPORTED
- Certeza: 1.0
- Evidência: clearer-rules:24-28 vs AGENTS.md:26-39. Mecânica em `scripts/setup-branches.sh`.

### Claim A7: "Protocolo CLEARER (7 letras) está expresso em clearer-rules"
- Status: UNSUPPORTED
- Certeza: 1.0
- Evidência: nenhuma em clearer-rules:1-44. Profile: SUPPORTED em
  `skills/clearer/SKILL.md:32-40` (dispatcher, resumo operacional das 7 letras).

### Claim A8: "Tríade OBSERVED/INFERRED/UNKNOWN + proibição de promoção silenciosa está em clearer-rules"
- Status: PARTIALLY_SUPPORTED
- Certeza: 1.0
- Evidência: `OBSERVED` citado em clearer-rules:22; tríade e proibição ausentes no arquivo.
  Profile: SUPPORTED em `skills/clearer/SKILL.md:42-48` + `skills/clearer-map/SKILL.md:29`.

### Claim A9: "Tríade de claims SUPPORTED/PARTIALLY/UNSUPPORTED está em clearer-rules"
- Status: PARTIALLY_SUPPORTED
- Certeza: 1.0
- Evidência: clearer-rules:44 cita `PARTIALLY_SUPPORTED`/`UNSUPPORTED`; definições delegadas com
  ponte explícita a `clearer-audit` (clearer-rules:36). Normativo em `skills/clearer-audit/SKILL.md`.

### Claim A10: "Risk Dial LOW/MEDIUM/HIGH está definido em clearer-rules"
- Status: PARTIALLY_SUPPORTED
- Certeza: 1.0
- Evidência: só `HIGH` citado (clearer-rules:40). Profile: SUPPORTED em
  `skills/clearer/SKILL.md:24-30` (sem ponte de volta em clearer-rules).

### Claim A11: "Escada Ponytail (5 degraus) está em §4"
- Status: SUPPORTED
- Certeza: 1.0
- Evidência: clearer-rules:32 (precisa existir? já existe? stdlib? API nativa? cirúrgica mínima)
  vs AGENTS.md:94-99.

### Claim A12: "Parcimônia anti-over-orchestration (1–3 arquivos, turno único) está em §4"
- Status: SUPPORTED
- Certeza: 1.0
- Evidência: clearer-rules:32 vs AGENTS.md:100.

### Claim A13: "AST-first/Graphify + fallback fatiado está em clearer-rules"
- Status: PARTIALLY_SUPPORTED
- Certeza: 1.0
- Evidência: "fatie só o contexto necessário" (clearer-rules:36); Graphify ausente no arquivo.
  Profile: SUPPORTED via `skills/token-economy/SKILL.md:10` (equivale ao Graphify) +
  `skills/clearer-bugfix/SKILL.md:111`.

### Claim A14: "Otimização de shell RTK + fallback está em clearer-rules"
- Status: UNSUPPORTED
- Certeza: 1.0
- Evidência: nenhuma em clearer-rules:1-44. Profile: SUPPORTED (opt-in) em
  `skills/token-economy/SKILL.md:11` + `skills/token-economy/SKILL.md:17` +
  `scripts/compress-output.sh` (fallback) + `scripts/test-runner.sh:66` (stripping de prefixo rtk).

### Claim A15a: "Tipagem estrita + blast radius mínimo + diff-audit estão em §4"
- Status: SUPPORTED
- Certeza: 1.0
- Evidência: clearer-rules:32 vs AGENTS.md:106-113.

### Claim A15b: "Dever de código idiomático + testes comportamentais determinísticos está em clearer-rules"
- Status: UNSUPPORTED
- Certeza: 1.0
- Evidência: nenhuma em clearer-rules:1-44. Profile: SUPPORTED em
  `skills/clearer-feature/SKILL.md:40` (Clean Code/SOLID) +
  `skills/clearer-feature/SKILL.md:44-46` e `skills/clearer-test/SKILL.md` (comportamentais).

### Claim A16: "Heurísticas de comunicação executiva + heartbeat 25s estão em clearer-rules"
- Status: UNSUPPORTED
- Certeza: 1.0
- Evidência: nenhuma em clearer-rules:1-44. Profile: SUPPORTED (opt-in) em
  `skills/clearer-adhd/SKILL.md:10-22` (11 heurísticas) + `skills/clearer-test/SKILL.md`
  e `scripts/heartbeat.sh` (heartbeat).

### Claim A17: "Cláusula break-rules (segurança > concisão) está em clearer-rules"
- Status: UNSUPPORTED
- Certeza: 1.0
- Evidência: nenhuma em clearer-rules:1-44. Profile: SUPPORTED (opt-in) em
  `skills/clearer-adhd/SKILL.md:24-26`.

### Claim A18: "Os 7 invariantes System One estão em §5"
- Status: SUPPORTED
- Certeza: 1.0
- Evidência: clearer-rules:34-36 vs AGENTS.md:140-147.

### Claim A19: "Mitigação dos 4 modos de falha de avaliação está em §5"
- Status: PARTIALLY_SUPPORTED
- Certeza: 1.0
- Evidência: 3/4 em clearer-rules:36 (contagem no shell, fatiamento, dado passivo);
  literalidade/critérios contrastivos delegados com ponte a `clearer-review`/`clearer-audit`
  (ponte em clearer-rules:36; `what`/`not_for` em `skills/clearer-audit/SKILL.md`).

### Claim A20: "Operação Like a Jev (certeza materializada) está em §5"
- Status: PARTIALLY_SUPPORTED
- Certeza: 1.0
- Evidência: teto 0.60 p/ inferência em clearer-rules:36 vs AGENTS.md:155-160;
  constrained-decoding/auto-consistência ausentes (específicos do modelo Gemini do host Antigravity).

### Claim A21: "Checkpoints por exceção (4 condições) estão em §6"
- Status: SUPPORTED
- Certeza: 1.0
- Evidência: clearer-rules:38-40 vs AGENTS.md:164-175.

### Claim A22: "Onboarding Antigravity (cockpit/ceh-branches) está em clearer-rules"
- Status: UNSUPPORTED
- Certeza: 1.0
- Evidência: nenhuma em clearer-rules:1-44. By-design host-specific (Antigravity IDE);
  topologia de branches coberta por `scripts/setup-branches.sh`. Sem ação.

## core-engineering.md

### Claim C1: "Ciclo INSPECT→REPORT (7 etapas) está em clearer-rules"
- Status: UNSUPPORTED
- Certeza: 1.0
- Evidência: nenhuma em clearer-rules:1-44. Profile: SUPPORTED em
  `skills/clearer/SKILL.md:27` (MEDIUM turno único) + `skills/clearer-feature/SKILL.md` (fluxo 8 fases).

### Claim C2: "Risk Dial (core-engineering §2) está em clearer-rules"
- Status: PARTIALLY_SUPPORTED
- Certeza: 1.0
- Evidência: idem A10 (mesma propriedade, não conta 2x no veredito).

### Claim C3: "Gestão por exceção está em clearer-rules"
- Status: SUPPORTED
- Certeza: 1.0
- Evidência: clearer-rules:38-40 vs core-engineering.md:18-19.

## evidence-policy.md

### Claim E1: "Classificação de fatos está em clearer-rules"
- Status: PARTIALLY_SUPPORTED
- Certeza: 1.0
- Evidência: idem A8 (mesma propriedade, não conta 2x no veredito).

### Claim E2: "Proibição de hallucination coding (UNKNOWN→OBSERVED, NOT FOUND) está em clearer-rules"
- Status: UNSUPPORTED
- Certeza: 1.0
- Evidência: nenhuma em clearer-rules:1-44. Profile: SUPPORTED em
  `skills/clearer/SKILL.md:44-46` ("nunca alucine") + `skills/clearer-map/SKILL.md:29`
  ("Ausente = `NOT FOUND`, nunca inventado").

### Claim E3: "Classificação de claims está em clearer-rules"
- Status: PARTIALLY_SUPPORTED
- Certeza: 1.0
- Evidência: idem A9 (mesma propriedade, não conta 2x no veredito).

## testing-policy.md

### Claim T1: "Contrato COMMAND/EXIT/RESULT p/ 'testado' está em clearer-rules"
- Status: PARTIALLY_SUPPORTED
- Certeza: 1.0
- Evidência: comando + exit + saída em clearer-rules:44; contagem RESULT formal delegada a
  `skills/clearer-test/SKILL.md` (contrato) + `skills/clearer-feature/SKILL.md` (registro).

### Claim T2: "Testes comportamentais happy/unhappy/bordas + sem mocks excessivos está em clearer-rules"
- Status: UNSUPPORTED
- Certeza: 1.0
- Evidência: nenhuma em clearer-rules:1-44. Profile: SUPPORTED em
  `skills/clearer-test/SKILL.md` (§3 Cobertura) + `skills/clearer-feature/SKILL.md:44-46`.

### Claim T3: "Auto-reparo (1 iteração fundamentada) está em clearer-rules"
- Status: PARTIALLY_SUPPORTED
- Certeza: 1.0
- Evidência: "1 auto-reparo fundamentado" em clearer-rules:40; detalhe (stack trace →
  handoff) em `skills/clearer-test/SKILL.md` (§3 Falhas).

### Claim T4: "Proibição de fake pass + NOT RUN explícito está em clearer-rules"
- Status: UNSUPPORTED
- Certeza: 1.0
- Evidência: nenhuma em clearer-rules:1-44. Profile: SUPPORTED em
  `skills/clearer-test/SKILL.md` (§1 "Sem fake pass", §3 `NOT RUN`).

## git-safety.md

### Claim G1a: "Inspeção git status/branch antes de mutar está em clearer-rules"
- Status: UNSUPPORTED
- Certeza: 1.0
- Evidência: nenhuma em clearer-rules:1-44. Profile: SUPPORTED em
  `skills/clearer-feature/SKILL.md:21` + `skills/clearer-map/SKILL.md:14`.

### Claim G1b: "Dever de nunca descartar trabalho alheio sem autorização está no profile"
- Status: UNSUPPORTED
- Certeza: 1.0
- Evidência: nenhuma — `grep -ri "sem autorização|autorização expressa|não relacionada"`
  sobre `profiles/clearer-muse/skills/` retorna só `clearer-map:29` (NOT FOUND, outro dever).
  **GAP G1b** (refinamento R2).

### Claim G2: "Bloqueio de comandos git perigosos + revisão de diff está em clearer-rules"
- Status: PARTIALLY_SUPPORTED
- Certeza: 1.0
- Evidência: `reset --hard`/`push --force` em clearer-rules:16 + `diff-audit` em
  clearer-rules:32; `git diff --stat`/`--check` textuais ausentes (mecânica existe em
  `scripts/diff-audit.sh`).

## security-policy.md

### Claim S1: "Security-by-default + HIGH automático p/ auth/segredos está em clearer-rules"
- Status: UNSUPPORTED
- Certeza: 1.0
- Evidência: nenhuma em clearer-rules:1-44. Profile: PARTIALLY_SUPPORTED —
  `skills/clearer/SKILL.md:28` (HIGH p/ auth/pagamentos/segurança) +
  `skills/clearer-review/SKILL.md:31` (check `modifies_security_or_auth`) +
  `skills/clearer-review/SKILL.md:39` (promoção a HIGH); "toda entrada é não confiável"
  sem dever textual. **GAP S1** (refinamento R1).

### Claim S2: "Vetores (injeção, authz backend, nunca comitar segredos) estão em clearer-rules"
- Status: UNSUPPORTED
- Certeza: 1.0
- Evidência: nenhuma em clearer-rules:1-44. Profile: PARTIALLY_SUPPORTED —
  `skills/clearer-review/SKILL.md:60` (checklist injeção SQL/XSS/CSRF/command, sem vazar
  segredo) + `scripts/evidence_report.py:190,246` (varredura de segredos no diff);
  "nunca comitar credenciais" e "authz no backend" sem dever textual. **GAP S2** (refinamento R1).

## coding-policy.md

### Claim D1: "Inspect-before-edit + grounding em OBSERVED está em clearer-rules"
- Status: UNSUPPORTED
- Certeza: 1.0
- Evidência: nenhuma em clearer-rules:1-44. Profile: SUPPORTED em
  `skills/clearer/SKILL.md:35` + `skills/clearer-feature/SKILL.md:19-23`.

### Claim D2: "Blast radius + sem ruído cosmético + preservar contratos está em clearer-rules"
- Status: PARTIALLY_SUPPORTED
- Certeza: 1.0
- Evidência: blast radius em clearer-rules:32; resto em `skills/clearer/SKILL.md:36` +
  `skills/clearer-feature/SKILL.md` (§2 Contratos, §5 menor diff).

### Claim D3: "Tipagem estrita + sem any/mixed + auto-documentado está em clearer-rules"
- Status: PARTIALLY_SUPPORTED
- Certeza: 1.0
- Evidência: tipagem estrita em clearer-rules:32; `any`/`mixed`/single-responsibility em
  `skills/clearer-feature/SKILL.md:40`.

### Claim D4: "Engenharia defensiva (nulos/vazios/timeouts, fail-fast, SOLID) está em clearer-rules"
- Status: PARTIALLY_SUPPORTED
- Certeza: 1.0
- Evidência: nulos/timeouts em clearer-rules:32; defensiva completa em
  `skills/clearer-feature/SKILL.md:36` (§4 Plan) + `skills/clearer-feature/SKILL.md:40` (SOLID).

### Claim D5: "Root-cause-first (reprodução→regressão→fix mínimo) está em clearer-rules"
- Status: UNSUPPORTED
- Certeza: 1.0
- Evidência: nenhuma em clearer-rules:1-44. Profile: SUPPORTED em
  `skills/clearer-bugfix/SKILL.md` (5 gates, teste de regressão que FALHA AGORA, fix mínimo).

## Vereditos (agregação determinística)

Críticos p/ este audit: A1–A6, A18, A21, C3 (núcleo normativo de clearer-rules) + E2, T4, S1, S2
(deveres fail-closed do profile).

- **Escopo estrito (só `clearer-rules/SKILL.md`): `NEEDS_EVIDENCE`** — por desenho: clearer-rules é
  consolidação nuclear, não transcrição; A7, E2, T4, S1, S2 vivem em skills próprias
  (dispatcher/test/audit/review). Nenhum claim contradiz o upstream (zero `REJECTED`).
- **Escopo profile: `NEEDS_EVIDENCE`** — 3 refinamentos textuais (nenhum bloqueante; mecanismos de
  enforcement existem nos dois casos de segurança):
  - R1 (GAP S1/S2): deveres textuais de segurança — "toda entrada é não confiável", "nunca comitar
    credenciais", "authz no backend". Sugestão: 3 linhas no checklist de `clearer-review` (§check 1).
  - R2 (GAP G1b): "nunca descartar/reverter trabalho alheio sem autorização expressa". Sugestão:
    1 linha em `clearer-feature` (§1 Inspect) ou `clearer-map`.
  - R3 (ponte, não gap): A10/C2 — adicionar em clearer-rules §6 uma ponte "Risk Dial: ver
    `clearer` §2" (1 linha), simétrica à ponte de §5 p/ review/audit.
- Invariante crítico (§7/Invariante 6, motivo do handoff): **SUPPORTED** — clearer-rules:42-44
  + `scripts/evidence-report.sh` + `scripts/evidence_report.py` (OBSERVED na suíte
  `test_evidence_contract.sh`, 17 asserts).

## Backlog remanescente deste audit

1. R1, R2, R3 acima (custo: ~5 linhas; escopo de um commit `docs` futuro).
2. By-design sem ação: A22 (cockpit Antigravity), A20-parcial (constrained decoding Gemini),
   A14/A16/A17 opt-in (`token-economy`, `clearer-adhd`).

