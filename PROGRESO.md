# THREAD BY THREAD — Progreso

Última actualización: 2026-10-12 · Fases 1 y 2 cerradas · **Fase 3 (progresión) lista para revisar**

## Resumen de fases

| Fase | Estado |
|---|---|
| 1 · Prototipo jugable (sala de ovillos) | Cerrada y aprobada |
| 2 · Mejorar la experiencia (física, sonido, paisaje, mobiliario) | Cerrada (pendiente solo tu opinión sobre sonidos y *feel*) |
| 3 · Progresión (familias, estanterías, salas, colecciones, desbloqueos, guardado) | **Lista para revisar**: espera tu aprobación |
| 4 · Demo comercial (15–25 min, ejecutable de Windows) | No empezada |
| 5 · Pruebas y expansión | No empezada |

## Fase 3 — Qué funciona (verificado con pruebas automáticas salvo lo marcado)

**Familias de objetos** (todas por datos: un `.tres` por tipo, sin código por objeto):

- Lanas: 10 colores de ovillo (sala 1, 150 objetos).
- Hilos: 10 carretes (algodón en 8 colores y 2 metálicos: dorado y plateado), con shader de hebras.
- Botones: 10 tipos (madera ×2, plástico ×2, metal ×2, cristal ×2, nácar, vintage), con varias formas (planos, con borde, de pie).
- Telas: 10 rollos (lisas y estampadas: lino, vichy, rayas, flores, lunares, tartán, vaquero, terciopelo, pana, encaje) y 5 telas dobladas, con shader de tejido y dibujo.
- Cintas: carretes (satén, vichy, encaje, dorada) y lazos.
- Accesorios: cremalleras, tijeras (grandes y de bordar), cinta métrica, reglas, dedales (latón y plata), estuches de agujas, acericos, tizas, cajas de costura, latas, patrones, bastidores y planchas.
- Datos en `data/items/` (generados por `tools/make_item_data.gd`: añadir una variante es añadir una fila a la tabla).

**Contenedores** (`StorageUnit`): estantería (`ShelfUnit`), bandeja de celdas (`TrayUnit`) y panel de ganchos (`PegBoard`). Cada fila/celda acepta un tipo; el resto se rechaza con "negación".

**Cuatro salas conectadas** (`Shop`, `RoomController`, `RoomShell*`): ovillos, botones y carretes, telas y cintas, almacén de sastrería. 450 objetos en total. La puerta de cada sala (corredera) se abre al ordenar la anterior. Las salas lejanas se ocultan por rendimiento.

**Colecciones**: cada tipo de objeto es una colección; al completar una suena una melodía breve y al completar la sala, otra más larga con banner. El **libro de colecciones** (Esc → *Libro de colecciones*) lista por sala cada colección con su progreso y los tesoros.

**Tesoros escondidos** (opcionales, 2 por sala, 8 en total): versiones de lujo y mayor tamaño de objetos de cada sala, escondidos sobre estanterías, cajones o pilas de cajas. Destellan muy poco y solo de cerca. Al cogerlos se enseñan un instante delante de la cámara y pasan a una repisa de la pared sur de la sala (las pastillas de fieltro vacías son la pista de que hay algo que buscar). No cuentan para ordenar la sala.

**Decoración desbloqueable**: al ordenar una sala por completo aparece una guirnalda de banderines entre las paredes.

**Guardado y carga** (`SaveGame`, `Shop`): JSON, escritura atómica con copia `.bak`, autoguardado cada 20 s si hay cambios, al pausar, al completar sala, al hallar un tesoro y al cerrar. Guarda qué objetos están colocados (y en qué hueco), dónde están los sueltos, salas desbloqueadas, tesoros hallados y sala activa. Un guardado que no encaja con el contenido actual de la sala se ignora con un aviso. Verificado **entre procesos** (`tests\run_persist.ps1`).

**Vista de la ventana** (sala 1 mira a una calle de barrio; salas 2–4 miran a un jardín trasero con montañas):

- Calle con calzada, aceras, bordillos, paso de cebra, farolas, setos y casas de dos y tres plantas modeladas en Blender; árboles de tres tipos, prado con hierba texturizada, estanque y montañas con bruma. Cielo con nubes que se desplazan y sol.
- **Vida en la calle** (`StreetLife`): un suceso cada 14–40 s como máximo (hasta 3 a la vez, nunca el mismo tipo dos veces seguidas): coche, berlina, furgoneta, bicicleta (a veces con timbre), moto, peatón, peatón con perro (a veces ladra). Las ruedas giran, las personas caminan y los perros trotan. Sonido por un bus "Outdoor" filtrado: ronroneo de motor con efecto Doppler, alguna bocina suave, timbre y ladridos ocasionales.
- Aparte del sol que entra por la ventana, los objetos de la calle reciben una luz de relleno sin sombras (si no, las fachadas que miran a la ventana quedarían a contraluz).

