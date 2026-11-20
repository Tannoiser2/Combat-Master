extends SceneTree
func _init():
	var dati := Motore.carica_dati()
	Motore.regole["vita"] = 14
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var a: Dictionary = {}
	var b: Dictionary = {}
	for i in 2:
		a = Generatore.casuale(dati, 30, rng)
		b = Generatore.casuale(dati, 30, rng)
	var m := Motore.new(dati)
	m.nuova_partita(a, b, "cortile", 1)
	var passi := 0
	while m.s["vinc"] < 0 and passi < 40:
		var chi := m.chi_decide()
		if m.s["fase"] == "azione" and chi == 0:
			var w := IA.pesi()
			var righe := []
			for op in IA._sfoltisci(m, chi, m.opzioni(chi), w):
				righe.append([IA.valuta_opzione(m, chi, op, w), op["t"], op.get("slot", ""), op.get("b", {})])
			righe.sort_custom(func(x, y): return x[0] > y[0])
			for r in righe.slice(0, 8): print("   ", r)
			print("mano: ", m.dadi_di(chi, "mano").map(func(d): return d["col"] + str(d["v"])), " pos ", m.s["g"][chi]["pos"], " nemico ", m.s["g"][1-chi]["pos"])
		var op := IA.scegli(m, chi, rng)
		print(m.s["g"][chi]["nome"], " -> ", op["t"], " ", op.get("slot",""))
		m.applica(chi, op)
		passi += 1
	quit()
