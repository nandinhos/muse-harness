#!/usr/bin/env bash
# test_scripts_smoke.sh — Smoke dos scripts portados do CEH (Fase 3).
# Garante que cada script executa com exit esperado sem efeitos no repo:
# topologias de branch rodam em sandbox /tmp; doc-audit detecta o layout
# (CEH com plano, Muse sem) e falha fechado (exit 2) sem nenhum dos dois;
# conselho roda só --list-available/--dry-run.
# Uso: bash profiles/clearer-muse/tests/test_scripts_smoke.sh (cwd: raiz do repo; offline)
set -u

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCR="$ROOT/profiles/clearer-muse/scripts"
PASS=0; FAIL=0; FAILED_LIST=""

ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
bad()  { FAIL=$((FAIL+1)); FAILED_LIST="$FAILED_LIST $1"; echo "FAIL $1 :: $2"; }

run_ok() { # <nome> <comando...>
  local name="$1"; shift
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [[ "$rc" -eq 0 ]]; then ok "$name"; else bad "$name" "rc=$rc out=[$(echo "$out" | head -c 200)]"; fi
}

# --- Scripts read-only devem sair 0 ---
run_ok "smoke-detect"    bash "$SCR/detect-project.sh" "$ROOT"
run_ok "smoke-preflight" bash "$SCR/preflight.sh"
run_ok "smoke-ceh-help"  bash "$SCR/ceh-help.sh"
run_ok "smoke-monitor"   bash "$SCR/task-monitor.sh"
run_ok "smoke-evidence"  bash "$SCR/evidence-report.sh"
run_ok "smoke-diff-audit" bash "$SCR/diff-audit.sh"
run_ok "smoke-gate-probe" python3 "$ROOT/profiles/clearer-muse/hooks/safety-gate.py" "git status"

# --- conselho: só modos seguros (sem invocar CLIs) ---
if bash "$SCR/conselho-seniores.sh" --list-available 2>&1 | grep -q "Quórum"; then
  ok "smoke-conselho-list"
else
  bad "smoke-conselho-list" "sem linha de quórum"
fi

# --- setup-branches em sandbox isolado (nunca no repo real) ---
for mode in --enterprise --classic; do
  TMP="$(mktemp -d)"
  git -C "$TMP" init -b main -q
  git -C "$TMP" config user.name T
  git -C "$TMP" config user.email t@t.l
  touch "$TMP/f"; git -C "$TMP" add f; git -C "$TMP" commit -qm i
  if bash "$SCR/setup-branches.sh" "$mode" "$TMP" >/dev/null 2>&1 \
     && git -C "$TMP" show-ref --verify --quiet refs/heads/dev; then
    if [[ "$mode" == "--enterprise" ]]; then
      git -C "$TMP" show-ref --verify --quiet refs/heads/staging \
        && ok "smoke-branches-enterprise" || bad "smoke-branches-enterprise" "sem staging"
    else
      git -C "$TMP" show-ref --verify --quiet refs/heads/staging \
        && bad "smoke-branches-classic" "staging inesperada" || ok "smoke-branches-classic"
    fi
  else
    bad "smoke-branches-${mode#--}" "setup falhou"
  fi
  rm -rf "$TMP"
done

# --- doc-audit: layout Muse verde neste repo (auditável de verdade) ---
run_ok "smoke-doc-audit-muse" bash "$SCR/doc-audit.sh"

# --- doc-audit: sandbox com link quebrado + caminho vazado = exit 1 ---
DAT="$(mktemp -d)"
printf '# X\n[quebrado](falta.md) e /home/alice/segredo\n' > "$DAT/README.md"
if python3 "$SCR/doc-audit.py" "$DAT" >/dev/null 2>&1; then
  bad "smoke-doc-audit-red" "saiu 0 com link quebrado e vazamento (falso-verde)"
else
  ok "smoke-doc-audit-red"
fi
# --- doc-audit: diretório sem layout algum = exit 2 (fail-closed) ---
DAV="$(mktemp -d)"
python3 "$SCR/doc-audit.py" "$DAV" >/dev/null 2>&1; DAVRC=$?
if [[ "$DAVRC" -eq 2 ]]; then ok "smoke-doc-audit-failclosed"; else bad "smoke-doc-audit-failclosed" "rc=$DAVRC (esperado 2)"; fi
rm -rf "$DAT" "$DAV"

