"""Unisce il manichino Mixamo (Y Bot) e le sue animazioni in un solo GLB per Godot.

Le animazioni restano "sul posto": il gioco sposta la figura da un esagono all'altro,
quindi dalle anche si toglie lo spostamento orizzontale complessivo di ogni clip
(resta l'oscillazione, sparisce la deriva).

Uso (Blender come modulo Python, oppure dentro Blender):
    python3 tools/mixamo_a_glb.py CARTELLA_FBX USCITA.glb [PELLE.glb]
Con PELLE.glb (un personaggio statico in T-pose, per esempio generato da un'IA) il manichino
viene sostituito: lo scheletro di Mixamo si adatta alle sue misure (braccia comprese) e la
pelle si lega alle ossa con i pesi automatici di Blender. Le animazioni restano quelle.
I file FBX di Mixamo non vanno nel repository: la licenza permette di usarli nel gioco,
non di ridistribuirli da soli.
"""
import os
import sys

import bpy

ANIMAZIONI = ["idle", "jab", "cross", "montante", "calcio", "parata", "schivata",
              "passo_avanti", "passo_indietro", "passo_sinistra", "passo_destra",
              "gira_sinistra", "gira_destra", "colpito_testa", "colpito_corpo",
              "ko", "rialzata", "proiezione", "proiettato", "vittoria", "sconfitta", "caduta"]
# parte utile delle clip lunghe (fotogrammi a 30 al secondo): la proiezione dura 6,7 s, la rialzata 8,4 s
TAGLI = {"proiezione": (40, 118), "proiettato": (40, 118), "rialzata": (95, 190), "caduta": (20, 90)}
# clip in cui lo spostamento delle anche resta (la caduta all'indietro); nelle altre si toglie
CON_DERIVA = {"caduta"}
# clip in cui le anche restano ferme in orizzontale: il volo lo fa il gioco, verso l'esagono giusto
FISSE = {"proiezione", "proiettato"}
# clip che si ripetono in loop in Godot
CICLICHE = {"idle"}


def importa(path):
    prima = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False, ignore_leaf_bones=True)
    return [o for o in bpy.data.objects if o not in prima]


def taglia(action, da, a):
    """Tiene solo i fotogrammi da..a e li riporta a partire da 1."""
    for fc in _fcurves(action):
        kp = fc.keyframe_points
        for i in range(len(kp) - 1, -1, -1):
            if kp[i].co[0] < da or kp[i].co[0] > a:
                kp.remove(kp[i])
        for k in kp:
            k.co[0] -= da - 1
            k.handle_left[0] -= da - 1
            k.handle_right[0] -= da - 1
        fc.update()


def fissa(action):
    for fc in _fcurves(action):
        if fc.data_path.endswith('location') and 'Hips' in fc.data_path and fc.array_index in (0, 2):
            for k in fc.keyframe_points:
                d = k.co[1]
                k.co[1] = 0.0
                k.handle_left[1] -= d
                k.handle_right[1] -= d
            fc.update()


def sul_posto(action, deriva=False):
    """Porta le anche all'origine nel primo fotogramma (le clip in coppia di Mixamo partono a 2 m di
    distanza) e, salvo deriva=True, toglie lo spostamento orizzontale complessivo."""
    for fc in _fcurves(action):
        if fc.data_path.endswith('location') and 'Hips' in fc.data_path and fc.array_index in (0, 2):
            kp = fc.keyframe_points
            if len(kp) < 2:
                continue
            x0, y0 = kp[0].co
            x1, y1 = kp[-1].co
            for k in kp:
                t = 0.0 if x1 == x0 else (k.co[0] - x0) / (x1 - x0)
                # nella caduta resta un terzo dello spostamento, così chi cade resta nel suo esagono
                d = y0 + ((k.co[1] - y0) * 0.65 if deriva else (y1 - y0) * t)
                k.co[1] -= d
                k.handle_left[1] -= d
                k.handle_right[1] -= d
            fc.update()


