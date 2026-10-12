"""Genera el mobiliario de la mercería (original) y lo exporta a GLB para Godot.

Uso:
  blender --background --factory-startup --python art/blender/make_furniture.py -- art/models

Modelos: shelf_unit, table, crate, cardboard_box, plant.
Todo con bordes biselados (cogen la luz como objetos reales, no como cajas), UVs en
metros (1 azulejo de textura = 0.5 m) y la veta de la madera en la dirección correcta
de cada pieza. Las dimensiones coinciden con las constantes de los scripts de Godot
(scripts/core/shelf_unit.gd, scripts/room/room_shell.gd).

Convención: se modela en ejes de Godot (X derecha, Y arriba, Z hacia delante) y al
fusionar se convierte a ejes de Blender; el exportador glTF los devuelve a Godot.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

OUT_DIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
TILE = 0.5   # metros que cubre una repetición de textura


def gv(x, y, z):
    """Ejes de Godot -> ejes de Blender (rotación propia, conserva el sentido de las caras)."""
    return Vector((x, -z, y))


class Model:
    def __init__(self, name, seed=1):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.rng = random.Random(seed)
        self.materials = []

    # -- piezas ----------------------------------------------------------
    def box(self, center, size, grain="y", bevel=0.004, segments=2, taper=None, rotate=None, mat=0):
        """Caja biselada. taper=(escala_abajo) estrecha la base. rotate=(eje, grados, pivote)."""
        part = bmesh.new()
        bmesh.ops.create_cube(part, size=1.0)
        for v in part.verts:
            x, y, z = v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]
            if taper is not None:
                t = (v.co.y + 0.5)              # 0 abajo, 1 arriba
                k = taper + (1.0 - taper) * t
                x *= k
                z *= k
            v.co = Vector((x, y, z)) + Vector(center)
        if bevel > 0:
            bmesh.ops.bevel(part, geom=list(part.edges), offset=bevel, offset_type="OFFSET",
                            segments=segments, profile=0.5, affect="EDGES")
        if rotate is not None:
            axis, deg, pivot = rotate
            rot = Matrix.Rotation(math.radians(deg), 3, axis)
            piv = Vector(pivot)
            for v in part.verts:
                v.co = rot @ (v.co - piv) + piv
        bmesh.ops.recalc_face_normals(part, faces=part.faces)
        self._uv_box(part, grain)
        self._merge(part, mat)
        part.free()

    def _uv_box(self, part, grain):
        layer = part.loops.layers.uv.new("UVMap")
        off_u = self.rng.random()
        off_v = self.rng.random()
        axes = {"x": 0, "y": 1, "z": 2}
        for f in part.faces:
            n = f.normal
            dom = max(range(3), key=lambda i: abs(n[i]))
            pair = [i for i in range(3) if i != dom]            # los dos ejes del plano de la cara
            g = axes[grain]
            if g in pair:
                v_axis = g
                u_axis = pair[0] if pair[1] == g else pair[1]
            else:
                u_axis, v_axis = pair
            for loop in f.loops:
                c = loop.vert.co
                loop[layer].uv = (c[u_axis] / TILE + off_u, c[v_axis] / TILE + off_v)

    def _merge(self, part, mat):
        puv = part.loops.layers.uv.active
        vmap = {v: self.bm.verts.new(gv(*v.co)) for v in part.verts}
        for f in part.faces:
            nf = self.bm.faces.new([vmap[v] for v in f.verts])
            nf.smooth = True
            nf.material_index = mat
            for lo, ln in zip(f.loops, nf.loops):
                ln[self.uv].uv = lo[puv].uv

    def add_mesh_faces(self, verts, faces, mat=0):
        """Añade geometría ya construida (coordenadas Godot)."""
        vs = [self.bm.verts.new(gv(*p)) for p in verts]
        for idx in faces:
            try:
                f = self.bm.faces.new([vs[i] for i in idx])
            except ValueError:
                continue
            f.smooth = True
            f.material_index = mat
            for loop in f.loops:
                loop[self.uv].uv = (0.0, 0.0)

    # -- exportar --------------------------------------------------------
    def add_material(self, name, color, roughness=0.8, double_sided=False):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        mat.use_backface_culling = not double_sided
        self.materials.append(mat)

    def export(self):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for m in self.materials or [self._default_material()]:
            mesh.materials.append(m)
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(38))
        path = os.path.join(OUT_DIR, self.name + ".glb")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_normals=True, use_selection=True)
        tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
        print("EXPORTADO:", path, "triangulos:", tris)

    def _default_material(self):
        m = bpy.data.materials.new(self.name + "_mat")
        return m


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


# ------------------------------------------------------------------------
# Estantería: coincide con ShelfUnit (2.1 de ancho, 5 filas, paso 0.34, base 0.16, fondo 0.30)
# ------------------------------------------------------------------------
def make_shelf():
    reset_scene()
    m = Model("shelf_unit", seed=3)
    m.add_material("wood", (0.9, 0.78, 0.58), 0.7)
    W, rows, pitch, base, depth = 2.1, 5, 0.34, 0.16, 0.30
    SIDE_T, BOARD_T = 0.04, 0.06
    inner = W - 2 * SIDE_T
    H = base + rows * pitch + BOARD_T

    for sx in (-1, 1):
        m.box((sx * (W / 2 - SIDE_T / 2), H / 2, depth / 2), (SIDE_T, H, depth), grain="y", bevel=0.005)
    m.box((0, H / 2, 0.01), (inner, H, 0.02), grain="y", bevel=0.0)
    # Zócalo con hueco para los pies
    m.box((0, (base - BOARD_T) / 2, (depth - 0.04) / 2), (inner, base - BOARD_T, depth - 0.04), grain="x", bevel=0.004)
    for sx in (-1, 1):
        m.box((sx * (W / 2 - SIDE_T / 2), 0.035, depth - 0.02), (SIDE_T + 0.012, 0.07, 0.05), grain="y", bevel=0.006)
    # Baldas
    for r in range(rows):
        top = base + r * pitch
        m.box((0, top - BOARD_T / 2, depth / 2), (inner, BOARD_T, depth), grain="x", bevel=0.006, segments=3)
        m.box((0, top + 0.009, depth - 0.007), (inner, 0.018, 0.014), grain="x", bevel=0.003)
    # Remate con moldura
    cap_y = base + rows * pitch
    m.box((0, cap_y + BOARD_T / 2, (depth + 0.03) / 2), (W + 0.04, BOARD_T, depth + 0.03), grain="x", bevel=0.012, segments=3)
    m.box((0, cap_y + BOARD_T + 0.012, (depth + 0.05) / 2), (W + 0.08, 0.026, depth + 0.05), grain="x", bevel=0.009, segments=3)
    m.export()


# ------------------------------------------------------------------------
# Mesa: tablero 1.25 x 1.1, altura 0.76 (RoomShell.TABLE_RECT / TABLE_TOP_Y)
# ------------------------------------------------------------------------
def make_table():
    reset_scene()
    m = Model("table", seed=5)
    m.add_material("wood", (0.8, 0.6, 0.38), 0.6)
    L, D, topy, T = 1.25, 1.1, 0.76, 0.06
    m.box((0, topy - T / 2, 0), (L, T, D), grain="x", bevel=0.009, segments=3)
    # Faldón
    ah = 0.09
    ay = topy - T - ah / 2
    m.box((0, ay, D / 2 - 0.1), (L - 0.2, ah, 0.025), grain="x", bevel=0.003)
    m.box((0, ay, -D / 2 + 0.1), (L - 0.2, ah, 0.025), grain="x", bevel=0.003)
    for sx in (-1, 1):
        m.box((sx * (L / 2 - 0.1), ay, 0), (0.025, ah, D - 0.2), grain="z", bevel=0.003)
    # Patas cónicas
    leg_h = topy - T - 0.002
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.box((sx * (L / 2 - 0.08), leg_h / 2, sz * (D / 2 - 0.08)), (0.07, leg_h, 0.07),
                  grain="y", bevel=0.004, taper=0.62)
    m.export()


# ------------------------------------------------------------------------
# Cajón de madera de listones: 0.62 x 0.32 x 0.50
# ------------------------------------------------------------------------
def make_crate():
    reset_scene()
    m = Model("crate", seed=7)
    m.add_material("wood", (0.84, 0.66, 0.42), 0.8)
    X, Y, Z = 0.62, 0.32, 0.50
    for k in (-1, 0, 1):
        m.box((0, 0.01, k * 0.17), (X - 0.04, 0.02, 0.15), grain="x", bevel=0.002)
    for sz in (-1, 1):
        for i in range(3):
            m.box((0, 0.075 + i * 0.09, sz * (Z / 2 - 0.011)), (X, 0.082, 0.022), grain="x", bevel=0.003)
    for sx in (-1, 1):
        for i in range(3):
            m.box((sx * (X / 2 - 0.011), 0.075 + i * 0.09, 0), (0.022, 0.082, Z - 0.05), grain="z", bevel=0.003)
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.box((sx * (X / 2 - 0.02), Y / 2, sz * (Z / 2 - 0.02)), (0.04, Y, 0.04), grain="y", bevel=0.004)
    m.export()


# ------------------------------------------------------------------------
# Caja de cartón abierta con solapas: 0.62 x 0.42 x 0.50
# ------------------------------------------------------------------------
def make_cardboard():
    reset_scene()
    m = Model("cardboard_box", seed=9)
    m.add_material("cardboard", (0.79, 0.64, 0.42), 0.95)
    X, Y, Z, T = 0.62, 0.42, 0.50, 0.012
    m.box((0, T / 2, 0), (X, T, Z), grain="x", bevel=0.002, segments=1)
    for sz in (-1, 1):
        m.box((0, Y / 2, sz * (Z / 2 - T / 2)), (X, Y, T), grain="x", bevel=0.002, segments=1)
    for sx in (-1, 1):
        m.box((sx * (X / 2 - T / 2), Y / 2, 0), (T, Y, Z - 2 * T), grain="z", bevel=0.002, segments=1)
    # Solapas abiertas hacia fuera
    for sz, ang in ((1, 118), (-1, -118)):
        m.box((0, Y + 0.004, sz * (Z / 2 + 0.12)), (X - 0.01, 0.008, 0.24), grain="x", bevel=0.001, segments=1,
              rotate=("X", -ang * sz, (0, Y, sz * Z / 2)))
    m.export()


# ------------------------------------------------------------------------
# Planta en maceta: maceta de terracota, tierra y hojas arqueadas
# ------------------------------------------------------------------------
def lathe(model, profile, segments, mat):
    rings = []
    verts = []
    for (r, y) in profile:
        ring = []
        for k in range(segments):
            a = math.tau * k / segments
            ring.append(len(verts))
            verts.append((r * math.cos(a), y, r * math.sin(a)))
        rings.append(ring)
    faces = []
    for i in range(len(rings) - 1):
        for k in range(segments):
            k2 = (k + 1) % segments
            faces.append((rings[i][k], rings[i + 1][k], rings[i + 1][k2], rings[i][k2]))
    model.add_mesh_faces(verts, faces, mat)


def leaf(model, base, yaw, length, width, lift, droop, mat):
    rows, cols = 8, 5
    d = Vector((math.cos(yaw), 0.0, math.sin(yaw)))
    s = Vector((-math.sin(yaw), 0.0, math.cos(yaw)))
    verts = []
    for i in range(rows):
        t = i / (rows - 1)
        centre = Vector(base) + d * (length * t) + Vector((0, lift * t - droop * t * t, 0))
        w = width * math.sin(math.pi * (t ** 0.75)) + 0.004
        for j in range(cols):
            c = (j / (cols - 1)) * 2.0 - 1.0
            fold = abs(c) * w * 0.25            # nervio central: hoja ligeramente plegada
            verts.append((centre + s * (c * w) + Vector((0, fold, 0)))[:])
    faces = []
    for i in range(rows - 1):
        for j in range(cols - 1):
            a = i * cols + j
            faces.append((a, a + 1, a + cols + 1, a + cols))
    model.add_mesh_faces(verts, faces, mat)


def make_plant():
    reset_scene()
    m = Model("plant", seed=11)
    m.add_material("pot", (0.76, 0.44, 0.29), 0.85)
    m.add_material("leaf", (0.36, 0.60, 0.35), 0.75, double_sided=True)
    m.add_material("soil", (0.22, 0.15, 0.10), 1.0)
    pot = [(0.0, 0.0), (0.13, 0.0), (0.15, 0.025), (0.19, 0.30), (0.215, 0.33), (0.22, 0.365), (0.20, 0.372), (0.19, 0.345)]
    lathe(m, pot, 28, 0)
    lathe(m, [(0.0, 0.335), (0.185, 0.335)], 28, 2)
    rng = random.Random(4)
    for i in range(11):
        yaw = i * (math.tau / 11) + rng.uniform(-0.2, 0.2)
        r0 = rng.uniform(0.02, 0.09)
        base = (math.cos(yaw) * r0, 0.34, math.sin(yaw) * r0)
        leaf(m, base, yaw, rng.uniform(0.42, 0.7), rng.uniform(0.07, 0.1), rng.uniform(0.35, 0.65), rng.uniform(0.12, 0.3), 1)
    m.export()


for fn in (make_shelf, make_table, make_crate, make_cardboard, make_plant):
    fn()
