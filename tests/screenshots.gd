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
	main._off_categoria("attributo")
	await _foto("officina_caratteristiche")
	main._off_categoria("magia")
	await _foto("officina_magie")
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
	main._mostra_dettaglio(0, main.m.s["g"][0]["pg"]["token"].keys()[1])
	await _foto("dettaglio")
	main._chiudi_dettaglio()
	var mano: Array = main.m.dadi_di(0, "mano")
	if not mano.is_empty():
		main._dado(mano[0]["id"])
		await _foto("suggerimento")
		main._dado(mano[0]["id"])

	if main.m.chi_decide() == 0 and main.m.s["fase"] == "azione" and not main.m.bersagli_passo(0).is_empty():
		main._cmd_passo()
		await _foto("passo")
		main._cmd_annulla()
	# guardie sull'esagono e scelta del lato
	var pa := {"nome": "Aldra", "token": {"forza": 2, "tempra": 2, "spada": 1, "postura": 1, "scudo": 1}}
	var pb := {"nome": "Brun", "token": {"forza": 2, "tempra": 2, "lama_scudo": 1, "sgambetto": 1, "destrezza": 1}}
	main.battaglia(pa, pb, d["scenari"][0], [false, false])
	await _attendi(5)
	var m: Motore = main.m
	m.s["fase"] = "azione"
	m.s["attivo"] = 0
	m.s["da_pescare"] = []
	m.s["g"][0]["pos"] = Vector2i(-1, 0)
	m.s["g"][0]["dir"] = 0
	m.s["g"][1]["pos"] = Vector2i(0, 0)
	m.s["g"][1]["dir"] = 3
	for p in 2:
		for dd in m.s["g"][p]["dadi"]:
			dd["st"] = "mucchio"
	var vb := -1
	for dd in m.s["g"][1]["dadi"]:
		if dd["col"] == "verde":
			dd["st"] = "token"
			dd["v"] = 5
			vb = dd["id"]
			break
	m.s["g"][1]["occupati"]["lama_scudo/taglia_copri"] = [vb]
	m.s["g"][1]["guardie"]["lama_scudo/taglia_copri"] = {"lato": 0}
	var conta := 0
	for dd in m.s["g"][0]["dadi"]:
		if dd["col"] in ["verde", "rosso"] and conta < 3:
			dd["st"] = "mano"
			dd["v"] = [4, 6, 3][conta]
			conta += 1
	main.arena.sincronizza()
	main._ricostruisci_carte()
	main._aggiorna()
	main._slot("postura", "in_guardia")
	await _attendi(20)
	await _foto("guardia_lato")
	var bl: Array = main.attesa.get("bersagli", [])
	if not bl.is_empty():
		var bb: Dictionary = bl[0].duplicate()
		bb.erase("dir")
		bb.erase("pos")
		main._esegui(0, main._op_attesa(bb))
	await _attendi(1)
	await _foto("dado_in_volo")
	await _attendi(60)
	main._aggiorna()
	await _foto("guardia_attiva")
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
