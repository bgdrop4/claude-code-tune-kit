#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  Suite del FORK ·  bash test/test-fork.sh
#
#  Cubre solo lo que añade este fork sobre el kit original:
#    · blindaje con modo por proyecto (.claude/blindaje.conf)
#    · lectura de secretos desde Bash cortada en modo=total
#    · registro de llaves nuevas sin blindar
#
#  Va en archivo aparte a propósito: así un `git merge upstream/main`
#  que toque test/test.sh nunca choca con estas pruebas.
# ─────────────────────────────────────────────────────────────
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
RAIZ="$PWD"

V=$'\033[38;5;71m'; X=$'\033[38;5;167m'; D=$'\033[2m'; B=$'\033[1m'; O=$'\033[38;5;173m'; R=$'\033[0m'
ok=0; fail=0
titulo(){ printf "\n${O}${B}%s${R}\n" "$1"; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.claude"
printf 'ANTHROPIC_API_KEY=sk-ant-1234567890abcdefghij\n' > "$TMP/llaves-api.md"
printf '# tareas\n- comprar pan\n'                        > "$TMP/tareas.md"
printf 'RETELL_TOKEN=key-abcdefghij1234567890\n'          > "$TMP/nuevo-proveedor.md"

conf() { printf 'modo=%s\nproteger=llaves-api.md\n' "$1" > "$TMP/.claude/blindaje.conf"; }

# $1 hook · $2 payload · $3 BLOQUEA|PASA · $4 etiqueta
corre() {
  local code got
  printf '%s' "$2" | CLAUDE_PROJECT_DIR="$TMP" bash "$RAIZ/hooks/$1" >/dev/null 2>&1
  code=$?
  got=PASA
  [ "$code" -eq 2 ] && got=BLOQUEA
  if [ "$got" = "$3" ]; then
    ok=$((ok+1)); printf "  ${V}✓${R} %-7s ${D}%s${R}\n" "$got" "$4"
  else
    fail=$((fail+1)); printf "  ${X}✗ esperaba %s, dio %s${R}  %s\n" "$3" "$got" "$4"
  fi
}

edit() { printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1"; }
lee()  { printf '{"tool_name":"Read","tool_input":{"file_path":"%s"}}' "$1"; }
bash_() { printf '{"tool_input":{"command":"%s"}}' "$1"; }

printf "\n${O}${B}  Tune Kit · fork de Bryan${R}\n"

titulo "modo=escritura · se protege de la sobrescritura, no de la lectura"
conf escritura
corre blindaje-env.sh "$(edit "$TMP/llaves-api.md")" BLOQUEA "escribir llaves-api.md"
corre blindaje-env.sh "$(lee  "$TMP/llaves-api.md")" PASA    "leer llaves-api.md (Claude sí puede)"
corre blindaje-env.sh "$(edit "$TMP/tareas.md")"     PASA    "escribir un .md normal"
corre blindaje-env.sh "$(edit "$TMP/.env")"          BLOQUEA ".env sigue cubierto sin listarlo"
corre blindaje-env.sh "$(edit "$TMP/.env.example")"  PASA    ".env.example es plantilla"
corre freno-de-mano.sh "$(bash_ "cat llaves-api.md")" PASA   "cat llaves-api.md en modo escritura"

titulo "modo=total · tampoco se lee, ni con Read ni con cat"
conf total
corre blindaje-env.sh "$(edit "$TMP/llaves-api.md")"  BLOQUEA "escribir llaves-api.md"
corre blindaje-env.sh "$(lee  "$TMP/llaves-api.md")"  BLOQUEA "Read sobre llaves-api.md"
corre blindaje-env.sh "$(lee  "$TMP/tareas.md")"      PASA    "Read sobre un .md normal"
corre freno-de-mano.sh "$(bash_ "cat llaves-api.md")"        BLOQUEA "cat llaves-api.md"
corre freno-de-mano.sh "$(bash_ "grep -n TOKEN llaves-api.md")" BLOQUEA "grep dentro de llaves-api.md"
corre freno-de-mano.sh "$(bash_ "cat .env")"                 BLOQUEA "cat .env"
corre freno-de-mano.sh "$(bash_ "cp .env /tmp/x")"           BLOQUEA "copiar el .env fuera"
corre freno-de-mano.sh "$(bash_ "cat tareas.md")"            PASA    "cat de un archivo normal"
corre freno-de-mano.sh "$(bash_ "cat .env.example")"         PASA    "cat de la plantilla"
corre freno-de-mano.sh "$(bash_ "ls -la")"                   PASA    "trabajo normal no estorbado"

titulo "sin blindaje.conf · nunca menos protección que el kit original"
rm -f "$TMP/.claude/blindaje.conf"
corre blindaje-env.sh "$(edit "$TMP/.env")"          BLOQUEA ".env protegido por default"
corre blindaje-env.sh "$(edit "$TMP/id_rsa")"        BLOQUEA "llave privada protegida por default"
corre blindaje-env.sh "$(lee  "$TMP/.env")"          PASA    "sin conf, la lectura no se corta"
corre freno-de-mano.sh "$(bash_ "cat .env")"         PASA    "sin conf, cat no se corta"

titulo "registro de llaves nuevas"
corre registro-llaves.sh "$(edit "$TMP/nuevo-proveedor.md")" BLOQUEA "archivo nuevo con un token dentro"
corre registro-llaves.sh "$(edit "$TMP/tareas.md")"          PASA    "un .md sin secretos no molesta"
conf escritura
corre registro-llaves.sh "$(edit "$TMP/llaves-api.md")"      PASA    "ya registrado: no vuelve a avisar"
corre registro-llaves.sh "$(edit "$TMP/.env")"               PASA    "estándar: el blindaje ya lo cubre"

titulo "varias entradas proteger= · el bug del tr que se comía los saltos de línea"
printf 'modo=total\nproteger=llaves-api.md\nproteger=notas-privadas.md\nproteger=*-secretos.md\n' > "$TMP/.claude/blindaje.conf"
printf 'x\n' > "$TMP/notas-privadas.md"; printf 'x\n' > "$TMP/cliente-secretos.md"
corre blindaje-env.sh "$(edit "$TMP/llaves-api.md")"      BLOQUEA "la 1a entrada de la lista"
corre blindaje-env.sh "$(edit "$TMP/notas-privadas.md")"  BLOQUEA "la 2a entrada (aquí fallaba antes)"
corre blindaje-env.sh "$(edit "$TMP/cliente-secretos.md")" BLOQUEA "la 3a, por comodín"
corre blindaje-env.sh "$(edit "$TMP/tareas.md")"          PASA    "lo que no está en la lista"
corre freno-de-mano.sh "$(bash_ "cat notas-privadas.md")" BLOQUEA "cat de la 2a entrada"

titulo "sintaxis"
for f in hooks/blindaje-env.sh hooks/registro-llaves.sh hooks/freno-de-mano.sh test/test-fork.sh; do
  if bash -n "$f" 2>/dev/null; then
    ok=$((ok+1)); printf "  ${V}✓${R} bash -n  ${D}%s${R}\n" "$f"
  else
    fail=$((fail+1)); printf "  ${X}✗ bash -n  %s${R}\n" "$f"
  fi
done

printf "\n${B}  %d pasaron · %d fallaron${R}\n\n" "$ok" "$fail"
[ "$fail" -eq 0 ]