# --- doc-audit resolve a raiz do repo (não profiles/) ---
if bash "$SCR/doc-audit.sh" 2>&1 | grep -q "Repositório: $ROOT$"; then
  ok "smoke-doc-audit-root"
else
  bad "smoke-doc-audit-root" "raiz incorreta"
fi

# --- conselho --dry-run redige segredos do contexto (PR-21; stub hermético) ---
TCB=$(mktemp -d); TCOUT=$(mktemp -d)
printf '#!/usr/bin/env bash\necho STUB\n' > "$TCB/muse"; chmod +x "$TCB/muse"
# Token sintético em partes p/ não tripar o scanner do evidence-report.
FAKETOK='ghp_'"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdef"
if PATH="$TCB:$PATH" bash "$SCR/conselho-seniores.sh" --dry-run --agent muse \
    --prompt "revisar token $FAKETOK em /home/alice/proj" \
    --output-dir "$TCOUT" >/dev/null 2>&1 \
  && grep -q "REDACTED_GIT_TOKEN" "$TCOUT/prompt_muse.txt" \
  && grep -q "AVISO CEH: .*trecho(s) redigido(s)" "$TCOUT/prompt_muse.txt" \
  && ! grep -q "ghp_ABC" "$TCOUT/prompt_muse.txt" \
  && ! grep -q "/home/alice" "$TCOUT/prompt_muse.txt" \
  && ! grep -q "ghp_ABC" "$TCOUT/contexto_avaliado.txt"; then
  ok "smoke-conselho-redact"
else
  bad "smoke-conselho-redact" "prompt/contexto com segredo não redigido"
fi
rm -rf "$TCB" "$TCOUT"

# --- doc-audit [4/7]: regex de home abrange /home e /Users (escopo upstream) ---
DARX='(file:///home/[^\s\)\"'"'"'>]+|/(?:home|Users)/[\w.-]+/[^\s\)\"'"'"'>]*)'
if python3 -c "
import re, sys
rx = re.compile(sys.argv[1])
must = ['x /home/alice/proj/a.md y', 'x /Users/bob/f.md y', 'x file:///home/c/d.md y']
mustnt = ['x ~/proj/a.md y', 'x docs/a.md y', 'x /var/lib/z y']
assert all(rx.search(s) for s in must), 'falha em positivo'
assert not any(rx.search(s) for s in mustnt), 'falso positivo'
" "$DARX"; then
  if grep -qF '/(?:home|Users)/' "$SCR/doc-audit.py"; then ok "smoke-docaudit-home-regex";
  else bad "smoke-docaudit-home-regex" "doc-audit.py sem classe /(home|Users)/"; fi
else
  bad "smoke-docaudit-home-regex" "amostras do regex falharam"
fi

# --- Etapa3: test-runner ignora stub "no test specified" do npm (U09) ---
TSN="$(mktemp -d)"
printf '%s\n' '{"scripts":{"test":"echo \"Error: no test specified\" && exit 1"}}' > "$TSN/package.json"
OUTSN="$(cd "$TSN" && bash "$SCR/test-runner.sh" 2>&1)"; RCSN=$?
if [[ "$RCSN" -eq 3 && "$OUTSN" == *'STATUS: NOT RUN'* ]]; then ok "smoke-runner-npm-stub";
else bad "smoke-runner-npm-stub" "rc=$RCSN out=[$(echo "$OUTSN" | head -c 200)]"; fi
rm -rf "$TSN"

# --- Etapa3: test-runner despacha p/ docker_service do config (U09, docker stub) ---
TDS="$(mktemp -d)"; BDS="$(mktemp -d)"
git -C "$TDS" init -b main -q; git -C "$TDS" config user.name T; git -C "$TDS" config user.email t@t.l
mkdir -p "$TDS/.ceh"
printf '%s\n' '{"canonical_test_command":"true","docker_service":"web"}' > "$TDS/.ceh/config.json"
printf 'services:\n  db:\n    image: x\n  web:\n    image: x\n' > "$TDS/docker-compose.yml"
git -C "$TDS" add .; git -C "$TDS" commit -qm base
cat > "$BDS/docker" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == "info" ]]; then exit 0; fi
if [[ "${1:-}" == "compose" && "${2:-}" == "ps" ]]; then printf 'db\nweb\n'; exit 0; fi
if [[ "${1:-}" == "compose" && "${2:-}" == "exec" ]]; then shift 4; exec "$@"; fi
exit 0
STUB
chmod +x "$BDS/docker"
OUTDS="$(cd "$TDS" && PATH="$BDS:$PATH" bash "$SCR/test-runner.sh" 2>&1)"; RCDS=$?
if [[ "$RCDS" -eq 0 && "$OUTDS" == *'docker compose exec -T web true'* ]]; then ok "smoke-runner-docker-service";
else bad "smoke-runner-docker-service" "rc=$RCDS out=[$(echo "$OUTDS" | head -c 300)]"; fi

