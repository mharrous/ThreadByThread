# THREAD BY THREAD — Progreso

Última actualización: 2026-10-24 · Fases 1–3 cerradas · **Fase 4 en curso: final de la demo hecho (barrer, cajas, apertura, gato vivo, interfaz cozy, inglés y tráiler)**

## Resumen de fases

| Fase | Estado |
|---|---|
| 1 · Prototipo jugable (sala de ovillos) | Cerrada y aprobada |
| 2 · Mejorar la experiencia (física, sonido, paisaje, mobiliario) | Cerrada (pendiente solo tu opinión sobre sonidos y *feel*) |
| 3 · Progresión (familias, estanterías, salas, colecciones, desbloqueos, guardado) | Cerrada |
| 4 · Demo comercial (15–25 min, ejecutable de Windows) | **En curso**: sala única hecha (ver abajo) |
| 5 · Pruebas y expansión | No empezada |

## Fase 4 — Trece arreglos: cajas, física, escoba, té, tesoros, carteles, sastrería y calle (2026-10-24, quinta parte)

### Cajas de cartón de los rincones (recogibles)

- Las pilas de los rincones noroeste y sureste ya no son decorado: son cajas de `ShopBoxes` como las demás. Hay **10** en total: 5 por el suelo, 2+1 en el noroeste y 2 en el sureste.
- Las de los rincones empiezan donde estaban, la de arriba encima de la de abajo. La de arriba tapa a la de abajo, así que se coge primero. Si se aplana la de abajo con otra encima, la de arriba baja a su sitio (`drop_boxes_on`).
  - Al cargar una partida, una caja que estaba encima de otra que ya no está queda en el suelo.
- Los tesoros que hay encima de las pilas siguen ahí. Al aplanar la caja, el tesoro cae, como cualquier objeto encima de una caja.
- La caja pequeña del noroeste se ha movido un poco hacia el sur (-5.25, -2.6), porque en su sitio no se podía apuntar desde ningún lado.
- **Las 10 son obligatorias para abrir la tienda.** Antes eran 5.

### Física de las cajas

- Perfil nuevo `data/motion/box.tres`: masa 0,6, rebote 0,06, fricción 0,95, frenado lineal 0,9 y de giro 4,5.
- Lo usan la caja de costura, la lata, la plancha, la caja de botones, la caja de agujas y la bobina industrial. Antes la caja de costura era de madera (20 g y rebote 0,42) y salía despedida.
- Nueva prueba "Cajas pesadas": se sueltan 4 a la vez, dos encima de las otras y empujadas de lado. Recorren como mucho 0,21 m, no saltan y se paran en 1,1 s.

### Escoba (`make_broom`, `ShopSweep`)

- Mango torneado algo cónico, con la veta pintada en los colores de los vértices.
- La paja se recoge alrededor del mango con un cordel rojo en espiral.
- El abanico son 56 mechones algo curvados en cuatro filas al tresbolillo, con las puntas desiguales y un tono distinto cada uno, cosidos con dos pasadas de cordel.
- Unos 4.500 triángulos (antes 1.324). Mismo tamaño, origen y punto de agarre: el barrido sigue cuadrando.
- `ShopSweep` hace que "wood" y "straw" usen el color de los vértices (`vertex_color_is_srgb = false`, porque son colores lineales en coma flotante).

### Juego de té en el alféizar

- El modelo pone tetera y tazas en fila (`make_tea_set`), con unos 3 cm entre pieza y pieza. Antes las tazas iban delante y una sobresalía del alféizar.
- Va centrado en el alféizar sur (z 4,39), con la caja de colisión dentro del tablero.
- Los alféizares tienen colisión y se puede dejar cosas encima. La colisión acaba en la cara de la pared.
- Una lámina invisible en la cara de la pared tapa el hueco de la ventana, para que lo lanzado no se quede metido entre la pared y el cristal.

### Tesoros que no se encontraban

- Cinta real, lazo de seda y tijeras de nácar (y también el botón de zafiro) estaban encima de muebles altos (1,92 m).
  - El juego los detectaba (la prueba los apuntaba), pero desde el suelo no se veían: los ojos quedan por debajo del tablero y un objeto plano no asoma por encima del remate.
- Nuevos sitios, a la vista:
  - botón de zafiro, encima de la caja registradora;
  - cinta real, encima de la máquina de coser;
  - lazo de seda, en el alféizar de la ventana de la calle;
  - tijeras de nácar, en el alféizar del jardín, junto al té.
- El cajón del rincón noreste se ha corrido hacia el oeste, y su tesoro con él.
- La prueba de humo coge los 8.

### Etiquetas de las bandejas

- `TrayUnit._fit_label`: el nombre ya traducido se mide; si no cabe, primero se baja la letra y luego se parte en dos líneas. Con dos líneas, la placa crece hacia arriba.
- Se vuelve a ajustar al cambiar de idioma.
- Probado con "Estuche de agujas", "Cinta métrica", "Bastidor de bordado" y uno muy largo. Comprobado en capturas en inglés.

