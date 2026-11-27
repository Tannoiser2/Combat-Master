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
		if fase == "reazione":
			reazioni += 1
		if not main._sf_esagoni.is_empty() and gen.randf() < 0.5:
			main._sf_esagono(main._sf_esagoni["hex"][0])
			esagoni += 1
			continue
		var bs := _bottoni()
		var v = main._sf_vista
		# i posti illuminati sulla sfera, come li toccherebbe il giocatore
		var tocchi := []
		for id in v.evid_dadi:
			tocchi.append({"tipo": "dado", "id": id})
		for az in v.evid_azioni:
			tocchi.append({"tipo": "azione", "az": az})
		for ti in v.evid_token:
			tocchi.append({"tipo": "token", "i": ti})
		for j2 in v.evid_fermi:
			tocchi.append({"tipo": "fermo", "j": j2})
		if v.evid_attesa and gen.randf() < 0.1:
			tocchi.append({"tipo": "attesa", "posto": "rosso"})
		if not bs.is_empty() and (tocchi.is_empty() or gen.randf() < 0.6):
			var scelta: Button = bs[gen.randi() % bs.size()]
			if scelta.text == "Nessuna reazione" and bs.size() > 1 and gen.randf() < 0.7:
				scelta = bs[0]
			scelta.pressed.emit()
			mosse += 1
			continue
		if not tocchi.is_empty():
			main._sf_premuto(tocchi[gen.randi() % tocchi.size()])
			continue
		if fase == "azione":
			main._sf_esegui({"t": "passa"})
		else:
			main._sf_azzera()
			main._sf_aggiorna()
	Engine.time_scale = 1.0
	var ms2: Sfera = main.ms
	print("mosse %d  esagoni %d  reazioni %d  scambio %d  vincitore %d" % [mosse, esagoni, reazioni, ms2.s["scambio"], ms2.s["vinc"]])
	var ok: bool = ms2.s["vinc"] >= 0 and mosse > 5
	print("OK" if ok else "ERRORE")
	quit(0 if ok else 1)
