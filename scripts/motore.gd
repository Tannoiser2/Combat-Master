class_name Motore
extends RefCounted
## Motore delle regole di Combat Master: stato della partita, dadi, iniziativa,
## reazioni, azzardo e movimento sugli esagoni. Nessuna dipendenza grafica:
## si usa uguale nell'interfaccia, nell'IA e nei test headless.

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
const RITMO_BASE := 3
const VITA_BASE := 10
const CONSERVA_BASE := 1
const DANNO_PERICOLO := 2
const DANNO_URTO := 2
const ROUND_MAX := 30

var cat: Dictionary = {}        # id token -> definizione
var dati: Dictionary = {}       # file tokens.json completo
var s: Dictionary = {}          # stato della partita
var rng := RandomNumberGenerator.new()
var simulazione := false        # true nelle copie usate dall'IA (niente diario)

# ---------------------------------------------------------------- catalogo

static func carica_dati() -> Dictionary:
	var f := FileAccess.open("res://data/tokens.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	var c := {}
	for t in d["token"]:
		c[t["id"]] = t
	d["per_id"] = c
	return d

static func costo_token(t: Dictionary, livello: int) -> int:
	if t.has("livelli"):
		return int(t["livelli"][clampi(livello, 1, t["livelli"].size()) - 1]["costo"])
	return int(t.get("costo", 0))

static func costo_personaggio(c: Dictionary, pg: Dictionary) -> int:
	var tot := 0
	for id in pg.get("token", {}):
		if c.has(id):
			tot += costo_token(c[id], int(pg["token"][id]))
	return tot

## Statistiche derivate da una scheda personaggio.
static func statistiche(c: Dictionary, pg: Dictionary) -> Dictionary:
	var st := {"dadi": {}, "vita": VITA_BASE, "ritmo": RITMO_BASE, "armatura": 0, "movimento": 0,
		"conserva": CONSERVA_BASE, "iniziativa": 0, "flag": {}}
	for id in pg.get("token", {}):
		if not c.has(id):
			continue
		var t: Dictionary = c[id]
		var lv := int(pg["token"][id])
		if t.has("livelli"):
			var L: Dictionary = t["livelli"][clampi(lv, 1, t["livelli"].size()) - 1]
			st["dadi"][t["colore"]] = int(st["dadi"].get(t["colore"], 0)) + int(L["dadi"])
			st["vita"] += int(L.get("vita", 0))
		var pas: Dictionary = t.get("passivo", {})
		for k in pas:
			match k:
				"vita": st["vita"] += int(pas[k])
				"ritmo": st["ritmo"] += int(pas[k])
				"armatura": st["armatura"] += int(pas[k])
				"movimento": st["movimento"] += int(pas[k])
				"conserva": st["conserva"] += int(pas[k])
				"iniziativa": st["iniziativa"] += int(pas[k])
				"bianco": st["dadi"]["bianco"] = int(st["dadi"].get("bianco", 0)) + int(pas[k])
				_: st["flag"][k] = int(st["flag"].get(k, 0)) + int(pas[k])
	st["ritmo"] = maxi(1, st["ritmo"])
	return st

# ---------------------------------------------------------------- avvio

func _init(d: Dictionary = {}) -> void:
	if not d.is_empty():
		dati = d
		cat = d["per_id"]

func nuova_partita(pg0: Dictionary, pg1: Dictionary, arena_id: String, seme: int = -1) -> void:
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
	var R := int(ar["raggio"])
	s = {"round": 0, "attivo": 0, "primo": -1, "fase": "azione", "pend": {}, "azz": {},
		"raggio": R, "ost": ost, "per": per, "arena": arena_id, "vinc": -1,
		"log": [], "eventi": [], "g": []}
	var partenze := [Vector2i(-(R - 2), 0), Vector2i(R - 2, 0)]
	var dirs := [0, 3]
	for i in 2:
		var pg: Dictionary = [pg0, pg1][i]
		var st := statistiche(cat, pg)
		var dadi := []
		var n := 0
		for col in ["rosso", "blu", "verde", "viola", "bianco"]:
			for k in int(st["dadi"].get(col, 0)):
				dadi.append({"id": n, "col": col, "v": 1, "st": "riserva"})
				n += 1
		s["g"].append({"nome": pg.get("nome", "Combattente"), "pg": pg.duplicate(true),
			"vita": st["vita"], "vita_max": st["vita"], "ritmo": st["ritmo"], "ritmo_usato": 0,
			"armatura": st["armatura"], "mov": st["movimento"], "conserva_max": st["conserva"],
			"ini": st["iniziativa"], "flag": st["flag"], "pos": partenze[i], "dir": dirs[i],
			"dadi": dadi, "passato": false, "spinte": 0, "usi": {}, "piazzati": {}})
	_nuovo_round()

# ---------------------------------------------------------------- utilità esagoni

static func dist(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return (absi(d.x) + absi(d.y) + absi(d.x + d.y)) / 2

static func mondo(h: Vector2i) -> Vector2:
	return Vector2(1.5 * h.x, sqrt(3.0) * (h.y + h.x * 0.5))

## Angolo (gradi, 0..180) fra l'orientamento `dir` di chi sta in `da` e la posizione `a`.
static func angolo(da: Vector2i, dir: int, a: Vector2i) -> float:
	if da == a:
		return 0.0
	return rad_to_deg(absf(mondo(DIRS[dir]).angle_to(mondo(a) - mondo(da))))

static func in_fronte(da: Vector2i, dir: int, a: Vector2i) -> bool:
	return angolo(da, dir, a) <= 90.5

## Da che lato `dif` (in pos, rivolto a dir) vede arrivare chi sta in `att`.
static func lato(pos: Vector2i, dir: int, att: Vector2i) -> String:
	var a := angolo(pos, dir, att)
	if a <= 90.5:
		return "fronte"
	if a < 149.5:
		return "fianco"
	return "retro"

static func dir_verso(da: Vector2i, a: Vector2i) -> int:
	var v := mondo(a) - mondo(da)
	var best := 0
	var bd := -INF
	for i in 6:
		var d := mondo(DIRS[i]).normalized().dot(v)
		if d > bd:
			bd = d
			best = i
	return best

func in_arena(h: Vector2i) -> bool:
	return dist(h, Vector2i.ZERO) <= int(s["raggio"])

func libero(h: Vector2i, ignora: int = -1) -> bool:
	if not in_arena(h) or s["ost"].has(h):
		return false
	for i in s["g"].size():
		if i != ignora and s["g"][i]["pos"] == h:
			return false
	return true

func linea_di_vista(a: Vector2i, b: Vector2i) -> bool:
	var n := dist(a, b)
	for i in range(1, n):
		var t := float(i) / n
		var h := _arrotonda_cubo(lerpf(a.x + 1e-4, b.x + 1e-4, t), lerpf(a.y + 1e-4, b.y + 1e-4, t))
		if s["ost"].has(h):
			return false
	return true

static func _arrotonda_cubo(q: float, r: float) -> Vector2i:
	var x := q
	var z := r
	var y := -x - z
	var rx := roundf(x)
	var ry := roundf(y)
	var rz := roundf(z)
	var dx := absf(rx - x)
	var dy := absf(ry - y)
	var dz := absf(rz - z)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))