### Objetos en las bandejas

- Medido en la prueba de humo: el centro de cada objeto queda donde toca y el fondo de su malla a menos de 0,5 mm del fondo de la bandeja.
- Lo que se veía "flotando" era el saltito de celebración al completar una fila o la sala, que dura unas décimas.
- No había un desfase que corregir y no se ha tocado el ajuste. Los botones con argolla meten la argolla en el fondo, que no se ve.

### Sastrería: más piezas grandes

- Cinco tipos nuevos en `tools/make_item_data.gd`, con sus modelos en `make_items.py`:
  - caja de botones grande;
  - rollo de entretela;
  - bolsa de relleno;
  - caja de agujas surtidas;
  - bobina industrial.
- Van 3 de cada tipo, con su traducción al inglés.
- Como cada tipo ocupa una fila de estantería, hay una **segunda estantería** (`StoreShelfB`, 1,45 m de ancho, 3 huecos por fila) en la pared este, junto al rincón noreste. Su modelo es `shelf_5x145x40.glb`; `make_shelf` admite ahora el ancho.

### Alfombra

- La alfombra tiene colisión fina y se puede dejar cosas encima (capas 1 y 16).
- Los objetos que aparecen encima salen a su altura. El gato y su ovillo ya se apoyaban en ella (cuarta parte).

### Carteles modelados (`art/blender/make_signs.py`, `ShopSign`, `DoorSign`)

- **Texto:** sigue siendo Label3D, que se traduce y se encoge solo para caber en español y en inglés.
- **Secciones:** tabla de roble con la moldura del color de la sección y un icono pirograbado (ovillo, botón, telas con lazo o tijeras).
- **Cartel principal:** de nogal con moldura dorada, un carrete de hilo rojo y la hebra que corre hasta una aguja.
- **Puerta de la calle:** placa esmaltada crema colgada de un gancho, con CERRADO en granate por un lado y ABIERTO en verde por el otro. Al abrir la tienda da media vuelta.
- **Premio de ¡ABIERTO!:** cuelga con dos cordeles bajo el cartel principal.
- **Montón de cartón:** tablilla con una caja desmontada pirograbada y el texto de siempre ("Cartón para tirar").
- **Capturas:** `--signs`.
- **Pendiente:** no hay fuente con remates (serif), así que el principal usa Fredoka.

### Peatones y perro de la calle, al estilo de la clienta

- Los dos peatones están rehechos como la clienta: malla low-poly con esqueleto (`common.Rig`), paso a 12 fps y las mismas superficies y paleta.
  - El peatón es un chico alto con parka oliva, bufanda mostaza y pelo rizado.
  - El que pasea al perro es un señor mayor con abrigo camello, gorra y bufanda granates y bigote canoso.
- El perro también es nuevo: orejas caídas, hocico y patitas claros, collar rojo y trote en diagonal.
- La correa une la mano y el collar en cada fotograma.
- Los ciclistas y los de la moto siguen con el modelo antiguo.

### Arreglos tras probarlo (mismo día)

- **Recogedor y escoba sobre la alfombra:** la alfombra tiene grosor y tapaba el fondo del recogedor. Ahora la escoba y el recogedor se apoyan a la altura de la alfombra (`Sweeper._pose`).
- **Cajas apiladas de los rincones, cerradas y precintadas:** usan el modelo nuevo `cardboard_box_closed.glb` (`make_cardboard(closed=True)`). Con las solapas abiertas, las de la caja de abajo se cruzaban con la de encima.
- **Tesoros encima de las cajas:** al aplanar la caja, ahora también caen (`RoomController.hidden_treasures()` entra en `drop_items_on`). Al cargar partida, o con el atajo, un tesoro cuya caja ya no está queda sobre la de abajo o en el suelo (`_settle_treasures`). La prueba de humo lo comprueba.
- **Prueba de cajas pesadas:** ahora devuelve las cajas a su sitio. Si no, se quedaban amontonadas en medio y estorbaban al gato y a los lanzamientos del resto de la prueba.
- **Estado de las pruebas:** de las últimas 5 pasadas de la prueba de humo, 4 pasan y 1 tuvo un fallo que no quedó registrado. La de guardado y la de pantalla final pasan.

### Cómo se ha hecho

- La escoba, los carteles y los peatones los han hecho tres agentes en paralelo, cada uno en su rama. Se han integrado sin conflictos.
- Las pruebas de humo de varias copias del proyecto a la vez se pisan: comparten el log de `run_smoke.ps1` y el guardado `user://savegame_test.json`. Eso dio fallos falsos mientras trabajaban a la vez. Por separado, todo pasa.

### Pruebas (2026-10-24, quinta parte)

