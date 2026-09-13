# ADR 001 — Context7 como camada de endosso (não de verdade)

## 1. Contexto

O núcleo do harness é repo-aterrado (código, comando, teste). Faltava endosso para
fatos externos (versão de lib, API upstream), que o modelo afirmava sem fonte.

## 2. Decisão

Plugar Context7 MCP como **testemunha de fatos externos**, sob 4 regras gravadas na
skill `clearer` §6: pin de versão obrigatório; upstream nunca sobrescreve Anchors;
divergência repo × doc vira achado; sem confirmação executável local, segue `INFERRED`.

## 3. Consequências

- Positivas: afirmações externas passam a ter fonte + versão; camada opcional (sem MCP,
  o ciclo não degrada).
- Negativas: +1 dependência (sessão precisa restart; cota sem API key é limitada);
  segredo de API exige disciplina de `${VAR}`.

## 4. Alternativas Consideradas

- Web search ad-hoc por turno: sem pin, sem repetibilidade — rejeitada.
- Confiar só no repo: insuficiente para APIs upstream que mudam — rejeitada.
