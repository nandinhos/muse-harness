#!/usr/bin/env bash
# test_evidence_contract.sh — Contrato do relatório canônico de evidências.
# Espelho bash de clearer-engineering/tests/test_evidence_report.py (CEH v1.3.0):
# RESULT/CONFIDENCE são CALCULADOS pelo código, nunca declarados (Invariante 6).
# E15-E17 cobrem a fiação do host Muse (adapter, D3, --json). Hermético.
# Uso: bash profiles/clearer-muse/tests/test_evidence_contract.sh (cwd: raiz; offline)
set -u

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
REPORT="$ROOT/profiles/clearer-muse/scripts/evidence-report.sh"
PASS=0; FAIL=0; FAILED_LIST=""

ok()  { PASS=$((PASS+1)); echo "PASS $1"; }
bad() { FAIL=$((FAIL+1)); FAILED_LIST="$FAILED_LIST $1"; echo "FAIL $1 :: $2"; }

[[ -f "$REPORT" ]] || { echo "INFRA-FAIL: relatório ausente: $REPORT"; exit 1; }

fresh_repo() {
  local d; d=$(mktemp -d)
  git -C "$d" init -q -b main
  git -C "$d" config user.email t@t.invalid; git -C "$d" config user.name t
  printf '.ceh/\n' > "$d/.gitignore"
  printf 'v1\n' > "$d/app.txt"
  git -C "$d" add .; git -C "$d" commit -qm base
  git -C "$d" checkout -qb dev
  printf 'v2\n' > "$d/app.txt"
  printf '{"ok": true}\n' > "$d/proof.json"
  git -C "$d" add .; git -C "$d" commit -qm "feat: v2"
  echo "$d"
}

mkcert() { # <repo> [status] [commit] [canonical] [evals] [evals_commit]
  local d="$1" status="${2:-PASS}" commit="${3:-HEAD}" canonical="${4:-true}"
  local evals="${5:-APROVA}" evals_commit="${6:-HEAD}"
  local head; head=$(git -C "$d" rev-parse HEAD)
  [[ "$commit" == "HEAD" ]] && commit="$head"
  [[ "$evals_commit" == "HEAD" ]] && evals_commit="$head"
  local code=0; [[ "$status" == "PASS" ]] || code=1
  local epassed=5; [[ "$evals" == "APROVA" ]] || epassed=4
  mkdir -p "$d/.ceh"
  cat > "$d/.ceh/last-ci-run.json" <<EOF
{"commit_hash": "$commit", "timestamp": "2026-09-25T00:00:00Z", "command": "make test", "normalized_runner": "make test", "canonical_verified": $canonical, "status": "$status", "exit_code": $code}
EOF
  cat > "$d/.ceh/last-evals-run.json" <<EOF
{"commit": "$evals_commit", "verdict": "$evals", "passed": $epassed, "total": 5, "timestamp": "2026-09-25T00:00:00Z"}
EOF
}

run_rep() { # <repo> [args...] -> stdout; echo RC na última linha é evitado: usa globals
  local d="$1"; shift
  (cd "$d" && env -i PATH="$PATH" bash "$REPORT" --base main "$@" 2>&1)
}

# --- E1: sem certificado => NAO_VERIFICADO, 9 seções, exit 0 ---
T=$(fresh_repo)
O1="$(run_rep "$T")"; R1=$?
SECOK=1; for s in RESULT ENVIRONMENT CHANGES EVIDENCE TESTS REVIEW ACCEPTANCE "REMAINING RISKS" CONFIDENCE; do
  [[ "$O1" == *"## $s"* ]] || SECOK=0
done
if [[ "$R1" -eq 0 && "$SECOK" -eq 1 && "$O1" == *'**NAO_VERIFICADO**'* && "$O1" == *'**NOT_RUN**'* \
  && "$O1" == *'**BAIXA**'* && "$O1" == *'feat: v2'* && "$O1" == *'app.txt'* ]]; then ok "E1-sem-cert-nao-verificado";
else bad "E1-sem-cert-nao-verificado" "rc=$R1 sec=$SECOK out=[$(echo "$O1" | head -c 300)]"; fi
rm -rf "$T"

# --- E2: PASS no HEAD + claims com prova => VERIFICADO/ALTA ---
T=$(fresh_repo); mkcert "$T"; H=$(git -C "$T" rev-parse HEAD)
O2="$(run_rep "$T" --claim "Versão 2 publicada" "proof.json" --criterion "Commit da feature" "commit:$H")"; R2=$?
if [[ "$R2" -eq 0 && "$O2" == *'**VERIFICADO**'* && "$O2" == *'**ALTA**'* \
  && "$O2" == *'[SUPPORTED] Versão 2 publicada'* && "$O2" == *'- [x] Commit da feature'* ]]; then ok "E2-verificado-alta";
