<h1 align="center">Tune Kit</h1>

<p align="center">
  <strong>Deja de usar Claude Code como venía en la caja.</strong><br>
  Semáforo de contexto, modo conciso, cuatro paredes que no se negocian<br>
  y un script que audita tu instalación y te dice qué te falta.
</p>

<p align="center">
  <img alt="Licencia MIT" src="https://img.shields.io/badge/licencia-MIT-1f6feb?style=flat-square">
  <img alt="Claude Code 2.1.237+" src="https://img.shields.io/badge/Claude%20Code-%E2%89%A5%202.1.237-ec8c44?style=flat-square">
  <img alt="94 tests" src="https://img.shields.io/badge/tests-94%20passing-2ea043?style=flat-square">
  <img alt="macOS · Linux · Windows" src="https://img.shields.io/badge/macOS%20%C2%B7%20Linux%20%C2%B7%20Windows-30363d?style=flat-square">
  <img alt="Español" src="https://img.shields.io/badge/idioma-espa%C3%B1ol-30363d?style=flat-square">
</p>

---

```console
$ bash cc-doctor.sh

  cc-doctor · Tune Kit

3 · Los settings
  ✓ outputStyle: Concise
  ✓ línea de estado activa
  ✓ remoto conectado al arrancar

4 · Hooks y permisos
  ✕ cero hooks
     Todo lo que le pides en el CLAUDE.md es una sugerencia.
  ✕ nada bloquea la lectura de tus .env

5 · Lo que se come tu ventana
  ▲ transcripts: 433M, sin política de limpieza
     Define "cleanupPeriodDays": 30.

  Veredicto
  10 bien  3 por revisar  2 pendientes
  Empieza por las ✕ — ahí es donde estás dejando tiempo, dinero o seguridad en la mesa.
```

## Instalación

**macOS y Linux**

```bash
git clone https://github.com/Carlos-Dominguez-faber/claude-code-tune-kit.git tune-kit
cd tune-kit
bash instalar.sh      # respalda lo tuyo antes de tocar nada
bash cc-doctor.sh     # y te dice cómo quedaste
```

**Windows** — en PowerShell:

```powershell
git clone https://github.com/Carlos-Dominguez-faber/claude-code-tune-kit.git tune-kit
cd tune-kit
powershell -ExecutionPolicy Bypass -File .\instalar.ps1
bash cc-doctor.sh     # el doctor corre en Git Bash
```

