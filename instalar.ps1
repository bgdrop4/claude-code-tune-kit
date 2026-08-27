# ─────────────────────────────────────────────────────────────
#  Instalador del Tune Kit · Windows
#  Imperio Agéntico
#
#  Correlo así, desde la carpeta del kit:
#      powershell -ExecutionPolicy Bypass -File .\instalar.ps1
#
#  Hace lo mismo que instalar.sh y respalda antes de tocar nada.
#  La fusión de settings.json va con ConvertFrom-Json, que viene en
#  PowerShell: para INSTALAR no necesitas jq. Para que los hooks
#  CORRAN sí lo vas a necesitar — al final te lo dice.
# ─────────────────────────────────────────────────────────────
$ErrorActionPreference = 'Stop'

$cfg  = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Ok   ($m) { Write-Host "  ✓ " -ForegroundColor Green      -NoNewline; Write-Host $m }
function Aviso($m) { Write-Host "  ▲ " -ForegroundColor Yellow     -NoNewline; Write-Host $m }
function Mal  ($m) { Write-Host "  ✕ " -ForegroundColor Red        -NoNewline; Write-Host $m }
function Tenue($m) { Write-Host "     $m" -ForegroundColor DarkGray }

Write-Host ""
Write-Host "  Tune Kit" -ForegroundColor DarkYellow -NoNewline
Write-Host " → $cfg" -ForegroundColor DarkGray
Write-Host ""

New-Item -ItemType Directory -Force -Path (Join-Path $cfg 'hooks')         | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $cfg 'output-styles') | Out-Null

$settingsPath = Join-Path $cfg 'settings.json'

# ── 1 · respaldo de lo que ya tenías ─────────────────────────
if (Test-Path $settingsPath) {
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  Copy-Item $settingsPath "$settingsPath.antes-del-tune-kit.$stamp"
  Ok "respaldo: settings.json.antes-del-tune-kit.$stamp"
}

# ── 2 · piezas que se copian sin riesgo ──────────────────────
# Se escriben con LF a propósito. Si un .sh queda con CRLF, bash lee el
# shebang como "#!/usr/bin/env bash`r" y sale a buscar un binario llamado
# «bash\r»: los cuatro hooks mueren con un error que no dice nada.
function Copiar-ComoLF ($origen, $destino) {
  $texto = [IO.File]::ReadAllText($origen) -replace "`r`n", "`n"
  $utf8SinBOM = New-Object System.Text.UTF8Encoding $false
  [IO.File]::WriteAllText($destino, $texto, $utf8SinBOM)
}

Get-ChildItem -Path (Join-Path $here 'hooks') -Filter '*.sh' | ForEach-Object {
  Copiar-ComoLF $_.FullName (Join-Path $cfg "hooks\$($_.Name)")
}
Copiar-ComoLF (Join-Path $here 'statusline.sh') (Join-Path $cfg 'statusline.sh')
Get-ChildItem -Path (Join-Path $here 'output-styles') -Filter '*.md' | ForEach-Object {
  Copy-Item $_.FullName (Join-Path $cfg "output-styles\$($_.Name)")
}
Ok "hooks, línea de estado y estilo copiados (en LF)"

# ── 3 · settings: fusionar, NUNCA sobrescribir ───────────────
# Lo tuyo gana en cualquier clave que ya tuvieras definida.
function Fusionar ($base, $tuyo) {
  $salida = @{}
  foreach ($p in $base.PSObject.Properties)  { $salida[$p.Name] = $p.Value }
  foreach ($p in $tuyo.PSObject.Properties) {
    if ($salida.ContainsKey($p.Name) -and
        $salida[$p.Name] -is [PSCustomObject] -and $p.Value -is [PSCustomObject]) {
      $salida[$p.Name] = Fusionar $salida[$p.Name] $p.Value
    } else {
      $salida[$p.Name] = $p.Value          # el valor previo del usuario manda
    }
  }
  [PSCustomObject]$salida
}

$kitSettings = Get-Content (Join-Path $here 'settings.json') -Raw | ConvertFrom-Json

if (Test-Path $settingsPath) {
  try {
    $tuyo   = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $merged = Fusionar $kitSettings $tuyo
    # OJO: `Set-Content -Encoding UTF8` en Windows PowerShell 5.1 —el que trae
    # Windows de fábrica— escribe un BOM al inicio. Claude Code entonces ve
    # basura antes del `{` y descarta el settings.json ENTERO, sin avisar.
    # Por eso se escribe con WriteAllText y UTF8 sin BOM, que se comporta
    # igual en 5.1 y en 7.
    $utf8SinBOM = New-Object System.Text.UTF8Encoding $false
    [IO.File]::WriteAllText($settingsPath, ($merged | ConvertTo-Json -Depth 20), $utf8SinBOM)
    Ok "settings fusionados (tus valores previos ganan)"
  } catch {
    Mal "tu settings.json no es JSON válido — no lo toco"
    Tenue "Revísalo a mano. Tu respaldo quedó al lado con la fecha."
  }
} else {
  Copy-Item (Join-Path $here 'settings.json') $settingsPath
  Ok "settings.json instalado"
}

# ── 4 · lo que Windows sí necesita aparte ────────────────────
Write-Host ""
$bash = Get-Command bash -ErrorAction SilentlyContinue
if ($bash) { Ok "bash encontrado ($($bash.Source))" }
else {
  Mal "no hay bash en el PATH"
  Tenue "Los hooks son scripts .sh. Instala Git for Windows: winget install Git.Git"
}

if (Get-Command jq -ErrorAction SilentlyContinue) { Ok "jq instalado" }
else {
  Mal "jq NO instalado"
  Tenue "Los hooks y la línea de estado lo necesitan: winget install jqlang.jq"
}

Write-Host ""
Write-Host "  Cierra tus sesiones y abre una nueva: la config se lee al arrancar." -ForegroundColor DarkGray
Write-Host "  Luego corre: " -ForegroundColor DarkGray -NoNewline
Write-Host "bash cc-doctor.sh"
Write-Host ""
