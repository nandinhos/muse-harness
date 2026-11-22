# Issue (p/ mantenedor, host Antigravity) — Fail-open no dispatcher do enhancements

## Resumo
Em `hooks/hooks_dispatcher.py@7318f93` (linha 841), se `_ensure_safety_gate()`
falha no import lazy, todo o Elo 1 (avaliação CEH por ambiente) é pulado em
silêncio e o fluxo segue para Elo 1.5/3, que podem liberar. A exceção dentro
da avaliação é fail-closed (l. 863), mas a falha de carga não é. Mitigante
parcial: padrões catastróficos lexicais do Elo 0 rodam antes. Perde-se
governança por ambiente/pre-push sem nenhum sinal (`_SAFETY_GATE_ERROR`
nunca é lido; telemetria grava `allow`).

Classificação: OBSERVED por leitura de código; suspeito de falso positivo
até reprodução dinâmica (HANDOFF.md §12).

## Reprodução proposta (sandbox, host Antigravity)
1. Copiar os hooks do enhancements para sandbox.
2. Sombrear `hook_context.py` com stub que levanta `ImportError` na carga.
3. Enviar payload benigno e payload destrutivo em produção.
4. Esperado (correto): destrutivo em prod NEGA com import quebrado.

## Correção proposta (se confirmado)
Negar com motivo nomeado `SAFETY GATE UNAVAILABLE`, espelhando o adapter
Muse deste repo (`ENGINE_OK=False` → block dual, caso
`engine-broken-failclosed`).

## Fechamento deste item
- Confirmado → corrigir no enhancements e dar feedback neste repo.
- Refutado → registrar a evidência que refuta no HANDOFF.md §12 e fechar.
