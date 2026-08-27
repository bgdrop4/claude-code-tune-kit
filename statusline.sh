#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  EL SEMÁFORO · statusLine
#  Tune Kit — Imperio Agéntico
#
#  🧠 modelo | 🟢 ctx 23% | 📁 carpeta ⎇ rama | ⏳ 5h:12% 7d:41%
#
#  La regla, que es lo que de verdad importa:
#    🟢 <50%   sigue, no hagas nada
#    🟡 50-80% cierra el hilo actual, no abras frente nuevo
#    🔴 >80%   commit + PROGRESS.md + /clear   (nunca /compact a ciegas)
#
#  Instalar:  "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" }
# ─────────────────────────────────────────────────────────────
input=$(cat)

# Todo se lee con `// empty` a propósito: la documentación advierte que
# `context_window` es null antes de la primera llamada y después de /compact,
# y que `rate_limits` solo existe para suscriptores Pro/Max. Un campo ausente
# desaparece de la línea; nunca imprime "null".

MODEL=$(printf '%s' "$input" | jq -r '.model.display_name // "claude"')
CTX=$(printf   '%s' "$input" | jq -r '.context_window.used_percentage // empty')
DIR=$(printf   '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')
FIVE=$(printf  '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
WEEK=$(printf  '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
STYLE=$(printf '%s' "$input" | jq -r '.output_style.name // empty')
COST=$(printf  '%s' "$input" | jq -r '.cost.total_cost_usd // empty')
SIZE=$(printf  '%s' "$input" | jq -r '.context_window.context_window_size // empty')

# Naranja de marca + gris tenue. Si tu terminal no los soporta, borra estas 4 líneas.
O=$'\033[38;5;173m'   # naranja
D=$'\033[2m'          # tenue
B=$'\033[1m'          # fuerte
R=$'\033[0m'          # reset

out="${O}🧠 ${MODEL}${R}"

# Marca el modelo cuando NO es Claude — para que nunca se te olvide
# en qué motor estás corriendo cuando andes con GLM.
case "$MODEL" in
  *GLM*|*glm*) out="${out} ${D}(z.ai)${R}" ;;
esac

if [ -n "$CTX" ]; then
  pct=$(printf '%.0f' "$CTX")
  if   [ "$pct" -ge 80 ]; then icon="🔴"
  elif [ "$pct" -ge 50 ]; then icon="🟡"
  else                        icon="🟢"; fi
  out="${out} ${D}|${R} ${icon} ctx ${B}${pct}%${R}"
  # en ventana de 1M un 40% es otra cosa que en 200k: hay que decirlo
  [ "${SIZE:-0}" -ge 1000000 ] 2>/dev/null && out="${out} ${D}/1M${R}"
fi

if [ -n "$DIR" ]; then
  # En Windows la ruta llega con backslash; sin normalizar, `basename`
  # no parte nada y la línea de estado imprime C:\Users\x\proyecto entero.
  out="${out} ${D}|${R} 📁 $(basename "${DIR//\\//}")"
  branch=$(git -C "$DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    dirty=""
    [ -n "$(git -C "$DIR" status --porcelain 2>/dev/null)" ] && dirty="${O}*${R}"
    out="${out} ${D}⎇${R} ${branch}${dirty}"
  fi
fi

limits=""
[ -n "$FIVE" ] && limits="5h:$(printf '%.0f' "$FIVE")%"
[ -n "$WEEK" ] && limits="${limits:+$limits }7d:$(printf '%.0f' "$WEEK")%"
[ -n "$limits" ] && out="${out} ${D}|${R} ⏳ ${D}${limits}${R}"

if [ -n "$COST" ]; then
  usd=$(printf '%.2f' "$COST" 2>/dev/null)
  [ "$usd" != "0.00" ] && out="${out} ${D}|${R} ${D}\$${usd}${R}"
fi

# Solo se muestra si NO estás en el estilo por defecto, para que
# sepas cuándo traes puesto el modo conciso.
[ -n "$STYLE" ] && [ "$STYLE" != "default" ] && out="${out} ${D}| ✂️ ${STYLE}${R}"

printf '%s\n' "$out"
