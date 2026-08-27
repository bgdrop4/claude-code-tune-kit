# ─────────────────────────────────────────────────────────────
#  ccglm · levanta Claude Code con GLM SIN tocar tu config global
#  Tune Kit — Imperio Agéntico ·  versión PowerShell (Windows)
#
#  Instalar: pégalo al final de tu perfil de PowerShell y recarga.
#      notepad $PROFILE          # si no existe: New-Item $PROFILE -Force
#      . $PROFILE
#
#  ⚠️ El error que comete todo el mundo: meter estas variables en
#     ~/.claude/settings.json. Eso secuestra TODAS tus sesiones,
#     incluidas las de tus clientes en producción. Esto no.
#     Aquí las variables viven solo en el proceso que levantas y se
#     restauran al terminar, aunque canceles con Ctrl-C.
# ─────────────────────────────────────────────────────────────

# 1) Guarda tu llave fuera de este archivo. Nunca la pegues aquí.
#    En una terminal, UNA vez (queda guardada para tu usuario):
#       [Environment]::SetEnvironmentVariable('ZAI_API_KEY','tu-llave','User')
#    Cierra y abre PowerShell para que la tome.

if (-not $env:GLM_MODEL) { $env:GLM_MODEL = 'glm-5.3' }

function ccglm {
    if (-not $env:ZAI_API_KEY) {
        Write-Error "✋ Falta ZAI_API_KEY. Guárdala antes de usar ccglm."
        return 1
    }

    # Guardamos lo previo para devolver la terminal como estaba.
    $previo = @{}
    $vars = @{
        ANTHROPIC_BASE_URL            = 'https://api.z.ai/api/anthropic'
        ANTHROPIC_AUTH_TOKEN          = $env:ZAI_API_KEY
        ANTHROPIC_DEFAULT_OPUS_MODEL  = $env:GLM_MODEL
        ANTHROPIC_DEFAULT_SONNET_MODEL= $env:GLM_MODEL
        ANTHROPIC_DEFAULT_HAIKU_MODEL = $env:GLM_MODEL
    }

    try {
        foreach ($k in $vars.Keys) {
            $previo[$k] = [Environment]::GetEnvironmentVariable($k)
            Set-Item -Path "env:$k" -Value $vars[$k]
        }
        claude @args
    }
    finally {
        # El finally corre también con Ctrl-C: la terminal nunca queda
        # apuntando a z.ai por accidente después de cerrar la sesión.
        foreach ($k in $vars.Keys) {
            if ($null -eq $previo[$k]) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
            else { Set-Item -Path "env:$k" -Value $previo[$k] }
        }
    }
}

# Variante de contexto largo (1M). Requiere subirle la ventana de compactación.
function ccglm1m {
    $modeloPrevio = $env:GLM_MODEL
    $ventanaPrevia = $env:CLAUDE_CODE_AUTO_COMPACT_WINDOW
    try {
        $env:GLM_MODEL = 'glm-5.3[1m]'
        $env:CLAUDE_CODE_AUTO_COMPACT_WINDOW = '1000000'
        ccglm @args
    }
    finally {
        $env:GLM_MODEL = $modeloPrevio
        if ($null -eq $ventanaPrevia) {
            Remove-Item env:CLAUDE_CODE_AUTO_COMPACT_WINDOW -ErrorAction SilentlyContinue
        } else { $env:CLAUDE_CODE_AUTO_COMPACT_WINDOW = $ventanaPrevia }
    }
}

# Para saber en qué motor estás parado.
function motor {
    if ($env:ANTHROPIC_BASE_URL) { Write-Host "GLM · $env:ANTHROPIC_BASE_URL" -ForegroundColor DarkYellow }
    else { Write-Host "Claude (Anthropic)" -ForegroundColor Green }
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
