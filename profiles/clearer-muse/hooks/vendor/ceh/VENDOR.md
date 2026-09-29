# Vendor do núcleo CEH (`ceh_core`) — Opção B do handoff-060

> Cópia vendorizada (byte-identical) do motor de políticas portável do
> CLEARER Engineering Harness. **Nunca editar estes arquivos à mão** — atualizar
> só pelo procedimento abaixo.

## Proveniência (OBSERVED)

| Item | Valor |
|---|---|
| Origem | `clearer-engineering/scripts/{ceh_core/,safety-gate.py,hook_context.py}` |
| Ref validada | `6fc5a07` (`main`, CEH **v1.3.1**, handoff-061) |
| Extração | `git archive 6fc5a07 <paths>` (sem `__pycache__`) |
| sha256 do bundle (13 arquivos `.py`) | `6db34ff9e61b5b96650da3c22f0dea99dd3630607ce0f81bbd30ce2350e362ae` |
| Verificação (reproduzível; cobrada em `C13`) | `(cd hooks/vendor/ceh && find . -type f -name '*.py' \| LC_ALL=C sort \| xargs sha256sum \| sha256sum)` |
| Consumidor | `../safety-gate.py` (adapter fino do host Muse) |

## Atualização

```bash
cd /home/nandodev/projects/clearer-engineering-harness
git archive <nova-ref-validada> clearer-engineering/scripts/ceh_core \
  clearer-engineering/scripts/safety-gate.py \
  clearer-engineering/scripts/hook_context.py | tar -x -C /tmp/ceh-vendor
# conferir diff, copiar para cá, atualizar a tabela acima e rodar a suíte:
# bash profiles/clearer-muse/tests/run-all-tests.sh
```

## Controles compensatórios (adapter, não engine)

- **CC1 (REMOVIDO no handoff-061)**: o adapter aplicava `CATASTROPHIC_PATTERNS`
  do próprio motor sobre a linha de comando **bruta** antes de delegar — o
  lexer FSM do motor fragmentava pipelines (`;`, `&`), então o fork bomb
  clássico `:(){ :|:& };:` não casava o padrão em nenhum fragmento e o motor
  puro retornava `allow` (OBSERVED em 2026-09-28). O upstream corrigiu com
  early catastrophic check em `evaluate_command()` (`main 6fc5a07`, CEH v1.3.1)
  e o adapter voltou a delegar 100% ao motor. Nenhum controle compensatório
  ativo no momento.
