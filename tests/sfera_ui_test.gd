extends SceneTree
## Gioca un duello dall'interfaccia: il giocatore umano preme sempre il primo bottone utile
## (dadi, azioni, salite, reazioni, pause), l'IA risponde. Nessun errore e il duello finisce.

var main: Node

func _init() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_giro.call_deferred()

func _bottoni() -> Array:
	var out := []
	for c in main._sf_scelte.get_children():
		if c is Button and not c.is_queued_for_deletion() and not c.disabled:
			out.append(c)
	return out

func _giro() -> void:
	for i in 10:
		await process_frame
	var sf: Dictionary = main.sf
	main.sf_battaglia(sf["personaggi"][2].duplicate(true), sf["personaggi"][0].duplicate(true), "rovine", [false, true])
	Engine.time_scale = 10.0
	var gen := RandomNumberGenerator.new()
	gen.seed = 4
	var mosse := 0
	var esagoni := 0
	var reazioni := 0
	for k in 20000:
		await process_frame
		var ms: Sfera = main.ms
		if ms == null or ms.s["vinc"] >= 0:
			break
		if main.arena.occupato() or main._sf_umano() != 0:
			continue
		var fase := String(ms.s["fase"])
		var bs := _bottoni()
		if fase == "azione" and main._sf_sel.is_empty():
			var g: Dictionary = ms.s["g"][0]
			if not g["mano"].is_empty() and gen.randf() < 0.8:
				main._sf_premuto({"tipo": "dado", "id": g["mano"][gen.randi() % g["mano"].size()]["id"]})
			elif not g["fermi"].is_empty():
				main._sf_premuto({"tipo": "fermo", "j": 0})
			elif not bs.is_empty():
				bs[0].pressed.emit()
			else:
				main._sf_esegui({"t": "passa"})
			mosse += 1
			continue
		if not main._sf_esagoni.is_empty() and gen.randf() < 0.5:
			main._sf_esagono(main._sf_esagoni["hex"][0])
			esagoni += 1
			continue
		if fase == "reazione":
			reazioni += 1
		bs = _bottoni()
		if bs.is_empty():
			main._sf_azzera()
			main._sf_aggiorna()
			# un dado fermo che non può salire da nessuna parte: si passa, come col bottone in basso
			if fase == "azione" and ms.s["g"][0]["mano"].is_empty():
				main._sf_esegui({"t": "passa"})
			continue
		# evita "Annulla" se c'è altro
		var scelta: Button = bs[gen.randi() % bs.size()]
		if scelta.text == "Annulla" and bs.size() > 1:
			scelta = bs[0]
		if scelta.text == "Annulla" and fase == "azione" and ms.s["g"][0]["mano"].is_empty():
			# il dado fermo non ha dove salire: si passa
			main._sf_esegui({"t": "passa"})
			continue
		scelta.pressed.emit()
	Engine.time_scale = 1.0
	var ms2: Sfera = main.ms
	print("mosse %d  esagoni %d  reazioni %d  scambio %d  vincitore %d" % [mosse, esagoni, reazioni, ms2.s["scambio"], ms2.s["vinc"]])
	var ok: bool = ms2.s["vinc"] >= 0 and mosse > 5
	print("OK" if ok else "ERRORE")
	quit(0 if ok else 1)
