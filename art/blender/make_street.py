"""Genera los modelos de la calle que se ve por la ventana (originales) y los exporta a GLB.

Uso:
  blender --background --factory-startup --python art/blender/make_street.py -- art/models/street

Vehículos (miran a +Z, origen en el suelo, ruedas aparte para poder girarlas), personas y
perros (por piezas, para animar el paso), casas, farolas, árboles y seto.
Las superficies se llaman "paint", "glass", "trim", "tire", "chrome", "light_front",
"light_rear", "wall", "roof", "door", "skin", "hair", "shirt", "pants", "shoes", "fur"...:
scripts/room/street_actors.gd les pone el material y el color de cada ejemplar.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import Model, OUT_DIR, reset_scene  # noqa: E402
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


# ------------------------------------------------------------------ perro
def make_dog():
    m = new("dog_body", 41)
    mat(m, "fur", (0.7, 0.5, 0.3), 0.9)
    mat(m, "skin", (0.12, 0.08, 0.07), 0.5)
    m.sphere((0, 0.0, 0), 0.17, scale=(0.9, 0.95, 1.55), segments=14, rings=10, mat=0)         # cuerpo
    m.sphere((0, 0.04, 0.17), 0.15, scale=(0.9, 1.0, 1.0), segments=12, rings=8, mat=0)        # pecho
    m.sphere((0, 0.17, 0.33), 0.1, scale=(0.9, 1.0, 1.0), segments=12, rings=8, mat=0)         # cabeza
    m.box((0, 0.145, 0.43), (0.075, 0.065, 0.12), bevel=0.02, segments=2, mat=0)               # hocico
    m.sphere((0, 0.16, 0.49), 0.022, segments=6, rings=4, mat=1)                               # nariz
    for sx in (-1, 1):
        m.box((sx * 0.075, 0.22, 0.31), (0.035, 0.1, 0.07), bevel=0.01, segments=1, mat=0, rotate=("Z", sx * 18.0, (sx * 0.075, 0.22, 0.31)))  # orejas
    m.tube([(0, 0.08, -0.25), (0, 0.17, -0.34), (0.0, 0.26, -0.37)], 0.022, 6, mat=0, taper=0.4)  # cola
    m.export(center_y=False)

    m = new("dog_leg", 42)
    mat(m, "fur", (0.7, 0.5, 0.3), 0.9)
    m.cylinder((0, -0.12, 0), 0.032, 0.24, mat=0, segments=8)
    m.sphere((0, -0.25, 0.012), 0.036, scale=(1, 0.7, 1.3), segments=8, rings=6, mat=0)
    m.export(center_y=False)


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