- `run_smoke.ps1 -Count 1`, `run_persist.ps1` y `run_end_screen.ps1`: **pasan** sobre `main` con todo integrado.
- Nuevas comprobaciones de humo:
  - cajas pesadas;
  - lo de las bandejas toca el fondo;
  - etiquetas largas;
  - el objeto dejado reposa en el suelo o en la alfombra.
- Capturas revisadas: `--treasures`, `--filled` (con dos vistas nuevas de las bandejas), `--signs`, `--street` y `--sweep`.

Problemas conocidos y sin comprobar a mano:
- En una de varias pasadas de la prueba de humo el gato no encontró camino desde un rincón apretado ("anda por la sala (0.00 m)"). Al repetirla pasó dos veces seguidas: parece raro, no sistemático.
- Con 10 cajas obligatorias, abrir la tienda lleva más rato. Si sobran, se pueden quitar de `ShopBoxes.SPOTS`.
- Las animaciones nuevas (giro del cartel, peatones, perro) solo se han visto en fotogramas sueltos.
- Los tablones de roble se ven algo anaranjados con la luz cálida.
- El tráiler sigue con el gato, los carteles y la escoba antiguos.

## Fase 4 — Gato nuevo y puntadas del HUD (2026-10-24, cuarta parte)

### El gato, rehecho

- **Modelo** (`art/blender/make_cat.py` → `art/models/cat.glb`, unos 14.200 triángulos):
  - Antes era de piezas sueltas (bolas y tubos con huecos en las uniones). Ahora el pelaje es **una sola malla suave**: las formas (lomo, pecho, grupa, tripa, cuello, cabeza, mofletes, hocico, orejas, patas y cola) se funden con un remallado por vóxeles, se suavizan y se reducen.
  - La cabeza es más grande, con mofletes mullidos y ojos grandes con brillo; tiene nariz rosa, boca en "w" y bigotes.
- **Pelo pintado en los vértices**: atigrado gris con lomo más oscuro, rayas por los costados, muslos y patas, anillos en la cola y punta oscura, "M" en la frente y rayitas en los mofletes. Hocico, pechera, tripa y patitas son blancos y el interior de las orejas es rosa.
  - `shop_cat.gd` activa el color de vértice (sRGB) en la superficie `fur`, con un poco de luz de borde para que se lea el pelo.
- **Esqueleto de 24 huesos** con pesos suaves (calculados por Blender):
  - cadera, pecho, cuello y cabeza;
  - patas en tres tramos (hombro-codo, codo-muñeca, patita; cadera-rodilla, rodilla-corvejón, patita);
  - cola en cinco tramos.
  - Los nombres que usa el juego no cambian (`eyes`, `ear_l`, `ear_r` y las 16 animaciones).
- **Animaciones rehechas** con codos, rodillas y columna:
  - al andar y trotar dobla codo, muñeca y rodilla para levantar la patita;
  - sentado, la cola rodea el cuerpo por el suelo;
  - la siesta es ahora "barra de pan", con la barbilla sobre las patas;
  - al estirarse baja el pecho al suelo con las patas delanteras estiradas;
  - de pie, sentado, tumbado y durmiendo, el pecho respira.
- El script puede renderizar vistas de cada animación sin abrir el juego (segunda carpeta tras `--`).
- `art/blender/common.py`: `Rig.export` se ha partido en `build_armature`, `bake_actions` y `write_glb`, que reutiliza el gato. La clienta exporta igual que antes (mismo archivo, byte a byte de tamaño).

### HUD

- La puntada discontinua de la nota de tareas, de la cinta "Racha" y del banner final se pintaba encima del texto, porque se ajustaba al contenido y no al panel. Ahora sigue el borde del panel (`Stitch.cover_parent`).

### Alfombra

- El ovillo del gato (y el propio gato) se hundían 1,6 cm en la alfombra, que está por encima del suelo. Ahora la sala sabe dónde hay alfombras (`RoomShell.rugs`, `floor_height()`) y el gato y el ovillo se apoyan encima. La prueba de humo lo comprueba.

### Pruebas

- `run_smoke.ps1 -Count 1`, `run_persist.ps1` y `run_end_screen.ps1`: **pasan**.
- Capturas `--cat` de todas las poses en el juego, y vistas de Blender de cada animación.

Sin comprobar a mano: las animaciones en movimiento dentro del juego (solo las he visto en fotogramas sueltos), sobre todo el revolcarse y la carrera loca. El tráiler sigue mostrando el gato antiguo: hay que volver a grabarlo.

## Fase 4 — Cajas de cartón, gato vivo, interfaz cozy, inglés y tráiler (2026-10-24, tercera parte)

### Cajas de cartón (después de barrer)