## Stati raggiungibili (esagono+orientamento) con `mp` punti movimento.
## Avanti costa 1, di lato o indietro 2 (l'orientamento resta), girarsi di un lato 1.
func raggiungibili(p: int, mp: int) -> Dictionary:
	var g: Dictionary = s["g"][p]
	var start := Vector3i(g["pos"].x, g["pos"].y, g["dir"])
	var costo := {start: 0}
	var prec := {start: null}
	var secchi := []
	for i in mp + 1:
		secchi.append([])
	secchi[0].append(start)
	var lv := 0
	while lv <= mp:
		if secchi[lv].is_empty():
			lv += 1
			continue
		var cur: Vector3i = secchi[lv].pop_back()
		var c: int = costo[cur]
		if c != lv:
			continue
		var h := Vector2i(cur.x, cur.y)
		var vicini := []
		vicini.append([Vector3i(cur.x, cur.y, (cur.z + 1) % 6), 1])
		vicini.append([Vector3i(cur.x, cur.y, (cur.z + 5) % 6), 1])
		for k in 6:
			var nh: Vector2i = h + DIRS[k]
			if libero(nh, p):
				vicini.append([Vector3i(nh.x, nh.y, cur.z), 1 if k == cur.z else 2])
		for v in vicini:
			var nc: int = c + v[1]
			if nc <= mp and (not costo.has(v[0]) or nc < costo[v[0]]):
				costo[v[0]] = nc
				prec[v[0]] = cur
				secchi[nc].append(v[0])
	return {"costo": costo, "prec": prec}

static func percorso(rag: Dictionary, fine: Vector3i) -> Array:
	var out := []
	var cur = fine
	while cur != null:
		out.push_front(cur)
		cur = rag["prec"][cur]
	return out

# ---------------------------------------------------------------- dadi

func dadi_di(p: int, stato: String) -> Array:
	var out := []
	for d in s["g"][p]["dadi"]:
		if d["st"] == stato:
			out.append(d)
	return out

func dado(p: int, id: int) -> Dictionary:
	for d in s["g"][p]["dadi"]:
		if d["id"] == id:
			return d
	return {}

func _tira() -> int:
	return rng.randi_range(1, 6)

func ritmo_libero(p: int) -> int:
	return int(s["g"][p]["ritmo"]) - int(s["g"][p]["ritmo_usato"])

func puo_agire(p: int) -> bool:
	var g: Dictionary = s["g"][p]
	return not g["passato"] and ritmo_libero(p) > 0 and not dadi_di(p, "pronto").is_empty()

## Chi deve decidere adesso.
func chi_decide() -> int:
	if s["vinc"] >= 0:
		return -1
	match s["fase"]:
		"reazione":
			return int(s["pend"]["dif"])
		"azzardo":
			return int(s["azz"]["p"])
	return int(s["attivo"])

# ---------------------------------------------------------------- slot

func slot_def(tok: String, sid: String) -> Dictionary:
	if not cat.has(tok):
		return {}
	for sl in cat[tok]["slot"]:
		if sl["id"] == sid:
			return sl
	return {}

func slot_del_giocatore(p: int) -> Array:
	var out := []
	for tok in s["g"][p]["pg"]["token"]:
		if cat.has(tok):
			for sl in cat[tok]["slot"]:
				out.append([tok, sl])
	return out

static func colore_ok(col: String, ammessi: Array) -> bool:
	return col == "bianco" or ammessi.has(col)

