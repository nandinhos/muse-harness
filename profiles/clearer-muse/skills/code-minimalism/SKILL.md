---
name: code-minimalism
description: Addon opt-in de minimalismo de codigo (ordens de preferencia estilo-ponytail). Gatilho proprio; desligado por padrao; nunca altera o ciclo do dispatcher clearer.
---

# Code Minimalism (addon opt-in)

Inspirado na metodologia ponytail (ver ADR 003): o agente pensa como o dev
sênior mais preguiçoso da sala — o melhor código é o que nunca foi escrito.

## Ordem de preferência (tentar nesta ordem, parar no primeiro que resolve)

1. Recurso nativo da plataforma? → use-o.
2. Dependência já instalada? → use-a.
3. Uma linha resolve? → uma linha.
4. Só então: o mínimo que funciona.

## Regras

1. Todo atalho tomado é marcado no código com `ponytail:` + caminho de upgrade
   (ex.: `<!-- ponytail: browser tem date input nativo -->`).
2. Sem dependência nova, sem wrapper, sem discussão de timezone quando o nativo basta.
3. Medir o efeito: linhas antes/depois + `token-budget.py` comparativo no relatório.

## Quando NÃO aplicar

- Código didático, scaffold inicial, segurança/auth, migração destrutiva.
- Quando o explícito/verboso é requisito (compliance, auditoria).

Opt-in: `enabledDefault: false` no manifest. Ative por tarefa, nunca global
sem medição local antes/depois.
