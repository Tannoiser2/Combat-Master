extends SceneTree
## Controlla i movimenti dell'arena fotogramma per fotogramma, in duelli IA contro IA con i modelli animati.
## Segnala: figure sovrapposte, corpi che si compenetrano, anche che scivolano via dalla figura,
## salti di posizione (teletrasporti), rotazioni di colpo, e chi a riposo non guarda l'avversario.
## uso: godot --headless --path . --script tests/arena_movimenti.gd -- duelli=3 seme=1 velocita=4

var main: Node
var arg := {"duelli": "3", "seme": "1", "velocita": "4", "pg": ""}
var conta := {}
var esempi := {}
var d1 := 1.0

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			arg[kv[0]] = kv[1]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_giro.call_deferred()

func _segnala(tipo: String, dett: String) -> void:
	conta[tipo] = int(conta.get(tipo, 0)) + 1
	if not esempi.has(tipo):
		esempi[tipo] = []
	if esempi[tipo].size() < 6:
		esempi[tipo].append(dett)

func _anche(f: Node3D) -> Vector3:
	var sk: Skeleton3D = null
	for n in f.find_children("*", "Skeleton3D", true, false):
		sk = n
		break
	if sk == null:
		return f.global_position
	var b := sk.find_bone("mixamorig_Hips")
	if b < 0:
		b = 0
	return sk.global_transform * sk.get_bone_global_pose(b).origin

func get_process_frame_delta_time_safe() -> float:
	return root.get_process_delta_time() * Engine.time_scale

func _clip(i: int) -> String:
	var ap: AnimationPlayer = main.arena._ap(i)
	return String(ap.current_animation) if ap != null else ""

func _giro() -> void:
	for k in 10:
		await process_frame
	var sf: Dictionary = main.sf
	var rng := RandomNumberGenerator.new()
	rng.seed = int(arg["seme"])
	Engine.time_scale = float(arg["velocita"])
	d1 = (main.arena.mondo(Vector2i(0, 0)) - main.arena.mondo(Vector2i(1, 0))).length()
	var fotogrammi := 0
	for duello in int(arg["duelli"]):
		var n: int = sf["personaggi"].size()
		var a := rng.randi() % n
		var b := (a + 1 + rng.randi() % (n - 1)) % n
		var arene := ["cortile", "rovine", "fossa"]
		main.sf_battaglia(sf["personaggi"][a].duplicate(true), sf["personaggi"][b].duplicate(true), arene[duello % 3], [true, true])
		var prec := [null, null]
		var prec_r := [0.0, 0.0]
		var fermi := 0
		for fr in 30000:
			await process_frame
			fotogrammi += 1
			var ms = main.ms
			var ar = main.arena
			var f0: Node3D = ar.figure[0]
			var f1: Node3D = ar.figure[1]
			var c0 := _clip(0)
			var c1 := _clip(1)
			var ue: Dictionary = ar.ultimo_evento
			var ctx := "scambio %d  ev %s p%s%s  clip %s / %s" % [ms.s["scambio"], ue.get("t", ""), ue.get("p", ""), (" salta" if ue.get("salta", false) else "") + (" lancia" if ue.get("lancia", false) else ""), c0, c1]
			var dd := Vector2(f0.position.x - f1.position.x, f0.position.z - f1.position.z).length()
			if dd < 0.5 * d1:
				_segnala("figure sovrapposte", "%s  dist %.2f" % [ctx, dd / d1])
			var h0 := _anche(f0)
			var h1 := _anche(f1)
			var dh := Vector2(h0.x - h1.x, h0.z - h1.z).length()
			if dh < 0.28 * d1 and absf(h0.y - h1.y) < 0.6:
				_segnala("corpi compenetrati", "%s  anche a %.2f, figure a %.2f" % [ctx, dh / d1, dd / d1])
			for i in 2:
				var f: Node3D = ar.figure[i]
				var h := h0 if i == 0 else h1
				var c := c0 if i == 0 else c1
				var der := Vector2(h.x - f.position.x, h.z - f.position.z).length()
				# nei passi, nelle difese e da fermi le anche restano sopra la figura (gli attacchi possono affondare)
				if der > 0.3 * d1 and (c.begins_with("passo") or c in ["idle", "riposo", "respiro", "parata", "parata_forte", "blocco_alto", "blocco_interno", "schivata", "schiva_destra", "schiva_indietro", "scarto", "colpito_corpo", "colpito_testa", "gira_destra", "gira_sinistra", "provoca", "urlo"]):
					_segnala("anche lontane dalla figura (scivola)", "p%d %s  deriva %.2f" % [i, ctx, der / d1])
				if prec[i] != null:
					var salto := Vector2(f.position.x - prec[i].x, f.position.z - prec[i].z).length()
					var dtg := maxf(0.001, get_process_frame_delta_time_safe())
					if salto / dtg > 9.0 * d1:
						_segnala("teletrasporto", "p%d %s  %.2f esagoni in un fotogramma" % [i, ctx, salto / d1])
					var dr := absf(wrapf(f.rotation.y - prec_r[i], -PI, PI))
					if dr / dtg > deg_to_rad(1000) and dr > deg_to_rad(25):
						_segnala("rotazione di colpo", "p%d %s  %d gradi in %.2f s" % [i, ctx, int(rad_to_deg(dr)), dtg])
				prec[i] = f.position
				prec_r[i] = f.rotation.y
			# a riposo: guardarsi
			if not ar.occupato():
				fermi += 1
				if fermi == 20:
					for i in 2:
						var f: Node3D = ar.figure[i]
						var o: Node3D = ar.figure[1 - i]
						var v := o.position - f.position
						v.y = 0
						var avanti := Vector3(-sin(f.rotation.y), 0, -cos(f.rotation.y))
						var ang := rad_to_deg(avanti.angle_to(v.normalized()))
						if ang > 35 and int(ms.s["g"][i]["vita"]) > 0 and not ms.a_terra(i):
							_segnala("a riposo non guarda l'avversario", "p%d scambio %d  %d gradi, distanza %.1f" % [i, ms.s["scambio"], int(ang), v.length() / d1])
						var giusta: Vector3 = ar.posizione(ms.s["g"][i]["pos"])
						if Vector2(giusta.x - f.position.x, giusta.z - f.position.z).length() > 0.1:
							_segnala("a riposo fuori dal suo esagono", "p%d scambio %d" % [i, ms.s["scambio"]])
			else:
				fermi = 0
			if ms.s["vinc"] >= 0 and not ar.occupato():
				break
		print("duello %d finito: %d scambi" % [duello, main.ms.s["scambio"]])
	print("fotogrammi %d" % fotogrammi)
	for t in conta:
		print("%-40s %d" % [t, conta[t]])
		for e in esempi[t]:
			print("      ", e)
	if conta.is_empty():
		print("OK: nessun movimento sbagliato")
	quit()
