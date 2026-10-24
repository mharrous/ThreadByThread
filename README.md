# THREAD BY THREAD

Simulador 3D cozy de organización de una mercería. Godot 4.7, GDScript, PC Windows.
Recoger → identificar → clasificar → colocar → recibir recompensa.

Una sola sala grande (12 × 9 m). Unos 215 objetos (demo de 15–25 min) están tirados por el suelo y las mesas, mezclados, y las
estanterías de las paredes están vacías. Cada pared es una sección con su cartel: lanas y carretes/botones
(norte), sastrería (este), telas y cintas (sur). La ventana oeste da a la calle.

## Abrir y jugar

1. Abre Godot 4.7.2 (`%LOCALAPPDATA%\Programs\Godot\Godot_v4.7.2-stable_win64.exe`).
2. *Importar* → selecciona `project.godot` de esta carpeta → *Importar y editar*.
3. Pulsa **F5** (la escena principal es `scenes/main.tscn`).

O directamente, sin abrir el editor:

```
"%LOCALAPPDATA%\Programs\Godot\Godot_v4.7.2-stable_win64.exe" --path "C:\Users\Usuario\Documents\ThreadByThread"
```

La partida se guarda sola (cada 20 s si hay cambios, al pausar, al completar una sección, al hallar un tesoro y al cerrar). Está en `%APPDATA%\Godot\app_userdata\Thread by Thread\savegame.json`; borrar ese fichero empieza de cero.

## Ejecutable de Windows

Doble clic en `build\ThreadByThread.exe` (un solo fichero, sin instalar nada). Se genera con:

```powershell
& "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path . --export-release "Windows Desktop" build/ThreadByThread.exe
```

Usa los mismos guardados y ajustes que el juego abierto desde el editor. (`export_presets.cfg` y `build/` no se suben a Git.)

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

1. El tutorial de arriba te guía: recoger (E), buscar la sección por su cartel y apuntar a la fila, colocar (clic), lanzar (F).
2. Camina hasta cualquier objeto del suelo. Debe resaltarse y mostrar `[E] Recoger` con su nombre.
3. Pulsa E: vuela hasta tu mano, su fila destino da un **pulso de luz** y el panel de arriba dice **a qué sección va** ("Va en: Lanas 12 / 150"). Mantén R: gira. Apunta a su fila: esfera translúcida **verde**; clic = encaje, sonido, chispas. Otra fila: **roja** y el objeto "niega".
4. **Lanzar** (F): rebota, se aplasta un poco, suelta polvillo, rueda y se para. Cada material rebota distinto (lana, plástico, madera, metal, tela).
5. Completa una colección: arpegio. Completa una **sección**: melodía, aviso, sus focos se calientan, su cartel dice "¡sección completa!" y aparece una guirnalda sobre su pared.
6. Completa **toda la mercería**: banner de fin de la demo, guirnaldas de pared a pared, cartel de **¡ABIERTO!** bajo el principal y lámparas algo más luminosas.
7. **Mira por la ventana oeste** y espera un par de minutos: pasan coches, alguna bicicleta (con timbre), una moto, gente paseando y perros (que a veces ladran). Debe ser tranquilo y no repetitivo. La ventana sur mira a un jardín trasero.
8. **Tesoros**: ocho objetos de lujo, dos por sección (encima de estanterías altas, del cajón y de las pilas de cajas). Se ven destellos dorados muy leves de cerca; el panel de arriba a la izquierda dice cuántos hay. Al cogerlos se enseñan un momento y aparecen en la repisa de la pared sur (sus pastillas llevan el color y el nombre del tesoro). Los de lo alto de una estantería se apuntan con una ayuda de puntería: basta mirar hacia ellos desde 1–3 m. Los ya expuestos se pueden **examinar** con E (vienen a la mano, giran y vuelven).
9. Esc → **Libro de colecciones**: un capítulo por sección con su barra de progreso, el dibujo de cada colección, escarapela al completarla y los tesoros (silueta con "?" hasta encontrarlos). **Completar esta sección** es un atajo de pruebas: ordena de golpe la sección del objeto que llevas o la de los muebles más cercanos.
10. **Barrer**: la escoba y el recogedor están en la pared sur, junto a la papelera (bajo la ventana). E para cogerlos, mantén el clic mirando al suelo para barrer, y clic apuntando a la papelera para vaciar el recogedor (le caben 30 papelitos). E los devuelve. La tienda abre con todo colocado **y** el suelo barrido.
11. **El gato** anda por toda la tienda: juega con su ovillo, se lava, se echa la siesta. Apúntale con las manos vacías y pulsa E para acariciarlo.
12. Cierra el juego a medias y vuelve a abrirlo: todo debe seguir donde lo dejaste. Los guardados de la versión de cuatro salas no se cargan: se empieza de cero.

Dime qué sientes raro: fuerza del lanzamiento, sonidos (nada de audio se ha escuchado aún), frecuencia de la calle, sensibilidad, dificultad de encontrar los tesoros.

## Pruebas automáticas

