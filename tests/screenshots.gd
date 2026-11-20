extends SceneTree
## Cattura le schermate principali per controllarle a occhio.
## uso: xvfb-run godot --path . --resolution 1180x820 --script tests/screenshots.gd -- out=/tmp/shots/ipad

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
	main._off_categoria("segreto")
	await _foto("officina_segreti")
	main.preparazione("spettatore")
	await _foto("preparazione")
	var d: Dictionary = main.dati
	# partita contro l'IA: si comincia scegliendo i dadi dal mucchio
	main.battaglia(d["personaggi"][0].duplicate(true), d["personaggi"][2].duplicate(true), d["scenari"][0], [false, true])
	for i in 200:
		await process_frame
		if main.m.chi_decide() == 0:
			break
	main._aggiorna()
	await _foto("pesca")
	main._cmd_consigliata()
	await _foto("pesca_scelta")
	main._cmd_conferma()
	# lascia giocare l'IA per entrambi fino al secondo scambio
	main.ia = [true, true]
	for i in 600:
		await process_frame
		if main.m.s["round"] >= 2 and main.m.s["fase"] == "azione" and main.m.chi_decide() == 0 and not main.arena.occupato():
			break
	main.ia = [false, true]
	main._aggiorna()
	await _foto("battaglia")
	main._cmd_scheda()
	await _foto("scheda_avversario")
	main._cmd_scheda()
	if main.m.chi_decide() == 0 and main.m.s["fase"] == "azione" and not main.m.bersagli_passo(0).is_empty():
		main._cmd_passo()
		await _foto("passo")
		main._cmd_annulla()
	# modalità spettatore veloce
	main.battaglia(Generatore.casuale(d, 45, main.rng), Generatore.casuale(d, 45, main.rng), d["scenari"][1], [true, true])
	main.passo_ia = 0.05
	for i in 900:
		await process_frame
		if main.m.s["vinc"] >= 0 and not main.arena.occupato():
			break
	await _attendi(30)
	await _foto("spettatore")
	quit()
