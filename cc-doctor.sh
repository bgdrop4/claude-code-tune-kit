#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  cc-doctor · audita tu propia instalación de Claude Code
#  Tune Kit — Imperio Agéntico ·  bash cc-doctor.sh
#
#  No cambia nada. Solo lee, revisa y te dice qué te falta.
# ─────────────────────────────────────────────────────────────
set -uo pipefail

MIN_VERSION="2.1.237"        # mínima para el estilo Concise
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
S="$CFG/settings.json"

# Git Bash / MSYS / Cygwin se reportan como MINGW*, MSYS* o CYGWIN*
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*) ES_WINDOWS=1; SO="Windows (Git Bash)"; JQ_INSTALL="winget install jqlang.jq" ;;
  Darwin)               ES_WINDOWS=0; SO="macOS";              JQ_INSTALL="brew install jq" ;;
  *)                    ES_WINDOWS=0; SO="Linux";              JQ_INSTALL="sudo apt install jq" ;;
esac

O=$'\033[38;5;173m'; V=$'\033[38;5;71m'; A=$'\033[38;5;179m'
X=$'\033[38;5;167m'; D=$'\033[2m'; B=$'\033[1m'; R=$'\033[0m'

ok=0; warn=0; bad=0
si()   { printf "  ${V}✓${R} %s\n" "$1"; ok=$((ok+1)); }
casi() { printf "  ${A}▲${R} %s\n" "$1"; [ -n "${2:-}" ] && printf "     ${D}%s${R}\n" "$2"; warn=$((warn+1)); }
no()   { printf "  ${X}✕${R} %s\n" "$1"; [ -n "${2:-}" ] && printf "     ${D}%s${R}\n" "$2"; bad=$((bad+1)); }
titulo(){ printf "\n${O}${B}%s${R}\n" "$1"; }

get() { [ -f "$S" ] && jq -r "$1 // empty" "$S" 2>/dev/null; }

printf "\n${O}${B}  cc-doctor${R} ${D}· Tune Kit · Imperio Agéntico${R}\n"
printf "${D}  %s · %s${R}\n" "$CFG" "$SO"

# ── 1 · lo básico ───────────────────────────────────────────
titulo "1 · Lo básico"

if command -v jq >/dev/null 2>&1; then si "jq instalado"
else no "jq NO instalado" "Sin jq no corren ni los hooks ni la línea de estado: $JQ_INSTALL"; fi

if command -v claude >/dev/null 2>&1; then
  ver=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  menor=$(printf '%s\n%s\n' "$MIN_VERSION" "$ver" | sort -V | head -1)
  if [ "$menor" = "$MIN_VERSION" ]; then si "claude $ver"
  else casi "claude $ver — vieja" "El estilo Concise pide $MIN_VERSION o más: claude update"; fi
else no "claude no está en el PATH"; fi

if [ -f "$S" ]; then
  if jq empty "$S" 2>/dev/null; then si "settings.json válido"
  else no "settings.json tiene JSON roto" "Claude Code lo ignora entero. Revísalo con: jq . $S"; fi
else no "no hay settings.json" "Copia el del kit: cp settings.json $S"; fi

# ── 2 · el secuestro silencioso ─────────────────────────────
titulo "2 · ¿Quién manda en tu modelo?"

if [ -n "${ANTHROPIC_BASE_URL:-}" ]; then
  casi "ANTHROPIC_BASE_URL exportado en tu shell" "→ $ANTHROPIC_BASE_URL — TODAS tus sesiones salen por ahí, incluidas las de clientes."
else si "sin ANTHROPIC_BASE_URL global"; fi

if [ -n "$(get '.env.ANTHROPIC_BASE_URL')" ]; then
  no "settings.json global redirige el modelo" "Sácalo de ahí y usa la función ccglm o --settings por sesión."
else si "el settings global no secuestra el modelo"; fi

if [ -n "${ANTHROPIC_MODEL:-}" ]; then
  casi "ANTHROPIC_MODEL exportado" "Gana sobre la clave \"model\" de cualquier archivo. Por eso a veces no te toma el cambio."
fi

for k in ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ZAI_API_KEY; do
  v=$(get ".env.$k")
  [ -n "$v" ] && no "$k escrito dentro de settings.json" "Ese archivo se comparte y se respalda. Sácalo a una variable de entorno."
done

# ── 3 · lo que pediste en clase ─────────────────────────────
titulo "3 · Los settings de la clase"

st=$(get '.outputStyle')
case "$st" in
  "")        casi "sin outputStyle" 'Prueba "outputStyle": "Concise" — resultado primero, sin narración.' ;;
  Concise)   si "outputStyle: Concise" ;;
  *)         si "outputStyle: $st" ;;