## Riordina i dadi scelti perché rispettino i colori richiesti dallo slot; [] se impossibile.
func ordina_dadi(p: int, sl: Dictionary, ids: Array) -> Array:
	var req: Array = sl["dadi"]
	if ids.size() != req.size():
		return []
	for perm in _permutazioni(ids):
		var ok := true
		for i in perm.size():
			var d := dado(p, perm[i])
			if d.is_empty() or d["st"] != "pronto" or not colore_ok(d["col"], req[i]):
				ok = false
				break
		if ok and _condizione_ok(p, sl, perm):
			return perm
	return []

static func _permutazioni(a: Array) -> Array:
	if a.size() <= 1:
		return [a.duplicate()]
	var out := []
	for i in a.size():
		var resto := a.duplicate()
		var x = resto.pop_at(i)
		for p in _permutazioni(resto):
			p.push_front(x)
			out.append(p)
	return out

func _valori(p: int, ids: Array) -> Array:
	var v := []
	for id in ids:
		v.append(int(dado(p, id)["v"]))
	return v

func _condizione_ok(p: int, sl: Dictionary, ids: Array) -> bool:
	var v := _valori(p, ids)
	var c: Dictionary = sl.get("cond", {})
	if c.has("min"):
		for x in v:
			if x < int(c["min"]):
				return false
	if c.has("max"):
		for x in v:
			if x > int(c["max"]):
				return false
	if c.get("coppia", false):
		for x in v:
			if x != v[0]:
				return false
	if c.get("scala", false):
		var o := v.duplicate()
		o.sort()
		for i in range(1, o.size()):
			if o[i] != o[i - 1] + 1:
				return false
	if c.has("somma_min"):
		var t := 0
		for x in v:
			t += x
		if t < int(c["somma_min"]):
			return false
	if c.get("vs_attacco", false):
		if s["fase"] != "reazione" or v[0] < int(s["pend"].get("vd", 99)):
			return false
	return true

## Valore numerico prodotto dallo slot con i dadi dati.
func quantita(p: int, sl: Dictionary, ids: Array) -> int:
	if sl.has("fisso"):
		return int(sl["fisso"])
	var v := _valori(p, ids)
	var V := 0
	match sl.get("valore", "primo"):
		"primo": V = v[0]
		"secondo": V = v[min(1, v.size() - 1)]
		"somma":
			for x in v:
				V += x
		"max":
			for x in v:
				V = maxi(V, x)
	var div := int(sl.get("div", 1))
	var q := V
	if div > 1:
		q = int(ceil(float(V) / div)) if sl.get("arrotonda", "giu") == "su" else V / div
	return maxi(0, q + int(sl.get("bonus", 0)))

func _usa_dadi(p: int, tok: String, sid: String, ids: Array) -> void:
	var g: Dictionary = s["g"][p]
	var key := tok + "/" + sid
	var lista: Array = g["piazzati"].get(key, [])
	for id in ids:
		var d := dado(p, id)
		d["st"] = "usato"
		lista.append(id)
	g["piazzati"][key] = lista
	g["ritmo_usato"] += ids.size()

func _ricicla(p: int, ids: Array) -> void:
	var g: Dictionary = s["g"][p]
	if not g["flag"].has("riciclo") or g["usi"].get("riciclo", 0) > 0:
		return
	for id in ids:
		var d := dado(p, id)
		if d["v"] == 6:
			d["st"] = "pronto"
			d["v"] = _tira()
			g["usi"]["riciclo"] = 1
			for k in g["piazzati"]:
				g["piazzati"][k].erase(id)
			_scrivi("%s: Secondo respiro, il 6 torna pronto (ora %d)." % [g["nome"], d["v"]])
			_evento({"t": "dadi", "p": p})
			return

# ---------------------------------------------------------------- bersagli

## Bersagli validi di uno slot d'azione. Ogni bersaglio è un dizionario.
func bersagli(p: int, sl: Dictionary, ids: Array) -> Array:
	var g: Dictionary = s["g"][p]
	var o := 1 - p
	var go: Dictionary = s["g"][o]
	var out := []
	match sl["effetto"]:
		"attacco":
			if _attacco_possibile(p, sl, g["pos"], g["dir"]):
				out.append({"bers": o})
		"movimento":
			var mp := quantita(p, sl, ids) + int(g["mov"])
			var rag := raggiungibili(p, mp)
			for st in rag["costo"]:
				if st != Vector3i(g["pos"].x, g["pos"].y, g["dir"]):
					out.append({"pos": Vector2i(st.x, st.y), "dir": st.z})
		"assalto":
			var mp := int(dado(p, ids[0])["v"]) + int(g["mov"])
			var rag := raggiungibili(p, mp)
			for st in rag["costo"]:
				var h := Vector2i(st.x, st.y)
				if dist(h, go["pos"]) == 1 and in_fronte(h, st.z, go["pos"]):
					out.append({"pos": h, "dir": st.z})
		"ruota":
			for d in 6:
				if d != g["dir"]:
					out.append({"dir": d})
		"passo_ombra":
			for k in 6:
				var h: Vector2i = go["pos"] + DIRS[k]
				if libero(h, p) and dist(h, g["pos"]) <= int(sl.get("gittata", 4)) and h != g["pos"]:
					out.append({"pos": h, "dir": dir_verso(h, go["pos"])})
		"blocca_avversario":
			var V := quantita(p, sl, ids)
			if dist(g["pos"], go["pos"]) <= int(sl.get("gittata", 4)):
				for d in dadi_di(o, "pronto"):
					if d["v"] <= V:
						out.append({"bers": o})
						break
		"sblocca":
			if not dadi_di(p, "bloccato").is_empty():
				out.append({})
		"cura":
			if g["vita"] < g["vita_max"]:
				out.append({})
		"concentrazione":
			out.append({})
	return out

