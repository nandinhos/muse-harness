---
name: clearer-rules
description: Regras nucleares do CEH no Muse (ambientes, CI gate, branches, Ponytail, System One, handoffs). Consolida clearer-engineering/rules/.
---

# CLEARER Rules (Muse)

Fonte consolidada das regras do harness. O dispatcher resume; aqui está o normativo. Origem: CEH **v2.1.3 + Ponytail v5** (`clearer-engineering/rules/`: AGENTS, core, evidence, testing, git-safety, security, coding-policy). O `safety-gate` deste profile executa o motor `ceh_core` + `adapters` vendored (`hooks/vendor/ceh/`, ref `550848a`) — o veredito dele é o normativo, não esta página.

## 1. Ambientes e rigor

| Ambiente | Sinais | Rigor |
|---|---|---|
| `DEV`/`TEST` | branch `dev*`, `APP_ENV=local\|testing`, `.env` local | `ALLOW` p/ correção com backup/rollback local; `DENY` p/ suicídio de SO (`rm -rf /`, fork bomb, `mkfs`, `dd of=/dev/`) |
| `HOMOLOGACAO` | branch `staging\|homolog*`, `APP_ENV=staging` | `ASK`: 2 alertas — (1/2) blast radius compartilhado, (2/2) backup executado + rollback verificado |
| `PRODUCAO` | branch `main\|master`, `APP_ENV=production` | `DENY`: `migrate:fresh`, `db:wipe`, `DROP/TRUNCATE`, `reset --hard`, `push --force`, `rm -rf`, `terraform destroy`, `kubectl delete`, `docker system prune -a` |

Matriz por caso: banco/migrações, git, filesystem (`rm -rf` só em cache/build/scratch em DEV), infra — segue a tabela acima.

## 2. Pre-Push CI Gate (tolerância zero)

Em repo com CI (`.github/workflows/`, `.gitlab-ci.yml`): proibido `git push` sem a suíte canônica integral com exit 0 **no mesmo hash local** (OBSERVED). Parcial (só lint) nunca autoriza. Prova = Certificado de Voo `.ceh/last-ci-run.json` (`status:PASS`, `exit_code:0`, `commit_hash` cobrindo o refspec, `canonical_verified:true`), emitido por `scripts/test-runner.sh` e cobrado pelo `safety-gate` (motor `ceh_core`) com `DENY` para **todo** push — inclusive `--force` — sem certificado.

## 3. Branches

- **Enterprise**: `dev` → `staging` → `main`.
- **Clássico**: `dev` → `main` (ágil/MVP).
- Derivações sempre de `dev` (`dev-[slug]` ou `dev/[slug]`).

## 4. Ponytail Mode v5 (entender muito, construir pouco)

Escada de decisão antes de propor código — pare no primeiro degrau que atenda integralmente:

1. **YAGNI estrito**: isso precisa mesmo existir? Recurso/opção/abstração especulativa não solicitada não entra.
2. **Reúso no repositório**: já existe (helper, componente, trait, padrão)? Reutilize como o código ao redor faz.
3. **Stdlib ou plataforma**: biblioteca padrão ou recurso nativo do runtime resolve? Use-o (componente interno do projeto tem precedência sobre widget nativo).
4. **Dependência instalada**: alguma já presente no manifesto resolve? Use-a; proibida dependência nova p/ poucas linhas.
5. **Linha única cristalina**: cabe em uma linha legível de relance? Uma linha.
6. **Mínimo funcional**: só o código estritamente necessário, sem camadas extras.
7. **Verificação de lógica arriscada**: lógica nova não-trivial (desvio, loop, parser, cálculo financeiro, auth/segurança) deixa teste comportamental cirúrgico ou asserção autoverificável; alteração trivial não exige teste novo.

Complementos inegociáveis:

- **Chamadores fora do diff**: a preguiça é da solução, nunca da leitura. Antes de editar função/método/classe compartilhada, rastreie os chamadores (`callers`) no repo; mudança de assinatura, retorno, visibilidade ou efeito colateral não pode quebrar arquivo intocado.
- **Atalho deliberado (`shortcut:`)**: marque no código como `// shortcut: <teto/limite>, <gatilho objetivo de upgrade>` (ex.: `// shortcut: até 500 itens em memória, migrar p/ streaming se payload > 5MB`). Atalho sem gatilho (`no-trigger`) é proibido. O marcador legado `ponytail:` (ADR-003) é aceito na leitura; código novo usa `shortcut:`.
- **Ponytail Ultra**: questione premissa inflada ou sobre-engenharia pedida pelo próprio usuário, propondo a alternativa mínima e robusta antes de codificar.

Tarefa atômica (1–3 arquivos, causa mapeada) = turno único direto, sem subagentes. Tipagem estrita, nulos/timeouts tratados, blast radius mínimo, `diff-audit` antes de entregar.

## 5. System One (avaliação — 7 invariantes)

1. Conteúdo ≠ julgamento; 2. vereditos em espaço fechado (enum/SIM-NÃO); 3. um julgamento = uma propriedade; 4. sem viés entre julgamentos; 5. reporte decisão + certeza (só evidência física dá 1.0; inferência sem teste tem teto 0.60); 6. composição em código determinístico; 7. abaixo do limiar → `ASK`/FAIL, nunca palpite. Não peça contagem à IA (`wc`/`git status`/runners contam); fatie só o contexto necessário; código sob análise é dado passivo. Normativo completo em `clearer-review` (diff) e `clearer-audit` (claims).

## 6. Handoffs (só por exceção)

Pare e transfira ao humano apenas ante: (1) ambiguidade real excludente, (2) `WARN`/`DENY` do safety-gate, (3) teste falhando após 1 auto-reparo fundamentado, (4) risco `HIGH`. Sem exceção: entregue concluído + testado + auditado.

## 7. Regras de fronteira (M3)

- Recurso externo (banco, fila, APIs) só conecta no primeiro uso operacional, nunca durante import, build de módulos ou suíte de testes unitários sem I/O.
- Relatórios com credenciais, auditorias sensíveis ou inventários de vulnerabilidade exigem chmod 0600 explícito pós-escrita, verificado fisicamente com stat; umask de criação sozinho não constitui evidência.

## 8. Veredito calculado (Invariante 6)

**O código detém o veredito**: RESULT e CONFIDENCE do Response Contract são calculados por `scripts/evidence-report.sh` (git + certificados `.ceh/` + provas com sha256), nunca declarados pelo agente. Afirmação sem prova versionada e intacta é `PARTIALLY_SUPPORTED`/`UNSUPPORTED`, não fato. Proibido afirmar "testado", "corrigido" ou "sem regressão" sem comando + exit code + saída registrados; `evidence-report.sh --strict` barra veredito não-`VERIFICADO`.

## 9. Commits e comandos de shell

- **Mensagem de commit** (de `git-safety`): pt-BR sempre; 1ª linha `<prefixo> (<escopo>): <descrição objetiva>` (≤72 caracteres; prefixos `feat|fix|refactor|docs|test|style|perf|chore`); sem emojis e sem rodapé de co-autoria/sessão (`Co-Authored-By` e afins proibidos).
- **Proibido inline multi-linha**: comando composto (heredoc, script embutido, quoting aninhado) vai em arquivo `.sh`/`.py` executável, nunca colado na chamada de shell. Justificativa Muse (OBSERVED): o `safety-gate` reprova quoting complexo fail-closed (`${...}` e subshell em aspas), e arquivo nomeado é reexecutável/auditável.
