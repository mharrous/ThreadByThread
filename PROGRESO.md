# THREAD BY THREAD — Progreso

Última actualización: 2026-10-12 · Fase 1 (prototipo jugable) · **pendiente de tu aprobación para pasar a los 150 objetos**

## Lo que ya funciona (verificado)

Verificado con la prueba automática `tests/smoke_test.tscn` (sin ventana, con eventos de entrada reales)
y con capturas de render `tests/screenshot_runner.tscn`:

- Proyecto Godot 4.7.2 que arranca sin errores ni avisos de script.
- Sala de 6 × 5 m: suelo de tablas, paredes con friso, ventana, vigas, lámpara, mesa, cajas, planta, alfombra, cartel.
- Luz de sol cálida por la ventana (sombras suaves de los travesaños), luz ambiente cálida, lámpara y focos sobre estanterías.
- Controlador en primera persona: WASD, ratón, Shift correr, Ctrl agacharse (con comprobación de techo), cámara interpolada, balanceo suave, pasos.
- Dos estanterías de 5 filas × 15 huecos. Cada fila tiene un color asignado (franja de color + nombre + marcadores circulares).
- 10 ovillos de 10 colores repartidos por suelo y mesa, sin solaparse.
- **Recoger** (E): el ovillo vuela en arco hasta la mano; se resalta al apuntarlo; se puede coger también desde la estantería.
- **Sostener y girar** (R): sigue a la cámara con suavizado; se acerca solo si hay una pared delante.
- **Colocar** (clic izquierdo): vista previa translúcida (verde = correcto, rojo = fila equivocada), vuelo suave, encaje con aplastamiento elástico, onda y chispas.
- **Rechazo** en fila equivocada o llena: el ovillo "niega" con un temblor, sonido suave y aviso.
- **Dejar** en suelo o mesa (E, Q o clic derecho), con comprobación de espacio libre.
- Contador, porcentaje, barra y objetivo; indicador de interacción; punto de mira que reacciona.
- Colección completa → arpegio + pulso de la fila; sala completa → melodía, ola de color y salto en cadena, banner.
- Menú de pausa (Esc): sensibilidad, volumen general/efectos, pantalla completa, VSync, MSAA. Se guarda en `user://settings.cfg`.
- Sonidos 100 % originales sintetizados por código (`scripts/audio/sfx_synth.gd`), con variantes y variación de tono.
- Sistema modular: nuevos ovillos = nuevo `.tres` en `data/items/` + una línea en `data/catalog_yarn.tres`.

Rendimiento medido (solo orientativo): 165 FPS, 267 draw calls, 618 objetos a 1600×900
en Ryzen 7 3700X + RX 7900 XT con VSync. **No representa un equipo de gama media**; falta medir con 150 objetos.

## Lo que falta

- Probar a mano con ratón y teclado reales (lo automático no cubre el *feel*; ver "Cómo probar").
- Escalar a 150 objetos (`items_per_color = 15` en `scenes/rooms/room_yarn.tscn`) y medir FPS. **Esperando tu opinión.**
- Fase 2: modelos de Blender, texturas, sonidos editados, tutorial, interfaz pulida.
- Fases 3–5: progresión, guardado de partida, segunda sala, colecciones, demo, ejecutable.

## Problemas conocidos

- Los ovillos usan una esfera con shader procedural: es provisional y se verá "de prototipo" de cerca.
- El balance de volumen y el carácter de los sonidos solo se puede juzgar escuchándolos.
- Los trozos de tela y botones del suelo son decoración (MultiMesh), no se pueden recoger.
- Con el ratón liberado (pausa) un clic en la ventana lo recaptura; el clic no cuenta como colocar.
- Al salir, Godot avisa de 6 instancias de audio sin liberar: es el autoload de sonido, inofensivo.
- Sin guardado de partida todavía (Fase 3). Solo se guarda la configuración.
- `tests/debug_probe.*` es una sonda de depuración; se puede borrar.

## Próximas tareas

1. Tu prueba manual y opinión sobre el *feel* (ritmo del vuelo, sensación del encaje, volumen, sensibilidad).
2. Con tu OK: subir a 150 objetos, medir FPS, ajustar dispersión y colisiones.
3. Con tu OK: Fase 2.

## Cómo probar

Ver `README.md`.
