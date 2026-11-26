class_name Sfera
extends Motore
## Motore della sfera: i dadi nascono al centro, passano per le sei azioni base e salgono
## verso i token esterni (curvi) e l'anello raro. Usa la mappa, le spinte e gli eventi di Motore,
## così l'arena 3D anima tutto come prima. Le regole sono quelle equilibrate con il simulatore
## (tools/sfera_sim.py): vedi data/sfera.json e data/regole.md.
##
## Lo svolgimento è a "passi": ogni azione o reazione si applica con esegui()/reagisci()/piazza();
## quando serve una scelta di un giocatore umano il motore si ferma (fase "reazione" o "pausa").

const SETTORI_COL := {"rosso": "F", "giallo": "A", "blu": "P", "arancio": "FA", "verde": "AP", "viola": "PF", "scena": "FAP"}
const PRIMARI := {"rosso": "r", "giallo": "g", "blu": "b"}
const SETTORE_DADO := {"r": "F", "g": "A", "b": "P"}
const AZ_SETTORE := {"colpo": "F", "presa": "F", "passo": "A", "scarto": "A", "parata": "P", "leggi": "P"}
const TRAPPOLE := ["schivata", "irimi", "tenkan", "proiezione", "immobilizza", "contrattacco", "ukemi"]
const COLPI := ["colpo", "colpo_stordente", "spinta", "carica", "affondo"]
const VALORE_TRAPPOLA := {"proiezione": 5, "immobilizza": 4, "contrattacco": 4, "irimi": 3, "tenkan": 3, "schivata": 2, "ukemi": 2}
const NOMI_DADO := {"r": "rosso", "g": "giallo", "b": "blu", "n": "bianco"}
const NOMI_SETTORE := {"F": "Forza", "A": "Agilità", "P": "Percezione"}

var sd: Dictionary = {}
var reg: Dictionary = {}
var tokp: Dictionary = {}     # token esterni e di scena per id
var rarip: Dictionary = {}

