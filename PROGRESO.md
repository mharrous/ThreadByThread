# THREAD BY THREAD — Progreso

Última actualización: 2026-10-23 · Fases 1–3 cerradas · **Fase 4 en curso: la mercería es una sola sala**

## Resumen de fases

| Fase | Estado |
|---|---|
| 1 · Prototipo jugable (sala de ovillos) | Cerrada y aprobada |
| 2 · Mejorar la experiencia (física, sonido, paisaje, mobiliario) | Cerrada (pendiente solo tu opinión sobre sonidos y *feel*) |
| 3 · Progresión (familias, estanterías, salas, colecciones, desbloqueos, guardado) | Cerrada |
| 4 · Demo comercial (15–25 min, ejecutable de Windows) | **En curso**: sala única hecha (ver abajo) |
| 5 · Pruebas y expansión | No empezada |

## Fase 4 — Respuesta de racha, pista, música por capas, título y volúmenes (2026-10-23, tercera parte)

1. **Respuesta de la racha**:
   - El objeto colocado da un pulso de escala (solo visual, en su nodo `Squash`) que crece con la racha, hasta +25 % a ×10.
   - La ráfaga de chispas y la onda crecen con la racha. Desde ×3 las chispas se mezclan con dorado.
   - El texto "Racha ×N" del HUD tiembla (seno amortiguado de 0,3 s, más fuerte cuanto más larga la racha) y da un destello blanco.
2. **Pista del siguiente objeto** (`scripts/room/next_item_hint.gd`):
   - Al colocar, el objeto suelto más cercano del mismo tipo respira con un brillo cálido flojo.
   - Si lo apuntas, manda el resaltado normal.
   - Se retira si coges cualquier cosa, si lo has visto y apartas la vista más de 80°, o si pasan 12 s sin mirarlo.
3. **Música por capas** (`tools/make_music.gd`): tres pistas sincronizadas de 53 s.
   - **base**: bajo y acorde dispersos. Suena siempre.
   - **mid**: ecos del piano, colchón cálido y shaker. Entra al 33 % ordenado.
   - **full**: melodía y contracanto. Entra al 66 %.
   - Fundidos de 4 s. Si el progreso baja, la capa vuelve a salir.
4. **Pantalla de título**:
   - Fundido desde negro y fila de dibujos (ovillo, carrete, botón).
   - Jugar, o Continuar + Nueva partida si hay partida guardada, y Salir.
   - Nueva partida pide un segundo clic. Fundido al entrar.
5. **Repaso de volúmenes**:
   - La calle queda al menos 10 dB por debajo de colocar (0 dB): timbre de bici −12 dB, ladrido −13 dB, bocina −14 dB, motores entre −17 y −20 dB, todo por el bus exterior (−3 dB y filtro).
   - El destello de racha arranca en −9 dB y sube hasta −3 dB: siempre por encima del ambiente (pájaros −15 dB, viento −20 dB).
   - **Campanilla de la puerta** nueva, pulida en Audacity: tres golpes claros a 0 dB al entrar desde el título y cuando la tienda pasa a ABIERTO.

Pruebas:

- Humo con 215 objetos: pasa. Ahora comprueba también que las 3 capas de música suenan, que la campanilla existe y que la pista cae en el siguiente objeto del mismo tipo.
- Guardado entre procesos: pasa.
- Prueba de "mono" (semilla 7, 800 pasos): sin violaciones.
- Ejecutable re-exportado.

Sin comprobar a mano: cómo se oye y se ve todo esto. Nada de este audio se ha escuchado aún.

## Fase 4 — Mejoras de ambiente, arte, sonido y demo (2026-10-23, segunda parte)

**Luz**:
- Luz rebotada en tiempo real (SDFGI).
- Sonda de reflejos que cubre la sala.
- Motas de polvo en la luz de la ventana.
- Ajuste "Iluminación avanzada" para equipos modestos: apaga SDFGI, SSAO, niebla y brillo.

**Arte (Blender, `art/blender/make_props.py`)**:
- Lámpara colgante esmaltada, que sustituye al cono.
- Maniquí de costura (rincón suroeste).
- Máquina de coser antigua (mesa de corte).
- Caja registradora de latón (mesa de lanas).
- Puerta de la calle con campanilla (pared este). Su cartel dice CERRADO y pasa a ABIERTO al terminar.
- Mesas con patas torneadas y cajón.
- Las estanterías y el panel se separan 6 cm de la pared: antes el friso y la moldura las atravesaban.

**Sonido**:
- Coches, furgonetas, motos y bocinas, 10 dB más bajos.
- Racha musical: cada colocación seguida (menos de 6 s entre una y otra) sube una nota de la pentatónica.
- Desde la tercera colocación seguida se suma un destello de campanillas que crece con la racha. El HUD muestra "Racha ×N".
- Tic suave al apuntar a un hueco correcto.
- Arpegio en el 25, 50 y 75 % de cada sección.
- Música original en bucle (`tools/make_music.gd`) con su propio volumen.

