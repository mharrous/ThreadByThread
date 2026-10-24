"""El gato de la tienda: atigrado gris con hocico, pechera y patitas blancas. Modelo original del proyecto.

Uso:
  blender --background --factory-startup --python art/blender/make_cat.py -- art/models

Sale art/models/cat.glb: malla con esqueleto de 13 huesos (cuerpo, cabeza, ojos, orejas, cuatro patas y
cola en tres huesos; cada pieza pesada entera a su hueso) en pose de pie, y animaciones a 12 fps:
  walk          paso (8 fotogramas, bucle)
  trot          trote, para perseguir el ovillo (6, bucle)
  stand         de pie, respira y mece la cola (24, bucle)
  sit           sentado, respira y sacude la punta de la cola (24, bucle)
  groom         sentado, se lame la pata y se la pasa por la cara (36, bucle)
  sleep         hecho un ovillo, con los ojos cerrados (48, bucle)
  bat           sentado, da un zarpazo con la pata derecha (24; toca el suelo en el fotograma 13)
  pet           sentado, ojos cerrados, frota la cabeza contra la mano y ronronea (24, bucle)
  lie           tumbado de lado, relajado, mece la cola por el suelo y levanta la cabeza (32, bucle)
  roll          panza arriba revolcándose de un lado a otro con las patitas dobladas (36, bucle)
  stretch       de pie, estira las patas delanteras con el culete en alto y vuelve (30; empieza y
                acaba de pie)
  knead         sentado amasando con las patas delanteras, ojos entornados (24, bucle)
  gallop        carrera loca: patas delanteras juntas y traseras juntas, orejas atrás (6, bucle)
  blink         parpadeo (4; solo los ojos: se mezcla encima del resto)
  ear_twitch_l  la oreja izquierda se sacude (6; solo esa oreja)
  ear_twitch_r  ídem con la derecha
Superficies: body, stripes, white, eyes, pupil, nose, inner_ear, whiskers. Origen = suelo bajo el gato;
mira hacia +Z. Mide unos 0,5 m de largo con la cola y 0,45 de alto de pie.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import OUT_DIR, Rig, reset_scene  # noqa: E402

os.makedirs(OUT_DIR, exist_ok=True)

BODY, STRIPES, WHITE, EYES, PUPIL, NOSE, INNER_EAR, WHISKERS = range(8)

# Cola: sube hacia atrás y la punta se dobla hacia delante (gato contento).
TAIL = [(0.0, 0.235, -0.16), (0.0, 0.272, -0.228), (0.0, 0.33, -0.268), (0.0, 0.40, -0.282),
        (0.0, 0.458, -0.268), (0.0, 0.49, -0.236)]

# Su derecha es -X (mira hacia +Z).
BONES = [
    ("body", (0.0, 0.2, -0.12), (0.0, 0.21, 0.13), None),
    ("head", (0.0, 0.26, 0.15), (0.0, 0.36, 0.22), "body"),
    ("eyes", (0.0, 0.345, 0.262), (0.0, 0.375, 0.262), "head"),
    ("ear_l", (0.042, 0.385, 0.2), (0.052, 0.44, 0.2), "head"),
    ("ear_r", (-0.042, 0.385, 0.2), (-0.052, 0.44, 0.2), "head"),
    ("leg_fl", (0.045, 0.19, 0.1), (0.045, 0.02, 0.11), "body"),
    ("leg_fr", (-0.045, 0.19, 0.1), (-0.045, 0.02, 0.11), "body"),
    ("leg_bl", (0.052, 0.2, -0.11), (0.052, 0.02, -0.13), "body"),
    ("leg_br", (-0.052, 0.2, -0.11), (-0.052, 0.02, -0.13), "body"),
    ("tail_1", TAIL[0], TAIL[2], "body"),
    ("tail_2", TAIL[2], TAIL[4], "tail_1"),
    ("tail_3", TAIL[4], TAIL[5], "tail_2"),
]

TORSO_C = (0.0, 0.2, 0.0)
TORSO_R = (0.086, 0.083, 0.155)


def band_on_torso(m, z, thick=0.011, lift=0.012):
    """Raya oscura en el lomo: corte fino del cuerpo, algo más pequeño y subido, que solo asoma por arriba."""
    k = math.sqrt(max(0.0, 1.0 - (z / TORSO_R[2]) ** 2))
    m.sphere((0.0, TORSO_C[1] + lift, z), 1.0, scale=(TORSO_R[0] * k * 0.96, TORSO_R[1] * k * 0.97, thick),
             segments=14, rings=8, mat=STRIPES)


def build(m):
    m.add_material("body", (0.46, 0.46, 0.50), 0.95)
    m.add_material("stripes", (0.24, 0.24, 0.27), 0.95)
    m.add_material("white", (0.95, 0.93, 0.89), 0.95)
    m.add_material("eyes", (0.80, 0.68, 0.22), 0.25)
    m.add_material("pupil", (0.03, 0.03, 0.035), 0.1)
    m.add_material("nose", (0.86, 0.47, 0.52), 0.6)
    m.add_material("inner_ear", (0.93, 0.64, 0.66), 0.8)
    m.add_material("whiskers", (0.98, 0.97, 0.94), 0.5)

    # Cuerpo: lomo alargado, pechera y tripa blancas, rayas en el lomo.
    m.bone = "body"
    m.sphere(TORSO_C, 1.0, scale=TORSO_R, segments=18, rings=10, mat=BODY)
    m.sphere((0.0, 0.18, 0.112), 0.068, scale=(0.95, 1.05, 0.85), segments=12, rings=8, mat=WHITE)
    m.sphere((0.0, 0.152, 0.0), 0.06, scale=(1.08, 0.66, 2.0), segments=12, rings=8, mat=WHITE)
    m.sphere((0.0, 0.255, 0.15), 0.058, scale=(1.0, 1.1, 1.0), segments=12, rings=8, mat=BODY)
    for z in (-0.105, -0.055, -0.005, 0.045):
        band_on_torso(m, z)

    # Cabeza: cráneo, mofletes, hocico y barbilla blancos, nariz rosa, "M" de atigrado en la frente y bigotes.
    m.bone = "head"
    m.sphere((0.0, 0.335, 0.205), 0.07, scale=(1.15, 0.95, 1.0), segments=16, rings=10, mat=BODY)
    for s in (-1, 1):
        m.sphere((s * 0.035, 0.31, 0.238), 0.042, scale=(1.0, 0.85, 0.9), segments=10, rings=7, mat=BODY)
    m.sphere((0.0, 0.304, 0.262), 0.03, scale=(1.3, 0.85, 0.8), segments=10, rings=7, mat=WHITE)
    m.sphere((0.0, 0.286, 0.25), 0.02, scale=(1.0, 0.8, 1.0), segments=8, rings=6, mat=WHITE)
    m.sphere((0.0, 0.323, 0.287), 0.009, scale=(1.35, 0.8, 0.8), segments=8, rings=5, mat=NOSE)
    for x in (-0.022, 0.0, 0.022):
        c = (x, 0.392, 0.228 - abs(x) * 0.4)
        m.sphere(c, 1.0, scale=(0.0055, 0.006, 0.03), segments=6, rings=4, mat=STRIPES, rotate=("X", -38.0, c))
    for s in (-1, 1):
        m.sphere((s * 0.075, 0.33, 0.2), 1.0, scale=(0.006, 0.026, 0.01), segments=6, rings=4, mat=STRIPES)
        for k, dy in enumerate((-0.006, 0.0, 0.006)):
            m.tube([(s * 0.03, 0.302 + dy, 0.268), (s * 0.075, 0.302 + dy * 2.2, 0.27), (s * 0.115, 0.298 + dy * 3.4, 0.262)],
                   0.0016, sides=3, mat=WHISKERS, cap=False)

    # Ojos (un hueso: se cierran aplastándolos): iris ámbar y pupila vertical.
    m.bone = "eyes"
    for s in (-1, 1):
        m.sphere((s * 0.03, 0.345, 0.262), 0.0175, scale=(1.0, 1.1, 0.62), segments=10, rings=7, mat=EYES)
        m.sphere((s * 0.03, 0.345, 0.2715), 0.0095, scale=(0.5, 1.15, 0.4), segments=8, rings=5, mat=PUPIL)

    # Orejas: cono aplastado con el interior rosa.
    for side, s in (("l", 1), ("r", -1)):
        m.bone = "ear_" + side
        base = (s * 0.042, 0.378, 0.2)
        tilt = ("Z", -s * 16.0, base)
        m.lathe([(0.0, 0.0), (0.031, 0.0), (0.0, 0.062)], segments=8, mat=BODY,
                center=base, scale=(1.0, 1.0, 0.5), rotate=tilt)
        m.lathe([(0.0, 0.004), (0.021, 0.004), (0.0, 0.047)], segments=8, mat=INNER_EAR,
                center=(base[0], base[1], base[2] + 0.009), scale=(1.0, 1.0, 0.3), rotate=tilt)

    # Patas delanteras: rayas y patita blanca.
    for side, s in (("l", 1), ("r", -1)):
        m.bone = "leg_f" + side
        x = s * 0.045
        m.tube([(x, 0.19, 0.1), (x, 0.11, 0.104), (x, 0.03, 0.11)], 0.023, sides=10, mat=BODY, taper=0.3, cap=False)
        m.sphere((x, 0.022, 0.12), 0.022, scale=(1.0, 0.72, 1.3), segments=10, rings=6, mat=WHITE)

    # Patas traseras: muslo redondo (anca) y pata.
    for side, s in (("l", 1), ("r", -1)):
        m.bone = "leg_b" + side
        x = s * 0.052
        m.sphere((x, 0.168, -0.112), 0.06, scale=(0.72, 1.15, 1.05), segments=12, rings=8, mat=BODY)
        m.sphere((s * 0.083, 0.172, -0.112), 1.0, scale=(0.004, 0.03, 0.012), segments=6, rings=4, mat=STRIPES)
        m.tube([(x, 0.13, -0.12), (x, 0.08, -0.125), (x, 0.03, -0.13)], 0.02, sides=10, mat=BODY, taper=0.2, cap=False)
        m.sphere((x, 0.022, -0.118), 0.021, scale=(1.0, 0.72, 1.3), segments=10, rings=6, mat=WHITE)

    # Cola en tres huesos, con anillos y la punta oscura.
    # Cola en tres huesos; una bolita en cada unión tapa el hueco al doblarse. Punta oscura.
    m.bone = "tail_1"
    m.tube(TAIL[0:3], 0.02, sides=10, mat=BODY, taper=0.06, cap=False)
    m.bone = "tail_2"
    m.sphere(TAIL[2], 0.0188, segments=10, rings=6, mat=BODY)
    m.tube(TAIL[2:5], 0.0188, sides=10, mat=BODY, taper=0.08, cap=False)
    m.bone = "tail_3"
    m.sphere(TAIL[4], 0.0173, segments=10, rings=6, mat=BODY)
    m.tube(TAIL[4:6], 0.0172, sides=10, mat=STRIPES, taper=0.45)


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def at(points, f):
    """Valor suavizado en el fotograma f a partir de [(fotograma, valor), ...]."""
    for (f0, v0), (f1, v1) in zip(points, points[1:]):
        if f0 <= f <= f1:
            k = smooth((f - f0) / max(f1 - f0, 1e-6))
            if isinstance(v0, tuple):
                return tuple(a + (b - a) * k for a, b in zip(v0, v1))
            return v0 + (v1 - v0) * k
    return points[-1][1]


# --- Poses -----------------------------------------------------------------
# Sentado: el lomo se levanta por delante sobre la cadera (que baja casi al suelo), las patas delanteras
# quedan rectas, las traseras dobladas hacia delante (las ancas en el suelo) y la cola tumbada a un lado.
SIT_BODY = -0.75
SIT_LOC = (0.0, -0.13, 0.03)


def sit(head=(0.0, 0.0, 0.0), fl=None, fr=None, tail_sway=0.0, tip=0.0, breath=0.0):
    """Giros de la pose sentada. head/fl/fr: giro extra sobre la pose (las patas, en ejes absolutos)."""
    rots = {
        "body": (SIT_BODY, 0.0, 0.0),
        "head": (0.6 + head[0], head[1], head[2]),
        "leg_fl": ((fl or (0.0, 0.0, 0.0))[0] - SIT_BODY, (fl or (0, 0, 0))[1], (fl or (0, 0, 0))[2]),
        "leg_fr": ((fr or (0.0, 0.0, 0.0))[0] - SIT_BODY, (fr or (0, 0, 0))[1], (fr or (0, 0, 0))[2]),
        "leg_bl": (-1.25 - SIT_BODY, 0.0, -0.12),
        "leg_br": (-1.25 - SIT_BODY, 0.0, 0.12),
        "tail_1": (-0.15, 1.25, 0.0),
        "tail_2": (-0.9, 0.9 + tail_sway, 0.0),
        "tail_3": (-0.2, 0.8 + tip, 0.0),
    }
    locs = {"body": (SIT_LOC[0], SIT_LOC[1] + breath, SIT_LOC[2])}
    return rots, locs


def animate(m):
    # Paso: patas en diagonal (delantera izquierda con trasera derecha), el lomo sube y baja un poco,
    # la cola alta se mece.
    for name, frames, swing, lift, bob in (("walk", 8, 0.36, 0.016, 0.005), ("trot", 6, 0.55, 0.026, 0.011)):
        m.action(name, frames)
        for f in range(frames + 1):
            ph = math.tau * f / frames
            rots, locs = {}, {}
            for leg, off in (("leg_fl", 0.0), ("leg_br", 0.0), ("leg_fr", math.pi), ("leg_bl", math.pi)):
                a = ph + off
                rots[leg] = (-swing * math.sin(a), 0.0, 0.0)
                locs[leg] = (0.0, lift * max(0.0, math.cos(a)), 0.0)
            locs["body"] = (0.0, bob * math.cos(2.0 * ph), 0.0)
            rots["body"] = (0.0, 0.0, 0.03 * math.sin(ph))
            rots["head"] = (0.06 * math.cos(2.0 * ph), 0.0, -0.03 * math.sin(ph))
            rots["tail_1"] = (-0.25, 0.08 * math.sin(ph), 0.0)
            rots["tail_2"] = (0.0, 0.14 * math.sin(ph - 0.9), 0.0)
            rots["tail_3"] = (0.0, 0.18 * math.sin(ph - 1.8), 0.0)
            m.pose(name, f, rots, locs)

    # De pie: respira y mece la cola, mira un poco a un lado.
    m.action("stand", 24)
    for f in range(25):
        ph = math.tau * f / 24.0
        m.pose("stand", f, {
            "head": (0.0, 0.12 * math.sin(ph), 0.0),
            "tail_1": (-0.2, 0.0, 0.0),
            "tail_2": (0.0, 0.18 * math.sin(ph), 0.0),
            "tail_3": (0.0, 0.25 * math.sin(ph - 0.8), 0.0),
        }, {"body": (0.0, 0.003 * math.sin(ph), 0.0)})

    # Sentado: respira y sacude la punta de la cola de vez en cuando.
    m.action("sit", 24)
    tip = [(0, 0.0), (14, 0.0), (17, 0.5), (20, -0.1), (24, 0.0)]
    for f in range(25):
        ph = math.tau * f / 24.0
        rots, locs = sit(head=(0.0, 0.08 * math.sin(ph), 0.0), tip=at(tip, f), breath=0.003 * math.sin(ph))
        m.pose("sit", f, rots, locs)

    # Aseo: sube la pata derecha a la boca, la lame (la cabeza sube y baja) y se la pasa por la cara.
    m.action("groom", 36)
    paw = [(0, (0.0, 0.0, 0.0)), (6, (-2.2, 0.0, 0.28)), (24, (-2.2, 0.0, 0.28)), (30, (-2.45, 0.0, 0.1)),
           (33, (-2.0, 0.0, 0.2)), (36, (0.0, 0.0, 0.0))]
    for f in range(37):
        lick = 0.0 if f < 6 or f > 24 else 0.16 * max(0.0, math.sin(math.tau * (f - 6) / 6.0))
        hx = at([(0, 0.0), (6, 0.22), (24, 0.22), (30, 0.05), (36, 0.0)], f) + lick
        hz = at([(0, 0.0), (6, 0.15), (24, 0.15), (30, 0.35), (36, 0.0)], f)
        rots, locs = sit(head=(hx, -0.2 * hz, hz), fr=at(paw, f))
        m.pose("groom", f, rots, locs)

    # Siesta: tumbado hecho un ovillo, la cabeza sobre las patas, los ojos cerrados y la cola alrededor.
    m.action("sleep", 48)
    for f in range(49):
        ph = math.tau * f / 48.0
        m.pose("sleep", f, {
            "body": (0.0, 0.0, 0.0),
            "head": (0.42, 0.35, 0.15),
            "leg_fl": (1.5, 0.0, 0.0),
            "leg_fr": (1.5, 0.0, 0.0),
            "leg_bl": (-1.4, 0.0, -0.15),
            "leg_br": (-1.4, 0.0, 0.15),
            "tail_1": (-0.6, 1.45, 0.0),
            "tail_2": (-1.1, 1.1, 0.0),
            "tail_3": (-0.2, 1.0, 0.0),
        }, {"body": (0.0, -0.118 + 0.004 * math.sin(ph), 0.0)}, scales={"eyes": (1.0, 0.12, 1.0)})

    # Zarpazo sentado: sube la pata derecha, la sostiene y golpea el suelo delante (el ovillo) en el 13.
    m.action("bat", 24)
    paw = [(0, (0.0, 0.0, 0.0)), (7, (-1.4, 0.0, -0.15)), (10, (-1.5, 0.0, -0.18)), (13, (-0.35, 0.0, -0.1)),
           (16, (-0.45, 0.0, -0.1)), (22, (-0.05, 0.0, 0.0)), (24, (0.0, 0.0, 0.0))]
    head = [(0, (0.12, 0.0, 0.0)), (7, (0.05, -0.08, 0.1)), (13, (0.25, -0.05, 0.06)), (24, (0.12, 0.0, 0.0))]
    for f in range(25):
        rots, locs = sit(head=at(head, f), fr=at(paw, f), tail_sway=0.25 * math.sin(math.tau * f / 24.0))
        m.pose("bat", f, rots, locs)

    # Caricia: sentado, ojos cerrados, frota la cabeza contra la mano (de lado a lado) y la cola tiesa.
    m.action("pet", 24)
    for f in range(25):
        ph = math.tau * f / 24.0
        rots, locs = sit(head=(-0.12, 0.18 * math.sin(ph), 0.22 * math.sin(ph)))
        rots["tail_1"] = (1.25, 0.0, 0.0)
        rots["tail_2"] = (0.1, 0.12 * math.sin(ph), 0.0)
        rots["tail_3"] = (0.3, 0.2 * math.sin(ph - 0.7), 0.0)
        rots["ear_l"] = (0.25, 0.0, 0.2)
        rots["ear_r"] = (0.25, 0.0, -0.2)
        locs["body"] = (SIT_LOC[0], SIT_LOC[1] + 0.003 * math.sin(2.0 * ph), SIT_LOC[2])
        m.pose("pet", f, rots, locs, scales={"eyes": (1.0, 0.12, 1.0)})

    # Tumbado de lado (sobre el costado derecho): el lomo gira sobre su largo y baja hasta apoyar el costado,
    # las patas sueltas hacia un lado, la cabeza algo levantada y la cola barriendo el suelo despacio.
    lie_z = 1.42
    lie_y = -0.112

    def lie_rots(ph, head_up=0.0):
        return {
            "body": (0.0, 0.0, lie_z),
            "head": (0.15 + 0.1 * head_up, 0.1, -0.95 + 0.35 * head_up),
            "leg_fl": (0.35 + 0.05 * math.sin(ph), 0.0, 0.1),
            "leg_fr": (0.55, 0.0, -0.05),
            "leg_bl": (-0.35, 0.0, 0.1),
            "leg_br": (-0.15 + 0.04 * math.sin(ph + 1.0), 0.0, -0.05),
            "tail_1": (-1.1, 0.0, 0.0),
            "tail_2": (-0.35, 0.35 * math.sin(ph), 0.0),
            "tail_3": (-0.2, 0.45 * math.sin(ph - 0.8), 0.0),
        }

    m.action("lie", 32)
    look = [(0, 0.0), (10, 0.0), (14, 1.0), (22, 1.0), (26, 0.0), (32, 0.0)]
    for f in range(33):
        ph = math.tau * f / 32.0
        m.pose("lie", f, lie_rots(ph, at(look, f)), {"body": (0.0, lie_y + 0.004 * math.sin(ph), 0.0)})

    # Revolcarse panza arriba: el lomo se balancea de un lado a otro sobre la espalda, las patas delanteras
    # dobladas hacia el pecho, las traseras pataleando un poco, la cabeza hacia atrás mirando de lado.
    m.action("roll", 36)
    for f in range(37):
        ph = math.tau * f / 36.0
        sway = math.sin(ph)
        kick = math.sin(2.0 * ph)
        m.pose("roll", f, {
            "body": (0.0, 0.0, math.pi + 0.6 * sway),
            "head": (-0.35, 0.0, -0.45 * sway - 0.2),
            "leg_fl": (1.25 + 0.25 * max(0.0, kick), 0.0, 0.25),
            "leg_fr": (1.25 + 0.25 * max(0.0, -kick), 0.0, -0.25),
            "leg_bl": (0.55 + 0.35 * kick, 0.0, 0.3),
            "leg_br": (0.55 - 0.35 * kick, 0.0, -0.3),
            "ear_l": (-0.3, 0.0, 0.25),
            "ear_r": (-0.3, 0.0, -0.25),
            "tail_1": (-1.2, 0.0, 0.0),
            "tail_2": (-0.25, 0.5 * math.sin(ph - 0.6), 0.0),
            "tail_3": (0.0, 0.5 * math.sin(ph - 1.4), 0.0),
        }, {"body": (0.0, -0.115 + 0.006 * abs(sway), 0.0)}, scales={"eyes": (1.0, 0.45, 1.0)})

    # Estirarse: el pecho baja hacia el suelo con las patas delanteras estiradas hacia delante, el culete
    # queda en alto (el lomo gira sobre la cadera), la cola tiesa y los ojos entornados; luego vuelve.
    m.action("stretch", 30)
    k_s = [(0, 0.0), (8, 1.0), (20, 1.0), (28, 0.0), (30, 0.0)]
    for f in range(31):
        k = at(k_s, f)
        tilt = 0.42 * k
        m.pose("stretch", f, {
            "body": (tilt, 0.0, 0.0),
            "head": (-0.55 * k, 0.0, 0.0),
            "leg_fl": (0.95 * k, 0.0, 0.0),
            "leg_fr": (0.95 * k, 0.0, 0.0),
            "leg_bl": (-tilt - 0.12 * k, 0.0, 0.0),
            "leg_br": (-tilt - 0.12 * k, 0.0, 0.0),
            "tail_1": (-0.2 - 0.5 * k, 0.0, 0.0),
            "tail_2": (0.0, 0.0, 0.0),
            "tail_3": (0.3 * k, 0.0, 0.0),
            "ear_l": (-0.25 * k, 0.0, 0.0),
            "ear_r": (-0.25 * k, 0.0, 0.0),
        }, {"body": (0.0, -0.01 * k, 0.0)}, scales={"eyes": (1.0, 1.0 - 0.7 * k, 1.0)})

    # Amasar: sentado, las patas delanteras suben y aprietan por turnos, ojos entornados y la cola quieta.
    m.action("knead", 24)
    for f in range(25):
        ph = math.tau * f / 24.0
        a = max(0.0, math.sin(ph))
        b = max(0.0, -math.sin(ph))
        rots, locs = sit(head=(0.1, 0.05 * math.sin(ph), 0.0), fl=(-0.5 * a, 0.0, 0.0), fr=(-0.5 * b, 0.0, 0.0),
                         breath=0.004 * math.sin(2.0 * ph))
        rots["body"] = (SIT_BODY + 0.04 * math.sin(2.0 * ph), 0.0, 0.0)
        m.pose("knead", f, rots, locs, scales={"eyes": (1.0, 0.35, 1.0)})

    # Carrera loca: galope (delanteras juntas, traseras juntas), el lomo cabecea, las orejas hacia atrás
    # y la cola recta hacia atrás.
    m.action("gallop", 6)
    for f in range(7):
        ph = math.tau * f / 6.0
        m.pose("gallop", f, {
            "body": (0.14 * math.sin(ph), 0.0, 0.0),
            "head": (-0.14 * math.sin(ph), 0.0, 0.0),
            "leg_fl": (-0.75 * math.sin(ph + 0.2), 0.0, 0.0),
            "leg_fr": (-0.75 * math.sin(ph), 0.0, 0.0),
            "leg_bl": (-0.75 * math.sin(ph + math.pi + 0.2), 0.0, 0.0),
            "leg_br": (-0.75 * math.sin(ph + math.pi), 0.0, 0.0),
            "ear_l": (-0.6, 0.0, 0.35),
            "ear_r": (-0.6, 0.0, -0.35),
            "tail_1": (-0.9, 0.0, 0.0),
            "tail_2": (-0.4 + 0.15 * math.sin(ph), 0.0, 0.0),
            "tail_3": (-0.2, 0.0, 0.0),
        }, {"body": (0.0, 0.018 * abs(math.sin(ph)), 0.0)})

    # Parpadeo: solo los ojos.
    m.action("blink", 4)
    for f, k in ((0, 1.0), (1, 0.12), (2, 0.12), (4, 1.0)):
        m.pose("blink", f, {"eyes": (0.0, 0.0, 0.0)}, only=True, scales={"eyes": (1.0, k, 1.0)})

    # Sacudida de oreja: dos golpecitos hacia fuera; solo anima esa oreja.
    for side, s in (("l", 1), ("r", -1)):
        name = "ear_twitch_" + side
        m.action(name, 6)
        flick = [(0, 0.0), (1, 1.0), (3, 0.55), (4, 1.0), (6, 0.0)]
        for f in range(7):
            k = at(flick, f)
            m.pose(name, f, {"ear_" + side: (-0.15 * k, s * 0.35 * k, -s * 0.45 * k)}, only=True)


def main():
    reset_scene()
    m = Rig("cat", BONES)
    build(m)
    animate(m)
    m.export(fps=12)


main()