**Sonidos nuevos** (sintetizados): colocación por material (clic, madera, tela, metal), apertura de puerta, tesoro, decoración y todo el sonido de la calle.

## Rendimiento medido

Ryzen 7 3700X + RX 7900 XT, 1920×1080, sin VSync, 450 objetos en 4 salas, MSAA 4x, SSAO, glow, niebla volumétrica, calle y paisaje:

| Escena | FPS | Frame medio | Draw calls |
|---|---|---|---|
| Sala 1 · entrada | 767 | 1.3 ms | 261 |
| Sala 3 · suelo | 588 | 1.7 ms | 617 |
| Todas las salas visibles (peor caso) | 380 | 2.6 ms | 995 |
| 40 objetos rebotando | 441 | 2.3 ms | 560 |

Es hardware de gama alta: **no demuestra** los 60 FPS en gama media. Hay margen amplio (≈6×), pero falta probar en un equipo más modesto.

## Pruebas automáticas

```powershell
powershell -File tests\run_smoke.ps1 -Count 1 -Rooms 4   # humo de extremo a extremo (1 objeto por tipo)
powershell -File tests\run_smoke.ps1 -Count 0            # cantidades del juego completo (450 objetos)
powershell -File tests\run_persist.ps1                   # guardado y carga entre dos procesos
powershell -File tests\run_perf.ps1                      # FPS a 1080p sin VSync
powershell -File tests\run_shots.ps1                     # capturas de las salas
powershell -File tests\run_street_shots.ps1              # capturas de la ventana con cada suceso de la calle
```

La prueba de humo recoge, rechaza, deja, lanza, ordena todos los objetos de cada sala, comprueba puertas, tesoros (apuntar, coger, exponer, contar), guirnalda, cada tipo de suceso de la calle (avanza, ruedas/piernas giran, lleva sonido), pausa y guardado.

Resultados de hoy: `-Count 1 -Rooms 4` **pasa** (todas las comprobaciones); `run_persist.ps1` **pasa**. `-Count 0` (450 objetos) se ha lanzado tras los últimos cambios; el resultado está en el apartado siguiente.

## Cosas que no puedo comprobar yo (necesitan tus ojos y oídos)

- **Nada de audio se ha escuchado.** Volumen, tono y frecuencia de bocinas, timbres, ladridos, motores y del resto de sonidos son una primera versión. Prueba: abre el juego, ve a la ventana de la sala 1 y espera un par de minutos.
- El *feel* del lanzamiento, de la sensibilidad y de la distancia de la mano solo se valida a mano.
- Si la calle te parece demasiado tranquila o demasiado animada: `StreetLife.min_gap` / `max_gap` (hoy 14 y 40 s) en `scripts/room/street_life.gd`.
- Estética de personas, coches y árboles: es estilo "low-poly" cálido hecho con Blender; si quieres más realismo hay que decidir cuánto presupuesto de arte dedicarle.

## Problemas conocidos

- Un ovillo lanzado dentro de una estantería queda sobre la balda como objeto suelto (se puede recoger); no cuenta como colocado.
- Los trozos de tela y botones del suelo son decoración (MultiMesh), no recogibles.
- Al salir, Godot avisa de instancias de audio sin liberar: son los reproductores del autoload de sonido, inofensivo.
- Las ventanas sur de las salas 2–4 tienen un travesaño a la altura de los ojos (en la sala 1 se quitó para no tapar la calle).
- Los sonidos de la calle y los nuevos de colocación/tesoro/puerta aún no están pulidos con Audacity (la cadena actual de `tools/audacity_polish.ps1` pule los 38 sonidos anteriores).
- Los tesoros sobre estanterías altas solo se pueden apuntar desde algo más de un metro; no es un fallo, pero conviene que lo notes al jugar.

## Próximas tareas

1. Tu prueba manual de la Fase 3 y tu opinión.
2. Con tu OK explícito: **Fase 4** (demo de 15–25 min con variedad suficiente + ejecutable de Windows).
3. Ideas pendientes del documento inicial, sin construir (el prompt las marca como propuestas): pedidos opcionales de materiales, secretos extra, mejoras de organización, más decoración desbloqueable, niveles 5 y 6.

## Cómo probar

Ver `README.md`.
