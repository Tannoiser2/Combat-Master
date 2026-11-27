extends SceneTree
## Diagnosi rapida: che cosa ferisce, quanti token scattano per anello, quanto spesso si arriva all'esterno.

func _init() -> void:
	var dati := Motore.carica_dati()
	var sf := Sfera.carica_sfera()
	var gen := RandomNumberGenerator.new()
	gen.seed = 11
	var n := 200
	var cont := {}
	var scambi := 0
	for i in n:
		var m := Sfera.new(dati, sf)
		var a: Dictionary = m.casuale(gen, "A")
		var b: Dictionary = m.casuale(gen, "B")
		m.nuova_sfera(a, b, ["cortile", "rovine", "fossa"][i % 3], [false, false], 500 + i)
		m.gioca_da_sola()
		scambi += int(m.s["scambio"])
		var ultimo := "?"
		for riga in m.s["log"]:
			var r: String = String(riga)
			if " subisce " in r:
				var nn := int(r.split(" subisce ")[1].split(" ")[0])
				cont["D " + ultimo] = int(cont.get("D " + ultimo, 0)) + nn
				cont["D TOTALE"] = int(cont.get("D TOTALE", 0)) + nn
			elif r.ends_with("!") or r.ends_with("."):
				ultimo = r.left(48)
			for chiave in ["sale nell'anello esterno", "potenziat", "Scatta la trappola", "mette in campo", "guardia di", "6: ", "assorbe"]:
				if chiave in r:
					cont[chiave] = int(cont.get(chiave, 0)) + 1
			if r.ends_with("!") and ": " in r:
				var nome := r.split(": ")[1].trim_suffix("!").trim_suffix(" potenziato")
				cont["T " + nome] = int(cont.get("T " + nome, 0)) + 1
	print("scambi medi %.2f" % (float(scambi) / n))
	var k := cont.keys()
	k.sort_custom(func(a, b): return cont[a] > cont[b])
	for x in k.slice(0, 45):
		print("%5d  %s" % [cont[x], x])
	quit()
