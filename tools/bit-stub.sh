#!/usr/bin/env bash
# bit-stub.sh — reemplazo local del binario `bit` (BIT Developer Framework)
# para correr /opsx:apply y /opsx:archive dentro de un sandbox sin acceso
# al binario real (sin red/credenciales hacia el GitHub de la empresa).
#
# ALCANCE DELIBERADO (ver caso-de-uso-apply-archive-sandbox.md):
#   - Cubre: exec start/end, store list, status, instructions apply,
#     usage ingest (hook). Son las llamadas que el diagnóstico de Claude
#     Code calificó como confianza alta o media (derivables del layout de
#     carpetas y de tasks.md).
#   - NO cubre `bit instructions <artifact-id>` de /opsx:propose (las
#     plantillas reales de proposal/design/tasks), ni `bit new change`,
#     `bit validate`, `bit doctor`. Esas quedan fuera de alcance a
#     propósito porque /opsx:propose se ejecuta con el bit real, fuera del
#     sandbox, y el cambio ya resuelto se commitea tal cual.
#
# Instalación: copiar este archivo como `bit` en una carpeta del PATH
# dentro del sandbox (ej. /usr/local/bin/bit) y darle permiso de
# ejecución: chmod +x /usr/local/bin/bit
#
# Toda salida marcada con "_stub_warning" es un dato SINTÉTICO generado
# por este script, no una medición real del bit original. Repórtalo así
# en los resultados de la exploración.

set -euo pipefail

OPENSPEC_ROOT="${OPENSPEC_ROOT:-openspec}"
CHANGES_DIR="$OPENSPEC_ROOT/changes"
ACTIVITY_LOG="docs/metricas/guardrail_activity_log.csv"

# ---------- utilidades ----------

err() { echo "bit (stub): $*" >&2; }

find_change_dir() {
  local name="$1"
  local dir="$CHANGES_DIR/$name"
  if [[ -d "$dir" ]]; then
    echo "$dir"
    return 0
  fi
  return 1
}

# Cuenta checkboxes en tasks.md: imprime "total completados"
count_tasks() {
  local tasks_file="$1"
  local total=0 done_count=0
  if [[ -f "$tasks_file" ]]; then
    total=$(grep -cE '^[[:space:]]*-[[:space:]]*\[[ xX]\]' "$tasks_file" 2>/dev/null || true)
    done_count=$(grep -cE '^[[:space:]]*-[[:space:]]*\[[xX]\]' "$tasks_file" 2>/dev/null || true)
    [[ -z "$total" ]] && total=0
    [[ -z "$done_count" ]] && done_count=0
  fi
  echo "$total $done_count"
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

# ---------- subcomandos ----------

cmd_version() {
  echo "bit (stub) 0.1.0 — reemplazo local de pruebas, no es el binario real de BDF"
}

cmd_exec_start() {
  # bit exec start --command <propose|apply|archive> --tool <tool> [--model <m>]
  # Los prompts dicen explícitamente que esta llamada es "never blocking" y
  # que su stdout no se interpreta -> no-op, siempre éxito.
  exit 0
}

cmd_exec_end() {
  # bit exec end --command <cmd> --change <name> --result <OK|FAIL|BLOCKED>
  #              [--log-activity --role <r> --activity <txt>
  #               --guardrail <G-XXX-NN> --estimated-min <n>]
  local change="" result="" log_activity=0
  local role="" activity="" guardrail="" estimated_min="0"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --change) change="${2:-}"; shift 2 ;;
      --result) result="${2:-}"; shift 2 ;;
      --log-activity) log_activity=1; shift ;;
      --role) role="${2:-}"; shift 2 ;;
      --activity) activity="${2:-}"; shift 2 ;;
      --guardrail) guardrail="${2:-}"; shift 2 ;;
      --estimated-min) estimated_min="${2:-0}"; shift 2 ;;
      --command) shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ "$log_activity" -eq 1 ]]; then
    mkdir -p "$(dirname "$ACTIVITY_LOG")"
    if [[ ! -f "$ACTIVITY_LOG" ]]; then
      echo "fecha,proyecto,cambio,guardrail,herramienta,tiempo_estimado_min,tiempo_real_min,ahorro_min,resultado,observaciones" > "$ACTIVITY_LOG"
    fi
    # No sabemos cómo el bit real mide el tiempo_real_min (no vimos esa
    # lógica en el repo). Usamos el estimado como real y ahorro=0: déjalo
    # marcado como dato sintético, no como medición real de la prueba.
    echo "$(date +%F),IA-Champions-sandbox,${change},${guardrail},bit-stub,${estimated_min},${estimated_min},0,${result},dato_sintetico_stub_no_medido(rol=${role};actividad=${activity})" >> "$ACTIVITY_LOG"
  fi
  exit 0
}

cmd_store_list() {
  # bit store list --json
  # Sin "stores" (workspaces OpenSpec) registrados en esta máquina: lista vacía.
  echo "[]"
}

