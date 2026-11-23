class_name IA
extends RefCounted
## Avversario automatico. Prova ogni opzione legale su una copia della partita,
## lascia rispondere l'avversario con la sua difesa migliore e valuta il risultato
## con una funzione a pesi. I pesi si imparano giocando contro sé stessi
## (tests/allena_ia.gd) e si salvano in data/ia_pesi.json.

const PESI_BASE := {
	"vita": 4.0, "vita_bassa": 3.0, "mano_base": 0.55, "mano_val": 0.1, "conservato": 0.9,
	"mucchio_base": 0.4, "mucchio_val": 0.04, "stordito": 0.4, "eliminato": 0.9, "occupato": 1.0,
	"armato": 1.5, "distanza": 0.7, "fronte": 1.2, "fianco": 0.8, "retro": 1.6, "pericolo": 3.0,
	"iniziativa": 0.8, "azzardo": 7.0, "pesca_spazio": 0.5, "pesca_val": 0.1,
	"minaccia": 1.2, "pericolo_subito": 1.0, "cede": 0.6, "guardia": 1.0,
}

static var _pesi_salvati: Dictionary = {}
## 1 = guarda solo la propria mossa; 2 = per le mosse migliori guarda anche la risposta dell'avversario.
static var profondita := 2
const CANDIDATI := 3

static func pesi() -> Dictionary:
	if _pesi_salvati.is_empty():
		_pesi_salvati = PESI_BASE.duplicate()
		if FileAccess.file_exists("res://data/ia_pesi.json"):
			var d = JSON.parse_string(FileAccess.open("res://data/ia_pesi.json", FileAccess.READ).get_as_text())
			if d is Dictionary:
				for k in d.get("pesi", {}):
					if PESI_BASE.has(k):
						_pesi_salvati[k] = float(d["pesi"][k])
		# pesi migliorati sul dispositivo guardando l'IA allenarsi
		if FileAccess.file_exists("user://ia_pesi.json"):
			var u = JSON.parse_string(FileAccess.open("user://ia_pesi.json", FileAccess.READ).get_as_text())
			if u is Dictionary and int(u.get("versione_catalogo", 0)) == versione_catalogo():
				for k in u.get("pesi", {}):
					if PESI_BASE.has(k):
						_pesi_salvati[k] = float(u["pesi"][k])
	return _pesi_salvati

static func versione_catalogo() -> int:
	return 2

