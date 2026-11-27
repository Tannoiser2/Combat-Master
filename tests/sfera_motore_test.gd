extends SceneTree
## Prova del motore della sfera: duelli IA contro IA sulle tre arene, senza errori e con numeri sensati.

func _init() -> void:
	var dati := Motore.carica_dati()
	var sf := Sfera.carica_sfera()
	var n := 120
	var vinti := [0, 0]
	var pari := 0
	var scambi := 0
	var arene := ["cortile", "rovine", "fossa"]
	var gen := RandomNumberGenerator.new()
	gen.seed = 7
	var t0 := Time.get_ticks_msec()
	var sovrapposti := 0
	var teletrasporti := 0
	var fuori_posto := 0
	var mosse_viste := 0
	for i in n:
		var m := Sfera.new(dati, sf)
		var a: Dictionary = sf["personaggi"][i % sf["personaggi"].size()] if i % 2 == 0 else m.casuale(gen, "A")
		var b: Dictionary = m.casuale(gen, "B")
		m.nuova_sfera(a, b, arene[i % 3], [false, false], 1000 + i)
		var pos := [m.s["g"][0]["pos"], m.s["g"][1]["pos"]]
		var v := m.gioca_da_sola()
		# movimenti coerenti: mai sulla casella dell'avversario, e ogni passo è adiacente al precedente
		for e in m.prendi_eventi():
			if e["t"] == "muovi" or e["t"] == "spinto":
				mosse_viste += 1
			if e["t"] != "muovi" and e["t"] != "spinto":
				continue
			var q := int(e["p"])
			var da: Vector2i = pos[q]
			for k in e["percorso"].size():
				var h := Vector2i(e["percorso"][k].x, e["percorso"][k].y)
				if k == e["percorso"].size() - 1 and h == pos[1 - q]:
					sovrapposti += 1
				if not e.get("salta", false) and not e.get("lancia", false) and h != da and m.dist(da, h) > 1:
					teletrasporti += 1
				da = h
			pos[q] = da
		if pos[0] != m.s["g"][0]["pos"] or pos[1] != m.s["g"][1]["pos"]:
			fuori_posto += 1
		scambi += int(m.s["scambio"])
		if v < 0:
			pari += 1
		else:
			vinti[v] += 1
	var ms := Time.get_ticks_msec() - t0
	print("duelli %d  vinti %s  pari %d  scambi medi %.2f  ms %d" % [n, vinti, pari, float(scambi) / n, ms])
	print("movimenti: sulla casella avversaria %d, salti di casella %d, figure fuori posto %d (su %d movimenti)" % [sovrapposti, teletrasporti, fuori_posto, mosse_viste])
	var ok := mosse_viste > 300 and sovrapposti == 0 and teletrasporti == 0 and fuori_posto == 0 and pari < n * 0.1 and float(scambi) / n > 5.0 and float(scambi) / n < 60.0
	# un umano che reagisce: il motore si ferma e riparte
	var m2 := Sfera.new(dati, sf)
	m2.nuova_sfera(sf["personaggi"][1], sf["personaggi"][0], "cortile", [false, true], 3)
	var fermi := 0
	for k in 3000:
		if m2.s["vinc"] >= 0:
			break
		var chi := m2.chi_decide()
		if m2.s["fase"] == "reazione":
			fermi += 1
			var opz: Array = m2.opzioni_reazione(chi)
			m2.reagisci(chi, opz[0] if not opz.is_empty() else {"t": "nessuna"})
		elif m2.s["fase"] == "pausa":
			m2.piazza(chi, m2.token_disponibili(chi))
		else:
			if m2.esegui(chi, m2.ia_scegli(chi)) != "":
				m2.esegui(chi, {"t": "passa"})
	print("reazioni umane chieste: %d, vincitore %d" % [fermi, m2.s["vinc"]])
	ok = ok and fermi > 0 and m2.s["vinc"] >= 0
	print("OK" if ok else "ERRORE")
	quit(0 if ok else 1)