else bad "E2-verificado-alta" "rc=$R2 out=[$(echo "$O2" | head -c 300)]"; fi
rm -rf "$T"

# --- E3: PASS sem claims => VERIFICADO/MEDIA ---
T=$(fresh_repo); mkcert "$T"
O3="$(run_rep "$T")"; R3=$?
if [[ "$R3" -eq 0 && "$O3" == *'**VERIFICADO**'* && "$O3" == *'**MEDIA**'* ]]; then ok "E3-sem-claims-media";
else bad "E3-sem-claims-media" "rc=$R3 out=[$(echo "$O3" | head -c 300)]"; fi
rm -rf "$T"

# --- E4: cert obsoleto => STALE + NAO_VERIFICADO ---
T=$(fresh_repo); H=$(git -C "$T" rev-parse HEAD); mkcert "$T" PASS 0000000000000000000000000000000000000000 true APROVA "$H"
O4="$(run_rep "$T")"
if [[ "$O4" == *'**STALE**'* && "$O4" == *'**NAO_VERIFICADO**'* ]]; then ok "E4-cert-obsoleto";
else bad "E4-cert-obsoleto" "out=[$(echo "$O4" | head -c 300)]"; fi
rm -rf "$T"

# --- E5: suíte FAIL => FALHOU ---
T=$(fresh_repo); mkcert "$T" FAIL
O5="$(run_rep "$T")"
if [[ "$O5" == *'**FALHOU**'* ]]; then ok "E5-suite-fail";
else bad "E5-suite-fail" "out=[$(echo "$O5" | head -c 300)]"; fi
rm -rf "$T"

# --- E6: PASS não-canônico => NOT_CANONICAL + NAO_VERIFICADO ---
T=$(fresh_repo); mkcert "$T" PASS HEAD false
O6="$(run_rep "$T")"
if [[ "$O6" == *'**NOT_CANONICAL**'* && "$O6" == *'**NAO_VERIFICADO**'* ]]; then ok "E6-nao-canonico";
else bad "E6-nao-canonico" "out=[$(echo "$O6" | head -c 300)]"; fi
rm -rf "$T"

# --- E7: prova ausente + prova solta => UNSUPPORTED/PARTIALLY + NAO_VERIFICADO ---
T=$(fresh_repo); mkcert "$T"; printf 'x\n' > "$T/loose.log"
O7="$(run_rep "$T" --claim "Sem prova" "nao-existe.json" --claim "Prova solta" "loose.log")"
if [[ "$O7" == *'[UNSUPPORTED] Sem prova'* && "$O7" == *'[PARTIALLY_SUPPORTED] Prova solta'* \
  && "$O7" == *'**NAO_VERIFICADO**'* ]]; then ok "E7-provas-fracas";
else bad "E7-provas-fracas" "out=[$(echo "$O7" | head -c 300)]"; fi
rm -rf "$T"

# --- E8: BLOCKER => contagens calculadas + FALHOU ---
T=$(fresh_repo); mkcert "$T"
O8="$(run_rep "$T" --finding BLOCKER "Quebra de contrato" --finding low "Nome ruim")"
if [[ "$O8" == *'BLOCKER 1 · HIGH 0 · MEDIUM 0 · LOW 1'* && "$O8" == *'**FALHOU**'* ]]; then ok "E8-blocker-falhou";
else bad "E8-blocker-falhou" "out=[$(echo "$O8" | head -c 300)]"; fi
rm -rf "$T"

# --- E9: segredo no diff => FALHOU (chave montada em runtime, nunca literal) ---
T=$(fresh_repo)
KP1="abcdefghijklmnop"; KP2="1234"
printf "api_key = '%s%s'\n" "$KP1" "$KP2" > "$T/cfg.txt"
git -C "$T" add .; git -C "$T" commit -qm cfg
mkcert "$T"
O9="$(run_rep "$T")"
if [[ "$O9" == *'1 padrão(ões) de segredo'* && "$O9" == *'**FALHOU**'* ]]; then ok "E9-segredo-falhou";
else bad "E9-segredo-falhou" "out=[$(echo "$O9" | head -c 300)]"; fi
rm -rf "$T"

# --- E10: status declarado rejeitado (exit 2); --strict sem veredito => exit 1 ---
T=$(fresh_repo)
(cd "$T" && env -i PATH="$PATH" bash "$REPORT" COMPLETED HIGH >/dev/null 2>&1); R10a=$?
(cd "$T" && env -i PATH="$PATH" bash "$REPORT" --strict >/dev/null 2>&1); R10b=$?
if [[ "$R10a" -eq 2 && "$R10b" -eq 1 ]]; then ok "E10-declarado-rejeitado";
else bad "E10-declarado-rejeitado" "rc_decl=$R10a rc_strict=$R10b"; fi
rm -rf "$T"

