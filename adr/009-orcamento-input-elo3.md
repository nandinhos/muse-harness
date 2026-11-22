# ADR 009 — Orçamento de Input/turno e Elo3 advisory (pós-auditoria 3 repos)

## 1. Contexto

Auditoria dos repos `antigravity-clearer-engineering-harness`,
`antigravity-harness-enhancements` e `benchmark-antigravity` contra o
profile `clearer-muse` concluiu: o reenvio de histórico é do runtime;
o desenho MEDIUM em turno único amplifica. O benchmark (RULE-OPT-01)
mediu carga fixa de 40.079B para 22.798B por turno.

## 2. Decisão

1. **Teto auditável.** `scripts/input-budget.py` soma os bytes injetados
   por turno (default: regras do usuário + `AGENTS.md` do cwd), com teto
   total de 22.798B e teto por arquivo de 24.000B. Exits: 0 OK, 1 OVER,
   2 BLOCK/ilegível. Tokens são estimativa INFERRED (bytes/4); custo
   OBSERVED continua sendo o `session_cost.py`.
2. **Elo3 advisory, nunca deny.** O hook Muse só decide allow/block;
   reescrever o comando (overwrite do enhancements) não é possível e
   bloquear custaria deny-and-retry (+18,9% medido no E2E-06). O
   `safety-gate` mantém ALLOW e anexa `ELO3-ADVISORY` na trilha para
   `git log` sem limite, `git diff` sem `--stat` e `find /|~` sem
   `-maxdepth`, apontando `git_inspect.py`/`compress-output.sh`.
   `git_inspect.py` (OPT-004) já estava portado.
3. **Dispatch sob demanda.** `ceh-dispatch.py` não detecta ambiente em
   LOW leitura (`nao-verificado`); detecta em MEDIUM/HIGH ou `--with-env`.
   `context-guard.py --last-input/--steps-count` dá o veredito quente
   sem reler a sessão (WARN 150k/80, BLOCK 300k/200).

## 3. Baseline (passo 6) e recalibração N=10

Sessão longa de referência medida com `session_cost.py`: 79 steps,
bruto 9.778.090, cached 94,17%, custo real 603.915 (~7.647/step).

Recalibração CONTROLLED (2026-11-22, N=10 sessões headless idênticas:
`git log --oneline -5` + `git diff --stat`, 3 steps cada, `verdict OK`,
0 `ELO3-ADVISORY` — comandos delimitados silenciam): real/step entre
14.263 e 27.930, mediana 27.624. Ou seja, real/step depende do
comprimento: sessão curta paga a base fria (~48k no 1º step), sessão
longa amortiza via cache. Conclusão: o teto operacional continua sendo
o `last_input_step` do `context-guard.py` (WARN 150k/BLOCK 300k), não
uma média real/step única; média só compara sessões do mesmo tamanho.

## 4. Alternativas rejeitadas

- Portar tudo dos 3 repos: duplicaria o já absorvido (compress-output,
  ADR-008) e importaria telemetria via git e bootstrap `~/.gemini`.
- Elo3 como deny: custo de retry medido, sem ganho de segurança.
