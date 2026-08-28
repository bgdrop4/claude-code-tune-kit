#!/usr/bin/env bash
# Instalador del Tune Kit. Respalda antes de tocar nada.
set -euo pipefail

CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
O=$'\033[38;5;173m'; V=$'\033[38;5;71m'; A=$'\033[38;5;179m'; D=$'\033[2m'; B=$'\033[1m'; R=$'\033[0m'
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --sin-voz: instala todo menos el avisito hablado. El hook se copia igual
# (por si lo quieres luego), pero no se cablea en settings.json.
SIN_VOZ=0
for arg in "$@"; do case "$arg" in --sin-voz) SIN_VOZ=1 ;; esac; done

# Git Bash / MSYS / Cygwin se reportan como MINGW*, MSYS* o CYGWIN*
case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*|CYGWIN*) ES_WINDOWS=1 ;; *) ES_WINDOWS=0 ;; esac

printf "\n${O}  Tune Kit${R} ${D}→ %s${R}\n\n" "$CFG"

mkdir -p "$CFG/hooks" "$CFG/output-styles"

# 1 · respaldo de lo que ya tenías
if [ -f "$CFG/settings.json" ]; then
  stamp=$(date +%Y%m%d-%H%M%S)
  cp "$CFG/settings.json" "$CFG/settings.json.antes-del-tune-kit.$stamp"
  printf "  ${V}✓${R} respaldo: settings.json.antes-del-tune-kit.%s\n" "$stamp"
fi

# 2 · piezas que se copian sin riesgo
cp "$here"/hooks/*.sh          "$CFG/hooks/"
cp "$here"/statusline.sh       "$CFG/"
cp "$here"/output-styles/*.md  "$CFG/output-styles/"
chmod +x "$CFG"/hooks/*.sh "$CFG/statusline.sh" 2>/dev/null || true
printf "  ${V}✓${R} hooks, línea de estado y estilo copiados\n"

# En Windows, si el repo se clonó con core.autocrlf=true los .sh traen CRLF
# y bash sale a buscar un binario llamado «bash\r». El .gitattributes lo
# previene en clones nuevos; esto rescata a quien ya lo tenía clonado.
if [ "$ES_WINDOWS" -eq 1 ]; then
  arreglados=0
  for f in "$CFG"/hooks/*.sh "$CFG/statusline.sh"; do
    if [ -f "$f" ] && grep -q $'\r' "$f" 2>/dev/null; then
      tr -d '\r' < "$f" > "$f.tmp" && mv "$f.tmp" "$f"
      arreglados=$((arreglados+1))
    fi
  done
  [ "$arreglados" -gt 0 ] && printf "  ${V}✓${R} CRLF corregido en %s archivo(s) ${D}(si no, los hooks no arrancan)${R}\n" "$arreglados"
fi

# 3 · settings: fusionar, NUNCA sobrescribir
FUENTE="$here/settings.json"
if [ "$SIN_VOZ" -eq 1 ]; then
  if command -v jq >/dev/null 2>&1; then
    FUENTE=$(mktemp)
    jq 'del(.hooks.UserPromptSubmit) | del(.hooks.Stop)' "$here/settings.json" > "$FUENTE"
    printf "  ${V}✓${R} sin voz: el avisito no se cablea ${D}(el .sh queda copiado por si lo quieres)${R}\n"
  else
    printf "  ${A}▲${R} --sin-voz necesita jq; se instala con el avisito activo\n"
  fi
fi

if [ ! -f "$CFG/settings.json" ]; then
  cp "$FUENTE" "$CFG/settings.json"
  printf "  ${V}✓${R} settings.json instalado\n"
elif command -v jq >/dev/null 2>&1; then
  tmp=$(mktemp)
  # Lo tuyo gana en cualquier clave que ya tuvieras definida.
  jq -s '.[0] * .[1]' "$FUENTE" "$CFG/settings.json" > "$tmp"
  mv "$tmp" "$CFG/settings.json"
  printf "  ${V}✓${R} settings fusionados ${D}(tus valores previos ganan)${R}\n"
else
  # Sin jq NO se puede fusionar. Antes esto caía en un `cp` que borraba
  # la configuración del usuario — justo lo contrario de lo que promete
  # el README. En Windows es el caso común: jq no viene de fábrica.
  printf "  ${A}▲${R} tienes settings.json pero falta ${B}jq${R}: no lo toco para no borrarlo\n"
  printf "     ${D}Instala jq y vuelve a correr esto, o copia a mano los bloques de:${R}\n"
  printf "     ${D}%s/settings.json${R}\n" "$here"
fi

printf "\n${D}  Cierra tus sesiones y abre una nueva: la config se lee al arrancar.${R}\n"
printf "${D}  Luego corre:${R} bash %s/cc-doctor.sh\n\n" "$here"
