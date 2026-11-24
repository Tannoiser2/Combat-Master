"""Unisce il manichino Mixamo (Y Bot) e le sue animazioni in un solo GLB per Godot.

Le animazioni restano "sul posto": il gioco sposta la figura da un esagono all'altro,
quindi dalle anche si toglie lo spostamento orizzontale complessivo di ogni clip
(resta l'oscillazione, sparisce la deriva).

Uso (Blender come modulo Python, oppure dentro Blender):
    python3 tools/mixamo_a_glb.py CARTELLA_FBX USCITA.glb
I file FBX di Mixamo non vanno nel repository: la licenza permette di usarli nel gioco,
non di ridistribuirli da soli.
"""
import os
import sys

import bpy

ANIMAZIONI = ["idle", "jab", "cross", "montante", "calcio", "parata", "schivata",
              "passo_avanti", "passo_indietro", "passo_sinistra", "passo_destra",
              "gira_sinistra", "gira_destra", "colpito_testa", "colpito_corpo",
              "ko", "rialzata", "proiezione", "proiettato", "vittoria", "sconfitta"]
# clip che si ripetono in loop in Godot
CICLICHE = {"idle"}


def importa(path):
    prima = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False, ignore_leaf_bones=True)
    return [o for o in bpy.data.objects if o not in prima]


def sul_posto(action):
    """Toglie alle anche la deriva orizzontale: valore - retta tra primo e ultimo fotogramma."""
    for fc in _fcurves(action):
        if fc.data_path.endswith('location') and 'Hips' in fc.data_path and fc.array_index in (0, 2):
            kp = fc.keyframe_points
            if len(kp) < 2:
                continue
            x0, y0 = kp[0].co
            x1, y1 = kp[-1].co
            for k in kp:
                t = 0.0 if x1 == x0 else (k.co[0] - x0) / (x1 - x0)
                d = y0 + (y1 - y0) * t - y0
                k.co[1] -= d
                k.handle_left[1] -= d
                k.handle_right[1] -= d
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


def main(cartella, uscita):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    base = importa(os.path.join(cartella, "ybot.fbx"))
    arm = next(o for o in base if o.type == "ARMATURE")
    arm.name = "Combattente"
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
        sul_posto(act)
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
                              export_yup=True, export_apply=False)
    print("esportato", uscita, len(azioni), "animazioni")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    main(args[0], args[1])