esac

if [ -n "$(get '.statusLine.command')" ]; then si "línea de estado activa"
else casi "sin línea de estado" "Vuelas a ciegas de contexto. Copia statusline.sh del kit."; fi

if [ "$(get '.remoteControlAtStartup')" = "true" ]; then si "remoto conectado al arrancar"
else casi "remoto apagado" '"remoteControlAtStartup": true y sigues la sesión desde el celular.'; fi

if [ "$(get '.agentPushNotifEnabled')" = "true" ] || [ "$(get '.inputNeededNotifEnabled')" = "true" ]; then
  si "notificaciones al celular activas"
else casi "sin notificaciones" "La sesión se queda esperándote parado en vez de buscarte."; fi

acw=$(get '.autoCompactWindow')
if [ -n "$acw" ]; then
  # acepta 100K a 1M TOKENS. Un 0.8 o un 80 ahí no es "80%": es basura.
  if printf '%s' "$acw" | grep -qE '^[0-9]+$' && [ "$acw" -ge 100000 ] && [ "$acw" -le 1000000 ]; then
    si "autoCompactWindow: $acw tokens"
  else
    no "autoCompactWindow: $acw — fuera de rango" "Son TOKENS, de 100000 a 1000000. Un 0.8 no es 80%. Bórralo o usa /autocompact 150k."
  fi
else
  printf "  ${D}·${R} ${D}autoCompactWindow sin definir — el default del modelo está bien${R}\n"
fi

ef=$(get '.effortLevel')
[ -n "$ef" ] && si "effortLevel: $ef" || printf "  ${D}·${R} ${D}effortLevel sin fijar — cada sesión arranca en el default${R}\n"

if [ -n "$(get '.attribution')" ]; then si "atribución de commits personalizada"
else printf "  ${D}·${R} ${D}tus commits llevan el Co-Authored-By por defecto (se quita con \"attribution\")${R}\n"; fi

# ── 4 · las paredes ─────────────────────────────────────────
titulo "4 · Hooks y permisos"

if [ "$(get '.disableAllHooks')" = "true" ]; then
  no "disableAllHooks está en true" "Tienes TODO apagado: hooks y línea de estado. ¿Se te olvidó quitarlo?"
fi

n_hooks=$( [ -f "$S" ] && jq '[.hooks // {} | to_entries[] | .value[]?.hooks[]?] | length' "$S" 2>/dev/null || echo 0 )
n_hooks=${n_hooks:-0}
if [ "$n_hooks" -eq 0 ]; then
  no "cero hooks" "Todo lo que le pides en el CLAUDE.md es una sugerencia. El kit trae 4 paredes listas."
else
  si "$n_hooks hook(s) configurados"
  for ev in PreToolUse PostToolUse Stop SessionStart; do
    c=$(jq --arg e "$ev" '[.hooks[$e][]?.hooks[]?] | length' "$S" 2>/dev/null || echo 0)
    [ "${c:-0}" -gt 0 ] && printf "     ${D}%s × %s${R}\n" "$ev" "$c"
  done

  # El avisito necesita su par de eventos. Con Stop a solas, habla en CADA turno.
  n_stop=$(jq '[.hooks.Stop[]?.hooks[]? | select(.command | test("aviso"))] | length' "$S" 2>/dev/null || echo 0)
  n_ups=$(jq  '[.hooks.UserPromptSubmit[]?.hooks[]? | select(.command | test("aviso"))] | length' "$S" 2>/dev/null || echo 0)
  if [ "${n_stop:-0}" -gt 0 ] && [ "${n_ups:-0}" -eq 0 ]; then
    casi "el avisito solo tiene el hook Stop" "Sin el de UserPromptSubmit no puede medir cuánto tardó el turno y te va a hablar en cada respuesta."
  fi
fi

deny=$(jq -r '[.permissions.deny[]?] | join(" ")' "$S" 2>/dev/null)
case "$deny" in
  *env*) si "tus .env están bloqueados para lectura" ;;
  *)     no "nada bloquea la lectura de tus .env" 'Agrega "Read(./.env)" y "Read(./.env.*)" a permissions.deny.' ;;
esac

n_allow=$(jq '[.permissions.allow[]?] | length' "$S" 2>/dev/null || echo 0)
if [ "${n_allow:-0}" -lt 5 ]; then
  casi "solo ${n_allow:-0} permisos pre-aprobados" "Corre /fewer-permission-prompts: lee tus transcripts y te escribe el allowlist solo."
else si "${n_allow} permisos pre-aprobados"; fi

# ── 5 · lo que se come tu contexto ──────────────────────────
titulo "5 · Lo que se come tu ventana"

