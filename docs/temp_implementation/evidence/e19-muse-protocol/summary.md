# E19 — Sonda local do protocolo PreToolUse do Muse (Fase 0, gate da absorção v2.1.2)

Data: 2026-10-10. Método: wrapper-passthrough temporário sobre o hook instalado,
registrando argv+stdin em `/tmp/e19-probe.log` (12 disparos reais) + 3 canários.
Wrapper removido após a sonda; hook do cache restaurado byte-identical
(`diff` contra backup OK) e hook do repo verificado `git diff` vazio.

## Achados (todos OBSERVED)

1. **O runtime executa o hook a partir do CACHE**, não do `source.path`:
   `~/.local/share/muse/plugins/cache/.../package/hooks/safety-gate.py`.
   Sonda no repo = 0 disparos; sonda no cache = 12 disparos.
2. **Invocação**: `argv=[<hook>]` sem argumentos; payload JSON via stdin (572 B
   típico p/ bash); cwd do processo = raiz do projeto.
3. **Payload real** (`probe-redacted.log`, ids redigidos):
   `{cwd, hook_event_name:PreToolUse, model, model_provider:meta,
   permission_mode, session_id, tool_input, tool_name, tool_use_id,
   transcript_path:null, turn_id}`.
   - `bash`: `tool_input={command, description, workdir}`.
   - `write_file`: `tool_input={content, path}` (sem `workdir`; `cwd` top-level).
   - `submit_reminder_decision`: ferramenta interna, sem comando nem escrita.
4. **`{"decision":"block"}` + exit 0 BLOQUEIA de verdade**: canário
   `CEH_CANARY_PROBE_E19*` em bash e em write_file retornou
   `tool blocked by hook: E19 canary probe block` (a carga útil do próprio
   wrapper-v1 foi bloqueada ao ser escrita — prova incidental de write_file).
5. **Linha `CEH-SAFETY DENY` NÃO bloqueia**: canário advisory com saída
   `CEH-SAFETY DENY production :: ...` + exit 0 teve a chamada EXECUTADA
   normalmente (exit 0, stdout entregue). Gap de enforcement confirmado:
   o adapter atual é consultivo; só o JSON nativo impõe.

## Consequência de desenho (F1/F2.1)

- Adapter novo deve responder JSON nativo no stdout (`{}` allow /
  `{"decision":"block","reason"}` deny+ask, sempre exit 0) — igual ao
  `MuseAdapter` upstream — e manter a linha `CEH-SAFETY` no stderr como
  trilha auditável (contrato dual; cobre runtime advisory-only se existir).
- `MuseAdapter.detect` upstream (sem `toolCall` + `model_provider`/`turn_id` +
  tool names) casa com o payload real observado aqui.

## Arquivos

- `probe-redacted.log`: 12 disparos (5 bash, 5 submit_reminder_decision,
  2 write_file), 7 marcações CANARY; `session_id`/`tool_use_id`/`turn_id`
  redigidos via sed (comando registrado no HANDOFF da absorção).

## Nota de classificação (pós-conselho F4.2 — honestidade de evidência)

O log registra o lado do hook (o que foi emitido). O lado do runtime (o que o
Muse fez com a resposta) foi observado no transcript da sessão, não persistido
em arquivo — classificação honesta: PARTIALLY_SUPPORTED para a metade runtime:

- bash + `{"decision":"block"}` → eco do runtime: `tool blocked by hook: E19
  canary probe block` (chamada não executou).
- write_file contendo o token canário → mesmo eco de bloqueio (prova
  corroborada no disco: o wrapper-v1 teve de ser reescrito com o token fatiado
  `_P = "CEH_CANARY" + "_PROBE_E19"` para conseguir ser gravado).
- advisory `CEH-SAFETY DENY …` + exit 0 → chamada EXECUTADA (stdout entregue,
  exit 0); depende só do transcript.

Por isso o contrato dual (JSON impõe + stderr audita) é o desenho seguro nos
dois mundos: se um runtime futuro ignorar o JSON, a trilha `CEH-SAFETY` continua
vinculante pela skill; se só honrar o JSON (este runtime), o block é mecânico.
