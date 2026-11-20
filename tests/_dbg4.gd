extends SceneTree
func _init():
	var dati := Motore.carica_dati()
	Motore.regole["vita"] = 14
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var casi := {"vinto_da_chi_non_attacca": 0, "mai_vicino": 0, "vicino_ma_niente": 0, "tot": 0}
	var esempi := []
	for i in 60:
		var a: Dictionary = Generatore.casuale(dati, [30,45,60][i%3], rng)
		var b: Dictionary = Generatore.casuale(dati, [30,45,60][i%3], rng)
		var m := Motore.new(dati)
		m.nuova_partita(a, b, "rovine", i)
		var att := [0, 0]
		var dmin := [99, 99]
		var passi := 0
		while m.s["vinc"] < 0 and passi < 3000:
			var chi := m.chi_decide()
			var op := IA.scegli(m, chi, rng)
			if op["t"] == "slot" and m.slot_def(op["tok"], op["slot"])["effetto"] in ["attacco","assalto"]:
				att[chi] += 1
			m.applica(chi, op)
			var d := Motore.dist(m.s["g"][0]["pos"], m.s["g"][1]["pos"])
			dmin[0] = mini(dmin[0], d)
			passi += 1
		for p in 2:
			if att[p] == 0:
				casi["tot"] += 1
				if m.s["vinc"] == p: casi["vinto_da_chi_non_attacca"] += 1
				if dmin[0] > 1: casi["mai_vicino"] += 1
				else:
					casi["vicino_ma_niente"] += 1
					if esempi.size() < 3: esempi.append([m.s["round"], [a,b][p]["token"]])
	print(casi)
	for e in esempi: print(e)
	quit()