func _attacco_possibile(p: int, sl: Dictionary, pos: Vector2i, dir: int) -> bool:
	var o := 1 - p
	var tp: Vector2i = s["g"][o]["pos"]
	var d := dist(pos, tp)
	if sl.has("area"):
		return d == 1
	if d < int(sl.get("gittata_min", 1)) or d > int(sl.get("portata", 1)):
		return false
	if not sl.get("tutti_lati", false) and not in_fronte(pos, dir, tp):
		return false
	if sl.get("los", false) and not linea_di_vista(pos, tp):
		return false
	return true

## Reazioni che `dif` può usare contro l'attacco in sospeso.
func reazione_possibile(dif: int, sl: Dictionary) -> bool:
	if s["fase"] != "reazione" or sl["tipo"] != "reazione":
		return false
	var pe: Dictionary = s["pend"]
	if pe["annullato"]:
		return false
	if sl.get("quando", "qualsiasi") == "mischia" and not pe["mischia"]:
		return false
	match sl["effetto"]:
		"schiva":
			if pe["non_schivabile"]:
				return false
		"para":
			if pe["lato"] == "retro" and not sl.get("anche_retro", false):
				return false
		"contrattacco":
			var gd: Dictionary = s["g"][dif]
			var ap: Vector2i = s["g"][pe["att"]]["pos"]
			if pe["lato"] == "retro" or dist(gd["pos"], ap) > int(sl.get("portata", 1)) or pe.get("contro", 0) > 0:
				return false
	return true

# ---------------------------------------------------------------- opzioni

## Tutte le combinazioni di dadi pronti che soddisfano lo slot (senza doppioni equivalenti).
func combinazioni(p: int, sl: Dictionary) -> Array:
	var pronti := dadi_di(p, "pronto")
	var k: int = sl["dadi"].size()
	if k > ritmo_libero(p) or pronti.size() < k:
		return []
	var out := []
	var visti := {}
	for combo in _scelte(pronti, k):
		var ids := []
		for d in combo:
			ids.append(d["id"])
		var ord := ordina_dadi(p, sl, ids)
		if ord.is_empty():
			continue
		var firma := ""
		for id in ord:
			var d := dado(p, id)
			firma += "%s%d," % [d["col"], d["v"]]
		if visti.has(firma):
			continue
		visti[firma] = true
		out.append(ord)
	return out

static func _scelte(a: Array, k: int) -> Array:
	if k == 0:
		return [[]]
	if a.size() < k:
		return []
	var out := []
	for i in a.size():
		for resto in _scelte(a.slice(i + 1), k - 1):
			resto.push_front(a[i])
			out.append(resto)
	return out

## Elenco delle opzioni legali per chi decide (usato dall'IA e per i suggerimenti).
func opzioni(p: int) -> Array:
	var out := []
	if chi_decide() != p:
		return out
	match s["fase"]:
		"azione":
			for ts in slot_del_giocatore(p):
				var sl: Dictionary = ts[1]
				if sl["tipo"] != "azione":
					continue
				for ids in combinazioni(p, sl):
					for b in bersagli(p, sl, ids):
						out.append({"t": "slot", "tok": ts[0], "slot": sl["id"], "dadi": ids, "b": b})
			out.append({"t": "passa"})
		"reazione":
			for ts in slot_del_giocatore(p):
				var sl: Dictionary = ts[1]
				if not reazione_possibile(p, sl):
					continue
				for ids in combinazioni(p, sl):
					out.append({"t": "slot", "tok": ts[0], "slot": sl["id"], "dadi": ids, "b": {}})
			out.append({"t": "risolvi"})
		"azzardo":
			for d in dadi_di(p, "pronto"):
				if colore_ok(d["col"], ["rosso"]):
					out.append({"t": "rilancia", "dado": d["id"]})
					break
			out.append({"t": "ferma"})
	return out

func ha_reazioni(dif: int) -> bool:
	if ritmo_libero(dif) <= 0:
		return false
	for ts in slot_del_giocatore(dif):
		if reazione_possibile(dif, ts[1]) and not combinazioni(dif, ts[1]).is_empty():
			return true
	return false

# ---------------------------------------------------------------- esecuzione

## Applica un'opzione. Restituisce "" se va bene, altrimenti il motivo del rifiuto.
func applica(p: int, op: Dictionary) -> String:
	if s["vinc"] >= 0:
		return "La partita è finita."
	match op["t"]:
		"spinta":
			return _spinta(p, op["dadi"])
		"conserva":
			return _conserva(p, int(op["dado"]))
		"riprendi":
			return _riprendi(p, int(op["dado"]))
		"aggiusta":
			return _aggiusta(p, int(op["dado"]), int(op["d"]))
	if chi_decide() != p:
		return "Non tocca a te."
	match op["t"]:
		"passa":
			if s["fase"] != "azione":
				return "Ora non puoi passare."
			s["g"][p]["passato"] = true
			_scrivi("%s passa." % s["g"][p]["nome"])
			_dopo_azione(p, false)
			return ""
		"risolvi":
			if s["fase"] != "reazione":
				return "Nessun colpo da subire."
			_risolvi_attacco()
			return ""
		"rilancia":
			return _rilancia(p, int(op["dado"]))
		"ferma":
			if s["fase"] != "azzardo":
				return "Nessun azzardo in corso."
			var az: Dictionary = s["azz"]
			s["fase"] = "azione"
			s["azz"] = {}
			_scrivi("%s si ferma a %d." % [s["g"][p]["nome"], az["tot"]])
			_dichiara_attacco(p, az["sl"], az["tot"], az["vd"])
			return ""
		"slot":
			return _slot(p, op)
	return "Opzione sconosciuta."

