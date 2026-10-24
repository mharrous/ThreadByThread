"""Genera los modelos de la calle que se ve por la ventana (originales) y los exporta a GLB.

Uso:
  blender --background --factory-startup --python art/blender/make_street.py -- art/models/street

Vehículos (miran a +Z, origen en el suelo, ruedas aparte para poder girarlas), ciclistas y
motoristas (por piezas, para animar el pedaleo), los dos peatones y el perro (con esqueleto y
animación, al estilo de la clienta), casas, farolas, árboles y seto.
Las superficies se llaman "paint", "glass", "trim", "tire", "chrome", "light_front",
"light_rear", "wall", "roof", "door", "skin", "hair", "shirt", "pants", "shoes", "clothes",
"fur"...: scripts/room/street_assets.gd y street_life.gd les ponen el material y el color de cada ejemplar.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import Model, OUT_DIR, Rig, reset_scene  # noqa: E402
from mathutils import Vector  # noqa: E402

os.makedirs(OUT_DIR, exist_ok=True)


def mat(m, name, color, rough=0.6, metallic=0.0, double=False):
    m.add_material(name, color, rough, double_sided=double, metallic=metallic)


def new(name, seed=1):
    reset_scene()
    return Model(name, seed)


# ------------------------------------------------------------------ ruedas
def make_wheel(name, radius, width, minor_rim=0.0):
    m = new(name, 3)
    mat(m, "tire", (0.05, 0.05, 0.055), 0.85)
    mat(m, "chrome", (0.8, 0.8, 0.83), 0.3, 1.0)
    r_in = radius * 0.56
    w2 = width * 0.5
    m.lathe([(r_in, -w2), (radius * 0.92, -w2), (radius, -w2 + width * 0.16), (radius, w2 - width * 0.16),
             (radius * 0.92, w2), (r_in, w2)], segments=32, axis="x", mat=0, closed=True)
    m.cylinder((0, 0, 0), r_in + 0.004, width * 0.85, axis="x", mat=1, segments=28)
    for k in range(5):
        a = math.tau * k / 5
        m.box((0, math.sin(a) * r_in * 0.55, math.cos(a) * r_in * 0.55), (width * 0.9, r_in * 0.2, r_in * 0.95),
              bevel=0.002, segments=1, mat=1, rotate=("X", -math.degrees(a), (0, 0, 0)))
    m.cylinder((0, 0, 0), r_in * 0.22, width * 0.95, axis="x", mat=1, segments=14)
    m.export(center_y=False)


def make_bike_wheel(name="bike_wheel", radius=0.34):
    m = new(name, 4)
    mat(m, "tire", (0.06, 0.06, 0.065), 0.9)
    mat(m, "chrome", (0.75, 0.76, 0.8), 0.35, 1.0)
    m.torus((0, 0, 0), radius - 0.012, 0.014, axis="x", major_seg=36, minor_seg=8, mat=0)
    m.torus((0, 0, 0), radius - 0.03, 0.006, axis="x", major_seg=36, minor_seg=6, mat=1)
    for k in range(18):
        a = math.tau * k / 18
        p1 = (0, math.sin(a) * 0.02, math.cos(a) * 0.02)
        p2 = (0.0, math.sin(a) * (radius - 0.035), math.cos(a) * (radius - 0.035))
        m.tube([p1, p2], 0.0012, 4, mat=1, cap=False)
    m.cylinder((0, 0, 0), 0.022, 0.07, axis="x", mat=1, segments=12)
    m.export(center_y=False)


# ------------------------------------------------------------------ coches
def car(name, L, W, H, wr, belt, cabin_z0, cabin_z1, hood=True, boot=True):
    m = new(name, 11)
    mat(m, "paint", (0.7, 0.1, 0.1), 0.28, 0.5)
    mat(m, "glass", (0.08, 0.1, 0.13), 0.04, 0.0)
    mat(m, "trim", (0.05, 0.05, 0.06), 0.6)
    mat(m, "light_front", (1.0, 0.95, 0.8), 0.2)
    mat(m, "light_rear", (0.85, 0.04, 0.05), 0.3)
    mat(m, "chrome", (0.8, 0.8, 0.83), 0.3, 1.0)
    c = 0.17
    hl = L / 2
    # Carrocería baja
    m.box((0, (c + belt) / 2, 0), (W, belt - c, L), grain="z", bevel=0.07, segments=3, mat=0)
    # Capó y maletero (ligeramente más altos y estrechos)
    if hood:
        m.box((0, belt + 0.006, (cabin_z1 + hl) / 2 - 0.02), (W * 0.94, 0.06, hl - cabin_z1 + 0.02), grain="z", bevel=0.03, segments=2, mat=0)
    if boot:
        m.box((0, belt + 0.006, (cabin_z0 - hl) / 2 + 0.02), (W * 0.94, 0.06, cabin_z0 + hl + 0.02), grain="z", bevel=0.03, segments=2, mat=0)
    # Habitáculo acristalado, algo más estrecho arriba
    ch = H - belt - 0.05
    cl = cabin_z1 - cabin_z0
    m.box((0, belt + ch / 2 + 0.0, (cabin_z0 + cabin_z1) / 2), (W * 0.9, ch, cl), grain="z", bevel=0.05, segments=2, mat=1, taper=0.86)
    # Techo y montantes
    m.box((0, H - 0.025, (cabin_z0 + cabin_z1) / 2), (W * 0.82, 0.055, cl + 0.02), grain="z", bevel=0.03, segments=2, mat=0)
    for sx in (-1, 1):
        for zz in (cabin_z0 + 0.04, (cabin_z0 + cabin_z1) / 2, cabin_z1 - 0.04):
            m.box((sx * (W * 0.44 - 0.01), belt + ch / 2, zz), (0.045, ch, 0.07), bevel=0.01, segments=1, mat=0, taper=0.95)
    # Parachoques, luces, parrilla, retrovisores
    for sz, (lt, lm) in ((1, ("light_front", 3)), (-1, ("light_rear", 4))):
        m.box((0, c + 0.13, sz * (hl - 0.02)), (W * 0.99, 0.2, 0.14), bevel=0.04, segments=2, mat=2)
        for sx in (-1, 1):
            m.box((sx * W * 0.34, belt - 0.14, sz * (hl - 0.01)), (W * 0.2, 0.1, 0.05), bevel=0.02, segments=2, mat=lm)
    m.box((0, belt - 0.16, hl - 0.005), (W * 0.3, 0.11, 0.04), bevel=0.01, segments=1, mat=2)
    for sx in (-1, 1):
        m.box((sx * (W * 0.5 + 0.02), belt + 0.12, cabin_z1 - 0.05), (0.1, 0.07, 0.12), bevel=0.02, segments=2, mat=0)
    # Pasos de rueda (discos oscuros)
    for axle in (hl - L * 0.2, -(hl - L * 0.19)):
        for sx in (-1, 1):
            m.cylinder((sx * (W / 2 + 0.002), wr, axle), wr * 1.16, 0.006, axis="x", mat=2, segments=26)
    m.export(center_y=False)


def make_van():
    m = new("car_van", 12)
    mat(m, "paint", (0.9, 0.9, 0.9), 0.35, 0.3)
    mat(m, "glass", (0.08, 0.1, 0.13), 0.04, 0.0)
    mat(m, "trim", (0.05, 0.05, 0.06), 0.6)
    mat(m, "light_front", (1.0, 0.95, 0.8), 0.2)
    mat(m, "light_rear", (0.85, 0.04, 0.05), 0.3)
    mat(m, "chrome", (0.8, 0.8, 0.83), 0.3, 1.0)
    L, W, H, c = 5.0, 2.0, 2.15, 0.22
    hl = L / 2
    m.box((0, (c + 1.08) / 2, 0), (W, 1.08 - c, L), grain="z", bevel=0.08, segments=3, mat=0)
    m.box((0, 1.08 + (H - 1.08) / 2, -0.35), (W * 0.99, H - 1.08, L - 1.5), grain="z", bevel=0.09, segments=3, mat=0)   # caja
    m.box((0, 1.08 + 0.55, hl - 1.05), (W * 0.94, 1.1, 1.3), grain="z", bevel=0.09, segments=3, mat=0, taper=0.92)      # cabina
    # Parabrisas inclinado y ventanas laterales
    m.box((0, 1.62, hl - 0.52), (W * 0.82, 0.78, 0.04), bevel=0.02, segments=1, mat=1, rotate=("X", -28.0, (0, 1.62, hl - 0.52)))
    for sx in (-1, 1):
        m.box((sx * (W * 0.47 + 0.004), 1.58, hl - 1.15), (0.03, 0.62, 0.95), bevel=0.01, segments=1, mat=1)
    for sz, (lt, lm) in ((1, ("front", 3)), (-1, ("rear", 4))):
        m.box((0, c + 0.14, sz * (hl - 0.02)), (W * 0.99, 0.22, 0.16), bevel=0.04, segments=2, mat=2)
        for sx in (-1, 1):
            m.box((sx * W * 0.36, 0.78, sz * (hl - 0.005)), (W * 0.16, 0.14, 0.05), bevel=0.02, segments=2, mat=lm)
    for sx in (-1, 1):
        m.box((sx * (W * 0.5 + 0.03), 1.55, hl - 0.95), (0.12, 0.2, 0.1), bevel=0.02, segments=2, mat=0)
    for axle in (hl - 1.0, -(hl - 1.0)):
        for sx in (-1, 1):
            m.cylinder((sx * (W / 2 + 0.002), 0.36, axle), 0.42, 0.006, axis="x", mat=2, segments=26)
    m.export(center_y=False)


# ------------------------------------------------------------------ personas
def make_person_torso():
    m = new("person_torso", 31)
    mat(m, "skin", (0.85, 0.65, 0.5), 0.6)
    mat(m, "hair", (0.25, 0.17, 0.1), 0.8)
    mat(m, "shirt", (0.2, 0.4, 0.7), 0.8)
    mat(m, "pants", (0.18, 0.2, 0.28), 0.8)
    m.box((0, 0.0, 0), (0.34, 0.2, 0.2), bevel=0.04, segments=2, mat=3)                       # cadera
    m.box((0, 0.34, 0), (0.42, 0.52, 0.22), bevel=0.045, segments=2, mat=2, taper=0.82)       # torso
    m.cylinder((0, 0.64, 0), 0.05, 0.1, mat=0, segments=10)                                    # cuello
    m.sphere((0, 0.77, 0), 0.105, scale=(0.92, 1.1, 1.0), segments=14, rings=10, mat=0)        # cabeza
    m.sphere((0, 0.83, -0.012), 0.112, scale=(0.98, 0.72, 1.05), segments=14, rings=8, mat=1)  # pelo
    m.export(center_y=False)


def make_person_arm():
    m = new("person_arm", 32)
    mat(m, "skin", (0.85, 0.65, 0.5), 0.6)
    mat(m, "shirt", (0.2, 0.4, 0.7), 0.8)
    m.cylinder((0, -0.15, 0), 0.047, 0.30, mat=1, segments=10, round_edge=0.01)               # manga
    m.cylinder((0, -0.43, 0), 0.04, 0.26, mat=0, segments=10)                                  # antebrazo
    m.sphere((0, -0.58, 0), 0.047, segments=8, rings=6, mat=0)                                 # mano
    m.export(center_y=False)


def make_person_leg():
    m = new("person_leg", 33)
    mat(m, "pants", (0.18, 0.2, 0.28), 0.8)
    mat(m, "shoes", (0.12, 0.1, 0.1), 0.6)
    m.cylinder((0, -0.22, 0), 0.075, 0.44, mat=0, segments=10, round_edge=0.01)
    m.cylinder((0, -0.63, 0), 0.058, 0.40, mat=0, segments=10)
    m.box((0, -0.86, 0.045), (0.095, 0.07, 0.25), bevel=0.02, segments=2, mat=1)
    m.export(center_y=False)


def make_helmet():
    m = new("moto_helmet", 34)
    mat(m, "paint", (0.1, 0.1, 0.12), 0.25, 0.3)
    mat(m, "glass", (0.05, 0.07, 0.1), 0.05)
    m.sphere((0, 0.0, 0), 0.13, scale=(1.0, 1.0, 1.1), segments=16, rings=10, mat=0)
    m.box((0, -0.01, 0.1), (0.2, 0.07, 0.06), bevel=0.02, segments=2, mat=1)
    m.export(center_y=False)


# ------------------------------------------------------------------ peatones y perro
# Al estilo de la clienta (make_customer.py): una malla con esqueleto sencillo (cada pieza pesada
# entera a su hueso) y animaciones de common.Rig a 12 fps. Origen = suelo, miran hacia +Z.
# Huesos de las personas: los de la clienta más hand_l / hand_r (el centro de la mano, donde
# street_life.gd engancha la correa). Superficies: skin, hair, clothes, pants, details, accent.
# El perro: body, head (su cabeza está en el collar), tail y leg_fl / leg_fr / leg_bl / leg_br.
# Superficies: fur, fur_light, details, collar. El juego cambia el tono de "skin" y de "fur".

SKIN, HAIR, CLOTHES, PANTS, DETAILS, ACCENT = range(6)


def person_bones(hip_y, neck_y, head_top, shoulder_x, elbow_y, wrist_y, hand_y, leg_x):
    return [
        ("hips", (0.0, hip_y, 0.0), (0.0, hip_y + 0.12, 0.0), None),
        ("spine", (0.0, hip_y + 0.12, 0.0), (0.0, neck_y, 0.0), "hips"),
        ("head", (0.0, neck_y + 0.04, 0.0), (0.0, head_top, 0.0), "spine"),
        ("upper_arm_l", (shoulder_x, neck_y - 0.065, 0.0), (shoulder_x + 0.025, elbow_y, 0.01), "spine"),
        ("forearm_l", (shoulder_x + 0.025, elbow_y, 0.01), (shoulder_x + 0.035, wrist_y, 0.04), "upper_arm_l"),
        ("hand_l", (shoulder_x + 0.037, hand_y, 0.045), (shoulder_x + 0.04, hand_y - 0.06, 0.05), "forearm_l"),
        ("upper_arm_r", (-shoulder_x, neck_y - 0.065, 0.0), (-shoulder_x - 0.025, elbow_y, 0.01), "spine"),
        ("forearm_r", (-shoulder_x - 0.025, elbow_y, 0.01), (-shoulder_x - 0.035, wrist_y, 0.04), "upper_arm_r"),
        ("hand_r", (-shoulder_x - 0.037, hand_y, 0.045), (-shoulder_x - 0.04, hand_y - 0.06, 0.05), "forearm_r"),
        ("thigh_l", (leg_x, hip_y, 0.0), (leg_x, (hip_y + 0.07) * 0.5 + 0.02, 0.0), "hips"),
        ("shin_l", (leg_x, (hip_y + 0.07) * 0.5 + 0.02, 0.0), (leg_x, 0.07, 0.0), "thigh_l"),
        ("thigh_r", (-leg_x, hip_y, 0.0), (-leg_x, (hip_y + 0.07) * 0.5 + 0.02, 0.0), "hips"),
        ("shin_r", (-leg_x, (hip_y + 0.07) * 0.5 + 0.02, 0.0), (-leg_x, 0.07, 0.0), "thigh_r"),
    ]


def bone(bones, name):
    return next(b for b in bones if b[0] == name)


def lerp3(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def person_face(m, cy, r, nose_r=0.022):
    """Cara como la de la clienta: nariz, orejas, ojos y sonrisa. cy = centro de la cabeza."""
    zf = r * 0.92
    m.sphere((0.0, cy - 0.015, r + 0.008), nose_r, scale=(0.9, 1.0, 0.8), segments=8, rings=5, mat=SKIN)
    for s in (-1, 1):
        m.sphere((s * r, cy - 0.005, 0.0), 0.024, scale=(0.5, 1.0, 0.8), segments=8, rings=5, mat=SKIN)
        m.sphere((s * 0.041, cy + 0.015, zf - 0.004), 0.013, segments=8, rings=5, mat=DETAILS)
    m.tube([(-0.03, cy - 0.052, zf - 0.012), (-0.015, cy - 0.062, zf - 0.003), (0.0, cy - 0.065, zf - 0.001),
            (0.015, cy - 0.062, zf - 0.003), (0.03, cy - 0.052, zf - 0.012)], 0.0045, sides=4, mat=DETAILS)


def person_arms(m, bones, sleeve_r, cuff_t=0.8):
    """Mangas hasta la muñeca (pesadas al brazo y al antebrazo) y manos (al hueso de la mano)."""
    for side in ("l", "r"):
        up, fo, ha = bone(bones, "upper_arm_" + side), bone(bones, "forearm_" + side), bone(bones, "hand_" + side)
        m.bone = up[0]
        m.sphere(up[1], sleeve_r * 1.06, segments=10, rings=6, mat=CLOTHES)
        m.tube([up[1], up[2]], sleeve_r, sides=8, mat=CLOTHES, cap=False)
        m.bone = fo[0]
        m.sphere(fo[1], sleeve_r * 0.96, segments=10, rings=6, mat=CLOTHES)
        cuff = lerp3(fo[1], fo[2], cuff_t)
        m.tube([fo[1], cuff], sleeve_r * 0.92, sides=8, mat=CLOTHES)
        m.tube([cuff, fo[2]], 0.031, sides=8, mat=SKIN, cap=False)
        m.bone = ha[0]
        m.sphere(ha[1], 0.042, scale=(0.8, 1.0, 1.0), segments=10, rings=6, mat=SKIN)


def person_legs(m, bones, thigh_r, shin_r, shoe=(1.0, 0.85, 1.9)):
    for side in ("l", "r"):
        th, sh = bone(bones, "thigh_" + side), bone(bones, "shin_" + side)
        x = th[1][0]
        m.bone = th[0]
        m.tube([th[1], th[2]], thigh_r, sides=8, mat=PANTS, cap=False)
        m.bone = sh[0]
        m.sphere(sh[1], thigh_r * 0.9, segments=8, rings=5, mat=PANTS)
        m.tube([sh[1], (x, 0.085, 0.0)], shin_r, sides=8, mat=PANTS, taper=0.12, cap=False)
        m.sphere((x, 0.045, 0.035), 0.05, scale=shoe, segments=10, rings=6, mat=DETAILS)


def person_walk(m, arm_swing, stride=0.36, lean=0.03, bounce=0.016):
    """Ciclo de paso de 8 fotogramas (el 8 repite el 0) como el de la clienta, con los dos brazos sueltos."""
    m.action("walk", 8)
    for f in range(9):
        ph = math.tau * (f % 8) / 8.0
        s, c = math.sin(ph), math.cos(ph)
        rots = {
            "thigh_l": (-stride * s, 0.0, 0.0),
            "thigh_r": (stride * s, 0.0, 0.0),
            "shin_l": (0.55 * max(0.0, c), 0.0, 0.0),
            "shin_r": (0.55 * max(0.0, -c), 0.0, 0.0),
            "hips": (0.0, 0.07 * s, 0.0),
            "spine": (lean, -0.11 * s, 0.0),
            "head": (-lean, 0.05 * s, 0.0),
            "upper_arm_r": (-arm_swing * s, 0.0, 0.0),
            "forearm_r": (-0.12 - 0.12 * max(0.0, s), 0.0, 0.0),
            "upper_arm_l": (arm_swing * s, 0.0, 0.0),
            "forearm_l": (-0.12 - 0.12 * max(0.0, -s), 0.0, 0.0),
        }
        m.pose("walk", f, rots, {"hips": (0.0, bounce * abs(c) - bounce * 0.5, 0.0)})


def make_walker():
    """Un chico joven, alto y delgado: parka verde oliva con capucha, bufanda mostaza, pantalón marrón,
    zapatillas y pelo rizado oscuro. Va con paso largo y braceando."""
    reset_scene()
    bones = person_bones(0.94, 1.46, 1.80, 0.20, 1.14, 0.90, 0.855, 0.09)
    m = Rig("walker", bones, 35)
    m.add_material("skin", (0.86, 0.58, 0.44), 0.7)
    m.add_material("hair", (0.16, 0.09, 0.06), 0.85)
    m.add_material("clothes", (0.36, 0.38, 0.17), 0.9)
    m.add_material("pants", (0.30, 0.17, 0.10), 0.9)
    m.add_material("details", (0.20, 0.11, 0.12), 0.6)
    m.add_material("accent", (0.86, 0.55, 0.12), 0.9)

    # Cadera: pantalón (asoma bajo la parka).
    m.bone = "hips"
    m.lathe([(0.0, 1.06), (0.15, 1.06), (0.165, 0.98), (0.162, 0.88), (0.0, 0.86)],
            segments=12, mat=PANTS, scale=(1.0, 1.0, 0.8))

    # Tronco: parka hasta la cadera con cremallera, bolsillos y capucha caída; bufanda.
    m.bone = "spine"
    m.lathe([(0.0, 0.85), (0.19, 0.85), (0.193, 0.91), (0.178, 1.04), (0.184, 1.20), (0.19, 1.33),
             (0.168, 1.42), (0.105, 1.47), (0.0, 1.48)], segments=14, mat=CLOTHES, scale=(1.0, 1.0, 0.8))
    m.tube([(0.0, 0.86, 0.156), (0.0, 1.04, 0.146), (0.0, 1.20, 0.151), (0.0, 1.33, 0.156)], 0.006, sides=4, mat=DETAILS)
    for s in (-1, 1):
        m.box((s * 0.105, 0.96, 0.145), (0.085, 0.012, 0.03), bevel=0.004, segments=1, mat=DETAILS,
              rotate=("Y", s * 34.0, (s * 0.105, 0.96, 0.145)))
    m.sphere((0.0, 1.415, -0.115), 0.085, scale=(1.35, 0.75, 0.6), segments=10, rings=6, mat=CLOTHES)
    m.cylinder((0.0, 1.50, -0.005), 0.045, 0.1, segments=10, mat=SKIN)
    m.torus((0.0, 1.465, 0.0), 0.075, 0.032, major_seg=14, minor_seg=6, mat=ACCENT, scale=(1.0, 1.0, 0.92))
    m.box((0.055, 1.32, 0.168), (0.07, 0.21, 0.024), bevel=0.008, segments=1, mat=ACCENT,
          rotate=("Z", 6.0, (0.055, 1.32, 0.168)))
    for y in (1.255, 1.285):
        m.box((0.048, y, 0.181), (0.072, 0.013, 0.006), bevel=0.002, segments=1, mat=CLOTHES,
              rotate=("Z", 6.0, (0.055, 1.32, 0.168)))

    # Cabeza: cara, cejas y pelo rizado (un casquete y rizos sueltos por encima).
    m.bone = "head"
    cy = 1.645
    m.sphere((0.0, cy, 0.01), 0.115, scale=(1.0, 1.1, 1.0), segments=14, rings=10, mat=SKIN)
    person_face(m, cy, 0.115)
    for s in (-1, 1):
        m.tube([(s * 0.062, cy + 0.045, 0.094), (s * 0.024, cy + 0.05, 0.106)], 0.006, sides=4, mat=HAIR)
    m.lathe([(0.0, 1.785), (0.07, 1.774), (0.11, 1.742), (0.127, 1.695), (0.128, 1.655), (0.0, 1.655)],
            segments=14, mat=HAIR, scale=(1.02, 1.0, 1.04), center=(0.0, 0.0, -0.01))
    m.sphere((0.0, 1.63, -0.05), 0.1, scale=(1.08, 1.0, 0.75), segments=12, rings=8, mat=HAIR)
    for (x, z) in ((-0.06, 0.07), (0.0, 0.085), (0.065, 0.065), (-0.1, 0.0), (0.1, 0.005), (-0.07, -0.07),
                   (0.07, -0.065), (0.0, -0.02), (0.0, -0.1), (-0.035, 0.03), (0.04, 0.025)):
        y = 1.66 + math.sqrt(max(0.0, 0.128 ** 2 - x * x - z * z)) * 0.95
        m.sphere((x, y, z - 0.006), 0.038, segments=8, rings=5, mat=HAIR)

    person_arms(m, bones, 0.054)
    person_legs(m, bones, 0.062, 0.054, shoe=(1.05, 0.9, 2.0))
    person_walk(m, arm_swing=0.32, stride=0.38)
    m.export(fps=12)


def make_dog_walker():
    """Un señor mayor, más bajo y ancho: abrigo largo color camello con botones, gorra plana y bufanda
    granates, pelo y bigote canosos, pantalón gris y zapatos marrones. Pasea tranquilo con el perro."""
    reset_scene()
    bones = person_bones(0.88, 1.38, 1.70, 0.215, 1.07, 0.84, 0.795, 0.095)
    m = Rig("dog_walker", bones, 36)
    m.add_material("skin", (0.86, 0.58, 0.44), 0.7)
    m.add_material("hair", (0.62, 0.60, 0.57), 0.85)
    m.add_material("clothes", (0.62, 0.40, 0.20), 0.9)
    m.add_material("pants", (0.20, 0.18, 0.19), 0.9)
    m.add_material("details", (0.20, 0.10, 0.07), 0.6)
    m.add_material("accent", (0.42, 0.10, 0.10), 0.9)

    # Cadera: el faldón del abrigo hasta la rodilla, con bolsillos.
    m.bone = "hips"
    m.lathe([(0.0, 1.0), (0.2, 1.0), (0.212, 0.9), (0.228, 0.70), (0.24, 0.52), (0.23, 0.50), (0.0, 0.50)],
            segments=14, mat=CLOTHES, scale=(1.0, 1.0, 0.85))
    for s in (-1, 1):
        m.box((s * 0.12, 0.80, 0.168), (0.1, 0.014, 0.035), bevel=0.005, segments=1, mat=CLOTHES,
              rotate=("Y", s * 35.0, (s * 0.12, 0.80, 0.168)))
    m.tube([(0.0, 0.51, 0.205), (0.0, 0.70, 0.196), (0.0, 0.90, 0.182), (0.0, 1.0, 0.172)], 0.005, sides=4, mat=DETAILS, cap=False)

    # Tronco: abrigo con barriga, botones, cuello subido y bufanda.
    m.bone = "spine"
    m.lathe([(0.0, 0.94), (0.204, 0.94), (0.218, 1.03), (0.228, 1.13), (0.214, 1.25), (0.194, 1.33),
             (0.125, 1.385), (0.0, 1.395)], segments=14, mat=CLOTHES, scale=(1.0, 1.0, 0.86))
    m.tube([(0.0, 0.96, 0.178), (0.0, 1.08, 0.198), (0.0, 1.20, 0.192), (0.0, 1.30, 0.172)], 0.005, sides=4, mat=DETAILS, cap=False)
    for y, z in ((0.99, 0.188), (1.09, 0.2), (1.19, 0.194)):
        m.sphere((0.028, y, z), 0.014, segments=6, rings=4, mat=DETAILS)
    m.cylinder((0.0, 1.42, -0.005), 0.05, 0.1, segments=10, mat=SKIN)
    m.torus((0.0, 1.385, 0.0), 0.075, 0.03, major_seg=14, minor_seg=6, mat=ACCENT)
    m.lathe([(0.11, 1.345), (0.118, 1.37), (0.104, 1.43), (0.095, 1.43)], segments=14, mat=CLOTHES,
            scale=(1.0, 1.0, 0.95), center=(0.0, 0.0, -0.015))
    m.box((0.03, 1.31, 0.17), (0.06, 0.08, 0.02), bevel=0.006, segments=1, mat=ACCENT)

    # Cabeza: cara redonda, nariz grande, bigote, cejas pobladas, pelo canoso y gorra plana.
    m.bone = "head"
    cy = 1.555
    m.sphere((0.0, cy, 0.01), 0.12, scale=(1.03, 1.05, 1.0), segments=14, rings=10, mat=SKIN)
    person_face(m, cy, 0.12, nose_r=0.028)
    m.sphere((0.0, cy - 0.04, 0.113), 0.042, scale=(1.35, 0.42, 0.5), segments=10, rings=5, mat=HAIR)
    for s in (-1, 1):
        m.tube([(s * 0.066, cy + 0.043, 0.098), (s * 0.022, cy + 0.05, 0.11)], 0.009, sides=5, mat=HAIR)
        m.sphere((s * 0.108, cy + 0.03, -0.01), 0.04, scale=(0.6, 1.0, 1.0), segments=8, rings=5, mat=HAIR)
    m.sphere((0.0, cy - 0.005, -0.055), 0.105, scale=(1.08, 0.82, 0.75), segments=12, rings=8, mat=HAIR)
    m.lathe([(0.0, 1.70), (0.085, 1.697), (0.123, 1.674), (0.132, 1.64), (0.128, 1.615), (0.0, 1.615)],
            segments=14, mat=ACCENT, scale=(1.04, 1.0, 1.12), center=(0.0, 0.0, -0.012))
    m.sphere((0.0, 1.622, 0.12), 0.085, scale=(1.3, 0.16, 0.85), segments=12, rings=5, mat=ACCENT)
    m.sphere((0.0, 1.70, -0.005), 0.014, segments=6, rings=4, mat=ACCENT)

    person_arms(m, bones, 0.058, cuff_t=0.85)
    person_legs(m, bones, 0.062, 0.052)
    person_walk(m, arm_swing=0.2, stride=0.3, lean=0.06, bounce=0.012)
    m.export(fps=12)


FUR, FUR_LIGHT, DOG_DETAILS, COLLAR = range(4)

DOG_BONES = [
    ("body", (0.0, 0.40, -0.16), (0.0, 0.40, 0.16), None),
    ("head", (0.0, 0.48, 0.20), (0.0, 0.62, 0.28), "body"),
    ("tail", (0.0, 0.46, -0.21), (0.0, 0.58, -0.33), "body"),
    ("leg_fl", (0.07, 0.36, 0.15), (0.07, 0.04, 0.15), "body"),
    ("leg_fr", (-0.07, 0.36, 0.15), (-0.07, 0.04, 0.15), "body"),
    ("leg_bl", (0.07, 0.36, -0.15), (0.07, 0.04, -0.15), "body"),
    ("leg_br", (-0.07, 0.36, -0.15), (-0.07, 0.04, -0.15), "body"),
]


def make_dog():
    """Un perro mediano de orejas caídas: pelo de color (lo cambia el juego), hocico, pecho, patitas y
    punta de la cola claros, collar rojo. Animación "trot" de 8 fotogramas, patas en diagonal."""
    reset_scene()
    m = Rig("dog", DOG_BONES, 41)
    m.add_material("fur", (0.62, 0.38, 0.19), 0.95)
    m.add_material("fur_light", (0.90, 0.80, 0.66), 0.95)
    m.add_material("details", (0.12, 0.07, 0.06), 0.5)
    m.add_material("collar", (0.70, 0.13, 0.10), 0.6)

    m.bone = "body"
    m.lathe([(0.0, -0.245), (0.07, -0.24), (0.115, -0.2), (0.135, -0.1), (0.14, 0.03), (0.132, 0.14),
             (0.10, 0.21), (0.0, 0.235)], segments=14, axis="z", mat=FUR, center=(0.0, 0.40, 0.0),
            scale=(0.82, 1.0, 1.0))
    m.sphere((0.0, 0.345, 0.03), 0.1, scale=(0.85, 0.55, 1.5), segments=12, rings=6, mat=FUR_LIGHT)
    m.sphere((0.0, 0.41, 0.175), 0.08, scale=(0.95, 1.05, 0.7), segments=10, rings=6, mat=FUR_LIGHT)
    m.torus((0.0, 0.49, 0.205), 0.062, 0.013, major_seg=14, minor_seg=5, mat=COLLAR,
            rotate=("X", 38.0, (0.0, 0.49, 0.205)))
    m.sphere((0.0, 0.437, 0.262), 0.014, segments=6, rings=4, mat=DOG_DETAILS)

    m.bone = "head"
    m.tube([(0.0, 0.45, 0.17), (0.0, 0.53, 0.235)], 0.058, sides=8, mat=FUR, cap=False)
    m.sphere((0.0, 0.585, 0.27), 0.092, scale=(0.95, 0.95, 1.0), segments=12, rings=8, mat=FUR)
    m.sphere((0.0, 0.555, 0.355), 0.054, scale=(0.85, 0.78, 1.2), segments=10, rings=6, mat=FUR_LIGHT)
    m.sphere((0.0, 0.572, 0.418), 0.02, scale=(1.25, 0.9, 0.9), segments=8, rings=5, mat=DOG_DETAILS)
    m.tube([(-0.02, 0.528, 0.398), (0.0, 0.523, 0.405), (0.02, 0.528, 0.398)], 0.004, sides=4, mat=DOG_DETAILS)
    for s in (-1, 1):
        m.sphere((s * 0.042, 0.61, 0.337), 0.013, segments=8, rings=5, mat=DOG_DETAILS)
        m.sphere((s * 0.083, 0.565, 0.25), 0.052, scale=(0.32, 1.05, 0.62), segments=8, rings=6, mat=FUR,
                 rotate=("Z", s * 14.0, (s * 0.083, 0.6, 0.25)))

    m.bone = "tail"
    m.tube([(0.0, 0.455, -0.205), (0.0, 0.52, -0.285), (0.0, 0.585, -0.32)], 0.026, sides=6, mat=FUR, taper=0.45, cap=False)
    m.sphere((0.0, 0.595, -0.325), 0.017, segments=6, rings=4, mat=FUR_LIGHT)

    for name, x, z, front in (("leg_fl", 0.07, 0.15, True), ("leg_fr", -0.07, 0.15, True),
                              ("leg_bl", 0.07, -0.15, False), ("leg_br", -0.07, -0.15, False)):
        m.bone = name
        m.sphere((x, 0.34, z), 0.055 if front else 0.063, scale=(0.8, 1.0, 1.15 if front else 1.35),
                 segments=8, rings=6, mat=FUR)
        m.tube([(x, 0.34, z), (x, 0.06, z + 0.005)], 0.033, sides=7, mat=FUR, taper=0.15, cap=False)
        m.sphere((x, 0.035, z + 0.018), 0.036, scale=(1.0, 0.75, 1.3), segments=8, rings=5, mat=FUR_LIGHT)

    # Trote: 8 fotogramas, el 8 repite el 0; patas en diagonal (delante izq. con detrás der.).
    m.action("trot", 8)
    for f in range(9):
        ph = math.tau * (f % 8) / 8.0
        s, c = math.sin(ph), math.cos(ph)
        rots = {
            "leg_fl": (-0.5 * s, 0.0, 0.0),
            "leg_br": (-0.5 * s, 0.0, 0.0),
            "leg_fr": (0.5 * s, 0.0, 0.0),
            "leg_bl": (0.5 * s, 0.0, 0.0),
            "body": (0.025 * c, 0.0, 0.0),
            "head": (-0.06 * abs(s), 0.0, 0.0),
            "tail": (0.0, 0.4 * math.sin(2.0 * ph), 0.0),
        }
        m.pose("trot", f, rots, {"body": (0.0, 0.014 * abs(c) - 0.007, 0.0)})
    m.export(fps=12)


# ------------------------------------------------------------------ bici y moto
def make_bike():
    m = new("bike_frame", 51)
    mat(m, "paint", (0.15, 0.4, 0.6), 0.35, 0.4)
    mat(m, "trim", (0.06, 0.06, 0.07), 0.6)
    mat(m, "chrome", (0.8, 0.8, 0.83), 0.3, 1.0)
    bb = (0.0, 0.30, -0.02)
    seat = (0.0, 0.80, -0.16)
    head_top = (0.0, 0.88, 0.43)
    head_bot = (0.0, 0.70, 0.40)
    rear_ax = (0.0, 0.34, -0.52)
    front_ax = (0.0, 0.34, 0.52)
    for pts in ([bb, seat], [bb, head_bot], [seat, (0.0, 0.78, 0.40)], [rear_ax, bb], [rear_ax, seat], [head_bot, front_ax]):
        m.tube(pts, 0.016, 6, mat=0, cap=False)
    m.tube([head_top, (0.0, 0.93, 0.44)], 0.014, 6, mat=2, cap=False)
    m.box((0, 0.94, 0.44), (0.5, 0.025, 0.025), bevel=0.01, segments=1, mat=1)                      # manillar
    for sx in (-1, 1):
        m.cylinder((sx * 0.27, 0.94, 0.44), 0.016, 0.1, axis="x", mat=1, segments=8)               # puños
        m.box((sx * 0.02, 0.45, 0.52), (0.014, 0.4, 0.02), bevel=0.003, segments=1, mat=2)          # horquilla
        m.box((sx * 0.02, 0.45, -0.52), (0.014, 0.4, 0.02), bevel=0.003, segments=1, mat=2)
    m.box((0.0, 0.82, -0.17), (0.12, 0.05, 0.26), bevel=0.02, segments=2, mat=1)                    # sillín
    m.box((0.0, 0.62, -0.5), (0.1, 0.03, 0.4), bevel=0.01, segments=1, mat=1)                       # portaequipajes
    m.cylinder((0, 0.30, -0.02), 0.045, 0.05, axis="x", mat=2, segments=14)                         # plato
    m.export(center_y=False)


def make_moto():
    m = new("moto_body", 52)
    mat(m, "paint", (0.75, 0.12, 0.1), 0.25, 0.5)
    mat(m, "trim", (0.06, 0.06, 0.07), 0.55)
    mat(m, "chrome", (0.8, 0.8, 0.83), 0.3, 1.0)
    mat(m, "light_front", (1.0, 0.95, 0.8), 0.2)
    mat(m, "light_rear", (0.85, 0.04, 0.05), 0.3)
    m.sphere((0, 0.78, 0.18), 0.2, scale=(0.9, 0.78, 1.5), segments=16, rings=10, mat=0)           # depósito
    m.box((0, 0.74, -0.22), (0.22, 0.09, 0.62), bevel=0.04, segments=2, mat=1)                      # asiento
    m.box((0, 0.5, 0.0), (0.26, 0.28, 0.46), bevel=0.04, segments=2, mat=2)                         # motor
    for sx in (-1, 1):
        m.tube([(sx * 0.12, 0.36, 0.1), (sx * 0.13, 0.28, -0.4), (sx * 0.13, 0.3, -0.78)], 0.026, 8, mat=2, cap=False)  # escape
        m.box((sx * 0.025, 0.46, 0.72), (0.03, 0.62, 0.04), bevel=0.01, segments=1, mat=2)          # horquilla
    m.box((0, 0.97, 0.62), (0.7, 0.03, 0.03), bevel=0.01, segments=1, mat=2)                        # manillar
    m.sphere((0, 0.9, 0.76), 0.1, scale=(1.0, 1.0, 0.8), segments=14, rings=8, mat=3)               # faro
    m.box((0, 0.74, -0.62), (0.2, 0.06, 0.08), bevel=0.02, segments=1, mat=4)                       # piloto
    m.box((0, 0.58, -0.58), (0.16, 0.06, 0.4), bevel=0.03, segments=2, mat=0)                       # guardabarros trasero
    m.box((0, 0.5, 0.72), (0.1, 0.04, 0.38), bevel=0.02, segments=2, mat=0)                         # guardabarros delantero
    m.export(center_y=False)


# ------------------------------------------------------------------ mobiliario urbano
def make_street_lamp():
    m = new("street_lamp", 61)
    mat(m, "trim", (0.2, 0.22, 0.24), 0.5, 0.6)
    mat(m, "light_front", (1.0, 0.92, 0.7), 0.2)
    m.cylinder((0, 0.15, 0), 0.12, 0.3, mat=0, segments=12, round_edge=0.02)
    m.cylinder((0, 2.6, 0), 0.045, 5.0, mat=0, segments=10)
    m.tube([(0, 5.0, 0), (0, 5.45, 0), (0.35, 5.62, 0), (0.8, 5.55, 0)], 0.035, 8, mat=0, cap=False)
    m.box((0.95, 5.5, 0), (0.55, 0.12, 0.2), bevel=0.04, segments=2, mat=0)
    m.box((0.95, 5.43, 0), (0.48, 0.03, 0.15), bevel=0.01, segments=1, mat=1)
    m.export(center_y=False)


def make_hedge():
    m = new("hedge", 62)
    mat(m, "leaf", (0.3, 0.55, 0.28), 0.9)
    m.box((0, 0.35, 0), (1.0, 0.7, 0.6), bevel=0.2, segments=3, mat=0)
    m.sphere((0.0, 0.62, 0), 0.34, scale=(1.4, 0.8, 0.9), segments=12, rings=8, mat=0)
    m.export(center_y=False)


# ------------------------------------------------------------------ árboles
def make_trees():
    m = new("tree_trunk", 71)
    mat(m, "bark", (0.36, 0.26, 0.18), 0.95)
    m.cylinder((0, 1.1, 0), 0.16, 2.2, mat=0, segments=9, scale=(1.0, 1.0, 1.0))
    m.lathe([(0.0, 0.0), (0.26, 0.0), (0.2, 0.25), (0.15, 0.55)], segments=9, mat=0)
    for ang, h, ln in ((0.0, 1.8, 0.9), (2.1, 2.0, 0.8), (4.2, 1.9, 0.85)):
        end = (math.cos(ang) * ln, h + ln * 0.8, math.sin(ang) * ln)
        m.tube([(0, h - 0.2, 0), end], 0.07, 6, mat=0, taper=0.5, cap=False)
    m.export(center_y=False)

    m = new("tree_leaves_round", 72)
    mat(m, "leaf", (0.4, 0.62, 0.3), 0.9)
    spots = [((0, 0, 0), 1.45), ((0.9, -0.15, 0.4), 1.0), ((-0.85, -0.1, 0.5), 1.05), ((0.2, 0.15, -0.9), 1.1),
             ((-0.4, 0.75, -0.1), 0.95), ((0.55, 0.65, 0.3), 0.9), ((0.0, -0.45, 0.75), 0.85)]
    for (p, r) in spots:
        m.sphere(p, r, scale=(1.0, 0.88, 1.0), segments=11, rings=7, mat=0)
    m.export(center_y=False)

    m = new("tree_leaves_tall", 73)
    mat(m, "leaf", (0.3, 0.5, 0.25), 0.9)
    for i in range(6):
        t = i / 5.0
        r = 0.95 - t * 0.55
        m.sphere((math.sin(i * 1.7) * 0.12, i * 0.85 - 2.1, math.cos(i * 1.3) * 0.12), r, scale=(1.0, 1.25, 1.0), segments=10, rings=6, mat=0)
    m.export(center_y=False)


# ------------------------------------------------------------------ casas
def house(name, width, depth, floors, roof_kind, seed):
    """Casa que mira a +Z. Origen en el suelo, centrada en X y Z."""
    m = new(name, seed)
    mat(m, "wall", (0.92, 0.85, 0.72), 0.95)
    mat(m, "roof", (0.7, 0.35, 0.25), 0.8)
    mat(m, "trim", (0.95, 0.93, 0.88), 0.7)
    mat(m, "glass", (0.15, 0.22, 0.3), 0.05)
    mat(m, "door", (0.35, 0.2, 0.12), 0.7)
    hf = 3.0                                  # altura de planta
    H = hf * floors
    hw, hd = width / 2, depth / 2
    m.box((0, H / 2, 0), (width, H, depth), grain="y", bevel=0.05, segments=1, mat=0)
    m.box((0, 0.2, 0), (width + 0.2, 0.4, depth + 0.2), bevel=0.04, segments=1, mat=1)           # zócalo
    for fl in range(1, floors):
        m.box((0, fl * hf, 0), (width + 0.12, 0.14, depth + 0.12), bevel=0.03, segments=1, mat=1)  # cornisa
    # Tejado
    rh = 2.4
    if roof_kind == "gable":
        # Dos faldones inclinados (cumbrera a lo largo de X) y hastiales.
        slope = math.degrees(math.atan2(rh, hd))
        ln = math.hypot(rh, hd) + 0.5
        for sz in (-1, 1):
            m.box((0, H + rh / 2 + 0.05, sz * hd / 2), (width + 0.7, 0.16, ln), grain="x", bevel=0.03, segments=1, mat=2,
                  rotate=("X", sz * slope, (0, H + rh / 2 + 0.05, sz * hd / 2)))
        # Hastiales: el triángulo bajo el tejado, en escalones que quedan siempre por dentro de la pendiente.
        steps = 8
        for sx in (-1, 1):
            for k in range(steps):
                half = hd * (1.0 - (k + 1) / steps) + 0.05
                m.box((sx * (hw - 0.04), H + (k + 0.5) * rh / steps, 0), (0.12, rh / steps, 2 * half), bevel=0.004, segments=1, mat=0)
    else:  # a cuatro aguas simplificado: faldón frontal y trasero + pequeño remate
        slope = math.degrees(math.atan2(rh * 0.8, hd))
        ln = math.hypot(rh * 0.8, hd) + 0.4
        for sz in (-1, 1):
            m.box((0, H + rh * 0.4 + 0.05, sz * hd / 2), (width + 0.5, 0.16, ln), grain="x", bevel=0.03, segments=1, mat=2,
                  rotate=("X", sz * slope, (0, H + rh * 0.4 + 0.05, sz * hd / 2)))
        m.box((0, H + rh * 0.8 + 0.05, 0), (width * 0.95, 0.2, 0.5), bevel=0.04, segments=2, mat=2)
    # Chimenea
    m.box((width * 0.28, H + rh + 0.2, -hd * 0.3), (0.7, 2.0, 0.7), bevel=0.05, segments=1, mat=1)
    # Fachada: ventanas y puerta
    cols = 3 if width > 9 else 2
    for fl in range(floors):
        for k in range(cols):
            wx = (k - (cols - 1) / 2) * (width / (cols + 0.3))
            wy = fl * hf + 1.65
            if fl == 0 and k == cols // 2:
                continue        # sitio de la puerta
            m.box((wx, wy, hd + 0.015), (1.1, 1.35, 0.05), bevel=0.01, segments=1, mat=3)
            m.box((wx, wy, hd + 0.03), (1.3, 0.1, 0.07), bevel=0.01, segments=1, mat=1)           # alféizar
            m.box((wx, wy, hd + 0.03), (0.07, 1.4, 0.07), bevel=0.01, segments=1, mat=1)           # travesaño
            for sx in (-1, 1):
                m.box((wx + sx * 0.62, wy, hd + 0.03), (0.1, 1.4, 0.07), bevel=0.01, segments=1, mat=1)
            m.box((wx, wy + 0.7, hd + 0.03), (1.3, 0.1, 0.07), bevel=0.01, segments=1, mat=1)
    dx = ((cols // 2) - (cols - 1) / 2) * (width / (cols + 0.3))
    m.box((dx, 1.15, hd + 0.02), (1.1, 2.3, 0.07), bevel=0.02, segments=1, mat=4)
    m.box((dx, 1.15, hd + 0.04), (1.3, 2.45, 0.05), bevel=0.01, segments=1, mat=1)
    m.box((dx, 0.1, hd + 0.5), (1.6, 0.2, 1.0), bevel=0.03, segments=1, mat=1)                      # escalón
    m.export(center_y=False)


def run():
    make_wheel("wheel_car", 0.31, 0.22)
    make_wheel("wheel_van", 0.36, 0.24)
    make_wheel("wheel_moto", 0.30, 0.14)
    make_bike_wheel()
    car("car_hatch", 3.9, 1.7, 1.46, 0.31, 0.9, -1.0, 0.75)
    car("car_sedan", 4.5, 1.8, 1.42, 0.32, 0.88, -1.15, 0.85)
    make_van()
    make_person_torso()
    make_person_arm()
    make_person_leg()
    make_helmet()
    make_walker()
    make_dog_walker()
    make_dog()
    make_bike()
    make_moto()
    make_street_lamp()
    make_hedge()
    make_trees()
    house("house_a", 9.5, 7.0, 2, "gable", 81)
    house("house_b", 11.0, 7.5, 2, "hip", 82)
    house("house_c", 8.0, 7.0, 3, "gable", 83)


run()
