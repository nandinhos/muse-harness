---
name: clearer-audit
description: Auditoria formal de claims vs evidências (SUPPORTED/PARTIALLY/UNSUPPORTED). Portado de clearer-engineering/skills/clearer-audit.
---

# CLEARER Audit (Muse)

Auditor final: confronta cada afirmação com evidência observável. Sem log, sem código, sem teste = sem claim.

```text
CLAIM <── Verificação ──> EVIDENCE
```

## Categorias (espaço fechado, julgamento univariado)

| Categoria | `what` | `not_for` | Exemplo |
|---|---|---|---|
| `SUPPORTED` | comando com exit 0 + log, arquivo lido, linha inspecionada | plausível sem log anexado | "Regressão passou, exit 0, 14/14 verdes." |
| `PARTIALLY_SUPPORTED` | código existe mas teste não rodou; inferência coerente sem prova física | ausência total de código | "Método existe, suíte Feature não executada." |
| `UNSUPPORTED` | sem evidência ou evidência contradiz | qualquer claim com prova física | "Suporta concorrência (sem teste de estresse)." |

## Formato por claim (dois eixos: decisão + certeza)

```text
### Claim: "<afirmação>"
- Status: SUPPORTED | PARTIALLY_SUPPORTED | UNSUPPORTED
- Certeza: 1.0 (física OBSERVED) | ≤0.60 (inferência sem teste) | 0.0 (ausência)
- Evidência: arquivo:linha, comando + exit code, ou "nenhuma".
```

Certeza materializada: só evidência física dá 1.0; inferência sem teste tem teto 0.60 e escala nos gates.

## Veredito (agregação determinística, sem prosa de opinião)

- `APPROVED`: 100% dos claims críticos SUPPORTED com OBSERVED.
- `NEEDS_EVIDENCE`: ≥1 crítico PARTIALLY/UNSUPPORTED → buscar prova física.
- `REJECTED`: ≥1 claim contradiz código/logs → escalar ao humano.

Rejeite de ofício: "deve funcionar", "testado com sucesso" (sem log), "sem regressões" (sem suíte).