- Cinco cajas vacías tiradas por la tienda (`scripts/room/shop_boxes.gd` y `cardboard_box.gd`). Unas están derechas y otras tumbadas.
- **E** apuntando a una caja: da un saltito y se aplasta, con un crujido sintetizado (`cardboard_fold`) y polvo. El cartón plano viene a la mano, bajo el brazo derecho (`scripts/player/box_carrier.gd`).
- **Clic** apuntando al montón de junto a la puerta de la calle (al sur de la puerta, con una marca en el suelo y una nota "Cartón para tirar"): el cartón vuela, se apoya en la pared y suena (`cardboard_drop`). **E** lo suelta plano en el suelo y se puede volver a coger.
- Con las cinco en el montón se atan con un cordel. Para hacer sitio al montón, el rincón sureste ya no tiene la caja pequeña.
- **La tienda abre con todo ordenado, el suelo barrido y las cajas en el montón**, en cualquier orden. Si falta algo, un aviso dice qué falta.
- Se guarda qué cajas están en el montón y dónde está cada cartón suelto (clave `boxes`).

### El gato

- **Ronroneo de verdad**: dos grabaciones de gatos reales de dominio público (Wikimedia Commons), limpiadas y en bucle. Están en `art/audio/sfx/cat_purr_1.wav` y `_2.wav`, con sus créditos en `art/audio/sfx/CREDITOS_SONIDOS.txt`.
  - En cada caricia suena una al azar, con el volumen igualado según su nivel medido.
  - No se encontró ningún "mrrp" real con licencia válida, así que el "mrrp" sigue siendo sintetizado.
- **Animaciones nuevas** (`make_cat.py`):
  - `lie`: tumbado de lado;
  - `roll`: panza arriba, revolcándose;
  - `stretch`: se estira con el culete en alto;
  - `knead`: amasa;
  - `gallop`: carrera loca.
- **Comportamiento**:
  - se tumba y se revuelca un rato;
  - amasa sentado;
  - se estira al pararse y al despertar;
  - de vez en cuando le dan carreras locas por la sala, solo con el jugador lejos.

### Interfaz cozy (fuentes OFL en `art/fonts`)

- Fuentes: **Nunito** para el texto (variante 650 para todo, `nunito_ui.tres`), **Fredoka** para títulos y cifras, y **Patrick Hand** para notas a mano. Las tres tienen licencia SIL OFL y su texto de licencia va en la carpeta. Los carteles de la tienda usan Fredoka y Patrick Hand.
- `scripts/ui/ui_style.gd`: colores, fuentes, tarjetas de papel, teclas dibujadas y botones cosidos, comunes a todos los menús.
- **HUD**:
  - Arriba a la izquierda, una nota de papel cosida con:
    - el progreso;
    - la **lista de tareas**: cada cosa a su sitio, barrer el suelo, cajas al montón y tesoros. La tarea en curso va en rojo y las hechas se marcan con un botón turquesa;
    - al pie, el siguiente paso escrito a mano.
  - Bajo la mira, una píldora con la tecla dibujada.
  - Los avisos van en tarjetitas de papel, doradas para los logros.
  - La racha es una cinta roja.
  - Los controles salen con teclas dibujadas.
  - El tutorial y la pantalla final siguen el mismo estilo.
- **Pantalla de título nueva**:
  - La tienda de verdad se ve detrás, con una cámara que se mece despacio; el juego no está en pausa y el gato sigue a lo suyo.
  - Velo cálido a la izquierda, el título grande y un hilo que se cose solo.
  - Botones cosidos que entran uno a uno: Jugar/Continuar, Nueva partida, **Ajustes** (abre el menú de pausa encima) y Salir.
  - Arriba a la derecha, el idioma.
  - Al jugar, la cámara vuela hasta los ojos del jugador.
- **Menú de pausa**: fuentes nuevas y fila **Idioma**. Desde el título se abre como "Ajustes".

### Inglés

- Todos los textos tienen inglés: interfaz, avisos, indicadores, nombres y detalles de los objetos, carteles grandes y pequeños de la tienda, la nota del cartón, la puerta (CERRADO/ABIERTO), el gato, la apertura y el tráiler.
- Traducciones en `data/i18n/interfaz.csv` (73 textos) y `data/i18n/juego.csv` (256). La clave es el texto en español, que es el que hay en el código.
  - Se generan con `python tools/i18n_interfaz.py` y `python tools/i18n_juego.py`.
- `GameSettings.language`: la primera vez se usa el idioma del sistema (español si el sistema está en español, inglés si no). Se guarda en los ajustes.
  - Los textos cambian al momento.
  - En pruebas siempre es español, salvo que se pase `--lang=en`.

### Tráiler

- `powershell -File tools\trailer\grabar_trailer.ps1` graba `build\trailer\thread_by_thread_trailer_es.mp4` y `_en.mp4`.
  - Formato: 1920×1080, 30 fps, H.264 + AAC, 63 s.
  - Usa el Movie Maker de Godot: es el juego de verdad, con su música y sus sonidos, siguiendo un guion de planos (`tools/trailer/trailer.gd`).
  - Tarda unos 3 minutos por idioma. Mientras graba hay una ventana sin bordes de 1920×1080 encima de todo.
