# THREAD BY THREAD — Progreso

Última actualización: 2026-10-12 · Fase 1 cerrada · **Fase 2 en curso (primera entrega lista para revisar)**

## Fase 1 — Prototipo jugable (cerrada, aprobada por el usuario)

- Sala jugable con **150 ovillos** (10 colores × 15) en montones por el suelo y sobre la mesa.
- Recoger, sostener, girar, colocar con vista previa, rechazo en fila equivocada, dejar en superficies, progreso, banner final.
- Verificado con prueba automática de extremo a extremo con 10 y con 150 objetos (ver "Pruebas").

## Fase 2 — Mejorar la experiencia (primera entrega)

Hecho y verificado:

- **Lanzar objetos (F)**: toque = lanzamiento suave, mantener = más fuerza (anillo de carga alrededor del punto de mira, la mano se recoge hacia atrás al cargar). Rebota, rueda y se detiene.
- **Física solo cuando hace falta**: los objetos en reposo están congelados (coste de un cuerpo estático). Al lanzarlos se activa su simulación y, al quedar quietos, se vuelven a congelar. Medido: 40 ovillos rebotando a la vez a 420 FPS (1080p, sin VSync, RX 7900 XT).
- **Perfiles de material** (`data/motion/*.tres`): lana, plástico, madera, metal y tela. Cada uno define rebote, fricción, masa, rodadura, intensidad del aplastamiento y banco de sonido. Los ovillos usan "lana". Los materiales futuros (botones, carretes, cremalleras...) solo necesitan apuntar a un perfil; no hace falta código.
- **Animación al impactar**: aplastamiento y rebote elástico (muelle amortiguado) a lo largo de la normal del golpe, polvillo suave, sonido según material y fuerza del golpe.
- **Modelo 3D de ovillo hecho en Blender** (`art/blender/make_yarn_ball.py` → `art/models/yarn_ball.glb`): forma orgánica, hebra suelta, ~1.8k triángulos.
- **Shader de lana con relieve** (hebras cruzadas con normal perturbada, fibra, borde esponjoso).
- **Paisaje en la ventana**: prado con 1600 flores, estanque, valla, 30 árboles (algunos en flor) que se mecen con el viento, colinas con bruma, montañas azuladas con nieve y nubes que se desplazan. Sin sombras ni colisiones.
- **Ambiente sonoro**: brisa en bucle por la ventana y pájaros lejanos ocasionales (posicionales).
- **Tutorial de 4 pasos** que avanza solo al recoger, apuntar, colocar y lanzar; no vuelve a salir. Interfaz: anillo de carga, ayuda de teclas en el menú de pausa.
- Cristal y techo con colisión: lo lanzado no escapa de la sala.

Entrega 2 (hecho y verificado con capturas + pruebas):

- **Mobiliario modelado en Blender** (`art/blender/make_furniture.py`): estantería con molduras y bordes biselados (2.4k triángulos), mesa con patas cónicas y faldón, cajón de listones, caja de cartón con solapas, planta con maceta y hojas arqueadas. UVs en metros y veta en la dirección correcta de cada pieza. La colisión sigue siendo de cajas simples.
- **Texturas propias** (`art/textures/`, generadas por `tools/make_textures.gd`, PNG editables en Krita/GIMP): suelo de tablas con veta y nudos, madera clara, cartón ondulado, yeso, friso machihembrado con mapa de normales, alfombra tejida con orla y rombos. Mapas de normales para el relieve.
- **Materiales compartidos** (`MaterialLibrary`): una instancia por material y mapeo triplanar en paredes y suelo.
- **Detalles de personalidad**: tres cuadros enmarcados y un reloj en la pared este.
- **Sonido de colocación melódico**: cada hueco de la fila tiene su nota (escala pentatónica); rellenar una fila de izquierda a derecha toca una escala.

Pendiente de la Fase 2 (siguientes entregas):

- Iluminación: ajuste fino con tus comentarios (hoy sol por la ventana, lámpara y focos; sin iluminación global).
- Sonidos: **pulidos con Audacity 3.7.9** de forma automática (`tools/audacity_polish.ps1`, por mod-script-pipe): 38 WAV en `art/audio/sfx/` (15 bancos), con graves recortados, sala suave y cola de reverb, al mismo nivel que el original (verificado midiendo picos y energía de la cola). El viento no se procesa (es un bucle). **Nadie los ha escuchado todavía**: los efectos son deliberadamente suaves; ajusta `$Chains` o edita a mano en Audacity (`art/audio/LEEME.txt`). `-Revert` vuelve a la síntesis.
- Cuadros, reloj y lámpara siguen siendo geometría sencilla; se pueden modelar más adelante.
- Estantería con otras medidas (filas/anchura distintas) vuelve a usar cajas; el modelo de Blender solo vale para las medidas por defecto.

## Rendimiento medido

Ryzen 7 3700X + RX 7900 XT, 1920×1080, sin VSync, 150 objetos, MSAA 4x, SSAO, glow, niebla volumétrica:

| Escena | FPS | Frame medio |
|---|---|---|
| Vista general | 617 | 1.6 ms |
| Estanterías | 678 | 1.5 ms |
| Ventana y paisaje | 654 | 1.5 ms |
| Suelo lleno de ovillos | 420 | 2.4 ms |
| 40 ovillos rebotando | 419 | 2.4 ms |

Esto es hardware de gama alta: **no demuestra** los 60 FPS en gama media. Hay margen amplio (≈10×), pero falta probar en un equipo más modesto. Hubo un pico puntual de 37 ms en una escena (probablemente primera vez que se dibuja algo); a vigilar.

## Pruebas automáticas

- `tests\run_smoke.ps1` (10 objetos) y `-ItemsPerColor 15` (150): arranque, recoger, rechazo, dejar, lanzar (rebote, aplastamiento, reposo), ordenar todo, sacar y recolocar, pausa. **Pasan los dos.**
- `tests\run_shots.ps1`: capturas de render. `tests\run_perf.ps1`: FPS.

## Problemas conocidos

- No he podido **escuchar** nada: volumen, tono y ritmo de los sonidos (rebotes, viento, pájaros) son una primera versión que debes juzgar tú.
- El *feel* del lanzamiento (fuerza, arco, rodadura) y de la sensibilidad solo se valida a mano.
- Un ovillo lanzado dentro de una estantería queda sobre la balda como objeto suelto (se puede recoger); no cuenta como colocado.
- Pico puntual de frame (37 ms) visto una vez en las medidas.
- Los trozos de tela y botones del suelo son decoración (MultiMesh), no recogibles.
- Al salir, Godot avisa de instancias de audio sin liberar: es el autoload de sonido, inofensivo.
- Sin guardado de partida todavía (Fase 3). Solo configuración y "tutorial visto".

## Próximas tareas

1. Tu prueba manual de esta entrega y tu opinión (lanzar, paisaje, sonidos, tutorial).
2. Resto de la Fase 2 según tus comentarios.
3. Con tu OK explícito: Fase 3 (progresión, nuevas familias de objetos, segunda sala, guardado).

## Cómo probar

Ver `README.md`.
