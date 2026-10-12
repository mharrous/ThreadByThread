"""Genera el modelo del ovillo de lana (original) y lo exporta a GLB para Godot.

Uso:
  blender --background --python art/blender/make_yarn_ball.py -- art/models/yarn_ball.glb

Forma: esfera ligeramente achatada con irregularidades suaves (un ovillo enrollado nunca
es perfecto) + una hebra suelta que sale de la superficie y se curva. ~1.5k triángulos.
El color y el dibujo de las hebras los pone el shader de Godot (shaders/yarn.gdshader),
así un único modelo sirve para todos los colores y tipos de lana.
"""
import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

out_path = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "yarn_ball.glb"

R = 0.055            # radio en metros (coincide con PickableItem.BASE_RADIUS)
TAIL_RADIUS = 0.0012
TAIL_SIDES = 6

bpy.ops.wm.read_factory_settings(use_empty=True)

bm = bmesh.new()
bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=20, radius=R)

# Forma orgánica: grumos suaves de baja frecuencia + achatamiento vertical.
for v in bm.verts:
    n = v.co.normalized()
    lump = noise.noise(n * 2.3 + Vector((3.1, 1.7, 5.2))) * 0.045
    fine = noise.noise(n * 7.0 + Vector((9.0, 2.0, 4.0))) * 0.012
    s = R * (1.0 + lump + fine)
    v.co = Vector((n.x * s, n.y * s, n.z * s * 0.96))


def tail_path():
    """Hebra suelta: pegada a la superficie un trecho y luego se despega y se curva."""
    start = Vector((0.92, 0.28, -0.10)).normalized()
    axis = start.cross(Vector((0.0, 0.0, 1.0))).normalized()
    pts = []
    steps = 14
    for i in range(steps):
        a = math.radians(55.0) * i / (steps - 1)
        d = start.copy()
        d.rotate(Matrix.Rotation(a, 3, axis))
        pts.append(d * (R * 1.0 + TAIL_RADIUS * 0.6))
    tangent = (pts[-1] - pts[-2]).normalized()
    outward = pts[-1].normalized()
    side = tangent.cross(outward).normalized()
    p = pts[-1].copy()
    for i in range(1, 13):
        t = i / 12.0
        direction = (tangent * (1.0 - 0.35 * t) + outward * (0.55 * t) + side * (0.9 * math.sin(3.6 * t))).normalized()
        p = p + direction * 0.0052
        pts.append(p.copy())
    return pts


def add_tube(bm, pts, radius, sides):
    rings = []
    prev_normal = None
    for i, p in enumerate(pts):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        t = (b - a).normalized()
        if prev_normal is None:
            helper = Vector((0.0, 0.0, 1.0)) if abs(t.z) < 0.9 else Vector((1.0, 0.0, 0.0))
            normal = (helper - t * helper.dot(t)).normalized()
        else:
            normal = (prev_normal - t * prev_normal.dot(t)).normalized()
        binormal = t.cross(normal)
        prev_normal = normal
        # La hebra se afina hacia la punta.
        r = radius * (1.0 - 0.35 * i / (len(pts) - 1))
        ring = []
        for k in range(sides):
            ang = math.tau * k / sides
            ring.append(bm.verts.new(p + (normal * math.cos(ang) + binormal * math.sin(ang)) * r))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            bm.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))
    tip = bm.verts.new(pts[-1] + (pts[-1] - pts[-2]).normalized() * radius * 0.6)
    for k in range(sides):
        bm.faces.new((rings[-1][k], rings[-1][(k + 1) % sides], tip))


add_tube(bm, tail_path(), TAIL_RADIUS, TAIL_SIDES)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
for f in bm.faces:
    f.smooth = True

mesh = bpy.data.meshes.new("YarnBall")
bm.to_mesh(mesh)
bm.free()

obj = bpy.data.objects.new("YarnBall", mesh)
bpy.context.scene.collection.objects.link(obj)

mat = bpy.data.materials.new("Yarn")
mesh.materials.append(mat)

bpy.ops.export_scene.gltf(
    filepath=out_path,
    export_format="GLB",
    export_yup=True,
    export_normals=True,
)
print("EXPORTADO:", out_path, "vertices:", len(mesh.vertices), "triangulos:", sum(len(p.vertices) - 2 for p in mesh.polygons))