- Planos, en orden:
  1. la tienda hecha un lío;
  2. colocar ovillos en primera persona, con su racha;
  3. antes y después de una pared;
  4. el gato revolcándose y la caricia, con corazones y ronroneo;
  5. barrer y vaciar el recogedor;
  6. aplanar una caja y llevarla al montón;
  7. la apertura: campanillas, puerta, clienta, confeti y "La mercería está abierta";
  8. el logotipo con "Próximamente".
- Los rótulos van en tarjetas de papel cosidas, en el idioma de cada versión.

### Pruebas (2026-10-24, tercera parte)

- `run_smoke.ps1 -Count 1`: **pasa**. Nuevas comprobaciones:
  - barrido pero con las cajas por el suelo, la tienda no abre y la tarea en curso son las cajas;
  - aplanar las cinco con E, soltar una con E y volver a cogerla, dejarlas con clic en el montón, cordel, HUD marcado y guardado.
- `run_persist.ps1`: **pasa**, con dos cajas en el montón y un cartón suelto entre dos procesos.
- `run_end_screen.ps1`: **pasa**. Se ha adaptado al título nuevo: el juego ya no está en pausa debajo y el jugador no se mueve.
- Capturas nuevas:
  - `--top`: planta de la sala desde arriba;
  - `--boxes`: las cajas;
  - `--menu --show-title`: título en español e inglés y ajustes.
  - Con `--lang=en`, cualquier vista sale en inglés.

Sin comprobar a mano:
- el sonido del ronroneo real (no lo he podido escuchar; lo elegí por sus niveles y su espectro);
- el crujido del cartón;
- cómo se siente llevar el cartón;
- si las carreras locas del gato distraen.

El tráiler lo he revisado por fotogramas sueltos, no viéndolo entero con sonido. No se ha exportado el ejecutable.

## Fase 4 — Barrer a mano, gato por toda la sala y caricias (2026-10-24, segunda parte)

### Barrer lo hace el jugador (desde el principio de la partida)

Sustituye al barrido automático de la escena de apertura.

- La escoba y el recogedor están apoyados en la pared sur desde el principio. Al apuntarles sale "[E] Coger escoba y recogedor".
- Con ellos en la mano:
  - el recogedor va por el suelo delante del jugador y la escoba donde mira;
  - **mantener el clic** da escobazos (sonido en cada uno) y cada escobazo mete en el recogedor los papelitos que hay a unos 45 cm. Llega también debajo de las mesas.
- El recogedor se ve lleno con los colores de los papelitos y le caben 30. Lleno sale "Recogedor lleno: vacíalo en la papelera" y la flecha del borde señala la papelera.
- Apuntar a la papelera y clic: el recogedor vuela encima, se inclina y caen los papelitos con una nube de polvo y sonido. Para los 110 papelitos hacen falta 4 vueltas.
- Cuando quedan menos de 10 papelitos, la flecha del borde señala el más cercano.
- **E** devuelve las herramientas a la pared. Si se apunta a un objeto al pulsar E, las devuelve y coge el objeto.
- Panel de arriba a la izquierda: línea nueva "Suelo barrido N %".
- **La tienda abre con todo colocado y el suelo barrido** (y el recogedor vacío), en cualquier orden:
  - Si se termina de colocar antes, sale "Solo falta barrer el suelo: la escoba está junto a la ventana sur" y el objetivo pasa a "barrer el suelo".
  - El último vaciado en la papelera lanza la apertura a los 2 s.
- La partida guarda qué papelitos se han barrido, lo que lleva el recogedor y los vaciados (clave `floor` del guardado).
- Código:
  - `scripts/room/shop_sweep.gd` (suelo, herramientas y papelera);
  - `scripts/player/sweeper.gd` (nuevo: control en primera persona, hijo del `ItemHolder`).
  - El `ItemHolder` tiene "cosas que se usan con E sin cogerlas": un `Area3D` en la capa de coger cuyo padre tiene `interact_info()` e `interact()`. Lo usan la escoba y el gato.

### Papelera fuera de las cajas

Estaba metida dentro de la tercera caja de cartón del rincón sureste. Ahora está en la pared sur, bajo la ventana, en (3,55, 4,12), junto a la escoba y el recogedor.

### El gato, nuevo y por toda la sala

- **Modelo nuevo** (`art/blender/make_cat.py` → `art/models/cat.glb`, 4.366 triángulos, 12 huesos):
  - gato atigrado gris con rayas en el lomo, hocico, pechera, tripa y patitas blancos, ojos ámbar con pupila vertical, nariz rosa y bigotes;
  - cola en tres huesos con la punta oscura.
  - Superficies: `body`, `stripes`, `white`, `eyes`, `pupil`, `nose`, `inner_ear`, `whiskers`.
  - `common.Rig` ahora también anima la escala de los huesos (para cerrar los ojos).
