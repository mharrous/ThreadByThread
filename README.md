# THREAD BY THREAD

Simulador 3D cozy de organización de una mercería. Godot 4.7, GDScript, PC Windows.
Recoger → identificar → clasificar → colocar → recibir recompensa.

## Abrir y jugar

1. Abre Godot 4.7.2 (`%LOCALAPPDATA%\Programs\Godot\Godot_v4.7.2-stable_win64.exe`).
2. *Importar* → selecciona `project.godot` de esta carpeta → *Importar y editar*.
3. Pulsa **F5** (la escena principal es `scenes/main.tscn`).

Primera vez: Godot importa el proyecto unos segundos.

## Controles

| Acción | Tecla |
|---|---|
| Mover | W A S D |
| Mirar | Ratón |
| Correr / agacharse | Shift / Ctrl |
| Recoger (manos vacías) | E |
| Colocar en una fila | Clic izquierdo |
| Girar el objeto sostenido | R (mantener) |
| Dejar en suelo o mesa | E, Q o clic derecho |
| Pausa y ajustes | Esc |

## Qué probar a mano (checklist)

1. Camina hasta un ovillo del suelo. Debe resaltarse y mostrar `[E] Recoger` con su nombre.
2. Pulsa E: el ovillo debe volar suave hasta tu mano (abajo a la derecha). Mantén R: gira.
3. Camina hacia una estantería con el ovillo. Apunta a la fila de su color: aparece una esfera translúcida **verde** y `Clic · Colocar aquí`.
4. Clic izquierdo: encaje suave, sonido, chispas y onda; el contador sube.
5. Apunta a una fila de otro color: esfera **roja**; al hacer clic el ovillo "niega" y no se coloca.
6. Pulsa E o clic derecho mirando al suelo/mesa: lo deja ahí. Puedes volver a cogerlo.
7. Coge un ovillo ya colocado en la estantería: el contador baja.
8. Completa una fila de color (con 10 objetos no se da; con 150 sí): arpegio y pulso. Coloca los 10: melodía y banner.
9. Esc: menú de pausa. Prueba sensibilidad, volumen y pantalla completa.

Dime qué sientes raro: velocidad del vuelo, aplastamiento al encajar, volumen/tono de los sonidos, sensibilidad del ratón, distancia de la mano.

## Pruebas automáticas

```powershell
# Prueba de humo sin ventana (código de salida 0 = todo correcto)
powershell -File tests\run_smoke.ps1

# Capturas de render en captures\ (abre una ventana unos segundos)
powershell -File tests\run_shots.ps1
```

## Estructura

```
data/            ItemData (.tres) y catálogo por sala
scenes/          main, sala, jugador, estantería, ovillo, interfaz
scripts/
  autoload/      Events (bus de señales), GameSettings, InputSetup, AudioManager
  core/          ItemData, ItemCatalog, PickableItem, ShelfUnit
  player/        Player (movimiento), ItemHolder (recoger/sostener/colocar)
  room/          RoomController (progreso), RoomShell (geometría), RoomLighting, PlacementFx
  audio/         SfxSynth (síntesis procedural)
  ui/            HUD, menú de pausa
shaders/         yarn.gdshader
tests/           prueba de humo y capturas
```

## Añadir un tipo de ovillo

1. Duplica `data/items/yarn_red.tres`, cambia `id`, `sort_key`, `sort_label`, `color`, `detail`.
2. Añádelo a `data/catalog_yarn.tres`.
3. Cada fila de estantería muestra un tipo, en el orden del catálogo (de arriba abajo, izquierda y luego derecha).

## Capas de física

`world` 1 · `items` 2 · `shelf_aim` 3 · `player` 4 · `settable` 5 (superficies donde se puede dejar un objeto).

## Licencias

Todo el contenido es original (código, shader, modelos procedurales, sonidos sintetizados). Sin recursos de terceros.