func _slot(p: int, op: Dictionary) -> String:
	var sl := slot_def(op["tok"], op["slot"])
	if sl.is_empty() or not s["g"][p]["pg"]["token"].has(op["tok"]):
		return "Slot inesistente."
	var ids := ordina_dadi(p, sl, op["dadi"])
	if ids.is_empty():
		return "Questi dadi non vanno bene per %s." % sl["nome"]
	if ids.size() > ritmo_libero(p):
		return "Non hai abbastanza ritmo."
	var g: Dictionary = s["g"][p]
	if s["fase"] == "reazione":
		if not reazione_possibile(p, sl):
			return "Questa reazione ora non si può usare."
		_usa_dadi(p, op["tok"], op["slot"], ids)
		_reazione(p, sl, ids)
		_ricicla(p, ids)
		return ""
	if s["fase"] != "azione" or sl["tipo"] != "azione":
		return "Ora non puoi usare questo slot."
	var b: Dictionary = op.get("b", {})
	var trovato := false
	if sl["effetto"] in ["movimento", "assalto"]:
		if b.has("pos") and b.has("dir"):
			var mp0 := (quantita(p, sl, ids) if sl["effetto"] == "movimento" else int(dado(p, ids[0])["v"])) + int(s["g"][p]["mov"])
			var r0 := raggiungibili(p, mp0)
			var st0 := Vector3i(b["pos"].x, b["pos"].y, int(b["dir"]))
			trovato = r0["costo"].has(st0) and st0 != Vector3i(s["g"][p]["pos"].x, s["g"][p]["pos"].y, s["g"][p]["dir"])
			if sl["effetto"] == "assalto":
				var tp: Vector2i = s["g"][1 - p]["pos"]
				trovato = r0["costo"].has(st0) and dist(b["pos"], tp) == 1 and in_fronte(b["pos"], int(b["dir"]), tp)
	else:
		for v in bersagli(p, sl, ids):
			if _stesso_bersaglio(v, b):
				trovato = true
				break
	if not trovato:
		return "Bersaglio non valido."
	_usa_dadi(p, op["tok"], op["slot"], ids)
	var catena: bool = sl.get("catena", false)
	var o := 1 - p
	match sl["effetto"]:
		"attacco":
			var q := quantita(p, sl, ids)
			var vd := 0
			for v in _valori(p, ids):
				vd = maxi(vd, v)
			if sl.get("azzardo", false):
				s["fase"] = "azzardo"
				s["azz"] = {"p": p, "sl": sl, "tot": q, "vd": vd, "tok": op["tok"], "dadi": ids.duplicate()}
				_scrivi("%s scatena %s: %d. Rilancia o fermati." % [g["nome"], sl["nome"], q])
				_ricicla(p, ids)
				return ""
			_ricicla(p, ids)
			_dichiara_attacco(p, sl, q, vd)
			return ""
		"movimento":
			var mp := quantita(p, sl, ids) + int(g["mov"])
			var rag := raggiungibili(p, mp)
			var fine := Vector3i(b["pos"].x, b["pos"].y, b["dir"])
			var per := percorso(rag, fine)
			g["pos"] = b["pos"]
			g["dir"] = b["dir"]
			_scrivi("%s si muove." % g["nome"])
			_evento({"t": "muovi", "p": p, "percorso": per})
			_pericolo(p)
		"assalto":
			var mp := int(dado(p, ids[0])["v"]) + int(g["mov"])
			var rag := raggiungibili(p, mp)
			var per := percorso(rag, Vector3i(b["pos"].x, b["pos"].y, b["dir"]))
			g["pos"] = b["pos"]
			g["dir"] = b["dir"]
			_scrivi("%s carica!" % g["nome"])
			_evento({"t": "muovi", "p": p, "percorso": per})
			_pericolo(p)
			if s["vinc"] < 0:
				var att := sl.duplicate()
				att["portata"] = 1
				_ricicla(p, ids)
				_dichiara_attacco(p, att, quantita(p, sl, ids), int(dado(p, ids[1])["v"]))
				return ""
		"ruota":
			g["dir"] = int(b["dir"])
			_scrivi("%s si gira." % g["nome"])
			_evento({"t": "muovi", "p": p, "percorso": [Vector3i(g["pos"].x, g["pos"].y, g["dir"])]})
		"passo_ombra":
			g["pos"] = b["pos"]
			g["dir"] = b["dir"]
			_scrivi("%s scompare e riappare accanto a %s." % [g["nome"], s["g"][o]["nome"]])
			_evento({"t": "salto", "p": p, "pos": b["pos"], "dir": b["dir"]})
			_pericolo(p)
		"blocca_avversario":
			var V := quantita(p, sl, ids)
			var best := {}
			for d in dadi_di(o, "pronto"):
				if d["v"] <= V and (best.is_empty() or d["v"] > best["v"]):
					best = d
			if not best.is_empty():
				best["st"] = "bloccato"
				_scrivi("%s intimidisce %s: bloccato un suo %d." % [g["nome"], s["g"][o]["nome"], best["v"]])
				_evento({"t": "blocco", "p": o, "n": 1})
		"sblocca":
			var n := quantita(p, sl, ids)
			var k := 0
			for d in dadi_di(p, "bloccato"):
				if k >= n:
					break
				d["st"] = "pronto"
				d["v"] = _tira()
				k += 1
			_scrivi("%s riprende fiato: %s." % [g["nome"], plurale(k, "dado sbloccato", "dadi sbloccati")])
			_evento({"t": "dadi", "p": p})
		"cura":
			var n := mini(quantita(p, sl, ids), g["vita_max"] - g["vita"])
			g["vita"] += n
			_scrivi("%s si rigenera: +%d." % [g["nome"], n])
			_evento({"t": "cura", "p": p, "n": n})
		"concentrazione":
			var n := quantita(p, sl, ids)
			var bassi := dadi_di(p, "pronto")
			bassi.sort_custom(func(a, b2): return a["v"] < b2["v"])
			var k := 0
			for d in bassi:
				if k >= n or d["v"] > 3:
					break
				d["v"] = _tira()
				k += 1
			_scrivi("%s si concentra e ritira %s." % [g["nome"], plurale(k, "dado", "dadi")])
			_evento({"t": "dadi", "p": p})
	_ricicla(p, ids)
	_dopo_azione(p, catena)
	return ""