- **Animaciones** a 12 fps:
  - `walk` (8 fotogramas), `trot` (6), `stand`, `sit`, `groom` (se lame la pata), `sleep` (hecho un ovillo, ojos cerrados), `bat` (zarpazo) y `pet` (ojos cerrados, frota la cabeza);
  - `blink` y las sacudidas de oreja (cada 6–10 s) se mezclan encima.
- **Qué hace** (`scripts/room/shop_cat.gd`), mientras el jugador ordena:
  - juega con el ovillo: va hasta él (al trote si está lejos), se sienta, le da un zarpazo y el ovillo rueda 0,8–1,8 m por suelo libre;
  - pasea, se lava o se echa la siesta (20–35 s), y repite.
- Solo pisa suelo libre:
  - no cruza muebles ni montones de objetos;
  - si una mesa le corta el paso, da un rodeo;
  - si empieza dentro de un hueco de mueble, sale al suelo libre más cercano.
- Se aparta si el jugador se le echa encima andando rápido. Si se le acerca despacio, no se espanta.
- No tiene colisión: no bloquea ni empuja nada. Fuera de cámara no calcula huesos.
- **Acariciar**: con las manos vacías, apuntarle y **E**. Sale "[E] Acariciar · Botón, el gato de la tienda".
  - Se sienta mirando al jugador, cierra los ojos, frota la cabeza, hace "mrrp" y ronronea unos 3 s, con corazoncitos.
  - Sonidos sintetizados nuevos: `cat_purr` (bucle de 2 s) y `cat_mrrp`.
- El ovillo sigue siendo el de la tienda (`yarn_ball.glb` con el material de `yarn_red.tres`); ahora es hermano del gato en la sala (`CatYarn`) para poder rodar.

### Arreglos que salieron al probar

- **Objeto escondido detrás de la planta** (o de un cajón o las cajas, junto a la pared): un lanzamiento podía dejarlo entre la maceta y la pared, sin poder verlo ni cogerlo.
  - Lo encontró la prueba de humo.
  - Ahora `RoomController._rescue_if_stuck` también mira si un objeto en el suelo junto a la pared se ve desde un paso más adentro. Si no se ve, sale al suelo libre con el aviso "Se había quedado escondido: aquí lo tienes".
- **El gato tapaba los objetos:** sentado junto a un objeto, al apuntar salía "Acariciar" en vez de "Recoger". Ahora, si hay un objeto justo detrás del gato (a menos de 0,5 m), manda el objeto.

### Pruebas (2026-10-24, segunda parte)

- `run_smoke.ps1 -Count 1`: **pasa** tres veces seguidas (229 comprobaciones). Nuevas:
  - con todo colocado y papelitos en el suelo no abre, y el objetivo pasa a barrer;
  - barrer como un jugador: apuntar y coger con E, 78 escobazos, 4 vaciados con polvo, el recogedor se llena (30), HUD al 100 %, guardado con el suelo barrido, y entonces empieza la apertura con la escoba ya en la pared;
  - la papelera no está dentro de las cajas;
  - un objeto escondido detrás de la planta sale al suelo libre;
  - gato: anda 1,6 m sin pisar muebles, va hasta el ovillo, zarpazo (la pata gira 1,48 rad), el ovillo rueda y acaba en suelo libre, sacude una oreja, sale "Acariciar", E le acaricia (pose `pet`) y luego vuelve a lo suyo.
- `run_persist.ps1`: **pasa**, ahora también con medio suelo barrido y papelitos en el recogedor entre dos procesos.
- `run_end_screen.ps1`: **pasa**.
- Capturas: `--sweep` (nuevo: coger, escobazo, recogedor, papelera, vaciar) y `--cat` (cada pose de cerca, zarpazo, caricia y suelto por la sala).

Sin comprobar a mano:
- cómo se sienten el ritmo del escobazo y el tamaño del alcance;
- el sonido del ronroneo y del "mrrp";
- si el gato se cruza demasiado en el camino.

No se ha exportado el ejecutable.

## Fase 4 — Final de la demo: barrido, apertura, clienta, gato y repaso para Steam (2026-10-24)

### Escena de apertura (al colocar el último objeto)

`scripts/room/shop_opening.gd` (nodo `ShopOpening` en `main.tscn`). Sin control del jugador durante toda la escena; la interfaz de juego se apaga y la cámara sigue lo que pasa.

1. **Barrido** (*sustituido en la segunda parte: ahora barre el jugador, ver arriba*). Una escoba y un recogedor aparecen apoyados en la pared sur.
   - La escoba junta en un montón los papelitos del suelo (el MultiMesh `FabricScraps`), un cuadrante cada vez y con tres escobazos.
   - El recogedor recoge el montón (se ve lleno, con los colores de los papelitos) y lo vacía en la papelera de junto a la puerta, con una nube de polvo y sonido.
   - Son cuatro cargas, cada una una cuarta parte del suelo, y dura unos 30 s. Al terminar, la escoba y el recogedor vuelven a la pared y se quedan allí.
