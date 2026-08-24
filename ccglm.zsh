# ─────────────────────────────────────────────────────────────
#  ccglm · levanta Claude Code con GLM SIN tocar tu config global
#  Tune Kit — Imperio Agéntico
#
#  Pégalo en ~/.zshrc (o ~/.bashrc) y recarga:  source ~/.zshrc
#
#  ⚠️ El error que comete todo el mundo: meter este bloque `env` en
#     ~/.claude/settings.json. Eso secuestra TODAS tus sesiones,
#     incluidas las de tus clientes en producción. Esto no.
#     Aquí las variables viven solo en el proceso que levantas.
# ─────────────────────────────────────────────────────────────

# 1) Guarda tu llave fuera del archivo de config. Nunca la pegues aquí.
#    export ZAI_API_KEY="..."      ← en ~/.zshrc.local, que no va a git
#    o léela del llavero de macOS:
#    export ZAI_API_KEY="$(security find-generic-password -s zai -w)"

export GLM_MODEL="${GLM_MODEL:-glm-5.3}"

ccglm() {
  if [ -z "${ZAI_API_KEY:-}" ]; then
    echo "✋ Falta ZAI_API_KEY. Expórtala antes de usar ccglm." >&2
    return 1
  fi
  ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic" \
  ANTHROPIC_AUTH_TOKEN="$ZAI_API_KEY" \
  ANTHROPIC_DEFAULT_OPUS_MODEL="$GLM_MODEL" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="$GLM_MODEL" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL="$GLM_MODEL" \
  claude "$@"
}

# Variante de contexto largo (1M). Requiere subirle la ventana de compactación.
ccglm1m() {
  GLM_MODEL="glm-5.3[1m]" \
  CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000 \
  ccglm "$@"
}

# ─────────────────────────────────────────────────────────────
#  ⚠️ EL ENDPOINT CORRECTO ES  /api/anthropic
#
#  Si apuntas a  https://api.z.ai/api/coding/paas/v4  (el que usan
#  OTRAS herramientas) NO te da un error de conexión: te devuelve
#  «1113 Insufficient Balance» y te empieza a cobrar por token en vez
#  de consumir tu plan. Es el error más caro de todo este setup.
#
#  Y la variable es ANTHROPIC_BASE_URL. Varios tutoriales dicen
#  ANTHROPIC_API_BASE — Claude Code no lee esa.
# ─────────────────────────────────────────────────────────────
