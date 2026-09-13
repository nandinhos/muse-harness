# ADR 003 — Minimalismo de código como addon opt-in (ponytail)

## 1. Contexto

O dispatcher `clearer` garante rigor e evidência, mas nada continha o
inchamento de código gerado pelo agente (wrappers, dependências novas e
discussões desnecessárias onde o recurso nativo bastava). A metodologia
ponytail (`thisisformuchfun/ponytail`: ordem nativo → instalado → one-liner →
mínimo, com marcação `ponytail:` dos atalhos) trata exatamente disso, mas seus
claims de benchmark (80–94% menos código) são do autor, não verificados aqui.

## 2. Decisão

Adotar o minimalismo como skill addon `code-minimalism`, `enabledDefault:
false`: ordem de preferência + marcação `ponytail:` com upgrade path +
seção "quando NÃO aplicar" (didático, scaffold, auth/segurança, compliance).
Ativação por tarefa, com medição local antes/depois (linhas + `token-budget`).

## 3. Consequências

- Positivas: menos código gerado onde o nativo basta; atalhos auditáveis pela
  marcação; custo de contexto do addon só quando ativado.
- Negativas: risco de obscuridade se aplicado onde verbosidade é requisito
  (contido pela blacklist da skill); claims externos seguem não verificados.

## 4. Alternativas Consideradas

- Fundir no dispatcher `clearer`: poluiria o ciclo rigor/evidência — rejeitada.
- Vendorizar o repo ponytail: acoplamento e licença a verificar — rejeitada;
  referência + adaptação própria.
