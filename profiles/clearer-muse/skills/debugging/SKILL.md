---
name: debugging
description: Addon opt-in de debugging determinístico (5 gates bloqueantes, relatório lesson-ready). Gatilho próprio: bug, erro, regressão. Promovido de skill de usuário para o harness.
---

# Systematic Debugging v2 (vendored no harness — origem: skill de usuário `systematic-debugging`, MIT, Fernando Dos Santos)

Processo determinístico para encontrar causa raiz sem chutes. Nenhum gate avança sem evidência. Saída é um relatório markdown em memória — nenhum arquivo é criado; o orquestrador ou humano decide se persiste o conhecimento.

## Princípio Fundamental

> Nunca chute a causa. Prove com artefato.
> Linguagem normativa: DEVE, NÃO DEVE, BLOQUEADO SE (RFC 2119).
> Sem evidência = sem avanço.

## Quando Usar

`bug`, `erro`, `falha`, `não funciona`, `quebrou`, `regressão`, `comportamento inesperado`, `flaky`, `intermitente`.

## Visão Geral — 5 Gates

| Gate | Nome | Output obrigatório (em memória) | Gate bloqueante |
|------|------|----------------------------------|-----------------|
| 0 | TRIAGE | Classificação P0-P3 + owner + SLA | BLOQUEADO SE sem severity |
| 1 | REPRODUCE | Repro mínima + teste que falha + dump env/dados | BLOQUEADO SE sem repro determinística ou flaky sem seed |
| 2 | ISOLATE | Matriz de hipóteses falsificáveis + arquivo:linha + estado incorreto | BLOQUEADO SE sem hipótese refutada com log/trace/bisect |
| 3 | ROOT CAUSE | Tipo de causa + cadeia causal + 5 Porques | BLOQUEADO SE descreve sintoma como causa |
| 4 | FIX & HARDEN | Fix mínimo + teste que falha agora passa + sem regressão + prevenção | BLOQUEADO SE sem detector de regressão |

Timebox padrão: P0 2h sem causa raiz → escalar; P1 4h; P2 1 dia → pair debug.

---

## Gate 0 — TRIAGE

**Objetivo:** Priorizar e dar ownership antes de investigar.

**DEVE produzir (responder em texto):**

```markdown
**Triage:** P0|P1|P2|P3 — [uma linha de impacto]
**Owner:** [nome/papel]
**SLA:** [ex: P0 4h, P1 1 dia]
**Rota afetada/tabela:** [ex: /api/contratos, Contrato]
**Commit/branch/env:** [ex: main@abc123, local docker]
```

Classificação:
- **P0** sistema fora / perda de dados / financeiro errado em produção
- **P1** feature crítica quebrada sem workaround
- **P2** bug com workaround ou escopo limitado
- **P3** cosmético / tech debt

**BLOQUEADO SE:** severity, owner ou env/commit não informados. NÃO inicie REPRODUCE.

---

## Gate 1 — REPRODUCE

**Objetivo:** Tornar o bug confiável e isolado.

**DEVE:**
1. Escrever passos mínimos numerados (3-5 passos). Isolar de cache, estado anterior, dados sujos.
2. Capturar evidência completa: mensagem de erro, stack trace, logs, screenshot se UI.
3. Criar teste que falha AGORA (sem fix):

```javascript
it('should [comportamento esperado] — repro #<id>', () => {
  // Arrange — seed/dados que reproduzem
  // Act — ação que dispara o bug
  // Assert — falha hoje, passará após Gate 4
});
```

4. Classificar repro: `determinístico` | `flaky (seed=X, taxa N/M)` | `env-only (diff de env/dados)`

**Árvore de decisão:**
- Determinístico → teste unitário/integração basta
- Flaky → DEVE registrar seed, taxa de falha e rodar com `--repeat` / `git bisect` se regressão
- Env-only → DEVE dumpar `env`, `commit`, `dump de dados anonimizado`, `docker diff`

**Critério de saída:**
- [ ] Bug reproduzido consistentemente OU flaky com seed/taxa documentada
- [ ] Passos mínimos documentados
- [ ] Evidência capturada em texto
- [ ] Teste que falha criado e executado (log de falha colado)

**BLOQUEADO SE:** "funciona na minha máquina" sem dump comparativo, ou teste não foi executado.

---

## Gate 2 — ISOLATE

**Objetivo:** Provar ONDE o bug nasce, não onde aparece.

**DEVE preencher Matriz de Hipóteses (mín 2 hipóteses, sempre falsificáveis):**

```markdown
| # | Hipótese | Teste de falsificação | Resultado | Evidência |
|---|----------|-----------------------|-----------|-----------|
| H1 | [ex: binding faltando em view X] | [ex: adicionar log em linha Y] | REFUTADA | [log: var=null] |
| H2 | [ex: query retorna null por WHERE errado] | [ex: rodar query isolada] | CONFIRMADA | [query log] |
```

**Toolbox — escolha a técnica que prova, não a que é fácil:**
- `git bisect` para regressões
- Bisseção com feature flag / config toggle
- `binary search` no código (comentar metade, observar)
- Logging estratégico em 2 pontos (entrada/saída da unidade suspeita)
- Tracing / query log / dump de estado
- Diferencial: comparar execução que passa vs que falha

**Perguntas que DEVE responder em texto:**
- Arquivo:linha exato: `app/Repositories/ContratoRepository.php:142`
- Variável/estado incorreto: `valor = null, esperado string`
- Suposição refutada: `input estava correto, falha é no transform`

**BLOQUEADO SE:** sem matriz, com 1 hipótese só, ou sem arquivo:linha + evidência de log.

---

## Gate 3 — ROOT CAUSE

**Objetivo:** Entender POR QUE, não apenas onde.

