# ADR 006 — Isenção declaration-only por sintaxe (registro, sem gate hoje)

## 1. Contexto

Toolkits de lint (fonte do M4 no runbook v1.3.0: `quality/max-lines` do
`vibe-coding-toolkit`) costumam impor teto de tamanho de arquivo (ex.: 350
linhas) com isenção para módulos só-de-declaração. Neste porte, o
`diff-audit.sh` não possui nenhum teto de tamanho: não há dor observada que
justifique criá-lo. Criar o teto só para absorver a isenção inverte a escada
Ponytail (precisa existir? já existe? o nativo resolve?) e força fragmentação
artificial de contratos, schemas e tipos extensos.

## 2. Decisão

1. **Rejeição de teto arbitrário hoje:** nenhum gate de tamanho é criado
   nesta Etapa. `diff-audit.sh` permanece intocado por este item e nenhuma
   contagem de linhas (`wc -l`, regex, nome/extensão de arquivo) vira
   veredito neste repositório.
2. **Isenção sintática futura:** se um gate de tamanho um dia nascer de dor
   comprovada, a isenção de módulos puramente declarativos (tipos,
   interfaces, schemas, enums sem statements executáveis) será decidida por
   sintaxe (AST da linguagem), nunca por nome de arquivo. Uma única linha
   executável no arquivo revoga a isenção.
3. **Par de provas obrigatório:** nenhum gate dessa natureza é ativado sem
   o par determinístico — (A) arquivo puramente declarativo com mais de 350
   linhas aprovado com exit 0; (B) o mesmo arquivo acrescido de 1 linha
   executável reprovado. Sem o par verde, o gate não entra.

## 3. Consequências

- Positivas: zero código novo para um problema inexistente; a fronteira
  fica registrada e impede que um teto ingênuo futuro puna arquivos
  declarativos legítimos ou seja burlado por compactação.
- Negativas: a proteção é só documental até o gatilho existir; um gate
  futuro precisará implementar a análise sintática e o par de provas do
  zero (custo aceito, adiado para quando houver dor).

## 4. Alternativas Consideradas

- Criar agora o teto de 350 linhas com a isenção: overengineering sem dor
  observada — rejeitada.
- Isenção por nome/extensão de arquivo: burlável e cega ao conteúdo —
  rejeitada em favor da isenção sintática quando (e se) o gate existir.
