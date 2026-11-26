"""Rigga una pelle statica in A-pose (braccia aperte di circa 45 gradi) usando lo scheletro di un
modello del gioco già riggato su Mixamo, e porta il riposo dello scheletro in T-pose.

Perché serve: le animazioni del manichino Y Bot sono rotazioni rispetto a un riposo in T-pose.
Su uno scheletro che riposa in A-pose le stesse rotazioni piegano le braccia nel verso sbagliato
(braccia "accartocciate"). Qui si alzano le braccia a T, si fissa la mesh in quella posa e la si
usa come nuovo riposo.

uso: python3 tools/apose_a_tpose.py MODELLO_RIGGATO.glb PELLE_STATICA.fbx USCITA.fbx [facce]
"""
import sys
import bpy
import mathutils
import numpy as np


def importa(f):
    prima = set(bpy.data.objects)
    if f.lower().endswith(".glb") or f.lower().endswith(".gltf"):
        bpy.ops.import_scene.gltf(filepath=f)
    elif f.lower().endswith(".obj"):
        bpy.ops.wm.obj_import(filepath=f, forward_axis="NEGATIVE_Z", up_axis="Y")
    else:
        bpy.ops.import_scene.fbx(filepath=f, automatic_bone_orientation=False, ignore_leaf_bones=True)
    return [o for o in bpy.data.objects if o not in prima]


def bbox(o):
    v = np.array([o.matrix_world @ x.co for x in o.data.vertices])
    return v.min(0), v.max(0)


def main(riggato, statica, uscita, facce=30000):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    base = importa(riggato)
    arm = next(o for o in base if o.type == "ARMATURE")
    vecchia = next(o for o in base if o.type == "MESH" and o.parent == arm)
    for o in base:
        if o not in (arm, vecchia) and o.name in bpy.data.objects:
            bpy.data.objects.remove(o, do_unlink=True)
    if arm.animation_data:
        arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis = mathutils.Matrix.Identity(4)
    bpy.context.view_layer.update()

    nuovi = [o for o in importa(statica) if o.type == "MESH"]
    corpo = nuovi[0]
    bpy.ops.object.select_all(action="DESELECT")
    corpo.select_set(True)
    bpy.context.view_layer.objects.active = corpo
    corpo.parent = None
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0001)
    bpy.ops.object.mode_set(mode="OBJECT")
    # le pelli generate (Tripo) guardano di lato: si girano come la pelle riggata
    b0, b1 = bbox(corpo)
    a0, a1 = bbox(vecchia)
    if (b1 - b0)[0] < (b1 - b0)[1] and (a1 - a0)[0] > (a1 - a0)[1]:
        corpo.data.transform(mathutils.Matrix.Rotation(-1.5707963, 4, "Z"))
        corpo.data.update()
    if len(corpo.data.polygons) > facce:
        m = corpo.modifiers.new("dec", "DECIMATE")
        m.ratio = facce / len(corpo.data.polygons)
        bpy.ops.object.modifier_apply(modifier=m.name)
    for img in bpy.data.images:
        if img.size[0] > 2048:
            img.scale(2048, 2048)

    # stessa posizione e statura della pelle già riggata (sono lo stesso personaggio)
    a0, a1 = bbox(vecchia)
    b0, b1 = bbox(corpo)
    print("riggata", a1 - a0, "statica", b1 - b0)
    k = (a1[2] - a0[2]) / (b1[2] - b0[2])
    corpo.scale = (k, k, k)
    bpy.ops.object.transform_apply(scale=True)
    b0, b1 = bbox(corpo)
    corpo.location = ((a0 + a1) / 2 - (b0 + b1) / 2)[:3] * np.array([1, 1, 0]) + np.array([0, 0, a0[2] - b0[2]])
    bpy.ops.object.transform_apply(location=True)

    # pesi presi dalla pelle riggata, vertice per vertice sulla superficie più vicina
    dt = corpo.modifiers.new("pesi", "DATA_TRANSFER")
    dt.object = vecchia
    dt.use_vert_data = True
    dt.data_types_verts = {"VGROUP_WEIGHTS"}
    dt.vert_mapping = "POLYINTERP_NEAREST"
    bpy.ops.object.datalayout_transfer(modifier=dt.name)
    bpy.ops.object.modifier_apply(modifier=dt.name)
    bpy.data.objects.remove(vecchia, do_unlink=True)
    corpo.name = "Pelle"
    corpo.parent = arm
    corpo.matrix_parent_inverse = arm.matrix_world.inverted()
    am = corpo.modifiers.new("Armature", "ARMATURE")
    am.object = arm

    # braccia a T: ogni osso del braccio si allinea all'orizzontale, verso l'esterno
    for lato, sx in (("Left", 1.0), ("Right", -1.0)):
        for nome in ("Arm", "ForeArm", "Hand"):
            pb = arm.pose.bones["mixamorig:" + lato + nome]
            bpy.context.view_layer.update()
            mw = arm.matrix_world @ pb.matrix
            testa = mw.translation
            coda = arm.matrix_world @ pb.tail
            ora = (coda - testa).normalized()
            voluto = mathutils.Vector((sx, 0.0, 0.0))
            rot = ora.rotation_difference(voluto)
            nuova = mathutils.Matrix.Translation(testa) @ rot.to_matrix().to_4x4() @ mathutils.Matrix.Translation(-testa) @ mw
            pb.matrix = arm.matrix_world.inverted() @ nuova
    bpy.context.view_layer.update()

    # la posa a T diventa il riposo: si fissa la mesh deformata, poi lo scheletro
    bpy.ops.object.select_all(action="DESELECT")
    corpo.select_set(True)
    bpy.context.view_layer.objects.active = corpo
    bpy.ops.object.modifier_apply(modifier=am.name)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    am = corpo.modifiers.new("Armature", "ARMATURE")
    am.object = arm
    for lato in ("Left", "Right"):
        b = arm.data.bones["mixamorig:" + lato + "Arm"]
        print(lato, "braccio a riposo", tuple(round(x, 2) for x in (b.tail_local - b.head_local).normalized()))

    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    corpo.select_set(True)
    bpy.ops.export_scene.fbx(filepath=uscita, use_selection=True, add_leaf_bones=False, path_mode="COPY",
                             embed_textures=True, bake_anim=False)
    print("esportato", uscita, len(corpo.data.vertices), "vertici")


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    main(a[0], a[1], a[2], int(a[3]) if len(a) > 3 else 30000)
