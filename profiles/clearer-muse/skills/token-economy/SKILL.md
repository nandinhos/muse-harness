---
name: token-economy
description: Addon de gestao de tokens do harness. Aplica orcamento por artefato, compressao de saidas verbosas e higiene de contexto; usa rtk quando disponivel, com fallback nativo.
---

# Token Economy (addon)

Tríade de economia portada do CEH, sem dependência obrigatória externa:

1. **Navegação cirúrgica** (equivale ao Graphify): `search` + leitura fatiada (`offset`/`limit`); proibido despejar arquivo inteiro sem necessidade.
2. **Compressão de shell** (equivale ao RTK): se `rtk` estiver no `PATH`, prefixe comandos verbosos (`rtk git diff`, `rtk pest`, `rtk sail logs`); senão, envolva com `scripts/compress-output.sh`.
3. **Higiene de sessão**: histórico e dumps pesados fora do contexto; "pense em código".

## Regras

1. Antes de ler um artefato grande, estime com `python3 scripts/token-budget.py <arquivo...>` (≈ `chars/4` tokens). Classificação: `ok` (≤ 8k), `fatie` (> 8k — leia em janelas), `resuma` (> 32k — extraia via busca primeiro).
2. Comandos verbosos (`git diff`, `git log`, suítes de teste, logs do Sail/Docker) SEMPRE via `scripts/compress-output.sh <comando...>` (ou `rtk`, se presente). O exit code original é preservado; head+tail com contagem do omitido valem como `OBSERVED`, e a saída bruta segue acessível reexecutando sem o wrapper (escape hatch).
3. Nunca cole o mesmo dump duas vezes no contexto; referencie arquivo:linha.
4. Um ciclo de auto-reparo de teste com evidência; falhou de novo → handoff (regra do dispatcher `clearer`).
5. Feche a tarefa com `/token-report` quando a sessão envolveu logs grandes: registra gasto estimado vs. orçamento.
6. Densidade de palavras no contexto: prefira tabelas a parágrafos para estado
   comparativo; cite `arquivo:linha`, nunca recole o mesmo dump duas vezes;
   condense prosa de handoff ao essencial verificável (quem, o quê, evidência).

## Orçamento padrão por tarefa

| Classe | Teto estimado |
|---|---|
| Leitura única de arquivo | 8k tokens (`fatie` acima) |
| Saída única de comando (comprimida) | 4k tokens |
| Evidence Pack entre subagentes | 2k tokens |
| Handoff/resumo entre sessões | 1k tokens |

Tetos são metas de higiene, não limites rígidos: estoure apenas com justificativa `OBSERVED` (ex. stack trace completo necessário ao diagnóstico).