## Variante casuale dei pesi: si cambiano da 2 a 5 pesi di un fattore vicino a 1.
static func muta(w: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var c := w.duplicate()
	var chiavi: Array = c.keys()
	for i in rng.randi_range(2, 5):
		var k: String = chiavi[rng.randi() % chiavi.size()]
		c[k] = maxf(0.01, float(c[k]) * exp(rng.randfn(0.0, 0.3)))
	return c

## Adotta nuovi pesi e li salva sul dispositivo.
static func adotta(w: Dictionary, generazioni: int) -> void:
	_pesi_salvati = w.duplicate()
	var f := FileAccess.open("user://ia_pesi.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"pesi": w, "generazioni": generazioni, "versione_catalogo": versione_catalogo()}))

static func scegli(m: Motore, p: int, rng: RandomNumberGenerator = null, w: Dictionary = {}) -> Dictionary:
	if w.is_empty():
		w = pesi()
	if m.chi_decide() != p:
		return {}
	var g: Dictionary = m.s["g"][p]
	match m.s["fase"]:
		"pesca":
			return {"t": "prendi", "dadi": scelta_mucchio(m, p, m.da_prendere(p), w)}
		"azzardo":
			var soglia: float = w["azzardo"] if g["vita"] * 2 > g["vita_max"] else w["azzardo"] + 2.0
			if float(m.s["azz"]["tot"]) < soglia:
				for op in m.opzioni(p):
					if op["t"] == "rilancia":
						return op
			return {"t": "ferma"}
		"azione":
			var sp := _spinta_utile(m, p)
			if not sp.is_empty():
				return sp
	var opz := _sfoltisci(m, p, m.opzioni(p), w)
	var migliore := {}
	var bv := -INF
	var classifica := []
	for op in opz:
		var v := valuta_opzione(m, p, op, w)
		if rng != null:
			v += rng.randf() * 0.3
		classifica.append([v, op])
		if v > bv:
			bv = v
			migliore = op
	if profondita >= 2 and m.s["fase"] == "azione" and classifica.size() > 1:
		classifica.sort_custom(func(a, b): return a[0] > b[0])
		bv = -INF
		for i in mini(CANDIDATI, classifica.size()):
			var v2 := _valuta_con_risposta(m, p, classifica[i][1], w)
			if v2 > bv:
				bv = v2
				migliore = classifica[i][1]
	if migliore.get("t", "") == "passa":
		var cons := _conserva_utile(m, p)
		if not cons.is_empty():
			return cons
	return migliore

## Sceglie n dadi dal mucchio: quelli che entrano negli spazi liberi più preziosi.
static func scelta_mucchio(m: Motore, p: int, n: int, w: Dictionary = {}) -> Array:
	if w.is_empty():
		w = pesi()
	var punti := []
	var spazi := []
	for ts in m.slot_del_giocatore(p):
		if not m.occupato(p, ts[0], ts[1]["id"]):
			spazi.append(ts[1])
	for d in m.dadi_di(p, "mucchio"):
		var v := float(d["v"]) * float(w["pesca_val"])
		for sl in spazi:
			var c: Dictionary = sl.get("cond", {})
			if c.has("min") and d["v"] < int(c["min"]):
				continue
			if c.has("max") and d["v"] > int(c["max"]):
				continue
			for req in sl["dadi"]:
				if Motore.colore_ok(d["col"], req):
					v += valore_spazio(sl) * float(w["pesca_spazio"]) / sl["dadi"].size()
					break
		if d["col"] == "blu":
			v += 0.05 * d["v"]
		punti.append([v, d["id"]])
	punti.sort_custom(func(a, b): return a[0] > b[0])
	var out := []
	for i in mini(n, punti.size()):
		out.append(punti[i][1])
	return out

static func valuta_opzione(m: Motore, p: int, op: Dictionary, w: Dictionary) -> float:
	var c := m.clona()
	# l'IA non conosce i segreti dell'avversario: nella simulazione non scattano
	c.s["g"][1 - p]["armati"] = {}
	if c.applica(p, op) != "":
		return -INF
	_completa(c, p, w)
	return valuta(c, p, w)

## Valore della mossa dopo la risposta migliore dell'avversario (se tocca a lui).
static func _valuta_con_risposta(m: Motore, p: int, op: Dictionary, w: Dictionary) -> float:
	var c := m.clona()
	c.s["g"][1 - p]["armati"] = {}
	if c.applica(p, op) != "":
		return -INF
	_completa(c, p, w)
	var o := 1 - p
	if c.s["vinc"] >= 0 or c.chi_decide() != o or c.s["fase"] != "azione":
		return valuta(c, p, w)
	var peggiore := INF
	var meglio_per_o := -INF
	for op2 in _sfoltisci(c, o, c.opzioni(o), w):
		var c2 := c.clona()
		if c2.applica(o, op2) != "":
			continue
		_completa(c2, o, w)
		var vo := valuta(c2, o, w)
		if vo > meglio_per_o:
			meglio_per_o = vo
			peggiore = valuta(c2, p, w)
	return peggiore if peggiore < INF else valuta(c, p, w)

static func _completa(c: Motore, p: int, w: Dictionary) -> void:
	var guard := 0
	while c.s["vinc"] < 0 and guard < 16:
		guard += 1
		var chi := c.chi_decide()
		var f: String = c.s["fase"]
		if f == "reazione" and chi != p:
			var best := {"t": "risolvi"}
			var bv := -INF
			for op in c.opzioni(chi):
				var c2 := c.clona()
				if c2.applica(chi, op) != "":
					continue
				if c2.s["fase"] == "reazione" and c2.chi_decide() == chi:
					c2.applica(chi, {"t": "risolvi"})
				var v := valuta(c2, chi, w)
				if v > bv:
					bv = v
					best = op
			c.applica(chi, best)
		elif f == "rinforzo" and chi == p:
			var best := {"t": "sferra"}
			var bv := -INF
			for op in c.opzioni(p):
				if op["t"] == "slot" and c.slot_def(op["tok"], op["slot"])["tipo"] != "supporto_attacco":
					continue
				var c2 := c.clona()
				if c2.applica(p, op) != "":
					continue
				if c2.s["fase"] == "rinforzo":
					c2.applica(p, {"t": "sferra"})
				var v := valuta(c2, p, w)
				if op["t"] == "sferra":
					v -= 0.01
				if v > bv:
					bv = v
					best = op
			c.applica(p, best)
		elif f == "azzardo" and chi == p:
			c.applica(p, scegli(c, p, null, w))
		elif f == "pesca":
			c.applica(chi, {"t": "prendi", "dadi": scelta_mucchio(c, chi, c.da_prendere(chi), w)})
		else:
			break

static func valore_spazio(sl: Dictionary) -> float:
	match sl["effetto"]:
		"attacco", "assalto":
			return 2.2
		"movimento", "passo_ombra":
			return 0.9
		"sblocca", "pesca":
			return 1.4
		"schiva", "para", "contrattacco", "supp_difesa":
			return 1.0
		"supp_danno":
			return 0.9
		"segreto":
			return 1.2
	return 0.6

static func valuta(m: Motore, p: int, w: Dictionary) -> float:
	var o := 1 - p
	if m.s["vinc"] == p:
		return 10000.0
	if m.s["vinc"] == o:
		return -10000.0
	var v := _risorse(m, p, w) - _risorse(m, o, w)
	var g: Dictionary = m.s["g"][p]
	var go: Dictionary = m.s["g"][o]
	v += w["vita"] * (g["vita"] - go["vita"])
	if g["vita"] <= 3:
		v -= w["vita_bassa"]
	if go["vita"] <= 3:
		v += w["vita_bassa"]
	v += _posizione(m, p, g["pos"], g["dir"], w)
	# guardie: quanto coprono il lato da cui arriverebbe il nemico
	v += w["guardia"] * (float(m.copertura(p, go["pos"])[0]) - float(m.copertura(o, g["pos"])[0]))
	# minaccia: quanto può far male ciascuno con i dadi che ha in mano
	var mia := minaccia(m, p)
	var sua := minaccia(m, o)
	v += w["minaccia"] * mia
	if not go["passato"]:
		v -= w["pericolo_subito"] * sua
		# chi passa per primo lascia all'avversario azioni gratuite
		if g["passato"]:
			v -= w["cede"] * m.dadi_di(o, "mano").size()
	elif not g["passato"]:
		v += w["cede"] * m.dadi_di(p, "mano").size()
	if m.s["fase"] == "azione" and int(m.s["attivo"]) == p and not g["passato"]:
		v += w["iniziativa"]
	return v

static func _risorse(m: Motore, p: int, w: Dictionary) -> float:
	var v := 0.0
	for d in m.dadi_di(p, "mano"):
		v += w["mano_base"] + w["mano_val"] * d["v"]
	for d in m.dadi_di(p, "mucchio"):
		v += w["mucchio_base"] + w["mucchio_val"] * d["v"]
	# Dadi in Attesa valgono meno di quelli pronti: il recupero e una scelta tattica.
	# Valore futuro: i dadi pronti valgono di piu dei dadi bloccati in Attesa.
	# Premia la preparazione di un dado con soglia minima al prossimo recupero.
	for d in m.dadi_di(p, "attesa"):
		v += 0.15 + 0.35 * maxf(0.0, float(int(d.get("min_rientro", 1)) - 1))
	v += 0.35 * m.dadi_di(p, "mucchio").size()
	v += w["conservato"] * m.dadi_di(p, "conservato").size()
	v -= w["stordito"] * m.dadi_di(p, "stordito").size()
	v -= w["eliminato"] * m.dadi_di(p, "eliminato").size()
	var g: Dictionary = m.s["g"][p]
	for k in g["occupati"]:
		var parti: PackedStringArray = k.split("/")
		if g["armati"].has(k):
			v += w["armato"]
		else:
			v -= w["occupato"] * valore_spazio(m.slot_def(parti[0], parti[1]))
	return v

static func distanza_preferita(m: Motore, p: int) -> float:
	var lontano := 0
	var vicino := 0
	for ts in m.slot_del_giocatore(p):
		var sl: Dictionary = ts[1]
		if sl["tipo"] == "azione" and sl["effetto"] == "attacco":
			if int(sl.get("gittata_min", 1)) >= 2 or int(sl.get("portata", 1)) >= 4:
				lontano += 1
			elif not (ts[0] in ["forza", "base"]):
				vicino += 1
	return 3.5 if lontano > vicino else 1.0

static func _posizione(m: Motore, p: int, pos: Vector2i, dir: int, w: Dictionary) -> float:
	var go: Dictionary = m.s["g"][1 - p]
	var v: float = -w["distanza"] * absf(Motore.dist(pos, go["pos"]) - distanza_preferita(m, p))
	if Motore.in_fronte(pos, dir, go["pos"]):
		v += w["fronte"]
	var l := Motore.lato(go["pos"], go["dir"], pos)
	v += w["fianco"] if l == "fianco" else (w["retro"] if l == "retro" else 0.0)
	if m.s["per"].has(pos):
		v -= w["pericolo"]
	return v

static func _sfoltisci(m: Motore, p: int, opz: Array, w: Dictionary) -> Array:
	var out := []
	var mov := {}
	for op in opz:
		if op["t"] == "passo":
			var kp := Vector3i(op["b"]["pos"].x, op["b"]["pos"].y, op["b"]["dir"])
			if not mov.has(kp):
				mov[kp] = [0, op]
		elif op["t"] == "slot" and op["b"].has("pos") and m.slot_def(op["tok"], op["slot"])["effetto"] == "movimento":
			var k := Vector3i(op["b"]["pos"].x, op["b"]["pos"].y, op["b"]["dir"])
			var v: int = m.dado(p, op["dadi"][0])["v"]
			if not mov.has(k) or v < mov[k][0]:
				mov[k] = [v, op]
		else:
			out.append(op)
	var lista := []
	for k in mov:
		lista.append([_posizione(m, p, Vector2i(k.x, k.y), k.z, w) - 0.15 * mov[k][0], mov[k][1]])
	lista.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(6, lista.size()):
		out.append(lista[i][1])
	return out

static func _spinta_utile(m: Motore, p: int) -> Dictionary:
	if not m.spinta_disponibile(p):
		return {}
	var ids := []
	for d in m.dadi_di(p, "mano"):
		if d["v"] > 2:
			continue
		var serve := false
		for ts in m.slot_del_giocatore(p):
			var sl: Dictionary = ts[1]
			var c: Dictionary = sl.get("cond", {})
			if (c.has("max") or c.has("valori")) and not m.occupato(p, ts[0], sl["id"]):
				for req in sl["dadi"]:
					if Motore.colore_ok(d["col"], req):
						serve = true
		if not serve:
			ids.append(d["id"])
	if ids.is_empty():
		return {}
	return {"t": "spinta", "dadi": ids}

static func _conserva_utile(m: Motore, p: int) -> Dictionary:
	var g: Dictionary = m.s["g"][p]
	if m.dadi_di(p, "conservato").size() >= int(g["conserva_max"]):
		return {}
	var best := {}
	for d in m.dadi_di(p, "mano"):
		if (d["v"] >= 5 or d["v"] == 1) and (best.is_empty() or d["v"] > best["v"]):
			best = d
	if best.is_empty():
		return {}
	return {"t": "conserva", "dado": best["id"]}

## Stima del colpo più forte che `p` può portare con i dadi in mano, se il nemico è a tiro
## (contando anche un passo o un movimento ancora disponibili).
static func minaccia(m: Motore, p: int) -> float:
	var g: Dictionary = m.s["g"][p]
	var go: Dictionary = m.s["g"][1 - p]
	var mano := m.dadi_di(p, "mano")
	if mano.is_empty():
		return 0.0
	var d := Motore.dist(g["pos"], go["pos"])
	var avvicina := 0 if g["usi"].get("passo", 0) > 0 else Motore.PASSO_BASE
	var best := 0.0
	for ts in m.slot_del_giocatore(p):
		var sl: Dictionary = ts[1]
		if sl["tipo"] != "azione" or not (sl["effetto"] in ["attacco", "assalto"]) or m.occupato(p, ts[0], sl["id"]):
			continue
		var portata := int(sl.get("portata", 1))
		if sl["effetto"] == "assalto":
			portata = 6
		if d - avvicina > portata or d < int(sl.get("gittata_min", 1)):
			continue
		for ids in m.combinazioni(p, sl):
			var q := float(m.quantita(p, sl, ids))
			if not sl.get("ignora_armatura", false):
				q -= float(go["armatura"])
			best = maxf(best, q)
			break
	return best
