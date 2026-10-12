# THREAD BY THREAD

Simulador 3D cozy de organización de una mercería. Godot 4.7, GDScript, PC Windows.
Recoger → identificar → clasificar → colocar → recibir recompensa.

## Abrir y jugar

1. Abre Godot 4.7.2 (`%LOCALAPPDATA%\Programs\Godot\Godot_v4.7.2-stable_win64.exe`).
2. *Importar* → selecciona `project.godot` de esta carpeta → *Importar y editar*.
3. Pulsa **F5** (la escena principal es `scenes/main.tscn`).

O directamente, sin abrir el editor:

```
"%LOCALAPPDATA%\Programs\Godot\Godot_v4.7.2-stable_win64.exe" --path "C:\Users\Usuario\Documents\ThreadByThread"
```

## Controles

| Acción | Tecla |
|---|---|
| Mover | W A S D |
| Mirar | Ratón |
| Correr / agacharse | Shift / Ctrl |
| Recoger (manos vacías) | E |
| Colocar en una fila | Clic izquierdo |
| Girar el objeto sostenido | R (mantener) |
| Lanzar | F (toque = suave, mantener = más fuerza) |
| Dejar en suelo o mesa | E, Q o clic derecho |
| Pausa y ajustes | Esc |

## Qué probar a mano (checklist)

1. El tutorial de arriba te guía: recoger (E), apuntar a la fila de su color, colocar (clic), lanzar (F).
2. Camina hasta un ovillo. Debe resaltarse y mostrar `[E] Recoger` con su nombre.
3. Pulsa E: el ovillo vuela hasta tu mano. Mantén R: gira.
4. Apunta a la fila de su color: esfera translúcida **verde**. Clic: encaje suave, sonido, chispas, onda.
5. Apunta a una fila de otro color: esfera **roja**; al hacer clic el ovillo "niega".
6. **Lanzar**: sosteniendo un ovillo, pulsa F rápido (toque suave) o mantenla (se llena un anillo) y suelta. Debe rebotar, aplastarse un poco, soltar polvillo, rodar y pararse. Puedes volver a cogerlo.
7. Mira por la ventana: prado, estanque, valla, árboles que se mecen, montañas y nubes que se mueven. Se oye brisa y algún pájaro.
8. Completa una fila de color: arpegio y pulso de la fila. Completa todo: melodía, ola de color y banner.
9. Esc: menú de pausa (sensibilidad, volumen, pantalla completa, VSync, MSAA, lista de teclas).

Dime qué sientes raro: fuerza y arco del lanzamiento, rebote, sonidos, sensibilidad, distancia de la mano, paisaje.

## Pruebas automáticas

```powershell
# Prueba de humo sin ventana (código de salida 0 = todo correcto)
powershell -File tests\run_smoke.ps1                    # 10 objetos, rápido
powershell -File tests\run_smoke.ps1 -ItemsPerColor 15  # 150 objetos, unos minutos

# Capturas de render en captures\ (abre una ventana unos segundos)
powershell -File tests\run_shots.ps1

# FPS con 150 objetos a 1080p sin VSync
powershell -File tests\run_perf.ps1
```

Las pruebas usan `settings_test.cfg` (`--test-mode`): no tocan tu configuración ni tu "tutorial visto".

## Estructura

```
art/             modelos (glb), texturas (png) y scripts de Blender que los generan
tools/           make_textures.gd (genera las texturas)
data/            ItemData (.tres), catálogo por sala y perfiles de material (motion/)
scenes/          main, sala, jugador, estantería, ovillo, interfaz
scripts/
  autoload/      Events (bus de señales), GameSettings, InputSetup, AudioManager
  core/          ItemData, ItemCatalog, MotionProfile, PickableItem, ShelfUnit
  player/        Player (movimiento), ItemHolder (recoger/sostener/lanzar/colocar)
  room/          RoomController, RoomShell, RoomLighting, Landscape, Ambience, PlacementFx
  audio/         SfxSynth (síntesis procedural)
  ui/            HUD, tutorial, menú de pausa
shaders/         yarn.gdshader, foliage_sway.gdshader
tests/           prueba de humo, capturas, rendimiento
```

