"""Escribe data/i18n/interfaz.csv: las traducciones de la interfaz (HUD, título, pausa, tutorial y final).

Uso:  python tools/i18n_interfaz.py
La clave de cada fila es el texto en español tal cual aparece en el código (los \\n, escritos así).
Los textos del resto del juego (objetos, carteles, avisos) están en data/i18n/juego.csv.
Después, abre el proyecto en Godot (o godot --headless --path . --import) para que se importe.
"""
import csv
import os

ROWS = [
    # HUD
    ("Organizados  %d / %d", "Sorted  %d / %d"),
    ("Cada cosa a su sitio", "Everything in its place"),
    ("Barrer el suelo", "Sweep the floor"),
    ("Cajas al montón", "Boxes to the pile"),
    ("Tesoros escondidos", "Hidden treasures"),
    ("Lleva cada cosa a su sección: mira los carteles", "Take each thing to its section: check the signs"),
    ("¡Mercería ordenada!", "The shop is all tidy!"),
    ("La escoba y el recogedor están junto a la ventana sur", "The broom and dustpan are by the south window"),
    ("Aplana las cajas y déjalas junto a la puerta", "Flatten the boxes and leave them by the door"),
    ("Va en:  %s   %d / %d", "Goes in:  %s   %d / %d"),
    ("Racha ×%d", "Streak ×%d"),
    ("¡Sección completa: %s!", "Section complete: %s!"),
    ("¡Tesoro encontrado!  %s", "Treasure found!  %s"),
    ("Partida guardada", "Game saved"),
    ("¡La mercería está lista!", "The haberdashery is ready!"),
    ("Cada cosa tiene su sitio. La tienda vuelve a abrir sus puertas.", "Everything has its place. The shop opens its doors again."),
    ("Clic", "Click"),
    ("mover", "move"),
    ("correr", "run"),
    ("agacharse", "crouch"),
    ("coger / usar", "take / use"),
    ("colocar", "place"),
    ("girar", "rotate"),
    ("lanzar", "throw"),
    ("pausa", "pause"),
    # Título
    ("una mercería por ordenar, hilo a hilo", "a haberdashery to tidy, thread by thread"),
    ("Jugar", "Play"),
    ("Continuar", "Continue"),
    ("Nueva partida", "New game"),
    ("¿Seguro? Se borra la partida", "Sure? Your game will be erased"),
    ("Ajustes", "Settings"),
    ("Salir", "Quit"),
    ("Demo · 15–25 minutos · Esc: pausa, ajustes y libro de colecciones",
     "Demo · 15–25 minutes · Esc: pause, settings and collection book"),
    # Pausa y ajustes
    ("Pausa", "Paused"),
    ("Volver", "Back"),
    ("Libro de colecciones", "Collection book"),
    ("Completar esta sección", "Complete this section"),
    ("Salir del juego", "Quit game"),
    ("Idioma", "Language"),
    ("Manos", "Hands"),
    ("Sensibilidad del ratón", "Mouse sensitivity"),
    ("Sonido", "Sound"),
    ("Volumen general", "Master volume"),
    ("Efectos", "Effects"),
    ("Música", "Music"),
    ("Pantalla", "Display"),
    ("Pantalla completa", "Fullscreen"),
    ("Sincronización vertical", "Vertical sync"),
    ("Bordes suaves (MSAA 4x)", "Smooth edges (MSAA 4x)"),
    ("Iluminación avanzada", "Advanced lighting"),
    ("Accesibilidad", "Accessibility"),
    ("Tamaño del texto", "Text size"),
    ("Colores para daltonismo (azul / naranja)", "Colour-blind colours (blue / orange)"),
    ("WASD mover · Shift correr\\nCtrl agacharse · R girar\\nE recoger / dejar\\nClic izq. colocar · F lanzar\\nEsc pausa",
     "WASD move · Shift run\\nCtrl crouch · R rotate\\nE pick up / put down\\nLeft click place · F throw\\nEsc pause"),
    ("Ordenados %d de %d  ·  Tesoros encontrados: %d de %d", "Sorted %d of %d  ·  Treasures found: %d of %d"),
    ("  ·  ¡completada!", "  ·  complete!"),
    ("ordenados %d de %d", "sorted %d of %d"),
    # Tutorial
    ("Acércate a cualquier cosa del suelo y pulsa E para cogerla", "Walk up to anything on the floor and press E to pick it up"),
    ("Busca su sección (mira los carteles de las paredes) y apunta a su fila",
     "Find its section (check the signs on the walls) and aim at its row"),
    ("Haz clic izquierdo para colocarlo", "Left click to put it in place"),
    ("Truco: coge otro y pulsa F para lanzarlo (mantén F = más fuerza)", "Tip: pick up another and press F to throw it (hold F = harder)"),
    ("Listo", "Done"),
    ("Ya sabes jugar. ¡Ordena toda la mercería! Hay tesoros escondidos en lo alto",
     "You know how to play. Tidy up the whole shop! There are treasures hidden up high"),
    # Final
    ("Gracias por ordenar la mercería", "Thank you for tidying the haberdashery"),
    ("Seguir explorando", "Keep exploring"),
    ("Menú principal", "Main menu"),
    # Tráiler (tools/trailer)
    ("Una mercería hecha un lío…", "A haberdashery in a tangle…"),
    ("Coloca cada cosa en su sitio", "Find a place for everything"),
    ("Hilo a hilo", "Thread by thread"),
    ("Mima a Botón, el gato de la tienda", "Pet Button, the shop cat"),
    ("Barre los retales del suelo", "Sweep up the scraps"),
    ("Y recoge las cajas", "And clear away the boxes"),
    ("Próximamente", "Coming soon"),
]


def main():
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "i18n", "interfaz.csv")
    keys = [k for k, _ in ROWS]
    dup = {k for k in keys if keys.count(k) > 1}
    assert not dup, dup
    with open(out, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, quoting=csv.QUOTE_ALL, lineterminator="\n")
        w.writerow(["keys", "es", "en"])
        for es, en in ROWS:
            assert es.count("%") == en.count("%"), es
            w.writerow([es, es, en])
    print("filas:", len(ROWS))


main()