cmd_status() {
  # bit status --change <name> [--json]
  local change="" as_json=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --change) change="${2:-}"; shift 2 ;;
      --json) as_json=1; shift ;;
      *) shift ;;
    esac
  done

  local dir
  if ! dir=$(find_change_dir "$change"); then
    if [[ "$as_json" -eq 1 ]]; then
      echo "{\"error\":\"change_not_found\",\"change\":\"$(json_escape "$change")\"}"
    else
      err "No se encontró el cambio '$change' en $CHANGES_DIR"
    fi
    exit 1
  fi

  read -r total done_count <<< "$(count_tasks "$dir/tasks.md")"
  local state="in_progress"
  if [[ "$total" -eq 0 ]]; then
    state="ready"
  elif [[ "$done_count" -eq "$total" ]]; then
    state="all_done"
  fi

  if [[ "$as_json" -eq 0 ]]; then
    echo "Cambio: $change"
    echo "Carpeta: $dir"
    echo "Tareas: $done_count/$total completadas"
    echo "Estado inferido: $state"
    return 0
  fi

  local has_proposal="missing" has_design="missing" has_tasks="missing"
  [[ -f "$dir/proposal.md" ]] && has_proposal="done"
  [[ -f "$dir/design.md" ]] && has_design="done"
  [[ -f "$dir/tasks.md" ]] && has_tasks="done"

  cat <<JSON
{
  "schemaName": "spec-driven",
  "planningHome": "$(json_escape "$OPENSPEC_ROOT")",
  "changeRoot": "$(json_escape "$dir")",
  "actionContext": "local",
  "state": "$state",
  "progress": {"total": $total, "complete": $done_count},
  "artifacts": [
    {"id": "proposal", "status": "$has_proposal"},
    {"id": "design", "status": "$has_design"},
    {"id": "tasks", "status": "$has_tasks"}
  ],
  "_stub_warning": "JSON inferido por bit-stub a partir del layout de carpetas y de tasks.md; no proviene del binario bit real. Campos que el bit real pudiera traer y que aqui no aparecen, simplemente no estan disponibles."
}
JSON
}

cmd_instructions_apply() {
  # bit instructions apply --change <name> --json
  local change=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --change) change="${2:-}"; shift 2 ;;
      --json) shift ;;
      *) shift ;;
    esac
  done

  local dir
  if ! dir=$(find_change_dir "$change"); then
    echo "{\"error\":\"change_not_found\"}"
    exit 1
  fi

  local next_task=""
  if [[ -f "$dir/tasks.md" ]]; then
    next_task=$(grep -nE '^[[:space:]]*-[[:space:]]*\[ \]' "$dir/tasks.md" 2>/dev/null | head -n1 | cut -d: -f2- | sed 's/^[[:space:]]*-[[:space:]]*\[ \][[:space:]]*//' || true)
  fi

  read -r total done_count <<< "$(count_tasks "$dir/tasks.md")"
  local state="in_progress"
  [[ "$total" -eq 0 ]] && state="ready"
  [[ "$total" -gt 0 && "$done_count" -eq "$total" ]] && state="all_done"

  cat <<JSON
{
  "state": "$state",
  "nextTask": "$(json_escape "$next_task")",
  "contextFiles": {
    "proposal": "$(json_escape "$dir/proposal.md")",
    "design": "$(json_escape "$dir/design.md")",
    "tasks": "$(json_escape "$dir/tasks.md")"
  },
  "progress": {"total": $total, "complete": $done_count},
  "instruction": "Implementa la siguiente tarea pendiente de tasks.md contra el stack ya inicializado (Angular + .NET + SQL Server 2022). Marca la tarea como [x] al terminarla y vuelve a llamar a bit status antes de continuar con la siguiente.",
  "_stub_warning": "Instruccion generica de bit-stub; el bit real probablemente trae una instruccion mas especifica por tarea (ligada a template/rules) que este stub no puede replicar sin el binario real."
}
JSON
}

cmd_usage_ingest() {
  # Hook "Stop" en .claude/settings.json: bit usage ingest --from-hook (async).
  # Telemetria del binario real; no-op silencioso en el stub.
  exit 0
}

# ---------- despacho ----------

main() {
  local sub="${1:-}"
  shift || true
  case "$sub" in
    --version|-v|version)
      cmd_version
      ;;
    exec)
      local action="${1:-}"; shift || true
      case "$action" in
        start) cmd_exec_start "$@" ;;
        end)   cmd_exec_end "$@" ;;
        *) err "subcomando 'exec $action' no soportado por el stub"; exit 1 ;;
      esac
      ;;
    store)
      local action="${1:-}"; shift || true
      case "$action" in
        list) cmd_store_list "$@" ;;
        *) err "subcomando 'store $action' no soportado por el stub"; exit 1 ;;
      esac
      ;;
    status)
      cmd_status "$@"
      ;;
    instructions)
      local target="${1:-}"; shift || true
      case "$target" in
        apply) cmd_instructions_apply "$@" ;;
        *)
          err "'bit instructions $target' no esta implementado (fuera de alcance deliberado: ver caso-de-uso-apply-archive-sandbox.md)."
          exit 1
          ;;
      esac
      ;;
    usage)
      local action="${1:-}"; shift || true
      case "$action" in
        ingest) cmd_usage_ingest "$@" ;;
        *) err "subcomando 'usage $action' no soportado por el stub"; exit 1 ;;
      esac
      ;;
    "")
      err "uso: bit <exec|store|status|instructions|usage|--version> ..."
      exit 1
      ;;
    *)
      err "subcomando '$sub' no reconocido por este stub (revisa caso-de-uso-apply-archive-sandbox.md para el alcance)."
      exit 1
      ;;
  esac
}

main "$@"
