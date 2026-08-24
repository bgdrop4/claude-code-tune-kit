#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  EL AVISITO · hooks UserPromptSubmit + Stop
#  Tune Kit — Imperio Agéntico
#
#  Te avisa cuando la sesión termina, para que dejes de mirar la
#  terminal esperando.
#
#  ⚠️ El detalle que hace la diferencia: `Stop` se dispara al final de
#  CADA respuesta. Un aviso en cada turno es insufrible y lo desinstalas
#  el primer día. Así que el mismo script se engancha a dos eventos:
#  marca la hora cuando mandas el prompt, y al terminar solo habla si el
#  turno tardó lo suficiente como para que te hubieras ido a otra cosa.
#
#  Umbral:  export CC_AVISO_SEGUNDOS=60   (default 60)
#  Voz:     export CC_VOZ=Paulina         (voces en español de macOS)
#  Frase:   export CC_FRASE=listo
# ─────────────────────────────────────────────────────────────
set -uo pipefail

UMBRAL="${CC_AVISO_SEGUNDOS:-60}"
VOZ="${CC_VOZ:-Paulina}"
FRASE="${CC_FRASE:-listo}"

input=$(cat)
evento=$(printf '%s' "$input" | jq -r '.hook_event_name // ""')
sesion=$(printf '%s' "$input" | jq -r '.session_id // "sin-sesion"')
marca="${TMPDIR:-/tmp}/cc-aviso-${sesion}"

case "$evento" in
  UserPromptSubmit)
    date +%s > "$marca" 2>/dev/null
    exit 0
    ;;
esac

# ── a partir de aquí, es el Stop ──
ahora=$(date +%s)
inicio=$(cat "$marca" 2>/dev/null || echo "$ahora")
rm -f "$marca" 2>/dev/null

# si el marcador no es un número (archivo corrupto), no avisamos
case "$inicio" in ''|*[!0-9]*) exit 0 ;; esac

duracion=$(( ahora - inicio ))
[ "$duracion" -lt "$UMBRAL" ] && exit 0

if command -v say >/dev/null 2>&1; then
  say -v "$VOZ" "$FRASE" >/dev/null 2>&1 &
elif command -v notify-send >/dev/null 2>&1; then
  notify-send "Claude Code" "$FRASE" >/dev/null 2>&1 &
fi

# campana del terminal — funciona en Linux, WSL y en Mac sin `say`
printf '\a' >&2
exit 0
