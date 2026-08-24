#!/usr/bin/env bash
# Instalador del Tune Kit. Respalda antes de tocar nada.
set -euo pipefail

CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
O=$'\033[38;5;173m'; V=$'\033[38;5;71m'; D=$'\033[2m'; R=$'\033[0m'
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
chmod +x "$CFG"/hooks/*.sh "$CFG/statusline.sh"
printf "  ${V}✓${R} hooks, línea de estado y estilo copiados\n"

# 3 · settings: fusionar, NUNCA sobrescribir
if [ -f "$CFG/settings.json" ] && command -v jq >/dev/null 2>&1; then
  tmp=$(mktemp)
  # Lo tuyo gana en cualquier clave que ya tuvieras definida.
  jq -s '.[0] * .[1]' "$here/settings.json" "$CFG/settings.json" > "$tmp"
  mv "$tmp" "$CFG/settings.json"
  printf "  ${V}✓${R} settings fusionados ${D}(tus valores previos ganan)${R}\n"
else
  cp "$here/settings.json" "$CFG/settings.json"
  printf "  ${V}✓${R} settings.json instalado\n"
fi

printf "\n${D}  Cierra tus sesiones y abre una nueva: la config se lee al arrancar.${R}\n"
printf "${D}  Luego corre:${R} bash %s/cc-doctor.sh\n\n" "$here"
