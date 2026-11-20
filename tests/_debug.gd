extends SceneTree
func _init():
	var dati := Motore.carica_dati()
	Motore.regole["vita"] = 14
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var trovati := 0
	for i in 40:
		var a: Dictionary = Generatore.casuale(dati, 30, rng)
		var b: Dictionary = Generatore.casuale(dati, 30, rng)
		var m := Motore.new(dati)
		m.nuova_partita(a, b, "cortile", i)
		var att := [0, 0]
		var passi := 0
		while m.s["vinc"] < 0 and passi < 3000:
			var chi := m.chi_decide()
			var op := IA.scegli(m, chi, rng)
			if op["t"] == "slot" and m.slot_def(op["tok"], op["slot"])["effetto"] in ["attacco","assalto"]:
				att[chi] += 1
			m.applica(chi, op)
			passi += 1
		if att[0] == 0 or att[1] == 0:
			trovati += 1
			print("=== partita ", i, " scambi ", m.s["round"], " attacchi ", att, " vince ", m.s["vinc"])
			print(a["token"]); print(b["token"])
			print("\n".join(m.s["log"].slice(0, 28)))
			if trovati >= 3: break
	quit()