**DEVE:**

1. Classificar tipo (escolha 1): `logic | data | concurrency | config | dependency | env | integration`

2. Aplicar **5 Porques** completo + checar com **Ishikawa** (mín 2 técnicas):

```
Sintoma: "formulário não submete"
  Por que? validação falha → Por que? campo null → Por que? binding não funcionou
  → Por que? falta wire:model → Por que? template copiado sem ajustar
Causa raiz: template copiado sem ajustar bindings
Tipo: logic
```

3. Escrever cadeia causal com links:

```markdown
**Cadeia causal:** view X:18 (input sem binding) → controller Y:42 (recebe null) → validação falha → sintoma
**Correlação vs causalidade:** [ex: cache limpo mascarava, mas causa era WHERE]
**Contribuintes:** [ex: falta de type check, ausência de teste de contrato]
```

**BLOQUEADO SE:** descreve sintoma como causa ("validação falha" não é causa raiz), ou não classifica tipo, ou cadeia sem arquivo:linha.

---

## Gate 4 — FIX & HARDEN

**Objetivo:** Corrigir com prova e impedir recorrência. Menor diff possível.

**DEVE nesta ordem:**

1. Confirmar teste ainda falha (colar log)
2. Implementar fix mínimo — NÃO refatorar no mesmo diff
3. Confirmar teste agora passa (colar log)
4. Rodar suite relevante completa — sem regressão (colar resumo)
5. Declarar blast radius + rollback:

```markdown
**Blast radius:** arquivos: [X.php, Y.php] | tabelas: [Contrato, Parcela] | rotas: [/api/*]
**Rollback:** `git revert <commit>` ou `feature flag OFF`
```

6. Criar prevenção em 3 níveis (pelo menos 1 detector obrigatório):
   - **Detector:** teste de regressão que falharia se bug voltar
   - **Barreira:** validação, type, lint, constraint
   - **Runbook:** nota para P0/P1

**BLOQUEADO SE:** teste que falhava não passa, suite com regressão, ou sem detector.

---

## Saída Final — Relatório Markdown (sem arquivos)

Ao completar Gate 4, DEVE retornar **um único bloco markdown** no chat (não cria arquivo). O orquestrador ou humano decide se persiste.

Use exatamente este template:

```markdown
# Debug Report — <slug curto> — <YYYY-MM-DD>

**Triage:** P<0-3> | **Tipo:** logic|data|concurrency|config|dependency|env|integration | **Arquivo:** `path:linha`
**Commit:** <hash> | **Env:** <local/docker/prod>

## 1. Sintoma
[1-3 linhas: o que foi observado vs esperado]

## 2. Reprodução
Passos: 1. ... 2. ... 3. ...
Evidência: [erro/stack/log resumido]
Classificação: determinístico|flaky|env-only

## 3. Isolamento
Matriz de hipóteses: [tabela H1/H2 com resultado]
Local isolado: `arquivo:linha` — estado incorreto: `var=valor`

## 4. Causa Raiz
Tipo: [um dos 7]
Cadeia causal: [fluxo com arquivo:linha]
5 Porques: [resumo]
Contribuintes: [fatores que facilitaram]

## 5. Correção
Diff essencial: [descrição do fix mínimo, sem refatoração]
Blast radius: [arquivos/tabelas/rotas]
Rollback: [comando]

## 6. Verificação
- Teste repro antes: FALHOU [log curto]
- Teste repro depois: PASSOU [log curto]
- Suite: PASSOU [N testes, 0 regressão]

## 7. Prevenção
- [ ] Detector: [nome do teste de regressão]
- [ ] Barreira: [validação/type/constraint]
- [ ] Runbook: [se P0/P1, link ou nota]

## 8. Lição Aprendida
**Sintoma:** [...]
**Causa raiz:** [...]
**Correção:** [...]
**Como evitar:** [1-3 bullets acionáveis]

---
> **Quer salvar esta lição como conhecimento?**
> Responda `sim` para que eu persista em memória (ex: `.agents/memory/` ou KB global via MCP), ou `não` para manter apenas como relatório de leitura.
> Orquestrador: se `sim`, use o conteúdo de `## 8. Lição Aprendida` + frontmatter acima como payload de ingestão.
```

**Regras da saída:**
- NÃO cria arquivo em `.aidev/`, `kb/`, ou `docs/` — apenas retorna markdown.
- SEMPRE inclui a pergunta final `Quer salvar esta lição...` — DEVE aguardar resposta do usuário/orquestrador antes de qualquer persistência.
- Se o usuário/orquestrador responder `sim`, então e só então persista usando o mecanismo disponível (ex: `muse.add_memory`, `mcp__basic-memory__write_note`). Se `não` ou sem resposta, encerra como relatório.

---

## Anti-Patterns — NÃO DEVE

| Errado | Certo |
|--------|-------|
| "Acho que é cache, vou limpar" | Provar com matriz de hipóteses |
| Adicionar try-catch para esconder erro | Corrigir causa raiz |
| Refatorar junto com o fix | Fix mínimo isolado, refatorar depois |
| Corrigir sem teste que falha antes | Sempre teste repro antes/depois |
| Fix sem blast radius/rollback | Declarar impacto e reversão |

---

## Checklist de Done (todos DEVE estar marcados)

- [ ] Gate 0 triado (P + owner + env)
- [ ] Gate 1 repro com teste que falha (log colado)
- [ ] Gate 2 matriz com ≥2 hipóteses e arquivo:linha provado
- [ ] Gate 3 tipo + cadeia causal + 5 Porques
- [ ] Gate 4 fix mínimo + teste agora passa + suite sem regressão + detector
- [ ] Relatório markdown retornado com pergunta de persistência

Se qualquer item não marcado, debug NÃO está completo.
