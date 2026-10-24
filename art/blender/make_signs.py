"""Genera los carteles de la mercería (tablas, marcos, iconos pirograbados y cordeles) en GLB para Godot.

Uso:
  blender --background --factory-startup --python art/blender/make_signs.py -- art/models

El texto NO va en el modelo: el juego pone Label3D encima (se traduce al inglés). Aquí solo la madera,
el marco, los iconos y lo que cuelga. scripts/room/shop_sign.gd monta cada cartel y les da color.

Modelos (frente hacia +Z, origen indicado):
  sign_section      tabla de sección 2,0 × 0,42 con moldura y dos tornillos (origen = centro)
  sign_main         cartel principal 3,0 × 0,62 con carrete de hilo, hebra y aguja (origen = centro)
  sign_small        tablilla 0,46 × 0,28 colgada de un clavo con bramante (origen = centro de la tabla)
  sign_door         placa esmaltada de CERRADO/ABIERTO con su cordel (origen = punto del gancho; gira en Y)
  sign_door_hook    gancho de latón atornillado al larguero de la puerta (origen = punta del gancho)
  sign_open         placa esmaltada ancha (0,78 × 0,24) de ¡ABIERTO! con dos cordeles (origen = arriba, entre los cordeles)
  sign_icon_yarn / _button / _fabric / _scissors / _box
                    iconos pirograbados de unos 0,24 m (origen = centro, apoyados en z = 0)

Superficies (el juego decide el material de cada una):
  wood    tabla de madera          frame   moldura pintada (color de la sección)
  burn    pirograbado (marrón)     metal   latón (tornillos, gancho, ojales, aguja)
  enamel  esmalte crema            rim     borde esmaltado (color del cartel)
  cord    cordel / bramante        thread  hilo del carrete
"""
import math
import os
import sys

import bmesh

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import Model, OUT_DIR, reset_scene  # noqa: E402

os.makedirs(OUT_DIR, exist_ok=True)

BRASS = (0.83, 0.64, 0.32)
OAK = (0.80, 0.60, 0.38)
BURN = (0.20, 0.11, 0.06)
CREAM = (0.96, 0.92, 0.82)
GREEN = (0.20, 0.38, 0.33)
TWINE = (0.72, 0.60, 0.42)


# ---------------------------------------------------------------- formas planas
def rrect(w, h, r, seg=4):
    """Contorno de un rectángulo de esquinas redondeadas (sentido antihorario)."""
    r = max(1e-4, min(r, w * 0.5 - 1e-4, h * 0.5 - 1e-4))
    pts = []
    for cx, cy, a0 in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90),
                       (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)):
        for k in range(seg + 1):
            a = math.radians(a0 + 90.0 * k / seg)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def circle(cx, cy, r, seg=20, a0=0.0, a1=360.0, rx=None):
    """Puntos de una circunferencia (o un arco, o una elipse con rx)."""
    rx = r if rx is None else rx
    n = seg if abs(a1 - a0) >= 360.0 else seg + 1
    span = a1 - a0
    out = []
    for k in range(n):
        a = math.radians(a0 + span * k / seg)
        out.append((cx + rx * math.cos(a), cy + r * math.sin(a)))
    return out


def prism(m, pts, z0, z1, mat, bevel=0.0, grain="x"):
    """Contorno plano (en XY) extruido de z0 a z1, con las aristas de las tapas biseladas."""
    part = bmesh.new()
    bot = [part.verts.new((x, y, z0)) for (x, y) in pts]
    top = [part.verts.new((x, y, z1)) for (x, y) in pts]
    part.faces.new(list(reversed(bot)))
    part.faces.new(top)
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        part.faces.new((bot[i], bot[j], top[j], top[i]))
    if bevel > 0:
        caps = [e for e in part.edges if abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-7]
        bmesh.ops.bevel(part, geom=caps, offset=bevel, offset_type="OFFSET", segments=2,
                        profile=0.5, affect="EDGES")
    m._finish(part, grain, mat, None)