# --- Etapa3: detect-project escolhe servico primario conhecido (docker stub) ---
cat > "$BDS/docker" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == "info" ]]; then exit 0; fi
if [[ "${1:-}" == "compose" && "${2:-}" == "ps" ]]; then printf 'db\nphp\n'; exit 0; fi
exit 0
STUB
chmod +x "$BDS/docker"
OUTDP="$(PATH="$BDS:$PATH" bash "$SCR/detect-project.sh" "$TDS" 2>&1)"
if [[ "$OUTDP" == *'docker compose exec -T php <cmd>'* ]]; then ok "smoke-detect-primary-svc";
else bad "smoke-detect-primary-svc" "out=[$(echo "$OUTDP" | head -c 300)]"; fi
rm -rf "$TDS" "$BDS"

# --- Etapa3: doc-audit reprova SKILL.md sem frontmatter (U05 adaptado) ---
DFR="$(mktemp -d)"
printf '# X\n' > "$DFR/README.md"
mkdir -p "$DFR/profiles/p/skills/bad"
printf '# sem frontmatter\n' > "$DFR/profiles/p/skills/bad/SKILL.md"
OUTFR="$(python3 "$SCR/doc-audit.py" "$DFR" 2>&1)"; RCFR=$?
if [[ "$RCFR" -eq 1 && "$OUTFR" == *'frontmatter'* ]]; then ok "smoke-docaudit-frontmatter-red";
else bad "smoke-docaudit-frontmatter-red" "rc=$RCFR out=[$(echo "$OUTFR" | head -c 300)]"; fi
rm -rf "$DFR"

# --- Etapa3: doc-audit aprova SKILL.md com frontmatter name+description ---
DFG="$(mktemp -d)"
printf '# X\n' > "$DFG/README.md"
mkdir -p "$DFG/profiles/p/skills/good"
printf -- '---\nname: good\ndescription: skill valida\n---\n# ok\n' > "$DFG/profiles/p/skills/good/SKILL.md"
OUTFG="$(python3 "$SCR/doc-audit.py" "$DFG" 2>&1)"; RCFG=$?
if [[ "$RCFG" -eq 0 && "$OUTFG" == *'Frontmatter'* && "$OUTFG" == *'SUCESSO: 6/6'* ]]; then ok "smoke-docaudit-frontmatter-green";
else bad "smoke-docaudit-frontmatter-green" "rc=$RCFG out=[$(echo "$OUTFG" | head -c 300)]"; fi
rm -rf "$DFG"

# --- Etapa4 F2: telemetria append mascara segredo e caminho de home ---
TEL="$(mktemp -d)"; TELOG="$TEL/sub/eventos.jsonl"
FAKEKEY='sk-'"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
if python3 "$SCR/telemetry_log.py" --file "$TELOG" --tool muse.bash --decision allow \
     --latency-ms 12 --tokens 100 --token-source estimated_chars4 \
     --note "rodou com chave $FAKEKEY em /home/alice/proj" >/dev/null 2>&1 \
   && [[ -f "$TELOG" ]] \
   && grep -q "REDACTED" "$TELOG" \
   && ! grep -q "sk-ABC" "$TELOG" \
   && ! grep -q "/home/alice" "$TELOG" \
   && python3 -c "import json,sys; e=json.loads(open(sys.argv[1]).readline()); assert e['decision']=='allow' and e['tool']=='muse.bash' and e['tokens']==100 and e['token_source']=='estimated_chars4' and e['ts'].endswith('Z')" "$TELOG" 2>/dev/null; then
  ok "smoke-telemetry-append-mask"
else
  bad "smoke-telemetry-append-mask" "append/máscara/schema inválidos"
fi

