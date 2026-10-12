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

La partida se guarda sola (cada 20 s si hay cambios, al pausar, al completar una sala, al hallar un tesoro y al cerrar). Está en `%APPDATA%\Godot\app_userdata\Thread by Thread\savegame.json`; borrar ese fichero empieza de cero.

## Controles

| Acción | Tecla |
|---|---|
| Mover | W A S D |
| Mirar | Ratón |
| Correr / agacharse | Shift / Ctrl |
| Recoger (manos vacías) | E |
| Colocar en una fila o celda | Clic izquierdo |
| Girar el objeto sostenido | R (mantener) |
| Lanzar | F (toque = suave, mantener = más fuerza) |
| Dejar en suelo o mesa | E, Q o clic derecho |
| Pausa, ajustes y libro de colecciones | Esc |

## Qué probar a mano (checklist)

1. El tutorial de arriba te guía: recoger (E), apuntar a la fila de su color, colocar (clic), lanzar (F).
2. Camina hasta un ovillo. Debe resaltarse y mostrar `[E] Recoger` con su nombre.
3. Pulsa E: vuela hasta tu mano. Mantén R: gira. Apunta a la fila de su color: esfera translúcida **verde**; clic = encaje, sonido, chispas. Otra fila: **roja** y el objeto "niega".
4. **Lanzar** (F): rebota, se aplasta un poco, suelta polvillo, rueda y se para. Cada material rebota distinto (lana, plástico, madera, metal, tela).
5. Completa una fila: arpegio. Completa la sala: melodía, banner, **se abre la puerta** de la siguiente y, un momento después, **aparece una guirnalda de banderines**.
6. **Mira por la ventana de la sala 1** y espera un par de minutos: pasan coches, alguna bicicleta (con timbre), una moto, gente paseando y perros (que a veces ladran). Debe ser tranquilo y no repetitivo. Las salas 2–4 miran a un jardín trasero.
7. **Tesoros**: cada sala esconde dos objetos de lujo (sobre estanterías altas, cajones o pilas de cajas). Se ven destellos dorados muy leves de cerca; el panel de arriba a la izquierda dice cuántos hay. Al cogerlos se enseñan un momento y aparecen en la repisa de la pared sur (sus pastillas llevan el color y el nombre del tesoro). Los de lo alto de una estantería se apuntan con una ayuda de puntería: basta mirar hacia ellos desde 1–3 m. Los ya expuestos se pueden **examinar** con E (vienen a la mano, giran y vuelven).
8. Esc → **Libro de colecciones**: dibujo de cada colección con su barra de progreso, escarapela al completarla y los tesoros (silueta con "?" hasta encontrarlos).
9. Cierra el juego a mitad de una sala y vuelve a abrirlo: todo debe seguir donde lo dejaste.

Dime qué sientes raro: fuerza del lanzamiento, sonidos (nada de audio se ha escuchado aún), frecuencia de la calle, sensibilidad, dificultad de encontrar los tesoros.

## Pruebas automáticas

```powershell
# Prueba de humo sin ventana (código de salida 0 = todo correcto)
powershell -File tests\run_smoke.ps1 -Count 1 -Rooms 4   # 1 objeto por tipo, 4 salas, rápido
powershell -File tests\run_smoke.ps1 -Count 0            # cantidades del juego completo (450 objetos), varios minutos

# Guardado y carga entre dos procesos distintos
powershell -File tests\run_persist.ps1

# Prueba de "mono": acciones aleatorias (andar, coger, colocar, lanzar, pausar, guardar...) con comprobación de invariantes
powershell -File tests\run_fuzz.ps1 -Steps 1200 -Seed 5 -Count 3

# Capturas de render (abren una ventana unos segundos)
powershell -File tests\run_shots.ps1          # salas -> captures\
powershell -File tests\run_street_shots.ps1   # ventana y sucesos de la calle -> captures_street\

# FPS con 450 objetos a 1080p sin VSync
powershell -File tests\run_perf.ps1
```

Las pruebas usan ficheros de configuración y guardado propios (`--test-mode`): no tocan tu partida ni tus ajustes.

## Estructura

```
art/             modelos (glb), texturas (png) y scripts de Blender que los generan
  models/          objetos (items/), mobiliario y calle (street/)
tools/           generadores: make_textures.gd, make_item_data.gd, export_sfx.gd, audacity_*.ps1
data/            ItemData (.tres), catálogos por sala, tesoros (treasures/) y perfiles de material (motion/)
scenes/          main, salas, jugador, estanterías/bandejas/panel, objetos, interfaz
scripts/
  autoload/      Events (bus de señales), GameSettings, SaveGame, InputSetup, AudioManager
  core/          ItemData, ItemCatalog, MotionProfile, PickableItem, StorageUnit y sus hijos
  player/        Player (movimiento), ItemHolder (recoger/sostener/lanzar/colocar/tesoros)
  room/          Shop, RoomController, RoomShell*, Door, Landscape, StreetLife/Actor/Assets, Ambience, ...
  audio/         SfxSynth (síntesis procedural)
  ui/            HUD, tutorial, menú de pausa con libro de colecciones
shaders/         yarn, thread, fabric, ribbon, foliage_sway, terrain, sky
tests/           prueba de humo, guardado, capturas, rendimiento
```

