class_name Generatore
extends RefCounted
## Crea avventurieri casuali entro un budget: prima i token che producono dadi,
## poi di preferenza quelli che consumano i colori prodotti. Serve al banco di
## bilanciamento, all'allenamento dell'IA e alla modalità spettatore.

const NOMI := ["Aldric", "Brenna", "Corvo", "Dalia", "Edda", "Falco", "Greta", "Ilvo", "Jora", "Kael",
	"Lirio", "Mara", "Nerio", "Orsa", "Pietra", "Rovo", "Selva", "Teo", "Ulma", "Vesna", "Zaira", "Bruno",
	"Cira", "Dario", "Elsa", "Furio", "Gilda", "Ivo", "Lupa", "Mirto"]
const EPITETI := ["il Rosso", "Mano Lesta", "l'Implacabile", "dei Monti", "la Silente", "Occhio di Falco",
	"il Paziente", "Spaccascudi", "l'Errante", "dalle Sette Lame", "la Rapida", "il Saggio", "Pugno di Ferro",
	"la Volpe", "il Folle", "dell'Ombra", "Cuore Saldo", "la Tempesta"]

static func colori_prodotti(cat: Dictionary, pg: Dictionary) -> Dictionary:
	return Motore.statistiche(cat, pg)["dadi"]

static func _usabile(sl: Dictionary, prodotti: Dictionary) -> bool:
	if prodotti.has("bianco"):
		return true
	for req in sl["dadi"]:
		var ok := false
		for c in req:
			if prodotti.has(c):
				ok = true
		if not ok:
			return false
	return true

## Il personaggio ha almeno un attacco e un modo per raggiungere il nemico (o un attacco a distanza)?
static func valido(cat: Dictionary, pg: Dictionary) -> bool:
	var st := Motore.statistiche(cat, pg)
	var n := 0
	for c in st["dadi"]:
		n += int(st["dadi"][c])
	if n < 4:
		return false
	var attacco := false
	var distanza := false
	var moto := false
	for id in pg["token"]:
		for sl in cat[id]["slot"]:
			if not _usabile(sl, st["dadi"]):
				continue
			var semplice: bool = sl["dadi"].size() <= 2 and not sl["cond"].has("valori") and not sl["cond"].has("somma_esatta") and not sl.get("esecuzione", false) and not sl.get("elimina_dado", false)
			if sl["effetto"] in ["attacco", "assalto"] and sl["tipo"] == "azione" and semplice:
				attacco = true
				if int(sl.get("portata", 1)) >= 3:
					distanza = true
			if sl["effetto"] in ["movimento", "assalto", "passo_ombra"]:
				moto = true
	return attacco  # il passo base permette sempre di avvicinarsi

static func casuale(dati: Dictionary, budget: int, rng: RandomNumberGenerator) -> Dictionary:
	var cat: Dictionary = dati["per_id"]
	for tentativo in 60:
		var pg := {"nome": "%s %s" % [NOMI[rng.randi() % NOMI.size()], EPITETI[rng.randi() % EPITETI.size()]],
			"budget": budget, "token": {}}
		var guardie := 0
		while guardie < 300:
			guardie += 1
			var resto := budget - Motore.costo_personaggio(cat, pg)
			if resto < 3:
				break
			var prodotti := colori_prodotti(cat, pg)
			var ndadi := 0
			for c in prodotti:
				ndadi += int(prodotti[c])
			var t: Dictionary = dati["token"][rng.randi() % dati["token"].size()]
			var id: String = t["id"]
			if pg["token"].has(id):
				# per le caratteristiche si può salire di livello
				if t.has("livelli") and int(pg["token"][id]) < t["livelli"].size():
					var extra := Motore.costo_token(t, int(pg["token"][id]) + 1) - Motore.costo_token(t, int(pg["token"][id]))
					if extra <= resto and rng.randf() < 0.5:
						pg["token"][id] = int(pg["token"][id]) + 1
				continue
			# prima di tutto servono dadi
			var produce := t.has("livelli") or t.has("produce")
			if ndadi < 4 and not produce and rng.randf() < 0.8:
				continue
			# i consumatori di colori che non produci sono poco probabili
			var utile := produce
			for sl in t["slot"]:
				if _usabile(sl, prodotti):
					utile = true
			if not utile and rng.randf() < 0.85:
				continue
			if Motore.costo_token(t, 1) <= resto:
				pg["token"][id] = 1
		if valido(cat, pg):
			return pg
	return dati["personaggi"][rng.randi() % dati["personaggi"].size()].duplicate(true)