# --- Etapa4 F2: decisão inválida = exit 2 sem escrever (fail-closed) ---
LINES_BEFORE="$(wc -l < "$TELOG" 2>/dev/null || echo 0)"
python3 "$SCR/telemetry_log.py" --file "$TELOG" --tool muse.bash --decision talvez >/dev/null 2>&1; RCTEL=$?
LINES_AFTER="$(wc -l < "$TELOG" 2>/dev/null || echo 0)"
if [[ "$RCTEL" -eq 2 && "$LINES_BEFORE" == "$LINES_AFTER" ]]; then ok "smoke-telemetry-bad-decision";
else bad "smoke-telemetry-bad-decision" "rc=$RCTEL linhas $LINES_BEFORE->$LINES_AFTER"; fi

# --- Etapa4 F2: agregador offline conta decisões/tokens; ausente = exit 2 ---
python3 "$SCR/telemetry_log.py" --file "$TELOG" --tool muse.bash --decision deny --latency-ms 30 --rule R15 >/dev/null 2>&1
python3 "$SCR/telemetry_log.py" --file "$TELOG" --tool muse.bash --decision allow --latency-ms 20 --tokens 50 --token-source api >/dev/null 2>&1
printf 'linha-invalida\n' >> "$TELOG"
OUTREP="$(python3 "$SCR/telemetry_report.py" "$TELOG" 2>&1)"; RCREP=$?
python3 "$SCR/telemetry_report.py" "$TEL/nao-existe.jsonl" >/dev/null 2>&1; RCMISS=$?
if [[ "$RCREP" -eq 0 && "$RCMISS" -eq 2 && "$OUTREP" == *'eventos=3'* && "$OUTREP" == *'invalidos=1'* && "$OUTREP" == *'allow=2'* && "$OUTREP" == *'deny=1'* && "$OUTREP" == *'estimated_chars4=100'* && "$OUTREP" == *'api=50'* ]]; then
  ok "smoke-telemetry-report"
else bad "smoke-telemetry-report" "rc=$RCREP miss=$RCMISS out=[$(echo "$OUTREP" | head -c 300)]"; fi
rm -rf "$TEL"

# --- Etapa4 F2: git_inspect declarativo (exit 0 válido; repo ruim exit !=0) ---
OUTGI="$(python3 "$SCR/git_inspect.py" --repo "$ROOT" --limit 2 2>&1)"; RCGI=$?
python3 "$SCR/git_inspect.py" --repo /caminho/inexistente-xyz >/dev/null 2>&1; RCGIB=$?
if [[ "$RCGI" -eq 0 && "$RCGIB" -ne 0 ]] \
   && printf '%s' "$OUTGI" | python3 -c "import json,sys; d=json.load(sys.stdin); assert len(d['commits'])>=1 and len(d['commits'][0]['hash'])>=7 and d['error'] is None" 2>/dev/null; then
  ok "smoke-git-inspect"
else bad "smoke-git-inspect" "rc=$RCGI ruim=$RCGIB out=[$(echo "$OUTGI" | head -c 200)]"; fi

# --- Etapa4 F3: classificador shadow (HIGH->T4, LOW nunca T4, config ruim=2) ---
ORC="$SCR/route_classify.py"
outhigh="$(python3 "$ORC" --task "alterar autenticacao e sessao em producao" 2>&1)"
outlow="$(python3 "$ORC" --task "corrigir typo em um comentario" 2>&1)"
outmed="$(python3 "$ORC" --task "adicionar cache com ttl a consulta frequente" 2>&1)"
python3 "$ORC" --config /nao/existe.json --task "qualquer" >/dev/null 2>&1; RCBADCFG=$?
if printf '%s' "$outhigh" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['classe']=='HIGH' and d['tier']=='T4' and d['modo']=='shadow'" 2>/dev/null \
   && printf '%s' "$outlow" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['classe']=='LOW' and d['tier'] in ('T0','T1')" 2>/dev/null \
   && printf '%s' "$outmed" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['classe']=='MEDIUM' and d['tier']=='T3'" 2>/dev/null \
   && [[ "$RCBADCFG" -eq 2 ]]; then
  ok "smoke-route-classify"
else bad "smoke-route-classify" "high=[$outhigh] low=[$outlow] med=[$outmed] badcfg=$RCBADCFG"; fi

# --- Etapa4 F3: shadow registra na telemetria sem decidir (decision=shadow) ---
TSH="$(mktemp -d)"
if python3 "$ORC" --task "migrar tabela de pagamentos em producao" --telemetry "$TSH/ev.jsonl" >/dev/null 2>&1 \
   && python3 -c "import json,sys; e=json.loads(open(sys.argv[1]).readline()); assert e['decision']=='shadow' and e['rule']=='T4' and e['tool']=='route_classify'" "$TSH/ev.jsonl" 2>/dev/null; then
  ok "smoke-route-shadow-telemetry"