```powershell
# Prueba de humo sin ventana (código de salida 0 = todo correcto)
powershell -File tests\run_smoke.ps1 -Count 1               # 1 objeto por tipo, rápido
powershell -File tests\run_smoke.ps1 -Count 1 -Sections 1   # ordena a mano solo la 1.ª sección; el resto, con el atajo
powershell -File tests\run_smoke.ps1 -Count 0            # cantidades del juego completo (215 objetos), varios minutos

# Guardado y carga entre dos procesos distintos
powershell -File tests\run_persist.ps1

# Prueba de "mono": acciones aleatorias (andar, coger, colocar, lanzar, pausar, guardar...) con comprobación de invariantes
powershell -File tests\run_fuzz.ps1 -Steps 1200 -Seed 5 -Count 3

# Capturas de render (abren una ventana unos segundos)
powershell -File tests\run_shots.ps1          # vistas de la sala -> captures\
powershell -File tests\run_street_shots.ps1   # ventana y sucesos de la calle -> captures_street\

# FPS con todos los objetos a 1080p sin VSync
powershell -File tests\run_perf.ps1
```

Las pruebas usan ficheros de configuración y guardado propios (`--test-mode`): no tocan tu partida ni tus ajustes.

## Estructura

```
art/             modelos (glb), texturas (png) y scripts de Blender que los generan
  models/          objetos (items/), mobiliario y calle (street/)
tools/           generadores: make_textures.gd, make_item_data.gd, export_sfx.gd, audacity_*.ps1
data/            ItemData (.tres), catálogos por sección, tesoros (treasures/) y perfiles de material (motion/)
scenes/          main, la sala (rooms/shop_floor.tscn), jugador, estanterías/bandejas/panel, objetos, interfaz
scripts/
  autoload/      Events (bus de señales), GameSettings, SaveGame, InputSetup, AudioManager
  core/          ItemData, ItemCatalog, MotionProfile, PickableItem, StorageUnit y sus hijos
  player/        Player (movimiento), ItemHolder (recoger/sostener/lanzar/colocar/tesoros)
  room/          Shop, RoomController, ShopSection, RoomShell(Shop), Bunting, Landscape, StreetLife/Actor/Assets, ...
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

Eso regenera `data/items/*.tres` y los catálogos. Cada fila de estantería/celda/ganchos muestra un tipo, en el orden del catálogo de su sección. Los ovillos son `.tres` a mano: duplica `data/items/yarn_red.tres` y añádelo a `data/catalog_yarn.tres`.

**Un material nuevo** (cómo rebota y suena): duplica un perfil de `data/motion/` (`wool`, `plastic`, `wood`, `metal`, `fabric`), ajusta `bounce`, `friction`, `mass`, `angular_damp`, `squash` e `impact_sound`, y apúntalo desde el `ItemData` en `motion`.

**Un tesoro nuevo**: añade una fila a `_make_treasures()` en `tools/make_item_data.gd` un sitio en `treasure_spots` (`scripts/room/room_shell_shop.gd`; base del objeto, en el orden de las secciones) y sube `display_count` del nodo `Shell` en `scenes/rooms/shop_floor.tscn`.

**Una sección nueva** (o mover una): en `scenes/rooms/shop_floor.tscn`, bajo `Sections`, un nodo con `shop_section.gd` (catálogo, tesoros, cartel, guirnalda) y sus muebles como hijos. Los muebles de pared reciben foco solos y el suelo de delante queda libre al repartir objetos.

**Un modelo nuevo**: añade la función en el script de Blender correspondiente y regenera (abajo). Las superficies se nombran `main`, `accent`, `metal` o `glass`; el juego decide el material de cada una.

## Regenerar modelos y texturas

```
# Ovillo
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python art/blender/make_yarn_ball.py -- art/models/yarn_ball.glb

# Atrezo (lámpara colgante, maniquí, máquina de coser, caja registradora, puerta de la calle)
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python art/blender/make_props.py -- art/models

# Mobiliario (estantería, mesa con patas torneadas, cajón, caja de cartón, planta, bandeja)
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python art/blender/make_furniture.py -- art/models

# Objetos de las familias (botones, carretes, telas, cintas, accesorios)
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python art/blender/make_items.py -- art/models/items

# Calle (coches, personas, perro, bicicleta, moto, casas, farolas, árboles, setos)
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python art/blender/make_street.py -- art/models/street

# Texturas (PNG en art/textures; tras regenerarlas, vuelve a importar el proyecto)
"%LOCALAPPDATA%\Programs\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path . --script res://tools/make_textures.gd
```

Las texturas son PNG normales: puedes retocarlas en Krita o GIMP y Godot las reimporta solo. Las texturas de la calle (asfalto, acera, hierba, tejas) deben importarse con mipmaps y compresión VRAM; las de relieve, como mapa de normales (ya está configurado en sus `.import`).

## Música

La música son tres bucles originales de 53 s en `art/audio/music/`: `shop_base` (siempre), `shop_mid` (entra al 33 % ordenado) y `shop_full` (al 66 %). Se componen y sintetizan con

```
"%LOCALAPPDATA%\Programs\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path . --script res://tools/make_music.gd
```

El bucle sale del `.import` (`edit/loop_mode=2` en cada uno; al regenerarlos, compruébalo). Tiene su propio bus ("Music") y volumen en los ajustes.

## Duración de la demo

`spawn_scale` del nodo `ShopFloor` (`scenes/rooms/shop_floor.tscn`) escala el `spawn_count` de cada tipo (mínimo 2). Con 0.45 salen 215 objetos; con 1.0, los 450 completos.

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
