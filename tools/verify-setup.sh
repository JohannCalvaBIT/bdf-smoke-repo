#!/usr/bin/env bash
# Verifica la configuracion de AgentSky para el caso de uso apply/archive.
# Simula apply y archive sobre el cambio demo-hola SIN usar el modelo.
# Ejecutar desde la raiz del repo: bash tools/verify-setup.sh

CHANGE="demo-hola"
RESULTS=()
ok()   { echo "[PASS] $1"; RESULTS+=("PASS $1"); }
fail() { echo "[FAIL] $1"; RESULTS+=("FAIL $1"); }

echo "=== Entorno ==="
echo "usuario: $(whoami)  cwd: $(pwd)"
echo "PATH: $PATH"
echo "/usr/local/bin escribible: $([ -w /usr/local/bin ] && echo si || echo no)"
echo

echo "=== 1. Stub instalado en el PATH ==="
if command -v bit >/dev/null 2>&1; then
  ok "bit en PATH: $(command -v bit)"
  bit --version
else
  fail "bit NO esta en el PATH (el hook session_start no lo instalo donde el agente lo ve)"
  echo "Instalacion manual para continuar la prueba:"
  mkdir -p "$HOME/.local/bin" && install -m 755 tools/bit-stub.sh "$HOME/.local/bin/bit" && export PATH="$HOME/.local/bin:$PATH"
fi
echo

echo "=== 2. Stub lee el cambio ==="
if bit status --change "$CHANGE" --json | grep -q '"state"'; then ok "bit status --json"; else fail "bit status --json"; fi
if bit instructions apply --change "$CHANGE" --json | grep -q '"nextTask"'; then ok "bit instructions apply --json"; else fail "bit instructions apply --json"; fi
echo

echo "=== 3. Simulacion de apply (escritura en el workspace) ==="
mkdir -p src && printf 'hola\nmundo\n' > src/hola.txt && ok "escribio src/hola.txt" || fail "no pudo escribir src/hola.txt"
sed -i 's/- \[ \]/- [x]/' "openspec/changes/$CHANGE/tasks.md" && ok "marco tareas como hechas"
bit exec end --command apply --change "$CHANGE" --result OK --log-activity --role "Developer Backend" --activity "smoke test" --guardrail G-GLOBAL-07 --estimated-min 1
[ -f docs/metricas/guardrail_activity_log.csv ] && ok "CSV de guardrails creado" || fail "CSV de guardrails no creado"
echo

echo "=== 4. Simulacion de archive ==="
DEST="openspec/changes/archive/$(date +%F)-$CHANGE"
if [ -d "openspec/changes/$CHANGE" ]; then
  mkdir -p openspec/changes/archive && mv "openspec/changes/$CHANGE" "$DEST" && ok "archivo movido a $DEST" || fail "mv a archive fallo"
else
  echo "(el cambio ya estaba archivado; se omite)"
fi
echo

echo "=== 5. Estado de git (lo que deberia verse en workspace/changes) ==="
git status --short 2>&1 | head -20
echo

echo "=== 6. Prueba de push (informativa) ==="
git remote -v 2>&1 | head -2
GIT_TERMINAL_PROMPT=0 timeout 25 git push origin "HEAD:refs/heads/agentsky-smoke-$(date +%s)" 2>&1 | tail -3
echo "(si falla por credenciales, es lo esperado con el token fuera del sandbox)"
echo

echo "=== RESUMEN ==="
printf '%s\n' "${RESULTS[@]}"