static func _stesso_bersaglio(a: Dictionary, b: Dictionary) -> bool:
	for k in a:
		if not b.has(k) or b[k] != a[k]:
			return false
	return true

func _rilancia(p: int, id: int) -> String:
	if s["fase"] != "azzardo":
		return "Nessun azzardo in corso."
	var d := dado(p, id)
	if d.is_empty() or d["st"] != "pronto" or not colore_ok(d["col"], ["rosso"]):
		return "Serve un tuo dado rosso pronto."
	var az: Dictionary = s["azz"]
	var g: Dictionary = s["g"][p]
	d["v"] = _tira()
	d["st"] = "usato"
	az["dadi"].append(id)
	var key: String = az["tok"] + "/" + az["sl"]["id"]
	g["piazzati"][key] = g["piazzati"].get(key, []) + [id]
	_evento({"t": "dadi", "p": p})
	if d["v"] == 1:
		for x in az["dadi"]:
			dado(p, x)["st"] = "bloccato"
		g["piazzati"].erase(key)
		s["fase"] = "azione"
		s["azz"] = {}
		_scrivi("%s esagera: esce 1! Il colpo fallisce e si bloccano %s." % [g["nome"], plurale(az["dadi"].size(), "dado", "dadi")])
		_evento({"t": "fallito", "p": p})
		_dopo_azione(p, false)
		return ""
	az["tot"] += d["v"]
	az["vd"] = maxi(az["vd"], d["v"])
	_scrivi("%s rilancia: %d (totale %d)." % [g["nome"], d["v"], az["tot"]])
	return ""

func _dichiara_attacco(p: int, sl: Dictionary, q: int, vd: int) -> void:
	var o := 1 - p
	var g: Dictionary = s["g"][p]
	var go: Dictionary = s["g"][o]
	var d := dist(g["pos"], go["pos"])
	var l := lato(go["pos"], go["dir"], g["pos"])
	var bonus := 0
	if l == "fianco":
		bonus += 1
	elif l == "retro":
		bonus += 2
	if g["flag"].has("berserker") and g["vita"] * 2 <= g["vita_max"]:
		bonus += 1
	if g["flag"].has("tiro") and d >= 2:
		bonus += 1
	s["pend"] = {"att": p, "dif": o, "danno": q, "bonus": bonus, "vd": vd, "mischia": d <= 2 and int(sl.get("portata", 1)) <= 2,
		"lato": l, "ignora": sl.get("ignora_armatura", false), "non_schivabile": sl.get("non_schivabile", false),
		"riduz": 0, "annullato": false, "contro": 0, "spingi": int(sl.get("spingi", 0)), "blocca": int(sl.get("blocca", 0)),
		"catena": sl.get("catena", false), "nome": sl["nome"], "ruba": false}
	var latotxt := "" if l == "fronte" else (" sul fianco" if l == "fianco" else " alle spalle")
	_scrivi("%s: %s%s, %s." % [g["nome"], sl["nome"], latotxt, plurale(q + bonus, "danno", "danni")])
	_evento({"t": "attacco", "p": p, "bers": o, "dist": d})
	s["fase"] = "reazione"
	if not ha_reazioni(o):
		_risolvi_attacco()

func _reazione(p: int, sl: Dictionary, ids: Array) -> void:
	var pe: Dictionary = s["pend"]
	var g: Dictionary = s["g"][p]
	match sl["effetto"]:
		"schiva":
			pe["annullato"] = true
			_scrivi("%s schiva!" % g["nome"])
			_evento({"t": "schiva", "p": p})
		"para":
			var q := quantita(p, sl, ids)
			pe["riduz"] += q
			_scrivi("%s: %s, -%d." % [g["nome"], sl["nome"], q])
			_evento({"t": "para", "p": p})
		"contrattacco":
			var q := quantita(p, sl, ids)
			pe["contro"] = maxi(1, q)
			pe["ruba"] = true
			if sl.get("para_pieno", false):
				pe["annullato"] = true
			_scrivi("%s: %s!" % [g["nome"], sl["nome"]])
			_evento({"t": "para", "p": p})
	# finché ha reazioni utili resta in fase di reazione, altrimenti si risolve
	if pe["annullato"] or not ha_reazioni(p):
		_risolvi_attacco()

