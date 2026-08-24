#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  FRENO DE MANO · hook PreToolUse (matcher: Bash)
#  Tune Kit — Imperio Agéntico
#
#  Una instrucción en tu CLAUDE.md es una sugerencia.
#  Esto es una pared: exit 2 cancela la llamada antes de ejecutarla
#  y le manda a Claude el motivo por stderr para que corrija solo.
# ─────────────────────────────────────────────────────────────
set -uo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
[ -z "$cmd" ] && exit 0

# Normalizamos espacios para que "rm   -rf" no se escape del filtro.
norm=$(printf '%s' "$cmd" | tr '\n' ' ' | tr -s ' ')

bloquea() {
  echo "🛑 FRENO DE MANO: $1" >&2
  echo "   Comando: $cmd" >&2
  echo "   Si de verdad lo necesitas, córrelo tú en la terminal." >&2
  exit 2
}

# 1 · Borrado recursivo sobre raíz, home o comodines.
#     Ojo con el alcance: "rm -rf build/" es trabajo normal y NO se bloquea.
#     Solo mueren la raíz, los directorios de sistema, el home y los comodines.
rmrf='rm[[:space:]]+-[rf]{2}[[:space:]]+'
if printf '%s' "$norm" | grep -qE "${rmrf}/([[:space:]]|$)"; then
  bloquea "borrado recursivo de la raíz del disco."
fi
if printf '%s' "$norm" | grep -qE "${rmrf}/(usr|etc|var|bin|sbin|opt|lib|boot|System|Library|Applications|Users|home)(/|[[:space:]]|$)"; then
  bloquea "borrado recursivo de un directorio de sistema."
fi
if printf '%s' "$norm" | grep -qE "${rmrf}(~|\\\$HOME)(/[[:space:]]*)?([[:space:]]|$)"; then
  bloquea "borrado recursivo del home completo."
fi
if printf '%s' "$norm" | grep -qE "${rmrf}(\\*|\\.|\\./)([[:space:]]|$)"; then
  bloquea "borrado recursivo con comodín o sobre el directorio actual."
fi

# 2 · Reescritura de historia remota
case "$norm" in
  *"push --force"*|*"push -f "*)
    case "$norm" in
      *--force-with-lease*) : ;;  # esta sí pasa: es la versión segura
      *) bloquea "push forzado. Usa --force-with-lease." ;;
    esac ;;
  *"git reset --hard"*"origin/main"*|*"git reset --hard"*"origin/master"*)
    bloquea "reset --hard contra la rama remota principal." ;;
esac

# 3 · Saltarse las verificaciones del repo
case "$norm" in
  *--no-verify*) bloquea "--no-verify se salta los hooks de git. Arregla lo que falla." ;;
esac

# 4 · Destrucción de datos
if printf '%s' "$norm" | grep -qiE '\b(drop[[:space:]]+(table|database|schema)|truncate[[:space:]]+table)\b'; then
  bloquea "sentencia SQL destructiva."
fi

# 5 · Tubería de internet directo a la shell
if printf '%s' "$norm" | grep -qE '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba)?sh'; then
  bloquea "descarga ejecutada a ciegas (curl | sh). Descarga, lee, y luego ejecuta."
fi

# 6 · Permisos abiertos de par en par
case "$norm" in
  *"chmod -R 777"*|*"chmod 777"*) bloquea "chmod 777 deja el archivo abierto a todo el sistema." ;;
esac

# 7 · Aplastar un archivo de secretos con un redirect
if printf '%s' "$norm" | grep -qE '>[[:space:]]*\.?[^[:space:]]*\.env(\.[a-z]+)?([[:space:]]|$)'; then
  bloquea "eso sobrescribe un archivo .env."
fi

exit 0
