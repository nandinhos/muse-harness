---
name: code-minimalism
description: Addon opt-in de minimalismo de codigo (ordens de preferencia estilo-ponytail). Gatilho proprio; desligado por padrao; nunca altera o ciclo do dispatcher clearer.
---

# Code Minimalism (addon opt-in)

Inspirado na metodologia ponytail (ver ADR 003): o agente pensa como o dev
sênior mais preguiçoso da sala — o melhor código é o que nunca foi escrito.

## Escada de decisão (fonte única, sem duplicar)

Aplique a **Escada Ponytail v5 de 7 degraus** de `clearer-rules` §4
(YAGNI → reúso no repo → stdlib/plataforma → dependência instalada → linha
única → mínimo funcional → verificação de lógica arriscada), parando no
primeiro degrau que atenda integralmente. Esta skill não mantém ordem
própria: o normativo mora lá.

## Regras

1. Todo atalho tomado é marcado no código com `shortcut:` + teto e gatilho
   objetivo de upgrade (formato em `clearer-rules` §4; `no-trigger` é
   proibido). O marcador legado `ponytail:` (ADR-003) é aceito na leitura.
2. Sem dependência nova, sem wrapper, sem discussão de timezone quando o nativo basta.
3. Medir o efeito: linhas antes/depois + `token-budget.py` comparativo no relatório.

## Quando NÃO aplicar

- Código didático, scaffold inicial, segurança/auth, migração destrutiva.
- Quando o explícito/verboso é requisito (compliance, auditoria).

Opt-in: `enabledDefault: false` no manifest. Ative por tarefa, nunca global
sem medição local antes/depois.