func _risolvi_attacco() -> void:
	var pe: Dictionary = s["pend"]
	var att: int = pe["att"]
	var dif: int = pe["dif"]
	var ga: Dictionary = s["g"][att]
	var gd: Dictionary = s["g"][dif]
	s["fase"] = "azione"
	s["pend"] = {}
	if not pe["annullato"]:
		var arm: int = 0 if pe["ignora"] else int(gd["armatura"])
		var tot: int = maxi(0, int(pe["danno"]) + int(pe["bonus"]) - int(pe["riduz"]) - arm)
		_ferisci(dif, tot, "colpo")
		if s["vinc"] < 0 and pe["blocca"] > 0:
			var pronti := dadi_di(dif, "pronto")
			pronti.sort_custom(func(a, b): return a["v"] > b["v"])
			var n := 0
			for d in pronti:
				if n >= pe["blocca"]:
					break
				d["st"] = "bloccato"
				n += 1
			if n > 0:
				_scrivi("%s ha %s." % [gd["nome"], plurale(n, "dado bloccato", "dadi bloccati")])
				_evento({"t": "blocco", "p": dif, "n": n})
		if s["vinc"] < 0 and pe["spingi"] > 0:
			_spingi(att, dif, pe["spingi"])
	if s["vinc"] < 0 and pe["contro"] > 0:
		var arm2: int = int(ga["armatura"])
		var dn: int = maxi(0, int(pe["contro"]) - arm2)
		_evento({"t": "attacco", "p": dif, "bers": att, "dist": 1})
		_ferisci(att, dn, "contrattacco")
	if s["vinc"] >= 0:
		return
	if pe["ruba"] and puo_agire(dif):
		_scrivi("%s prende l'iniziativa!" % gd["nome"])
		s["attivo"] = dif
		_evento({"t": "iniziativa", "p": dif})
		return
	_dopo_azione(att, pe["catena"])

func _ferisci(p: int, n: int, causa: String) -> void:
	var g: Dictionary = s["g"][p]
	g["vita"] = maxi(0, g["vita"] - n)
	_evento({"t": "danno", "p": p, "n": n, "causa": causa})
	if n > 0:
		_scrivi("%s subisce %s (%d/%d)." % [g["nome"], plurale(n, "ferita", "ferite"), g["vita"], g["vita_max"]])
	else:
		_scrivi("%s non subisce danni." % g["nome"])
	if g["vita"] <= 0:
		s["vinc"] = 1 - p
		s["fase"] = "fine"
		_scrivi("%s è a terra. Vince %s!" % [g["nome"], s["g"][1 - p]["nome"]])
		_evento({"t": "ko", "p": p})

func _spingi(att: int, dif: int, n: int) -> void:
	var gd: Dictionary = s["g"][dif]
	var d := dir_verso(s["g"][att]["pos"], gd["pos"])
	var per := [Vector3i(gd["pos"].x, gd["pos"].y, gd["dir"])]
	var urto := false
	for i in n:
		var nh: Vector2i = gd["pos"] + DIRS[d]
		if not libero(nh, dif):
			urto = true
			break
		gd["pos"] = nh
		per.append(Vector3i(nh.x, nh.y, gd["dir"]))
	_evento({"t": "spinto", "p": dif, "percorso": per})
	if urto:
		_scrivi("%s sbatte contro un ostacolo!" % gd["nome"])
		_ferisci(dif, DANNO_URTO, "urto")
	if s["vinc"] < 0:
		_pericolo(dif)

func _pericolo(p: int) -> void:
	if s["per"].has(s["g"][p]["pos"]):
		_scrivi("%s è finito nel braciere!" % s["g"][p]["nome"])
		_ferisci(p, DANNO_PERICOLO, "fuoco")

func _dopo_azione(p: int, catena: bool) -> void:
	if s["vinc"] >= 0:
		return
	s["fase"] = "azione"
	var o := 1 - p
	if catena and puo_agire(p):
		s["attivo"] = p
	elif puo_agire(o):
		s["attivo"] = o
	elif puo_agire(p):
		s["attivo"] = p
	else:
		_fine_round()
		return
	_evento({"t": "iniziativa", "p": s["attivo"]})

# ---------------------------------------------------------------- spingere la fortuna e azioni libere

func costo_spinta(p: int) -> int:
	return 0 if int(s["g"][p]["spinte"]) == 0 else 1

func puo_azioni_libere(p: int) -> bool:
	return chi_decide() == p and s["fase"] in ["azione", "reazione"]

func _spinta(p: int, ids: Array) -> String:
	if not puo_azioni_libere(p):
		return "Non puoi spingere la fortuna adesso."
	if ids.is_empty():
		return "Scegli i dadi da ritirare."
	var g: Dictionary = s["g"][p]
	var c := costo_spinta(p)
	if c > ritmo_libero(p):
		return "Non hai ritmo per spingere ancora."
	for id in ids:
		var d := dado(p, id)
		if d.is_empty() or d["st"] != "pronto":
			return "Si ritirano solo dadi pronti."
	g["ritmo_usato"] += c
	g["spinte"] += 1
	var bloccati := 0
	var esiti := []
	for id in ids:
		var d := dado(p, id)
		d["v"] = _tira()
		esiti.append(str(d["v"]))
		if d["v"] == 1:
			if g["flag"].has("temerario") and g["usi"].get("temerario", 0) == 0:
				g["usi"]["temerario"] = 1
				_scrivi("%s, temerario: il primo 1 non blocca." % g["nome"])
			else:
				d["st"] = "bloccato"
				bloccati += 1
	_scrivi("%s spinge la fortuna: %s%s." % [g["nome"], ", ".join(esiti), ("" if bloccati == 0 else " (%s)" % plurale(bloccati, "bloccato", "bloccati"))])
	_evento({"t": "dadi", "p": p})
	if s["fase"] == "azione" and not puo_agire(p) and int(s["attivo"]) == p:
		_dopo_azione(p, false)
	return ""

