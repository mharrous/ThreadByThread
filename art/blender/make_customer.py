"""La primera clienta de la mercería: una mujer de unos cincuenta, con rebeca, falda, gafas redondas,
moño canoso y una cestita colgada del brazo. Modelo original del proyecto (sin recursos de terceros).

Uso:
  blender --background --factory-startup --python art/blender/make_customer.py -- art/models

Sale art/models/customer.glb: una malla con esqueleto sencillo (11 huesos, cada pieza pesada entera a
su hueso, al estilo low-poly del resto de la tienda) y tres animaciones a 12 fps:
  walk         ciclo de paso de 8 fotogramas (el 8 repite el 0 para cerrar el bucle)
  idle         respiración y balanceo leve, 3 s en bucle
  look_around  gira la cabeza a un lado y a otro mirando las estanterías, 5 s
Superficies: skin, hair, clothes, basket, details. Origen = suelo entre los pies; mira hacia +Z.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import OUT_DIR, Rig, reset_scene  # noqa: E402

os.makedirs(OUT_DIR, exist_ok=True)

SKIN, HAIR, CLOTHES, BASKET, DETAILS = range(5)

# (nombre, cabeza, cola, padre) en ejes de Godot. Su izquierda es +X (mira hacia +Z).
# El brazo izquierdo ya está doblado en reposo: lleva la cesta colgada del antebrazo.
BONES = [
    ("hips", (0.0, 0.90, 0.0), (0.0, 1.02, 0.0), None),
    ("spine", (0.0, 1.02, 0.0), (0.0, 1.40, 0.0), "hips"),
    ("head", (0.0, 1.44, 0.0), (0.0, 1.74, 0.0), "spine"),
    ("upper_arm_l", (0.19, 1.37, 0.0), (0.215, 1.11, 0.03), "spine"),
    ("forearm_l", (0.215, 1.11, 0.03), (0.225, 1.06, 0.27), "upper_arm_l"),
    ("upper_arm_r", (-0.19, 1.37, 0.0), (-0.21, 1.10, 0.0), "spine"),
    ("forearm_r", (-0.21, 1.10, 0.0), (-0.22, 0.86, 0.02), "upper_arm_r"),
    ("thigh_l", (0.085, 0.90, 0.0), (0.085, 0.50, 0.0), "hips"),
    ("shin_l", (0.085, 0.50, 0.0), (0.085, 0.06, 0.0), "thigh_l"),
    ("thigh_r", (-0.085, 0.90, 0.0), (-0.085, 0.50, 0.0), "hips"),
    ("shin_r", (-0.085, 0.50, 0.0), (-0.085, 0.06, 0.0), "thigh_r"),
]


def build(m):
    m.add_material("skin", (0.86, 0.58, 0.44), 0.7)
    m.add_material("hair", (0.33, 0.27, 0.25), 0.85)
    m.add_material("clothes", (0.70, 0.30, 0.25), 0.9)
    m.add_material("basket", (0.55, 0.36, 0.16), 0.85)
    m.add_material("details", (0.22, 0.11, 0.15), 0.6)

    # Cadera: falda acampanada hasta la rodilla.
    m.bone = "hips"
    m.lathe([(0.0, 1.03), (0.15, 1.03), (0.165, 0.95), (0.20, 0.72), (0.235, 0.52), (0.225, 0.49), (0.0, 0.49)],
            segments=14, mat=DETAILS, scale=(1.0, 1.0, 0.82))

    # Tronco: rebeca con botones y cuello.
    m.bone = "spine"
    m.lathe([(0.0, 0.96), (0.168, 0.96), (0.172, 1.06), (0.160, 1.18), (0.172, 1.29), (0.160, 1.37),
             (0.105, 1.42), (0.0, 1.43)], segments=14, mat=CLOTHES, scale=(1.0, 1.0, 0.78))
    for i in range(4):
        m.sphere((0.0, 1.02 + i * 0.09, 0.128 - (0.004 if i == 3 else 0.0)), 0.013, segments=6, rings=4, mat=DETAILS)
    m.cylinder((0.0, 1.45, -0.005), 0.046, 0.12, segments=10, mat=SKIN)
    m.torus((0.0, 1.415, -0.005), 0.058, 0.016, major_seg=14, minor_seg=5, mat=CLOTHES)

    # Cabeza: cara redonda, nariz, orejas, ojos, gafas redondas y pelo recogido en un moño.
    m.bone = "head"
    m.sphere((0.0, 1.585, 0.01), 0.118, scale=(1.0, 1.08, 1.0), segments=14, rings=10, mat=SKIN)
    m.sphere((0.0, 1.57, 0.128), 0.022, scale=(0.9, 1.0, 0.8), segments=8, rings=5, mat=SKIN)
    for s in (-1, 1):
        m.sphere((s * 0.118, 1.58, 0.0), 0.024, scale=(0.5, 1.0, 0.8), segments=8, rings=5, mat=SKIN)
        m.sphere((s * 0.042, 1.60, 0.107), 0.013, segments=8, rings=5, mat=DETAILS)
        # Mejillas sonrosadas (del color de la rebeca), apenas asomando de la cara.
        m.sphere((s * 0.066, 1.556, 0.094), 0.022, scale=(1.0, 0.65, 0.35), segments=8, rings=5, mat=CLOTHES)
        m.torus((s * 0.043, 1.60, 0.122), 0.03, 0.0045, axis="z", major_seg=14, minor_seg=4, mat=DETAILS)
        m.tube([(s * 0.073, 1.60, 0.12), (s * 0.11, 1.605, 0.07), (s * 0.118, 1.60, 0.0)], 0.004, sides=4, mat=DETAILS)
    m.tube([(-0.013, 1.603, 0.123), (0.0, 1.608, 0.126), (0.013, 1.603, 0.123)], 0.004, sides=4, mat=DETAILS, cap=False)
    # Sonrisa.
    m.tube([(-0.032, 1.532, 0.106), (-0.016, 1.522, 0.115), (0.0, 1.519, 0.117), (0.016, 1.522, 0.115),
            (0.032, 1.532, 0.106)], 0.0045, sides=4, mat=DETAILS)
    m.lathe([(0.0, 1.727), (0.07, 1.716), (0.11, 1.684), (0.128, 1.635), (0.131, 1.60), (0.0, 1.60)],
            segments=14, mat=HAIR, scale=(1.02, 1.0, 1.04), center=(0.0, 0.0, -0.006))
    m.sphere((0.0, 1.56, -0.045), 0.105, scale=(1.08, 1.0, 0.8), segments=12, rings=8, mat=HAIR)
    m.sphere((0.0, 1.705, -0.098), 0.06, scale=(1.0, 0.9, 0.9), segments=10, rings=7, mat=HAIR)
    m.torus((0.0, 1.69, -0.088), 0.045, 0.01, axis="z", major_seg=12, minor_seg=4, mat=DETAILS,
            rotate=("X", -35.0, (0.0, 1.69, -0.088)))

    # Brazos: mangas de la rebeca hasta tres cuartos y manos.
    for side, upper, fore in (("l", BONES[3], BONES[4]), ("r", BONES[5], BONES[6])):
        m.bone = "upper_arm_" + side
        m.sphere(upper[1], 0.06, segments=10, rings=6, mat=CLOTHES)
        m.tube([upper[1], upper[2]], 0.052, sides=8, mat=CLOTHES, cap=False)
        m.bone = "forearm_" + side
        m.sphere(fore[1], 0.05, segments=10, rings=6, mat=CLOTHES)
        a, b = fore[1], fore[2]
        cuff = tuple(a[i] + (b[i] - a[i]) * 0.72 for i in range(3))
        m.tube([a, cuff], 0.046, sides=8, mat=CLOTHES)
        m.tube([cuff, b], 0.032, sides=8, mat=SKIN, cap=False)
        hand = tuple(b[i] + (b[i] - a[i]) * 0.14 for i in range(3))
        m.sphere(hand, 0.042, scale=(0.8, 1.0, 1.0), segments=10, rings=6, mat=SKIN)

    # La cesta, colgada del antebrazo izquierdo: asa de mimbre, cuerpo, borde y un paño a cuadros.
    m.bone = "forearm_l"
    bx, bz = 0.228, 0.15
    m.torus((bx, 1.005, bz), 0.085, 0.009, axis="x", major_seg=16, minor_seg=5, mat=BASKET)
    m.lathe([(0.0, 0.84), (0.072, 0.84), (0.082, 0.86), (0.098, 0.93), (0.0, 0.93)],
            segments=14, mat=BASKET, center=(bx, 0.0, bz), scale=(0.75, 1.0, 1.0))
    m.torus((bx, 0.93, bz), 0.098, 0.011, major_seg=16, minor_seg=5, mat=BASKET, scale=(0.75, 1.0, 1.0))
    m.sphere((bx, 0.935, bz + 0.01), 0.07, scale=(0.95, 0.35, 1.15), segments=10, rings=5, mat=DETAILS)

    # Piernas (medias color carne) y zapatos.
    for side, s in (("l", 1), ("r", -1)):
        m.bone = "thigh_" + side
        m.tube([(s * 0.085, 0.90, 0.0), (s * 0.085, 0.50, 0.0)], 0.058, sides=8, mat=SKIN, cap=False)
        m.bone = "shin_" + side
        m.sphere((s * 0.085, 0.50, 0.0), 0.05, segments=8, rings=5, mat=SKIN)
        m.tube([(s * 0.085, 0.50, 0.0), (s * 0.085, 0.07, 0.0)], 0.044, sides=8, mat=SKIN, taper=0.25, cap=False)
        m.sphere((s * 0.085, 0.045, 0.035), 0.05, scale=(1.0, 0.85, 1.9), segments=10, rings=6, mat=DETAILS)


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def keys_between(points, f):
    """Valor suavizado en el fotograma f a partir de [(fotograma, valor), ...]."""
    for (f0, v0), (f1, v1) in zip(points, points[1:]):
        if f0 <= f <= f1:
            return v0 + (v1 - v0) * smooth((f - f0) / max(f1 - f0, 1e-6))
    return points[-1][1]


# El brazo de la cesta, un poco adelantado y quieto (la cesta no se balancea de más).
BASKET_ARM = {"upper_arm_l": (-0.05, 0.0, 0.0)}


def animate(m):
    # Paso: 8 fotogramas; el 8 repite el 0. Fase 0 = pierna izquierda pasando hacia delante.
    m.action("walk", 8)
    for f in range(9):
        ph = math.tau * (f % 8) / 8.0
        s, c = math.sin(ph), math.cos(ph)
        rots = {
            # Giro negativo en X = el pie va hacia delante (+Z).
            "thigh_l": (-0.36 * s, 0.0, 0.0),
            "thigh_r": (0.36 * s, 0.0, 0.0),
            "shin_l": (0.55 * max(0.0, c), 0.0, 0.0),
            "shin_r": (0.55 * max(0.0, -c), 0.0, 0.0),
            "hips": (0.0, 0.07 * s, 0.0),
            "spine": (0.03, -0.11 * s, 0.0),
            "head": (-0.03, 0.05 * s, 0.0),
            "upper_arm_r": (-0.30 * s, 0.0, 0.0),
            "forearm_r": (-0.12 - 0.12 * max(0.0, s), 0.0, 0.0),
            "upper_arm_l": (-0.05 + 0.05 * s, 0.0, 0.0),
        }
        m.pose("walk", f, rots, {"hips": (0.0, 0.016 * abs(c) - 0.008, 0.0)})

    # Quieta: respira y se balancea un poco. 3 s (36 fotogramas).
    m.action("idle", 36)
    for f in range(37):
        b = math.sin(math.tau * f / 36.0)
        rots = dict(BASKET_ARM)
        rots.update({
            "spine": (0.015 * b, 0.0, 0.01 * b),
            "head": (-0.01 * b, 0.025 * math.sin(math.tau * f / 36.0 + 1.0), 0.0),
            "upper_arm_r": (0.02 * b, 0.0, 0.0),
            "forearm_r": (-0.1, 0.0, 0.0),
        })
        m.pose("idle", f, rots, {"hips": (0.0, 0.003 * b, 0.0)})

    # Mira a su alrededor: cabeza (y algo el tronco) a un lado, al otro, y vuelta; alza la vista. 5 s.
    m.action("look_around", 60)
    yaw = [(0, 0.0), (10, 0.6), (24, 0.6), (34, -0.55), (48, -0.55), (60, 0.0)]
    tilt = [(0, 0.0), (10, -0.12), (24, -0.1), (34, -0.14), (48, -0.08), (60, 0.0)]
    for f in range(61):
        y = keys_between(yaw, f)
        b = math.sin(math.tau * f / 30.0)
        rots = dict(BASKET_ARM)
        rots.update({
            "spine": (0.012 * b, y * 0.25, 0.0),
            "head": (keys_between(tilt, f), y * 0.75, -y * 0.08),
            "forearm_r": (-0.1, 0.0, 0.0),
        })
        m.pose("look_around", f, rots, {"hips": (0.0, 0.002 * b, 0.0)})


def main():
    reset_scene()
    m = Rig("customer", BONES)
    build(m)
    animate(m)
    m.export(fps=12)


main()