> [!NOTE]
> En Windows necesitas **Git for Windows** (`winget install Git.Git`) y **jq**
> (`winget install jqlang.jq`). Claude Code ya usa Git Bash por default en Windows,
> así que lo más probable es que Git ya lo tengas. Los detalles, en
> [Windows](#windows).

El instalador **fusiona, no sobrescribe**. Respalda tu `settings.json` con fecha y hora, y en el
merge tus valores previos siempre ganan: si ya tenías tu propio `outputStyle` o tu allowlist, se
quedan como estaban.

> [!IMPORTANT]
> Claude Code lee la configuración **al arrancar**. Cierra tus sesiones abiertas y abre una nueva,
> o no vas a ver ningún cambio.

<details>
<summary>Instalación manual, si prefieres no correr el script</summary>

```bash
mkdir -p ~/.claude/hooks ~/.claude/output-styles
cp hooks/*.sh          ~/.claude/hooks/
cp statusline.sh       ~/.claude/
cp output-styles/*.md  ~/.claude/output-styles/
chmod +x ~/.claude/hooks/*.sh ~/.claude/statusline.sh
```

Después copia a mano los bloques de `settings.json` que quieras dentro de tu
`~/.claude/settings.json`. **No lo sobrescribas entero** si ya tenías cosas ahí.
</details>

## Qué trae

| Pieza | Qué hace |
| :--- | :--- |
| [`settings.json`](settings.json) | Modo conciso, semáforo, remoto, permisos y los cuatro hooks, ya cableados. |
| [`statusline.sh`](statusline.sh) | Modelo, contexto quemado, carpeta, rama, límites de 5 h y 7 d, y el costo de la sesión. |
| [`hooks/freno-de-mano.sh`](hooks/freno-de-mano.sh) | Cancela comandos destructivos antes de que se ejecuten. |
| [`hooks/blindaje-env.sh`](hooks/blindaje-env.sh) | Nada escribe encima de un archivo de credenciales. |
| [`hooks/formatter.sh`](hooks/formatter.sh) | Prettier, ruff, gofmt o rustfmt corren solos tras cada edición. |
| [`hooks/aviso.sh`](hooks/aviso.sh) | Te avisa cuando termina — pero solo si el turno fue largo. |
| [`output-styles/sin-humo.md`](output-styles/sin-humo.md) | Sin halagos, comandos sin placeholders, el error exacto completo. |
| [`ccglm.zsh`](ccglm.zsh) | Levanta Claude Code con GLM sin tocar tu configuración global. |
| [`ccglm.ps1`](ccglm.ps1) | Lo mismo, para PowerShell. Restaura las variables aunque canceles con Ctrl-C. |
| [`cc-doctor.sh`](cc-doctor.sh) | Audita tu instalación y te dice qué te falta. No cambia nada. |
| [`instalar.ps1`](instalar.ps1) | Instalador de Windows. Fusiona sin jq y escribe los `.sh` en LF. |
| [`.gitattributes`](.gitattributes) | Fuerza LF. Sin esto el kit no arranca en Windows — ver abajo. |

## La idea

Todo el kit está montado sobre una sola distinción:

| | Dónde vive | Qué tan fuerte es |
| :--- | :--- | :--- |
| **Una sugerencia** | `CLAUDE.md` | La lee, la considera, y a veces se le olvida. |
| **Una regla** | `settings.json` | Cambia el arnés. No depende de que el modelo se acuerde. |
| **Una pared** | `hooks/` | Código tuyo que corre antes de la acción y la cancela. No se negocia. |

Cuando algo **no puede** pasar —borrar la base, subir un secreto, forzar un push— no lo pidas
por escrito. Ponle una pared.

## El semáforo

```text
🧠 Opus 5 | 🟡 ctx 63% | 📁 forge-cloud ⎇ main* | ⏳ 5h:12% 7d:41% | $4.73 | ✂️ Concise
```

La línea no sirve de nada si no sabes qué hacer con el número. Esa es la regla:

| | Contexto | Qué haces |
| :---: | :--- | :--- |
| 🟢 | menos de 50 % | Sigue. No hagas nada. |
| 🟡 | 50 – 80 % | Cierra el hilo actual. No abras frente nuevo. |
| 🔴 | más de 80 % | Commit + `PROGRESS.md` + `/clear`. **Nunca `/compact` a ciegas.** |

Marca `(z.ai)` cuando no estás corriendo en Claude, y `/1M` cuando traes la ventana extendida —
porque un 40 % en 1M no significa lo mismo que un 40 % en 200k.

## Los cuatro hooks

| Hook | Evento | Matcher | Qué corta |
| :--- | :--- | :--- | :--- |
| Freno de mano | `PreToolUse` | `Bash` | Borrados de sistema, `push --force`, `--no-verify`, SQL destructivo, `curl \| sh`, `chmod 777` |
| Blindaje | `PreToolUse` | `Edit\|Write\|NotebookEdit` | Escrituras sobre `.env`, llaves privadas, service accounts |
| Formatter | `PostToolUse` | `Edit\|Write` | — (formatea, no bloquea) |
| El avisito | `UserPromptSubmit` + `Stop` | — | — (te avisa, no bloquea) |

Los dos primeros salen con **exit 2**: la llamada se cancela y el motivo le llega a Claude por
stderr, así que se corrige solo en vez de quedarse trabado.

### Qué bloquea y qué no

Un hook de seguridad que se evade con comillas da **falsa** seguridad. Uno que bloquea
`rm -rf build/` se desinstala el primer día. El freno de mano tokeniza el comando en vez de
buscar patrones en la cadena, así que aguanta las dos cosas:

| Muere | Pasa |
| :--- | :--- |
| `rm -rf /` · `rm -r -f /` · `rm -rfv /usr/local` | `rm -rf build dist` |
| `rm -rf "/usr/local"` · `rm -rf '/etc'` | `rm -rf ./node_modules` |
| `rm --recursive --force /usr` · `rm -fR /System` | `rm -rf /tmp/cache-build` |
| `cd /tmp && rm -rf /` | `rm -rf ~/Developer/proyecto/dist` |
| `rm -rf ~` · `rm -rf $HOME` · `rm -rf *` | `rm -rf /Users/ana/proyecto/.next` |
| `git push --force` · `git push -f` | `git push --force-with-lease` |
| `git commit --no-verify` | `echo "no uses --no-verify" >> CONTRIBUTING.md` |
| `psql -c "DROP TABLE users"` | `grep -rn "DROP TABLE" migrations/` |
| `curl -sL x.sh \| sh` | `curl -sL api.com/x -o data.json` |
| `echo FOO=1 > .env` | `echo FOO=1 >> .env` |

Los 70 casos están en [`test/test.sh`](test/test.sh):

```bash
bash test/test.sh
```

### Si te encierras afuera

```bash
claude --settings '{"disableAllHooks": true}'
```

O `"disableAllHooks": true` en tu `settings.json`. Apaga hooks y línea de estado de un golpe.

## GLM sin secuestrar tu configuración

El error que comete todo el mundo es meter el bloque `env` en `~/.claude/settings.json`. Eso
manda **todas** tus sesiones al modelo alterno, incluidas las del cliente en producción que
abriste el martes sin acordarte. [`ccglm.zsh`](ccglm.zsh) lo resuelve con una función de shell:
escribes `claude` y es Claude, escribes `ccglm` y es GLM.

> [!WARNING]
> El endpoint para Claude Code es `https://api.z.ai/api/anthropic`. Si apuntas al de otras
> herramientas (`/api/coding/paas/v4`) no obtienes un error de conexión: obtienes
> `1113 Insufficient Balance` y te empieza a cobrar por token en vez de consumir tu plan.
> Y la variable es `ANTHROPIC_BASE_URL` — varios tutoriales dicen `ANTHROPIC_API_BASE`,
> que Claude Code no lee.

## Windows

El kit corre en Windows nativo, sin WSL. Claude Code ya usa **Git Bash** por default ahí
(cae a PowerShell solo si Git Bash no está instalado), así que los hooks en `.sh` son el
camino natural — no hay que traducir nada a PowerShell.

Pero hay **dos trampas que matan el kit en Windows y son invisibles desde una Mac**. Las dos
ya están resueltas aquí; se documentan porque te van a morder en cualquier otro repo de hooks:

**1 · CRLF mata los cuatro hooks.** Git for Windows trae `core.autocrlf=true` de fábrica: al
clonar convierte los `.sh` a CRLF, el shebang queda `#!/usr/bin/env bash\r` y bash sale a
buscar un binario llamado «bash\r». Todo muere con un error que no dice nada. Lo previene el
[`.gitattributes`](.gitattributes) del repo, y `instalar.ps1` reescribe en LF por si ya lo
tenías clonado de antes.

**2 · Un `.sh` pelón en `settings.json` no se ejecuta.** Windows lo resuelve por asociación de
archivo y abre el **selector de aplicación** o el editor
([#21847](https://github.com/anthropics/claude-code/issues/21847),
[#24097](https://github.com/anthropics/claude-code/issues/24097)). Por eso todos los comandos
del kit llevan `bash` adelante:

```jsonc
"command": "bash ~/.claude/hooks/freno-de-mano.sh"   // ✓
"command": "~/.claude/hooks/freno-de-mano.sh"        // ✕ abre el selector de aplicación
```

Y un tercero que es de seguridad: en Windows las rutas llegan con backslash
(`C:\Users\ana\.ssh\id_rsa`), y `basename` solo parte por `/`. Sin normalizar, los patrones de
coincidencia exacta del blindaje nunca casaban: **`id_rsa`, `credentials` y `.npmrc` quedaban
desprotegidos con solo estar en Windows**. Los hooks normalizan la ruta antes de comparar, y la
suite trae 24 casos de Windows que lo fijan.

`cc-doctor.sh` revisa los tres cuando corre en Windows, más a cuál `bash` estás resolviendo —
desde `2.1.81` el instalador nativo llegó a resolver al bash de WSL, que no ve tus rutas de
Windows ([#37634](https://github.com/anthropics/claude-code/issues/37634)).

## Requisitos

| | |
| :--- | :--- |
| **Claude Code** | `2.1.237` o superior — el estilo `Concise` no existe antes. `claude update` |
| **jq** | Los hooks y la línea de estado lo necesitan. `brew install jq` · `sudo apt install jq` · `winget install jqlang.jq` |
| **Git Bash** | Solo Windows: `winget install Git.Git`. Claude Code ya lo usa por default ahí. |
| **Sistema** | macOS, Linux o Windows. La voz del avisito usa `say` (macOS), `notify-send` (Linux) o SAPI vía PowerShell (Windows, sin instalar nada). |

## Desinstalar

```bash
rm -f ~/.claude/hooks/{freno-de-mano,blindaje-env,formatter,aviso}.sh
rm -f ~/.claude/statusline.sh ~/.claude/output-styles/sin-humo.md
```

En PowerShell:

```powershell
Remove-Item "$env:USERPROFILE\.claude\hooks\{freno-de-mano,blindaje-env,formatter,aviso}.sh"
Remove-Item "$env:USERPROFILE\.claude\statusline.sh","$env:USERPROFILE\.claude\output-styles\sin-humo.md"
```

Y restaura tu configuración anterior desde el respaldo que dejó el instalador:

```bash
ls ~/.claude/settings.json.antes-del-tune-kit.*          # macOS · Linux
```

```powershell
Get-ChildItem "$env:USERPROFILE\.claude\settings.json.antes-del-tune-kit.*"
```

## Notas

- `/output-style` **ya no existe**: deprecado en `2.1.73`, eliminado en `2.1.91`. Hoy el estilo se
  cambia con `/config` o editando la clave `outputStyle`.
- El estilo de salida vive en el system prompt, así que aplica **después** de `/clear` o de abrir
  una sesión nueva.
- `autoCompactWindow` acepta un conteo de **tokens** de 100 000 a 1 000 000 — no una fracción.
  El kit no lo define a propósito: el default de tu modelo es mejor que un número inventado.
  Si quieres compactar antes, usa `/autocompact 150k`.
- Nunca escribas una API key dentro de `settings.json`. Ese archivo se respalda, se comparte y
  se sube a repos. Usa variables de entorno.

## Licencia

MIT — ver [LICENSE](LICENSE).

---

<p align="center">
  Del taller de <a href="https://www.skool.com/imperio"><strong>Imperio Agéntico</strong></a> ·
  Carlos Domínguez
</p>
