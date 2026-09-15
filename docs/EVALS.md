# Guia de replicação — dinâmica de evals do harness

Como opera o `smoke-eval` (validado no piloto `553b3bc`, 5/5 critérios) e como
replicar em outro harness. Ver artefatos: `evals/CRITERIA.md`, `evals/run.sh`.

## 0. Pré-requisitos

O eval não cria segurança, só a mede. Exige algo executável com contrato
observável. Aqui: `hooks/safety-gate.py` (imprime
`CEH-SAFETY ALLOW|WARN|DENY <env> :: motivo`, exit sempre 0) e
`scripts/canonical-diff.sh` (exit 0/1/2). No outro harness, use o equivalente:
qualquer script com saída estruturada + exit code.

## 1. Critério antes das fixtures

Arquivo `evals/CRITERIA.md` escrito primeiro e imutável após o primeiro
resultado. Define APROVA (baseline 3× verde <60s + deriva A vermelha +
deriva B vermelha + restauração verde + barra de regressão) e DESCARTA
(qualquer falha → ADR de descarte + remover `evals/`). Sem isso o piloto é
auto-confirmatório (exigência do conselho).

## 2. Fixtures que executam, não que leem

Cada fixture invoca o código real com ambiente controlado
(`env -i … CEH_ENV=production` vs branch real sem overrides) e asserta só
tokens do contrato + exit code — nunca prosa de docs. Regras:

- Pares de forma equivalente: comando malicioso e sua variante (`push --force`
  e `push -f …`) mantêm o veredito; benigno (`git status`) continua liberado.
- Cobertura da tabela inteira: nega em produção, libera em dev, alerta em
  staging, fallback sem comando, catastrófico, largura de padrões.

## 3. Runner fail-closed

Hook ausente = `INFRA-FAIL` exit 1 imediato (nunca verde silencioso —
gate silenciosamente ausente é pior que sessão brickada, ADR-004). Saída por
fixture `PASS/FAIL` + `WALL=` + exit 0/1. Teto: parede ≥60s = vermelho.

## 4. Baseline

3 corridas seguidas, todas verdes, cronometradas, offline, sem LLM-judge.

## 5. Deriva A (histórica)

Remove-se 1 peça cuja ausência o próprio histórico já provou dolorosa
(aqui: hook movido para `/tmp`, eco do incidente ADR-004). Esperado:
vermelho de infra. Restaura, espera-se verde.

## 6. Deriva B (silenciosa)

Enfraquece-se 1 token sem quebrar nada (aqui: `("prod",…)`→`("live",)` no
`normalize_env`). Esperado: vermelhos comportamentais com exit codes
idênticos e sem crash — escalada silenciosa capturada. Restauração
byte-idêntica (`git diff` vazio) → verde.

## 7. Veredito

Tabela APROVA/DESCARTA do passo 1, aplicada sem ajuste retroativo.
Promoção = commit na `dev`, sem push automático a `main`. Descarte = ADR +
remoção de `evals/`. Decisão final sempre humana.

## 8. Camada do conselho (opcional, para decisões)

Mesma pauta via one-shot aos CLIs das cadeiras em paralelo, cada um
devolvendo VOTO + fundamento + risco + condição; síntese consolida as
exigências. Pré-requisito: 1 ping por cadeira com zero fallback antes da
pauta (ver lição do header `x-opencode-session`).

## 9. Checklist de replicação (só 4 adaptações)

1. Caminho do executável e seus tokens de veredito.
2. Sinais de ambiente dele (branch, env vars, arquivos).
3. Deriva A extraída do próprio histórico de incidentes.
4. Deriva B como remoção mínima que inverte uma decisão sem crash.

O resto — critério prévio, runner, 3+2+1 corridas, tabela de veredito — é
portátil sem alteração.

## 10. Validação do guia

**Assumptions:** o harness destino tem ao menos 1 script com saída
estruturada + exit code; existe histórico de incidentes para extrair a
deriva A; quem replica tem permissão de executar o hook fora de sessão.

**Missing Information:** teto de tempo ideal para harnesses com suítes
lentas (>60s legítimos); padrão de eval para gates que exigem rede/MCP.

**Recommendations:** começar pelo passo 1 mesmo antes de ter fixtures;
rodar deriva B primeiro se o histórico for pobre; revisitar o teto de 60s
após 3 pilotos em harnesses distintos.