2. La música se apaga en 1,5 s y la campanilla de la puerta suena tres veces.
3. La puerta se abre (ahora es una hoja con bisagra y hay un hueco real en la pared este, con escalón, camino y terreno detrás) y entra **la primera clienta**.
4. Al cruzar la puerta:
   - las luces suben un 20 % en 3 s;
   - el cartel pasa a ABIERTO;
   - cae confeti del techo;
   - aparece el letrero "La mercería está abierta" (letra con serifa, 4 s).
   - La capa `full` de la música vuelve 2 s después de abrirse la puerta; el resto, poco después.
5. La clienta va al centro, se gira hacia la estantería más cercana, mira a su alrededor, espera 3 s y se va. La puerta se cierra tras ella.
6. Fundido a negro (3 s) y **pantalla final** (`scenes/ui/end_screen.tscn`): de negro a crema, "Thread by Thread" y "Gracias por ordenar la mercería", con la música sonando.
   - "Seguir explorando" devuelve a la tienda abierta e iluminada, con control libre.
   - "Menú principal" recarga la escena y sale el título.
7. Se guarda `shop_opened: true`. Una partida cargada con la tienda abierta no repite la escena: suelo limpio, escoba y recogedor en su rincón, tienda iluminada. Si se cerró el juego a media escena, se ve al cargar.
8. Atajo: con `--test-mode`, la tecla **T** lanza la escena.

### Arreglos

- **Botones de la pantalla final (crítico).** "Seguir explorando" y "Menú principal" no respondían.
  - Causa: `scripts/main.gd` recapturaba el ratón con cualquier clic en `_input`, que va antes que la interfaz. El clic nunca llegaba a los botones y el puntero desaparecía.
  - Arreglo: la pantalla final está en el grupo `modal_ui` y `main.gd` no toca el ratón mientras haya un nodo de ese grupo.
  - Prueba nueva con clics reales (`tests/run_end_screen.ps1`): reproducía el fallo con el código anterior y pasa con el arreglo.
- **"Racha ×N"** va ahora arriba a la derecha (crece hacia la izquierda, nunca se sale del borde). Se oculta del todo durante la escena de apertura y con la pantalla final, y no vuelve a salir hasta la siguiente racha. El tutorial también se esconde durante la escena.
- Revisión de solapes del HUD a 1600×900 y 1280×720: panel de progreso (arriba a la izquierda), tutorial (arriba al centro), racha (arriba a la derecha), indicador (centro, 60 %), avisos (80 %) y controles (abajo a la izquierda). Sin solapes.

### Arte nuevo (Blender, todo original del proyecto)

- **La clienta** (`art/blender/make_customer.py` → `art/models/customer.glb`, script `scripts/room/customer.gd`). Sustituye al peatón de la calle que hacía de cliente.
  - Una mujer de unos 50 años: rebeca teja, falda, gafas redondas, moño canoso, mejillas sonrosadas, sonrisa y una cestita colgada del brazo.
  - Esqueleto de 11 huesos; cada pieza va pesada entera a su hueso (estilo low-poly) y la malla tiene 3.732 triángulos.
  - Tres animaciones a 12 fps: `walk` (ciclo de 8 fotogramas, que va al ritmo de su velocidad), `idle` (respira) y `look_around` (gira la cabeza a un lado y al otro).
  - Superficies `skin`, `hair`, `clothes`, `basket` y `details`. Sin cuerpo físico: no toca los objetos.
- **El gato** (`art/blender/make_cat.py` → `art/models/cat.glb`, script `scripts/room/shop_cat.gd`).
  - Sentado en el rincón suroeste, junto al maniquí. Gris claro, redondo, de 2.000 triángulos.
  - Da zarpazos lentos a un ovillo de la tienda: usa el mismo `yarn_ball.glb` y el material de `yarn_red.tres`, sin duplicarlo. Es un bucle de 24 fotogramas (2 s) y el ovillo rueda un poco con cada toque.
  - Cada 6–10 s sacude una oreja al azar. Esa animación se mezcla encima del zarpazo con un AnimationTree (OneShot filtrado a la oreja).
  - Superficies `body`, `eyes`, `nose` e `inner_ear`. Fuera de cámara se para.
- **Escoba, recogedor y papelera de mimbre** (`make_props.py`: `broom`, `dustpan`, `waste_bin`). La papelera está junto a la puerta este, con colisión.
- `art/blender/common.py` tiene una clase nueva, `Rig`: modelos con esqueleto y animaciones escritas en ejes de Godot, exportadas como pistas NLA del GLB.
- Sonidos sintetizados nuevos: `sweep` (escobazo, 3 variantes) y `dust_dump` (vaciar el recogedor, 2 variantes).

### Repaso para Steam

