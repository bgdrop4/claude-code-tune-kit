#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  FRENO DE MANO · hook PreToolUse (matcher: Bash)
#  Tune Kit — Imperio Agéntico
#
#  Una instrucción en tu CLAUDE.md es una sugerencia.
#  Esto es una pared: exit 2 cancela la llamada antes de ejecutarla
#  y le manda el motivo a Claude por stderr para que corrija solo.
#
#  Dos reglas de diseño, en este orden:
#    1. No se evade.  Comillas, flags separados o sinónimos largos
#       no deben servir para colar un borrado de la raíz.
#    2. No estorba.   `rm -rf build/` es trabajo normal y pasa.
#       Buscar "DROP TABLE" con grep es trabajo normal y pasa.
#
#  Un hook que se burla con comillas da falsa seguridad; uno que
#  bloquea trabajo legítimo se desinstala el primer día.
# ─────────────────────────────────────────────────────────────
set -uo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
[ -z "$cmd" ] && exit 0

bloquea() {
  echo "🛑 FRENO DE MANO: $1" >&2
  [ -n "${2:-}" ] && echo "   $2" >&2
  echo "   Si de verdad lo necesitas, córrelo tú en la terminal." >&2
  exit 2
}

# Comandos que solo LEEN. Dentro de uno de ellos, "DROP TABLE" o
# "--no-verify" son texto que se busca, no una acción que se ejecuta.
es_lectura() {
  case "$1" in
    grep|egrep|fgrep|rg|ag|ack|echo|printf|cat|bat|less|more|head|tail|\
    awk|jq|yq|ls|find|man|open|code|wc|sort|uniq|diff|tree|which|type) return 0 ;;
    git) case "${2:-}" in log|grep|show|diff|blame|status) return 0 ;; esac ;;
  esac
  return 1
}