func _conserva(p: int, id: int) -> String:
	if not puo_azioni_libere(p):
		return "Non puoi farlo adesso."
	var g: Dictionary = s["g"][p]
	var d := dado(p, id)
	if d.is_empty() or d["st"] != "pronto":
		return "Si conservano solo dadi pronti."
	if dadi_di(p, "conservato").size() >= int(g["conserva_max"]):
		return "Puoi conservare al massimo %d dadi." % g["conserva_max"]
	d["st"] = "conservato"
	_scrivi("%s conserva un %d per lo scambio seguente." % [g["nome"], d["v"]])
	_evento({"t": "dadi", "p": p})
	if s["fase"] == "azione" and not puo_agire(p) and int(s["attivo"]) == p:
		_dopo_azione(p, false)
	return ""

func _riprendi(p: int, id: int) -> String:
	if not puo_azioni_libere(p):
		return "Non puoi farlo adesso."
	var d := dado(p, id)
	if d.is_empty() or d["st"] != "conservato":
		return "Questo dado non è conservato."
	d["st"] = "pronto"
	_evento({"t": "dadi", "p": p})
	return ""

func _aggiusta(p: int, id: int, delta: int) -> String:
	if not puo_azioni_libere(p):
		return "Non puoi farlo adesso."
	var g: Dictionary = s["g"][p]
	if not g["flag"].has("aggiusta") or g["usi"].get("aggiusta", 0) > 0:
		return "Sangue freddo già usato in questo scambio."
	var d := dado(p, id)
	if d.is_empty() or d["st"] != "pronto":
		return "Serve un dado pronto."
	var nv := clampi(int(d["v"]) + delta, 1, 6)
	if nv == d["v"]:
		return "Il dado è già al limite."
	d["v"] = nv
	g["usi"]["aggiusta"] = 1
	_scrivi("%s, sangue freddo: il dado diventa %d." % [g["nome"], nv])
	_evento({"t": "dadi", "p": p})
	return ""

# ---------------------------------------------------------------- scambi (round)

func _fine_round() -> void:
	for p in 2:
		var g: Dictionary = s["g"][p]
		var liberato := false
		for d in g["dadi"]:
			if d["st"] in ["usato", "pronto"]:
				d["st"] = "riserva"
			elif d["st"] == "bloccato" and not liberato:
				d["st"] = "riserva"
				liberato = true
		g["piazzati"] = {}
	if int(s["round"]) >= ROUND_MAX:
		var a: float = float(s["g"][0]["vita"]) / s["g"][0]["vita_max"]
		var b: float = float(s["g"][1]["vita"]) / s["g"][1]["vita_max"]
		s["vinc"] = 0 if a >= b else 1
		s["fase"] = "fine"
		_scrivi("Tempo scaduto: vince ai punti %s." % s["g"][s["vinc"]]["nome"])
		_evento({"t": "ko", "p": 1 - s["vinc"]})
		return
	_nuovo_round()

func _nuovo_round() -> void:
	s["round"] += 1
	var ini := [0, 0]
	for p in 2:
		var g: Dictionary = s["g"][p]
		g["ritmo_usato"] = 0
		g["passato"] = false
		g["spinte"] = 0
		g["usi"] = {}
		for d in g["dadi"]:
			if d["st"] == "riserva":
				d["v"] = _tira()
				d["st"] = "pronto"
			elif d["st"] == "conservato":
				d["st"] = "pronto"
		for d in g["dadi"]:
			if d["st"] == "pronto" and d["col"] == "blu":
				ini[p] += d["v"]
		ini[p] += int(g["ini"])
	var primo: int
	if ini[0] != ini[1]:
		primo = 0 if ini[0] > ini[1] else 1
	else:
		primo = 1 - int(s["primo"]) if s["primo"] >= 0 else rng.randi_range(0, 1)
	s["primo"] = primo
	s["attivo"] = primo
	s["fase"] = "azione"
	_scrivi("--- Scambio %d: iniziativa a %s (%d contro %d)." % [s["round"], s["g"][primo]["nome"], ini[primo], ini[1 - primo]])
	_evento({"t": "round", "n": s["round"], "p": primo})
	for p in 2:
		_evento({"t": "dadi", "p": p})
	if not puo_agire(primo):
		if puo_agire(1 - primo):
			s["attivo"] = 1 - primo
		else:
			_fine_round()

# ---------------------------------------------------------------- diario ed eventi

static func plurale(n: int, uno: String, molti: String) -> String:
	return "%d %s" % [n, uno if n == 1 else molti]

func _scrivi(t: String) -> void:
	if not simulazione:
		s["log"].append(t)

func _evento(e: Dictionary) -> void:
	if not simulazione:
		s["eventi"].append(e)

func prendi_eventi() -> Array:
	var e: Array = s["eventi"]
	s["eventi"] = []
	return e

func clona() -> Motore:
	var m := Motore.new()
	m.dati = dati
	m.cat = cat
	m.s = s.duplicate(true)
	m.s["log"] = []
	m.s["eventi"] = []
	m.simulazione = true
	m.rng.seed = rng.randi()
	return m
