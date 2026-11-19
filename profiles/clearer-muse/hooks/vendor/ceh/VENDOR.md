# Vendor do núcleo CEH (`ceh_core` + `adapters`) — Opção B do handoff-060

> Cópia vendorizada (byte-identical) do motor de políticas portável e dos
> adaptadores de host do CLEARER Engineering Harness. **Nunca editar estes
> arquivos à mão** — atualizar só pelo procedimento abaixo.

## Proveniência (OBSERVED)

| Item | Valor |
|---|---|
| Origem | `clearer-engineering/scripts/{ceh_core/,adapters/,safety-gate.py,hook_context.py}` |
| Ref validada | `4db20b7` (`main`, CEH **v2.3.1**, Etapa 4/F5; anteriores: `550848a` v2.1.3, `76eaf76` v2.1.2) |
| Extração | `git archive 4db20b7 <paths>` (sem `__pycache__`); drift vs. `550848a` = só `ceh_core/push.py` (+`is_tree_identical` no Pre-Push Gate) e `adapters/antigravity.py` (cwd/`git -C`, inerte no Muse) |
| sha256 do bundle (23 arquivos `.py`) | `eed5a05162b5bcdc7516c0648704d69c3822c1ff533d3d5f1eb90b7b4e07c6f7` |
| Verificação (reproduzível; cobrada em `C13`) | `(cd hooks/vendor/ceh && find . -type f -name '*.py' \| LC_ALL=C sort \| xargs sha256sum \| sha256sum)` |
| Consumidor | `../safety-gate.py` (adapter fino do host Muse sobre `adapters/muse.py`) |

## Atualização

```bash
cd <checkout-antigravity-clearer-engineering-harness>
git archive <nova-ref-validada> clearer-engineering/scripts/ceh_core \
  clearer-engineering/scripts/adapters \
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
  e o adapter voltou a delegar 100% ao motor. Desde a v2.1.2 o check vive em
  `ceh_core/engine.py` (invariante P2).
- **CC2 (ATIVO, revisão Codex 2026-11-19)**: o adapter `../safety-gate.py`
  adiciona apenas controles de borda do host Muse, sem editar o bundle:
  (a) ferramentas desconhecidas com formas executáveis alternativas
  (`cmd`, `chars`, `args`, `input.command`, ...) são avaliadas como
  terminal; `muse.workflow/script` é exceção porque as ferramentas filhas
  voltam ao PreToolUse; (b) lojas de credencial conhecidas são bloqueadas
  em leitura/escrita por ferramenta de arquivo; (c) comando cujo executável
  é só uma variável ou `eval` com expansão é negado como dinâmico não
  inspecionável; (d) comentário puro não derruba o motor e qualquer exceção
  de avaliação vira deny dual, nunca traceback. Se o upstream absorver
  essas bordas, remover o CC2 e registrar aqui.