else bad "smoke-route-shadow-telemetry" "evento shadow ausente/inválido"; fi
rm -rf "$TSH"

# --- Etapa4 F6: System One offline (perguntas atomicas sobre o diff) ---
TSO="$(mktemp -d)"
cat > "$TSO/auth.diff" <<'DIFF'
diff --git a/src/Auth/LoginController.php b/src/Auth/LoginController.php
--- a/src/Auth/LoginController.php
+++ b/src/Auth/LoginController.php
@@ -1,3 +1,4 @@
 <?php
+$token = $request->session()->regenerateToken();
 return view('login');
DIFF
OUTSO="$(python3 "$SCR/system_one.py" --diff-file "$TSO/auth.diff" 2>&1)"; RCSO=$?
OUTH="$(python3 "$SCR/system_one.py" --diff-file "$TSO/auth.diff" --human 2>&1)"
if [[ "$RCSO" -eq 0 ]] \
   && printf '%s' "$OUTSO" | python3 -c "import json,sys; d=json.load(sys.stdin); q={p['id']:p for p in d['perguntas']}; assert q['toca_auth']['resposta']=='SIM' and q['toca_auth']['certeza']==1.0 and q['segredo_provavel']['resposta']=='NAO' and 'T4' in d['recomendacao']" 2>/dev/null \
   && [[ "$OUTH" == *'toca_auth: SIM'* ]]; then
  ok "smoke-system-one-auth"
else bad "smoke-system-one-auth" "rc=$RCSO out=[$(echo "$OUTSO" | head -c 300)] human=[$(echo "$OUTH" | head -c 200)]"; fi

# --- Etapa4 F6: segredo no diff = BLOQUEAR e --strict sai 1 ---
FAKESK='sk-'"ZYXWVUTSRQPONMLKJIHGFEDCBA9876543210"
printf 'diff --git a/a.py b/a.py\n--- a/a.py\n+++ b/a.py\n@@ -0,0 +1 @@\n+KEY = "%s"\n' "$FAKESK" > "$TSO/seg.diff"
OUTSEG="$(python3 "$SCR/system_one.py" --diff-file "$TSO/seg.diff" --strict 2>&1)"; RCSEG=$?
if [[ "$RCSEG" -eq 1 ]] \
   && printf '%s' "$OUTSEG" | python3 -c "import json,sys; d=json.load(sys.stdin); q={p['id']:p for p in d['perguntas']}; assert q['segredo_provavel']['resposta']=='SIM' and 'BLOQUEAR' in d['recomendacao']" 2>/dev/null; then
  ok "smoke-system-one-segredo"
else bad "smoke-system-one-segredo" "rc=$RCSEG out=[$(echo "$OUTSEG" | head -c 300)]"; fi
rm -rf "$TSO"

# --- Etapa4 F6: stop-guard (sem feature = no-op 0; ativa sem contrato = 1) ---
TSG="$(mktemp -d)"
python3 "$SCR/stop-guard.py" --repo "$TSG" >/dev/null 2>&1; RCG0=$?
mkdir -p "$TSG/.ceh"
printf '{"name":"f1","status":"active"}' > "$TSG/.ceh/feature.json"
printf 'pronto, terminei tudo' > "$TSG/resp.txt"
python3 "$SCR/stop-guard.py" --repo "$TSG" --response "$TSG/resp.txt" >/dev/null 2>&1; RCG1=$?
printf 'RESULT: VERIFICADO (OBSERVED) suite PASS=9 exit 0' > "$TSG/resp.txt"
python3 "$SCR/stop-guard.py" --repo "$TSG" --response "$TSG/resp.txt" >/dev/null 2>&1; RCG2=$?
printf 'lixo{' > "$TSG/.ceh/feature.json"
python3 "$SCR/stop-guard.py" --repo "$TSG" --response "$TSG/resp.txt" >/dev/null 2>&1; RCG3=$?
if [[ "$RCG0" -eq 0 && "$RCG1" -eq 1 && "$RCG2" -eq 0 && "$RCG3" -eq 2 ]]; then
  ok "smoke-stop-guard"
else bad "smoke-stop-guard" "rcs=$RCG0/$RCG1/$RCG2/$RCG3 (esperado 0/1/0/2)"; fi
rm -rf "$TSG"

