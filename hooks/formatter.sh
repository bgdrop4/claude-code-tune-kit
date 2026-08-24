#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  FORMATTER AUTOMÁTICO · hook PostToolUse (matcher: Edit|Write)
#  Tune Kit — Imperio Agéntico
#
#  Formatea el archivo recién editado, si el proyecto tiene con qué.
#  Silencioso por diseño: si no hay formatter, no pasa nada y no molesta.
#  Nunca bloquea (PostToolUse corre DESPUÉS; aquí exit 2 no cancela nada).
# ─────────────────────────────────────────────────────────────
set -uo pipefail

input=$(cat)
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')
# `A || B && C` en bash es `(A || B) && C` — funcionaba por accidente.
# Explícito, para que nadie lo copie mal a otro hook.
if [ -z "$path" ] || [ ! -f "$path" ]; then exit 0; fi

tiene() { command -v "$1" >/dev/null 2>&1; }

case "$path" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.css|*.scss|*.html|*.md|*.yml|*.yaml)
    if [ -f package.json ] && tiene npx; then
      npx --no-install prettier --write "$path" >/dev/null 2>&1
    fi ;;
  *.py)
    if   tiene ruff;  then ruff format "$path" >/dev/null 2>&1
    elif tiene black; then black -q "$path"    >/dev/null 2>&1
    fi ;;
  *.go)  tiene gofmt   && gofmt -w "$path"      >/dev/null 2>&1 ;;
  *.rs)  tiene rustfmt && rustfmt "$path"       >/dev/null 2>&1 ;;
  *.sh)  tiene shfmt   && shfmt -w -i 2 "$path" >/dev/null 2>&1 ;;
esac

exit 0
