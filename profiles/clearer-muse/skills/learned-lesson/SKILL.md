---
name: learned-lesson
description: Extração e persistência de lições (error/lesson/best-practice, contrato canônico). Portado de clearer-engineering/skills/learned-lesson.
---

# Learned Lesson (Muse)

Transforma atrito superado em barreira permanente. Só com causa raiz comprovada + solução validada por teste/comando/build.

## Gatilhos

Pós-bugfix complexo (Gate 4 do `debugging`), particularidade de stack/container/CLI, convenção nova, ou comando explícito (`/lesson`, `lição aprendida`, `salvar memória`).

## Tipos canônicos (exatamente um)

| Tipo | Quando | Exemplo |
|---|---|---|
| `error` | falha/crash/bug/conflito resolvido | porta Docker em conflito, SQL por versão |
| `lesson` | descoberta, atalho, comportamento não documentado | volume Sail correto, busca AST vs grep |
| `best_practice` | padrão/convenção/invariante | tipagem estrita de DTOs, menor diff funcional |

## Contrato canônico

Metadados: `title` (≤80 chars, imperativo), `type`, `stack` (minúsculas), `scope` (`project`|`global`).

Conteúdo (`description`):

```markdown
### 1. Sintoma / Contexto
[erro objetivo, comando, situação OBSERVED]

### 2. Causa Raiz
[mecanismo real — o PORQUÊ, não o sintoma]

### 3. Solução Canônica
[comando exato, diff mínimo ou config definitiva]

### 4. Regra de Prevenção (Invariante)
[da próxima vez, faça X antes de Y]
```

## Persistência (ordem de força)

1. Barreira no repo (teste de regressão, hook, gate) — preferido.
2. Runbook.
3. Nota no formato acima; hub `dev-memory` quando disponível, senão relatório local.

Pergunte ao humano antes de persistir em memória; default = relatório de leitura.
