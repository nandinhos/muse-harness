# ADR 010 — Aceitação formal dos resíduos da revisão Codex (2026-11-19)

## 1. Contexto

A revisão externa Codex v0.12.1 (HANDOFF.md §13) corrigiu o que era
corrigível localmente e deixou 4 resíduos registrados no backlog §12
como itens fora da correção daquela rodada. Eles permaneciam como
pendência aberta sem dono de decisão.

## 2. Decisão

Aceitos formalmente como limites conhecidos do desenho atual:

1. **Certificado sem assinatura criptográfica.** O modelo de confiança
   é local: o G9 protege escrita via ferramentas, mas o certificado
   (`.ceh/last-ci-run.json`) não é proveniência criptográfica.
2. **Execução dinâmica além dos padrões compensatórios CC2.** O gate
   estático cobre os padrões documentados em `VENDOR.md`; formas novas
   de execução dinâmica fora deles são limite do gate, não bug aberto.
3. **Leitura de segredos via shell.** O gate bloqueia caminhos de
   credencial conhecidos em ferramentas de arquivo e padrões no motor;
   leitura arbitrária via shell permanece fora do alcance estático.
4. **`install.sh` em update usa fonte/escopo já registrados.** Troca de
   fonte exige `muse plugins remove` + `install` (mensagem já corrigida);
   não haverá detecção automática de troca de fonte.

## 3. Consequências

- O item "Resíduos da revisão externa Codex" no HANDOFF.md §12 fecha
  como **aceito** por esta ADR, não como pendência aberta.
- Reabrir qualquer limite exige ADR nova que o supersede, com caso
  concreto (incidente ou bypass reproduzido), não preferência genérica.
- Nenhum código muda por esta ADR.
