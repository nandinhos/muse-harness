# [CEH Core] Fork bomb clássico retorna `allow` — lexer fragmenta antes do casamento de padrões catastróficos

> **Cópia persistida em repo** (2026-09-28) do draft que vivia em `/tmp/ceh-forkbomb-issue.md`
> (volátil — some se a máquina reiniciar). **RESOLVIDA via Handoff 061 sem abrir issue**:
> upstream corrigiu em `main 6fc5a07` (CEH v1.3.1, early catastrophic check +
> flags `--command`/`--cwd`); Muse re-vendored e removeu o CC1 (`clearer-muse` v0.8.1).
> Corpo abaixo verbatim do draft original, preservado como registro.

---

> Draft p/ abrir em `antigravity-clearer-engineering-harness` (issues). Evidências OBSERVED em 2026-09-28.

## Reprodução

```bash
cd /home/nandodev/projects/clearer-engineering-harness  # staging == origin/staging @ 525da48 (CEH v1.3.0)
python3 clearer-engineering/scripts/safety-gate.py --check ':(){ :|:& };:'
echo "EXIT=$?"
```

## Esperado

`decision: deny`, severity `CATASTROPHIC`, exit `2` (`CATASTROPHIC_PATTERNS` casa fork bomb).

## Obtido (OBSERVED)

```json
{
  "decision": "allow",
  "reason": "Command complies with CEH safety policy ...",
  ...
}
```

`EXIT=0`. Reproduz em `dev`/`staging`/`production` (via `--env`; CC1 do host Muse confirma o `allow` do motor puro nos 3 ambientes).

## Causa provável

`ceh_core/lexer.py::split_shell_pipeline` fragmenta a linha em `;`/`&`/`|` **antes** da avaliação contra `CATASTROPHIC_PATTERNS` (`ceh_core/rules.py`): nenhum fragmento isolado (`:(){ :`, `:`, `}:` …) casa o padrão do fork bomb, então cada fragmento avalia `allow` e o veredito agregado nunca vê a linha inteira.

## Impacto

Bypass completo do safety-gate p/ a catástrofe de SO mais clássica — em qualquer harness consumidor do `ceh_core` (Antigravity, Muse, Codex). Severidade: **security / CATASTROPHIC**.

## Sugestão de correção (não prescritiva)

Avaliar `CATASTROPHIC_PATTERNS` sobre a **linha bruta normalizada** antes de fragmentar (fail-closed primeiro, paths caros depois), ou casar os padrões em cada fragmento **e** na linha inteira. Se o fix mudar vereditos de pipelines benignos, cobrir com `test_lexer_fuzz.py` + matriz `test_safety_matrix.py`.

## Mitigação downstream (referência)

O host Muse aplica enquanto isso o controle compensatório **CC1**: mesmos `CATASTROPHIC_PATTERNS` do motor sobre a linha bruta antes de delegar (`profiles/clearer-muse/hooks/safety-gate.py::_cc1_catastrophic`, documentado em `hooks/vendor/ceh/VENDOR.md`). CC1 será removido quando o upstream corrigir — favor referenciar esta issue no fix p/ sabermos quando re-vendar.

## Checklist do repórter

- [x] Reproduzido no `staging` atual sem override de ambiente
- [x] Confirmado motor puro (`allow`) vs CC1 (`DENY`) no host Muse (C11 `test_ceh_core_contract.sh`)
- [x] Fix + teste de regressão no upstream (`2654e64`, `test_catastrophic_fork_bomb_blocked_in_all_envs`)
- [x] Re-vendar `ceh_core` no Muse + remover CC1 após o fix (handoff-061, v0.8.1; C11+C14 verdes)