Lo que piden las guías de accesibilidad de Steam y los juegos tranquilos de ordenar: tamaño de texto ajustable, colores para daltonismo con forma además de color, controles claros, sin bloqueos y sin trabajo inútil por fotograma.

| # | Encontrado | Arreglo |
|---|---|---|
| 1 | La pantalla final no respondía al ratón | grupo `modal_ui` (arriba) |
| 2 | Un objeto lanzado podía quedar en el hueco de 6 cm entre una estantería o un panel y la pared, o metido en el grueso de la pared (la prueba de humo lo pilló: un lanzamiento contra el rodapié sur dejó la tiza en z = 4,53, fuera del alcance, y la tienda no se podía terminar) | `RoomController._rescue_if_stuck`: al posarse ahí, se desliza delante del mueble o hacia dentro de la sala, con un aviso ("Se había colado detrás del mueble…" / "Se había quedado pegado a la pared…"). Con prueba para los dos casos |
| 3 | Botón de desarrollo "Completar esta sección" visible para los jugadores en el menú de pausa | solo sale en el editor (versión de depuración) o con `--test-mode` |
| 4 | Sin opción de tamaño de texto | Ajuste "Tamaño del texto" (×1,0–×1,5) en Accesibilidad: agranda toda la interfaz (`content_scale_factor`). Comprobado a ×1,5 en 1280×720: el menú cabe |
| 5 | La mira y el objeto fantasma solo distinguían "cabe / no cabe" con verde y rojo | Ajuste "Colores para daltonismo": azul y naranja. Además, siempre, una X en la mira cuando no cabe (forma, no solo color). El texto del indicador usa los mismos colores |
| 6 | Final de una sección y final de la tienda sonaban casi igual | El final de la tienda añade una cascada de campanillas que sube (do-mi-sol-do) |
| 7 | Animaciones lineales: fundidos del HUD, menú, título, tutorial y pantalla final; saltos del contador y de los tesoros; color de los focos al completar sección | todas con curva suave (`TRANS_SINE`, `TRANS_QUAD`) |
| 8 | Trabajo en cada fotograma que podía ir con temporizador | autoguardado (`Shop`), pájaros (`Ambience`) y sucesos de la calle (`StreetLife`) con `Timer`. `AudioManager.sounds_ready` sustituye a comprobar `ready_to_play` en cada fotograma. La flecha de orientación y el punto de mira se duermen cuando no cambian. El gato se para fuera de cámara |
| 9 | Textos de controles distintos entre el HUD y el menú ("Clic colocar" / "Clic izq. colocar") | unificados ("E recoger / dejar · Clic izq. colocar") |

Ya estaba bien: sonido al coger, al rechazar (`deny`, además del aviso de texto y el temblor), al colocar (según material y racha), al completar sección y tienda. También la red de seguridad para objetos que salen de la sala.

### Pruebas (2026-10-24)

- `run_smoke.ps1 -Count 1`: **pasa** (dos ejecuciones seguidas, 205 comprobaciones; una tercera anterior falló por el objeto metido en la pared, ya corregido). Comprobaciones nuevas:
  - barrido: 4 cargas, el suelo se va limpiando por grupos, polvo en cada vaciado, escoba y recogedor de vuelta en la pared;
  - clienta: anda, mira a su alrededor, entra y se va;
  - gato: la pata gira y la oreja se sacude;
  - un objeto colado detrás de una estantería sale delante, y uno metido en la pared vuelve dentro;
  - la racha oculta durante la escena.
- `run_persist.ps1`: **pasa**.
- `run_end_screen.ps1` (nueva, clics reales):
  - título, Jugar, apertura y "Seguir explorando";
  - apertura otra vez y "Menú principal": recarga, sin nodos huérfanos, sale el título;
  - la partida cargada tiene la tienda abierta y el suelo barrido.
  - Resultado: **pasa**.
- Capturas: `tests/screenshot_runner.gd` con `--opening` (incluye el barrido), `--customer`, `--cat`, `--hud` y `--access`.

Sin comprobar a mano:
- cómo se oyen el escobazo y el vaciado;
- el ritmo total del final: unos 30 s de barrido más unos 25 s de apertura;
- si la clienta y el gato quedan bien de cerca.

No se ha exportado el ejecutable.

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
powershell -File tests\run_end_screen.ps1                # pantalla final con clics reales (seguir / menú)
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

- Premios de sección (Blender, `art/blender/make_props.py`): al completar cada sección aparece, con un rebote, un objeto nuevo en la tienda. Lanas: un gato canela dormido en su cesta, junto a la ventana oeste. Botones y carretes: una radio de madera con el dial encendido, en la mesa de corte. Telas y cintas: un jarrón con margaritas y lavanda, en la misma mesa. Sastrería: un juego de té en el alféizar de la ventana sur. Se guardan con la sección y tienen colisión solo desde que aparecen. Capturas en `tests/screenshot_runner.gd --filled` (vistas `premio_*`).

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
