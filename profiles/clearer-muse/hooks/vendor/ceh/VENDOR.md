# Vendor do núcleo CEH (`ceh_core`) — Opção B do handoff-060

> Cópia vendorizada (byte-identical) do motor de políticas portável do
> CLEARER Engineering Harness. **Nunca editar estes arquivos à mão** — atualizar
> só pelo procedimento abaixo.

## Proveniência (OBSERVED)

| Item | Valor |
|---|---|
| Origem | `clearer-engineering/scripts/{ceh_core/,safety-gate.py,hook_context.py}` |
| Ref validada | `1b26e10` (`staging`, CEH **v1.3.0**, handoff-060) |
| Extração | `git archive 1b26e10 <paths>` (sem `__pycache__`) |
| sha256 do bundle (13 arquivos `.py`) | `d89128dcde42475287851f39d9c2d3ff8ece0309310a291ecc757a2361918599` |
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

- **CC1**: o adapter aplica `CATASTROPHIC_PATTERNS` do próprio motor sobre a linha
  de comando **bruta** antes de delegar — o lexer FSM do motor fragmenta
  pipelines (`;`, `&`), então o fork bomb clássico `:(){ :|:& };:` não casa o
  padrão em nenhum fragmento e o motor puro retorna `allow` (OBSERVED em
  2026-09-28, dev e production). CC1 usa os padrões do motor (zero lógica
  duplicada) e deve ser removido quando o upstream corrigir a detecção.