# ── rm: se analiza token por token, no con comodines sobre la cadena ──
revisa_rm() {
  local -a tok=(); read -ra tok <<< "$1"
  local n=${#tok[@]} i=0

  # saltar prefijos (sudo, env, time…) hasta dar con el binario
  while [ $i -lt $n ]; do
    case "${tok[$i]}" in
      sudo|doas|env|nohup|time|command|\\rm) i=$((i+1)) ;;
      *) break ;;
    esac
  done
  [ "${tok[$i]:-}" = "rm" ] || return 0
  i=$((i+1))

  # separar flags de operandos — aquí mueren `-r -f`, `-rfv`, `-fR` y `--recursive`
  local recursivo=0
  local -a operandos=()
  while [ $i -lt $n ]; do
    case "${tok[$i]}" in
      --recursive|--recursive=*) recursivo=1 ;;
      --) i=$((i+1)); while [ $i -lt $n ]; do operandos+=("${tok[$i]}"); i=$((i+1)); done; break ;;
      --*) : ;;
      -*) case "${tok[$i]}" in *[rR]*) recursivo=1 ;; esac ;;
      *)  operandos+=("${tok[$i]}") ;;
    esac
    i=$((i+1))
  done
  # sin -r un rm no puede vaciar un árbol: no es asunto nuestro
  [ "$recursivo" -eq 1 ] || return 0

  local ruta
  for ruta in "${operandos[@]:-}"; do
    [ -z "$ruta" ] && continue
    ruta="${ruta//\\//}"                   # C:\Windows → C:/Windows
    ruta="${ruta%/}"                       # /usr/ y /usr son lo mismo
    [ -z "$ruta" ] && ruta="/"             # "/" quedó vacío al quitar la barra
    case "$ruta" in
      /)          bloquea "borrado recursivo de la raíz del disco." ;;
      '~'|'$HOME'|'${HOME}'|'$USERPROFILE'|'%USERPROFILE%')
                  bloquea "borrado recursivo del home completo." ;;
      '*'|'.'|'..'|'./*'|'/*')
                  bloquea "borrado recursivo con comodín o sobre el directorio actual." \
                          "Nombra la carpeta: rm -rf ./build" ;;
      /usr|/usr/*|/etc|/etc/*|/bin|/bin/*|/sbin|/sbin/*|/boot|/boot/*|/lib|/lib/*|\
      /System|/System/*|/Library|/Library/*|/Applications|/Applications/*|/opt|/opt/*)
                  bloquea "borrado recursivo dentro de un directorio de sistema ($ruta)." ;;
      /Users|/home|/var|/private)
                  bloquea "borrado recursivo de un árbol de sistema completo ($ruta)." ;;

      # ── Windows ──────────────────────────────────────────────
      # Git Bash monta las unidades como /c, /d… y Claude Code también
      # llega a pasar rutas nativas (C:/Users). Sin estos casos, un
      # `rm -rf /c/Windows` pasaba derecho: verificado antes de agregarlos.
      # Ojo: las comillas ya se quitaron arriba, así que "Program Files"
      # llega partido en dos tokens — por eso el patrón corta en Program*.
      [A-Za-z]:|/[A-Za-z])
                  bloquea "borrado recursivo de la raíz de una unidad ($ruta)." ;;
      [A-Za-z]:/Windows|[A-Za-z]:/Windows/*|/[A-Za-z]/Windows|/[A-Za-z]/Windows/*|\
      [A-Za-z]:/Program*|/[A-Za-z]/Program*|\
      [A-Za-z]:/ProgramData|[A-Za-z]:/ProgramData/*|/[A-Za-z]/ProgramData|/[A-Za-z]/ProgramData/*)
                  bloquea "borrado recursivo dentro de un directorio de sistema de Windows ($ruta)." ;;
      [A-Za-z]:/Users|/[A-Za-z]/Users)
                  bloquea "borrado recursivo de un árbol de sistema completo ($ruta)." ;;
    esac
  done
}

# ── lectura de secretos por la puerta de atrás (fork de Bryan) ──
# El blindaje corta Edit/Write/Read, pero un `cat llaves-api.md` es Bash
# y se colaba entero. En modo=total eso deja el blindaje en decorado.
# Solo aplica si el proyecto declaró modo=total en .claude/blindaje.conf.
revisa_lectura_secretos() {
  local sub="$1" proyecto conf modo extra
  proyecto="${CLAUDE_PROJECT_DIR:-$PWD}"
  conf="$proyecto/.claude/blindaje.conf"
  [ -f "$conf" ] || return 0
  modo=$(grep -E '^[[:space:]]*modo[[:space:]]*=' "$conf" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '[:space:]')
  [ "$modo" = "total" ] || return 0

  local bin=""
  for p in $sub; do
    case "$p" in sudo|doas|env|nohup|time|command) continue ;; esac
    bin="$p"; break
  done
  case "$bin" in
    cat|bat|less|more|head|tail|grep|egrep|rg|ag|strings|xxd|od|nl|cp|scp|rsync|open|code|pbcopy) : ;;
    *) return 0 ;;
  esac

  extra=$(grep -E '^[[:space:]]*proteger[[:space:]]*=' "$conf" 2>/dev/null | cut -d= -f2- | tr -d ' \t\r')
  local tok base patron
  for tok in $sub; do
    case "$tok" in -*) continue ;; esac
    base=$(basename "${tok//\\//}")
    case "$base" in
      .env|.env.*|*.env|id_rsa|id_ed25519|*.pem|*.key|*.p12|*.pfx|credentials|.netrc|.pgpass|.npmrc|.pypirc)
        case "$base" in .env.example|.env.template|.env.sample) continue ;; esac
        bloquea "este proyecto está en modo=total: no se leen secretos desde Bash ($base)." \
                "Si necesitas un valor de ahí, pídeselo a Bryan." ;;
    esac
    [ -z "$extra" ] && continue
    while IFS= read -r patron; do
      [ -z "$patron" ] && continue
      case "$base" in $patron)
        bloquea "este proyecto está en modo=total: \"$base\" está blindado en $conf." \
                "Si necesitas un valor de ahí, pídeselo a Bryan." ;;
      esac
    done <<< "$extra"
  done
}

# ── cada sub-comando se juzga por separado ──
# `cd /tmp && rm -rf /` no se escapa por venir encadenado.
IFS=$'\n' read -rd '' -a SUBS <<< "$(
  printf '%s' "$cmd" \
    | tr -d "\"'" \
    | sed -E 's/(\&\&|\|\||;|\||\n)/\n/g' \
    | sed -E 's/^[[:space:]]+|[[:space:]]+$//g' \
    | tr -s ' '
)" || true

for sub in "${SUBS[@]:-}"; do
  [ -z "${sub// /}" ] && continue

  # binario y subcomando, saltando prefijos
  bin=""; sc=""
  for p in $sub; do
    case "$p" in sudo|doas|env|nohup|time|command) continue ;; esac
    if [ -z "$bin" ]; then bin="$p"; else sc="$p"; break; fi
  done

  revisa_rm "$sub"
  revisa_lectura_secretos "$sub"

  # Un redirect que aplasta un .env es peligroso venga del binario que venga
  # —incluso de `echo`—, así que se juzga ANTES de la excepción de lectura.
  # `>>` (agregar) sí pasa: no destruye lo que ya estaba.
  if printf '%s' "$sub" | grep -qE '[^>]>[[:space:]]*[^[:space:]]*\.env(\.[a-zA-Z0-9]+)?[[:space:]]*$'; then
    bloquea "eso sobrescribe un archivo .env." "Para agregar una variable usa >> y dime cuál."
  fi

  # los chequeos de texto no aplican dentro de un comando de lectura
  es_lectura "$bin" "$sc" && continue

  case " $sub " in
    *" --no-verify "*|*" -n "*"commit"*)
      [ "$bin" = "git" ] && bloquea "--no-verify se salta los hooks de git." \
                                     "Arregla lo que falla, no lo esquives." ;;
  esac

  if [ "$bin" = "git" ]; then
    case " $sub " in
      *" --force "*|*" -f "*)
        case "$sc" in
          push) case " $sub " in *--force-with-lease*) : ;;
                  *) bloquea "push forzado." "Usa --force-with-lease: falla si alguien más subió algo." ;;
                esac ;;
        esac ;;
    esac
    case "$sub" in
      *"reset --hard origin/main"*|*"reset --hard origin/master"*|*"reset --hard upstream/"*)
        bloquea "reset --hard contra la rama remota principal." "Perderías todo lo local sin commit." ;;
    esac
  fi

  if printf '%s' "$sub" | grep -qiE '\b(drop[[:space:]]+(table|database|schema)|truncate[[:space:]]+table)\b'; then
    bloquea "sentencia SQL destructiva."
  fi

  if printf '%s' "$sub" | grep -qE '^[[:space:]]*(curl|wget)\b' && \
     printf '%s' "$cmd"  | grep -qE '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|k)?sh\b'; then
    bloquea "descarga ejecutada a ciegas (curl | sh)." "Descárgalo, léelo, y entonces ejecútalo."
  fi

  case " $sub " in
    *" chmod "*)
      case "$sub" in *777*) bloquea "chmod 777 deja el archivo abierto a todo el sistema." ;; esac ;;
  esac

done

exit 0
