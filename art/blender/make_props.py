"""Genera el atrezo de la mercería (original) y lo exporta a GLB para Godot.

Uso:
  blender --background --factory-startup --python art/blender/make_props.py -- art/models

Modelos:
  pendant_lamp     lámpara colgante esmaltada (origen = bombilla)
  dress_form       maniquí de costura sobre trípode (origen = suelo)
  sewing_machine   máquina de coser antigua, negra con filetes dorados (origen = base)
  cash_register    caja registradora de latón (origen = base)
  shop_door        puerta de entrada con cristal, placa y tirador (origen = suelo, cara hacia +Z)
Se modela en ejes de Godot (Y arriba, Z hacia delante). Los materiales viajan en el GLB.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
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
    reset_scene()
    m = Model("shop_door", 105)
    m.add_material("paint", (0.20, 0.38, 0.33), 0.45)                    # 0 verde de la casa
    m.add_material("frame", (0.93, 0.88, 0.78), 0.55)                    # 1 marco crema
    m.add_material("glass", (0.85, 0.95, 1.0), 0.05)                     # 2
    m.add_material("brass", BRASS, 0.3, metallic=1.0)                    # 3
    W, H, T = 1.0, 2.15, 0.05
    # Marco: jambas y dintel salientes de la pared.
    for sx in (-1, 1):
        m.box((sx * (W / 2 + 0.05), (H + 0.1) / 2, 0.03), (0.1, H + 0.1, 0.06), bevel=0.008, segments=2, mat=1)
    m.box((0, H + 0.075, 0.03), (W + 0.2, 0.15, 0.06), grain="x", bevel=0.01, segments=2, mat=1)
    # Hoja: paneles inferiores, cristal arriba con travesaño y cuarterones.
    z = 0.012
    m.box((-W / 2 + 0.04, H / 2, z), (0.08, H, T), bevel=0.006, segments=2, mat=0)
    m.box((W / 2 - 0.04, H / 2, z), (0.08, H, T), bevel=0.006, segments=2, mat=0)
    m.box((0, 0.06, z), (W, 0.12, T), grain="x", bevel=0.006, segments=2, mat=0)
    m.box((0, 0.9, z), (W, 0.12, T), grain="x", bevel=0.006, segments=2, mat=0)
    m.box((0, H - 0.05, z), (W, 0.1, T), grain="x", bevel=0.006, segments=2, mat=0)
    m.box((0, 0.48, z - 0.005), (W - 0.16, 0.72, T * 0.6), bevel=0.0, mat=0)
    for sx in (-1, 1):
        m.box((sx * 0.21, 0.48, z + 0.012), (0.3, 0.6, 0.012), bevel=0.012, segments=3, mat=0)
    m.box((0, (0.96 + H - 0.1) / 2, z), (W - 0.16, H - 0.1 - 0.96, 0.008), bevel=0.0, mat=2)
    m.box((0, (0.96 + H - 0.1) / 2, z + 0.006), (0.03, H - 0.1 - 0.96, 0.02), bevel=0.003, segments=1, mat=0)
    # Placa de empuje, pomo y buzón.
    m.box((0.36, 1.05, z + 0.03), (0.06, 0.22, 0.004), bevel=0.002, segments=1, mat=3)
    m.sphere((0.36, 1.0, z + 0.06), 0.028, mat=3)
    m.cylinder((0.36, 1.0, z + 0.04), 0.008, 0.04, axis="z", mat=3, segments=10)
    m.box((0, 0.62, z + 0.03), (0.26, 0.05, 0.006), grain="x", bevel=0.003, segments=1, mat=3)
    # Campanilla sobre la puerta, colgada de un brazo de latón.
    m.tube([(0.3, H + 0.12, 0.06), (0.3, H + 0.12, 0.16)], 0.006, 6, mat=3, cap=False)
    m.lathe([(0.0, H + 0.11), (0.025, H + 0.1), (0.045, H + 0.03), (0.05, H + 0.015), (0.0, H + 0.015)], 18,
            center=(0.3, -H - 0.01 + H, 0.16), mat=3)
    m.export(center_y=False)


if __name__ == "__main__":
    for fn in (make_pendant_lamp, make_dress_form, make_sewing_machine, make_cash_register, make_shop_door):
        fn()
