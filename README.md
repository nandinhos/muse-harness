# muse-harness — Casa canônica dos profiles harness do Muse Code

Documentação e fonte canônica de **como criar um profile harness dentro do Muse**,
extraídas da construção real do profile `clearer-muse` (CLEARER Engineering Harness)
no projeto `events`. Sem segredos neste repo: chaves vivem no ambiente do host
(`~/.bashrc`, modo 600) e entram via expansão `${VAR}` — nunca em arquivo versionado.

## Estrutura

| Caminho | Conteúdo |
|---|---|
| `profiles/clearer-muse/` | Cópia canônica do profile (skills, commands, hooks, scripts, manifest) |
| `docs/CREATE-PROFILE.md` | Guia técnico: criar um profile harness do zero |
| `templates/mcp.json` | Template `.mcp.json` (placeholders `${}`, sem segredos) |
| `adr/` | Decisões arquiteturais do harness (Context7, lições) |

## Estado

- Profile `clearer-muse` v0.1.0 + seções 6 (endosso Context7) e 7 (lições) — espelha o
  que roda no `events`, promovido de lá por cópia verificada (`diff -r` idêntico).
- Ativação num projeto: ver `docs/CREATE-PROFILE.md` §5 (aponta a fonte instalada para
  `profiles/<nome>` e reinicia a sessão).

## Regras deste repo

- Nenhum segredo commitado (gitleaks como rede, nunca como plano).
- PT-BR nos docs; prefixos de commit do projeto consumidor quando houver código.
- Toda afirmação técnica com fonte: arquivo, comando+saída ou teste.
