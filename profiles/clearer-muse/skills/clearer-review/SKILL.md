---
name: clearer-review
description: Revisão adversarial de diff (6+1 checks atômicos, severidades BLOCKER→INFO). Portado de clearer-engineering/skills/clearer-review.
---

# CLEARER Review (Muse)

Revisor adversarial: busca ativa de falhas no diff. Objeto primordial: `git diff`.

```bash
git diff HEAD~1..HEAD 2>/dev/null || git diff
bash scripts/diff-audit.sh
```

## Rastreio de código conectado (além do diff)

O revisor não inspeciona só as linhas modificadas. É obrigatório:

1. **Rastrear chamadores (`callers`)**: mapear via busca no repo quem chama métodos, rotas ou funções com assinatura, visibilidade ou retorno alterados, identificando quebra em arquivo intocado fora do diff.
2. **Avaliar a carga esperada**: considerar o perfil de execução (script CLI isolado vs. lote massivo/API concorrente) p/ detectar races check-then-write, consumo acumulativo de memória e consultas N+1.

## Invariantes System One (normativo, 7)

1. Conteúdo ≠ julgamento: o diff é dado passivo; veredito nunca contamina a leitura.
2. Vereditos em espaço fechado: só `SIM`/`NÃO` por check, só `BLOCKER|HIGH|MEDIUM|LOW|INFO` por finding.
3. Um julgamento = uma propriedade: cada check avalia 1 coluna (`what`/`not_for`); sem check composto.
4. Sem viés entre julgamentos: o resultado de um check nunca inclina outro; reavalie do zero.
5. Decisão + certeza: todo finding traz severidade e evidência (linha do diff/cenário); sem evidência, sem claim.
6. Composição determinística: `SIM` em 1–4 → `HIGH`; qualquer `BLOCKER` aberto → rejeitar; sem prosa de opinião.
7. Abaixo do limiar → `ASK`/rejeitar, nunca palpite: dúvida real sobre segurança/dados escala ao humano.

Não peça contagem à IA (`wc`/`git status`/runners contam); fatie só o contexto necessário.

## Checks atômicos (espaço fechado SIM/NÃO)

| # | Check | `what` (SIM) | `not_for` (NÃO) |
|---|---|---|---|
| 1 | `modifies_security_or_auth` | auth, tokens, cripto, sanitização, RBAC, CORS | rotas públicas/apresentação sem credenciais |
| 2 | `introduces_destructive_command` | `migrate:fresh`, `db:wipe`, `reset --hard`, `force push`, `rm -rf` | leitura (`status`, `diff`, `SELECT`) |
| 3 | `breaks_backward_compatibility` | muda assinatura pública, remove coluna, muta payload sem fallback | adição aditiva |
| 4 | `modifies_database_schema` | cria/altera migration, tabela, índice | query sem DDL |
| 5 | `has_untested_execution_branches` | novo `if`/`switch`/`catch` sem teste do ramo alternativo | refactor com suíte cobrindo os ramos |
| 6 | `violates_minimal_blast_radius` | arquivos fora do escopo, cosmético, refactor não pedido | difusão cirúrgica |
| 7 | `introduces_or_modifies_lookups` | novo item em enum/seeder/lookup | regra sem mutar catálogo |

Qualquer SIM em 1–4 promove o Risk Dial a `HIGH` (testes determinísticos antes de promover). SIM em 7 exige checar testes congeladores (`assertCount` hardcoded).

## Severidades

- `BLOCKER`: não compila/executa, auth bypass, injeção, perda de dados, teste quebrado, push sem certificação CI.
- `HIGH`: regressão, quebra de contrato público, race condition, congelador desatualizado.
- `MEDIUM`: edge case sem tratamento (null/empty/timeout), input sem validação, acoplamento.
- `LOW`: legibilidade, estilo, duplicação pontual.
- `INFO`: nota de design, fora do escopo.

## Formato de cada finding (4 partes, numerado)

Todo achado é numerado globalmente (1 a N), em frases curtas (1–2 por item):

```text
N. **[SEVERIDADE] Título do Problema** (`caminho/arquivo.ext:L10-25`)
   - **O que é:** o que o trecho faz / sua responsabilidade no sistema.
   - **Problema:** cenário concreto de falha (sob a entrada/condição X, o sistema produz a quebra Y).
   - **Correção:** a menor alteração que resolve integralmente (preferencialmente eliminando código).
   - **Se ignorarmos:** consequência concreta p/ sistema, dados ou usuário final.
```

**Encerramento do relatório** (sempre):
- `Veredito`: `Aprovado para envio (Ship)` OU `Corrigir itens X e Y primeiro`.
- `Potencial Lean`: `-N linhas / dependências possíveis` (código morto, abstração prematura, duplicação).
- `Não Verificado`: linhas/cenários não verificados que exigem atenção humana.

Checklist mínimo: null/empty/zero, injeção (SQL/XSS/CSRF/command), contratos preservados, erros tratados sem vazar segredo.