## Añadir contenido (sin tocar código de objetos)

**Un tipo de objeto nuevo** (hilos, botones, telas, cintas, accesorios): añade una fila a la tabla correspondiente de `tools/make_item_data.gd` (id, nombre, color, modelo, tamaño, material, dibujo...) y ejecuta

```
"%LOCALAPPDATA%\Programs\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path . --script res://tools/make_item_data.gd
```

Eso regenera `data/items/*.tres` y los catálogos. Cada fila de estantería/celda/ganchos muestra un tipo, en el orden del catálogo. Los ovillos de la sala 1 son `.tres` a mano: duplica `data/items/yarn_red.tres` y añádelo a `data/catalog_yarn.tres`.

**Un material nuevo** (cómo rebota y suena): duplica un perfil de `data/motion/` (`wool`, `plastic`, `wood`, `metal`, `fabric`), ajusta `bounce`, `friction`, `mass`, `angular_damp`, `squash` e `impact_sound`, y apúntalo desde el `ItemData` en `motion`.

**Un tesoro nuevo**: añade una fila a `_make_treasures()` en `tools/make_item_data.gd` y un sitio en `treasure_spots` de la sala (`scripts/room/room_shell_*.gd`; posición de la base del objeto).

**Un modelo nuevo**: añade la función en el script de Blender correspondiente y regenera (abajo). Las superficies se nombran `main`, `accent`, `metal` o `glass`; el juego decide el material de cada una.

## Regenerar modelos y texturas

```
# Ovillo
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python art/blender/make_yarn_ball.py -- art/models/yarn_ball.glb

# Mobiliario (estantería, mesa, cajón, caja de cartón, planta, bandeja)
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python art/blender/make_furniture.py -- art/models

# Objetos de las familias (botones, carretes, telas, cintas, accesorios)
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python art/blender/make_items.py -- art/models/items

# Calle (coches, personas, perro, bicicleta, moto, casas, farolas, árboles, setos)
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python art/blender/make_street.py -- art/models/street

# Texturas (PNG en art/textures; tras regenerarlas, vuelve a importar el proyecto)
"%LOCALAPPDATA%\Programs\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path . --script res://tools/make_textures.gd
```

Las texturas son PNG normales: puedes retocarlas en Krita o GIMP y Godot las reimporta solo. Las texturas de la calle (asfalto, acera, hierba, tejas) deben importarse con mipmaps y compresión VRAM; las de relieve, como mapa de normales (ya está configurado en sus `.import`).

## Sonidos: Audacity

Hay dos Audacity instalados: la **3.7.9** (`C:\Program Files\Audacity\Audacity.exe`) tiene scripting y la usa el proyecto; la 4.0.1 no tiene scripting.

**Automático (Audacity 3.7.9):**

```
powershell -File tools\audacity_polish.ps1              # pule los sonidos de art/audio/raw (menos los bucles)
powershell -File tools\audacity_polish.ps1 -Only place_1 # solo uno
powershell -File tools\audacity_polish.ps1 -Revert       # vuelve a los sonidos sintetizados
```

Abre Audacity si hace falta, importa cada WAV de `art/audio/raw/`, aplica una cadena de efectos (graves recortados + sala suave; campanas con más cola; pájaros con reverb de distancia), normaliza al nivel original y exporta a `art/audio/sfx/`. No toques Audacity mientras corre. Las cadenas se ajustan en `$Chains` dentro del script. Requiere el módulo `mod-script-pipe` activo en Audacity (ya activado; copia de seguridad de la configuración: `%APPDATA%\audacity\audacity.cfg.bak-tbt`). Nota: el efecto `ClassicFilters` cierra Audacity 3.7.9 si se llama por scripting, por eso no se usa.

**A mano:**

1. Los originales están en `art/audio/raw/`. Si faltan: `godot --headless --path . --script res://tools/export_sfx.gd`.
2. Edítalos en Audacity y exporta como WAV 16 bit, mono, 44100 Hz a `art/audio/sfx/` con **el mismo nombre**.
3. Abre el proyecto en Godot para que lo importe. Borra el fichero de `sfx/` para volver al sintetizado.

El juego usa lo que haya en `sfx/` y, si falta, la síntesis. Se pueden reemplazar solo algunas variantes o añadir más (`pick_4.wav`). Más detalle en `art/audio/LEEME.txt`.

## Capas de física

`world` 1 · `items` 2 · `shelf_aim` 3 · `player` 4 · `settable` 5 · `pick` 6 (volumen de puntería de los objetos). Capas visuales: 1 normal, 2 luz de relleno de la calle.

## Licencias

Todo el contenido es original (código, shaders, modelos de Blender, paisaje y calle procedurales, texturas generadas, sonidos sintetizados). Sin recursos de terceros.