## Añadir un tipo de ovillo

1. Duplica `data/items/yarn_red.tres`, cambia `id`, `sort_key`, `sort_label`, `color`, `detail`.
2. Añádelo a `data/catalog_yarn.tres`.
3. Cada fila de estantería muestra un tipo, en el orden del catálogo (de arriba abajo, izquierda y luego derecha).

## Añadir un material nuevo (cómo rebota y suena)

Los materiales viven en `data/motion/`: `wool`, `plastic`, `wood`, `metal`, `fabric`.

1. Duplica el `.tres` más parecido y ajusta `bounce`, `friction`, `mass`, `angular_damp` (cuánto rueda), `squash` (aplastamiento) y `impact_sound`.
2. En el `ItemData` del objeto, asigna ese perfil a `motion`.
3. Para un sonido de impacto nuevo: añade la función en `scripts/audio/sfx_synth.gd` y su banco en `audio_manager.gd`.

## Regenerar modelos y texturas

```
# Ovillo
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python art/blender/make_yarn_ball.py -- art/models/yarn_ball.glb

# Mobiliario (estantería, mesa, cajón, caja de cartón, planta)
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python art/blender/make_furniture.py -- art/models

# Texturas (PNG en art/textures; tras regenerarlas, vuelve a importar el proyecto)
"%LOCALAPPDATA%\Programs\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path . --script res://tools/make_textures.gd
```

Las texturas son PNG normales: puedes retocarlas en Krita o GIMP y Godot las reimporta solo.

## Sonidos: Audacity

Hay dos Audacity instalados: la **3.7.9** (`C:\Program Files\Audacity\Audacity.exe`) tiene scripting y la usa el proyecto; la 4.0.1 no tiene scripting.

**Automático (Audacity 3.7.9):**

```
powershell -File tools\audacity_polish.ps1              # pule los 38 sonidos (menos el viento, que es un bucle)
powershell -File tools\audacity_polish.ps1 -Only place_1 # solo uno
powershell -File tools\audacity_polish.ps1 -Revert       # vuelve a los sonidos sintetizados
```

Abre Audacity si hace falta, importa cada WAV de `art/audio/raw/`, aplica una cadena de efectos (graves recortados + sala suave; campanas con más cola; pájaros con reverb de distancia), normaliza al nivel original y exporta a `art/audio/sfx/`. No toques Audacity mientras corre. Las cadenas se ajustan en `$Chains` dentro del script.
Requiere el módulo `mod-script-pipe` activo en Audacity (ya activado; copia de seguridad de la configuración: `%APPDATA%\audacity\audacity.cfg.bak-tbt`).
Nota: el efecto `ClassicFilters` cierra Audacity 3.7.9 si se llama por scripting, por eso no se usa.

**A mano:**

1. Los originales están en `art/audio/raw/` (39 WAV). Si faltan: `godot --headless --path . --script res://tools/export_sfx.gd`.
2. Edítalos en Audacity y exporta como WAV 16 bit, mono, 44100 Hz a `art/audio/sfx/` con **el mismo nombre**.
3. Abre el proyecto en Godot para que lo importe. Borra el fichero de `sfx/` para volver al sintetizado.

El juego usa lo que haya en `sfx/` y, si falta, la síntesis. Se pueden reemplazar solo algunas variantes o añadir más (`pick_4.wav`). Más detalle en `art/audio/LEEME.txt`.

## Capas de física

`world` 1 · `items` 2 · `shelf_aim` 3 · `player` 4 · `settable` 5 · `pick` 6 (volumen de puntería de los objetos).

## Licencias

Todo el contenido es original (código, shaders, modelo de Blender, paisaje procedural, sonidos sintetizados). Sin recursos de terceros.
