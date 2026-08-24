# Tune Kit

Deja de usar Claude Code como venía en la caja.

Ocho piezas, todas pegables en menos de diez minutos. Del taller de
**Imperio Agéntico** — clase *Tunea tu Claude Code*, 26 de agosto de 2026.

---

## Instalación en 3 comandos

```bash
git clone https://github.com/Carlos-Dominguez-faber/claude-code-tune-kit.git tune-kit && cd tune-kit
bash instalar.sh          # respalda lo tuyo antes de tocar nada
bash cc-doctor.sh         # te dice cómo quedaste
```

¿Prefieres a mano? Es esto:

```bash
mkdir -p ~/.claude/hooks ~/.claude/output-styles
cp hooks/*.sh          ~/.claude/hooks/
cp statusline.sh       ~/.claude/
cp output-styles/*.md  ~/.claude/output-styles/
chmod +x ~/.claude/hooks/*.sh ~/.claude/statusline.sh
```

Y luego copias a mano los bloques de `settings.json` que quieras dentro de tu
`~/.claude/settings.json`. **No lo sobrescribas entero** si ya tenías cosas ahí.

> Claude Code lee la configuración **al arrancar**. Cierra tus sesiones y abre una nueva.

---

## Qué trae

| Pieza | Qué hace |
|---|---|
| `settings.json` | La configuración completa: modo conciso, semáforo, remoto, permisos y los cuatro hooks cableados. |
| `statusline.sh` | El semáforo de contexto: modelo, ventana quemada, carpeta, rama y tu consumo de 5 h y 7 días. |
| `hooks/freno-de-mano.sh` | Mata comandos destructivos antes de que se ejecuten. |
| `hooks/blindaje-env.sh` | Nada escribe encima de un archivo de credenciales. |
| `hooks/formatter.sh` | Corre prettier / ruff / gofmt solo, después de cada edición. |
| `hooks/aviso.sh` | Te avisa por voz cuando la sesión termina. |
| `output-styles/sin-humo.md` | Estilo propio: cero halagos, comandos sin placeholders, el error exacto siempre. |
| `ccglm.zsh` | Levanta Claude Code con GLM **sin** tocar tu configuración global. |
| `cc-doctor.sh` | Audita tu instalación y te dice qué te falta. |

---

## La regla del semáforo

La línea de estado no sirve de nada si no sabes qué hacer con ella:

| | Contexto | Qué haces |
|---|---|---|
| 🟢 | menos de 50 % | Sigue. No hagas nada. |
| 🟡 | 50 – 80 % | Cierra el hilo actual. No abras frente nuevo. |
| 🔴 | más de 80 % | Commit + PROGRESS.md + `/clear`. **Nunca `/compact` a ciegas.** |

---

## Los tres niveles

Todo el kit está montado sobre una sola idea:

> Una instrucción en tu `CLAUDE.md` es una **sugerencia**.
> Un setting es una **regla**.
> Un hook es una **pared**.

Cuando algo *no puede* pasar —borrar la base, subir un secreto, forzar un push—
no lo pidas por escrito. Ponle una pared.

---

## Salidas de emergencia

Te encerraste afuera con tus propios hooks:

```bash
claude --settings '{"disableAllHooks": true}'
```

O en tu `settings.json`: `"disableAllHooks": true`. Apaga hooks y línea de estado
de un golpe.

---

## Avisos

- Los hooks piden **jq**: `brew install jq`.
- El modo `Concise` pide **claude 2.1.237 o superior**: `claude update`.
- `/output-style` **ya no existe** (eliminado en 2.1.91). Hoy se cambia con `/config`
  o editando la clave `outputStyle`.
- El estilo de salida vive en el system prompt: aplica hasta que hagas `/clear`
  o abras sesión nueva.
- Nunca escribas una API key dentro de `settings.json`. Ese archivo se respalda,
  se comparte y se sube a repos. Usa variables de entorno.

---

Carlos Domínguez · [Imperio Agéntico](https://www.skool.com/imperio)
