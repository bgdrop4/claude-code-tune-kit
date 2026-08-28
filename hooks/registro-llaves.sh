#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  REGISTRO DE LLAVES · hook PostToolUse (matcher: Edit|Write)
#  Tune Kit — fork de Bryan
#
#  El problema que resuelve: el blindaje protege lo que ya sabe que es
#  un secreto. Pero cuando aparece un archivo NUEVO con credenciales
#  —y en este vault pasa cada dos por tres: llaves-api.md, un token de
#  Retell, la key de z.ai— nadie lo registra, y queda desprotegido
#  justo el día que más importa.
#
#  Esto lo detecta en el momento en que se crea y le manda el aviso a
#  Claude por stderr, con la instrucción de PREGUNTARLE A BRYAN cómo
#  quiere blindarlo. Un hook no puede abrir un diálogo; el agente sí.
#
#  Sale con exit 2 a propósito: en PostToolUse eso NO cancela nada
#  (el archivo ya se escribió), solo garantiza que el mensaje llegue.
# ─────────────────────────────────────────────────────────────
set -uo pipefail

input=$(cat)
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')
[ -z "$path" ] && exit 0
path="${path//\\//}"
[ -f "$path" ] || exit 0

base=$(basename "$path")

# Lo que el blindaje ya cubre de fábrica no necesita registro.
case "$base" in
  .env|.env.*|*.env|id_rsa|id_ed25519|*.pem|*.key|*.p12|*.pfx|\
  credentials|credentials.*|.netrc|.pgpass|.npmrc|.pypirc) exit 0 ;;
  .env.example|.env.template|.env.sample) exit 0 ;;
esac

# Binarios y archivos enormes fuera: ni se leen.
case "$base" in *.png|*.jpg|*.jpeg|*.gif|*.pdf|*.zip|*.mp4|*.mov|*.woff*) exit 0 ;; esac
tam=$(wc -c < "$path" 2>/dev/null || echo 0)
[ "$tam" -gt 200000 ] && exit 0

proyecto="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$proyecto" ]; then
  proyecto=$(cd "$(dirname "$path")" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || proyecto="$PWD"
fi
conf="$proyecto/.claude/blindaje.conf"

# ¿ya está registrado? entonces el blindaje lo cubre y no hay nada que decir
if [ -f "$conf" ]; then
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    case "$base" in $p) exit 0 ;; esac
  done <<< "$(grep -E '^[[:space:]]*proteger[[:space:]]*=' "$conf" 2>/dev/null | cut -d= -f2- | tr -d ' \t\r')"
fi

# ── ¿esto huele a credencial? ──
# Por nombre, o por contenido. Los patrones de contenido son los prefijos
# reales de los proveedores que usa Bryan (OpenAI, Anthropic, GitHub,
# Retell, z.ai) más las formas genéricas de asignar un secreto.
pista=""
case "$base" in
  *llave*|*llaves*|*clave*|*claves*|*secret*|*secreto*|*token*|*credencial*|*apikey*|*api-key*)
    pista="el nombre del archivo" ;;
esac

if [ -z "$pista" ]; then
  if grep -qE '(sk-[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|key-[A-Za-z0-9]{20,}|AIza[A-Za-z0-9_-]{20,})' "$path" 2>/dev/null; then
    pista="una clave con formato de proveedor conocido"
  elif grep -qiE '^[[:space:]]*[A-Z0-9_]*(API_?KEY|SECRET|TOKEN|PASSWORD|PASSWD|BEARER)[A-Z0-9_]*[[:space:]]*[:=][[:space:]]*["'\''`]?[A-Za-z0-9/+_-]{16,}' "$path" 2>/dev/null; then
    pista="una variable de tipo API_KEY / SECRET / TOKEN con un valor real"
  fi
fi

[ -z "$pista" ] && exit 0

rel="${path#$proyecto/}"

cat >&2 <<AVISO
🔑 LLAVE NUEVA SIN BLINDAR: $rel
   Detectada por: $pista.
   Este archivo NO está en $conf, así que ahora mismo cualquier agente
   puede sobrescribirlo o leerlo.

   INSTRUCCIÓN PARA CLAUDE — no lo decidas tú, PREGÚNTALE A BRYAN:
     «$rel parece contener credenciales. ¿Cómo lo blindo?»
       1) escritura — nadie lo sobrescribe, yo sí puedo leerlo
       2) total     — nadie lo sobrescribe NI lo lee, ni yo
       3) nada      — es un falso positivo, déjalo

   Con su respuesta, añade a $conf:
       proteger=$(basename "$rel")
   y si eligió total, ajusta también la línea  modo=total
   Comprueba además que el archivo esté en el .gitignore.
AVISO
exit 2
