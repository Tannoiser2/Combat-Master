extends SceneTree
## Cattura le schermate principali per controllarle a occhio.
## uso: xvfb-run godot --path . --resolution 1366x1024 --script tests/screenshots.gd -- out=/tmp/shots/ipad

var out := "/tmp/shots/x"
var main: Node

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_giro.call_deferred()

func _attendi(n: int) -> void:
	for i in n:
		await process_frame

func _foto(nome: String) -> void:
	await _attendi(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s_%s.png" % [out, nome])
	print("foto ", nome)

func _giro() -> void:
	await _attendi(10)
	await _foto("menu")
	main.officina()
	main._off_carica_in_editor(main.dati["personaggi"][7])
	await _foto("officina")
	main.preparazione("ia")
	await _foto("preparazione")
	var d: Dictionary = main.dati
	main.battaglia(d["personaggi"][0].duplicate(true), d["personaggi"][1].duplicate(true), d["scenari"][1], [false, true])
	await _attendi(30)
	await _foto("battaglia")
	# fai giocare l'IA per entrambi un po'
	main.ia = [true, true]
	for i in 400:
		await process_frame
		if main.m.s["round"] >= 2 and main.m.chi_decide() == 0 and not main.arena.occupato():
			break
	main.ia = [false, true]
	main._aggiorna()
	await _foto("battaglia2")
	# selezione di un movimento: forza l'iniziativa al giocatore 1
	main.battaglia(d["personaggi"][0].duplicate(true), d["personaggi"][2].duplicate(true), d["scenari"][0], [false, false])
	await _attendi(20)
	main.m.s["attivo"] = 0
	main.m.s["fase"] = "azione"
	for dd in main.m.s["g"][0]["dadi"]:
		if dd["col"] == "blu":
			dd["v"] = 4
	main._aggiorna()
	main._slot("agilita", "muovi")
	await _foto("movimento")
	var g: Dictionary = main.m.s["g"][0]
	var dest: Vector2i = g["pos"] + Motore.DIRS[0] + Motore.DIRS[0]
	main._esagono(dest, Arena3D.mondo(dest))
	await _foto("direzioni")
	main._cmd_annulla()
	# spazi occupati e scelta di quelli da liberare passando
	var m: Motore = main.m
	var g0: Dictionary = m.s["g"][0]
	var occ := 0
	for dd in g0["dadi"]:
		if dd["st"] == "mano" and occ < 3:
			var k: String = ["spada/fendente", "agilita/muovi", "forza/pugno"][occ]
			dd["st"] = "token"
			g0["occupati"][k] = [dd["id"]]
			occ += 1
	main._aggiorna()
	main._cmd_passa()
	main._slot("spada", "fendente")
	await _foto("libera")
	quit()
