# ADR 004 — `plugins update` orfana hooks vivos (fail-closed bricka a sessão)

## 1. Contexto

Após `muse plugins update clearer-muse` (v0.2.0 → v0.3.0, OBSERVED 2026-09-13),
o diretório de cache trocou (`1f7bed62…` → `f22a6cf3…`) mas o comando do hook
`safety-gate` da sessão viva continuou apontando para o path absoluto antigo.
Resultado: `ENOENT` no hook em **toda** chamada de ferramenta (leitura
inclusive) — sessão operacionalmente brickada até o restart.

## 2. Decisão

1. Documentar como rotina: **todo `plugins update` exige restart da sessão**;
   no boot, o runtime re-resolve o path do hook para o cache novo (confirmado:
   pós-restart as ferramentas voltaram; novo cache `4a9fcf9e…` com hook íntegro).
2. Se o aviso "hooks require review" persistir pós-restart:
   `muse plugins approve clearer-muse` (hook é código próprio deste repo).
3. Não vendorizar workaround no repo agora (ex.: wrapper que resolve
   `installed.json` em runtime): o registro do comando do hook é estado do
   runtime, não deste repo — anotar como melhoria candidata.

## 3. Consequências

- Positivas: procedimento conhecido, sem improviso; fail-closed do hook
  continua valendo (sessão brickada é melhor que gate silenciosamente ausente).
- Negativas: `update` no meio de um turno interrompe o turno; agendar updates
  para início de sessão.

## 4. Alternativas Consideradas

- Fail-open em erro de infra do hook: sessão seguiria sem safety-gate sem
  ninguém notar — rejeitada (piora silenciosa).
- Re-aprovar sem restart: o path continuaria inexistente — insuficiente
  sozinho; restart é o passo que re-resolve.