**Demo**:
- Pantalla de título: Jugar o Continuar, Nueva partida y Salir.
- 215 objetos (`spawn_scale` = 0.45), pensados para 15–25 min. La duración no está medida jugando.

**Rendimiento con 215 objetos** (1080p, sin VSync, todo activado):

| Vista | FPS |
|---|---|
| Peor caso | 434 |
| Entrada | 460 |

Hubo un pico aislado de 49 ms al girar (probablemente compilación de un shader).

Con "Iluminación avanzada" apagada (`tests
un_perf.ps1 -Low`): 497 FPS en el peor caso y 581 en la entrada. Es poca diferencia en este equipo de gama alta; donde se notará es en GPU modestas. Falta probarlo en una.

## Fase 4 — Una sola sala (2026-10-23)

Las cuatro salas con puertas se sustituyen por **una sola sala de 12 × 9 m**. Los 450 objetos empiezan
tirados por el suelo y las mesas, con todas las familias mezcladas en 14 montones; las estanterías de las
paredes están vacías.

**Distribución** (`scenes/rooms/shop_floor.tscn`, mobiliario en `scripts/room/room_shell_shop.gd`):

- Norte: lanas (2 estanterías) y carretes (2 estanterías), con el cartel principal en medio.
- Este: sastrería (panel de ganchos y estantería).
- Sur: telas (2 bastidores de rollos) y cintas, ventana al jardín y repisa con 8 huecos para los tesoros.
- Oeste: ventana a la calle y el mueble de telas dobladas.
- Centro: mesas con las bandejas de botones y de piezas de sastrería, mesa de lanas y mesa de corte.

**Secciones** (`ShopSection`): cada familia es un nodo con su catálogo, sus tesoros y sus muebles como hijos.
Pone su cartel en la pared y un foco sobre cada mueble de pared. Sustituye a las salas.

**Progresión sin puertas**: todo está disponible desde el principio. La sala cambia según avanzas:

- Sección completa: melodía, aviso, sus focos se calientan, su cartel dice "¡sección completa!" y aparece su guirnalda.
- Mercería completa (fin de la demo): banner, guirnaldas de pared a pared, cartel de ¡ABIERTO! y lámparas más luminosas.

**Orientarse en una sala grande**: al coger un objeto, su fila destino da un pulso de luz y el HUD dice a
qué sección va y cuánto le falta ("Va en: Lanas 12 / 150"). El tutorial habla de buscar los carteles.

**Rendimiento con 450 objetos visibles a la vez**:

- Los objetos sueltos siguen congelados (coste de cuerpo estático).
- El reparto inicial usa una rejilla espacial: cada comprobación de hueco libre mira solo las celdas vecinas.
- Las piezas pequeñas (radio < 3,5 cm) no proyectan sombra y dejan de dibujarse a 11 m, con fundido.
- Hay 4 lámparas; solo 2 dan sombra, de paraboloide doble (2 pasadas en vez de 6).
- Los focos de las secciones no dan sombra.
- No se usa MultiMesh para los objetos: cada uno necesita resaltado, recogida, aplastamiento y guardado propios.

**Guardado v2**: `{"room": ...}` con los objetos, los tesoros y las secciones completadas. Los guardados de
cuatro salas (v1) se ignoran y se empieza de cero.

**Borrado**: `room_yarn/buttons/fabrics/store.tscn`, `room_shell_*.gd` de cada sala y `door.gd`.

**Arreglado de paso**: la ventana sur ya no tiene travesaño a la altura de los ojos.

**Atajo del menú de pausa**: "Completar esta sección" ordena la sección del objeto que llevas en la mano.
Con las manos vacías, ordena la de los muebles más cercanos.

## Fase 3 — Qué funcionaba (verificado con pruebas automáticas salvo lo marcado)

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

## Revisión de errores (segunda vuelta de la Fase 3)

Hecha con tres métodos: una **prueba de "mono"** (`tests\fuzz_test.gd`: acciones aleatorias durante miles de pasos con comprobación de invariantes), la **prueba de humo con cantidades completas** y una **revisión de código independiente** (un segundo agente leyó todos los scripts; cada hallazgo se comprobó antes de arreglarlo).

Errores reales encontrados y arreglados:

