---
name: token-economy
description: Addon de gestao de tokens do harness. Aplica orcamento por artefato, compressao de saidas verbosas e higiene de contexto; usa rtk quando disponivel, com fallback nativo.
---

# Token Economy (addon)

Tríade de economia portada do CEH, sem dependência obrigatória externa:

1. **Navegação cirúrgica** (equivale ao Graphify): `search` + leitura fatiada (`offset`/`limit`); proibido despejar arquivo inteiro sem necessidade. Histórico Git via `scripts/git_inspect.py --repo <path> --limit N` (JSON declarativo) em vez de scripts ad-hoc.
2. **Compressão de shell** (equivale ao RTK): se `rtk` estiver no `PATH`, prefixe comandos verbosos (`rtk git diff`, `rtk pest`, `rtk sail logs`); senão, envolva com `scripts/compress-output.sh`.
3. **Higiene de sessão**: histórico e dumps pesados fora do contexto; "pense em código".

## Guarda de contexto (obrigatória — incidente 2026-11-18)

Causa raiz provada: sessão única sem reinício por etapa; o histórico foi de
39k → 442k tokens e cada um dos 367 passos re-enviou tudo (amplificado por
loops editar→testar, saídas verbosas retidas, 20 subagentes no modelo full
e skills residentes). Correções em ordem de ganho:

1. **Reinicie a sessão por etapa.** Rode
   `python3 scripts/context-guard.py --session <session.jsonl>` no fecho de
   cada etapa: `WARN` (≥150k tok no último passo ou ≥80 passos) = planeje
   fechar; `BLOCK` (≥300k ou ≥200 passos, exit 2) = **não** inicie etapa
   nova nesta sessão — feche com handoff ≤1k tok e reinicie. Continuar
   multiplica o custo de todos os passos seguintes.
2. **Trunque a saída de `bash` antes de ela entrar no histórico.**
   Comandos verbosos sempre via `scripts/compress-output.sh` (teto duro de
   16k chars) ou com `| head`/`| tail` explícitos; nunca despeje log bruto.
   Saída retida no histórico é re-paga em cada passo seguinte.
3. **Não repita trabalho em subagentes.** Delegue com Evidence Pack
   (arquivos já inspecionados com `arquivo:linha`); o filho **não** relê o
   que o pai já leu — recebe o resumo. Prefira o modelo leve
   (`muse-spark-1.3`) para investigação read-only; `full` só decide/revisa.
   Tarefa LOW não usa subagente (ver `clearer-orchestration`).
4. **Meça o custo real, nunca o bruto.** A métrica oficial é
   `custo_real = (input − cached) + output`, via
   `python3 scripts/session_cost.py <session.jsonl|dir>`. `input_tokens`
   bruto inclui cache relido por passo e superestima o gasto em até ~40×
   (98,8M brutos = ~2,18M reais na sessão do incidente). Relatar o bruto
   como “gasto” é claim `UNSUPPORTED`.

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
