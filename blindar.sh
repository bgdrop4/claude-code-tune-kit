#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  blindar · configura el blindaje de ESTE proyecto
#  Tune Kit — fork de Bryan
#
#    bash blindar.sh                          → ver el estado actual
#    bash blindar.sh escritura                → fijar el modo
#    bash blindar.sh total llaves-api.md      → modo + archivo, de una
#    bash blindar.sh + notas-privadas.md      → añadir sin tocar el modo
# ─────────────────────────────────────────────────────────────
set -euo pipefail

V=$'\033[38;5;71m'; A=$'\033[38;5;179m'; D=$'\033[2m'; B=$'\033[1m'; O=$'\033[38;5;173m'; R=$'\033[0m'

raiz=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
conf="$raiz/.claude/blindaje.conf"
mkdir -p "$raiz/.claude"
[ -f "$conf" ] || printf 'modo=escritura\n' > "$conf"

modo_actual=$(grep -E '^[[:space:]]*modo[[:space:]]*=' "$conf" | tail -1 | cut -d= -f2- | tr -d '[:space:]')

estado() {
  printf "\n${O}${B}  blindaje${R} ${D}→ %s${R}\n\n" "$conf"
  printf "  modo: ${B}%s${R}  " "$modo_actual"
  case "$modo_actual" in
    total)     printf "${D}nadie sobrescribe NI lee los archivos protegidos${R}\n" ;;
    *)         printf "${D}nadie sobrescribe, pero Claude sí puede leerlos${R}\n" ;;
  esac
  local n
  n=$(grep -cE '^[[:space:]]*proteger[[:space:]]*=' "$conf" || true)
  if [ "$n" -eq 0 ]; then
    printf "  ${D}sin archivos propios en la lista (los estándar ya van cubiertos)${R}\n\n"
  else
    printf "\n  protegidos aquí:\n"
    grep -E '^[[:space:]]*proteger[[:space:]]*=' "$conf" | cut -d= -f2- | tr -d ' \t\r' \
      | while read -r p; do
          if [ -e "$raiz/$p" ] && ! git -C "$raiz" check-ignore -q "$p" 2>/dev/null; then
            printf "    ${A}▲${R} %-28s ${D}existe y NO está en .gitignore${R}\n" "$p"
          else
            printf "    ${V}✓${R} %s\n" "$p"
          fi
        done
    printf "\n"
  fi
}

[ $# -eq 0 ] && { estado; exit 0; }

case "$1" in
  escritura|total)
    modo_actual="$1"; shift
    tmp=$(mktemp)
    { printf 'modo=%s\n' "$modo_actual"
      grep -E '^[[:space:]]*proteger[[:space:]]*=' "$conf" 2>/dev/null || true; } > "$tmp"
    mv "$tmp" "$conf" ;;
  +) shift ;;
  *) echo "Uso: blindar.sh [escritura|total|+] [archivo...]" >&2; exit 1 ;;
esac

for f in "$@"; do
  base=$(basename "$f")
  if grep -qE "^[[:space:]]*proteger[[:space:]]*=[[:space:]]*$base[[:space:]]*$" "$conf"; then
    printf "  ${D}ya estaba: %s${R}\n" "$base"
  else
    printf 'proteger=%s\n' "$base" >> "$conf"
    printf "  ${V}✓${R} protegido: %s\n" "$base"
  fi
  # una llave protegida que se sube a git no está protegida de nada
  if [ -e "$raiz/$base" ] && ! git -C "$raiz" check-ignore -q "$base" 2>/dev/null; then
    printf "  ${A}▲${R} %s NO está en .gitignore ${D}— si lo commiteas, la llave sale del Mac${R}\n" "$base"
  fi
done

estado