- **El contador del HUD no se actualizaba al colocar objetos** (solo al cambiar de sala): "Organizados 0 / 150" aunque ya hubieras colocado diez, y la barra y "Sala completada" tampoco. Las pruebas solo miraban el estado interno; ahora la prueba de humo comprueba también el texto del HUD.
- **Tesoros sobre estanterías sin acción de recoger**: el canto de la estantería tapaba el rayo de puntería. Ahora hay una ayuda de puntería por cono (7°, hasta 3,6 m) para los tesoros, sin tener en cuenta las estanterías.
- Objeto lanzado con la mano pegada a una esquina podía salir por la pared del edificio (la prueba de "mono" lo vio una vez; no he conseguido reproducirlo a voluntad). Ahora sale desde la cámara y, si aun así se saliera, vuelve al suelo de la sala (antes hacía falta caer a −3 m).
- Guardar con un objeto en la mano o en el aire lo dejaba **flotando** al cargar; ahora se guarda apoyado en lo que haya debajo (sin contar estanterías).
- En un montón de telas dobladas, coger la pieza de abajo dejaba las demás flotando; ahora siempre se coge la de arriba.
- Guardado: una sala completada pero guardada justo antes de abrirse la puerta quedaba con la siguiente cerrada para siempre; ahora al cargar una sala completada siempre se abre la siguiente. Un guardado que no encaja con la disposición actual de una estantería ya no rompe la carga.
- El objeto en la mano **desaparecía** al alejarse dos salas de la suya (las salas lejanas se ocultan); ahora la sala de origen sigue visible mientras lo llevas.
- Al salir desde el menú o cerrar la ventana no se guardaban los ajustes; ya se guardan.
- Carga del lanzamiento: soltar F durante la pausa o pulsar E con F apretada dejaba el arco del HUD lleno o congelado.
- Los saltos de celebración de una fila podían mover un objeto que ya habías cogido; los temporizadores de "sala completada" seguían corriendo durante la pausa; el tutorial podía atascarse en "apunta" si apuntabas antes de tiempo; un objeto lanzado podía quedarse dormido en pleno vuelo.

Resultado de la prueba de "mono" tras los arreglos: 7 semillas × 1200 pasos sin violaciones (salvo la vez que se vio la fuga por la pared, antes del arreglo).

No arreglado (decisión de diseño o sin importancia): el jingle de colección se repite si repones la última pieza de una colección ya completa; costuras de 0,5–6 m sin suelo lejano en el terreno (invisibles por la bruma); si algún día sustituyes los bucles de motor por WAV editados, habría que marcarlos como bucle.

## Rendimiento medido

Ryzen 7 3700X + RX 7900 XT, 1920×1080, sin VSync, MSAA 4x, SSAO, glow, niebla volumétrica, calle y paisaje.

**Sala única, 450 objetos (2026-10-23)** (`tests\run_perf.ps1`):

| Escena | FPS | Frame medio | Draw calls |
|---|---|---|---|
| Entrada (toda la sala) | 334 | 3.0 ms | 648 |
| Centro hacia el norte | 405 | 2.5 ms | 384 |
| Esquina sureste mirando a toda la sala (peor caso) | 301 | 3.3 ms | 861 |
| Suelo con montones | 423 | 2.4 ms | 423 |
| Ventana a la calle | 604 | 1.7 ms | 94 |
| 40 objetos rebotando a la vez | 229 | 4.4 ms | 1157 |

Antes de usar sombras de paraboloide doble en las lámparas, el peor caso daba 262 FPS.

El caso de 40 objetos rebotando no se da jugando: se lanza un objeto cada vez. Tuvo un pico aislado de 74 ms
(probablemente compilación de un shader al primer rebote). Hay que vigilarlo en gama media.

Antes, con 4 salas (solo se dibujaban la sala del jugador y las contiguas): 380 FPS en el peor caso.

Es hardware de gama alta: **no demuestra** los 60 FPS en gama media. Hay margen (≈5× en el peor caso),
pero falta probar en un equipo más modesto.

## Pruebas automáticas

```powershell
powershell -File tests\run_smoke.ps1 -Count 1            # humo de extremo a extremo (1 objeto por tipo)
powershell -File tests\run_smoke.ps1 -Count 0            # cantidades del juego completo (450 objetos)
powershell -File tests\run_persist.ps1                   # guardado y carga entre dos procesos
powershell -File tests\run_perf.ps1                      # FPS a 1080p sin VSync
powershell -File tests\run_shots.ps1                     # capturas de la sala
powershell -File tests\run_street_shots.ps1              # capturas de la ventana con cada suceso de la calle
```

La prueba de humo recoge, rechaza, deja, lanza (también contra paredes y ventanas) y ordena todos los objetos, sección a sección. Comprueba también:

- el HUD (a qué sección va lo que llevas y el progreso total);
- el premio de cada sección y el final (guirnaldas y cartel de ABIERTO);
- los 8 tesoros (apuntar, coger, exponer, contar);
- cada tipo de suceso de la calle (avanza, ruedas o piernas giran, lleva sonido);
- la pausa y el guardado.

La prueba de guardado entre procesos completa además una sección y comprueba que su premio sigue tras reiniciar.

