#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  BLINDAJE DE SECRETOS · hook PreToolUse (Edit|Write|NotebookEdit|Read)
#  Tune Kit — fork de Bryan
#
#  Diferencia con el kit original: el original protege una lista fija
#  de nombres estándar (.env, id_rsa, *.pem) y siempre en modo escritura.
#  Aquí el nivel se decide POR PROYECTO, porque no todos los proyectos
#  tienen el mismo riesgo: el vault personal no es lo mismo que una
#  demo de cliente.
#
#  Configuración: .claude/blindaje.conf en la raíz del proyecto
#
#      modo=escritura     nadie sobrescribe el archivo, pero se puede leer
#      modo=total         además, nadie lo lee (ni Claude ni un cat)
#      proteger=llaves-api.md
#      proteger=notas-privadas.md
#
#  Sin blindaje.conf → modo=escritura sobre los nombres estándar.
#  Ese es el default seguro: nunca menos protección que el kit original.
# ─────────────────────────────────────────────────────────────
set -uo pipefail

input=$(cat)
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""')
evento=$(printf '%s' "$input" | jq -r '.tool_name // ""')
[ -z "$path" ] && exit 0

# Windows: C:\Users\x\.ssh\id_rsa → basename solo parte por «/»
base=$(basename "${path//\\//}")

# ── de qué proyecto estamos hablando ──
proyecto="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$proyecto" ]; then
  d=$(dirname "${path//\\//}")
  proyecto=$(cd "$d" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || proyecto="$PWD"
fi
conf="$proyecto/.claude/blindaje.conf"

modo="escritura"
extra=""
if [ -f "$conf" ]; then
  m=$(grep -E '^[[:space:]]*modo[[:space:]]*=' "$conf" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '[:space:]')
  case "$m" in escritura|total) modo="$m" ;; esac
  extra=$(grep -E '^[[:space:]]*proteger[[:space:]]*=' "$conf" 2>/dev/null | cut -d= -f2- | tr -d ' \t\r')
fi

# ── nombres estándar, siempre protegidos ──
case "$base" in
  .env|.env.*|*.env)                         motivo="es un archivo de variables de entorno" ;;
  id_rsa|id_ed25519|*.pem|*.key|*.p12|*.pfx) motivo="es una llave privada" ;;
  credentials|credentials.*|.netrc|.pgpass)  motivo="guarda credenciales" ;;
  *service-account*.json|*serviceaccount*.json) motivo="es una cuenta de servicio" ;;
  .npmrc|.pypirc)                            motivo="guarda tokens de publicación" ;;
  *) motivo="" ;;
esac

# ── lo que este proyecto declaró suyo ──
if [ -z "$motivo" ] && [ -n "$extra" ]; then
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    case "$base" in $p) motivo="está en la lista de $conf"; break ;; esac
  done <<< "$extra"
fi

# plantillas sin secretos: siempre se pueden tocar
case "$base" in
  .env.example|.env.template|.env.sample|*.env.example) motivo="" ;;
esac

[ -z "$motivo" ] && exit 0

# ── lectura: solo se corta en modo total ──
if [ "$evento" = "Read" ]; then
  if [ "$modo" != "total" ]; then exit 0; fi
  echo "🔒 BLINDAJE TOTAL: no se lee \"$base\" porque $motivo." >&2
  echo "   Este proyecto está en modo=total ($conf)." >&2
  echo "   Si necesitas un valor de ahí, pídeselo a Bryan y que te lo pegue él." >&2
  exit 2
fi

# ── escritura: siempre se corta ──
echo "🔒 BLINDAJE: no se escribe sobre \"$base\" porque $motivo." >&2
echo "   Si necesitas una variable nueva, dime cuál y la agrego yo a mano." >&2
exit 2
