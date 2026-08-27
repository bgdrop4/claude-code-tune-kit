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
#  Voz:     export CC_VOZ=Paulina         (macOS: `say -v ?` lista las voces.
#                                          Windows: nombre SAPI, ej. Sabina)
#  Frase:   export CC_FRASE=listo
# ─────────────────────────────────────────────────────────────
set -uo pipefail

UMBRAL="${CC_AVISO_SEGUNDOS:-60}"
VOZ="${CC_VOZ:-Paulina}"
FRASE="${CC_FRASE:-listo}"

input=$(cat)
evento=$(printf '%s' "$input" | jq -r '.hook_event_name // ""')
sesion=$(printf '%s' "$input" | jq -r '.session_id // "sin-sesion"')

# En Git Bash, TMPDIR a veces viene como ruta de Windows (C:\Users\…\Temp).
# Normalizamos el backslash o el redirect de abajo escribe en un archivo
# con nombre literal «C:\Users…» dentro del directorio actual.
TMPBASE="${TMPDIR:-/tmp}"
marca="${TMPBASE//\\//}/cc-aviso-${sesion}"

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
  # macOS
  say -v "$VOZ" "$FRASE" >/dev/null 2>&1 &
elif command -v notify-send >/dev/null 2>&1; then
  # Linux de escritorio
  notify-send "Claude Code" "$FRASE" >/dev/null 2>&1 &
elif command -v powershell.exe >/dev/null 2>&1; then
  # Windows. SAPI viene de fábrica: no hay que instalar ningún módulo.
  # Se intenta la voz de CC_VOZ por coincidencia parcial (las voces en
  # español se llaman Sabina, Helena, Laura…); si no está, habla la
  # predeterminada en vez de fallar callado.
  powershell.exe -NoProfile -NonInteractive -Command "
    Add-Type -AssemblyName System.Speech;
    \$s = New-Object System.Speech.Synthesis.SpeechSynthesizer;
    \$v = \$s.GetInstalledVoices() | Where-Object { \$_.VoiceInfo.Name -like '*${VOZ}*' } | Select-Object -First 1;
    if (\$v) { \$s.SelectVoice(\$v.VoiceInfo.Name) };
    \$s.Speak('${FRASE}')" >/dev/null 2>&1 &
fi

# campana del terminal — el respaldo que funciona en los tres sistemas
printf '\a' >&2
exit 0
