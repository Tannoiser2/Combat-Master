extends SceneTree
func _init():
	var dati := Motore.carica_dati()
	IA.profondita = 1
	var rng := RandomNumberGenerator.new(); rng.seed = 12
	for i in 120:
		var budget: int = [30,45,60][i%3]
		var a: Dictionary = Generatore.casuale(dati, budget, rng)
		var b: Dictionary = Generatore.casuale(dati, budget, rng)
		var m := Motore.new(dati)
		m.nuova_partita(a, b, ["cortile","rovine","fossa"][i%3], i)
		var passi := 0
		while m.s["vinc"] < 0 and passi < 4000:
			var chi := m.chi_decide()
			m.applica(chi, IA.scegli(m, chi, rng))
			passi += 1
		if m.s["round"] >= 30:
			print("=== ", i, " vita ", m.s["g"][0]["vita"], "/", m.s["g"][0]["vita_max"], " ", m.s["g"][1]["vita"], "/", m.s["g"][1]["vita_max"])
			print(a["token"]); print(b["token"])
			var L: Array = m.s["log"]
			print("\n".join(L.slice(L.size() - 30)))
			break
	quit()
