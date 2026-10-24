"""Utilidades de modelado compartidas por los scripts de Blender del proyecto.

Se modela en ejes de Godot (X derecha, Y arriba, Z hacia delante) y al fusionar cada pieza se
convierte a ejes de Blender; el exportador glTF los devuelve a Godot. Cada pieza lleva UVs en
metros (1 azulejo de textura = 0.5 m) y normales suavizadas por ángulo. Las superficies se
nombran "main", "accent", "metal" o "glass": el juego decide qué material lleva cada una
(scripts/core/item_materials.gd).
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

TILE = 0.5
OUT_DIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."


def gv(x, y, z):
    """Ejes de Godot -> ejes de Blender (rotación propia, conserva el sentido de las caras)."""
    return Vector((x, -z, y))


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


class Model:
    def __init__(self, name, seed=1):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.rng = random.Random(seed)
        self.materials = []
        self.min = Vector((1e9, 1e9, 1e9))
        self.max = Vector((-1e9, -1e9, -1e9))

    # -- materiales -------------------------------------------------------
    def add_material(self, name, color, roughness=0.8, double_sided=False, metallic=0.0):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        mat.use_backface_culling = not double_sided
        self.materials.append(mat)

    # -- piezas -----------------------------------------------------------
    def box(self, center, size, grain="y", bevel=0.004, segments=2, taper=None, rotate=None, mat=0):
        """Caja biselada. taper = escala de la base. rotate = (eje, grados, pivote)."""
        part = bmesh.new()
        bmesh.ops.create_cube(part, size=1.0)
        for v in part.verts:
            x, y, z = v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]
            if taper is not None:
                k = taper + (1.0 - taper) * (v.co.y + 0.5)
                x *= k
                z *= k
            v.co = Vector((x, y, z)) + Vector(center)
        if bevel > 0:
            bmesh.ops.bevel(part, geom=list(part.edges), offset=bevel, offset_type="OFFSET",
                            segments=segments, profile=0.5, affect="EDGES")
        self._finish(part, grain, mat, rotate)

    def lathe(self, profile, segments=24, axis="y", center=(0, 0, 0), mat=0, grain="y",
              closed=False, rotate=None, scale=(1.0, 1.0, 1.0)):
        """Sólido de revolución alrededor de un eje. profile = [(radio, altura), ...]."""
        part = bmesh.new()
        rings = []
        for (r, h) in profile:
            if r < 1e-6 and not closed:
                rings.append([part.verts.new(Vector((0.0, h, 0.0)))])
            else:
                ring = []
                for k in range(segments):
                    a = math.tau * k / segments
                    ring.append(part.verts.new(Vector((r * math.cos(a), h, r * math.sin(a)))))
                rings.append(ring)
        n = len(rings)
        last = n if closed else n - 1
        for i in range(last):
            ra, rb = rings[i], rings[(i + 1) % n]
            for k in range(segments):
                k2 = (k + 1) % segments
                quad = [ra[k % len(ra)], rb[k % len(rb)], rb[k2 % len(rb)], ra[k2 % len(ra)]]
                uniq = []
                for v in quad:
                    if v not in uniq:
                        uniq.append(v)
                if len(uniq) >= 3:
                    try:
                        part.faces.new(uniq)
                    except ValueError:
                        pass
        self._orient(part, axis)
        for v in part.verts:
            v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2])) + Vector(center)
        self._finish(part, grain, mat, rotate)

    def cylinder(self, center, radius, height, axis="y", segments=24, mat=0, grain="y", round_edge=0.0,
                 rotate=None, scale=(1.0, 1.0, 1.0)):
        h2 = height * 0.5
        e = min(round_edge, radius * 0.9, h2 * 0.9)
        if e > 0:
            profile = [(0, -h2), (radius - e, -h2), (radius - e * 0.3, -h2 + e * 0.3), (radius, -h2 + e),
                       (radius, h2 - e), (radius - e * 0.3, h2 - e * 0.3), (radius - e, h2), (0, h2)]
        else:
            profile = [(0, -h2), (radius, -h2), (radius, h2), (0, h2)]
        self.lathe(profile, segments, axis, center, mat, grain, rotate=rotate, scale=scale)

    def torus(self, center, major, minor, axis="y", major_seg=24, minor_seg=8, mat=0, rotate=None, scale=(1.0, 1.0, 1.0)):
        profile = []
        for k in range(minor_seg):
            a = math.tau * k / minor_seg
            profile.append((major + minor * math.cos(a), minor * math.sin(a)))
        self.lathe(profile, major_seg, axis, center, mat, "y", closed=True, rotate=rotate, scale=scale)

    def sphere(self, center, radius, scale=(1.0, 1.0, 1.0), segments=16, rings=10, mat=0, rotate=None):
        part = bmesh.new()
        bmesh.ops.create_uvsphere(part, u_segments=segments, v_segments=rings, radius=radius)
        for v in part.verts:
            v.co = Vector((v.co.x * scale[0], v.co.z * scale[1], v.co.y * scale[2])) + Vector(center)
        self._finish(part, "y", mat, rotate)

    def tube(self, points, radius, sides=6, mat=0, taper=0.0, cap=True):
        """Barrido de un círculo a lo largo de una ruta (hilos sueltos, asas)."""
        part = bmesh.new()
        rings = []
        prev_normal = None
        for i, p in enumerate(points):
            a = Vector(points[max(i - 1, 0)])
            b = Vector(points[min(i + 1, len(points) - 1)])
            t = (b - a).normalized()
            if prev_normal is None:
                helper = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
                normal = (helper - t * helper.dot(t)).normalized()
            else:
                normal = (prev_normal - t * prev_normal.dot(t)).normalized()
            binormal = t.cross(normal)
            prev_normal = normal
            r = radius * (1.0 - taper * i / (len(points) - 1))
            ring = []
            for k in range(sides):
                ang = math.tau * k / sides
                ring.append(part.verts.new(Vector(p) + (normal * math.cos(ang) + binormal * math.sin(ang)) * r))
            rings.append(ring)
        for i in range(len(rings) - 1):
            for k in range(sides):
                k2 = (k + 1) % sides
                part.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))
        if cap:
            tip = part.verts.new(Vector(points[-1]) + (Vector(points[-1]) - Vector(points[-2])).normalized() * radius * 0.6)
            for k in range(sides):
                part.faces.new((rings[-1][k], rings[-1][(k + 1) % sides], tip))
        self._finish(part, "y", mat, None)

    # -- internos ---------------------------------------------------------
    @staticmethod
    def _orient(part, axis):
        if axis == "y":
            return
        rot = Matrix.Rotation(math.radians(-90.0), 3, "Z") if axis == "x" else Matrix.Rotation(math.radians(90.0), 3, "X")
        for v in part.verts:
            v.co = rot @ v.co

    def _finish(self, part, grain, mat, rotate):
        if rotate is not None:
            axis, deg, pivot = rotate
            rot = Matrix.Rotation(math.radians(deg), 3, axis)
            piv = Vector(pivot)
            for v in part.verts:
                v.co = rot @ (v.co - piv) + piv
        bmesh.ops.remove_doubles(part, verts=list(part.verts), dist=1e-6)
        bmesh.ops.recalc_face_normals(part, faces=list(part.faces))
        self._uv_box(part, grain)
        puv = part.loops.layers.uv.active
        vmap = {}
        for v in part.verts:
            vmap[v] = self.bm.verts.new(gv(*v.co))
            for i in range(3):
                self.min[i] = min(self.min[i], v.co[i])
                self.max[i] = max(self.max[i], v.co[i])
        for f in part.faces:
            try:
                nf = self.bm.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                continue
            nf.smooth = True
            nf.material_index = mat
            for lo, ln in zip(f.loops, nf.loops):
                ln[self.uv].uv = lo[puv].uv
        part.free()

    def _uv_box(self, part, grain):
        layer = part.loops.layers.uv.new("UVMap")
        off_u = self.rng.random()
        off_v = self.rng.random()
        axes = {"x": 0, "y": 1, "z": 2}
        for f in part.faces:
            n = f.normal
            dom = max(range(3), key=lambda i: abs(n[i]))
            pair = [i for i in range(3) if i != dom]
            g = axes[grain]
            if g in pair:
                v_axis = g
                u_axis = pair[0] if pair[1] == g else pair[1]
            else:
                u_axis, v_axis = pair
            for loop in f.loops:
                c = loop.vert.co
                loop[layer].uv = (c[u_axis] / TILE + off_u, c[v_axis] / TILE + off_v)

    # -- exportar ---------------------------------------------------------
    def export(self, shade_angle=38.0, center_y=True):
        # Centra el modelo en vertical: el origen queda en el centro de su altura, así la
        # "mitad de altura" del juego coincide con lo que se ve apoyado en una superficie.
        if center_y:
            cy = (self.min.y + self.max.y) * 0.5
            for v in self.bm.verts:
                v.co.z -= cy
            self.min.y -= cy
            self.max.y -= cy
        bmesh.ops.recalc_face_normals(self.bm, faces=list(self.bm.faces))
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for m in self.materials or [bpy.data.materials.new(self.name + "_mat")]:
            mesh.materials.append(m)
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(shade_angle))
        path = os.path.join(OUT_DIR, self.name + ".glb")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_normals=True, use_selection=True)
        tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
        size = self.max - self.min
        print("EXPORTADO: %s  triangulos=%d  tamaño(x,y,z)=(%.3f, %.3f, %.3f)  min=(%.3f, %.3f, %.3f)" % (
            self.name, tris, size.x, size.y, size.z, self.min.x, self.min.y, self.min.z))


class Rig(Model):
    """Modelo con esqueleto: cada pieza se pesa entera (100 %) al hueso activo (`self.bone`).

    Los huesos se definen en ejes de Godot: bones = [(nombre, cabeza, cola, padre), ...].
    Las animaciones se escriben con `pose(acción, fotograma, {hueso: (rot_x, rot_y, rot_z)})`, con los
    giros en radianes alrededor de los ejes de Godot (X derecha, Y arriba, Z delante) y en el espacio
    del modelo, no del hueso: así "girar la cabeza" es siempre rot_y aunque el hueso esté inclinado.
    Cada acción se exporta como una animación del GLB con su nombre.
    """

    def __init__(self, name, bones, seed=1):
        super().__init__(name, seed)
        self.bones = bones
        self.bone_names = [b[0] for b in bones]
        self.bone = bones[0][0]
        self.deform = self.bm.verts.layers.deform.verify()
        self.actions = {}   # nombre -> {"length": n, "keys": {fotograma: {hueso: (rot, loc)}}}

    def _finish(self, part, grain, mat, rotate):
        self.bm.verts.ensure_lookup_table()
        n0 = len(self.bm.verts)
        super()._finish(part, grain, mat, rotate)
        self.bm.verts.ensure_lookup_table()
        gi = self.bone_names.index(self.bone)
        for i in range(n0, len(self.bm.verts)):
            self.bm.verts[i][self.deform][gi] = 1.0

    def action(self, name, length):
        self.actions[name] = {"length": length, "keys": {}}

    def pose(self, action, frame, rots, locs=None, only=False, scales=None):
        """only=True: solo se animan los huesos de `rots` (para animaciones que se mezclan encima de otra).
        scales: {hueso: (sx, sy, sz)} en los ejes del hueso (Y = a lo largo del hueso), p. ej. para parpadear."""
        keys = self.actions[action]["keys"].setdefault(frame, {})
        for b in (list(rots) if only else self.bone_names):
            keys[b] = (rots.get(b, (0.0, 0.0, 0.0)), (locs or {}).get(b, (0.0, 0.0, 0.0)),
                       (scales or {}).get(b, (1.0, 1.0, 1.0)))

    def export(self, shade_angle=38.0, center_y=False, fps=24):
        bmesh.ops.recalc_face_normals(self.bm, faces=list(self.bm.faces))
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for m in self.materials:
            mesh.materials.append(m)
        obj = bpy.data.objects.new(self.name, mesh)
        scene = bpy.context.scene
        scene.collection.objects.link(obj)
        for b in self.bone_names:
            obj.vertex_groups.new(name=b)
        scene.render.fps = fps

        arm_data = bpy.data.armatures.new(self.name + "_rig")
        arm = bpy.data.objects.new(self.name + "_rig", arm_data)
        scene.collection.objects.link(arm)
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode="EDIT")
        for (bname, head, tail, parent) in self.bones:
            eb = arm_data.edit_bones.new(bname)
            eb.head = gv(*head)
            eb.tail = gv(*tail)
            eb.roll = 0.0
            if parent:
                eb.parent = arm_data.edit_bones[parent]
                eb.use_connect = False
        bpy.ops.object.mode_set(mode="OBJECT")
        obj.parent = arm
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = arm

        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(shade_angle))

        # Giros en ejes de Godot (espacio del modelo) -> giro local de cada hueso.
        axes = {0: Vector((1, 0, 0)), 1: Vector((0, 0, 1)), 2: Vector((0, -1, 0))}
        arm.animation_data_create()
        arm.rotation_mode = "XYZ"
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
        for aname, act in self.actions.items():
            action = bpy.data.actions.new(aname)
            action.use_fake_user = True
            arm.animation_data.action = action
            for frame in sorted(act["keys"]):
                for bname, (rot, loc, scl) in act["keys"][frame].items():
                    pb = arm.pose.bones[bname]
                    rest = pb.bone.matrix_local.to_3x3()
                    r = Matrix.Identity(3)
                    for i in (2, 1, 0):
                        if abs(rot[i]) > 1e-9:
                            r = Matrix.Rotation(rot[i], 3, axes[i]) @ r
                    local = rest.inverted() @ r @ rest
                    pb.rotation_quaternion = local.to_quaternion()
                    pb.location = rest.inverted() @ gv(*loc)
                    pb.scale = scl
                    pb.keyframe_insert("rotation_quaternion", frame=frame)
                    pb.keyframe_insert("location", frame=frame)
                    pb.keyframe_insert("scale", frame=frame)
            track = arm.animation_data.nla_tracks.new()
            track.name = aname
            track.strips.new(aname, int(min(act["keys"])), action)
            arm.animation_data.action = None
        for pb in arm.pose.bones:
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.location = (0, 0, 0)
            pb.scale = (1, 1, 1)

        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        arm.select_set(True)
        path = os.path.join(OUT_DIR, self.name + ".glb")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_normals=True,
                                  use_selection=True, export_animations=True, export_animation_mode="NLA_TRACKS",
                                  export_force_sampling=True, export_optimize_animation_size=False)
        tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
        size = self.max - self.min
        print("EXPORTADO: %s  triangulos=%d  huesos=%d  animaciones=%s  tamaño(x,y,z)=(%.3f, %.3f, %.3f)" % (
            self.name, tris, len(self.bones), ",".join(self.actions), size.x, size.y, size.z))