# --- Revisao Codex: mascara cobre URL/JWT/AWS rotulado; report nao quebra ---
TCX="$(mktemp -d)"; TCLOG="$TCX/ev.jsonl"
python3 "$SCR/telemetry_log.py" --file "$TCLOG" --tool muse.bash --decision info \
  --note "url https://user:segredoURL123@example.com/x aws_secret_access_key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY jwt eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signaturepart" >/dev/null 2>&1
if [[ -f "$TCLOG" ]] && ! grep -q "segredoURL123" "$TCLOG" && ! grep -q "wJalrXUtnFEMI" "$TCLOG" && ! grep -q "eyJhbGciOiJIUzI1NiJ9" "$TCLOG"; then
  ok "smoke-telemetry-mask-url-aws-jwt"
else bad "smoke-telemetry-mask-url-aws-jwt" "valor sensível vazou no JSONL"; fi
cat > "$TCX/bad.jsonl" <<'JSONL'
{"decision":"allow","tool":"x","latency_ms":true,"tokens":true,"token_source":"api"}
{"decision":["allow"],"tool":"x"}
{"decision":"deny","tool":"x","latency_ms":NaN,"tokens":-5,"token_source":"api"}
{"decision":"deny","tool":["x"],"tokens":10,"token_source":["api"]}
JSONL
OUTBAD="$(python3 "$SCR/telemetry_report.py" "$TCX/bad.jsonl" 2>&1)"; RCBAD=$?
if [[ "$RCBAD" -eq 0 && "$OUTBAD" == *'eventos=0 invalidos=4'* ]]; then ok "smoke-telemetry-report-malformed";
else bad "smoke-telemetry-report-malformed" "rc=$RCBAD out=[$(echo "$OUTBAD" | head -c 300)]"; fi
rm -rf "$TCX"

# --- Revisao Codex: arbitragem do roteador privilegia o verbo principal ---
OUTRT1="$(python3 "$SCR/route_classify.py" --task "corrigir typo na documentacao do endpoint" 2>&1)"
OUTRT2="$(python3 "$SCR/route_classify.py" --task "explicar como funciona o cache" 2>&1)"
if printf '%s' "$OUTRT1" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['classe']=='LOW' and d['tier']=='T1'" 2>/dev/null \
   && printf '%s' "$OUTRT2" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['classe']=='LOW' and d['tier']=='T0'" 2>/dev/null; then
  ok "smoke-route-main-verb"
else bad "smoke-route-main-verb" "typo=[$OUTRT1] explicar=[$OUTRT2]"; fi

# --- Revisao Codex: System One nao quebra com migracao em path+conteudo ---
TMIG="$(mktemp -d)"
printf 'diff --git a/migrations/001.sql b/migrations/001.sql\n--- a/migrations/001.sql\n+++ b/migrations/001.sql\n@@\n+CREATE TABLE usuarios (id int);\n' > "$TMIG/mig.diff"
OUTMIG="$(python3 "$SCR/system_one.py" --diff-file "$TMIG/mig.diff" 2>&1)"; RCMIG=$?
if [[ "$RCMIG" -eq 0 ]] && printf '%s' "$OUTMIG" | python3 -c "import json,sys; d=json.load(sys.stdin); q={p['id']:p for p in d['perguntas']}; assert q['toca_migracao']['resposta']=='SIM'" 2>/dev/null; then
  ok "smoke-system-one-migration-mixed"
else bad "smoke-system-one-migration-mixed" "rc=$RCMIG out=[$(echo "$OUTMIG" | head -c 300)]"; fi
rm -rf "$TMIG"

# --- Revisao Codex: git_inspect preserva autor/assunto com pipe ---
TGIP="$(mktemp -d)"
git -C "$TGIP" init -q -b dev; git -C "$TGIP" config user.name 'A|B'; git -C "$TGIP" config user.email t@t
echo x > "$TGIP/f"; git -C "$TGIP" add .; git -C "$TGIP" commit -qm 'assunto | com pipe'
OUTGIP="$(python3 "$SCR/git_inspect.py" --repo "$TGIP" --limit 1 2>&1)"
if printf '%s' "$OUTGIP" | python3 -c "import json,sys; d=json.load(sys.stdin); c=d['commits'][0]; assert c['author']=='A|B' and c['subject']=='assunto | com pipe'" 2>/dev/null; then
  ok "smoke-git-inspect-delimiters"
else bad "smoke-git-inspect-delimiters" "out=[$OUTGIP]"; fi
rm -rf "$TGIP"

