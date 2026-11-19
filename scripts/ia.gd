class_name IA
extends RefCounted
## Avversario automatico: prova ogni opzione legale su una copia della partita,
## lascia rispondere l'avversario con la sua reazione migliore e valuta il risultato.

## Restituisce la prossima opzione da applicare per il giocatore `p` (una alla volta).
static func scegli(m: Motore, p: int, rng: RandomNumberGenerator = null) -> Dictionary:
	if m.chi_decide() != p:
		return {}
	var g: Dictionary = m.s["g"][p]
	match m.s["fase"]:
		"azzardo":
			var az: Dictionary = m.s["azz"]
			var soglia := 7 if g["vita"] * 2 > g["vita_max"] else 9
			if int(az["tot"]) < soglia:
				for op in m.opzioni(p):
					if op["t"] == "rilancia":
						return op
			return {"t": "ferma"}
		"azione":
			var sp := _spinta_utile(m, p)
			if not sp.is_empty():
				return sp
	var opz := _sfoltisci(m, p, m.opzioni(p))
	var migliore := {}
	var bv := -INF
	for op in opz:
		var v := valuta_opzione(m, p, op)
		if rng != null:
			v += rng.randf() * 0.3
		if v > bv:
			bv = v
			migliore = op
	if migliore.get("t", "") == "passa":
		var cons := _conserva_utile(m, p)
		if not cons.is_empty():
			return cons
	return migliore

static func valuta_opzione(m: Motore, p: int, op: Dictionary) -> float:
	var c := m.clona()
	if c.applica(p, op) != "":
		return -INF
	_completa(c, p)
	return valuta(c, p)

## Porta avanti la copia finché la mossa non è chiusa: reazione dell'avversario, azzardo proprio.
static func _completa(c: Motore, p: int) -> void:
	var guard := 0
	while c.s["vinc"] < 0 and guard < 12:
		guard += 1
		var chi := c.chi_decide()
		if c.s["fase"] == "reazione" and chi != p:
			var best := {"t": "risolvi"}
			var bv := -INF
			for op in c.opzioni(chi):
				var c2 := c.clona()
				if c2.applica(chi, op) != "":
					continue
				var v := valuta(c2, chi)
				if v > bv:
					bv = v
					best = op
			c.applica(chi, best)
		elif c.s["fase"] == "azzardo" and chi == p:
			var op := scegli(c, p)
			c.applica(p, op)
		else:
			break

## Valutazione di una posizione dal punto di vista di `p`.
static func valuta(m: Motore, p: int) -> float:
	var o := 1 - p
	if m.s["vinc"] == p:
		return 10000.0
	if m.s["vinc"] == o:
		return -10000.0
	var g: Dictionary = m.s["g"][p]
	var go: Dictionary = m.s["g"][o]
	var v := 0.0
	v += 4.0 * g["vita"] - 4.0 * go["vita"]
	if g["vita"] <= 3:
		v -= 3.0
	for d in m.dadi_di(p, "pronto"):
		v += 0.6 + 0.18 * d["v"]
	for d in m.dadi_di(o, "pronto"):
		v -= 0.6 + 0.18 * d["v"]
	v += 0.9 * m.dadi_di(p, "conservato").size()
	v -= 1.6 * m.dadi_di(p, "bloccato").size()
	v += 1.6 * m.dadi_di(o, "bloccato").size()
	v += 0.5 * m.ritmo_libero(p) - 0.5 * m.ritmo_libero(o)
	# posizione
	var d := Motore.dist(g["pos"], go["pos"])
	var pref := distanza_preferita(m, p)
	v -= 0.7 * absf(d - pref)
	if Motore.in_fronte(g["pos"], g["dir"], go["pos"]):
		v += 1.2
	var mio_lato := Motore.lato(go["pos"], go["dir"], g["pos"])
	if mio_lato == "fianco":
		v += 0.8
	elif mio_lato == "retro":
		v += 1.6
	if m.s["per"].has(g["pos"]):
		v -= 3.0
	if m.s["fase"] == "azione" and int(m.s["attivo"]) == p and not g["passato"]:
		v += 0.8
	return v

static func distanza_preferita(m: Motore, p: int) -> float:
	var lontano := 0
	var vicino := 0
	for ts in m.slot_del_giocatore(p):
		var sl: Dictionary = ts[1]
		if sl["tipo"] == "azione" and sl["effetto"] == "attacco":
			if int(sl.get("gittata_min", 1)) >= 2 or (int(sl.get("portata", 1)) >= 4):
				lontano += 1
			elif ts[0] not in ["forza"]:
				vicino += 1
	if lontano > vicino:
		return 3.5
	return 1.0

static func _spinta_utile(m: Motore, p: int) -> Dictionary:
	if m.costo_spinta(p) > 0 or not m.puo_agire(p):
		return {}
	var ids := []
	for d in m.dadi_di(p, "pronto"):
		if d["v"] <= 2:
			ids.append(d["id"])
	if ids.is_empty():
		return {}
	return {"t": "spinta", "dadi": ids}

static func _conserva_utile(m: Motore, p: int) -> Dictionary:
	var g: Dictionary = m.s["g"][p]
	if m.dadi_di(p, "conservato").size() >= int(g["conserva_max"]):
		return {}
	var best := {}
	for d in m.dadi_di(p, "pronto"):
		if d["v"] >= 4 and (best.is_empty() or d["v"] > best["v"]):
			best = d
	if best.is_empty():
		return {}
	return {"t": "conserva", "dado": best["id"]}

## Tiene tutte le opzioni tranne i movimenti, di cui conserva solo i più promettenti
## (per ogni destinazione il dado più basso), per non simulare centinaia di passi.
static func _sfoltisci(m: Motore, p: int, opz: Array) -> Array:
	var out := []
	var mov := {}
	for op in opz:
		if op["t"] == "slot" and op["b"].has("pos") and m.slot_def(op["tok"], op["slot"])["effetto"] == "movimento":
			var k := Vector3i(op["b"]["pos"].x, op["b"]["pos"].y, op["b"]["dir"])
			var v: int = m.dado(p, op["dadi"][0])["v"]
			if not mov.has(k) or v < mov[k][0]:
				mov[k] = [v, op]
		else:
			out.append(op)
	var lista := []
	for k in mov:
		lista.append([_posizione(m, p, Vector2i(k.x, k.y), k.z) - 0.15 * mov[k][0], mov[k][1]])
	lista.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(6, lista.size()):
		out.append(lista[i][1])
	return out

static func _posizione(m: Motore, p: int, pos: Vector2i, dir: int) -> float:
	var go: Dictionary = m.s["g"][1 - p]
	var v := -0.7 * absf(Motore.dist(pos, go["pos"]) - distanza_preferita(m, p))
	if Motore.in_fronte(pos, dir, go["pos"]):
		v += 1.2
	var l := Motore.lato(go["pos"], go["dir"], pos)
	v += 0.8 if l == "fianco" else (1.6 if l == "retro" else 0.0)
	if m.s["per"].has(pos):
		v -= 3.0
	return v
