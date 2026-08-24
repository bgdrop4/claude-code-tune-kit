#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  BLINDAJE DE SECRETOS · hook PreToolUse (matcher: Edit|Write|NotebookEdit)
#  Tune Kit — Imperio Agéntico
#
#  Nada escribe encima de un archivo de credenciales. Ni tú distraído,
#  ni el agente "arreglando" una variable que faltaba.
#
#  Ojo: esto protege la ESCRITURA. Para que tampoco los LEA, usa
#  permissions.deny en tu settings.json — vienen los dos en el kit.
# ─────────────────────────────────────────────────────────────
set -uo pipefail

input=$(cat)
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""')
[ -z "$path" ] && exit 0

base=$(basename "$path")

case "$base" in
  .env|.env.*|*.env)                       motivo="es un archivo de variables de entorno" ;;
  id_rsa|id_ed25519|*.pem|*.key|*.p12|*.pfx) motivo="es una llave privada" ;;
  credentials|credentials.*|.netrc|.pgpass) motivo="guarda credenciales" ;;
  *service-account*.json|*serviceaccount*.json) motivo="es una cuenta de servicio" ;;
  .npmrc|.pypirc)                          motivo="guarda tokens de publicación" ;;
  *) motivo="" ;;
esac

# .env.example y .env.template SÍ se pueden tocar: son plantillas sin secretos.
case "$base" in
  .env.example|.env.template|.env.sample|*.env.example) motivo="" ;;
esac

if [ -n "$motivo" ]; then
  echo "🔒 BLINDAJE: no se escribe sobre \"$base\" porque $motivo." >&2
  echo "   Si necesitas una variable nueva, dime cuál y la agrego yo a mano." >&2
  exit 2
fi

exit 0