# --- Revisao Codex: sonda docker que ignora TERM e encerrada por kill-after ---
TKILL="$(mktemp -d)"; BKILL="$(mktemp -d)"
cat > "$BKILL/docker" <<'STUB'
#!/usr/bin/env bash
trap '' TERM
sleep 6
STUB
chmod +x "$BKILL/docker"
STARTK=$SECONDS
PATH="$BKILL:$PATH" bash "$SCR/detect-project.sh" "$TKILL" >/dev/null 2>&1
ELAPK=$((SECONDS-STARTK))
if [[ "$ELAPK" -le 4 ]]; then ok "smoke-docker-timeout-kill-after";
else bad "smoke-docker-timeout-kill-after" "detect levou ${ELAPK}s com sonda que ignora TERM"; fi
rm -rf "$TKILL" "$BKILL"

# --- Revisao Codex: certificado e JSON valido mesmo com aspas no comando ---
TCERT="$(mktemp -d)"
git -C "$TCERT" init -q -b dev; git -C "$TCERT" config user.name T; git -C "$TCERT" config user.email t@t
mkdir -p "$TCERT/.ceh"
printf '%s\n' '{"canonical_test_command":"printf \"ok\""}' > "$TCERT/.ceh/config.json"
git -C "$TCERT" add .; git -C "$TCERT" commit -qm cfg
OUTCERT="$(cd "$TCERT" && bash "$SCR/test-runner.sh" 2>&1)"; RCCERT=$?
if [[ "$RCCERT" -eq 0 ]] && python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert d['command']=='printf \"ok\"' and d['normalized_runner']=='printf \"ok\"' and d['canonical_verified'] is True" "$TCERT/.ceh/last-ci-run.json" 2>/dev/null; then
  ok "smoke-runner-cert-json-quotes"
else bad "smoke-runner-cert-json-quotes" "rc=$RCCERT out=[$(echo "$OUTCERT" | head -c 300)] cert=[$(cat "$TCERT/.ceh/last-ci-run.json" 2>/dev/null)]"; fi
rm -rf "$TCERT"

# --- Revisao Codex: install/uninstall respeitam consentimento, CRLF e modo ---
TINST="$(mktemp -d)"; BINST="$(mktemp -d)"; RCINST="$TINST/rc"
cat > "$BINST/muse" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-} ${2:-}" == "plugins list" ]]; then echo "clearer-muse"; fi
if [[ "${1:-} ${2:-}" == "plugins remove" ]]; then echo remove >> "$STUB_LOG"; fi
exit 0
STUB
chmod +x "$BINST/muse"
printf 'linha-original\r\n' > "$RCINST"; chmod 640 "$RCINST"
cp "$RCINST" "$RCINST.orig"
OUTINST="$(PATH="$BINST:$PATH" RC_FILES="$RCINST" bash "$ROOT/install.sh" --scope user </dev/null 2>&1)"; RCINST1=$?
cr_ok=0; cmp -s "$RCINST" "$RCINST.orig" && cr_ok=1
if [[ "$RCINST1" -eq 0 && "$cr_ok" -eq 1 && "$OUTINST" == *'nenhum rc foi alterado'* ]]; then ok "smoke-install-noninteractive-no-rc";
else bad "smoke-install-noninteractive-no-rc" "rc=$RCINST1 igual=$cr_ok out=[$(echo "$OUTINST" | tail -c 250)]"; fi
OUTINST2="$(PATH="$BINST:$PATH" RC_FILES="$RCINST" bash "$ROOT/install.sh" --scope user --yes </dev/null 2>&1)"; RCINST2=$?
if [[ "$RCINST2" -eq 0 ]] && python3 -c "import os,stat,sys; d=open(sys.argv[1],'rb').read(); assert d.startswith(b'linha-original\r\n') and b'# BEGIN CLEARER-MUSE ALIASES\r\n' in d and stat.S_IMODE(os.stat(sys.argv[1]).st_mode)==0o640" "$RCINST" 2>/dev/null; then
  ok "smoke-install-yes-crlf-mode"