for f in "$CFG/CLAUDE.md" "./CLAUDE.md"; do
  if [ -f "$f" ]; then
    w=$(wc -w < "$f" | tr -d ' ')
    aprox=$(( w * 4 / 3 ))
    if   [ "$aprox" -gt 6000 ]; then no   "$f ≈ ${aprox} tokens" "Se carga ENTERO en cada sesión. Arriba de ~6k ya duele."
    elif [ "$aprox" -gt 3000 ]; then casi "$f ≈ ${aprox} tokens" "Vigílalo. Lo que no sea regla dura, muévelo a una skill."
    else si "$f ≈ ${aprox} tokens"; fi
  fi
done

n_plug=$(jq '[.enabledPlugins // {} | to_entries[] | select(.value == true)] | length' "$S" 2>/dev/null || echo 0)
if [ "${n_plug:-0}" -gt 8 ]; then casi "$n_plug plugins activos" "Cada uno mete sus skills al listado. Corre /context y mira cuánto pesan."
elif [ "${n_plug:-0}" -gt 0 ]; then si "$n_plug plugins activos"; fi

cd_days=$(get '.cleanupPeriodDays')
if [ -d "$CFG/projects" ]; then
  peso=$(du -sh "$CFG/projects" 2>/dev/null | cut -f1)
  if [ -z "$cd_days" ]; then casi "transcripts: $peso, sin política de limpieza" 'Define "cleanupPeriodDays": 30.'
  else si "transcripts: $peso · se borran a los $cd_days días"; fi
fi

# ── 6 · Windows ─────────────────────────────────────────────
# Las tres formas en que este kit muere en Windows y en ningún otro lado.
if [ "$ES_WINDOWS" -eq 1 ]; then
  titulo "6 · Windows"

  # a) CRLF — el asesino silencioso. Con core.autocrlf=true el clone
  #    convierte los .sh y bash sale a buscar «bash\r».
  crlf=0
  for f in "$CFG"/hooks/*.sh "$CFG/statusline.sh"; do
    [ -f "$f" ] && grep -q $'\r' "$f" 2>/dev/null && crlf=$((crlf+1))
  done
  if [ "$crlf" -gt 0 ]; then
    no "$crlf script(s) con finales de línea CRLF" \
       "Bash busca un binario llamado «bash\\r» y NADA arranca. Corre: bash instalar.sh"
  else
    si "los scripts instalados están en LF"
  fi

  # b) el .sh pelón en settings.json — Windows lo abre con el selector de
  #    aplicación en vez de ejecutarlo (claude-code#21847, #24097).
  if [ -f "$S" ]; then
    pelon=$(jq -r '[.. | objects | select(has("command")) | .command
                    | select(type == "string")
                    | select(test("\\.sh\\s*$")) | select(test("^\\s*bash\\s") | not)] | length' \
                 "$S" 2>/dev/null || echo 0)
    if [ "${pelon:-0}" -gt 0 ]; then
      no "$pelon comando(s) apuntan a un .sh sin 'bash' adelante" \
         "Windows abre el selector de aplicación en vez de ejecutarlo. Usa: \"bash ~/.claude/hooks/x.sh\""
    else
      si "los comandos .sh llevan 'bash' adelante"
    fi
  fi

  # c) qué bash resuelve. Desde 2.1.81 el instalador nativo llegó a
  #    resolver a bash de WSL, que no ve tus rutas de Windows (#37634).
  cual_bash=$(command -v bash 2>/dev/null)
  case "$cual_bash" in
    /usr/bin/bash|/bin/bash|*Git*|*git*|*mingw*|*MINGW*) si "bash resuelve a Git Bash ${D}($cual_bash)${R}" ;;
    "") no "no encuentro bash en el PATH" "Instala Git for Windows: winget install Git.Git" ;;
    *)  casi "bash resuelve a $cual_bash" "Si es el de WSL, no ve tus rutas de Windows y los hooks fallan raro." ;;
  esac
fi

# ── veredicto ───────────────────────────────────────────────
printf "\n${O}${B}  Veredicto${R}\n"
printf "  ${V}%s bien${R}  ${A}%s por revisar${R}  ${X}%s pendientes${R}\n" "$ok" "$warn" "$bad"
if [ "$bad" -eq 0 ] && [ "$warn" -le 2 ]; then
  printf "  ${V}Tu Claude Code está tuneado.${R}\n\n"
elif [ "$bad" -eq 0 ]; then
  printf "  ${A}Vas bien. Lo de arriba son mejoras, no fugas.${R}\n\n"
else
  printf "  ${X}Empieza por las ✕ — ahí es donde estás dejando tiempo, dinero o seguridad en la mesa.${R}\n\n"
fi