def ring(m, outer, inner, z0, z1, mat, grain="x"):
    """Marco plano entre dos contornos con el mismo número de puntos."""
    part = bmesh.new()
    n = len(outer)
    ob = [part.verts.new((x, y, z0)) for (x, y) in outer]
    ot = [part.verts.new((x, y, z1)) for (x, y) in outer]
    ib = [part.verts.new((x, y, z0)) for (x, y) in inner]
    it = [part.verts.new((x, y, z1)) for (x, y) in inner]
    for i in range(n):
        j = (i + 1) % n
        part.faces.new((ot[i], ot[j], it[j], it[i]))
        part.faces.new((ob[j], ob[i], ib[i], ib[j]))
        part.faces.new((ob[i], ob[j], ot[j], ot[i]))
        part.faces.new((ib[j], ib[i], it[i], it[j]))
    m._finish(part, grain, mat, None)


def stroke(m, pts, width, z0, z1, mat, closed=False, taper_end=1.0):
    """Trazo plano de grosor `width` a lo largo de una polilínea (para dibujar los iconos)."""
    n = len(pts)
    left, right = [], []
    for i in range(n):
        if closed:
            a, b = pts[(i - 1) % n], pts[(i + 1) % n]
        else:
            a, b = pts[max(i - 1, 0)], pts[min(i + 1, n - 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / ln, dx / ln
        t = i / max(n - 1, 1)
        hw = width * 0.5 * (1.0 + (taper_end - 1.0) * t)
        left.append((pts[i][0] + nx * hw, pts[i][1] + ny * hw))
        right.append((pts[i][0] - nx * hw, pts[i][1] - ny * hw))
    part = bmesh.new()
    lt = [part.verts.new((x, y, z1)) for (x, y) in left]
    rt = [part.verts.new((x, y, z1)) for (x, y) in right]
    lb = [part.verts.new((x, y, z0)) for (x, y) in left]
    rb = [part.verts.new((x, y, z0)) for (x, y) in right]
    segs = n if closed else n - 1
    for i in range(segs):
        j = (i + 1) % n
        part.faces.new((lt[i], rt[i], rt[j], lt[j]))
        part.faces.new((lb[j], rb[j], rb[i], lb[i]))
        part.faces.new((lb[i], lt[i], lt[j], lb[j]))
        part.faces.new((rb[j], rt[j], rt[i], rb[i]))
    if not closed:
        part.faces.new((lb[0], rb[0], rt[0], lt[0]))
        part.faces.new((lt[-1], rt[-1], rb[-1], lb[-1]))
    m._finish(part, "x", mat, None)


# ---------------------------------------------------------------- tablas de madera
def framed_board(m, w, h, thick, frame_w, r, wood=0, frame=1):
    """Tabla con moldura: panel de madera algo hundido y marco redondeado que sobresale."""
    z0, z1 = -thick / 2, thick / 2
    # Panel de madera (cara a z1) y moldura biselada que sobresale 4 mm por delante.
    prism(m, rrect(w - frame_w, h - frame_w, r * 0.6), z0, z1, wood, bevel=0.0)
    outer = rrect(w, h, r, 4)
    inner = rrect(w - frame_w * 2, h - frame_w * 2, max(r - frame_w, 0.006), 4)
    ring(m, outer, inner, z0 + 0.002, z1 + 0.004, frame)
    # Filete fino por dentro de la moldura (el "fresado").
    ring(m, rrect(w - frame_w * 2 + 0.008, h - frame_w * 2 + 0.008, max(r - frame_w + 0.004, 0.006), 4),
         inner, z1 + 0.004, z1 + 0.007, frame)
    return z1  # cara de la madera


def make_sign_section():
    reset_scene()
    m = Model("sign_section", 401)
    m.add_material("wood", OAK, 0.7)                 # 0
    m.add_material("frame", (0.42, 0.55, 0.50), 0.6)  # 1
    m.add_material("metal", BRASS, 0.3, metallic=1.0)  # 2
    w, h = 2.0, 0.42
    face = framed_board(m, w, h, 0.03, 0.045, 0.05)
    for sx in (-1, 1):
        m.cylinder((sx * (w / 2 - 0.0225), 0, face + 0.008), 0.009, 0.006, axis="z", segments=10,
                   round_edge=0.002, mat=2)
    m.export(center_y=False)


def make_sign_main():
    reset_scene()
    m = Model("sign_main", 402)
    m.add_material("wood", (0.50, 0.32, 0.19), 0.6)   # 0 nogal
    m.add_material("frame", (0.78, 0.58, 0.30), 0.45)  # 1 moldura dorada
    m.add_material("metal", (0.80, 0.81, 0.84), 0.25, metallic=1.0)  # 2 aguja
    m.add_material("thread", (0.70, 0.16, 0.18), 0.85)  # 3 hilo rojo
    m.add_material("spool", (0.86, 0.68, 0.46), 0.6)   # 4 madera clara del carrete
    w, h = 3.0, 0.62
    face = framed_board(m, w, h, 0.035, 0.06, 0.07)
    # Carrete de pie a la izquierda: dos valonas, el hilo enrollado y el agujero de arriba.
    sx, sz = -1.28, face + 0.07
    y0, y1 = -0.16, 0.14
    m.cylinder((sx, y0 + 0.012, sz), 0.07, 0.024, segments=20, round_edge=0.006, mat=4)
    m.cylinder((sx, y1 - 0.012, sz), 0.07, 0.024, segments=20, round_edge=0.006, mat=4)
    m.cylinder((sx, (y0 + y1) / 2, sz), 0.035, y1 - y0 - 0.02, segments=14, mat=4)
    m.lathe([(0.0, y0 + 0.024), (0.052, y0 + 0.024), (0.058, y0 + 0.05), (0.058, y1 - 0.05),
             (0.052, y1 - 0.024), (0.0, y1 - 0.024)], 20, center=(sx, 0, sz), mat=3)
    m.cylinder((sx, y1, sz), 0.012, 0.004, segments=10, mat=0)
    # Hebra suelta que sale del carrete y ondula por abajo hasta una aguja a la derecha.
    pts = [(sx + 0.05, -0.1, sz - 0.02), (sx + 0.14, -0.2, face + 0.02), (-0.7, -0.235, face + 0.008)]
    for k in range(14):
        x = -0.55 + k * 0.13
        pts.append((x, -0.235 + 0.018 * math.sin(k * 1.1), face + 0.008))
    pts.append((1.25, -0.2, face + 0.012))
    m.tube(pts, 0.0045, 6, mat=3, cap=False)
    # Aguja inclinada con el ojo arriba.
    nx0, ny0, nx1, ny1 = 1.22, -0.23, 1.33, 0.06
    m.tube([(nx0, ny0, face + 0.012), (nx1, ny1, face + 0.012)], 0.005, 8, mat=2, taper=0.8, cap=True)
    m.torus((nx1 - 0.004, ny1 + 0.004, face + 0.012), 0.012, 0.003, axis="z", major_seg=12, minor_seg=4, mat=2)
    m.tube([(1.25, -0.2, face + 0.012), (1.31, 0.0, face + 0.016), (1.325, 0.06, face + 0.014)], 0.0035, 5, mat=3)
    m.export(center_y=False)


def make_sign_small():
    reset_scene()
    m = Model("sign_small", 403)
    m.add_material("wood", OAK, 0.7)                  # 0
    m.add_material("frame", (0.55, 0.40, 0.30), 0.6)   # 1
    m.add_material("metal", (0.35, 0.33, 0.32), 0.4, metallic=1.0)  # 2 clavo
    m.add_material("cord", TWINE, 0.9)                 # 3
    w, h = 0.46, 0.28
    face = framed_board(m, w, h, 0.02, 0.026, 0.03)
    # Dos hembrillas arriba, el bramante en V y el clavo de la pared.
    nail = (0.0, h / 2 + 0.11, -0.004)
    for sx in (-1, 1):
        eye = (sx * (w / 2 - 0.05), h / 2 + 0.008, 0.0)
        m.torus(eye, 0.008, 0.0022, axis="z", major_seg=10, minor_seg=4, mat=2)
        m.tube([(eye[0], eye[1] + 0.006, 0.0), (eye[0] * 0.5, (eye[1] + nail[1]) * 0.5 + 0.004, 0.001),
                (0.0, nail[1] - 0.004, 0.003)], 0.0028, 5, mat=3, cap=False)
    m.cylinder((nail[0], nail[1], nail[2] + 0.004), 0.0032, 0.022, axis="z", segments=8, mat=2)
    m.cylinder((nail[0], nail[1], nail[2] + 0.016), 0.008, 0.003, axis="z", segments=10, mat=2)
    m.export(center_y=False)


# ---------------------------------------------------------------- placas esmaltadas
def enamel_plate(m, w, h, r, cy, rim=0, enamel=1):
    """Placa esmaltada de doble cara: borde de color y las dos caras crema (centro en y = cy)."""
    pts = [(x, y + cy) for (x, y) in rrect(w, h, r, 5)]
    prism(m, pts, -0.004, 0.004, rim, bevel=0.0015)
    b = 0.014
    inner = [(x, y + cy) for (x, y) in rrect(w - b * 2, h - b * 2, r - b, 5)]
    prism(m, inner, -0.0055, 0.0055, enamel, bevel=0.0008)
    # Filete del color del borde por dentro de la cara crema (las dos caras).
    line_o = [(x, y + cy) for (x, y) in rrect(w - b * 2 - 0.012, h - b * 2 - 0.012, r - b - 0.006, 5)]
    line_i = [(x, y + cy) for (x, y) in rrect(w - b * 2 - 0.02, h - b * 2 - 0.02, r - b - 0.01, 5)]
    ring(m, line_o, line_i, 0.0055, 0.0062, rim)
    ring(m, line_o, line_i, -0.0062, -0.0055, rim)


def make_sign_door():
    reset_scene()
    m = Model("sign_door", 404)
    m.add_material("rim", GREEN, 0.35)                 # 0
    m.add_material("enamel", CREAM, 0.35)              # 1
    m.add_material("metal", BRASS, 0.3, metallic=1.0)  # 2
    m.add_material("cord", (0.55, 0.20, 0.22), 0.85)   # 3 cordón granate
    w, h, cy = 0.30, 0.15, -0.30
    enamel_plate(m, w, h, 0.035, cy)
    top = cy + h / 2
    for sx in (-1, 1):
        eye = (sx * (w / 2 - 0.035), top - 0.018)
        m.torus((eye[0], eye[1], 0.0), 0.0075, 0.0022, axis="z", major_seg=12, minor_seg=4, mat=2)
        m.tube([(eye[0], eye[1] + 0.004, 0.0), (eye[0] * 0.55, (eye[1] + 0.0) * 0.5, 0.0),
                (0.0, -0.006, 0.0)], 0.0025, 5, mat=3, cap=False)
    # Anilla de la que cuelga (se apoya en el gancho).
    m.torus((0, -0.004, 0), 0.007, 0.0018, axis="x", major_seg=10, minor_seg=4, mat=2)
    m.export(center_y=False)


def make_sign_door_hook():
    reset_scene()
    m = Model("sign_door_hook", 405)
    m.add_material("metal", BRASS, 0.3, metallic=1.0)  # 0
    reach = 0.15
    # Pletina atornillada al larguero (detrás, en z = -reach) y brazo con la punta doblada hacia arriba.
    m.box((0, 0.0, -reach - 0.002), (0.03, 0.05, 0.004), bevel=0.0015, segments=1)
    m.tube([(0, 0.0, -reach), (0, 0.0, -0.04), (0, -0.004, -0.008), (0, 0.004, 0.006), (0, 0.016, 0.01)],
           0.0035, 8, cap=True)
    m.export(center_y=False)


def make_sign_open():
    reset_scene()
    m = Model("sign_open", 406)
    m.add_material("rim", GREEN, 0.35)                 # 0
    m.add_material("enamel", CREAM, 0.35)              # 1
    m.add_material("metal", BRASS, 0.3, metallic=1.0)  # 2
    m.add_material("cord", TWINE, 0.9)                 # 3
    w, h, drop = 0.78, 0.24, 0.06
    cy = -drop - h / 2
    enamel_plate(m, w, h, 0.06, cy)
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.09)
        m.torus((x, -drop - 0.016, 0.0), 0.008, 0.0024, axis="z", major_seg=12, minor_seg=4, mat=2)
        m.tube([(x, -drop - 0.01, 0.0), (x, 0.0, 0.0)], 0.0028, 5, mat=3, cap=False)
        m.torus((x, 0.004, 0.0), 0.007, 0.002, axis="x", major_seg=10, minor_seg=4, mat=2)
    m.export(center_y=False)


# ---------------------------------------------------------------- iconos pirograbados
Z0, Z1 = 0.0, 0.0025
LW = 0.012


def icon(name, seed):
    reset_scene()
    m = Model("sign_icon_" + name, seed)
    m.add_material("burn", BURN, 0.9)
    return m


def make_icon_yarn():
    m = icon("yarn", 410)
    R = 0.1
    stroke(m, circle(0, 0, R, 28), LW, Z0, Z1, 0, closed=True)
    # Vueltas de hebra: dos haces de arcos paralelos (arcos de circunferencias concéntricas
    # recortados dentro del ovillo) que se cruzan.
    for (cx, cy, radii) in ((-0.15, 0.15, (0.11, 0.155, 0.2)), (0.2, 0.1, (0.15, 0.2))):
        for r in radii:
            full = circle(cx, cy, r, 96)
            inside = [math.hypot(*p) < R - 0.014 for p in full]
            if all(inside) or not any(inside):
                continue
            # La circunferencia empieza en un ángulo cualquiera: se empieza donde entra en el ovillo.
            start = next(i for i in range(96) if inside[i] and not inside[i - 1])
            arc = []
            i = start
            while inside[i % 96] and len(arc) < 96:
                arc.append(full[i % 96])
                i += 1
            if len(arc) >= 2:
                stroke(m, arc, LW * 0.7, Z0, Z1, 0)
    # Hebra suelta que se aleja rizándose.
    tail = [(0.07, -0.072), (0.11, -0.095), (0.15, -0.09), (0.165, -0.06), (0.145, -0.04), (0.125, -0.06),
            (0.15, -0.105), (0.19, -0.115)]
    stroke(m, tail, LW * 0.75, Z0, Z1, 0)
    m.export(center_y=False)


def make_icon_button():
    m = icon("button", 411)
    stroke(m, circle(0, 0, 0.1, 28), LW, Z0, Z1, 0, closed=True)
    stroke(m, circle(0, 0, 0.074, 24), LW * 0.6, Z0, Z1, 0, closed=True)
    for (x, y) in ((-0.024, 0.024), (0.024, 0.024), (-0.024, -0.024), (0.024, -0.024)):
        prism(m, circle(x, y, 0.0135, 10), Z0, Z1, 0)
    # Hilo cosido en cruz entre los agujeros.
    stroke(m, [(-0.024, 0.024), (0.024, -0.024)], LW * 0.5, Z0, Z1 * 0.8, 0)
    stroke(m, [(0.024, 0.024), (-0.024, -0.024)], LW * 0.5, Z0, Z1 * 0.8, 0)
    m.export(center_y=False)


def make_icon_fabric():
    m = icon("fabric", 412)
    # Pila de telas dobladas (tres capas, cada una algo más estrecha) y un lazo de cinta encima.
    for k, y in enumerate((-0.088, -0.038, 0.012)):
        w = 0.21 - k * 0.014
        layer = [(x, yy + y) for (x, yy) in rrect(w, 0.044, 0.018, 3)]
        stroke(m, layer, LW, Z0, Z1, 0, closed=True)
        if k == 1:
            for x in (-0.06, -0.02, 0.02, 0.06):
                prism(m, circle(x, y, 0.0065, 8), Z0, Z1, 0)
        elif k == 0:
            stroke(m, [(-w / 2 + 0.03, y), (w / 2 - 0.03, y)], LW * 0.45, Z0, Z1, 0)
        else:
            for x in (-0.05, 0.0, 0.05):
                stroke(m, [(x - 0.012, y - 0.01), (x + 0.012, y + 0.01)], LW * 0.45, Z0, Z1, 0)
    # Lazo: dos lazadas, el nudo y las dos puntas que caen sobre la pila.
    by = 0.075
    for sx in (-1, 1):
        stroke(m, circle(sx * 0.034, by + 0.004, 0.022, 14, rx=0.032), LW * 0.85, Z0, Z1, 0, closed=True)
        stroke(m, [(sx * 0.006, by - 0.006), (sx * 0.022, by - 0.03), (sx * 0.03, by - 0.04)], LW * 0.85, Z0, Z1, 0)
    prism(m, circle(0.0, by, 0.011, 10), Z0, Z1 * 1.2, 0)
    m.export(center_y=False)


def make_icon_scissors():
    m = icon("scissors", 413)
    # Ojos (anillas) abajo y hojas cruzadas hacia arriba.
    for sx in (-1, 1):
        stroke(m, circle(sx * 0.055, -0.07, 0.034, 20), LW, Z0, Z1, 0, closed=True)
    for sx in (-1, 1):
        base = (sx * 0.042, -0.04)
        tip = (-sx * 0.05, 0.125)
        dx, dy = tip[0] - base[0], tip[1] - base[1]
        ln = math.hypot(dx, dy)
        nx, ny = -dy / ln, dx / ln
        wd = 0.013
        blade = [(base[0] + nx * wd, base[1] + ny * wd), (tip[0], tip[1]), (base[0] - nx * wd, base[1] - ny * wd)]
        if sx < 0:
            blade.reverse()
        prism(m, blade, Z0, Z1, 0)
    prism(m, circle(0.0, 0.034, 0.011, 10), Z0, Z1 * 1.3, 0)
    m.export(center_y=False)


def make_icon_box():
    m = icon("box", 414)
    # Caja de cartón desmontada y plana: cuatro paneles con sus pliegues y las solapas arriba y abajo.
    w, h = 0.22, 0.1
    xs = [-w / 2, -0.04, 0.0, 0.07, w / 2]
    stroke(m, [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)], LW, Z0, Z1, 0, closed=True)
    for x in xs[1:-1]:
        stroke(m, [(x, -h / 2), (x, h / 2)], LW * 0.55, Z0, Z1, 0)
    for k in range(4):
        a, b = xs[k] + 0.006, xs[k + 1] - 0.006
        fl = 0.045 if k % 2 == 0 else 0.03
        stroke(m, [(a, h / 2), (a + 0.008, h / 2 + fl), (b - 0.008, h / 2 + fl), (b, h / 2)], LW * 0.7, Z0, Z1, 0)
        stroke(m, [(a, -h / 2), (a + 0.008, -h / 2 - fl), (b - 0.008, -h / 2 - fl), (b, -h / 2)], LW * 0.7, Z0, Z1, 0)
    # Flecha de "plegar" sobre el panel grande.
    stroke(m, circle(-0.08, 0.0, 0.024, 10, 200, 340), LW * 0.5, Z0, Z1, 0)
    prism(m, [(-0.062, 0.002), (-0.05, -0.016), (-0.07, -0.014)], Z0, Z1, 0)
    m.export(center_y=False)


if __name__ == "__main__":
    for fn in (make_sign_section, make_sign_main, make_sign_small, make_sign_door, make_sign_door_hook,
               make_sign_open, make_icon_yarn, make_icon_button, make_icon_fabric, make_icon_scissors,
               make_icon_box):
        fn()