Resultados del 2026-10-23 (sala única):

- `-Count 1`: **pasa**.
- `-Count 0` (450 objetos, 149 comprobaciones): **pasa**. Una primera pasada falló en el harness (cogió un objeto vecino en un montón denso y un lanzamiento de prueba acabó bajo una mesa); el harness ahora coloca el vecino y reintenta, y devuelve al suelo lo que rueda bajo un mueble.
- `run_persist.ps1`: **pasa**.
- `run_fuzz.ps1 -Steps 1200 -Count 3` con las semillas 5, 11 y 23: **sin violaciones**.

La prueba con las cantidades completas encontró un fallo real que la de 1 objeto por tipo no veía: en la sala de telas, si el reparto aleatorio no encontraba hueco, el punto de reserva caía debajo de la mesa central y el objeto quedaba inalcanzable (sala imposible de completar). Corregido en `RoomController._find_spot` (tres pasadas con separación decreciente y un último recurso fuera de los muebles).

## Cosas que no puedo comprobar yo (necesitan tus ojos y oídos)

- **Nada de audio se ha escuchado.** Volumen, tono y frecuencia de bocinas, timbres, ladridos, motores y del resto de sonidos son una primera versión. Prueba: abre el juego, ve a la ventana oeste y espera un par de minutos.
- **Duración de la demo**: no medida. 450 objetos en una sola sala probablemente pasan de 25 min. Si sobra tiempo, se baja `spawn_count` por tipo (solo datos).
- Si encontrar la sección de cada objeto cuesta: hoy hay carteles, un pulso de luz en la fila destino y el texto del HUD. Desde 2026-10-24 hay una flecha en el borde de la pantalla cuando la estantería no está a la vista; no hay minimapa.
- El *feel* del lanzamiento, de la sensibilidad y de la distancia de la mano solo se valida a mano.
- Si la calle te parece demasiado tranquila o demasiado animada: `StreetLife.min_gap` / `max_gap` (hoy 14 y 40 s) en `scripts/room/street_life.gd`.
- Estética de personas, coches y árboles: es estilo "low-poly" cálido hecho con Blender; si quieres más realismo hay que decidir cuánto presupuesto de arte dedicarle.

## Ejecutable final de la demo (2026-10-24)

- `build/ThreadByThread.exe`, versión 0.4.0: icono propio (`icon.ico`, generado desde `icon.svg` con `tools/make_icon.gd`), nombre, descripción y copyright en las propiedades del archivo. Sin ventana de consola. El icono también sale en la barra de título (`config/windows_native_icon`).
- `export_presets.cfg` está en `.gitignore`: los cambios del preset (icono, versión, `modify_resources`) solo viven en este equipo.
- Precarga de shaders: bajo el velo negro de la pantalla de título la cámara da una vuelta completa en 16 frames, así lo que aún no se ha visto se compila antes de jugar. Godot además guarda la caché en disco, así que el tirón de 49 ms solo podía darse en la primera partida. No se puede medir de forma fiable en este equipo (la caché ya está caliente).

- Flecha de orientación (`scripts/ui/target_pointer.gd`): con un objeto en la mano, si su estantería no está en pantalla (o queda a la espalda), una flecha del color de la sección sale en el borde tras 1,2 s y se apaga al mirarla. Prueba automática en la prueba de humo. Sin verificar a ojo: tamaño y color pueden necesitar ajuste.

## Problemas conocidos

- Lanzar a la estantería: si el objeto se queda dentro de la estantería de su tipo, entra solo en el hueco libre más cercano ("¡Canasta!", cuenta para la racha). En la de otro tipo, o con la fila llena, sigue quedando suelto sobre la balda.
- Los trozos de tela y botones del suelo son decoración (MultiMesh), no recogibles.
- Al salir, Godot avisa de instancias de audio sin liberar: son los reproductores del autoload de sonido, inofensivo.
- Pulidos con Audacity 55 sonidos (incluidos el destello de racha y el tic de acierto). Los bucles y la calle no se pulen: ya pasan por el bus "Outdoor". La música lleva una reverb suave en su bus.
- Los tesoros sobre estanterías altas solo se pueden apuntar desde algo más de un metro; no es un fallo, pero conviene que lo notes al jugar.

## Próximas tareas

1. Tu prueba manual de la sala única: recorrido, orientación entre secciones, ritmo y duración real.
2. Ajustar cantidades para 15–25 min si hace falta.
3. Resto de la Fase 4: prueba en gama media (lo demás está hecho).
4. Ideas pendientes del documento inicial, sin construir (el prompt las marca como propuestas): pedidos opcionales de materiales, secretos extra, mejoras de organización, más decoración desbloqueable, niveles 5 y 6.

## Cómo probar

Ver `README.md`.