def veste_pelle(arm, pelle, facce=60000, lato_tex=2048):
    """Sostituisce le mesh del manichino con la pelle e adatta lo scheletro alle sue misure."""
    import mathutils
    import numpy as np
    vecchie = [o for o in bpy.data.objects if o.type == "MESH"]
    yv = np.array([o.matrix_world @ v.co for o in vecchie for v in o.data.vertices])
    prima = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=pelle)
    nuovi = [o for o in bpy.data.objects if o not in prima]
    mesh = [o for o in nuovi if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in mesh:
        o.select_set(True)
    bpy.context.view_layer.objects.active = mesh[0]
    if len(mesh) > 1:
        bpy.ops.object.join()
    corpo = bpy.context.view_layer.objects.active
    corpo.parent = None
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in nuovi:
        if o != corpo and o.name in bpy.data.objects:
            bpy.data.objects.remove(o, do_unlink=True)
    # le mesh generate hanno spesso vertici doppi lungo le cuciture: la pesatura automatica fallisce
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    bpy.ops.object.mode_set(mode="OBJECT")
    # meno poligoni: il gioco gira anche nel browser
    if len(corpo.data.polygons) > facce:
        m = corpo.modifiers.new("dec", "DECIMATE")
        m.ratio = facce / len(corpo.data.polygons)
        bpy.ops.object.modifier_apply(modifier=m.name)
    for img in bpy.data.images:
        if img.size[0] > lato_tex:
            img.scale(lato_tex, lato_tex)
    v = np.array([corpo.matrix_world @ x.co for x in corpo.data.vertices])
    mw = arm.matrix_world
    def testa(n):
        return mw @ arm.data.bones["mixamorig:" + n].head_local
    # altezza delle spalle uguale a quella del manichino (le braccia in T sono la parte più chiara)
    def braccia_z(pts):
        mx = np.abs(pts[:, 0]).max()
        return float(np.median(pts[np.abs(pts[:, 0]) > 0.6 * mx][:, 2]))
    k = (braccia_z(yv) - yv[:, 2].min()) / (braccia_z(v) - v[:, 2].min())
    corpo.location = (-(v[:, 0].max() + v[:, 0].min()) / 2 * k, -(v[:, 1].max() + v[:, 1].min()) / 2 * k, -v[:, 2].min() * k)
    corpo.scale = (k, k, k)
    bpy.ops.object.transform_apply(location=True, scale=True)
    v = np.array([x.co for x in corpo.data.vertices])
    # le braccia si scalano attorno alla spalla: stessa direzione delle ossa, quindi le animazioni restano valide
    sx = testa("LeftArm").x
    s_br = (v[:, 0].max() - sx) / (yv[:, 0].max() - sx)
    print("pelle: scala", round(k, 3), "braccia", round(s_br, 3))
    for o in vecchie:
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    inv = mw.inverted()
    eb = arm.data.edit_bones
    for lato in ("Left", "Right"):
        perno = eb["mixamorig:%sArm" % lato].head.copy()
        catena = [b for b in eb if b.name == "mixamorig:%sArm" % lato or
                  any(p.name == "mixamorig:%sArm" % lato for p in b.parent_recursive)]
        for b in catena:
            b.head = perno + (b.head - perno) * s_br
            b.tail = perno + (b.tail - perno) * s_br
    bpy.ops.object.mode_set(mode="OBJECT")
    corpo.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    senza = sum(1 for x in corpo.data.vertices if not x.groups)
    print("pelle: vertici senza peso", senza, "su", len(corpo.data.vertices))
    corpo.name = "Pelle"


# misure del manichino Y Bot, a cui si riferiscono le animazioni scaricate
YBOT_ANCHE = 99.79   # altezza di riposo dell'osso Hips, in centimetri
YBOT_ALTEZZA = 1.805  # altezza della figura, in metri


def adatta_anche(action, riposo, k):
    """Le animazioni del manichino danno le anche come scarto dal suo riposo (99,79 cm).
    Una pelle riggata da Mixamo ha un altro riposo e un'altra statura: si riporta l'altezza
    assoluta e la si scala con la statura, così i piedi restano sul pavimento."""
    for fc in _fcurves(action):
        if fc.data_path.endswith('location') and 'Hips' in fc.data_path:
            i = fc.array_index
            for kp in fc.keyframe_points:
                for pt in (kp.co, kp.handle_left, kp.handle_right):
                    ass = pt[1] + (YBOT_ANCHE if i == 1 else 0.0)
                    pt[1] = ass * k - (riposo[i])
            fc.update()


def _fcurves(action):
    # Blender 4.4+ usa le "slotted actions": le curve stanno nei layer/strip/channelbag
    if hasattr(action, "fcurves") and len(action.fcurves):
        return list(action.fcurves)
    out = []
    for layer in getattr(action, "layers", []):
        for strip in layer.strips:
            for cb in getattr(strip, "channelbags", []):
                out.extend(cb.fcurves)
    return out


def main(cartella, uscita, pelle=None, statura=None):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # una pelle già riggata da Mixamo (FBX "T-pose, with skin") prende il posto del manichino
    riggata = bool(pelle) and pelle.lower().endswith(".fbx")
    base = importa(pelle if riggata else os.path.join(cartella, "ybot.fbx"))
    arm = next(o for o in base if o.type == "ARMATURE")
    arm.name = "Combattente"
    adatta = None
    if riggata:
        import mathutils
        alt = max((o.matrix_world @ mathutils.Vector(c)).z for o in base if o.type == "MESH" for c in o.bound_box)
        # statura voluta (quarto argomento, in metri): Mixamo riscala i modelli a piacere
        # (la scala dell'armatura ingrandisce anche gli spostamenti delle anche: k resta sulla statura originale)
        if statura:
            arm.scale = arm.scale * (statura / alt)
        adatta = (tuple(arm.data.bones["mixamorig:Hips"].head_local), alt / YBOT_ALTEZZA)
        print("pelle riggata: statura", round(alt, 3), "riposo anche", [round(x, 2) for x in adatta[0]])
        for o in base:
            if o.type == "MESH":
                o.name = "Pelle"
                for img in bpy.data.images:
                    if img.size[0] > 2048:
                        img.scale(2048, 2048)
    elif pelle:
        veste_pelle(arm, pelle)
    if arm.animation_data and arm.animation_data.action:
        vecchia = arm.animation_data.action
        arm.animation_data.action = None
        bpy.data.actions.remove(vecchia)
    arm.animation_data_create()
    azioni = []
    for nome in ANIMAZIONI:
        p = os.path.join(cartella, nome + ".fbx")
        if not os.path.exists(p):
            print("manca", nome)
            continue
        nuovi = importa(p)
        a2 = next(o for o in nuovi if o.type == "ARMATURE")
        act = a2.animation_data.action
        act.name = nome
        act.use_fake_user = True
        if nome in TAGLI:
            taglia(act, *TAGLI[nome])
        if nome in FISSE:
            fissa(act)
        else:
            sul_posto(act, nome in CON_DERIVA)
        if adatta:
            adatta_anche(act, *adatta)
        for o in nuovi:
            bpy.data.objects.remove(o, do_unlink=True)
        azioni.append(act)
    # ogni azione su una traccia NLA: l'esportatore glTF le esporta tutte, una per animazione
    for act in azioni:
        tr = arm.animation_data.nla_tracks.new()
        tr.name = act.name
        st = tr.strips.new(act.name, int(act.frame_range[0]), act)
        if hasattr(arm.animation_data, "action_slot") and act.slots:
            try:
                st.action_slot = act.slots[0]
            except Exception:
                pass
        tr.mute = True
    for a in list(bpy.data.actions):
        if a not in azioni:
            bpy.data.actions.remove(a)
    bpy.ops.export_scene.gltf(filepath=uscita, export_format="GLB", export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                              export_optimize_animation_size=True, export_skins=True,
                              export_yup=True, export_apply=False,
                              export_image_format="NONE")  # la texture sta nel jpg accanto
    print("esportato", uscita, len(azioni), "animazioni")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    main(args[0], args[1], args[2] if len(args) > 2 else None, float(args[3]) if len(args) > 3 else None)
