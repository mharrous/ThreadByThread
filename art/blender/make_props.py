"""Genera el atrezo de la mercería (original) y lo exporta a GLB para Godot.

Uso:
  blender --background --factory-startup --python art/blender/make_props.py -- art/models

Modelos:
  pendant_lamp     lámpara colgante esmaltada (origen = bombilla)
  dress_form       maniquí de costura sobre trípode (origen = suelo)
  sewing_machine   máquina de coser antigua, negra con filetes dorados (origen = base)
  cash_register    caja registradora de latón (origen = base)
  shop_door        marco de la puerta de entrada con la campanilla (origen = suelo, cara hacia +Z)
  shop_door_leaf   hoja de la puerta, con cristal, placa y pomo (origen = bisagra, a la izquierda)
  Premios de sección (aparecen al completarla; origen = base, frente hacia +Z):
  cat_basket       gato canela dormido, enroscado en una cesta de mimbre (lanas)
  radio            radio de válvulas de madera con dial iluminado (botones y carretes)
  flower_vase      jarrón de cerámica con margaritas y lavanda (telas y cintas)
  tea_set          tetera esmaltada con dos tazas (sastrería)
  Barrido del final (scripts/room/shop_sweep.gd):
  broom            escoba de paja con mango de madera (origen = punta de la paja en el suelo, mango hacia +Y)
  dustpan          recogedor esmaltado de mango largo (origen = borde delantero en el suelo; la pala va hacia -Z)
  waste_bin        papelera de mimbre junto a la puerta (origen = suelo)
Se modela en ejes de Godot (Y arriba, Z hacia delante). Los materiales viajan en el GLB.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

from common import Model, OUT_DIR, reset_scene  # noqa: E402

os.makedirs(OUT_DIR, exist_ok=True)

BRASS = (0.83, 0.64, 0.32)
BLACK_LACQUER = (0.035, 0.035, 0.04)


def emissive(m, name, color, strength):
    """Material que brilla (la bombilla): el exportador glTF lo lleva como emisivo."""
    m.add_material(name, color, 0.4)
    bsdf = m.materials[-1].node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
    bsdf.inputs["Emission Strength"].default_value = strength


# ---------------------------------------------------------------- lámpara
def make_pendant_lamp():
    reset_scene()
    m = Model("pendant_lamp", 101)
    m.add_material("enamel", (0.20, 0.38, 0.33), 0.35)                  # 0 verde esmaltado por fuera
    m.add_material("enamel_in", (0.97, 0.93, 0.84), 0.5, double_sided=True)  # 1 crema por dentro
    m.add_material("brass", BRASS, 0.3, metallic=1.0)                   # 2
    emissive(m, "bulb", (1.0, 0.86, 0.62), 6.0)                         # 3
    # Pantalla de campana con borde enrollado.
    shade = [(0.035, 0.20), (0.06, 0.19), (0.12, 0.14), (0.20, 0.07), (0.255, 0.02), (0.27, 0.005), (0.272, -0.005)]
    m.lathe(shade, 40, mat=0)
    m.lathe([(r * 0.965, y - 0.004) for (r, y) in shade], 40, mat=1)
    m.torus((0, -0.006, 0), 0.272, 0.006, major_seg=40, minor_seg=6, mat=0)
    # Portalámparas y florón de latón.
    m.cylinder((0, 0.205, 0), 0.03, 0.05, mat=2, round_edge=0.006, segments=20)
    m.cylinder((0, 0.25, 0), 0.012, 0.04, mat=2, segments=12)
    m.cylinder((0, 0.08, 0), 0.022, 0.1, mat=2, segments=18)
    # Bombilla de globo.
    m.sphere((0, 0.0, 0), 0.055, scale=(1.0, 1.15, 1.0), segments=20, rings=12, mat=3)
    m.export(center_y=False)


# ---------------------------------------------------------------- maniquí
def make_dress_form():
    reset_scene()
    m = Model("dress_form", 102)
    m.add_material("linen", (0.86, 0.79, 0.66), 0.95)                   # 0 tela
    m.add_material("wood", (0.42, 0.27, 0.16), 0.55)                    # 1 nogal
    m.add_material("brass", BRASS, 0.3, metallic=1.0)                   # 2
    # Torso: hombros, pecho, cintura y cadera (sección algo ovalada).
    torso = [(0.0, 0.86), (0.13, 0.87), (0.17, 0.92), (0.165, 1.0), (0.135, 1.08), (0.16, 1.18),
             (0.175, 1.27), (0.17, 1.33), (0.14, 1.38), (0.07, 1.42), (0.05, 1.45), (0.0, 1.455)]
    m.lathe(torso, 32, mat=0, scale=(1.0, 1.0, 0.72))
    # Remate del cuello y costura de la cintura.
    m.cylinder((0, 1.47, 0), 0.045, 0.03, mat=1, round_edge=0.01, segments=20)
    m.sphere((0, 1.5, 0), 0.025, mat=1)
    m.torus((0, 1.08, 0), 0.135, 0.004, major_seg=32, minor_seg=5, mat=0, scale=(1.0, 1.0, 0.72))
    # Mástil con anilla de latón y trípode.
    m.cylinder((0, 0.48, 0), 0.016, 0.78, mat=1, segments=12)
    m.cylinder((0, 0.6, 0), 0.026, 0.05, mat=2, round_edge=0.008, segments=16)
    m.cylinder((0, 0.1, 0), 0.03, 0.08, mat=1, round_edge=0.01, segments=16)
    for k in range(3):
        a = math.tau * k / 3 + 0.3
        tip = (math.cos(a) * 0.3, 0.015, math.sin(a) * 0.3)
        m.tube([(0, 0.1, 0), (tip[0] * 0.5, 0.06, tip[2] * 0.5), tip], 0.014, 8, mat=1, cap=True)
    m.export(center_y=False)


# ---------------------------------------------------------------- máquina de coser
def make_sewing_machine():
    reset_scene()
    m = Model("sewing_machine", 103)
    m.add_material("lacquer", BLACK_LACQUER, 0.22)                      # 0 negro brillante
    m.add_material("gold", (0.86, 0.68, 0.30), 0.35, metallic=1.0)       # 1 filetes dorados
    m.add_material("steel", (0.78, 0.79, 0.82), 0.25, metallic=1.0)      # 2
    m.add_material("wood", (0.45, 0.28, 0.16), 0.5)                      # 3 base de madera
    # Base de madera y bancada.
    m.box((0, 0.02, 0), (0.44, 0.04, 0.2), grain="x", bevel=0.008, segments=3, mat=3)
    m.box((0, 0.055, 0), (0.38, 0.03, 0.17), grain="x", bevel=0.01, segments=3, mat=0)
    # Columna (derecha), brazo superior y cabezal (izquierda).
    m.box((0.13, 0.15, 0), (0.08, 0.17, 0.085), bevel=0.025, segments=4, mat=0, taper=1.25)
    m.box((0.0, 0.245, 0), (0.30, 0.055, 0.07), grain="x", bevel=0.022, segments=4, mat=0)
    m.box((-0.15, 0.2, 0), (0.06, 0.14, 0.065), bevel=0.02, segments=4, mat=0)
    # Filetes dorados a lo largo del brazo.
    m.box((0.0, 0.245, 0.0355), (0.26, 0.004, 0.002), grain="x", bevel=0.0, mat=1)
    m.box((0.0, 0.232, 0.0355), (0.24, 0.002, 0.002), grain="x", bevel=0.0, mat=1)
    # Barra de la aguja y prensatelas.
    m.cylinder((-0.16, 0.11, 0.012), 0.004, 0.08, mat=2, segments=8)
    m.box((-0.16, 0.075, 0.012), (0.03, 0.006, 0.02), bevel=0.002, segments=1, mat=2)
    m.cylinder((-0.16, 0.085, 0.022), 0.0012, 0.03, mat=2, segments=6)
    # Volante (rueda) a la derecha, eje X.
    m.cylinder((0.19, 0.2, 0), 0.06, 0.022, axis="x", mat=2, round_edge=0.006, segments=28)
    m.cylinder((0.205, 0.2, 0), 0.02, 0.02, axis="x", mat=1, segments=16)
    # Portacarrete con un carrete rojo.
    m.cylinder((0.05, 0.29, 0), 0.0025, 0.05, mat=2, segments=6)
    m.add_material("thread", (0.75, 0.15, 0.15), 0.8)                    # 4
    m.cylinder((0.05, 0.293, 0), 0.012, 0.028, mat=4, segments=14)
    m.export(center_y=False)


# ---------------------------------------------------------------- caja registradora
def make_cash_register():
    reset_scene()
    m = Model("cash_register", 104)
    m.add_material("brass", BRASS, 0.32, metallic=1.0)                   # 0
    m.add_material("wood", (0.40, 0.25, 0.14), 0.5)                      # 1
    m.add_material("keys", (0.96, 0.93, 0.86), 0.4)                      # 2 teclas de marfil
    m.add_material("dark", (0.08, 0.07, 0.06), 0.6)                      # 3
    # Cajón de madera y cuerpo de latón inclinado.
    m.box((0, 0.045, 0.01), (0.36, 0.09, 0.34), grain="x", bevel=0.008, segments=3, mat=1)
    m.box((0, 0.065, 0.175), (0.06, 0.02, 0.012), bevel=0.004, segments=2, mat=0)       # tirador
    m.box((0, 0.17, -0.02), (0.34, 0.16, 0.28), bevel=0.02, segments=3, mat=0, taper=1.15)
    # Teclado en gradas (3 filas x 6 teclas).
    for row in range(3):
        for col in range(6):
            x = -0.125 + col * 0.05
            y = 0.205 + row * 0.03
            z = 0.1 - row * 0.045
            m.cylinder((x, y, z), 0.013, 0.012, mat=2, round_edge=0.003, segments=14)
            m.cylinder((x, y - 0.015, z), 0.003, 0.02, mat=3, segments=6)
    # Marcador superior con ventanilla y remate.
    m.box((0, 0.32, -0.08), (0.2, 0.1, 0.1), bevel=0.012, segments=3, mat=0)
    m.box((0, 0.325, -0.029), (0.15, 0.04, 0.004), bevel=0.0, mat=3)
    m.lathe([(0, 0.37), (0.035, 0.37), (0.02, 0.4), (0.0, 0.41)], 16, center=(0, 0, -0.08), mat=0)
    # Manivela lateral.
    m.cylinder((0.185, 0.16, -0.02), 0.025, 0.02, axis="x", mat=0, segments=16)
    m.tube([(0.2, 0.16, -0.02), (0.215, 0.16, -0.02), (0.215, 0.09, -0.02)], 0.005, 6, mat=0)
    m.cylinder((0.225, 0.09, -0.02), 0.009, 0.03, axis="x", mat=1, segments=10)
    m.export(center_y=False)


# ---------------------------------------------------------------- puerta de la tienda
def make_shop_door():
    """Dos modelos: el marco fijo con la campanilla (shop_door) y la hoja (shop_door_leaf), que se abre.
    La hoja tiene el origen en la bisagra (su canto izquierdo), así se gira sin más en Godot."""
    W, H, T = 1.0, 2.15, 0.05

    def materials(m):
        m.add_material("paint", (0.20, 0.38, 0.33), 0.45)                # 0 verde de la casa
        m.add_material("frame", (0.93, 0.88, 0.78), 0.55)                # 1 marco crema
        m.add_material("glass", (0.85, 0.95, 1.0), 0.05)                 # 2
        m.add_material("brass", BRASS, 0.3, metallic=1.0)                # 3

    reset_scene()
    m = Model("shop_door", 105)
    materials(m)
    # Marco: jambas y dintel salientes de la pared.
    for sx in (-1, 1):
        m.box((sx * (W / 2 + 0.05), (H + 0.1) / 2, 0.03), (0.1, H + 0.1, 0.06), bevel=0.008, segments=2, mat=1)
    m.box((0, H + 0.075, 0.03), (W + 0.2, 0.15, 0.06), grain="x", bevel=0.01, segments=2, mat=1)
    # Campanilla sobre la puerta, colgada de un brazo de latón.
    m.tube([(0.3, H + 0.12, 0.06), (0.3, H + 0.12, 0.16)], 0.006, 6, mat=3, cap=False)
    m.lathe([(0.0, H + 0.11), (0.025, H + 0.1), (0.045, H + 0.03), (0.05, H + 0.015), (0.0, H + 0.015)], 18,
            center=(0.3, -H - 0.01 + H, 0.16), mat=3)
    m.export(center_y=False)

    # Hoja: paneles inferiores, cristal arriba con travesaño y cuarterones. x0 desplaza la bisagra al origen.
    reset_scene()
    m = Model("shop_door_leaf", 110)
    materials(m)
    x0 = W / 2
    z = 0.012
    m.box((x0 - W / 2 + 0.04, H / 2, z), (0.08, H, T), bevel=0.006, segments=2, mat=0)
    m.box((x0 + W / 2 - 0.04, H / 2, z), (0.08, H, T), bevel=0.006, segments=2, mat=0)
    m.box((x0, 0.06, z), (W, 0.12, T), grain="x", bevel=0.006, segments=2, mat=0)
    m.box((x0, 0.9, z), (W, 0.12, T), grain="x", bevel=0.006, segments=2, mat=0)
    m.box((x0, H - 0.05, z), (W, 0.1, T), grain="x", bevel=0.006, segments=2, mat=0)
    m.box((x0, 0.48, z - 0.005), (W - 0.16, 0.72, T * 0.6), bevel=0.0, mat=0)
    for sx in (-1, 1):
        m.box((x0 + sx * 0.21, 0.48, z + 0.012), (0.3, 0.6, 0.012), bevel=0.012, segments=3, mat=0)
    m.box((x0, (0.96 + H - 0.1) / 2, z), (W - 0.16, H - 0.1 - 0.96, 0.008), bevel=0.0, mat=2)
    m.box((x0, (0.96 + H - 0.1) / 2, z + 0.006), (0.03, H - 0.1 - 0.96, 0.02), bevel=0.003, segments=1, mat=0)
    # Placa de empuje, pomo (por las dos caras) y buzón.
    m.box((x0 + 0.36, 1.05, z + 0.03), (0.06, 0.22, 0.004), bevel=0.002, segments=1, mat=3)
    for side in (1, -1):
        m.sphere((x0 + 0.36, 1.0, z + side * 0.06), 0.028, mat=3)
        m.cylinder((x0 + 0.36, 1.0, z + side * 0.04), 0.008, 0.04, axis="z", mat=3, segments=10)
    m.box((x0, 0.62, z + 0.03), (0.26, 0.05, 0.006), grain="x", bevel=0.003, segments=1, mat=3)
    m.export(center_y=False)


# ---------------------------------------------------------------- premio: gato en su cesta
def make_cat_basket():
    reset_scene()
    m = Model("cat_basket", 106)
    m.add_material("wicker", (0.72, 0.53, 0.30), 0.85)                   # 0 mimbre
    m.add_material("cushion", (0.66, 0.25, 0.27), 0.9)                   # 1 cojín granate
    m.add_material("fur", (0.86, 0.55, 0.26), 0.95)                      # 2 pelo canela
    m.add_material("stripe", (0.62, 0.34, 0.14), 0.95)                   # 3 rayas oscuras
    m.add_material("pink", (0.93, 0.62, 0.62), 0.7)                      # 4 nariz y orejas
    m.add_material("dark", (0.12, 0.08, 0.06), 0.6)                      # 5 ojos cerrados
    # Cesta baja con anillos trenzados, borde grueso y cojín.
    m.lathe([(0.0, 0.0), (0.2, 0.0), (0.24, 0.03), (0.265, 0.12), (0.27, 0.14), (0.25, 0.14),
             (0.245, 0.125), (0.22, 0.035), (0.0, 0.03)], 36, mat=0)
    for k in range(3):
        m.torus((0, 0.045 + k * 0.035, 0), 0.245 + k * 0.008, 0.011, major_seg=36, minor_seg=6, mat=0)
    m.torus((0, 0.145, 0), 0.262, 0.016, major_seg=36, minor_seg=7, mat=0)
    m.cylinder((0, 0.06, 0), 0.215, 0.05, mat=1, round_edge=0.022, segments=32)
    # Cuerpo enroscado: un anillo grueso aplastado; rayas como aros finos alrededor del lomo.
    m.torus((0, 0.12, 0), 0.1, 0.07, major_seg=28, minor_seg=12, mat=2, scale=(1.0, 0.75, 0.9))
    m.sphere((0, 0.135, 0), 0.08, scale=(1.0, 0.6, 1.0), mat=2)
    for k in range(4):
        a = 2.2 + k * 0.6
        c = (math.cos(a) * 0.1, 0.12, math.sin(a) * 0.09)
        m.torus(c, 0.066, 0.007, axis="x", major_seg=16, minor_seg=4, mat=3,
                rotate=("Y", -(math.degrees(a) + 90.0), c), scale=(1.0, 0.8, 1.0))
    # Cabeza apoyada delante, ojos cerrados, orejas y hocico.
    head = (0.07, 0.17, 0.11)
    m.sphere(head, 0.065, scale=(1.05, 0.85, 0.95), mat=2)
    m.sphere((head[0] + 0.015, head[1] - 0.012, head[2] + 0.05), 0.03, scale=(1.1, 0.75, 0.8), mat=2)
    m.sphere((head[0] + 0.015, head[1] - 0.004, head[2] + 0.077), 0.007, mat=4)
    for sx in (-1, 1):
        ex = head[0] + sx * 0.03
        m.lathe([(0.0, 0.0), (0.024, 0.0), (0.0, 0.045)], 4, center=(ex, head[1] + 0.04, head[2] - 0.01), mat=2)
        m.lathe([(0.0, 0.0), (0.014, 0.0), (0.0, 0.03)], 4, center=(ex, head[1] + 0.043, head[2] - 0.002), mat=4)
        m.box((ex + 0.006, head[1] + 0.008, head[2] + 0.058), (0.018, 0.003, 0.003), bevel=0.0, mat=5)
    # Cola que rodea el cuerpo por delante y patitas bajo la cabeza.
    tail = []
    for k in range(9):
        a = -0.3 + k * 0.32
        tail.append((math.cos(a) * 0.17, 0.09 + 0.01 * math.sin(k), math.sin(a) * 0.15))
    m.tube(tail, 0.022, 8, mat=3, taper=0.5)
    for sx in (-1, 1):
        m.sphere((head[0] + sx * 0.035, 0.105, head[2] + 0.07), 0.022, scale=(1.0, 0.7, 1.4), mat=2)
    m.export(center_y=False)


# ---------------------------------------------------------------- premio: radio
def make_radio():
    reset_scene()
    m = Model("radio", 107)
    m.add_material("walnut", (0.38, 0.21, 0.11), 0.4)                    # 0 madera barnizada
    m.add_material("cloth", (0.82, 0.72, 0.52), 0.95)                    # 1 rejilla de tela
    m.add_material("brass", BRASS, 0.3, metallic=1.0)                    # 2
    emissive(m, "dial", (1.0, 0.78, 0.45), 2.5)                          # 3 dial encendido
    m.add_material("bakelite", (0.12, 0.08, 0.05), 0.35)                 # 4 mandos
    W, H, D = 0.3, 0.2, 0.15
    # Caja con la parte de arriba en arco, sobre un zócalo.
    m.box((0, H * 0.35, 0), (W, H * 0.7, D), grain="x", bevel=0.012, segments=3, mat=0)
    m.cylinder((0, H * 0.7, 0), W * 0.5, D, axis="z", mat=0, round_edge=0.012, segments=36, scale=(1.0, 0.55, 1.0))
    m.box((0, 0.012, 0), (W + 0.02, 0.024, D + 0.015), grain="x", bevel=0.006, segments=2, mat=0)
    # Rejilla del altavoz, con listones de madera delante.
    m.cylinder((0, H * 0.62, D * 0.5 + 0.001), W * 0.36, 0.004, axis="z", mat=1, segments=32, scale=(1.0, 0.8, 1.0))
    for k in range(-2, 3):
        m.box((k * 0.035, H * 0.62, D * 0.5 + 0.006), (0.008, 0.13 - abs(k) * 0.018, 0.006), bevel=0.002, segments=1, mat=0)
    # Dial iluminado con marco de latón y dos mandos.
    m.box((0, 0.06, D * 0.5 + 0.004), (0.13, 0.035, 0.004), bevel=0.0, mat=3)
    m.box((0, 0.06, D * 0.5 + 0.002), (0.145, 0.047, 0.003), bevel=0.0, mat=2)
    for sx in (-1, 1):
        m.cylinder((sx * 0.11, 0.055, D * 0.5 + 0.012), 0.018, 0.022, axis="z", mat=4, round_edge=0.005, segments=18)
        m.cylinder((sx * 0.11, 0.055, D * 0.5 + 0.024), 0.006, 0.004, axis="z", mat=2, segments=10)
    m.export(center_y=False)


# ---------------------------------------------------------------- premio: jarrón con flores
def make_flower_vase():
    import random
    reset_scene()
    m = Model("flower_vase", 108)
    m.add_material("ceramic", (0.33, 0.55, 0.62), 0.25)                  # 0 cerámica azul
    m.add_material("stem", (0.33, 0.52, 0.25), 0.8)                      # 1 tallos
    m.add_material("petal", (0.98, 0.97, 0.92), 0.7)                     # 2 margarita
    m.add_material("heart", (0.95, 0.74, 0.20), 0.6)                     # 3 centro amarillo
    m.add_material("lavender", (0.62, 0.50, 0.80), 0.8)                  # 4
    m.lathe([(0.0, 0.0), (0.045, 0.0), (0.065, 0.04), (0.07, 0.09), (0.05, 0.15), (0.032, 0.18),
             (0.04, 0.2), (0.036, 0.2), (0.026, 0.18), (0.0, 0.17)], 28, mat=0)
    rng = random.Random(9)
    for k in range(7):
        a = k * 2.4
        lean = 0.05 + rng.random() * 0.05
        top = (math.cos(a) * lean, 0.34 + rng.random() * 0.08, math.sin(a) * lean)
        m.tube([(0, 0.15, 0), (top[0] * 0.5, 0.25, top[2] * 0.5), top], 0.0035, 5, mat=1, cap=True)
        if k % 3 == 2:
            for j in range(5):
                m.sphere((top[0], top[1] + j * 0.012, top[2]), 0.008, scale=(1.0, 1.3, 1.0), segments=6, rings=4, mat=4)
            continue
        m.sphere(top, 0.011, scale=(1.0, 0.5, 1.0), segments=10, rings=6, mat=3)
        for j in range(8):
            b = j * math.tau / 8
            p = (top[0] + math.cos(b) * 0.02, top[1] - 0.002, top[2] + math.sin(b) * 0.02)
            m.sphere(p, 0.011, scale=(1.0, 0.25, 0.45), segments=8, rings=4, mat=2, rotate=("Y", -math.degrees(b), p))
    m.export(center_y=False)


# ---------------------------------------------------------------- premio: juego de té
def make_tea_set():
    reset_scene()
    m = Model("tea_set", 109)
    m.add_material("enamel", (0.90, 0.36, 0.30), 0.3)                    # 0 rojo esmaltado
    m.add_material("china", (0.97, 0.95, 0.90), 0.25)                    # 1 porcelana
    m.add_material("tea", (0.45, 0.22, 0.08), 0.1)                       # 2
    # Tetera: cuerpo, tapa con pomo, pitorro y asa.
    m.lathe([(0.0, 0.0), (0.05, 0.0), (0.075, 0.03), (0.08, 0.07), (0.068, 0.11), (0.04, 0.125), (0.0, 0.126)], 28, mat=0)
    m.lathe([(0.0, 0.135), (0.042, 0.125), (0.04, 0.122), (0.0, 0.122)], 24, mat=0)
    m.sphere((0, 0.145, 0), 0.013, mat=1)
    m.tube([(0.07, 0.06, 0), (0.1, 0.09, 0), (0.12, 0.125, 0)], 0.012, 8, mat=0, taper=0.4)
    m.tube([(-0.065, 0.1, 0), (-0.11, 0.1, 0), (-0.115, 0.06, 0), (-0.07, 0.035, 0)], 0.008, 6, mat=0)
    # Dos tazas con plato delante.
    for cx, cz in ((-0.05, 0.13), (0.09, 0.12)):
        m.cylinder((cx, 0.004, cz), 0.045, 0.008, mat=1, round_edge=0.003, segments=24)
        m.lathe([(0.0, 0.008), (0.022, 0.008), (0.032, 0.03), (0.034, 0.05), (0.031, 0.05),
                 (0.029, 0.032), (0.0, 0.03)], 22, center=(cx, 0, cz), mat=1)
        m.cylinder((cx, 0.042, cz), 0.03, 0.003, mat=2, segments=20)
        m.torus((cx + 0.036, 0.03, cz), 0.012, 0.003, axis="z", major_seg=12, minor_seg=4, mat=1)
    m.export(center_y=False)


# ---------------------------------------------------------------- barrido: escoba
def vcol_material(m, name, roughness):
    """Material cuyo color sale de los vértices (atributo "Col"): el exportador glTF lo lleva como COLOR_0.
    En Godot hay que activar vertex_color_use_as_albedo y vertex_color_is_srgb (lo hace ShopSweep)."""
    m.add_material(name, (1.0, 1.0, 1.0), roughness)
    nt = m.materials[-1].node_tree
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], nt.nodes.get("Principled BSDF").inputs["Base Color"])


def make_broom():
    """Escoba de paja: mango de madera algo cónico con la veta pintada en los vértices, la paja recogida
    alrededor del mango con un cordel enrollado y un abanico denso de mechones algo curvados, cosido con
    dos pasadas de cordel. Origen = punta de la paja en el suelo; el abanico queda en el plano XY."""
    import random
    reset_scene()
    m = Model("broom", 110)
    vcol_material(m, "wood", 0.55)                                       # 0 mango (veta en los vértices)
    vcol_material(m, "straw", 0.9)                                       # 1 paja (tono de cada mechón)
    m.add_material("band", (0.70, 0.20, 0.18), 0.6)                      # 2 cordel rojo
    col = m.bm.verts.layers.float_color.new("Col")
    rng = random.Random(110)

    def paint(build, color):
        """Construye una pieza y pinta sus vértices nuevos con color(p) (p en ejes de Godot, color lineal)."""
        n0 = len(m.bm.verts)
        build()
        m.bm.verts.ensure_lookup_table()
        for i in range(n0, len(m.bm.verts)):
            v = m.bm.verts[i]
            v[col] = (*color((v.co.x, v.co.z, -v.co.y)), 1.0)

    def mix(a, b, t):
        return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

    # -- mango: algo más grueso abajo, remate redondeado. Veta: vetas largas que serpentean.
    WOOD_LIGHT = (0.70, 0.45, 0.24)
    WOOD_DARK = (0.22, 0.11, 0.04)

    def wood(p):
        a = math.atan2(p[2], p[0])
        y = p[1]
        # Fondo con aguas suaves y, encima, vetas oscuras finas (umbral) como pinceladas.
        tone = 0.5 + 0.5 * math.sin(a * 2.0 + 1.5 * math.sin(y * 3.0) + y * 1.5)
        streak = 0.5 + 0.5 * math.sin(a * 7.0 + 2.5 * math.sin(y * 3.0 + a * 2.0) + y * 4.0)
        lines = max(0.0, min(1.0, (streak - 0.5) / 0.25))
        knot = math.exp(-((y - 0.78) ** 2) / 0.0012) * max(0.0, math.cos(a - 1.0)) ** 2
        t = 0.25 * tone + 0.8 * lines + 0.8 * knot
        return mix(WOOD_LIGHT, WOOD_DARK, min(t, 1.0))

    prof = []
    y = 0.26
    while y < 1.30:
        prof.append((0.0148 - 0.0026 * (y - 0.26) / 1.05, y))
        y += 0.06
    prof += [(0.0122, 1.31), (0.0112, 1.322), (0.0078, 1.330), (0.0, 1.334)]
    paint(lambda: m.lathe([(0.0, 0.26)] + prof, 20, mat=0), wood)

    # -- abanico: media anchura y medio grosor a cada altura (estrecho arriba, se abre abajo).
    TOP = 0.285

    def half_w(yy):
        return 0.045 + 0.10 * max(0.0, 1.0 - yy / TOP) ** 0.8

    def half_t(yy):
        return 0.014 + 0.009 * min(1.0, yy / TOP)

    STRAW = [(0.92, 0.77, 0.43), (0.86, 0.72, 0.38), (0.95, 0.83, 0.50), (0.82, 0.75, 0.38), (0.90, 0.69, 0.36)]

    def straw_tone():
        base = STRAW[rng.randrange(len(STRAW))]
        k = 0.85 + rng.random() * 0.22
        return tuple(c * k for c in base)

    def straw_shade(tone):
        # Más oscura dentro del atado y un poco tostada en las puntas que barren.
        def f(p):
            t = p[1] / TOP
            dark = 0.8 + 0.2 * min(1.0, t * 5.0) - 0.18 * max(0.0, t - 0.75) / 0.25
            return tuple(c * dark for c in tone)
        return f

    # Relleno: una lámina cónica que tapa los huecos entre mechones.
    paint(lambda: m.box((0, 0.15, 0), (0.09, 0.25, 0.007), bevel=0.0, taper=2.5, mat=1),
          straw_shade((0.66, 0.52, 0.27)))

    def clump(x_top, x_bot, z, tip_y, bow, rx, rz):
        part = bmesh.new()
        rings = []
        n = 4
        for i in range(n + 1):
            t = i / n                                   # 0 arriba, 1 en la punta
            yy = TOP + 0.01 - (TOP + 0.01 - tip_y) * t
            spread = 1.0 - (1.0 - t) ** 1.6             # se abre sobre todo en la mitad de abajo
            cx = x_top + (x_bot - x_top) * spread
            cz = z * (0.7 + 0.5 * t) + bow * math.sin(math.pi * t * 0.9)
            k = 1.0 - 0.45 * t ** 3
            ring = []
            for s in range(5):
                a = math.tau * s / 5 + 0.3
                ring.append(part.verts.new(Vector((cx + math.cos(a) * rx * k, yy, cz + math.sin(a) * rz * k))))
            rings.append(ring)
        for i in range(n):
            for s in range(5):
                s2 = (s + 1) % 5
                part.faces.new((rings[i][s], rings[i][s2], rings[i + 1][s2], rings[i + 1][s]))
        tip = part.verts.new(Vector((sum(v.co.x for v in rings[-1]) / 5, tip_y - 0.003,
                                     sum(v.co.z for v in rings[-1]) / 5)))
        for s in range(5):
            part.faces.new((rings[-1][s], rings[-1][(s + 1) % 5], tip))
        m._finish(part, "y", 1, None)

    # Cuatro filas de mechones al tresbolillo, con las puntas desiguales.
    N = 14
    for row, z in enumerate((-0.0115, -0.0045, 0.0045, 0.0115)):
        for i in range(N):
            u = (i + 0.5 + (0.5 if row % 2 else 0.0) - 0.25 + rng.uniform(-0.18, 0.18)) / N * 2.0 - 1.0
            u = max(-0.985, min(0.985, u))
            tip_y = 0.003 + rng.random() * 0.012 + 0.006 * u * u
            x_bot = u * (half_w(0.0) - 0.006)
            x_top = u * (half_w(TOP) - 0.012)
            bow = rng.uniform(-0.004, 0.006)
            tone = straw_tone()
            paint(lambda: clump(x_top, x_bot, z, tip_y, bow, 0.0115, 0.0036), straw_shade(tone))

    # -- paja recogida alrededor del mango (achatada como el abanico) y cordel enrollado en espiral.
    SQ = 0.45
    shoulder = [(0.0, 0.225), (0.056, 0.23), (0.054, 0.27), (0.044, 0.30), (0.03, 0.33), (0.0195, 0.355), (0.0165, 0.39), (0.0, 0.39)]

    def shoulder_r(yy):
        for (r0, y0), (r1, y1) in zip(shoulder, shoulder[1:]):
            if y0 <= yy <= y1 and y1 > y0:
                return r0 + (r1 - r0) * (yy - y0) / (y1 - y0)
        return shoulder[-2][0]

    def gathered(p):
        a = math.atan2(p[2], p[0])
        k = int(round((a + math.pi) / math.tau * 24.0))
        tone = STRAW[(k * 3) % len(STRAW)]
        return tuple(c * (0.8 + 0.08 * (k % 3)) for c in tone)

    def build_shoulder():
        # Achatada, pero sin hundirse en el mango: el grosor nunca baja del radio del mango.
        n0 = len(m.bm.verts)
        m.lathe(shoulder, 24, mat=1, scale=(1.0, 1.0, SQ))
        m.bm.verts.ensure_lookup_table()
        for i in range(n0, len(m.bm.verts)):
            v = m.bm.verts[i]
            r = math.hypot(v.co.x, v.co.y / SQ)
            if r > 1e-6:
                v.co.y = v.co.y / (SQ * r) * max(r * SQ, 0.0158)

    paint(build_shoulder, gathered)
    helix = []
    turns, y0, y1 = 3.5, 0.338, 0.382
    steps = int(turns * 11)
    for k in range(steps + 1):
        t = k / steps
        yy = y0 + (y1 - y0) * t
        a = math.tau * turns * t
        r = shoulder_r(yy) + 0.0022
        helix.append((math.cos(a) * r, yy, math.sin(a) * max(r * SQ, 0.018)))
    paint(lambda: m.tube(helix, 0.0024, 5, mat=2), lambda p: (1.0, 1.0, 1.0))

    # -- dos pasadas de cosido a lo ancho del abanico, con las puntadas que asoman por las dos caras.
    for yy in (0.233, 0.168):
        w = half_w(yy) + 0.004
        th = max(half_t(yy) + 0.0015, 0.027 if yy > 0.2 else 0.0)
        paint(lambda: m.box((0, yy, 0), (w * 2.0, 0.007, th * 2.0), bevel=0.0015, segments=1, mat=2),
              lambda p: (1.0, 1.0, 1.0))
        nst = int(w * 2.0 / 0.024)
        for j in range(nst):
            x = -w + (j + 0.5) * (w * 2.0 / nst)
            for sz in (-1, 1):
                paint(lambda: m.box((x, yy, sz * (th + 0.0008)), (0.004, 0.016, 0.002), bevel=0.0, mat=2,
                                    rotate=("Z", 12.0, (x, yy, 0))), lambda p: (1.0, 1.0, 1.0))
    m.export(shade_angle=75.0, center_y=False)


# ---------------------------------------------------------------- barrido: recogedor
def make_dustpan():
    reset_scene()
    m = Model("dustpan", 111)
    m.add_material("enamel", (0.27, 0.52, 0.47), 0.35, double_sided=True)   # 0 chapa esmaltada
    m.add_material("wood", (0.62, 0.42, 0.24), 0.6)                         # 1 mango
    m.add_material("rim", (0.85, 0.80, 0.68), 0.3)                          # 2 filo claro
    # Pala: suelo inclinado hacia el borde, laterales y respaldo.
    m.box((0, 0.008, -0.11), (0.28, 0.01, 0.22), bevel=0.002, mat=0, rotate=("X", -3.0, (0, 0, 0)))
    m.box((0, 0.05, -0.218), (0.28, 0.09, 0.01), bevel=0.002, mat=0)
    for sx in (-1, 1):
        m.box((sx * 0.138, 0.032, -0.115), (0.01, 0.05, 0.21), bevel=0.002, taper=1.0, mat=0,
              rotate=("X", 8.0, (sx * 0.138, 0.0, -0.22)))
    m.box((0, 0.004, 0.0), (0.28, 0.006, 0.014), bevel=0.002, mat=2)
    # Mango largo (se usa de pie) con su pomo.
    m.tube([(0, 0.08, -0.225), (0, 0.45, -0.24), (0, 0.84, -0.255)], 0.012, sides=10, mat=1)
    m.sphere((0, 0.86, -0.256), 0.018, segments=10, rings=6, mat=1)
    m.export(center_y=False)


# ---------------------------------------------------------------- barrido: papelera
def make_waste_bin():
    reset_scene()
    m = Model("waste_bin", 112)
    m.add_material("wicker", (0.70, 0.51, 0.29), 0.85, double_sided=True)  # 0 mimbre
    m.add_material("rim", (0.52, 0.34, 0.18), 0.8)                         # 1 borde trenzado
    # Cuerpo abierto (pared con grosor) que se abre hacia arriba, aros trenzados y borde.
    m.lathe([(0.0, 0.0), (0.125, 0.0), (0.135, 0.01), (0.165, 0.34), (0.152, 0.34), (0.124, 0.03), (0.0, 0.03)],
            28, mat=0)
    for k in range(4):
        y = 0.06 + k * 0.075
        m.torus((0, y, 0), 0.131 + y * 0.09, 0.006, major_seg=28, minor_seg=5, mat=0)
    m.torus((0, 0.342, 0), 0.159, 0.014, major_seg=28, minor_seg=6, mat=1)
    m.torus((0, 0.012, 0), 0.128, 0.01, major_seg=28, minor_seg=5, mat=1)
    m.export(center_y=False)


if __name__ == "__main__":
    for fn in (make_pendant_lamp, make_dress_form, make_sewing_machine, make_cash_register, make_shop_door,
               make_cat_basket, make_radio, make_flower_vase, make_tea_set, make_broom, make_dustpan, make_waste_bin):
        fn()