# --- E11: claim proibida com --strict => exit 1 ---
T=$(fresh_repo); mkcert "$T"
(cd "$T" && env -i PATH="$PATH" bash "$REPORT" --strict --claim "Suíte 53/53 PASS" "proof.json" >/dev/null 2>&1); R11=$?
if [[ "$R11" -eq 1 ]]; then ok "E11-claim-proibida-strict";
else bad "E11-claim-proibida-strict" "rc=$R11"; fi
rm -rf "$T"

# --- E12: frases legítimas com --strict => VERIFICADO ---
T=$(fresh_repo); mkcert "$T"
O12="$(cd "$T" && env -i PATH="$PATH" bash "$REPORT" --strict --claim "Gate evaluates bypass de find -delete" "proof.json" --claim "Contrato de evaluate_command cobre 12/12 variantes" "proof.json" 2>&1)"; R12=$?
if [[ "$R12" -eq 0 && "$O12" == *'**VERIFICADO**'* ]]; then ok "E12-frases-legitimas";
else bad "E12-frases-legitimas" "rc=$R12 out=[$(echo "$O12" | head -c 300)]"; fi
rm -rf "$T"

# --- E13: cert de evals OBSERVED; obsoleto => STALE + DESATUALIZADO ---
T=$(fresh_repo); mkcert "$T"
O13a="$(run_rep "$T")"
T2=$(fresh_repo); H2=$(git -C "$T2" rev-parse HEAD); mkcert "$T2" PASS "$H2" true APROVA 0000000000000000000000000000000000000000
O13b="$(run_rep "$T2")"
if [[ "$O13a" == *'Smoke-evals: **PASS** (`OBSERVED`)'* && "$O13a" == *'5/5 critérios (APROVA)'* \
  && "$O13b" == *'Smoke-evals: **STALE** (`OBSERVED`)'* && "$O13b" == *'[DESATUALIZADO]'* \
  && "$O13b" == *'**NAO_VERIFICADO**'* ]]; then ok "E13-evals-observed";
else bad "E13-evals-observed" "out=[$(echo "$O13a $O13b" | head -c 300)]"; fi
rm -rf "$T" "$T2"

# --- E14: prova versionada mas modificada após o HEAD => PARTIALLY ---
T=$(fresh_repo); mkcert "$T"; printf 'v3-sujo\n' > "$T/proof.json"
O14="$(run_rep "$T" --claim "Prova suja" "proof.json")"
if [[ "$O14" == *'[PARTIALLY_SUPPORTED] Prova suja'* && "$O14" == *'modificada após o HEAD'* ]]; then ok "E14-prova-modificada";
else bad "E14-prova-modificada" "out=[$(echo "$O14" | head -c 300)]"; fi
rm -rf "$T"

# --- E15: ambiente via adapter Muse (delta 1/1 do porte) => DEVELOPMENT ---
T=$(fresh_repo); mkcert "$T"
O15="$(run_rep "$T")"
if [[ "$O15" == *'Ambiente: DEVELOPMENT'* ]]; then ok "E15-ambiente-adapter";
else bad "E15-ambiente-adapter" "out=[$(echo "$O15" | head -c 300)]"; fi
rm -rf "$T"

# --- E16: cauda do .ceh/last-ci-run.log citada (fiação D3) ---
T=$(fresh_repo); mkcert "$T"
printf 'linha1\nlinha2\nlinha3\nlinha4\nlinha5-marcador-D3\n' > "$T/.ceh/last-ci-run.log"
O16="$(run_rep "$T")"
if [[ "$O16" == *'linha5-marcador-D3'* ]]; then ok "E16-log-tail-d3";
else bad "E16-log-tail-d3" "out=[$(echo "$O16" | head -c 300)]"; fi
rm -rf "$T"

# --- E17: --json grava relatório válido ---
T=$(fresh_repo); mkcert "$T"
(cd "$T" && env -i PATH="$PATH" bash "$REPORT" --json /tmp/ev-$PPID.json >/dev/null 2>&1); R17=$?
J17="ausente"
if [[ "$R17" -eq 0 && -f /tmp/ev-$PPID.json ]]; then
  J17=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("result","?"))' /tmp/ev-$PPID.json 2>/dev/null) || J17="ilegível"
fi
rm -f /tmp/ev-$PPID.json
if [[ "$J17" == "VERIFICADO" ]]; then ok "E17-json-valido";
else bad "E17-json-valido" "rc=$R17 result=[$J17]"; fi
rm -rf "$T"

echo "---"
echo "EVIDENCE-CONTRACT: PASS=$PASS FAIL=$FAIL$([ -n "$FAILED_LIST" ] && echo " [$FAILED_LIST]" || true)"
[[ "$FAIL" -eq 0 ]]
