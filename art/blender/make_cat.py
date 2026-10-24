"""El gato de la tienda: atigrado gris con hocico, pechera y patitas blancas. Modelo original del proyecto.

Uso:
  blender --background --factory-startup --python art/blender/make_cat.py -- art/models [carpeta_de_vistas]

Sale art/models/cat.glb. Con una carpeta de vistas, además renderiza ahí el gato en cada animación (para
revisarlo sin abrir el juego).

El pelaje es una sola malla suave: las formas (lomo, pecho, cabeza, mofletes, patas, cola...) se funden con
un remallado por vóxeles, se suavizan y se reducen. El color del pelo (rayas, pechera, patitas blancas,
interior de las orejas) va pintado en los vértices. Los ojos, la nariz, la boca y los bigotes son piezas
aparte, rígidas a su hueso.

Esqueleto de 24 huesos con pesos suaves (calculados por Blender):
  body (cadera) > chest > neck > head > eyes, ear_l, ear_r
  patas delanteras: leg_f* (hombro-codo) > fore_f* (codo-muñeca) > paw_f*
  patas traseras:   leg_b* (cadera-rodilla) > shin_b* (rodilla-corvejón) > paw_b*
  cola: tail_1 > ... > tail_5
Animaciones a 12 fps:
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
Superficies: fur (color en los vértices), eyes, pupil, shine, nose, mouth, whiskers. Origen = suelo bajo el
gato; mira hacia +Z. Mide unos 0,5 m de largo con la cola y 0,45 de alto de pie.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import OUT_DIR, Model, Rig, reset_scene  # noqa: E402

os.makedirs(OUT_DIR, exist_ok=True)
_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW_DIR = _args[1] if len(_args) > 1 else ""

EYES, PUPIL, SHINE, NOSE, MOUTH, WHISKERS = range(6)

# Cola: sube hacia atrás y la punta se dobla hacia delante (gato contento). Un hueso entre cada dos puntos.
TAIL = [(0.0, 0.232, -0.158), (0.0, 0.262, -0.222), (0.0, 0.312, -0.262), (0.0, 0.372, -0.28),
        (0.0, 0.432, -0.272), (0.0, 0.478, -0.24)]

HEAD_C = (0.0, 0.335, 0.19)
HEAD_R = (0.088, 0.077, 0.074)
EYE_X, EYE_Y, EYE_Z = 0.035, 0.343, 0.251
EAR_BASE = (0.048, 0.372, 0.183)
EAR_TILT = 18.0
EAR_H, EAR_R = 0.07, 0.036


def _leg_bones(side, s):
    fx, bx = s * 0.046, s * 0.052
    return [
        ("leg_f" + side, (fx, 0.2, 0.098), (fx, 0.112, 0.088), "chest"),
        ("fore_f" + side, (fx, 0.112, 0.088), (fx, 0.035, 0.1), "leg_f" + side),
        ("paw_f" + side, (fx, 0.035, 0.1), (fx, 0.012, 0.14), "fore_f" + side),
        ("leg_b" + side, (bx, 0.2, -0.1), (bx, 0.122, -0.068), "body"),
        ("shin_b" + side, (bx, 0.122, -0.068), (bx, 0.052, -0.132), "leg_b" + side),
        ("paw_b" + side, (bx, 0.052, -0.132), (bx, 0.012, -0.1), "shin_b" + side),
    ]


# Su derecha es -X (mira hacia +Z).
BONES = [
    ("body", (0.0, 0.2, -0.11), (0.0, 0.205, 0.0), None),
    ("chest", (0.0, 0.205, 0.0), (0.0, 0.215, 0.105), "body"),
    ("neck", (0.0, 0.225, 0.115), (0.0, 0.29, 0.165), "chest"),
    ("head", (0.0, 0.29, 0.165), (0.0, 0.39, 0.215), "neck"),
    ("eyes", (0.0, EYE_Y, EYE_Z), (0.0, EYE_Y + 0.03, EYE_Z), "head"),
    ("ear_l", EAR_BASE, (EAR_BASE[0] + 0.02, EAR_BASE[1] + 0.065, EAR_BASE[2]), "head"),
    ("ear_r", (-EAR_BASE[0], EAR_BASE[1], EAR_BASE[2]), (-EAR_BASE[0] - 0.02, EAR_BASE[1] + 0.065, EAR_BASE[2]), "head"),
] + _leg_bones("l", 1) + _leg_bones("r", -1) + [
    ("tail_1", TAIL[0], TAIL[1], "body"),
    ("tail_2", TAIL[1], TAIL[2], "tail_1"),
    ("tail_3", TAIL[2], TAIL[3], "tail_2"),
    ("tail_4", TAIL[3], TAIL[4], "tail_3"),
    ("tail_5", TAIL[4], TAIL[5], "tail_4"),
]
LEGS = [b[0] for b in BONES if b[0][:-1] in ("leg_f", "fore_f", "paw_f", "leg_b", "shin_b", "paw_b")]
TAILS = ["tail_%d" % i for i in range(1, 6)]


def catmull(points, steps):
    """Curva suave que pasa por los puntos (para la cola)."""
    pts = [Vector(points[0]) * 2 - Vector(points[1])] + [Vector(p) for p in points] + \
          [Vector(points[-1]) * 2 - Vector(points[-2])]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for k in range(steps):
            t = k / steps
            out.append(0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t +
                              (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
    out.append(Vector(points[-1]))
    return [tuple(p) for p in out]


# --- Pelaje: formas que se funden ---------------------------------------------

def build_fur(f):
    # Cuerpo: lomo, pecho y grupa redondos, tripa algo colgona y cuello ancho.
    f.sphere((0.0, 0.205, -0.01), 1.0, scale=(0.08, 0.078, 0.15), segments=24, rings=14)
    f.sphere((0.0, 0.208, 0.085), 0.074, segments=20, rings=12)
    f.sphere((0.0, 0.208, -0.1), 0.074, segments=20, rings=12)
    f.sphere((0.0, 0.165, -0.01), 1.0, scale=(0.066, 0.05, 0.12), segments=20, rings=12)
    f.sphere((0.0, 0.258, 0.135), 1.0, scale=(0.056, 0.062, 0.055), segments=16, rings=10)

    # Cabeza: cráneo ancho, mofletes mullidos, almohadillas del hocico y barbilla.
    f.sphere(HEAD_C, 1.0, scale=HEAD_R, segments=24, rings=16)
    for s in (-1, 1):
        f.sphere((s * 0.042, 0.31, 0.215), 0.046, scale=(1.0, 0.82, 0.9), segments=16, rings=10)
        f.sphere((s * 0.016, 0.304, 0.252), 0.021, scale=(1.0, 0.85, 0.9), segments=12, rings=8)
    f.sphere((0.0, 0.289, 0.242), 0.016, segments=12, rings=8)

    # Orejas: conos aplastados, algo abiertos hacia fuera.
    for s in (-1, 1):
        base = (s * EAR_BASE[0], EAR_BASE[1], EAR_BASE[2])
        f.lathe([(0.0, 0.0), (EAR_R, 0.0), (EAR_R * 0.55, EAR_H * 0.5), (0.0, EAR_H)], segments=14,
                center=base, scale=(1.0, 1.0, 0.5), rotate=("Z", -s * EAR_TILT, base))

    # Patas delanteras: hombro, brazo hasta el codo, antebrazo y patita.
    for s in (-1, 1):
        x = s * 0.046
        f.sphere((x, 0.182, 0.094), 0.042, scale=(0.85, 1.2, 1.0), segments=16, rings=10)
        f.tube([(x, 0.2, 0.096), (x, 0.112, 0.088), (x, 0.035, 0.1)], 0.029, sides=14, taper=0.24, cap=False)
        f.sphere((x, 0.021, 0.115), 0.027, scale=(1.0, 0.72, 1.3), segments=14, rings=8)

    # Patas traseras: muslo (anca) redondo, pata hasta el corvejón y patita.
    for s in (-1, 1):
        x = s * 0.052
        f.sphere((s * 0.054, 0.168, -0.098), 0.062, scale=(0.72, 1.15, 1.1), segments=16, rings=10)
        f.tube([(x, 0.13, -0.075), (x, 0.052, -0.133), (x, 0.024, -0.118)], 0.025, sides=14, taper=0.12, cap=False)
        f.sphere((x, 0.021, -0.11), 0.026, scale=(1.0, 0.72, 1.3), segments=14, rings=8)

    # Cola: gruesa en la base y más fina hacia la punta redondeada.
    f.sphere(TAIL[0], 0.028, segments=12, rings=8)
    f.tube(catmull(TAIL, 5), 0.022, sides=14, taper=0.3, cap=True)


# --- Color del pelo (en ejes de Godot) ----------------------------------------

def _ss(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def _mix(c0, c1, k):
    return tuple(a + (b - a) * k for a, b in zip(c0, c1))


BASE = (0.66, 0.66, 0.7)
BACK = (0.52, 0.52, 0.57)
STRIPE = (0.3, 0.3, 0.34)
WHITE = (1.0, 0.99, 0.96)
PINK = (0.95, 0.66, 0.68)


def _ellipsoid(p, c, r):
    return sum(((p[i] - c[i]) / r[i]) ** 2 for i in range(3))


def _tail_t(p):
    """Distancia (0..1) a lo largo de la cola y distancia al eje; None si no está cerca de la cola."""
    best, tt = 1e9, 0.0
    total = sum((Vector(b) - Vector(a)).length for a, b in zip(TAIL, TAIL[1:]))
    run = 0.0
    for a, b in zip(TAIL, TAIL[1:]):
        a, b = Vector(a), Vector(b)
        ab = b - a
        k = max(0.0, min(1.0, (Vector(p) - a).dot(ab) / ab.length_squared))
        d = (Vector(p) - (a + ab * k)).length
        if d < best:
            best, tt = d, (run + ab.length * k) / total
        run += ab.length
    return tt, best


def fur_color(p, n):
    x, y, z = p
    ax = abs(x)
    c = BASE
    in_tail = z < -0.16 and y > 0.2
    in_head = y > 0.27 and z > 0.15

    # Lomo más oscuro arriba, con rayas que bajan por los costados (atigrado).
    if not in_head and not in_tail and y > 0.12:
        c = _mix(c, BACK, _ss(0.2, 0.27, y))
        band = math.sin((z + 0.012 * math.sin(ax * 60.0)) * math.tau / 0.052)
        k = _ss(0.45, 0.8, band) * _ss(0.17, 0.22, y + 0.02 * (1.0 - ax / 0.09))
        c = _mix(c, STRIPE, 0.85 * k)
        # Raya del espinazo.
        c = _mix(c, STRIPE, 0.7 * (1.0 - _ss(0.008, 0.02, ax)) * _ss(0.26, 0.28, y))

    # Rayas en los muslos y en la parte de fuera de las patas.
    if y < 0.2 and ax > 0.03 and not in_head:
        band = math.sin(y * math.tau / 0.036)
        k = _ss(0.55, 0.85, band) * _ss(0.03, 0.06, ax) * _ss(0.05, 0.08, y)
        c = _mix(c, STRIPE, 0.75 * k)

    # Cola: anillos y la punta oscura.
    if in_tail or z < -0.2:
        t, d = _tail_t(p)
        if d < 0.04:
            ring = _ss(0.4, 0.75, math.sin(t * math.tau * 3.5))
            c = _mix(BASE, STRIPE, max(0.8 * ring, _ss(0.82, 0.9, t)))

    # Cabeza: "M" en la frente, rayitas en los mofletes y algo más oscura por arriba.
    if in_head:
        c = _mix(BASE, BACK, _ss(0.36, 0.41, y) * 0.8)
        for mx, tilt in ((-0.024, -0.35), (0.0, 0.0), (0.024, 0.35)):
            dx = x - mx - tilt * (y - 0.37) * 0.3
            k = (1.0 - _ss(0.004, 0.008, abs(dx))) * _ss(0.355, 0.37, y) * _ss(0.2, 0.235, z)
            c = _mix(c, STRIPE, 0.9 * k)
        for dy in (0.322, 0.334):
            k = (1.0 - _ss(0.003, 0.0055, abs(y - dy - 0.02 * (ax - 0.07)))) * _ss(0.07, 0.08, ax) * _ss(0.17, 0.2, z)
            c = _mix(c, STRIPE, 0.85 * k)

    # Blancos: hocico y barbilla, pechera, tripa y patitas.
    w = 0.0
    w = max(w, 1.0 - _ss(0.7, 1.15, _ellipsoid(p, (0.0, 0.296, 0.252), (0.042, 0.03, 0.04))))
    w = max(w, 1.0 - _ss(0.6, 1.1, _ellipsoid(p, (0.0, 0.215, 0.15), (0.045, 0.085, 0.06))))
    w = max(w, (1.0 - _ss(0.13, 0.145, y)) * (1.0 - _ss(0.05, 0.065, ax)) * _ss(-0.15, -0.1, z) * (1.0 - _ss(0.13, 0.16, z)))
    w = max(w, 1.0 - _ss(0.03, 0.045, y))
    c = _mix(c, WHITE, w)

    # Interior de las orejas.
    for s in (-1, 1):
        base = Vector((s * EAR_BASE[0], EAR_BASE[1], EAR_BASE[2]))
        a = math.radians(-s * EAR_TILT)
        up = Vector((-math.sin(a), math.cos(a), 0.0))
        d = Vector(p) - base
        h = d.dot(up)
        if 0.0 < h < EAR_H and d.z > -0.004 and n[2] > 0.15 and _ellipsoid(p, HEAD_C, HEAD_R) > 1.05:
            lat = d - up * h
            r = math.hypot(lat.x, lat.y)
            width = EAR_R * (1.0 - h / EAR_H)
            k = (1.0 - _ss(0.45, 0.7, r / max(width, 1e-4))) * _ss(0.006, 0.014, h) * (1.0 - _ss(0.05, 0.062, h))
            c = _mix(c, PINK, k)
    return c


# --- Ojos, nariz, boca y bigotes (piezas rígidas) -----------------------------

def build_face(m):
    m.add_material("eyes", (0.83, 0.67, 0.18), 0.2)
    m.add_material("pupil", (0.02, 0.02, 0.025), 0.1)
    m.add_material("shine", (1.0, 1.0, 1.0), 0.1)
    m.add_material("nose", (0.88, 0.48, 0.54), 0.5)
    m.add_material("mouth", (0.22, 0.16, 0.16), 0.8)
    m.add_material("whiskers", (0.98, 0.97, 0.94), 0.5)

    # Ojos grandes y algo abiertos hacia fuera: iris ámbar, pupila ovalada y un brillo.
    m.bone = "eyes"
    for s in (-1, 1):
        c = (s * EYE_X, EYE_Y, EYE_Z)
        turn = ("Y", s * 28.0, c)
        m.sphere(c, 0.0215, scale=(1.0, 1.05, 0.62), segments=16, rings=10, mat=EYES, rotate=turn)
        m.sphere((c[0], c[1] - 0.001, c[2] + 0.012), 0.0135, scale=(0.55, 1.05, 0.3), segments=12, rings=8,
                 mat=PUPIL, rotate=turn)
        m.sphere((c[0] + s * 0.0035 + 0.004, c[1] + 0.008, c[2] + 0.0142), 0.0042, scale=(1.0, 1.0, 0.5),
                 segments=8, rings=6, mat=SHINE, rotate=turn)

    # Nariz rosa, boca en "w" y bigotes.
    m.bone = "head"
    m.sphere((0.0, 0.318, 0.268), 0.0095, scale=(1.4, 0.8, 0.8), segments=10, rings=6, mat=NOSE)
    m.tube([(0.0, 0.311, 0.2735), (0.0, 0.301, 0.2745)], 0.0016, sides=5, mat=MOUTH, cap=False)
    m.tube([(-0.015, 0.3, 0.269), (-0.008, 0.2955, 0.2735), (0.0, 0.301, 0.2748), (0.008, 0.2955, 0.2735),
            (0.015, 0.3, 0.269)], 0.0016, sides=5, mat=MOUTH, cap=False)
    for s in (-1, 1):
        for dy in (-0.006, 0.0, 0.006):
            m.tube([(s * 0.03, 0.305 + dy, 0.262), (s * 0.075, 0.305 + dy * 2.2, 0.266),
                    (s * 0.118, 0.301 + dy * 3.4, 0.256)], 0.0014, sides=3, mat=WHISKERS, cap=False)


# --- Montaje ------------------------------------------------------------------

class CatRig(Rig):
    def __init__(self):
        super().__init__("cat", BONES)
        self.fur = Model("cat_fur")

    def export(self, fps=12):
        scene = bpy.context.scene
        scene.render.fps = fps
        obj = self._fur_object()
        arm = self.build_armature()
        self._skin(obj, arm)
        face = self._face_object()
        bpy.ops.object.select_all(action="DESELECT")
        face.select_set(True)
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.join()
        self.bake_actions(arm)
        self.write_glb(obj, arm)
        mesh = obj.data
        tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
        print("EXPORTADO: cat  triangulos=%d  huesos=%d  animaciones=%s" % (tris, len(self.bones), ",".join(self.actions)))
        if PREVIEW_DIR:
            preview(obj, arm, self.actions)

    def _fur_object(self):
        mesh = bpy.data.meshes.new("cat")
        self.fur.bm.to_mesh(mesh)
        self.fur.bm.free()
        obj = bpy.data.objects.new("cat", mesh)
        bpy.context.scene.collection.objects.link(obj)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        rem = obj.modifiers.new("Remesh", "REMESH")
        rem.mode = "VOXEL"
        rem.voxel_size = 0.0034
        sm = obj.modifiers.new("Smooth", "SMOOTH")
        sm.factor = 0.6
        sm.iterations = 6
        dec = obj.modifiers.new("Decimate", "DECIMATE")
        dec.ratio = 0.13
        for mod in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.ops.object.shade_smooth()

        mat = bpy.data.materials.new("fur")
        mat.use_nodes = True
        nt = mat.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        bsdf.inputs["Roughness"].default_value = 0.95
        attr = nt.nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Col"
        nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
        mesh.materials.append(mat)

        col = mesh.color_attributes.new("Col", "BYTE_COLOR", "POINT")
        for v in mesh.vertices:
            p = (v.co.x, v.co.z, -v.co.y)
            n = (v.normal.x, v.normal.z, -v.normal.y)
            col.data[v.index].color = (*fur_color(p, n), 1.0)
        return obj

    def _skin(self, obj, arm):
        # Los ojos no deforman el pelo (al parpadear solo se aplastan los ojos).
        arm.data.bones["eyes"].use_deform = False
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        arm.select_set(True)
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
        arm.data.bones["eyes"].use_deform = True
        missing = [b for b in self.bone_names if b != "eyes" and obj.vertex_groups.get(b) is None]
        unweighted = sum(1 for v in obj.data.vertices if not any(g.weight > 1e-4 for g in v.groups))
        print("PESOS: huesos sin grupo=%s  vertices sin peso=%d" % (missing, unweighted))

    def _face_object(self):
        from bmesh.ops import recalc_face_normals
        recalc_face_normals(self.bm, faces=list(self.bm.faces))
        mesh = bpy.data.meshes.new("cat_face")
        self.bm.to_mesh(mesh)
        self.bm.free()
        for mat in self.materials:
            mesh.materials.append(mat)
        obj = bpy.data.objects.new("cat_face", mesh)
        bpy.context.scene.collection.objects.link(obj)
        for b in self.bone_names:
            obj.vertex_groups.new(name=b)
        # Para las vistas previas: cada pieza pintada del color de su material.
        col = mesh.color_attributes.new("Col", "BYTE_COLOR", "POINT")
        for poly in mesh.polygons:
            rgb = self.materials[poly.material_index].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value
            for vi in poly.vertices:
                col.data[vi].color = (rgb[0], rgb[1], rgb[2], 1.0)
        for poly in mesh.polygons:
            poly.use_smooth = True
        return obj


# --- Vistas previas -------------------------------------------------------------

def preview(obj, arm, actions):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.show_shadows = False
    scene.render.resolution_x = 420
    scene.render.resolution_y = 420
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    world.color = (0.78, 0.72, 0.62)
    scene.world = world
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 0.62
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    views = {"lado": (1.0, 0.0), "frente": (0.0, 1.0), "tres_cuartos": (0.75, 0.75), "arriba": None}
    target = Vector((0.0, 0.0, 0.2))

    def shoot(name):
        for vname, dirs in views.items():
            if dirs is None:
                pos = Vector((0.0, -0.05, 2.0))
            else:
                pos = Vector((dirs[0], -dirs[1], 0.0)).normalized() * 2.0 + Vector((0.0, 0.0, 0.32))
            cam.location = pos
            cam.rotation_euler = (target - pos).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(PREVIEW_DIR, "%s_%s.png" % (name, vname))
            bpy.ops.render.render(write_still=True)

    arm.animation_data.action = None
    for t in list(arm.animation_data.nla_tracks):
        t.mute = True
    arm.data.pose_position = "REST"
    scene.frame_set(0)
    shoot("reposo")
    arm.data.pose_position = "POSE"
    for aname, act in actions.items():
        if aname in ("blink", "ear_twitch_l", "ear_twitch_r"):
            continue
        arm.animation_data.action = bpy.data.actions[aname]
        if hasattr(arm.animation_data, "action_slot") and bpy.data.actions[aname].slots:
            arm.animation_data.action_slot = bpy.data.actions[aname].slots[0]
        scene.frame_set(act.get("preview", act["length"] // 3))
        shoot(aname)


# --- Animaciones ---------------------------------------------------------------
# Giros en radianes sobre los ejes de Godot, relativos al hueso padre (ver common.Rig). Con +X la pata que
# cuelga se va hacia atrás y el lomo que mira adelante se inclina hacia abajo; +Y gira hacia su izquierda.

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


def add(*vs):
    return tuple(sum(c) for c in zip(*vs))


def tail(rots, curl, sway, phase=0.0, lag=0.55, curl_step=None):
    """Cola: curl = doblez (X) de cada tramo; sway = vaivén (Y) que avanza hacia la punta."""
    for i, name in enumerate(TAILS):
        c = curl[i] if isinstance(curl, (list, tuple)) else curl
        rots[name] = (c, sway * (0.6 + 0.2 * i) * math.sin(phase - lag * i) if sway else 0.0, 0.0)


# Sentado: la cadera baja casi al suelo y el lomo se levanta por delante; las patas delanteras quedan rectas,
# las traseras dobladas (muslo hacia delante por el suelo, pata hacia atrás y patita plana) y la cola
# alrededor, por el suelo.
SIT_BODY = -0.78
SIT_CHEST = -0.12
SIT_LOC = (0.0, -0.122, 0.035)


def sit(head=(0.0, 0.0, 0.0), fl=None, fr=None, breath=0.0, tail_phase=0.0, tail_sway=0.0, tip=0.0):
    up = -(SIT_BODY + SIT_CHEST)
    rots = {
        "body": (SIT_BODY, 0.0, 0.0),
        "chest": (SIT_CHEST, 0.0, 0.0),
        "neck": (0.42, 0.0, 0.0),
        "head": add((0.42, 0.0, 0.0), head),
    }
    for side, s, extra in (("l", 1, fl), ("r", -1, fr)):
        e = extra or {}
        rots["leg_f" + side] = add((up, 0.0, 0.0), e.get("leg", (0.0, 0.0, 0.0)))
        rots["fore_f" + side] = e.get("fore", (0.0, 0.0, 0.0))
        rots["paw_f" + side] = e.get("paw", (0.0, 0.0, 0.0))
        rots["leg_b" + side] = (-1.25 - SIT_BODY, 0.0, -s * 0.1)
        rots["shin_b" + side] = (1.72, 0.0, 0.0)
        rots["paw_b" + side] = (-1.32, 0.0, 0.0)
    curl = [1.0, 0.7, 0.6, 0.5, 0.3 + tip]
    turn = [0.5, 0.55, 0.5, 0.45, 0.4]
    for i, name in enumerate(TAILS):
        rots[name] = (curl[i], turn[i] + tail_sway * math.sin(tail_phase - 0.6 * i), 0.0)
    locs = {"body": (SIT_LOC[0], SIT_LOC[1] + breath, SIT_LOC[2])}
    return rots, locs


def animate(m):
    # Paso y trote: patas en diagonal; al adelantar la pata se doblan codo y muñeca (delante) o rodilla
    # (detrás) para levantar la patita. El lomo sube y baja, la cabeza va estable y la cola se mece alta.
    for name, frames, swing, bend, bob in (("walk", 8, 0.34, 0.75, 0.005), ("trot", 6, 0.5, 1.0, 0.01)):
        m.action(name, frames)
        for f in range(frames + 1):
            ph = math.tau * f / frames
            rots, locs = {}, {}
            for side, off in (("l", 0.0), ("r", math.pi)):
                a = ph + off
                lift = smooth(max(0.0, -math.cos(a)) * 1.4)
                rots["leg_f" + side] = (swing * math.sin(a), 0.0, 0.0)
                rots["fore_f" + side] = (0.55 * bend * lift, 0.0, 0.0)
                rots["paw_f" + side] = (0.9 * bend * lift, 0.0, 0.0)
                b = a + math.pi
                blift = smooth(max(0.0, -math.cos(b)) * 1.4)
                rots["leg_b" + side] = (swing * math.sin(b) - 0.25 * bend * blift, 0.0, 0.0)
                rots["shin_b" + side] = (0.75 * bend * blift, 0.0, 0.0)
                rots["paw_b" + side] = (-0.4 * bend * blift, 0.0, 0.0)
            locs["body"] = (0.0, bob * math.cos(2.0 * ph), 0.0)
            rots["body"] = (0.0, 0.0, 0.03 * math.sin(ph))
            rots["chest"] = (0.0, 0.04 * math.sin(ph), -0.04 * math.sin(ph))
            rots["head"] = (0.05 * math.cos(2.0 * ph), -0.03 * math.sin(ph), 0.03 * math.sin(ph))
            tail(rots, [-0.2, 0.0, 0.0, 0.0, 0.0], 0.12, ph)
            m.pose(name, f, rots, locs)

    # De pie: respira, mece la cola y mira un poco a un lado.
    m.action("stand", 24)
    for f in range(25):
        ph = math.tau * f / 24.0
        rots = {"head": (0.0, 0.14 * math.sin(ph), 0.04 * math.sin(ph)), "neck": (0.0, 0.05 * math.sin(ph), 0.0)}
        tail(rots, [-0.15, 0.0, 0.05, 0.05, 0.0], 0.16, ph)
        m.pose("stand", f, rots, {"body": (0.0, 0.003 * math.sin(ph), 0.0)},
               scales={"chest": (1.0 + 0.012 * math.sin(ph), 1.0, 1.0 + 0.012 * math.sin(ph))})

    # Sentado: respira y sacude la punta de la cola de vez en cuando.
    m.action("sit", 24)
    tip = [(0, 0.0), (14, 0.0), (17, 0.6), (20, -0.15), (24, 0.0)]
    for f in range(25):
        ph = math.tau * f / 24.0
        rots, locs = sit(head=(0.0, 0.1 * math.sin(ph), 0.03 * math.sin(ph)), tip=at(tip, f),
                         breath=0.003 * math.sin(ph))
        m.pose("sit", f, rots, locs)

    # Aseo: sube la pata derecha doblada a la boca, la lame (la cabeza sube y baja) y se la pasa por la cara.
    m.action("groom", 36)
    k_up = [(0, 0.0), (6, 1.0), (24, 1.0), (27, 1.0), (33, 1.0), (36, 0.0)]
    wipe = [(0, 0.0), (24, 0.0), (27, 1.0), (30, 0.3), (33, 1.0), (36, 0.0)]
    for f in range(37):
        k = at(k_up, f)
        w = at(wipe, f)
        lick = 0.0 if f < 6 or f > 24 else 0.14 * max(0.0, math.sin(math.tau * (f - 6) / 6.0))
        fr = {"leg": (-1.55 * k - 0.2 * w, 0.0, 0.3 * k), "fore": (2.0 * k, 0.0, 0.0), "paw": (0.7 * k, 0.0, 0.0)}
        rots, locs = sit(head=(0.42 * k + lick - 0.2 * w, -0.3 * k + 0.15 * w, 0.2 * k + 0.2 * w), fr=fr)
        m.pose("groom", f, rots, locs)

    # Siesta: tumbado como una barra de pan, con las patas delanteras estiradas por delante, la barbilla
    # apoyada en ellas, las traseras recogidas, la cola alrededor por el suelo y los ojos cerrados.
    # Respira despacio.
    m.action("sleep", 48)
    for f in range(49):
        ph = math.tau * f / 48.0
        rots = {
            "body": (-0.06, 0.0, 0.0),
            "chest": (0.0, 0.0, 0.0),
            "neck": (0.6, 0.15, 0.0),
            "head": (0.45, 0.2, 0.18),
            "ear_l": (0.15, 0.0, 0.1),
            "ear_r": (0.15, 0.0, -0.1),
        }
        for side, s in (("l", 1), ("r", -1)):
            rots["leg_f" + side] = (0.25, 0.0, 0.0)
            rots["fore_f" + side] = (-1.85, 0.0, 0.0)
            rots["paw_f" + side] = (0.35, 0.0, 0.0)
            rots["leg_b" + side] = (-1.35, 0.0, -s * 0.15)
            rots["shin_b" + side] = (1.9, 0.0, 0.0)
            rots["paw_b" + side] = (-1.4, 0.0, 0.0)
        for i, name in enumerate(TAILS):
            rots[name] = ([1.2, 0.55, 0.5, 0.45, 0.35][i], [0.8, 0.45, 0.45, 0.4, 0.35][i], 0.0)
        m.pose("sleep", f, rots, {"body": (0.0, -0.11 + 0.002 * math.sin(ph), 0.0)},
               scales={"eyes": (1.0, 0.1, 1.0), "chest": (1.0 + 0.02 * math.sin(ph), 1.0, 1.0 + 0.02 * math.sin(ph))})

    # Zarpazo sentado: sube la pata derecha, la sostiene y golpea el suelo delante (el ovillo) en el 13.
    m.action("bat", 24)
    raise_k = [(0, 0.0), (7, 1.0), (10, 1.1), (13, -0.1), (16, 0.05), (22, 0.0), (24, 0.0)]
    head = [(0, (0.12, 0.0, 0.0)), (7, (0.05, -0.08, 0.1)), (13, (0.25, -0.05, 0.06)), (24, (0.12, 0.0, 0.0))]
    for f in range(25):
        k = at(raise_k, f)
        fr = {"leg": (-1.0 * k, 0.0, -0.1 * k), "fore": (0.9 * max(k, 0.0), 0.0, 0.0), "paw": (0.5 * max(k, 0.0), 0.0, 0.0)}
        rots, locs = sit(head=at(head, f), fr=fr, tail_phase=math.tau * f / 24.0, tail_sway=0.2)
        m.pose("bat", f, rots, locs)

    # Caricia: sentado, ojos cerrados, frota la cabeza contra la mano (de lado a lado) y la cola tiesa.
    m.action("pet", 24)
    for f in range(25):
        ph = math.tau * f / 24.0
        rots, locs = sit(head=(-0.15, 0.2 * math.sin(ph), 0.24 * math.sin(ph)))
        rots["neck"] = (0.3, 0.08 * math.sin(ph), 0.0)
        tail(rots, [1.1, 0.1, 0.05, 0.15, 0.35], 0.1, ph)
        rots["ear_l"] = (0.3, 0.0, 0.25)
        rots["ear_r"] = (0.3, 0.0, -0.25)
        locs["body"] = (SIT_LOC[0], SIT_LOC[1] + 0.003 * math.sin(2.0 * ph), SIT_LOC[2])
        m.pose("pet", f, rots, locs, scales={"eyes": (1.0, 0.1, 1.0)})

    # Tumbado de lado (sobre el costado derecho): las patas sueltas hacia un lado, la cabeza algo levantada
    # mirando al frente y la cola barriendo el suelo despacio.
    m.action("lie", 32)
    look = [(0, 0.0), (10, 0.0), (14, 1.0), (22, 1.0), (26, 0.0), (32, 0.0)]
    for f in range(33):
        ph = math.tau * f / 32.0
        up = at(look, f)
        rots = {
            "body": (0.0, 0.0, 1.45),
            "chest": (0.0, 0.0, -0.1),
            "neck": (0.1, 0.0, -0.45 + 0.25 * up),
            "head": (0.1 + 0.1 * up, 0.15, -0.45 + 0.3 * up),
            "leg_fl": (-0.25 + 0.05 * math.sin(ph), 0.0, 0.0), "fore_fl": (0.5, 0.0, 0.0), "paw_fl": (0.4, 0.0, 0.0),
            "leg_fr": (-0.45, 0.0, 0.0), "fore_fr": (0.2, 0.0, 0.0), "paw_fr": (0.2, 0.0, 0.0),
            "leg_bl": (-0.4, 0.0, 0.0), "shin_bl": (0.4, 0.0, 0.0), "paw_bl": (-0.1, 0.0, 0.0),
            "leg_br": (-0.15 + 0.04 * math.sin(ph + 1.0), 0.0, 0.0), "shin_br": (0.2, 0.0, 0.0),
        }
        tail(rots, [-1.1, -0.2, 0.0, 0.0, 0.0], 0.3, ph)
        m.pose("lie", f, rots, {"body": (0.0, -0.11 + 0.003 * math.sin(ph), 0.0)},
               scales={"chest": (1.0 + 0.015 * math.sin(ph), 1.0, 1.0 + 0.015 * math.sin(ph))})

    # Revolcarse panza arriba: el lomo se balancea de un lado a otro sobre la espalda, las patas delanteras
    # dobladas sobre el pecho, las traseras pataleando, la cabeza hacia atrás mirando de lado.
    m.action("roll", 36)
    for f in range(37):
        ph = math.tau * f / 36.0
        sway = math.sin(ph)
        kick = math.sin(2.0 * ph)
        rots = {
            "body": (0.0, 0.0, math.pi + 0.55 * sway),
            "chest": (0.0, 0.0, 0.15 * sway),
            "neck": (-0.9, 0.0, -0.25 * sway),
            "head": (-0.5, 0.0, -0.3 * sway - 0.15),
            "ear_l": (-0.3, 0.0, 0.25),
            "ear_r": (-0.3, 0.0, -0.25),
        }
        for side, s, k in (("l", 1, max(0.0, kick)), ("r", -1, max(0.0, -kick))):
            rots["leg_f" + side] = (-0.9 - 0.3 * k, 0.0, s * 0.2)
            rots["fore_f" + side] = (1.6 - 0.4 * k, 0.0, 0.0)
            rots["paw_f" + side] = (0.8, 0.0, 0.0)
            rots["leg_b" + side] = (-0.6 - 0.35 * s * kick, 0.0, s * 0.25)
            rots["shin_b" + side] = (0.7 + 0.3 * s * kick, 0.0, 0.0)
            rots["paw_b" + side] = (-0.3, 0.0, 0.0)
        tail(rots, [-1.1, -0.3, 0.0, 0.0, 0.0], 0.35, ph)
        m.pose("roll", f, rots, {"body": (0.0, -0.095 + 0.006 * abs(sway), 0.0)}, scales={"eyes": (1.0, 0.45, 1.0)})

    # Estirarse: el pecho baja al suelo con las patas delanteras estiradas hacia delante, el culete en alto,
    # la cola tiesa y los ojos entornados; luego vuelve.
    m.action("stretch", 30)
    k_s = [(0, 0.0), (8, 1.0), (20, 1.0), (28, 0.0), (30, 0.0)]
    for f in range(31):
        k = at(k_s, f)
        rots = {
            "body": (0.3 * k, 0.0, 0.0),
            "chest": (0.3 * k, 0.0, 0.0),
            "neck": (-0.55 * k, 0.0, 0.0),
            "head": (-0.45 * k, 0.0, 0.0),
            "ear_l": (-0.25 * k, 0.0, 0.0),
            "ear_r": (-0.25 * k, 0.0, 0.0),
        }
        for side in ("l", "r"):
            rots["leg_f" + side] = (-1.75 * k, 0.0, 0.0)
            rots["fore_f" + side] = (0.1 * k, 0.0, 0.0)
            rots["paw_f" + side] = (1.0 * k, 0.0, 0.0)
            rots["leg_b" + side] = (-0.3 * k, 0.0, 0.0)
            rots["shin_b" + side] = (-0.2 * k, 0.0, 0.0)
            rots["paw_b" + side] = (0.2 * k, 0.0, 0.0)
        tail(rots, [-0.2 - 0.5 * k, 0.0, 0.0, 0.1 * k, 0.25 * k], 0.0)
        m.pose("stretch", f, rots, {"body": (0.0, -0.012 * k, -0.02 * k)}, scales={"eyes": (1.0, 1.0 - 0.75 * k, 1.0)})

    # Amasar: sentado, las patas delanteras suben y aprietan por turnos, ojos entornados.
    m.action("knead", 24)
    for f in range(25):
        ph = math.tau * f / 24.0
        a = max(0.0, math.sin(ph))
        b = max(0.0, -math.sin(ph))
        fl = {"leg": (-0.25 * a, 0.0, 0.0), "fore": (0.7 * a, 0.0, 0.0), "paw": (0.5 * a, 0.0, 0.0)}
        fr = {"leg": (-0.25 * b, 0.0, 0.0), "fore": (0.7 * b, 0.0, 0.0), "paw": (0.5 * b, 0.0, 0.0)}
        rots, locs = sit(head=(0.12, 0.05 * math.sin(ph), 0.0), fl=fl, fr=fr, breath=0.004 * math.sin(2.0 * ph))
        rots["body"] = (SIT_BODY + 0.04 * math.sin(2.0 * ph), 0.0, 0.0)
        m.pose("knead", f, rots, locs, scales={"eyes": (1.0, 0.3, 1.0)})

    # Carrera loca: galope (delanteras juntas, traseras juntas), el lomo se encoge y se estira, las orejas
    # hacia atrás y la cola recta hacia atrás.
    m.action("gallop", 6)
    for f in range(7):
        ph = math.tau * f / 6.0
        rots = {
            "body": (0.12 * math.sin(ph), 0.0, 0.0),
            "chest": (-0.18 * math.sin(ph), 0.0, 0.0),
            "neck": (0.06 * math.sin(ph), 0.0, 0.0),
            "head": (0.0, 0.0, 0.0),
            "ear_l": (-0.6, 0.0, 0.35),
            "ear_r": (-0.6, 0.0, -0.35),
        }
        for side, off in (("l", 0.25), ("r", 0.0)):
            a = ph + off
            lift = smooth(max(0.0, -math.cos(a)) * 1.3)
            rots["leg_f" + side] = (-0.8 * math.sin(a), 0.0, 0.0)
            rots["fore_f" + side] = (0.9 * lift, 0.0, 0.0)
            rots["paw_f" + side] = (0.7 * lift, 0.0, 0.0)
            b = a + math.pi
            blift = smooth(max(0.0, -math.cos(b)) * 1.3)
            rots["leg_b" + side] = (-0.8 * math.sin(b), 0.0, 0.0)
            rots["shin_b" + side] = (0.9 * blift, 0.0, 0.0)
            rots["paw_b" + side] = (-0.4 * blift, 0.0, 0.0)
        tail(rots, [-1.0, 0.0, 0.0, 0.0, 0.0], 0.0)
        for i, name in enumerate(TAILS):
            rots[name] = (rots[name][0] + 0.1 * math.sin(ph - 0.7 * i), 0.0, 0.0)
        m.pose("gallop", f, rots, {"body": (0.0, 0.018 * abs(math.sin(ph)), 0.0)})

    # Parpadeo: solo los ojos.
    m.action("blink", 4)
    for f, k in ((0, 1.0), (1, 0.1), (2, 0.1), (4, 1.0)):
        m.pose("blink", f, {"eyes": (0.0, 0.0, 0.0)}, only=True, scales={"eyes": (1.0, k, 1.0)})

    # Sacudida de oreja: dos golpecitos hacia fuera; solo anima esa oreja.
    for side, s in (("l", 1), ("r", -1)):
        name = "ear_twitch_" + side
        m.action(name, 6)
        flick = [(0, 0.0), (1, 1.0), (3, 0.55), (4, 1.0), (6, 0.0)]
        for f in range(7):
            k = at(flick, f)
            m.pose(name, f, {"ear_" + side: (-0.15 * k, s * 0.35 * k, -s * 0.45 * k)}, only=True)

    # Fotograma que sale en las vistas previas.
    for name, f in (("walk", 2), ("trot", 1), ("groom", 12), ("bat", 9), ("stretch", 14), ("gallop", 1), ("roll", 9)):
        m.actions[name]["preview"] = f


def main():
    reset_scene()
    m = CatRig()
    build_fur(m.fur)
    build_face(m)
    animate(m)
    m.export(fps=12)


main()