static func carica_sfera() -> Dictionary:
	var f := FileAccess.open("res://data/sfera.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())

func _init(d: Dictionary = {}, sfera: Dictionary = {}) -> void:
	super(d)
	sd = sfera if not sfera.is_empty() else carica_sfera()
	reg = sd["regole"]
	for t in sd["esterni"]:
		tokp[t["id"]] = t
	for t in sd["scena"]:
		tokp[t["id"]] = t
	for t in sd["rari"]:
		rarip[t["id"]] = t

# ================================================================ personaggi

## Punti e budget di un personaggio della sfera: {"punti": usati, "max_punti", "budget": spesi, "max_budget", "problemi": []}.
func conto(pg: Dictionary) -> Dictionary:
	var r3 := int(pg.get("R", 2)) == 3
	var maxp := int(reg["punti"]) - (int(reg["ritmo3_punti"]) if r3 else 0)
	var maxb := int(reg["budget"]) - (int(reg["ritmo3_budget"]) if r3 else 0)
	var punti := 0
	var prob := []
	for k in ["F", "A", "P", "C"]:
		var v := int(pg.get(k, 1))
		punti += v
		if v < 1 or v > 4:
			prob.append("ogni caratteristica va da 1 a 4")
	var spesi := 0
	for id in pg.get("coll", []):
		if tokp.has(id):
			spesi += int(tokp[id]["costo"])
	if String(pg.get("raro", "")) != "" and rarip.has(pg["raro"]):
		spesi += int(rarip[pg["raro"]]["costo"])
	if punti != maxp:
		prob.append("le caratteristiche devono sommare %d (ora %d)" % [maxp, punti])
	if spesi > maxb:
		prob.append("i token costano %d, il budget è %d" % [spesi, maxb])
	return {"punti": punti, "max_punti": maxp, "budget": spesi, "max_budget": maxb, "problemi": prob}

func casuale(gen: RandomNumberGenerator, nome := "Avventuriero") -> Dictionary:
	var R := 3 if gen.randi() % 3 == 0 else 2
	var punti := int(reg["punti"]) - (int(reg["ritmo3_punti"]) if R == 3 else 0)
	var v := [1, 1, 1, 1]
	while true:
		v = [1, 1, 1, 1]
		for i in punti - 4:
			v[gen.randi() % 4] += 1
		if v.max() <= 4:
			break
	var budget := int(reg["budget"]) - (int(reg["ritmo3_budget"]) if R == 3 else 0)
	var raro := ""
	if gen.randf() < 0.3:
		var r: Dictionary = sd["rari"][gen.randi() % sd["rari"].size()]
		if int(r["costo"]) <= budget:
			raro = r["id"]
			budget -= int(r["costo"])
	var ids := []
	for t in sd["esterni"]:
		ids.append(t["id"])
	for i in range(ids.size() - 1, 0, -1):
		var j := gen.randi() % (i + 1)
		var x = ids[i]
		ids[i] = ids[j]
		ids[j] = x
	var coll := []
	for id in ids:
		if coll.size() >= 6:
			break
		var c := int(tokp[id]["costo"])
		if c <= budget:
			coll.append(id)
			budget -= c
	return {"nome": nome, "F": v[0], "A": v[1], "P": v[2], "C": v[3], "R": R, "coll": coll, "raro": raro, "casuale": true}

# ================================================================ partita

func nuova_sfera(pg0: Dictionary, pg1: Dictionary, arena_id: String, umani: Array, seme: int = -1) -> void:
	if seme >= 0:
		rng.seed = seme
	else:
		rng.randomize()
	var ar: Dictionary = dati["arene"][arena_id]
	var ost := {}
	for o in ar["ostacoli"]:
		ost[Vector2i(int(o[0]), int(o[1]))] = true
	var per := {}
	for o in ar["pericoli"]:
		per[Vector2i(int(o[0]), int(o[1]))] = true
	var ogg := {}
	var cariche := {}
	const USI := {"pietre": 3, "braciere": 2, "fontana": 2, "cassa": 1}
	for o in ar.get("oggetti", []):
		var tipo := String(o[2])
		var h := Vector2i(int(o[0]), int(o[1]))
		ogg[h] = {"tipo": tipo, "cariche": int(USI.get(tipo, 0))}
		if USI.has(tipo):
			cariche[h] = int(USI[tipo])
	var radici := {}
	for o in ar.get("alberi_grandi", []):
		var c := Vector2i(int(o[0]), int(o[1]))
		ogg[c] = {"tipo": "albero", "cariche": 0, "grande": String(o[2])}
		for dd in DIRS:
			radici[c + dd] = c
	var sabbia := {}
	for o in ar.get("sabbia", []):
		var h := Vector2i(int(o[0]), int(o[1]))
		sabbia[h] = true
		cariche[h] = 1
	var bassi := {}
	for o in ar.get("bassi", []):
		bassi[Vector2i(int(o[0]), int(o[1]))] = true
	var alt := {}
	for o in ar.get("alture", []):
		alt[Vector2i(int(o[0]), int(o[1]))] = int(o[2])
	var R := int(ar["raggio"])
	for h in radici:
		alt[h] = 1
	for h in ogg:
		if ogg[h]["tipo"] == "cassa":
			alt[h] = int(alt.get(h, 0)) + 1
	s = {"alt": alt, "bassi": bassi, "ogg": ogg, "sabbia": sabbia, "radici": radici, "cariche": cariche,
		"raggio": R, "ost": ost, "per": per, "arena": arena_id, "vinc": -1, "fase": "azione",
		"scambio": 0, "primo": rng.randi() % 2, "attivo": 0, "finito": [false, false], "iniziativa_a": -1,
		"pend": {}, "da_piazzare": [], "nid": 0, "log": [], "eventi": [], "g": [], "round": 0}
	var partenze := [Vector2i(-(R - 3), 0), Vector2i(R - 3, 0)]
	for i in 2:
		var pg: Dictionary = [pg0, pg1][i]
		var mucchio := []
		for k in [["F", "r"], ["A", "g"], ["P", "b"], ["C", "n"]]:
			for j in int(pg.get(k[0], 1)):
				mucchio.append(k[1])
		var vita := int(reg["vita_base"]) + int(pg.get("C", 1))
		s["g"].append({"nome": pg.get("nome", "Combattente"), "pg": pg.duplicate(true), "umano": bool(umani[i]),
			"F": int(pg.get("F", 1)), "A": int(pg.get("A", 1)), "P": int(pg.get("P", 1)), "C": int(pg.get("C", 1)), "R": int(pg.get("R", 2)),
			"coll": pg.get("coll", []).duplicate(), "raro_id": String(pg.get("raro", "")),
			"vita": vita, "vita_max": vita, "vantaggi": 0, "svantaggi": 0,
			"pos": partenze[i], "dir": [0, 3][i], "guardie": {},
			"mucchio": mucchio, "mano": [], "fermi": [], "esterni": [], "raro": {}, "raro_usato": false,
			"girate": {}, "flussi": 0, "tenuto": false, "occhio": false, "zanshin": 0, "slot": 2})
	_scrivi("Inizia il duello: %s contro %s." % [s["g"][0]["nome"], s["g"][1]["nome"]])
	_pausa()

func valore_guardia(_p: int, _key: String) -> int:
	return 0

func chi_decide() -> int:
	if s["vinc"] >= 0 or s["fase"] == "fine":
		return -1
	match s["fase"]:
		"reazione":
			return int(s["pend"]["dif"])
		"pausa":
			return int(s["da_piazzare"][0]) if not s["da_piazzare"].is_empty() else -1
	return int(s["attivo"])

func _tira() -> int:
	return rng.randi_range(1, 6)

func D(x: int) -> int:
	return (x + 1) / 2

func nemico(p: int) -> Dictionary:
	return s["g"][1 - p]

func _vant(p: int, n: int) -> void:
	var g: Dictionary = s["g"][p]
	var prima: int = g["vantaggi"]
	g["vantaggi"] = clampi(prima + n, 0, int(reg["max_vant"]))
	if g["vantaggi"] != prima:
		_evento({"t": "vantaggi", "p": p})

func _svant(p: int, n: int) -> void:
	s["g"][p]["svantaggi"] = maxi(0, int(s["g"][p]["svantaggi"]) + n)
	_evento({"t": "svantaggi", "p": p})

## Valore effettivo di un dado: ogni svantaggio toglie 1 al prossimo dado usato.
func _valore(p: int, v: int) -> int:
	var g: Dictionary = s["g"][p]
	if int(g["svantaggi"]) > 0:
		g["svantaggi"] -= 1
		return maxi(1, v - 1)
	return v

func _nuovo_dado(c: String) -> Dictionary:
	s["nid"] += 1
	return {"id": int(s["nid"]), "c": c, "v": _tira()}

func dado_in_mano(p: int, id: int) -> int:
	var mano: Array = s["g"][p]["mano"]
	for i in mano.size():
		if int(mano[i]["id"]) == id:
			return i
	return -1

func _ferisci(p: int, n: int) -> void:
	if n <= 0 or s["vinc"] >= 0:
		return
	var g: Dictionary = s["g"][p]
	g["vita"] = maxi(0, int(g["vita"]) - n)
	_evento({"t": "danno", "p": p, "n": n})
	_scrivi("%s subisce %s (%d/%d)." % [g["nome"], plurale(n, "ferita", "ferite"), g["vita"], g["vita_max"]])
	if g["vita"] <= 0:
		s["vinc"] = 1 - p
		s["fase"] = "fine"
		_scrivi("%s è a terra. Vince %s!" % [g["nome"], s["g"][1 - p]["nome"]])
		_evento({"t": "ko", "p": p})

func _cura(p: int, n: int) -> void:
	var g: Dictionary = s["g"][p]
	var prima: int = g["vita"]
	g["vita"] = mini(int(g["vita_max"]), prima + n)
	if g["vita"] > prima:
		_evento({"t": "cura", "p": p, "n": g["vita"] - prima})

# ================================================================ mappa

func bloccato_s(h: Vector2i) -> bool:
	return (not in_arena(h)) or s["ost"].has(h) or s["bassi"].has(h) or oggetto(h) in ["fontana", "braciere", "albero", "pietre"]

func libero_s(h: Vector2i, chi: int) -> bool:
	if bloccato_s(h):
		return false
	for i in 2:
		if i != chi and s["g"][i]["pos"] == h:
			return false
	return true

func distanza() -> int:
	return dist(s["g"][0]["pos"], s["g"][1]["pos"])

func contatto() -> bool:
	return distanza() == 1 and absi(altezza(s["g"][0]["pos"]) - altezza(s["g"][1]["pos"])) <= 1

func contatto_da(h: Vector2i, p: int) -> bool:
	var o: Vector2i = s["g"][1 - p]["pos"]
	return dist(h, o) == 1 and absi(altezza(h) - altezza(o)) <= 1

## Esagoni raggiungibili camminando con k passi: {esagono: [passi, precedente]}.
func cammino(p: int, k: int) -> Dictionary:
	var start: Vector2i = s["g"][p]["pos"]
	var visti := {start: [0, null]}
	var coda := [start]
	while not coda.is_empty():
		var h: Vector2i = coda.pop_front()
		if int(visti[h][0]) >= k:
			continue
		for d in DIRS:
			var nh: Vector2i = h + d
			if visti.has(nh) or not libero_s(nh, p) or absi(altezza(nh) - altezza(h)) > 1:
				continue
			visti[nh] = [int(visti[h][0]) + 1, h]
			coda.append(nh)
	return visti

func _percorso(vis: Dictionary, fine: Vector2i) -> Array:
	var out := []
	var cur = fine
	while cur != null:
		out.push_front(cur)
		cur = vis[cur][1]
	var per := []
	for i in out.size():
		var h: Vector2i = out[i]
		var dd: int = dir_verso(out[i - 1], h) if i > 0 else int(s["g"][0]["dir"])
		per.append(Vector3i(h.x, h.y, dd))
	return per

func alle_spalle_di(dif: int, h: Vector2i) -> bool:
	return lato_rel(dif, h) in [2, 3, 4]

func valuta_casella(p: int, h: Vector2i) -> float:
	var o := 1 - p
	var v := 0.0
	if contatto_da(h, p):
		v += 10.0
		if alle_spalle_di(o, h):
			v += 3.0
	v -= dist(h, s["g"][o]["pos"]) * 1.5
	v += 0.8 * altezza(h) + (0.6 if altezza(h) > altezza(s["g"][o]["pos"]) else 0.0)
	if s["per"].has(h):
		v -= 4.0
	if oggetto_vicino(h) != "":
		v += 0.4
	return v

func gira_verso(p: int) -> void:
	var g: Dictionary = s["g"][p]
	var nd := dir_verso(g["pos"], s["g"][1 - p]["pos"])
	if nd != int(g["dir"]):
		g["dir"] = nd
		_evento({"t": "muovi", "p": p, "percorso": [Vector3i(g["pos"].x, g["pos"].y, nd)]})

func _muovi_a(p: int, vis: Dictionary, h: Vector2i) -> void:
	var g: Dictionary = s["g"][p]
	if h == g["pos"]:
		return
	var per := _percorso(vis, h)
	per[0] = Vector3i(per[0].x, per[0].y, int(g["dir"]))
	g["pos"] = h
	g["dir"] = per[per.size() - 1].z
	_evento({"t": "muovi", "p": p, "percorso": per})
	_pericolo_s(p)

func avvicina(p: int, k: int, dest = null) -> void:
	var vis := cammino(p, k)
	var best: Vector2i = s["g"][p]["pos"]
	if dest != null and vis.has(dest):
		best = dest
	else:
		var bv := -INF
		for h in vis:
			var v := valuta_casella(p, h) + rng.randf() * 0.3
			if v > bv:
				bv = v
				best = h
	_muovi_a(p, vis, best)

func allontana(p: int, k: int) -> void:
	var vis := cammino(p, k)
	var o: Vector2i = s["g"][1 - p]["pos"]
	var best: Vector2i = s["g"][p]["pos"]
	var bv := -INF
	for h in vis:
		var v := dist(h, o) + 0.3 * altezza(h) - (4.0 if s["per"].has(h) else 0.0) + rng.randf() * 0.2
		if v > bv:
			bv = v
			best = h
	_muovi_a(p, vis, best)

func _salta_a(p: int, h: Vector2i) -> void:
	var g: Dictionary = s["g"][p]
	g["pos"] = h
	g["dir"] = dir_verso(h, s["g"][1 - p]["pos"])
	_evento({"t": "salto", "p": p, "pos": h, "dir": g["dir"]})

## Salto o carica: arrivi a contatto se entro k esagoni. Dritto: atterri davanti, non sul fianco.
func porta_contatto(p: int, k: int, dritto := false) -> void:
	var o: Vector2i = s["g"][1 - p]["pos"]
	var cand := []
	for d in DIRS:
		var h: Vector2i = o + d
		if libero_s(h, p) and absi(altezza(h) - altezza(o)) <= 1 and dist(h, s["g"][p]["pos"]) <= k:
			cand.append(h)
	if cand.is_empty():
		avvicina(p, k)
		return
	var best: Vector2i = cand[0]
	if dritto:
		var bd := 99
		for h in cand:
			var dd := dist(h, s["g"][p]["pos"]) * 10 - altezza(h)
			if dd < bd:
				bd = dd
				best = h
	else:
		var bv := -INF
		for h in cand:
			var v := valuta_casella(p, h) + rng.randf() * 0.3
			if v > bv:
				bv = v
				best = h
	if best != s["g"][p]["pos"]:
		_salta_a(p, best)
	gira_verso(p)

func alle_spalle(p: int) -> void:
	var o := 1 - p
	var cand := []
	for d in DIRS:
		var h: Vector2i = s["g"][o]["pos"] + d
		if libero_s(h, p) and absi(altezza(h) - altezza(s["g"][o]["pos"])) <= 1:
			cand.append(h)
	if cand.is_empty():
		return
	cand.sort_custom(func(a, b): return absi(lato_rel(o, a) - 3) < absi(lato_rel(o, b) - 3))
	_salta_a(p, cand[0])

## A contatto: giri attorno al nemico di k esagoni verso le sue spalle. Ritorna true se arrivi dietro.
func aggira(p: int, k: int) -> bool:
	var o := 1 - p
	var op: Vector2i = s["g"][o]["pos"]
	var start: Vector2i = s["g"][p]["pos"]
	var vis := {start: [0, null]}
	var coda := [start]
	while not coda.is_empty():
		var h: Vector2i = coda.pop_front()
		if int(vis[h][0]) >= k:
			continue
		for d in DIRS:
			var nh: Vector2i = h + d
			if vis.has(nh) or dist(nh, op) != 1 or not libero_s(nh, p):
				continue
			if absi(altezza(nh) - altezza(h)) > 1 or absi(altezza(nh) - altezza(op)) > 1:
				continue
			vis[nh] = [int(vis[h][0]) + 1, h]
			coda.append(nh)
	var best: Vector2i = start
	var bv := 99
	for h in vis:
		var v := absi(lato_rel(o, h) - 3) * 10 - altezza(h)
		if v < bv:
			bv = v
			best = h
	_muovi_a(p, vis, best)
	gira_verso(p)
	return alle_spalle_di(o, best)

## Spinta o proiezione: dif vola di k esagoni; urta, cade dalle alture, finisce nei pericoli.
func spingi(att: int, dif: int, k: int, lancia := false) -> void:
	var gd: Dictionary = s["g"][dif]
	var d := dir_verso(s["g"][att]["pos"], gd["pos"])
	var per := [Vector3i(gd["pos"].x, gd["pos"].y, gd["dir"])]
	var urto := false
	var caduta := 0
	for i in k:
		var cur: Vector2i = gd["pos"]
		var nh: Vector2i = cur + DIRS[d]
		if not libero_s(nh, dif) or altezza(nh) > altezza(cur):
			urto = true
			break
		caduta += maxi(0, altezza(cur) - altezza(nh))
		gd["pos"] = nh
		per.append(Vector3i(nh.x, nh.y, gd["dir"]))
	_evento({"t": "spinto", "p": dif, "percorso": per, "lancia": lancia, "urto": urto, "dir": d, "caduta": caduta})
	if caduta > 0:
		_scrivi("%s cade giù dal rialzo!" % gd["nome"])
		_ferisci(dif, caduta)
	if urto:
		_scrivi("%s sbatte contro un ostacolo!" % gd["nome"])
		_ferisci(dif, int(reg["danno_urto"]))
	_pericolo_s(dif)

func _pericolo_s(p: int) -> void:
	if s["vinc"] < 0 and s["per"].has(s["g"][p]["pos"]):
		_scrivi("%s finisce nel fuoco!" % s["g"][p]["nome"])
		_ferisci(p, int(reg["danno_pericolo"]))

func spinta_utile(p: int) -> bool:
	var o := 1 - p
	var d := DIRS[dir_verso(s["g"][p]["pos"], s["g"][o]["pos"])]
	var op: Vector2i = s["g"][o]["pos"]
	var nh: Vector2i = op + d
	return (not libero_s(nh, o)) or altezza(nh) < altezza(op) or s["per"].has(nh)

## Oggetto di scena usabile da h (con usi rimasti): "tipo@x,y" oppure "".
func oggetto_vicino(h: Vector2i) -> String:
	if s["sabbia"].has(h) and int(s["cariche"].get(h, 0)) > 0:
		return "sabbia"
	for d in DIRS:
		var nh: Vector2i = h + d
		var t := oggetto(nh)
		if t in ["pietre", "braciere", "fontana", "cassa"] and int(s["cariche"].get(nh, 0)) > 0:
			return t
	return ""

func _casella_oggetto(h: Vector2i, tipo: String) -> Vector2i:
	if tipo == "sabbia":
		return h
	for d in DIRS:
		if oggetto(h + d) == tipo and int(s["cariche"].get(h + d, 0)) > 0:
			return h + d
	return h

func spalle_al_muro(p: int) -> bool:
	var h: Vector2i = s["g"][p]["pos"]
	for d in DIRS:
		if s["ost"].has(h + d) or oggetto(h + d) == "albero":
			return true
	return false

# ================================================================ pause e token

func tok(id: String) -> Dictionary:
	return tokp.get(id, {})

func slot_di(p: int) -> int:
	return int(s["g"][p]["R"]) + (1 if altezza(s["g"][p]["pos"]) >= 1 else 0)

func _pausa() -> void:
	s["scambio"] += 1
	s["da_piazzare"] = []
	_evento({"t": "pausa"})
	_scrivi("— Pausa: scambio %d." % s["scambio"])
	for p in 2:
		var g: Dictionary = s["g"][p]
		var slot := slot_di(p)
		g["slot"] = slot
		var tenuti := []
		if s["scambio"] > 1:
			for e in g["esterni"]:
				if not e["dadi"].is_empty() and not String(e["id"]).begins_with("scena_"):
					tenuti.append(e)
			tenuti.sort_custom(func(a, b): return a["dadi"].size() > b["dadi"].size())
			tenuti = tenuti.slice(0, slot)
			if spalle_al_muro(p) and not g["umano"] and rng.randf() < 0.5:
				var cand := tenuti.filter(func(e): return not e["pronto"])
				if not cand.is_empty():
					cand.sort_custom(func(a, b): return a["dadi"].size() < b["dadi"].size())
					tenuti.erase(cand[0])
			for e in tenuti:
				e["bloccato"] = false
		var pool: Array = g["mucchio"].duplicate()
		for e in tenuti:
			for dd in e["dadi"]:
				pool.erase(dd["c"])
		for i in range(pool.size() - 1, 0, -1):
			var j := rng.randi() % (i + 1)
			var x = pool[i]
			pool[i] = pool[j]
			pool[j] = x
		g["mano"] = []
		for i in mini(int(reg["pesca"]), pool.size()):
			g["mano"].append(_nuovo_dado(pool[i]))
		g["fermi"] = []
		g["girate"] = {}
		g["svantaggi"] = 0
		g["flussi"] = 0
		g["zanshin"] = maxi(0, int(g["zanshin"]) - 1)
		g["occhio"] = false
		g["tenuto"] = false
		g["esterni"] = tenuti
		if g["umano"] and slot > tenuti.size() and not g["coll"].is_empty():
			s["da_piazzare"].append(p)
		else:
			for id in _scegli_token(p, slot - tenuti.size()):
				g["esterni"].append(_nuovo_token(id))
		var ogg := oggetto_vicino(g["pos"])
		if ogg != "":
			var e := _nuovo_token("scena_" + ogg)
			e["ogg_h"] = _casella_oggetto(g["pos"], ogg)
			g["esterni"].append(e)
		if g["raro"].is_empty() and g["raro_id"] != "" and not g["raro_usato"]:
			g["raro"] = {"id": g["raro_id"], "dadi": [], "pronto": false}
	s["attivo"] = (int(s["primo"]) + int(s["scambio"])) % 2
	s["finito"] = [false, false]
	s["iniziativa_a"] = -1
	gira_verso(0)
	gira_verso(1)
	s["fase"] = "pausa" if not s["da_piazzare"].is_empty() else "azione"
	if s["fase"] == "azione":
		_avanza()

func _nuovo_token(id: String) -> Dictionary:
	return {"id": id, "dadi": [], "pronto": false, "bloccato": false, "pot": false, "respinto": false}

func token_disponibili(p: int) -> Array:
	var g: Dictionary = s["g"][p]
	var gia := {}
	for e in g["esterni"]:
		gia[e["id"]] = true
	return g["coll"].filter(func(id): return not gia.has(id))

func posti_da_piazzare(p: int) -> int:
	var g: Dictionary = s["g"][p]
	var n := 0
	for e in g["esterni"]:
		if not String(e["id"]).begins_with("scena_"):
			n += 1
	return maxi(0, int(g["slot"]) - n)

## Il giocatore umano sceglie i token da mettere in campo alla pausa.
func piazza(p: int, ids: Array) -> String:
	if s["fase"] != "pausa" or not s["da_piazzare"].has(p):
		return "non è il momento di piazzare"
	var g: Dictionary = s["g"][p]
	var n := posti_da_piazzare(p)
	var disp := token_disponibili(p)
	for id in ids:
		if n <= 0:
			break
		if disp.has(id):
			g["esterni"].insert(0, _nuovo_token(id))
			disp.erase(id)
			n -= 1
	s["da_piazzare"].erase(p)
	if s["da_piazzare"].is_empty():
		s["fase"] = "azione"
		_avanza()
	return ""

func _scegli_token(p: int, n: int) -> Array:
	var g: Dictionary = s["g"][p]
	var forze := {"F": g["F"] + g["C"] * 0.3, "A": g["A"] + g["C"] * 0.3, "P": g["P"] + g["C"] * 0.3}
	var punt := []
	for id in token_disponibili(p):
		var t := tok(id)
		var sett: String = SETTORI_COL[t["col"]]
		var v := 0.0
		for c in sett:
			v += forze[c]
		v = v / sett.length() + rng.randf() * 1.5
		if t["eff"] in COLPI and distanza() > 2:
			v += 0.5
		punt.append([v, id])
	punt.sort_custom(func(a, b): return a[0] > b[0])
	var out := []
	for x in punt.slice(0, maxi(0, n)):
		out.append(x[1])
	return out

func posti_liberi(e: Dictionary) -> Array:
	var liberi: Array = tok(e["id"])["req"].duplicate()
	for dd in e["dadi"]:
		var c: String = dd["c"]
		if liberi.has(c):
			liberi.erase(c)
		elif liberi.has("n"):
			liberi.erase("n")
		elif liberi.has("x"):
			liberi.erase("x")
	return liberi

func puo_caricare(e: Dictionary, colore: String, settore: String) -> bool:
	if e["pronto"] or e["bloccato"]:
		return false
	var t := tok(e["id"])
	if not settore in String(SETTORI_COL[t["col"]]):
		return false
	var liberi := posti_liberi(e)
	if liberi.is_empty():
		return false
	if liberi.has("x"):
		return true
	var prim: String = PRIMARI.get(t["col"], "")
	if colore == "n":
		return prim != "" and (liberi.has(prim) or liberi.has("n"))
	return liberi.has(colore) or (liberi.has("n") and colore == prim)

## Indici dei token esterni su cui può salire un dado di quel colore da quel settore.
func bersagli_salita(p: int, colore: String, settore: String) -> Array:
	var out := []
	var est: Array = s["g"][p]["esterni"]
	for i in est.size():
		if puo_caricare(est[i], colore, settore):
			out.append(i)
	return out

func freccia(e: Dictionary) -> int:
	return int(tok(e["id"]).get("freccia", 1))

func somma(e: Dictionary) -> int:
	var t := 0
	for dd in e["dadi"]:
		t += int(dd["v"])
	return t

func massimo(e: Dictionary) -> int:
	var m := 1
	for dd in e["dadi"]:
		m = maxi(m, int(dd["v"]))
	return m

func in_portata(e: Dictionary) -> bool:
	var t := tok(e["id"])
	var eff: String = t["eff"]
	if eff in ["colpo", "colpo_stordente", "spinta", "sgambetto"]:
		return contatto()
	if eff == "affondo":
		return distanza() <= 2
	if eff == "carica":
		return distanza() <= 4
	if eff in ["alle_spalle", "balzo"]:
		return distanza() <= 3
	if t.has("portata"):
		return distanza() <= int(t["portata"])
	return true

# ================================================================ salire

## Passaggio verso l'esterno. scelta = {"tok": indice o -1 (il più vicino a riempirsi), "modo": "scala" | "ritira" | "no" | "auto"}.
## poi riceve true se il giocatore continua a giocare (ritiro riuscito durante la sua azione).
func _sali(p: int, colore: String, settore: String, mia: bool, valore: int, scelta: Dictionary, poi: Callable) -> void:
	var g: Dictionary = s["g"][p]
	var cand := bersagli_salita(p, colore, settore)
	var modo := String(scelta.get("modo", "auto"))
	if cand.is_empty() or modo == "no":
		poi.call(false)
		return
	var idx := int(scelta.get("tok", -1))
	if not cand.has(idx):
		cand.sort_custom(func(a, b): return posti_liberi(g["esterni"][a]).size() < posti_liberi(g["esterni"][b]).size())
		idx = cand[0]
	var e: Dictionary = g["esterni"][idx]
	var scalato := maxi(1, valore - freccia(e))
	if modo == "auto":
		var soglia := 3 + (2 if int(g["zanshin"]) > 0 else 0)
		var caso := 0.6 if int(g["zanshin"]) > 0 else 0.25
		modo = "ritira" if (scalato < soglia or (mia and rng.randf() < caso)) else "scala"
	var v := scalato
	var continua := false
	var nome_t: String = tok(e["id"])["nome"]
	if modo == "ritira":
		v = _tira()
		var fallo := 1 if int(g["zanshin"]) > 0 else int(reg["fallisce_fino"])
		if v <= fallo:
			_scrivi("%s ritira per salire su %s: esce %d, il dado va in Attesa." % [g["nome"], nome_t, v])
			_evento({"t": "fallito", "p": p})
			poi.call(false)
			return
		continua = mia
		_vant(p, 1)
		_scrivi("%s ritira e sale su %s con un %d%s." % [g["nome"], nome_t, v, ", e continua" if continua else ""])
	else:
		_scrivi("%s sale su %s scalando: %d." % [g["nome"], nome_t, v])
	e["dadi"].append({"c": colore, "v": v})
	if not posti_liberi(e).is_empty():
		poi.call(continua)
		return
	e["pronto"] = true
	if e["dadi"].size() >= 2:
		var tutti_uguali := true
		for dd in e["dadi"]:
			if int(dd["v"]) != int(e["dadi"][0]["v"]):
				tutti_uguali = false
		if tutti_uguali:
			e["pot"] = true
			_scrivi("Combinazione: %s si gira sulla faccia potenziata!" % nome_t)
			_evento({"t": "segreto", "p": p, "nome": nome_t})
	if tok(e["id"])["modo"] == "subito" and in_portata(e):
		_scatta(p, e, func(): poi.call(continua))
	else:
		if tok(e["id"])["modo"] == "armato":
			_scrivi("%s arma %s." % [g["nome"], nome_t])
			_evento({"t": "guardia", "p": p})
		poi.call(continua)

# ================================================================ token che scattano

func _togli_dado_alto(p: int) -> void:
	var mano: Array = s["g"][p]["mano"]
	if mano.is_empty():
		return
	var bi := 0
	for i in mano.size():
		if int(mano[i]["v"]) > int(mano[bi]["v"]):
			bi = i
	mano.remove_at(bi)
	_evento({"t": "blocco", "p": p, "n": 1})

func _togli_dado_basso(p: int) -> void:
	var mano: Array = s["g"][p]["mano"]
	if mano.is_empty():
		return
	var bi := 0
	for i in mano.size():
		if int(mano[i]["v"]) < int(mano[bi]["v"]):
			bi = i
	mano.remove_at(bi)
	_evento({"t": "blocco", "p": p, "n": 1})

func _togli_dado_caso(p: int) -> void:
	var mano: Array = s["g"][p]["mano"]
	if not mano.is_empty():
		mano.remove_at(rng.randi() % mano.size())
		_evento({"t": "blocco", "p": p, "n": 1})

func _usa_oggetto(e: Dictionary) -> void:
	if e.has("ogg_h"):
		var h: Vector2i = e["ogg_h"]
		s["cariche"][h] = int(s["cariche"].get(h, 1)) - 1

func _scatta(p: int, e: Dictionary, poi: Callable) -> void:
	var g: Dictionary = s["g"][p]
	var o := 1 - p
	var t := tok(e["id"])
	var eff: String = t["eff"]
	var sm := somma(e) + int(t["bonus"]) + (2 if e["pot"] else 0)
	if not in_portata(e):
		poi.call()
		return
	g["esterni"].erase(e)
	_usa_oggetto(e)
	_scrivi("%s: %s!" % [g["nome"], t["nome"]])
	var fine := func():
		_carica_raro(p, e, poi)
	match eff:
		"colpo", "colpo_stordente", "spinta":
			var dopo := func(dmg: int) -> void:
				if s["vinc"] < 0:
					if eff == "colpo_stordente" and dmg > 0:
						_svant(o, 2)
						_togli_dado_alto(o)
					if eff == "spinta" and dmg >= 0:
						spingi(p, o, 2)
						_svant(o, 1)
				fine.call()
			_attacco(p, sm, massimo(e), t["nome"], "colpo", dopo)
		"carica", "affondo":
			porta_contatto(p, 4 if eff == "carica" else 2, true)
			var dopo := func(_dmg: int) -> void:
				if eff == "affondo" and s["vinc"] < 0:
					allontana(p, 1)
				fine.call()
			_attacco(p, sm, massimo(e), t["nome"], "colpo", dopo)
		"balzo":
			porta_contatto(p, 3, true)
			_vant(p, 1 + (1 if e["pot"] else 0))
			if contatto():
				var dopo := func(_dmg: int) -> void:
					fine.call()
				_attacco(p, sm, massimo(e), t["nome"], "colpo", dopo)
			else:
				fine.call()
		"alle_spalle":
			alle_spalle(p)
			var dopo := func(_dmg: int) -> void:
				fine.call()
			_attacco(p, somma(e) + 2 + int(t["bonus"]), 6, t["nome"], "colpo", dopo)
		"lancio", "tizzone":
			_evento({"t": "lancio", "p": p, "bers": o, "oggetto": "pietra" if eff == "lancio" else "tizzone"})
			var dopo := func(dmg: int) -> void:
				if eff == "tizzone" and dmg > 0:
					_svant(o, 1)
				fine.call()
			_attacco(p, sm, massimo(e), t["nome"], "lancio", dopo, false)
		"acqua":
			_evento({"t": "getta", "p": p, "bers": o, "acqua": true})
			_svant(o, 2)
			_togli_dado_alto(o)
			fine.call()
		"sabbia":
			_evento({"t": "getta", "p": p, "bers": o, "acqua": false})
			_svant(o, 2)
			var best := -1
			var mano: Array = s["g"][o]["mano"]
			for i in mano.size():
				if mano[i]["c"] in ["b", "g", "n"] and (best < 0 or int(mano[i]["v"]) > int(mano[best]["v"])):
					best = i
			if best >= 0:
				mano[best]["v"] = 1
			fine.call()
		"cassa":
			_evento({"t": "azione", "p": p, "effetto": "rovescia", "nome": t["nome"]})
			_ferisci(o, 1)
			if s["vinc"] < 0:
				spingi(p, o, 1)
			fine.call()
		"sgambetto":
			_evento({"t": "attacco", "p": p, "bers": o, "dist": distanza(), "nome": "Spazzata", "genere": "colpo"})
			_ferisci(o, 1 + D(somma(e)) / 2 + (1 if e["pot"] else 0))
			if s["vinc"] < 0:
				_svant(o, 2)
				_togli_dado_basso(o)
			fine.call()
		"respiro":
			_evento({"t": "azione", "p": p, "effetto": "cura", "nome": t["nome"]})
			_cura(p, mini(3, (somma(e) + 1) / 2 + (1 if e["pot"] else 0)))
			g["svantaggi"] = 0
			fine.call()
		"provoca":
			_evento({"t": "azione", "p": p, "effetto": "stordisci", "nome": t["nome"]})
			_svant(o, 2 + (1 if e["pot"] else 0))
			_vant(p, 1)
			_togli_dado_alto(o)
			fine.call()
		"calma":
			_evento({"t": "azione", "p": p, "effetto": "concentrazione", "nome": t["nome"]})
			for i in 2 + (1 if e["pot"] else 0):
				g["mano"].append(_nuovo_dado(g["mucchio"][rng.randi() % g["mucchio"].size()]))
			fine.call()
		_:
			fine.call()

func _carica_raro(p: int, e: Dictionary, poi: Callable) -> void:
	var g: Dictionary = s["g"][p]
	var r: Dictionary = g["raro"]
	if s["vinc"] >= 0 or r.is_empty() or r["pronto"] or e["dadi"].is_empty():
		poi.call()
		return
	var t: Dictionary = rarip[r["id"]]
	var v := _tira()
	if v < int(reg["soglia_raro"]):
		poi.call()
		return
	r["dadi"].append({"c": "x", "v": v})
	_scrivi("Un %d sale fino all'anello raro (%s)." % [v, t["nome"]])
	if r["dadi"].size() >= int(t["dadi"]):
		r["pronto"] = true
		if t["eff"] in ["kiai", "ritorno"] or (t["eff"] == "tenchi" and contatto()):
			_scatta_raro(p, poi)
			return
	poi.call()

func _scatta_raro(p: int, poi: Callable) -> void:
	var g: Dictionary = s["g"][p]
	var o := 1 - p
	var r: Dictionary = g["raro"]
	var t: Dictionary = rarip[r["id"]]
	var sm := 0
	for dd in r["dadi"]:
		sm += int(dd["v"])
	_scrivi("%s scatena il token raro: %s!" % [g["nome"], t["nome"]])
	match t["eff"]:
		"tenchi":
			_evento({"t": "tecnica", "p": p, "bers": o, "nome": t["nome"], "genere": "proiezione"})
			_ferisci(o, D(sm))
			if s["vinc"] < 0:
				spingi(p, o, 3, true)
				_togli_dado_caso(o)
				_togli_dado_caso(o)
		"kiai":
			_evento({"t": "azione", "p": p, "effetto": "stordisci", "nome": "Kiai"})
			for x in s["g"][o]["esterni"]:
				if x["pronto"]:
					x["pronto"] = false
					x["dadi"] = []
			_svant(o, 2)
			_vant(p, 2)
		"ritorno":
			_evento({"t": "azione", "p": p, "effetto": "recupera", "nome": t["nome"]})
			for i in 2:
				g["mano"].append(_nuovo_dado(g["mucchio"][rng.randi() % g["mucchio"].size()]))
	g["raro"] = {}
	g["raro_usato"] = true
	poi.call()

# ================================================================ attacco e reazioni

## Modificatori di posizione: [danno in più, il difensore può scartare].
func mod_posizione(p: int) -> Array:
	if not contatto():
		return [0, true]
	var d := 1 - p
	var extra := 0
	if altezza(s["g"][p]["pos"]) > altezza(s["g"][d]["pos"]):
		extra += int(reg["danno_alto"])
	var dietro := alle_spalle_di(d, s["g"][p]["pos"])
	if dietro:
		extra += int(reg["danno_spalle"])
	return [extra, not dietro]

## Attacco di p. poi riceve il danno inflitto (-1 se annullato da una trappola).
## Se il difensore è umano e può reagire, il motore si ferma in fase "reazione".
func _attacco(p: int, danno: int, dado_max: int, nome: String, genere: String, poi: Callable, anima := true) -> void:
	var g: Dictionary = s["g"][p]
	var d := 1 - p
	var n: Dictionary = s["g"][d]
	if anima:
		_evento({"t": "attacco", "p": p, "bers": d, "dist": distanza(), "nome": nome, "genere": genere})
	danno = D(danno)
	var mp := mod_posizione(p)
	danno += int(mp[0])
	if mp[0] > 0:
		_scrivi("Posizione: +%d (%s)." % [mp[0], "alle spalle" if not mp[1] else "dall'alto"])
	if n["occhio"]:
		danno = maxi(0, danno - 1)
	var spesa := mini(int(g["vantaggi"]), int(reg["vant_per_colpo"]))
	if spesa > 0:
		danno += spesa
		_vant(p, -spesa)
	_scrivi("%s attacca con %s: %d." % [g["nome"], nome, danno])
	# guardia ferrea: riduzione passiva per tutto lo scambio
	for e in n["esterni"]:
		if e["pronto"] and not e["bloccato"] and tok(e["id"])["eff"] == "guardia":
			danno = maxi(0, danno - 2 - (1 if e["pot"] else 0))
			_scrivi("La Guardia ferrea assorbe il colpo.")
			_evento({"t": "para", "p": d})
			if not e["respinto"]:
				e["respinto"] = true
				_ferisci(p, 1)
			if danno == 0 or s["vinc"] >= 0:
				poi.call(0)
				return
			break
	# trappole armate
	var trap := []
	for e in n["esterni"]:
		if e["pronto"] and not e["bloccato"] and tok(e["id"])["eff"] in TRAPPOLE:
			trap.append(e)
	if not trap.is_empty():
		trap.sort_custom(func(a, b): return VALORE_TRAPPOLA[tok(a["id"])["eff"]] > VALORE_TRAPPOLA[tok(b["id"])["eff"]])
		_trappola(d, trap[0], danno, p, poi)
		return
	var pend := {"att": p, "dif": d, "danno": danno, "dado_max": dado_max, "scartare": bool(mp[1]), "nome": nome, "poi": poi}
	if n["umano"] and not opzioni_reazione(d, pend).is_empty():
		s["pend"] = pend
		s["fase"] = "reazione"
		return
	var scelta := _ia_reazione(d, pend)
	_risolvi_reazione(pend, scelta)

## Reazioni possibili del difensore a un attacco in sospeso.
func opzioni_reazione(d: int, pend: Dictionary = {}) -> Array:
	if pend.is_empty():
		pend = s["pend"]
	var n: Dictionary = s["g"][d]
	var out := []
	for dd in n["mano"]:
		var v := int(dd["v"])
		if dd["c"] in ["b", "n"]:
			out.append({"t": "parata", "dado": dd["id"], "riduce": D(v)})
		if pend["scartare"] and dd["c"] in ["g", "n"] and v >= int(pend["dado_max"]) - int(reg["scarto_tolleranza"]):
			out.append({"t": "scarto", "dado": dd["id"]})
	return out

func reagisci(d: int, scelta: Dictionary) -> String:
	if s["fase"] != "reazione" or int(s["pend"]["dif"]) != d:
		return "non c'è un colpo a cui reagire"
	var pend: Dictionary = s["pend"]
	s["pend"] = {}
	s["fase"] = "azione"
	_risolvi_reazione(pend, scelta)
	return ""

func _ia_reazione(d: int, pend: Dictionary) -> Dictionary:
	var danno := int(pend["danno"])
	var best := {}
	var best_resto := 999
	for op in opzioni_reazione(d, pend):
		var resto: int = 0 if op["t"] == "scarto" else maxi(0, danno - int(op["riduce"]))
		if resto < best_resto or (resto == best_resto and op["t"] == "parata"):
			best_resto = resto
			best = op
	if best.is_empty() or danno - best_resto < 1:
		return {"t": "nessuna"}
	var sc := best.duplicate()
	sc["gira"] = true
	sc["salita"] = {"modo": "auto"}
	return sc

func _risolvi_reazione(pend: Dictionary, scelta: Dictionary) -> void:
	var p: int = pend["att"]
	var d: int = pend["dif"]
	var n: Dictionary = s["g"][d]
	var danno: int = pend["danno"]
	var poi: Callable = pend["poi"]
	var tipo := String(scelta.get("t", "nessuna"))
	var i := dado_in_mano(d, int(scelta.get("dado", -1)))
	if tipo == "nessuna" or i < 0:
		_ferisci(d, danno)
		poi.call(danno)
		return
	var dd: Dictionary = n["mano"][i]
	n["mano"].remove_at(i)
	var v := _valore(d, int(dd["v"]))
	var c: String = dd["c"]
	var salita: Dictionary = scelta.get("salita", {"modo": "auto"})
	if tipo == "parata":
		_evento({"t": "para", "p": d})
		var rid := D(v)
		if scelta.get("gira", false) and int(n["vantaggi"]) >= 1 and not n["girate"].has("parata") and danno - v > 0:
			_vant(d, -1)
			n["girate"]["parata"] = true
			rid += 1
			_scrivi("%s gira la Parata: Parata ferrea!" % n["nome"])
			_ferisci(p, 1)
		var k := mini(int(n["vantaggi"]), mini(2, maxi(0, danno - rid)))
		if k > 0:
			_vant(d, -k)
			rid += k
		var resto := maxi(0, danno - rid)
		_scrivi("%s para con un %d: %s." % [n["nome"], v, "nessun danno" if resto == 0 else "passa %d" % resto])
		_ferisci(d, resto)
		if s["vinc"] >= 0:
			poi.call(resto)
			return
		if resto == 0:
			_vant(d, 1)
		if rid - danno >= 2:
			_ferisci(p, 1)
		if s["vinc"] >= 0:
			poi.call(resto)
			return
		_sali(d, c, "P", false, v, salita, func(_c): poi.call(resto))
	else:
		_evento({"t": "schiva", "p": d})
		_scrivi("%s scarta il colpo con un %d." % [n["nome"], v])
		allontana(d, 1)
		_vant(d, 1)
		if scelta.get("gira", false) and int(n["vantaggi"]) >= 1 and not n["girate"].has("scarto"):
			_vant(d, 1)
			n["girate"]["scarto"] = true
		_sali(d, c, "A", false, v, salita, func(_c): poi.call(0))

func _trappola(d: int, e: Dictionary, danno: int, att: int, poi: Callable) -> void:
	var n: Dictionary = s["g"][d]
	var t := tok(e["id"])
	var eff: String = t["eff"]
	var sm := D(somma(e)) + int(t["bonus"]) + (2 if e["pot"] else 0)
	n["esterni"].erase(e)
	_scrivi("Scatta la trappola di %s: %s!" % [n["nome"], t["nome"]])
	var inflitto := -1
	match eff:
		"schivata":
			_evento({"t": "schiva", "p": d})
			_vant(d, 1)
			if t["col"] == "verde":
				n["zanshin"] = 2
			_ferisci(att, 1 + int(t["bonus"]) + (1 if e["pot"] else 0))
		"irimi":
			_evento({"t": "azione", "p": d, "effetto": "gira_nemico", "nome": t["nome"]})
			_vant(d, 3 + (1 if e["pot"] else 0))
			_svant(att, 1)
			_ferisci(att, 1)
			s["iniziativa_a"] = d
			if s["vinc"] < 0:
				alle_spalle(d)
		"tenkan":
			_evento({"t": "azione", "p": d, "effetto": "ruota", "nome": t["nome"]})
			_vant(d, 1)
			_svant(att, 1)
			_ferisci(att, 1 + (1 if e["pot"] else 0))
			for x in n["mano"]:
				x["v"] = mini(6, int(x["v"]) + 1)
			_togli_dado_caso(att)
		"proiezione":
			_evento({"t": "tecnica", "p": d, "bers": att, "nome": t["nome"], "genere": "proiezione"})
			_ferisci(att, sm)
			if s["vinc"] < 0:
				spingi(d, att, 2, true)
		"immobilizza":
			_evento({"t": "tecnica", "p": d, "bers": att, "nome": t["nome"], "genere": "immobilizzazione"})
			_ferisci(att, (sm + 1) / 2)
			_svant(att, 1)
			_togli_dado_caso(att)
		"ukemi":
			_evento({"t": "azione", "p": d, "effetto": "recupera", "nome": t["nome"]})
			_vant(d, 1)
			n["svantaggi"] = 0
			_cura(d, 2 + (1 if e["pot"] else 0))
		"contrattacco":
			inflitto = maxi(0, danno - 3)
			_ferisci(d, inflitto)
			_evento({"t": "attacco", "p": d, "bers": att, "dist": 1, "nome": "contrattacco"})
			_ferisci(att, sm)
	var r := inflitto
	var dopo := func() -> void:
		var rr: Dictionary = n["raro"]
		if s["vinc"] < 0 and not rr.is_empty() and rr["pronto"] and rarip[rr["id"]]["eff"] == "tenchi":
			_scatta_raro(d, func(): poi.call(r))
		else:
			poi.call(r)
	_carica_raro(d, e, dopo)

# ================================================================ azioni

func puo_agire(p: int) -> bool:
	if s["vinc"] >= 0 or s["finito"][p]:
		return false
	var g: Dictionary = s["g"][p]
	if not g["mano"].is_empty() or not g["fermi"].is_empty():
		return true
	for e in g["esterni"]:
		if e["pronto"] and not e["bloccato"] and tok(e["id"])["modo"] == "subito" and in_portata(e):
			return true
	return not g["raro"].is_empty() and g["raro"]["pronto"] and contatto()

## Azioni possibili di un dado in mano (per l'interfaccia): elenco di id di azione base.
func azioni_dado(p: int, dd: Dictionary) -> Array:
	var out := []
	var c: String = dd["c"]
	var cont := contatto()
	var g: Dictionary = s["g"][p]
	if c in ["r", "n"] and cont:
		out.append_array(["colpo", "presa"])
	if c in ["g", "n"] and not g["tenuto"]:
		out.append("passo")
	if c in ["b", "n"]:
		out.append("leggi")
	return out

## op: {"t": "colpo"|"presa"|"passo"|"leggi"|"sali"|"gira"|"scatta"|"raro"|"passa", "dado": id, "fermo": i, "tok": i,
##      "pesante": bool, "dest": Vector2i, "via": bool, "salita": {"tok", "modo"}}
func esegui(p: int, op: Dictionary) -> String:
	if s["fase"] != "azione" or int(s["attivo"]) != p or s["vinc"] >= 0:
		return "non è il tuo turno"
	var g: Dictionary = s["g"][p]
	var o := 1 - p
	var t := String(op.get("t", "passa"))
	var salita: Dictionary = op.get("salita", {"modo": "auto"})
	match t:
		"passa":
			s["finito"][p] = true
			_scrivi("%s si ferma fino alla pausa." % g["nome"])
			_fine_azione(p, false)
		"colpo":
			var i := dado_in_mano(p, int(op.get("dado", -1)))
			if i < 0 or not contatto() or not g["mano"][i]["c"] in ["r", "n"]:
				return "il colpo vuole un dado rosso o bianco e il contatto"
			var dd: Dictionary = g["mano"][i]
			g["mano"].remove_at(i)
			var v := _valore(p, int(dd["v"]))
			var dmg := v
			if op.get("pesante", false) and int(g["vantaggi"]) >= 1 and not g["girate"].has("colpo"):
				_vant(p, -1)
				g["girate"]["colpo"] = true
				dmg += 2
				_scrivi("%s gira il Colpo: Colpo pesante!" % g["nome"])
			var dopo := func(_dmg: int) -> void:
				if s["vinc"] >= 0:
					s["fase"] = "fine"
					return
				_sali(p, dd["c"], "F", true, v, salita, func(cont): _fine_azione(p, cont))
			_attacco(p, dmg, v, "Colpo", "colpo", dopo)
		"presa":
			var i := dado_in_mano(p, int(op.get("dado", -1)))
			if i < 0 or not contatto() or not g["mano"][i]["c"] in ["r", "n"]:
				return "la presa vuole un dado rosso o bianco e il contatto"
			var dd: Dictionary = g["mano"][i]
			g["mano"].remove_at(i)
			var v := _valore(p, int(dd["v"]))
			_evento({"t": "attacco", "p": p, "bers": o, "dist": 1, "nome": "Presa", "genere": "presa"})
			_scrivi("%s afferra %s con un %d." % [g["nome"], s["g"][o]["nome"], v])
			_svant(o, 1)
			_togli_dado_alto(o)
			if v >= 5:
				s["g"][o]["tenuto"] = true
			if v >= int(reg["presa_soglia_spinta"]):
				spingi(p, o, 1)
			g["fermi"].append({"c": dd["c"], "az": "presa", "v": v})
			_fine_azione(p, false)
		"passo":
			var i := dado_in_mano(p, int(op.get("dado", -1)))
			if i < 0 or g["tenuto"] or not g["mano"][i]["c"] in ["g", "n"]:
				return "il passo vuole un dado giallo o bianco"
			var dd: Dictionary = g["mano"][i]
			g["mano"].remove_at(i)
			var v := _valore(p, int(dd["v"]))
			var k := 2 if v >= 5 else 1
			var aggirato := false
			if contatto() and not op.get("via", false):
				var dietro := aggira(p, 2 if v >= 4 else 1)
				_vant(p, 2 if dietro else 1)
				if v >= 5 or dietro:
					_svant(o, 1)
				_scrivi("%s aggira %s%s." % [g["nome"], s["g"][o]["nome"], " e arriva alle sue spalle" if dietro else ""])
				aggirato = true
			elif op.get("via", false):
				allontana(p, k)
				_scrivi("%s si allontana." % g["nome"])
			else:
				avvicina(p, k, op.get("dest", null))
				_scrivi("%s avanza di %s." % [g["nome"], plurale(k, "esagono", "esagoni")])
			g["fermi"].append({"c": dd["c"], "az": "passo", "v": v})
			_fine_azione(p, false, aggirato)
		"leggi":
			var i := dado_in_mano(p, int(op.get("dado", -1)))
			if i < 0 or not g["mano"][i]["c"] in ["b", "n"]:
				return "leggere il colpo vuole un dado blu o bianco"
			var dd: Dictionary = g["mano"][i]
			g["mano"].remove_at(i)
			var v := _valore(p, int(dd["v"]))
			_evento({"t": "azione", "p": p, "effetto": "leggi", "nome": "Leggere il colpo"})
			_vant(p, 2 if v >= 5 else 1)
			if v >= 4:
				_svant(o, 1)
			_scrivi("%s legge il colpo con un %d." % [g["nome"], v])
			g["fermi"].append({"c": dd["c"], "az": "leggi", "v": v})
			_fine_azione(p, false)
		"sali":
			var j := int(op.get("fermo", -1))
			if j < 0 or j >= g["fermi"].size():
				return "nessun dado fermo"
			var f: Dictionary = g["fermi"][j]
			if bersagli_salita(p, f["c"], AZ_SETTORE[f["az"]]).is_empty():
				return "nessun token su cui salire"
			g["fermi"].remove_at(j)
			_sali(p, f["c"], AZ_SETTORE[f["az"]], true, int(f["v"]), salita, func(cont): _fine_azione(p, cont))
		"gira":
			var j := int(op.get("fermo", -1))
			if j < 0 or j >= g["fermi"].size():
				return "nessun dado fermo"
			var f: Dictionary = g["fermi"][j]
			var az: String = f["az"]
			if g["girate"].has(az):
				return "quest'azione è già stata girata in questo scambio"
			g["fermi"].remove_at(j)
			g["girate"][az] = true
			match az:
				"presa":
					_scrivi("%s gira la Presa: Presa forte!" % g["nome"])
					_evento({"t": "azione", "p": p, "effetto": "disarma", "nome": "Presa forte"})
					_svant(o, 2)
					var cand: Array = s["g"][o]["esterni"].filter(func(e): return not e["bloccato"])
					if not cand.is_empty():
						cand.sort_custom(func(a, b): return a["dadi"].size() + (5 if a["pronto"] else 0) > b["dadi"].size() + (5 if b["pronto"] else 0))
						cand[0]["bloccato"] = true
						_scrivi("%s è bloccato fino alla pausa." % tok(cand[0]["id"])["nome"])
				"passo":
					_scrivi("%s gira il Passo: Balzo!" % g["nome"])
					porta_contatto(p, 3)
					_vant(p, 1)
				"leggi":
					_scrivi("%s gira la Lettura: Lettura profonda!" % g["nome"])
					_evento({"t": "azione", "p": p, "effetto": "leggi", "nome": "Lettura profonda"})
					_vant(p, 2)
					_vant(o, -2)
					g["occhio"] = true
			_fine_azione(p, false)
		"scatta":
			var j := int(op.get("tok", -1))
			if j < 0 or j >= g["esterni"].size():
				return "token inesistente"
			var e: Dictionary = g["esterni"][j]
			if not e["pronto"] or e["bloccato"] or tok(e["id"])["modo"] != "subito" or not in_portata(e):
				return "il token non può scattare ora"
			_scatta(p, e, func(): _fine_azione(p, false))
		"raro":
			if g["raro"].is_empty() or not g["raro"]["pronto"] or not contatto():
				return "il token raro non è pronto"
			_scatta_raro(p, func(): _fine_azione(p, false))
		_:
			return "azione sconosciuta"
	return ""

func _fine_azione(p: int, flusso: bool, aggirato := false) -> void:
	if s["vinc"] >= 0:
		s["fase"] = "fine"
		return
	if s["fase"] == "reazione":
		return
	if not aggirato:
		gira_verso(p)
	if flusso:
		s["g"][p]["flussi"] += 1
	if int(s["iniziativa_a"]) >= 0:
		s["attivo"] = s["iniziativa_a"]
		s["iniziativa_a"] = -1
	elif not flusso:
		s["attivo"] = 1 - p
	_avanza()

func _avanza() -> void:
	if s["vinc"] >= 0:
		s["fase"] = "fine"
		return
	if s["fase"] != "azione":
		return
	if not puo_agire(0) and not puo_agire(1):
		if int(s["scambio"]) >= int(reg["max_scambi"]):
			s["fase"] = "fine"
			var a: int = s["g"][0]["vita"]
			var b: int = s["g"][1]["vita"]
			s["vinc"] = 0 if a > b else (1 if b > a else 2)
			_scrivi("Il duello finisce ai punti.")
			return
		_pausa()
		return
	if not puo_agire(int(s["attivo"])):
		s["attivo"] = 1 - int(s["attivo"])

# ================================================================ intelligenza artificiale

func _trappole_nemiche(p: int) -> bool:
	for e in s["g"][1 - p]["esterni"]:
		if e["pronto"] and not e["bloccato"] and tok(e["id"])["eff"] in TRAPPOLE:
			return true
	return false

## Scelta dell'IA per l'azione di p (stessa logica del simulatore).
func ia_scegli(p: int) -> Dictionary:
	var g: Dictionary = s["g"][p]
	var n: Dictionary = s["g"][1 - p]
	var op := []
	var trap := _trappole_nemiche(p)
	var cont := contatto()
	for j in g["esterni"].size():
		var e: Dictionary = g["esterni"][j]
		if e["pronto"] and not e["bloccato"] and tok(e["id"])["modo"] == "subito" and in_portata(e):
			op.append([9.0, {"t": "scatta", "tok": j}])
	if not g["raro"].is_empty() and g["raro"]["pronto"] and cont:
		op.append([10.0, {"t": "raro"}])
	var blu := 0
	for dd in g["mano"]:
		if dd["c"] == "b":
			blu += 1
	var minaccia := false
	for dd in n["mano"]:
		if dd["c"] in ["r", "n"]:
			minaccia = true
	minaccia = minaccia and distanza() <= 2
	for dd in g["mano"]:
		var c: String = dd["c"]
		var v := int(dd["v"])
		var id: int = dd["id"]
		if c in ["r", "n"] and cont:
			var sc: float
			if trap:
				sc = 3.0 + (6 - v) * 0.3
			else:
				sc = v + mini(int(g["vantaggi"]), int(reg["vant_per_colpo"])) + 0.6 * bersagli_salita(p, "r" if c == "n" else c, "F").size()
				if c == "n":
					sc -= 0.8
			op.append([sc, {"t": "colpo", "dado": id, "pesante": int(g["vantaggi"]) >= 3}])
			var pr := 1.5 + (0.8 if not g["tenuto"] and not n["mano"].is_empty() else 0.0) + (1.0 if v >= 5 else 0.0)
			if v >= int(reg["presa_soglia_spinta"]) and spinta_utile(p):
				pr += 2.5
			op.append([pr, {"t": "presa", "dado": id}])
		if c in ["g", "n"] and not g["tenuto"]:
			if not cont:
				op.append([5.0 + v * 0.2, {"t": "passo", "dado": id}])
			elif trap and bersagli_salita(p, c, "A").is_empty():
				op.append([1.0, {"t": "passo", "dado": id, "via": true}])
			else:
				op.append([2.2 + 0.5 * bersagli_salita(p, c, "A").size() - (0.8 if c == "n" else 0.0), {"t": "passo", "dado": id}])
		if c in ["b", "n"]:
			var riserva := 2.0 if blu <= 1 and c == "b" and minaccia else 0.0
			op.append([1.8 - riserva + 0.5 * bersagli_salita(p, c, "P").size(), {"t": "leggi", "dado": id}])
	for j in g["fermi"].size():
		var f: Dictionary = g["fermi"][j]
		if not bersagli_salita(p, f["c"], AZ_SETTORE[f["az"]]).is_empty():
			op.append([4.0, {"t": "sali", "fermo": j}])
		if not g["girate"].has(f["az"]):
			if f["az"] == "presa" and cont:
				op.append([3.0, {"t": "gira", "fermo": j}])
			elif f["az"] == "passo" and not cont:
				op.append([4.5, {"t": "gira", "fermo": j}])
			elif f["az"] == "leggi":
				op.append([2.5, {"t": "gira", "fermo": j}])
	op = op.filter(func(x): return x[0] > 0)
	if op.is_empty():
		return {"t": "passa"}
	if rng.randf() < 0.12:
		return op[rng.randi() % op.size()][1]
	var best = op[0]
	var bv := -INF
	for x in op:
		var v: float = x[0] + rng.randf() * 0.8
		if v > bv:
			bv = v
			best = x
	return best[1]

## Gioca da solo fino alla fine (per i test e il banco): ritorna il vincitore (-1 pari).
func gioca_da_sola(limite := 4000) -> int:
	var passi := 0
	while s["vinc"] < 0 and passi < limite:
		passi += 1
		var chi := chi_decide()
		if chi < 0:
			break
		match s["fase"]:
			"reazione":
				reagisci(chi, _ia_reazione(chi, s["pend"]))
			"pausa":
				piazza(chi, _scegli_token(chi, posti_da_piazzare(chi)))
			_:
				var e := esegui(chi, ia_scegli(chi))
				if e != "":
					esegui(chi, {"t": "passa"})
	return int(s["vinc"]) if int(s["vinc"]) < 2 else -1
