#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  EL AVISITO · hook Stop
#  Tune Kit — Imperio Agéntico
#
#  Te avisa cuando la sesión termina, para que dejes de mirar
#  la terminal esperando. Voz en Mac, campana en cualquier otro lado.
#
#  Súbele o bájale: cambia VOZ, o comenta la línea del say.
# ─────────────────────────────────────────────────────────────
set -uo pipefail

VOZ="${CC_VOZ:-Paulina}"          # voz en español de macOS
FRASE="${CC_FRASE:-listo}"

if command -v say >/dev/null 2>&1; then
  say -v "$VOZ" "$FRASE" >/dev/null 2>&1 &
fi

# Campana del terminal — funciona en Linux, WSL y en Mac sin `say`.
printf '\a' >&2

exit 0
