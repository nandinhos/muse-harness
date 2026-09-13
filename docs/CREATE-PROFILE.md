# Guia Técnico: criar um profile harness no Muse Code

## 1. Visão Geral

Um *profile harness* empacota metodologia de engenharia (protocolo, rigor por ambiente,
contrato de resposta, economia de tokens) como **plugin nativo do Muse**, instalável em
qualquer projeto. Este guia reproduz a construção do `clearer-muse` (CLEARER Engineering
Harness), validada em uso real no projeto `events` (Laravel 12 + Livewire 4 + Pest).

## 2. Objetivo

Ao final, um diretório `profiles/<nome>/` autocontido que, instalado, faz o agente:
identificar ambiente com evidência, classificar risco, executar ciclos disciplinados,
exigir contrato de resposta e operar dentro de orçamento de tokens — com endosso
externo opcional (Context7) e persistência de lições.

## 3. Escopo

- Dentro: manifest do plugin, skills (dispatcher + addons), commands, hooks de safety,
  scripts utilitários, wiring MCP (`.mcp.json`), runbook de segredos.
- Fora: regras de negócio do projeto consumidor, credenciais (nunca neste repo),
  dependências de runtime proprietário.

## 4. Anatomia de um profile

```text
profiles/<nome>/
  .muse-plugin/plugin.json   # manifest: name, version, skills[], commands[], hooks[]
  skills/<dispatcher>/SKILL.md # skill principal (frontmatter name+description + protocolo)
  skills/<addon>/SKILL.md      # addon opcional (ex.: token-economy)
  commands/<cmd>.md            # comandos invocáveis (/skill, /token-report)
  hooks/safety-gate.py         # hook PreToolUse: veredito WARN/DENY por ambiente
  scripts/*.sh|*.py            # utilitários (compressão de output, orçamento)
```

Contrato do manifest (observado em `plugin.json` do clearer-muse, `schemaVersion: 1`):

- `skills[]`: `{id, path, enabledDefault}` — `path` aponta o `SKILL.md`.
- `commands[]`: `{id, path, enabledDefault}`.
- `hooks[]`: `{id, event: "PreToolUse", command: [...], statusMessage, timeoutMs}`.
- `compat: {manifestDir: ".muse-plugin", source: "native"}`.

## 5. Passo a passo (como foi feito)

1. **Scaffold**: criar a árvore acima; `plugin.json` mínimo com dispatcher.
2. **Dispatcher** (`SKILL.md`, frontmatter `name` + `description` de roteamento):
   identificação de ambiente (branch + `APP_ENV`/`CEH_ENV` + `.env*`, fail-closed para o
   mais restritivo), Risk Dial (`LOW/MEDIUM/HIGH`), protocolo em ciclo único,
   semântica `OBSERVED/INFERRED/UNKNOWN`, Response Contract obrigatório, gestão por
   exceção (4 condições de handoff).
3. **Addons**: skills satélite com gatilho próprio (ex.: `token-economy` — tetos por
   artefato, compressão de shell, `/token-report`).
4. **Safety hook**: `PreToolUse` emitindo veredito por ambiente; `WARN`/`DENY` vinculantes.
5. **Instalação/ativação**: registrar a fonte instalada apontando para
   `profiles/<nome>` (no `events`, `installed.json` referencia o caminho-fonte) e
   **reiniciar a sessão** — skills e MCP só sobem no boot.
6. **Wiring MCP**: copiar `templates/mcp.json` para o `.mcp.json` do projeto e ajustar;
   segredos só via `${VAR}` (ver §6).
7. **Evolução**: melhorias entram primeiro no profile canônico aqui, depois são
   promovidas aos projetos por cópia verificada (`diff -r`), nunca o inverso.

## 6. Segredos (regra absoluta)

- Chave no host: `echo 'export NOME_KEY="..."' >> ~/.bashrc && chmod 600 ~/.bashrc`.
- No `.mcp.json` versionado, só referência: `"env": {"NOME_KEY": "${NOME_KEY}"}`.
- Verificação sem exposição: presença (`grep -c` no bashrc), tamanho (`${#VAR}`),
  e chamada funcional descartando a resposta (`shred -u`).
- Nunca colar segredo em chat (vira log), `.env` de app ou arquivo versionado.

## 7. Validação (checklist de aceite do profile)

- [ ] `python3 -c "json.load(...)"` passa no `plugin.json` e no `.mcp.json`.
- [ ] Skill carrega e o dispatcher declara ambiente + Risk Dial no primeiro turno.
- [ ] Hook emite veredito; `WARN`/`DENY` bloqueiam de fato.
- [ ] MCP aparece após restart; chamada de teste retorna 200 com resultados.
- [ ] `diff -r` entre canônico e cópia instalada: idêntico.
- [ ] Varredura de segredos limpa (nenhum padrão `sk-*`, `Bearer <token>` em arquivo).

## 8. Riscos Técnicos

- Plasticidade de versão: schema do manifest e APIs MCP mudam; pinar `schemaVersion` e
  rever a cada upgrade do CLI.
- Divergência canônico × cópias: sem `diff -r` periódico, projetos derivam em silêncio.
- `.mcp.json` heterogêneo: cada projeto tem servidores próprios — o template é base,
  não overlay cego (merge manual das chaves `mcpServers`).

## 9. Assumptions

- Muse Code carrega plugins da fonte registrada no boot (observado via `installed.json`).
- `npx -y @upstash/context7-mcp` é a distribuição oficial do servidor Context7
  (cf. https://context7.com/docs/resources/all-clients).
- Pre-commit com gitleaks existe nos projetos consumidores (rede, não plano).

## 10. Missing Information

- Comando oficial de (re)instalação de plugin local no Muse (observamos o estado em
  `installed.json`, não o comando que o gerou) — confirmar na doc do CLI.
- Cota anônima exata do Context7 sem API key — assumir limitada até prova.

## 11. Recomendações

- Versionar este repo (`git init` + commits por melhoria) — hoje o canônico ainda não
  tem histórico; cada promoção merece commit.
- Espelhar `.githooks/pre-push`-like por projeto consumidor (gate local antes do push).
- Próximos profiles candidatos: `durable-test-collateral` e `systematic-debugging`
  como skills de primeira classe do harness.
