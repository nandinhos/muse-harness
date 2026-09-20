---
name: clearer-map
description: Mapeamento técnico read-only do codebase (stack, módulos, dados, riscos). Portado de clearer-engineering/skills/clearer-map.
---

# CLEARER Map (Muse)

Análise puramente **read-only**: nenhum arquivo de código é modificado. Saída: mapa arquitetural do repositório.

## 1. Coleta

```bash
bash scripts/detect-project.sh
git status --short && git branch --show-current
```

Inspeção cirúrgica (grep + leitura fatiada); sem dumps integrais sem necessidade.

## 2. Seções do mapa

1. **Stack & Tooling**: linguagens/versões nos manifestos, frameworks, testes, lint.
2. **Entrypoints & Rotas**: pontos de entrada, rotas HTTP, comandos CLI, workers.
3. **Módulos & Arquitetura**: pastas (Domain/Application/Infrastructure…), fluxo de dados, regras de negócio.
4. **Dados & Persistência**: schemas, migrations, ORM/modelos, dialetos.
5. **Dependências & Integrações**: terceiros, gateways, filas.
6. **Infra & Ambientes**: Docker/Compose/K8s, variáveis necessárias.
7. **Riscos & Hotspots**: legado, baixa cobertura, complexidade, segurança.

Marque cada fato `OBSERVED`/`INFERRED`/`UNKNOWN`. Ausente = `NOT FOUND`, nunca inventado.
