"""Genera los modelos de objetos de la mercería (originales) y los exporta a GLB.

Uso:
  blender --background --factory-startup --python art/blender/make_items.py -- art/models/items

Familias: hilos (carrete), botones (4 estilos), telas (rollo y doblada), cintas (carrete y lazo)
y accesorios de sastrería (tijeras, metro, regla, cremallera, dedal, estuche de agujas,
acerico, tiza, caja de costura, lata, patrón, bastidor, plancha).
Cada modelo está centrado en el origen y en su "pose natural" (la que tiene sobre una balda).
Los que cuelgan de un panel de ganchos tienen su eje largo en X.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import Model, OUT_DIR, reset_scene  # noqa: E402
from mathutils import Vector  # noqa: E402

os.makedirs(OUT_DIR, exist_ok=True)

STEEL = (0.80, 0.81, 0.84)


def mats(m, main, accent=None, metal=False, glass=False, main_rough=0.7, accent_rough=0.6):
    m.add_material("main", main, main_rough)
    if accent is not None:
        m.add_material("accent", accent, accent_rough)
    if metal:
        m.add_material("metal", STEEL, 0.3, metallic=1.0)
    if glass:
        m.add_material("glass", (0.85, 0.95, 1.0), 0.05)


# ---------------------------------------------------------------- hilos
def make_spool():
    reset_scene()
    m = Model("spool", 21)
    mats(m, (0.8, 0.2, 0.2), (0.88, 0.76, 0.55))
    H, RF, FT, RC, RT = 0.056, 0.026, 0.0045, 0.0155, 0.0225
    m.cylinder((0, 0, 0), RC, H, mat=1, segments=20)                                   # núcleo
    m.cylinder((0, -H / 2 + FT / 2, 0), RF, FT, mat=1, round_edge=0.0012, segments=28)  # pestaña inferior
    m.cylinder((0, H / 2 - FT / 2, 0), RF, FT, mat=1, round_edge=0.0012, segments=28)   # pestaña superior
    th = H - 2 * FT
    m.lathe([(0, -th / 2), (RT - 0.0012, -th / 2), (RT, -th / 2 + 0.0012), (RT, th / 2 - 0.0012), (RT - 0.0012, th / 2), (0, th / 2)],
            segments=28, mat=0)                                                          # hilo enrollado
    # Cabo suelto
    pts = [(RT, 0.012, 0.0), (RT + 0.004, 0.006, 0.002), (RT + 0.008, -0.004, 0.004), (RT + 0.010, -0.016, 0.003), (RT + 0.007, -0.024, 0.008)]
    m.tube(pts, 0.0007, 5, mat=0)
    m.export()


# ---------------------------------------------------------------- botones
def button(name, kind, seed):
    reset_scene()
    m = Model(name, seed)
    mats(m, (0.85, 0.85, 0.85), (0.1, 0.07, 0.05), metal=True)
    R, T = 0.02, 0.005
    if kind == "flat":
        prof = [(0, -T / 2), (R - 0.002, -T / 2), (R, -T / 2 + 0.0015), (R, T / 2 - 0.0015), (R - 0.002, T / 2),
                (R * 0.62, T / 2 - 0.0007), (0, T / 2 - 0.0007)]
    elif kind == "rim":
        prof = [(0, -T / 2), (R - 0.002, -T / 2), (R, -T / 2 + 0.0015), (R, T / 2 - 0.0005), (R - 0.0018, T / 2 + 0.0016),
                (R * 0.74, T / 2 + 0.0016), (R * 0.68, T / 2 - 0.0006), (0, T / 2 - 0.0006)]
    else:  # domo con pie
        H = 0.011
        prof = [(0, -0.002), (R * 0.95, -0.002), (R, -0.0005), (R * 0.96, 0.0015), (R * 0.82, 0.0055), (R * 0.55, 0.0095), (R * 0.2, H), (0, H + 0.0004)]
    m.lathe(prof, segments=28, mat=0)
    if kind in ("flat", "rim"):
        top = (T / 2 - 0.0004) if kind == "flat" else (T / 2 - 0.0005)
        holes = [(-0.0045, 0.0), (0.0045, 0.0)] if name.endswith("2") else [(-0.0045, -0.0045), (0.0045, -0.0045), (-0.0045, 0.0045), (0.0045, 0.0045)]
        for (hx, hz) in holes:
            m.cylinder((hx, top - 0.0003, hz), 0.0026, 0.0012, mat=1, segments=10)
    else:
        m.torus((0, -0.006, 0), 0.0045, 0.0012, axis="x", major_seg=14, minor_seg=6, mat=2)   # pie (aro de metal)
    m.export()


# ---------------------------------------------------------------- telas
def make_bolt():
    reset_scene()
    m = Model("bolt", 31)
    mats(m, (0.9, 0.85, 0.75), (0.78, 0.62, 0.42), main_rough=0.95, accent_rough=0.95)
    L, R, RC = 0.42, 0.055, 0.021
    m.cylinder((0, 0, 0), RC, L + 0.05, axis="z", mat=1, segments=18)                    # tubo de cartón
    # Tela enrollada, con la capa exterior ligeramente suelta y el borde visible.
    m.lathe([(0, -L / 2), (R - 0.004, -L / 2), (R - 0.001, -L / 2 + 0.001), (R, -L / 2 + 0.004), (R, L / 2 - 0.004),
             (R - 0.001, L / 2 - 0.001), (R - 0.004, L / 2), (0, L / 2)], segments=36, axis="z", mat=0)
    # Cabo de tela colgando del rollo
    m.box((0.0, -R * 0.78, 0.04), (0.20, 0.0025, 0.12), grain="z", bevel=0.0008, segments=1, mat=0,
          rotate=("Z", 8.0, (0, 0, 0)))
    m.export()


def make_folded():
    reset_scene()
    m = Model("folded", 32)
    mats(m, (0.9, 0.85, 0.75), None, main_rough=0.95)
    X, Y, Z = 0.34, 0.045, 0.27
    m.box((0, 0, 0), (X, Y, Z), grain="x", bevel=0.011, segments=3, mat=0)
    # Pliegues: tres capas ligeramente desplazadas en el borde.
    m.box((0.004, Y * 0.18, 0.0), (X - 0.01, Y * 0.5, Z - 0.012), grain="x", bevel=0.006, segments=2, mat=0)
    m.export()


# ---------------------------------------------------------------- cintas
def make_ribbon_reel():
    reset_scene()
    m = Model("ribbon_reel", 41)
    mats(m, (0.8, 0.15, 0.2), (0.95, 0.95, 0.92), main_rough=0.35)
    H, RF, RC, RT = 0.028, 0.034, 0.012, 0.029
    m.cylinder((0, 0, 0), RC, H, mat=1, segments=20)
    m.cylinder((0, -H / 2 + 0.0015, 0), RF, 0.003, mat=1, round_edge=0.001, segments=28)
    m.cylinder((0, H / 2 - 0.0015, 0), RF, 0.003, mat=1, round_edge=0.001, segments=28)
    rh = H - 0.006
    m.lathe([(0, -rh / 2), (RT - 0.001, -rh / 2), (RT, -rh / 2 + 0.001), (RT, rh / 2 - 0.001), (RT - 0.001, rh / 2), (0, rh / 2)], segments=32, mat=0)
    # Cola de cinta colgando
    m.box((RT + 0.0015, -0.012, 0.0), (0.0016, 0.052, 0.020), grain="y", bevel=0.0003, segments=1, mat=0, rotate=("Z", -6.0, (RT, 0.012, 0)))
    m.export()


def make_bow():
    reset_scene()
    m = Model("bow", 42)
    mats(m, (0.85, 0.2, 0.3), None, main_rough=0.35)
    # Dos lazadas, nudo central y dos colas.
    for sx in (-1, 1):
        m.torus((sx * 0.026, 0, 0), 0.016, 0.0065, axis="y", major_seg=20, minor_seg=8, mat=0, scale=(1.35, 0.55, 0.9))
        m.box((sx * 0.026, 0, 0), (0.030, 0.003, 0.022), grain="x", bevel=0.001, segments=1, mat=0)
    m.sphere((0, 0, 0), 0.0105, scale=(1.0, 0.7, 1.0), segments=14, rings=8, mat=0)
    m.box((-0.010, -0.002, 0.026), (0.016, 0.003, 0.050), grain="z", bevel=0.001, segments=1, mat=0, rotate=("Y", 18.0, (-0.01, 0, 0.01)))
    m.box((0.010, -0.002, 0.026), (0.016, 0.003, 0.050), grain="z", bevel=0.001, segments=1, mat=0, rotate=("Y", -18.0, (0.01, 0, 0.01)))
    m.export()


# ---------------------------------------------------------------- accesorios
def make_scissors():
    reset_scene()
    m = Model("scissors", 51)
    mats(m, (0.85, 0.2, 0.2), None, metal=True, main_rough=0.35)
    # Eje largo en X: hojas hacia +X, anillos hacia -X; plano XZ, grosor en Y.
    for sz, ang in ((1, 3.0), (-1, -3.0)):
        m.box((0.052, 0.0, sz * 0.004), (0.095, 0.0028, 0.011), grain="x", bevel=0.0007, segments=1, mat=1, taper=None,
              rotate=("Y", ang, (0.0, 0.0, 0.0)))                      # hoja
        m.box((-0.020, 0.0, sz * 0.007), (0.040, 0.0034, 0.007), grain="x", bevel=0.001, segments=1, mat=1,
              rotate=("Y", -ang * 2.5, (0.0, 0.0, 0.0)))               # brazo
        m.torus((-0.050, 0.0, sz * 0.018), 0.0125, 0.0036, axis="y", major_seg=22, minor_seg=8, mat=0, scale=(1.15, 1.0, 1.0))  # anillo
    m.cylinder((0.0, 0.0, 0.0), 0.0035, 0.0052, mat=1, segments=12)   # tornillo
    m.export()


def make_tape_measure():
    reset_scene()
    m = Model("tape_measure", 52)
    mats(m, (0.85, 0.7, 0.2), (0.95, 0.92, 0.78), metal=True)
    m.cylinder((0, 0, 0), 0.033, 0.016, mat=0, round_edge=0.002, segments=32)
    m.cylinder((0, 0, 0), 0.0345, 0.0095, mat=1, segments=32)                           # banda de cinta
    m.cylinder((0, 0.0085, 0), 0.0055, 0.002, mat=2, segments=14)                        # botón
    m.box((0.040, 0.0, 0.0), (0.016, 0.003, 0.016), grain="x", bevel=0.0008, segments=1, mat=1)  # lengüeta
    m.box((0.049, 0.0, 0.0), (0.004, 0.004, 0.017), grain="x", bevel=0.0005, segments=1, mat=2)  # tope metálico
    m.torus((-0.043, 0.0, 0.0), 0.0075, 0.0018, axis="y", major_seg=18, minor_seg=6, mat=2)      # anilla para colgar
    m.export()


def make_ruler():
    reset_scene()
    m = Model("ruler", 53)
    mats(m, (0.9, 0.78, 0.45), (0.12, 0.09, 0.06))
    L, W, T = 0.30, 0.036, 0.004
    m.box((0, 0, 0), (L, T, W), grain="x", bevel=0.0007, segments=1, mat=0)
    for i in range(31):
        x = -L / 2 + 0.012 + i * 0.0092
        long = (i % 5 == 0)
        h = 0.013 if long else 0.007
        m.box((x, T / 2 + 0.0002, W / 2 - 0.004 - h / 2), (0.0008, 0.0006, h), bevel=0.0, mat=1)
    m.cylinder((-L / 2 + 0.012, 0.0, 0.0), 0.0045, T + 0.0008, mat=1, segments=12)       # agujero
    m.export()


def make_zipper():
    reset_scene()
    m = Model("zipper", 54)
    mats(m, (0.15, 0.2, 0.45), None, metal=True)
    L, W, T = 0.21, 0.032, 0.0022
    m.box((0, 0, 0), (L, T, W), grain="x", bevel=0.0004, segments=1, mat=0)
    for i in range(44):
        x = -L / 2 + 0.008 + i * 0.0044
        for sz in (-1, 1):
            m.box((x, 0.0, sz * (0.0028 if i % 2 == 0 else 0.0016)), (0.0030, 0.0030, 0.0042), bevel=0.0004, segments=1, mat=1)
    m.box((-0.045, 0.0, 0.0), (0.016, 0.0075, 0.015), bevel=0.0012, segments=2, mat=1)   # cursor
    m.box((-0.062, 0.0, 0.0), (0.016, 0.0022, 0.0085), bevel=0.0008, segments=1, mat=1)  # tirador
    m.torus((-0.0735, 0.0, 0.0), 0.0035, 0.0009, axis="y", major_seg=14, minor_seg=6, mat=1)
    m.export()


def make_thimble():
    reset_scene()
    m = Model("thimble", 55)
    mats(m, (0.85, 0.85, 0.88), None)
    prof = [(0, 0.0140), (0.0045, 0.0136), (0.0085, 0.0112), (0.0112, 0.0060), (0.0123, -0.0020), (0.0130, -0.0095),
            (0.0145, -0.0125), (0.0155, -0.0140), (0.0142, -0.0143), (0.0126, -0.0128), (0.0000, -0.0128)]
    m.lathe(prof, segments=26, mat=0)
    # Hoyuelos del dedal: pequeñas esferas hundidas en filas.
    for ring_i, (yy, rr) in enumerate([(0.0100, 0.0078), (0.0060, 0.0107), (0.0020, 0.0118), (-0.0020, 0.0124), (-0.0060, 0.0127)]):
        n = 7 + ring_i
        for k in range(n):
            a = math.tau * (k + 0.5 * (ring_i % 2)) / n
            m.sphere((rr * math.cos(a), yy, rr * math.sin(a)), 0.0014, segments=6, rings=4, mat=0)
    m.export()


def make_needle_case():
    reset_scene()
    m = Model("needle_case", 56)
    mats(m, (0.25, 0.5, 0.7), (0.92, 0.85, 0.7), metal=True, main_rough=0.4)
    m.cylinder((0, 0, 0), 0.0085, 0.080, mat=0, round_edge=0.002, segments=18)
    m.cylinder((0, 0.0455, 0), 0.0100, 0.022, mat=1, round_edge=0.002, segments=18)
    m.cylinder((0, -0.0395, 0), 0.0092, 0.004, mat=2, segments=18)
    m.export()


def make_pincushion():
    reset_scene()
    m = Model("pincushion", 57)
    mats(m, (0.8, 0.15, 0.18), (0.25, 0.55, 0.25), metal=True, main_rough=0.97)
    m.sphere((0, 0, 0), 0.034, scale=(1.0, 0.72, 1.0), segments=22, rings=14, mat=0)
    m.cylinder((0, 0.0245, 0), 0.013, 0.004, mat=1, segments=8, round_edge=0.001)         # sombrerete
    m.sphere((0, 0.027, 0), 0.0045, segments=8, rings=5, mat=1)
    for k in range(7):
        a = math.tau * k / 7 + 0.3
        tilt = 0.5 + 0.25 * (k % 3)
        base = Vector((0.026 * math.cos(a), 0.012, 0.026 * math.sin(a)))
        tip = base + Vector((math.cos(a) * 0.016 * tilt, 0.018, math.sin(a) * 0.016 * tilt))
        m.tube([tuple(base), tuple(tip)], 0.0005, 5, mat=2)
        m.sphere(tuple(tip), 0.0028, segments=7, rings=5, mat=1)
    m.export()


def make_chalk():
    reset_scene()
    m = Model("chalk", 58)
    mats(m, (0.9, 0.55, 0.65), None, main_rough=0.95)
    m.cylinder((0, 0, 0), 0.030, 0.007, mat=0, segments=6, round_edge=0.0012, scale=(1.0, 1.0, 0.82))
    m.cylinder((0, 0.0036, 0), 0.020, 0.0008, mat=0, segments=6, scale=(1.0, 1.0, 0.82))
    m.export()


def make_sewing_box():
    reset_scene()
    m = Model("sewing_box", 61)
    mats(m, (0.78, 0.55, 0.36), (0.55, 0.38, 0.25), metal=True, main_rough=0.7)
    X, Y, Z = 0.30, 0.15, 0.20
    m.box((0, -0.02, 0), (X, Y - 0.04, Z), grain="x", bevel=0.006, segments=2, mat=0)             # cuerpo
    m.box((0, 0.055, 0), (X + 0.01, 0.045, Z + 0.01), grain="x", bevel=0.007, segments=2, mat=0)  # tapa
    m.torus((0, 0.090, 0), 0.040, 0.0045, axis="z", major_seg=20, minor_seg=6, mat=1, scale=(1.0, 0.55, 1.0))  # asa
    for sx in (-1, 1):
        m.box((sx * 0.055, 0.032, Z / 2 + 0.003), (0.020, 0.032, 0.004), bevel=0.001, segments=1, mat=2)       # cierres
    m.box((0, 0.032, -Z / 2 - 0.003), (0.05, 0.012, 0.004), bevel=0.001, segments=1, mat=2)
    for sx in (-1, 1):
        m.cylinder((sx * 0.125, -0.0925, 0.085), 0.008, 0.01, mat=1, segments=10)                   # patas
        m.cylinder((sx * 0.125, -0.0925, -0.085), 0.008, 0.01, mat=1, segments=10)
    m.export()


def make_sewing_tin():
    reset_scene()
    m = Model("sewing_tin", 62)
    mats(m, (0.75, 0.2, 0.25), (0.92, 0.85, 0.7), metal=True, main_rough=0.35)
    R, H = 0.085, 0.06
    m.lathe([(0, -H / 2), (R - 0.004, -H / 2), (R, -H / 2 + 0.003), (R, H * 0.1), (R + 0.0025, H * 0.12), (R + 0.0025, H / 2 - 0.004),
             (R, H / 2), (R * 0.78, H / 2 + 0.0015), (0, H / 2 + 0.0015)], segments=40, mat=0)
    m.cylinder((0, H / 2 + 0.0023, 0), R * 0.55, 0.0012, mat=1, segments=32)                        # etiqueta
    m.torus((0, H * 0.11, 0), R + 0.0015, 0.0012, axis="y", major_seg=40, minor_seg=5, mat=2)
    m.export()


def make_pattern_envelope():
    reset_scene()
    m = Model("pattern_envelope", 63)
    mats(m, (0.9, 0.75, 0.55), (0.97, 0.95, 0.9), main_rough=0.85, accent_rough=0.85)
    X, T, Z = 0.22, 0.004, 0.32
    m.box((0, 0, 0), (X, T, Z), grain="x", bevel=0.0008, segments=1, mat=0)
    m.box((0, T / 2 + 0.0003, 0.02), (X * 0.78, 0.0007, Z * 0.52), bevel=0.0, mat=1)                 # etiqueta
    m.box((0, T / 2 + 0.0003, -Z * 0.40), (X * 0.78, 0.0007, 0.03), bevel=0.0, mat=1)                # título
    m.export()


def make_embroidery_hoop():
    reset_scene()
    m = Model("embroidery_hoop", 64)
    mats(m, (0.95, 0.9, 0.8), (0.82, 0.62, 0.38), metal=True, main_rough=0.95)
    R = 0.085
    m.torus((0, 0, 0), R, 0.0042, axis="y", major_seg=40, minor_seg=8, mat=1, scale=(1.0, 1.35, 1.0))    # aro
    m.torus((0, 0, 0), R - 0.0095, 0.0033, axis="y", major_seg=40, minor_seg=7, mat=1, scale=(1.0, 1.2, 1.0))
    m.cylinder((0, -0.0004, 0), R - 0.004, 0.0012, mat=0, segments=40)                                  # tela tensada
    m.box((R + 0.0075, 0.0, 0.0), (0.016, 0.016, 0.014), bevel=0.002, segments=2, mat=1)                 # tornillo
    m.cylinder((R + 0.0075, 0.012, 0.0), 0.0045, 0.008, mat=2, segments=10)
    m.export()


def make_iron():
    reset_scene()
    m = Model("iron", 65)
    mats(m, (0.22, 0.22, 0.25), (0.45, 0.3, 0.2), metal=True, main_rough=0.45)
    # Plancha de hierro vintage: base en cuña y asa de madera. Eje largo en X.
    m.box((0.0, -0.022, 0.0), (0.150, 0.014, 0.075), grain="x", bevel=0.004, segments=3, mat=0)
    m.box((0.0, 0.004, 0.0), (0.118, 0.040, 0.062), grain="x", bevel=0.010, segments=3, mat=0, taper=None)
    m.torus((-0.010, 0.050, 0.0), 0.034, 0.006, axis="z", major_seg=22, minor_seg=7, mat=1, scale=(1.35, 1.0, 1.0))
    m.box((-0.010, 0.082, 0.0), (0.070, 0.010, 0.016), bevel=0.003, segments=2, mat=1)
    for sx in (-1, 1):
        m.cylinder((sx * 0.026, 0.026, 0.0), 0.005, 0.016, mat=2, segments=10)
    m.export()


def run():
    make_spool()
    button("button_flat2", "flat", 22)
    button("button_flat4", "flat", 23)
    button("button_rim4", "rim", 24)
    button("button_shank", "shank", 25)
    make_bolt()
    make_folded()
    make_ribbon_reel()
    make_bow()
    make_scissors()
    make_tape_measure()
    make_ruler()
    make_zipper()
    make_thimble()
    make_needle_case()
    make_pincushion()
    make_chalk()
    make_sewing_box()
    make_sewing_tin()
    make_pattern_envelope()
    make_embroidery_hoop()
    make_iron()


run()
