extends SceneTree
## Allenamento dell'IA giocando contro sé stessa: si prova una variante dei pesi della
## valutazione, la si fa combattere contro i pesi attuali con avventurieri casuali (ogni
## coppia due volte, a lati invertiti) e la si tiene se vince abbastanza.
## Raccoglie anche i difetti trovati: opzioni rifiutate, partite bloccate, colpi senza effetto.
## uso: godot --headless --path . --script tests/allena_ia.gd -- generazioni=20 partite=30

var dati: Dictionary
var rng := RandomNumberGenerator.new()
var difetti := {"rifiutate": [], "a_tempo": 0, "partite": 0}

func _init() -> void:
	var arg := {"generazioni": "15", "partite": "30", "seme": "5", "soglia": "0.56"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			arg[kv[0]] = kv[1]
	dati = Motore.carica_dati()
	rng.seed = int(arg["seme"])
	var w: Dictionary = IA.pesi().duplicate()
	var storia := []
	var vecchio := _carica_storia()
	for gen in int(arg["generazioni"]):
		var cand := _muta(w)
		var punti := _sfida(cand, w, int(arg["partite"]))
		var accettata := punti >= float(arg["soglia"])
		print("Generazione %d: la variante vince il %.0f%%%s" % [gen + 1, punti * 100, " -> ADOTTATA" if accettata else ""])
		if accettata:
			var diff := {}
			for k in w:
				if absf(cand[k] - w[k]) > 0.001:
					diff[k] = [snappedf(w[k], 0.01), snappedf(cand[k], 0.01)]
			storia.append({"punti": snappedf(punti, 0.01), "cambi": diff})
			w = cand
	var out := {"pesi": {}, "generazioni": int(vecchio.get("generazioni", 0)) + int(arg["generazioni"]),
		"adottate": vecchio.get("adottate", []) + storia}
	for k in w:
		out["pesi"][k] = snappedf(w[k], 0.001)
	FileAccess.open("res://data/ia_pesi.json", FileAccess.WRITE).store_string(JSON.stringify(out, " "))
	print("Pesi salvati. Varianti adottate in questo giro: %d" % storia.size())
	var t := "# Allenamento dell'IA\n\n"
	t += "L'IA prova varianti dei pesi della sua valutazione e le fa combattere contro i pesi in uso, con avventurieri casuali e ogni coppia giocata due volte a lati invertiti. Una variante è adottata se vince almeno il %.0f%% delle partite.\n\n" % (float(arg["soglia"]) * 100)
	t += "- Generazioni totali: %d (questo giro: %s, %s partite ciascuna)\n" % [out["generazioni"], arg["generazioni"], arg["partite"]]
	t += "- Varianti adottate in questo giro: %d\n" % storia.size()
	t += "- Partite al limite di tempo: %d su %d\n- Opzioni rifiutate dal motore: %d\n\n" % [difetti["a_tempo"], difetti["partite"], difetti["rifiutate"].size()]
	t += "## Pesi attuali\n\n| Peso | Valore | Valore iniziale |\n| --- | --- | --- |\n"
	for k in out["pesi"]:
		t += "| %s | %.2f | %.2f |\n" % [k, out["pesi"][k], IA.PESI_BASE[k]]
	if not storia.is_empty():
		t += "\n## Varianti adottate\n\n"
		for x in storia:
			t += "- vince il %.0f%%: %s\n" % [x["punti"] * 100, str(x["cambi"])]
	FileAccess.open("res://docs/allenamento_ia.md", FileAccess.WRITE).store_string(t)
	print("Difetti: %d opzioni rifiutate, %d partite al limite di tempo su %d" % [difetti["rifiutate"].size(), difetti["a_tempo"], difetti["partite"]])
	for r in difetti["rifiutate"].slice(0, 10):
		print("  ", r)
	quit()

func _carica_storia() -> Dictionary:
	if FileAccess.file_exists("res://data/ia_pesi.json"):
		var d = JSON.parse_string(FileAccess.open("res://data/ia_pesi.json", FileAccess.READ).get_as_text())
		if d is Dictionary:
			return d
	return {}

func _muta(w: Dictionary) -> Dictionary:
	var c := w.duplicate()
	var chiavi: Array = c.keys()
	for i in rng.randi_range(2, 5):
		var k: String = chiavi[rng.randi() % chiavi.size()]
		c[k] = maxf(0.01, c[k] * exp(rng.randfn(0.0, 0.3)))
	return c

## Percentuale di vittorie della variante `a` contro `b`.
func _sfida(a: Dictionary, b: Dictionary, n: int) -> float:
	var vinte := 0.0
	var giocate := 0
	for i in n / 2:
		var budget: int = [30, 45, 60][rng.randi() % 3]
		var pa: Dictionary = Generatore.casuale(dati, budget, rng)
		var pb: Dictionary = Generatore.casuale(dati, budget, rng)
		var arena: String = ["cortile", "rovine", "fossa"][rng.randi() % 3]
		var seme := rng.randi()
		for lato in 2:
			var pesi := [a, b] if lato == 0 else [b, a]
			var m := Motore.new(dati)
			m.nuova_partita(pa, pb, arena, seme)
			var passi := 0
			var r2 := RandomNumberGenerator.new()
			r2.seed = seme
			while m.s["vinc"] < 0 and passi < 4000:
				var chi := m.chi_decide()
				var op := IA.scegli(m, chi, r2, pesi[chi])
				if op.is_empty():
					break
				var e := m.applica(chi, op)
				if e != "":
					difetti["rifiutate"].append("%s: %s" % [e, op])
					break
				passi += 1
			difetti["partite"] += 1
			if int(m.s["round"]) >= Motore.ROUND_MAX:
				difetti["a_tempo"] += 1
			var vincitore := int(m.s["vinc"])
			var lato_a := 0 if lato == 0 else 1
			if vincitore == lato_a:
				vinte += 1.0
			giocate += 1
	return vinte / maxi(1, giocate)