else bad "smoke-install-yes-crlf-mode" "rc=$RCINST2 out=[$(echo "$OUTINST2" | tail -c 250)]"; fi
STUB_LOG="$TINST/stub.log"; : > "$STUB_LOG"
OUTUN="$(STUB_LOG="$STUB_LOG" PATH="$BINST:$PATH" RC_FILES="$RCINST" bash "$ROOT/uninstall.sh" </dev/null 2>&1)"; RCUN=$?
if [[ "$RCUN" -eq 0 && ! -s "$STUB_LOG" ]] && grep -q "BEGIN CLEARER-MUSE" "$RCINST"; then ok "smoke-uninstall-no-consent-preserva";
else bad "smoke-uninstall-no-consent-preserva" "rc=$RCUN log=[$(cat "$STUB_LOG")] out=[$(echo "$OUTUN" | tail -c 200)]"; fi
rm -rf "$TINST" "$BINST"

# --- Guarda de contexto (incidente 2026-11-18): custo real e context-guard ---
TCOST="$(mktemp -d)"
python3 - <<'PYEOF' "$TCOST/small.jsonl" "$TCOST/big.jsonl"
import json, sys
def ev(model, inp, cached, out):
    return json.dumps({"payload_type": "runtime.session", "payload": {"event": {
        "kind": "model_completed", "model": model,
        "usage": {"input_tokens": inp, "cached_tokens": cached,
                  "output_tokens": out, "reasoning_tokens": 0}}}})
open(sys.argv[1], "w").write(ev("muse-spark-1.3", 1000, 800, 50) + "\n" + ev("muse-spark-1.3", 1200, 1000, 60) + "\n")
open(sys.argv[2], "w").write(ev("muse-wonder-full-1.0", 400000, 390000, 500) + "\n")
PYEOF
OUTCOST="$(python3 "$SCR/session_cost.py" "$TCOST/small.jsonl" 2>&1)"; RCCOST=$?
OUTBIG="$(python3 "$SCR/context-guard.py" --session "$TCOST/big.jsonl" 2>&1)"; RCBIG=$?
OUTOKG="$(python3 "$SCR/context-guard.py" --session "$TCOST/small.jsonl" 2>&1)"; RCOKG=$?
python3 "$SCR/session_cost.py" "$TCOST/nao-existe.jsonl" >/dev/null 2>&1; RCMISS2=$?
python3 "$SCR/context-guard.py" --session "$TCOST/nao-existe.jsonl" >/dev/null 2>&1; RCMISSG=$?
# real_cost pequeno = (1000-800+50)+(1200-1000+60) = 510; bruto seria 2200+110
if [[ "$RCCOST" -eq 0 && "$OUTCOST" == *'real_cost=510'* && "$OUTCOST" == *'input=2200'* ]]; then ok "smoke-session-cost-real";
else bad "smoke-session-cost-real" "rc=$RCCOST out=[$(echo "$OUTCOST" | head -c 300)]"; fi
if [[ "$RCBIG" -eq 2 && "$OUTBIG" == *'BLOCK'* && "$RCOKG" -eq 0 && "$OUTOKG" == *'OK'* ]]; then ok "smoke-context-guard-block-ok";
else bad "smoke-context-guard-block-ok" "big=$RCBIG ok=$RCOKG out=[$OUTBIG|$OUTOKG]"; fi
if [[ "$RCMISS2" -eq 2 && "$RCMISSG" -eq 2 ]]; then ok "smoke-cost-guard-failclosed";
else bad "smoke-cost-guard-failclosed" "cost=$RCMISS2 guard=$RCMISSG (esperado 2/2)"; fi
rm -rf "$TCOST"

# --- compress-output: teto duro de chars + exit preservado ---
OUTCMP="$(bash "$SCR/compress-output.sh" python3 -c "print('x'*30000)" 2>&1)"; RCCMP=$?
CMPBYTES=$(printf '%s' "$OUTCMP" | wc -c)
if [[ "$RCCMP" -eq 0 && "$CMPBYTES" -lt 20000 && "$OUTCMP" == *'teto 16000 chars'* ]]; then ok "smoke-compress-max-chars";
else bad "smoke-compress-max-chars" "rc=$RCCMP bytes=$CMPBYTES"; fi
bash "$SCR/compress-output.sh" bash -c "exit 3" >/dev/null 2>&1; RCEXIT=$?
if [[ "$RCEXIT" -eq 3 ]]; then ok "smoke-compress-exit-preserved"; else bad "smoke-compress-exit-preserved" "rc=$RCEXIT (esperado 3)"; fi

echo "---"
echo "SCRIPTS-SMOKE: PASS=$PASS FAIL=$FAIL$([ -n "$FAILED_LIST" ] && echo " [$FAILED_LIST]" || true)"
[[ "$FAIL" -eq 0 ]]
