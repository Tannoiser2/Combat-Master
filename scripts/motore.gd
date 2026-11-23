class_name Motore
extends RefCounted
## Motore delle regole di Combat Master.
## I dadi girano in cerchio: per ogni azione si scelgono direttamente dal mucchio
## entro il Ritmo e i limiti cromatici dell'Attitudine. I dadi usati occupano i
## token o entrano in Attesa; il recupero li riporta nel mucchio.
## Nessuna dipendenza grafica: serve all'interfaccia, all'IA e ai test headless.

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
const COLORI := ["rosso", "blu", "verde", "viola", "bianco"]
const NOMI_COLORE := {"rosso": "rosso", "blu": "blu", "verde": "verde", "viola": "viola", "giallo": "giallo", "bianco": "bianco"}
const RITMO_BASE := 3
const VITA_BASE := 10
const CONSERVA_BASE := 1
const RECUPERO_BASE := 1
const DANNO_PERICOLO := 2
const DANNO_URTO := 2
const ROUND_MAX := 30
const PASSO_BASE := 2          # punti movimento dell'azione base senza dadi, una volta per scambio
const SUPPORTI_MAX := 2        # supporti per colpo, in attacco e in difesa
## Lati del corpo, dal davanti in senso antiorario visto dall'alto (1 = avanti a sinistra).
const NOMI_LATO := ["davanti", "avanti a sinistra", "dietro a sinistra", "dietro", "dietro a destra", "avanti a destra"]

## Regole di base regolabili (data/tokens.json, voce "regole"): ritmo, recupero, vita, conserva.
static var regole: Dictionary = {}

var cat: Dictionary = {}
var dati: Dictionary = {}
var s: Dictionary = {}
var rng := RandomNumberGenerator.new()
var simulazione := false

# ================================================================ catalogo

static func carica_dati() -> Dictionary:
	var f := FileAccess.open("res://data/tokens.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	var c := {}
	for t in d["token"]:
		c[t["id"]] = t
	d["per_id"] = c
	regole = d.get("regole", {})
	return d

## Le quattro caratteristiche obbligatorie: ogni combattente ha una e una sola scheda per ognuna.
const CARATTERISTICHE := ["rosso", "blu", "verde", "viola"]
const NOMI_CARATTERISTICA := {"rosso": "Forza", "blu": "Destrezza", "verde": "Tempra", "viola": "Mente"}

## Cosa manca o è doppio fra le caratteristiche del personaggio (vuoto se è tutto a posto).
static func problemi_caratteristiche(c: Dictionary, pg: Dictionary) -> Array:
	var conta := {}
	for id in pg.get("token", {}):
		if c.has(id) and c[id]["categoria"] == "attributo":
			var k: String = c[id].get("caratteristica", c[id].get("colore", ""))
			conta[k] = int(conta.get(k, 0)) + 1
	var out := []
	for k in CARATTERISTICHE:
		var n := int(conta.get(k, 0))
		if n == 0:
			out.append("manca la %s" % NOMI_CARATTERISTICA[k])
		elif n > 1:
			out.append("ci sono %d schede di %s" % [n, NOMI_CARATTERISTICA[k]])
	return out

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

static func statistiche(c: Dictionary, pg: Dictionary) -> Dictionary:
	var st := {"dadi": {}, "vita": int(regole.get("vita", VITA_BASE)), "ritmo": int(regole.get("ritmo", RITMO_BASE)), "armatura": 0, "movimento": 0,
		"conserva": int(regole.get("conserva", CONSERVA_BASE)), "recupero": int(regole.get("recupero", RECUPERO_BASE)), "iniziativa": 0, "flag": {}}
	for id in pg.get("token", {}):
		if not c.has(id):
			continue
		var t: Dictionary = c[id]
		var lv := int(pg["token"][id])
		var bonus: Dictionary = t.get("passivo", {}).duplicate()
		for col in t.get("produce", {}):
			st["dadi"][col] = int(st["dadi"].get(col, 0)) + int(t["produce"][col])
		if t.has("livelli"):
			var L: Dictionary = t["livelli"][clampi(lv, 1, t["livelli"].size()) - 1]
			st["dadi"][t["colore"]] = int(st["dadi"].get(t["colore"], 0)) + int(L["dadi"])
			for k in L:
				if k not in ["costo", "dadi"]:
					bonus[k] = int(bonus.get(k, 0)) + int(L[k])
		for k in bonus:
			match k:
				"vita", "ritmo", "armatura", "movimento", "conserva", "recupero", "iniziativa":
					st[k] += int(bonus[k])
				"bianco":
					st["dadi"]["bianco"] = int(st["dadi"].get("bianco", 0)) + int(bonus[k])
				_:
					st["flag"][k] = int(st["flag"].get(k, 0)) + int(bonus[k])
	st["ritmo"] = maxi(1, st["ritmo"])
	return st

# ================================================================ avvio

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
	var partenze := [Vector2i(-(R - 3), 0), Vector2i(R - 3, 0)]
	var dirs := [0, 3]
	for i in 2:
		var pg: Dictionary = [pg0, pg1][i]
		var st := statistiche(cat, pg)
		var dadi := []
		var n := 0
		for col in COLORI:
			for k in int(st["dadi"].get(col, 0)):
				dadi.append({"id": n, "col": col, "v": rng.randi_range(1, 6), "st": "mucchio"})
				n += 1
		s["g"].append({"nome": pg.get("nome", "Combattente"), "pg": pg.duplicate(true),
			"vita": st["vita"], "vita_max": st["vita"], "ritmo": st["ritmo"], "recupero": st["recupero"],
			"assetto": 0, "scambi_senza_attacco": 0, "attitudine": "neutrale", "attitudine_colore": "", "attitudine_punti": {}, "ultimo_colore_azione": "", "ritmo_speso": 0, "colori_spesi": {},
			"armatura": st["armatura"], "mov": st["movimento"], "conserva_max": st["conserva"],
			"ini": st["iniziativa"], "flag": st["flag"], "pos": partenze[i], "dir": dirs[i],
			"dadi": dadi, "occupati": {}, "passato": false, "spinte": 0, "usi": {}, "armati": {}, "rivelati": {}, "bonus_ritmo": 0,
			"carichi": {}, "disarmati": {}, "guardie": {}})
	_nuovo_round()

# ================================================================ esagoni

static func dist(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return (absi(d.x) + absi(d.y) + absi(d.x + d.y)) / 2

static func mondo(h: Vector2i) -> Vector2:
	return Vector2(1.5 * h.x, sqrt(3.0) * (h.y + h.x * 0.5))

static func angolo(da: Vector2i, dir: int, a: Vector2i) -> float:
	if da == a:
		return 0.0
	return rad_to_deg(absf(mondo(DIRS[dir]).angle_to(mondo(a) - mondo(da))))

static func in_fronte(da: Vector2i, dir: int, a: Vector2i) -> bool:
	return angolo(da, dir, a) <= 90.5

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

## Quanti lati separano due lati dell'esagono (0-3).
static func scarto_lati(a: int, b: int) -> int:
	var d := absi(a - b) % 6
	return mini(d, 6 - d)

## Lato del corpo di p (0 = davanti) rivolto verso l'esagono h.
func lato_rel(p: int, h: Vector2i) -> int:
	var g: Dictionary = s["g"][p]
	return (dir_verso(g["pos"], h) - int(g["dir"]) + 6) % 6

## Valore attuale di una guardia: il dado sullo spazio, diviso e corretto come dice lo spazio.
func valore_guardia(p: int, key: String) -> int:
	var ids := dadi_su(p, key)
	if ids.is_empty():
		return 0
	var parti: PackedStringArray = key.split("/")
	var sl := slot_def(parti[0], parti[1])
	var v := int(dado(p, ids[0])["v"])
	var dv := int(sl.get("guardia_div", 1))
	if dv > 1:
		v = int(ceil(float(v) / dv))
	return maxi(0, v + int(sl.get("guardia_bonus", 0)))

## Quanto riduce un colpo che arriva da h la guardia migliore di p: [riduzione, chiave].
func copertura(p: int, h: Vector2i) -> Array:
	var g: Dictionary = s["g"][p]
	if g["pos"] == h:
		return [0, ""]
	var rel := lato_rel(p, h)
	var best := 0
	var bk := ""
	for k in g["guardie"]:
		var r := maxi(0, valore_guardia(p, k) - scarto_lati(int(g["guardie"][k]["lato"]), rel))
		if r > best:
			best = r
			bk = k
	return [best, bk]

## La guardia si consuma: il suo dado perde n; a zero lo spazio si libera.
func _erodi_guardia(p: int, key: String, n: int) -> void:
	var ids := dadi_su(p, key)
	if ids.is_empty():
		s["g"][p]["guardie"].erase(key)
		return
	var d := dado(p, ids[0])
	d["v"] = int(d["v"]) - n
	if d["v"] <= 0:
		d["v"] = 1
		_libera(p, key)
		_scrivi("La guardia di %s cede." % s["g"][p]["nome"])
	_evento({"t": "dadi", "p": p})
	_evento({"t": "guardia", "p": p})

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

## Stati raggiungibili (esagono+orientamento): avanti 1, di lato o indietro 2, girarsi 1.
func raggiungibili(p: int, mp: int) -> Dictionary:
	var g: Dictionary = s["g"][p]
	var start := Vector3i(g["pos"].x, g["pos"].y, g["dir"])
	var costo := {start: 0}
	var prec := {start: null}
	var secchi := []
	for i in maxi(0, mp) + 1:
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
		var vicini := [[Vector3i(cur.x, cur.y, (cur.z + 1) % 6), 1], [Vector3i(cur.x, cur.y, (cur.z + 5) % 6), 1]]
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

# ================================================================ dadi

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

## Ogni dado che entra nel mucchio viene tirato: il mucchio è sempre visibile.
func _al_mucchio(d: Dictionary) -> void:
	d["st"] = "mucchio"
	d["v"] = maxi(_tira(), int(d.get("min_rientro", 1)))
	d.erase("min_rientro")

## Prende dal mucchio i dadi più alti (usato dagli effetti automatici dei segreti).
func _pesca_migliori(p: int, n: int) -> int:
	var mucchio := dadi_di(p, "mucchio")
	mucchio.sort_custom(func(a, b): return a["v"] > b["v"])
	var k := 0
	for d in mucchio:
		if k >= n:
			break
		d["st"] = "mano"
		k += 1
	return k

## Quanti dadi deve prendere ora dal mucchio chi sta pescando.
func da_prendere(p: int) -> int:
	var g: Dictionary = s["g"][p]
	var r := int(g["ritmo"]) + int(g["bonus_ritmo"])
	if g["vita"] * 2 <= g["vita_max"]:
		r -= 1
	return mini(maxi(1, r), dadi_di(p, "mucchio").size())

## Il Ritmo ora limita la selezione temporanea di ogni singola azione.
func ritmo_azione(p: int) -> int:
	var g: Dictionary = s["g"][p]
	var r := int(g["ritmo"]) + int(g.get("bonus_ritmo", 0))
	if g["vita"] * 2 <= g["vita_max"]:
		r -= 1
	return maxi(1, r)

const NOMI_ATTITUDINE := {"rosso": "aggressiva", "blu": "fluida", "verde": "guardinga", "viola": "concentrata"}

func limite_colore(p: int, colore: String) -> int:
	var r := ritmo_azione(p)
	if colore == "bianco" or String(s["g"][p].get("attitudine_colore", "")) == colore:
		return r
	return maxi(1, int(ceil(float(r) / 2.0)))

func ritmo_disponibile(p: int) -> int:
	return maxi(0, ritmo_azione(p) - int(s["g"][p].get("ritmo_speso", 0)))

func selezione_attitudine_ok(p: int, ids: Array) -> bool:
	if ids.size() > ritmo_disponibile(p):
		return false
	var conteggio: Dictionary = s["g"][p].get("colori_spesi", {}).duplicate()
	for id in ids:
		var d := dado(p, int(id))
		if d.is_empty() or not (d.get("st", "") in ["mucchio", "mano"]):
			return false
		var col: String = d["col"]
		conteggio[col] = int(conteggio.get(col, 0)) + 1
		if int(conteggio[col]) > limite_colore(p, col):
			return false
	return true

func _spendi_ritmo(p: int, ids: Array) -> void:
	var g: Dictionary = s["g"][p]
	g["ritmo_speso"] = int(g.get("ritmo_speso", 0)) + ids.size()
	for id in ids:
		var col: String = dado(p, int(id))["col"]
		g["colori_spesi"][col] = int(g["colori_spesi"].get(col, 0)) + 1

func _colore_attitudine(tok: String, sl: Dictionary) -> String:
	var eff: String = sl.get("effetto", "")
	if eff in ["attacco", "assalto", "supp_danno", "stordisci", "disarma", "rompi_guardia"]:
		return "rosso"
	if eff in ["movimento", "passo_ombra", "schiva", "contrattacco", "spingi", "attira"]:
		return "blu"
	if eff in ["para", "supp_difesa", "recupera", "sblocca", "cura", "guardia"]:
		return "verde"
	if cat.get(tok, {}).get("categoria", "") == "magia" or eff in ["concentrazione", "prepara_attesa", "scambia", "rovescia", "ritocca", "pesca"]:
		return "viola"
	return ""

func aggiorna_attitudine(p: int) -> void:
	var g: Dictionary = s["g"][p]
	var punti := {"rosso": 0, "blu": 0, "verde": 0, "viola": 0}
	for key in g["occupati"]:
		var parti: PackedStringArray = String(key).split("/")
		var sl := slot_def(parti[0], parti[1])
		var col := _colore_attitudine(parti[0], sl)
		if col != "":
			punti[col] += g["occupati"][key].size()
	var ultimo: String = g.get("ultimo_colore_azione", "")
	if ultimo != "" and int(g.get("assetto", 0)) != 0:
		punti[ultimo] = maxi(0, int(punti[ultimo]) + int(g["assetto"]))
	var migliore := ""
	var massimo := 1
	var pari := false
	for col in punti:
		if int(punti[col]) > massimo:
			massimo = int(punti[col])
			migliore = col
			pari = false
		elif int(punti[col]) == massimo and massimo >= 2:
			pari = true
	if pari and ultimo != "" and int(punti.get(ultimo, 0)) == massimo:
		migliore = ultimo
		pari = false
	if pari:
		migliore = ""
	g["attitudine_punti"] = punti
	g["attitudine_colore"] = migliore
	g["attitudine"] = NOMI_ATTITUDINE.get(migliore, "neutrale")
	_evento({"t": "attitudine", "p": p, "nome": g["attitudine"], "colore": migliore, "punti": punti.duplicate()})

func chi_decide() -> int:
	if s["vinc"] >= 0:
		return -1
	match s["fase"]:
		"pesca":
			return int(s["da_pescare"][0]) if not s.get("da_pescare", []).is_empty() else -1
		"rinforzo":
			return int(s["pend"]["att"])
		"reazione":
			return int(s["pend"]["dif"])
		"azzardo":
			return int(s["azz"]["p"])
	return int(s["attivo"])

func puo_agire(p: int) -> bool:
	return not s["g"][p]["passato"]

## Assetto misura equilibrio fisico e mentale. Resta volutamente piccolo:
## deve aprire linee tattiche, non sostituire dadi, token e posizionamento.
func cambia_assetto(p: int, delta: int, motivo: String = "") -> void:
	var g: Dictionary = s["g"][p]
	var prima := int(g.get("assetto", 0))
	g["assetto"] = clampi(prima + delta, -3, 3)
	var reale := int(g["assetto"]) - prima
	if reale == 0:
		return
	_scrivi("%s: Assetto %s%d%s (ora %+d)." % [g["nome"], "+" if reale > 0 else "", reale, (" per " + motivo) if motivo != "" else "", g["assetto"]])
	_evento({"t": "assetto", "p": p, "delta": reale, "valore": g["assetto"], "motivo": motivo})

# ================================================================ spazi

func slot_def(tok: String, sid: String) -> Dictionary:
	if not cat.has(tok):
		return {}
	for sl in cat[tok]["slot"]:
		if sl["id"] == sid:
			return sl
	return {}

static func chiave(tok: String, sid: String) -> String:
	return tok + "/" + sid

func slot_del_giocatore(p: int) -> Array:
	var out := []
	if cat.has("base"):
		for sl in cat["base"]["slot"]:
			out.append(["base", sl])
	for tok in s["g"][p]["pg"]["token"]:
		if tok == "base":
			continue
		if cat.has(tok):
			for sl in cat[tok]["slot"]:
				out.append([tok, sl])
	return out

func occupato(p: int, tok: String, sid: String) -> bool:
	var k := chiave(tok, sid)
	if not s["g"][p]["occupati"].has(k):
		return false
	var cap := int(slot_def(tok, sid).get("capienza", 0))
	return cap == 0 or s["g"][p]["occupati"][k].size() >= cap

func dadi_su(p: int, key: String) -> Array:
	return s["g"][p]["occupati"].get(key, [])

static func colore_ok(col: String, ammessi: Array) -> bool:
	return col == "bianco" or ammessi.has(col)

## Lo spazio è del tipo giusto per la fase e per chi decide (senza guardare i dadi).
func slot_attivabile(p: int, tok: String, sl: Dictionary) -> bool:
	if chi_decide() != p or occupato(p, tok, sl["id"]):
		return false
	if sl.get("una_volta", false) and int(s["g"][p]["usi"].get("slot:" + chiave(tok, sl["id"]), 0)) > 0:
		return false
	if s["g"][p].get("disarmati", {}).has(chiave(tok, sl["id"])):
		return false
	var f: String = s["fase"]
	match sl["tipo"]:
		"azione":
			return f == "azione"
		"libera":
			return f in ["azione", "rinforzo", "reazione"]
		"supporto_attacco":
			return f == "rinforzo" and int(s["pend"].get("supp_att", 0)) < SUPPORTI_MAX
		"supporto_difesa":
			return f == "reazione" and not s["pend"]["annullato"] and not s["pend"].get("imparabile", false) and int(s["pend"].get("supp_dif", 0)) < SUPPORTI_MAX
		"reazione":
			return reazione_possibile(p, sl)
		"segreto":
			return f == "azione"
		"contatore":
			return f == "azione" and not s["g"][p]["carichi"].has(chiave(tok, sl["id"]))
	return false

func ordina_dadi(p: int, sl: Dictionary, ids: Array) -> Array:
	var req: Array = sl["dadi"]
	if ids.size() != req.size() or not selezione_attitudine_ok(p, ids):
		return []
	for perm in _permutazioni(ids):
		var ok := true
		for i in perm.size():
			var d := dado(p, perm[i])
			if d.is_empty() or not (d["st"] in ["mucchio", "mano"]) or not colore_ok(d["col"], req[i]):
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

## I colori accettati da uno spazio, in parole: "rosso o blu", "blu + rosso".
static func testo_colori(req: Array) -> String:
	var parti := []
	for alloggio in req:
		parti.append(" o ".join(alloggio))
	return " + ".join(parti)

## La condizione sui valori di uno spazio, in parole.
func testo_condizione(sl: Dictionary) -> String:
	var c: Dictionary = sl.get("cond", {})
	var t := []
	if c.has("min") and c.has("max"):
		t.append("dado da %d a %d" % [int(c["min"]), int(c["max"])])
	elif c.has("min"):
		t.append("dado %d o più" % int(c["min"]))
	elif c.has("max"):
		t.append("dado %d o meno" % int(c["max"]) if int(c["max"]) > 1 else "dado 1")
	if c.get("coppia", false):
		t.append("dadi uguali")
	if c.get("scala", false):
		t.append("dadi in scala")
	if c.has("valori"):
		var w := []
		for x in c["valori"]:
			w.append(str(int(x)))
		t.append("i valori %s" % "-".join(w))
	if c.get("pari", false):
		t.append("dadi pari")
	if c.get("dispari", false):
		t.append("dadi dispari")
	if c.has("somma_min"):
		t.append("somma %d o più" % int(c["somma_min"]))
	if c.has("somma_max"):
		t.append("somma %d o meno" % int(c["somma_max"]))
	if c.has("somma_esatta"):
		t.append("somma esattamente %d" % int(c["somma_esatta"]))
	if c.get("vs_attacco", false):
		if s["fase"] == "reazione" and not s["pend"].is_empty():
			t.append("dado almeno %d (quanto il dado d'attacco)" % int(s["pend"].get("vd", 0)))
		else:
			t.append("dado almeno quanto il dado d'attacco, quando ti attaccano")
	return ", ".join(t)

## Perché questi dadi non vanno su questo spazio (vuoto se vanno bene).
func spiega_dadi(p: int, sl: Dictionary, ids: Array) -> String:
	var req: Array = sl["dadi"]
	if ids.size() != req.size():
		return "%s vuole %s (%s), ne hai scelti %d." % [sl["nome"], plurale(req.size(), "dado", "dadi"), testo_colori(req), ids.size()]
	for id in ids:
		if not (dado(p, id).get("st", "") in ["mucchio", "mano"]):
			return "Si usano solo dadi disponibili nel mucchio."
	if not selezione_attitudine_ok(p, ids):
		return "La selezione supera il Ritmo o il limite cromatico dell'Attitudine %s." % s["g"][p].get("attitudine", "neutrale")
	var colori_ok := false
	for perm in _permutazioni(ids):
		var ok := true
		for i in perm.size():
			if not colore_ok(dado(p, perm[i])["col"], req[i]):
				ok = false
		if ok:
			colori_ok = true
	if not colori_ok:
		return "%s accetta solo dadi %s." % [sl["nome"], testo_colori(req)]
	if not _condizione_ok(p, sl, ids):
		return "%s vuole: %s." % [sl["nome"], testo_condizione(sl)]
	return ""

## Perché nessun dado disponibile va su questo spazio.
func spiega_mano(p: int, sl: Dictionary) -> String:
	var req: Array = sl["dadi"]
	var mano := dadi_di(p, "mucchio") + dadi_di(p, "mano")
	var adatti := 0
	for d in mano:
		for alloggio in req:
			if colore_ok(d["col"], alloggio):
				adatti += 1
				break
	if adatti == 0:
		return "Non hai nel mucchio dadi %s per %s." % [testo_colori(req), sl["nome"]]
	if adatti < req.size():
		return "%s vuole %s (%s): non ne hai abbastanza disponibili." % [sl["nome"], plurale(req.size(), "dado", "dadi"), testo_colori(req)]
	return "Nessun dado disponibile va bene per %s, che vuole: %s." % [sl["nome"], testo_condizione(sl)]

func _condizione_ok(p: int, sl: Dictionary, ids: Array) -> bool:
	var v := _valori(p, ids)
	var c: Dictionary = sl.get("cond", {})
	for x in v:
		if c.has("min") and x < int(c["min"]):
			return false
		if c.has("max") and x > int(c["max"]):
			return false
	if c.get("coppia", false):
		for x in v:
			if x != v[0]:
				return false
	var o := v.duplicate()
	o.sort()
	if c.get("scala", false):
		for i in range(1, o.size()):
			if o[i] != o[i - 1] + 1:
				return false
	if c.has("valori"):
		var w: Array = c["valori"].duplicate()
		w.sort()
		for i in w.size():
			if int(w[i]) != o[i]:
				return false
	for x in v:
		if c.get("pari", false) and x % 2 != 0:
			return false
		if c.get("dispari", false) and x % 2 == 0:
			return false
	if c.has("somma_max"):
		var t2 := 0
		for x in v:
			t2 += x
		if t2 > int(c["somma_max"]):
			return false
	if c.has("somma_esatta"):
		var t3 := 0
		for x in v:
			t3 += x
		if t3 != int(c["somma_esatta"]):
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

func _piazza(p: int, tok: String, sid: String, ids: Array, sl: Dictionary) -> void:
	var g: Dictionary = s["g"][p]
	if sl.get("elimina_dado", false):
		for id in ids:
			dado(p, id)["st"] = "eliminato"
		_scrivi("%s sacrifica per sempre %s." % [g["nome"], plurale(ids.size(), "dado", "dadi")])
		return
	var restano := []
	for id in ids:
		var d := dado(p, id)
		if sl.get("in_attesa", false):
			d["st"] = "attesa"
			continue
		if d["v"] == 1 and g["flag"].has("riciclo") and g["usi"].get("riciclo", 0) == 0:
			g["usi"]["riciclo"] = 1
			d["st"] = "attesa"
			_scrivi("%s: niente si spreca, l'1 entra in Attesa anziche occupare il token." % g["nome"])
			continue
		if d["v"] == 1 and sl.get("uno_torna", false):
			d["st"] = "attesa"
			_scrivi("%s: l'1 entra in Attesa senza occupare il token." % g["nome"])
			continue
		d["st"] = "token"
		restano.append(id)
	if not restano.is_empty():
		var k := chiave(tok, sid)
		g["occupati"][k] = g["occupati"].get(k, []) + restano

## Tutti gli sblocchi inviano i dadi in Attesa: nessun salto diretto in mano.
func _libera(p: int, key: String, _in_mano := false) -> void:
	var g: Dictionary = s["g"][p]
	if not g["occupati"].has(key):
		return
	for id in g["occupati"][key]:
		var d := dado(p, id)
		d["st"] = "attesa"
	g["occupati"].erase(key)
	g["armati"].erase(key)
	g["carichi"].erase(key)
	g["guardie"].erase(key)
	aggiorna_attitudine(p)

# ================================================================ bersagli

func _mano_senza(p: int, ids: Array) -> Array:
	var out := []
	for d in dadi_di(p, "mucchio") + dadi_di(p, "mano"):
		if not ids.has(d["id"]):
			out.append(d)
	return out

## Bersagli validi di uno spazio dati i dadi che lo pagano.
func bersagli(p: int, tok: String, sl: Dictionary, ids: Array) -> Array:
	var g: Dictionary = s["g"][p]
	var o := 1 - p
	var go: Dictionary = s["g"][o]
	var out := []
	match sl["effetto"]:
		"attacco":
			if _attacco_possibile(p, sl, g["pos"], g["dir"]):
				if sl.get("guardia", false):
					for l in 6:
						out.append({"bers": o, "lato": l})
				elif sl.get("esagono", "") == "mira":
					for l in [0, 1, 5]:
						out.append({"bers": o, "lato": l})
				else:
					out.append({"bers": o})
		"guardia":
			for l in 6:
				out.append({"lato": l})
		"gira_guardia":
			for k in g["guardie"]:
				for dd in [1, 5]:
					out.append({"key": k, "lato": (int(g["guardie"][k]["lato"]) + dd) % 6})
		"ritocca_guardia":
			for k in g["guardie"]:
				var ids2 := dadi_su(p, k)
				if not ids2.is_empty() and int(dado(p, ids2[0])["v"]) < 6:
					out.append({"key": k})
		"scarta":
			for k in 6:
				var h: Vector2i = g["pos"] + DIRS[k]
				if libero(h, p):
					out.append({"pos": h})
		"gira_nemico":
			if dist(g["pos"], go["pos"]) <= int(sl.get("gittata", 1)):
				out.append({"bers": o, "d": 1})
				out.append({"bers": o, "d": 5})
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
		"stordisci":
			var V := quantita(p, sl, ids)
			if dist(g["pos"], go["pos"]) <= int(sl.get("gittata", 4)):
				for d in dadi_di(o, "mucchio") + dadi_di(o, "mano"):
					if d["v"] <= V:
						out.append({"bers": o})
						break
		"prepara_attesa":
			for ris in dadi_di(p, "attesa"):
				if not ids.has(ris["id"]) and int(ris.get("min_rientro", 1)) < int(sl.get("soglia", 4)):
					out.append({"dado": ris["id"]})
		"recupera":
			var riserva := dadi_di(p, "attesa")
			# Il giocatore sceglie quali dadi recuperare: il colore conta tanto quanto il valore.
			var massimo := mini(quantita(p, sl, ids), riserva.size())
			# Dare priorita al recupero pieno, ma limitare la ramificazione dell'IA.
			for n_rec in range(massimo, 0, -1):
				for gruppo in _scelte(riserva, n_rec):
					if out.size() >= 16:
						break
					var scelti := []
					for dado_att in gruppo:
						scelti.append(dado_att["id"])
					out.append({"dadi": scelti})
				if out.size() >= 16:
					break
		"sblocca":
			var chiavi: Array = g["occupati"].keys()
			chiavi.erase(chiave(tok, sl["id"]))
			chiavi.sort()
			var n := mini(quantita(p, sl, ids), chiavi.size())
			if n > 0:
				for c in _scelte(chiavi, n):
					out.append({"slots": c})
			elif int(sl.get("cura", 0)) > 0 and g["vita"] < g["vita_max"]:
				out.append({"slots": []})
		"cura":
			if g["vita"] < g["vita_max"]:
				out.append({})
		"concentrazione":
			for d in _mano_senza(p, ids):
				if d["v"] <= 3:
					out.append({})
					break
		"pesca":
			var mu := dadi_di(p, "mucchio")
			mu.sort_custom(func(a, b): return a["v"] > b["v"])
			var n := mini(quantita(p, sl, ids), mu.size())
			if n > 0:
				var visti := {}
				for c in _scelte(mu.slice(0, 7), n):
					var ids2 := []
					var firma := []
					for d in c:
						ids2.append(d["id"])
						firma.append("%s%d" % [d["col"], d["v"]])
					firma.sort()
					var k := ",".join(firma)
					if not visti.has(k):
						visti[k] = true
						out.append({"dadi": ids2})
		"segreto", "accumula", "contatore":
			out.append({})
		"disarma":
			if dist(g["pos"], go["pos"]) <= int(sl.get("gittata", 1)) and not _miglior_attacco_libero(o).is_empty():
				out.append({"bers": o})
		"congela":
			if dist(g["pos"], go["pos"]) <= int(sl.get("gittata", 3)):
				for d in dadi_di(o, "mucchio") + dadi_di(o, "mano"):
					if d["v"] > 1:
						out.append({"bers": o})
						break
		"eco":
			for d in _mano_senza(p, ids):
				if d["v"] != _valori(p, ids)[0]:
					out.append({"dado": d["id"]})
		"rimetti":
			if not dadi_di(p, "stordito").is_empty():
				out.append({})
		"elimina":
			var cols := {}
			for d in dadi_di(p, "mucchio"):
				cols[d["col"]] = true
			for c in cols:
				out.append({"col": c})
		"scambia":
			var m := _mano_senza(p, ids)
			for i in m.size():
				for j in range(i + 1, m.size()):
					if m[i]["v"] != m[j]["v"]:
						out.append({"a": m[i]["id"], "b": m[j]["id"]})
		"rovescia":
			for d in _mano_senza(p, ids):
				out.append({"dado": d["id"]})
		"ritocca":
			for d in _mano_senza(p, ids):
				if d["v"] < 6:
					out.append({"dado": d["id"], "d": 1})
				if d["v"] > 1:
					out.append({"dado": d["id"], "d": -1})
		"supp_danno", "supp_difesa", "schiva", "para", "contrattacco":
			out.append({})
	return out

func _attacco_possibile(p: int, sl: Dictionary, pos: Vector2i, dir: int) -> bool:
	var tp: Vector2i = s["g"][1 - p]["pos"]
	var d := dist(pos, tp)
	if sl.get("esecuzione", false):
		var go: Dictionary = s["g"][1 - p]
		if go["vita"] * 4 > go["vita_max"] or d != 1 or lato(go["pos"], go["dir"], pos) == "fronte":
			return false
	if sl.has("area"):
		return d == 1
	if d < int(sl.get("gittata_min", 1)) or d > int(sl.get("portata", 1)):
		return false
	if not in_fronte(pos, dir, tp):
		return false
	if sl.get("los", false) and not linea_di_vista(pos, tp):
		return false
	return true

func reazione_possibile(dif: int, sl: Dictionary) -> bool:
	if s["fase"] != "reazione" or sl["tipo"] != "reazione" or int(s["pend"]["dif"]) != dif:
		return false
	var pe: Dictionary = s["pend"]
	if pe["annullato"]:
		return false
	if sl.get("quando", "qualsiasi") == "mischia" and not pe["mischia"]:
		return false
	match sl["effetto"]:
		"schiva", "scarta":
			if pe["non_schivabile"]:
				return false
		"gira_guardia":
			if s["g"][dif]["guardie"].is_empty():
				return false
		"para":
			if pe["lato"] == "retro" and not sl.get("anche_retro", false):
				return false
			if pe.get("imparabile", false):
				return false
		"contrattacco":
			if pe.get("imparabile", false):
				return false
			var ap: Vector2i = s["g"][pe["att"]]["pos"]
			if pe["lato"] == "retro" or dist(s["g"][dif]["pos"], ap) > int(sl.get("portata", 1)) or pe.get("contro", 0) > 0:
				return false
	return true

# ================================================================ opzioni

func combinazioni(p: int, sl: Dictionary, limite: int = 0) -> Array:
	var mano := dadi_di(p, "mucchio") + dadi_di(p, "mano")
	var k: int = sl["dadi"].size()
	if mano.size() < k:
		return []
	# Con il mucchio intero, materializzare tutte le combinazioni per ogni clone
	# dell'IA è molto costoso. Alterniamo valori alti e bassi e interrompiamo la
	# generazione; l'interfaccia umana (limite 0) conserva invece l'insieme pieno.
	var candidati := mano
	var grezze: Array
	if limite > 0:
		var ordinati := mano.duplicate()
		ordinati.sort_custom(func(a, b): return a["v"] > b["v"] if a["v"] != b["v"] else COLORI.find(a["col"]) < COLORI.find(b["col"]))
		candidati = []
		var sx := 0
		var dx := ordinati.size() - 1
		while sx <= dx:
			candidati.append(ordinati[sx])
			sx += 1
			if sx <= dx:
				candidati.append(ordinati[dx])
				dx -= 1
		grezze = _scelte_limitate(candidati, k, maxi(48, limite * 10))
	else:
		grezze = _scelte(candidati, k)
	var out := []
	var visti := {}
	for combo in grezze:
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
		if limite > 0 and out.size() >= limite:
			break
	return out

static func _scelte_limitate(a: Array, k: int, limite: int) -> Array:
	var out := []
	if k == 1:
		for i in a.size():
			out.append([a[i]])
			if out.size() >= limite:
				break
	elif k == 2:
		for i in a.size():
			for j in range(i + 1, a.size()):
				out.append([a[i], a[j]])
				if out.size() >= limite:
					return out
	elif k == 3:
		for i in a.size():
			for j in range(i + 1, a.size()):
				for q in range(j + 1, a.size()):
					out.append([a[i], a[j], a[q]])
					if out.size() >= limite:
						return out
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

func opzioni(p: int) -> Array:
	var out := []
	if chi_decide() != p:
		return out
	var f: String = s["fase"]
	if f == "pesca":
		return out
	if f == "azzardo":
		for d in dadi_di(p, "mucchio") + dadi_di(p, "mano"):
			if colore_ok(d["col"], ["rosso"]):
				out.append({"t": "rilancia", "dado": d["id"]})
				break
		out.append({"t": "ferma"})
		return out
	for ts in slot_del_giocatore(p):
		var sl: Dictionary = ts[1]
		if not slot_attivabile(p, ts[0], sl):
			continue
		# L'interfaccia può esplorare tutte le combinazioni; l'IA riceve un
		# campione rappresentativo per non moltiplicare i cloni dell'intero stato.
		for ids in combinazioni(p, sl, 4):
			for b in bersagli(p, ts[0], sl, ids):
				out.append({"t": "slot", "tok": ts[0], "slot": sl["id"], "dadi": ids, "b": b})
	match f:
		"azione":
			for b in bersagli_passo(p):
				out.append({"t": "passo", "b": b})
			for k in opzioni_scarica(p):
				out.append({"t": "scarica", "key": k})
			for c in opzioni_recupero(p):
				out.append({"t": "passa", "slots": c})
			# Il recupero generico non deve sostituire il primo gesto offensivo:
			# diventa disponibile solo dopo avere attaccato nello scambio.
			if not dadi_di(p, "attesa").is_empty() and int(s["g"][p]["usi"].get("riposo", 0)) == 0 and int(s["g"][p]["usi"].get("attacchi", 0)) > 0:
				out.append({"t": "riposo"})
			if int(s["g"][p]["usi"].get("emergenza", 0)) == 0:
				for k in s["g"][p]["occupati"]:
					for d in dadi_di(p, "mucchio") + dadi_di(p, "mano"):
						out.append({"t": "emergenza", "key": k, "dado": d["id"]})
			# Il vantaggio può trasformarsi in fluidità: libera un gesto già
			# eseguito, ma i dadi devono comunque attraversare l'Attesa.
			if int(s["g"][p].get("assetto", 0)) >= 1 and int(s["g"][p]["usi"].get("flusso", 0)) == 0:
				for k in s["g"][p]["occupati"]:
					out.append({"t": "flusso", "key": k})
		"rinforzo":
			out.append({"t": "sferra"})
		"reazione":
			out.append({"t": "risolvi"})
			if int(s["g"][p].get("assetto", 0)) >= 1 and not s["pend"].get("annullato", false):
				out.append({"t": "adatta"})
			if int(s["g"][p].get("assetto", 0)) >= 2 and not s["pend"].get("annullato", false) and s["pend"].get("contro", 0) == 0 and s["pend"].get("lato", "fronte") != "retro":
				out.append({"t": "rovescio_fluido"})
	return out

## Contatori carichi che ora possono scaricarsi sul nemico.
func opzioni_scarica(p: int) -> Array:
	var out := []
	if s["fase"] != "azione" or chi_decide() != p:
		return out
	for k in s["g"][p]["carichi"]:
		var parti: PackedStringArray = k.split("/")
		var sl := slot_def(parti[0], parti[1])
		var car: Dictionary = sl.get("carica", {})
		if car.get("effetto", "") != "attacco" or dist(s["g"][p]["pos"], s["g"][1 - p]["pos"]) <= int(car.get("portata", 1)):
			out.append(k)
	return out

func _miglior_attacco_libero(o: int) -> String:
	var best := ""
	var bv := -1
	for ts in slot_del_giocatore(o):
		var sl: Dictionary = ts[1]
		var k := chiave(ts[0], sl["id"])
		if sl["effetto"] == "attacco" and sl["tipo"] == "azione" and not occupato(o, ts[0], sl["id"]) and not s["g"][o]["disarmati"].has(k):
			var v: int = int(sl.get("bonus", 0)) + int(sl.get("fisso", 3)) + sl["dadi"].size()
			if v > bv:
				bv = v
				best = k
	return best

## Azione base senza dadi: muoversi di PASSO_BASE, una volta per scambio.
func bersagli_passo(p: int) -> Array:
	var out := []
	var g: Dictionary = s["g"][p]
	if s["fase"] != "azione" or chi_decide() != p or g["usi"].get("passo", 0) > 0:
		return out
	var rag := raggiungibili(p, PASSO_BASE + int(g["mov"]))
	for st in rag["costo"]:
		if st != Vector3i(g["pos"].x, g["pos"].y, g["dir"]):
			out.append({"pos": Vector2i(st.x, st.y), "dir": st.z})
	return out

func _passo(p: int, b: Dictionary) -> String:
	var g: Dictionary = s["g"][p]
	if s["fase"] != "azione" or g["usi"].get("passo", 0) > 0:
		return "Il passo si fa una volta per scambio."
	var rag := raggiungibili(p, PASSO_BASE + int(g["mov"]))
	var fine := Vector3i(b["pos"].x, b["pos"].y, int(b["dir"]))
	if not rag["costo"].has(fine) or fine == Vector3i(g["pos"].x, g["pos"].y, g["dir"]):
		return "Destinazione non raggiungibile con un passo."
	g["usi"]["passo"] = 1
	var per := percorso(rag, fine)
	g["pos"] = b["pos"]
	g["dir"] = int(b["dir"])
	_scrivi("%s fa un passo." % g["nome"])
	_evento({"t": "muovi", "p": p, "percorso": per})
	_pericolo(p)
	_dopo_movimento(p)
	_dopo_azione(p, false)
	return ""

func opzioni_recupero(p: int) -> Array:
	var chiavi: Array = s["g"][p]["occupati"].keys()
	chiavi.sort()
	var n := mini(int(s["g"][p]["recupero"]), chiavi.size())
	return _scelte(chiavi, n)

## Ci sono spazi di supporto o di reazione utilizzabili adesso? (le libere non fermano il gioco)
func _ha_risposte(p: int) -> bool:
	if s["fase"] == "reazione" and int(s["g"][p].get("assetto", 0)) >= 1 and not s["pend"].get("annullato", false):
		return true
	var libere := false
	var chiuse := false
	var tipi := ["supporto_attacco"] if s["fase"] == "rinforzo" else ["reazione", "supporto_difesa"]
	for ts in slot_del_giocatore(p):
		var sl: Dictionary = ts[1]
		if sl["tipo"] == "azione":
			continue
		if sl["tipo"] in tipi and not occupato(p, ts[0], sl["id"]):
			chiuse = true
		if slot_attivabile(p, ts[0], sl) and not combinazioni(p, sl).is_empty():
			if sl["tipo"] != "libera":
				return true
			libere = true
	# un'azione libera (ritocco, rovescio, scambio...) può rendere usabile un supporto o una reazione
	return libere and chiuse

# ================================================================ esecuzione

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
	if chi_decide() != p:
		return "Non tocca a te."
	match op["t"]:
		"flusso":
			if s["fase"] != "azione" or int(s["g"][p].get("assetto", 0)) < 1 or int(s["g"][p]["usi"].get("flusso", 0)) > 0:
				return "Serve Assetto positivo; il flusso si usa una volta per scambio."
			var key_f := String(op.get("key", ""))
			if not s["g"][p]["occupati"].has(key_f):
				return "Lo spazio da sbloccare non è occupato."
			cambia_assetto(p, -1, "entrare nel flusso")
			s["g"][p]["usi"]["flusso"] = 1
			_libera(p, key_f)
			_scrivi("%s collega i gesti e libera %s: i dadi vanno in Attesa." % [s["g"][p]["nome"], key_f])
			_evento({"t": "dadi", "p": p})
			return ""
		"adatta":
			if s["fase"] != "reazione" or int(s["g"][p].get("assetto", 0)) < 1:
				return "Serve Assetto positivo per adattarsi al colpo."
			cambia_assetto(p, -1, "difesa fluida")
			s["pend"]["riduz"] += 2
			_scrivi("%s si adatta: -2 danni." % s["g"][p]["nome"])
			_evento({"t": "para", "p": p})
			_dopo_risposta()
			return ""
		"rovescio_fluido":
			if s["fase"] != "reazione" or int(s["g"][p].get("assetto", 0)) < 2 or s["pend"].get("contro", 0) > 0 or s["pend"].get("lato", "fronte") == "retro":
				return "Serve Assetto +2 e il nemico deve essere visibile."
			cambia_assetto(p, -2, "rovescio fluido")
			s["pend"]["riduz"] += 1
			s["pend"]["contro"] = 2
			s["pend"]["ruba"] = true
			_scrivi("%s accompagna il colpo: -1 danno e contrattacco 2." % s["g"][p]["nome"])
			_evento({"t": "para", "p": p})
			_dopo_risposta()
			return ""
		"prendi":
			return _prendi(p, op["dadi"])
		"emergenza":
			if s["fase"] != "azione":
				return "Lo sblocco di emergenza richiede una azione."
			var g_e: Dictionary = s["g"][p]
			if int(g_e["usi"].get("emergenza", 0)) > 0:
				return "Hai gia usato lo sblocco di emergenza."
			var key_e: String = str(op.get("key", ""))
			var d_e := dado(p, int(op.get("dado", -1)))
			if not g_e["occupati"].has(key_e) or d_e.is_empty() or not (d_e["st"] in ["mucchio", "mano"]):
				return "Scegli uno spazio occupato e un dado dalla mano."
			d_e["st"] = "attesa"
			_spendi_ritmo(p, [d_e["id"]])
			_libera(p, key_e)
			g_e["usi"]["emergenza"] = 1
			_scrivi("%s sacrifica un dado per sbloccare %s (dadi in Attesa)." % [g_e["nome"], key_e])
			_evento({"t": "dadi", "p": p})
			_dopo_azione(p, false)
			return ""
		"riposo":
			if s["fase"] != "azione":
				return "Puoi riposare solo nella fase azione."
			var g_r: Dictionary = s["g"][p]
			if int(g_r["usi"].get("riposo", 0)) > 0:
				return "Hai gia riposato in questo scambio."
			var in_attesa := dadi_di(p, "attesa")
			if in_attesa.is_empty():
				return "Non ci sono dadi in Attesa da recuperare."
			var n_r := mini(1, in_attesa.size())
			for i in n_r:
				_al_mucchio(in_attesa[i])
			g_r["usi"]["riposo"] = 1
			_scrivi("%s riposa: recupera %s dall Attesa." % [g_r["nome"], plurale(n_r, "dado", "dadi")])
			_evento({"t": "dadi", "p": p})
			_dopo_azione(p, false)
			return ""
		"passa":
			if s["fase"] != "azione":
				return "Ora non puoi passare."
			var sl: Array = op.get("slots", [])
			if sl.size() > int(s["g"][p]["recupero"]):
				return "Puoi liberare al massimo %s." % plurale(s["g"][p]["recupero"], "spazio", "spazi")
			for k in sl:
				if not s["g"][p]["occupati"].has(k):
					return "Questo spazio non è occupato."
			for k in sl:
				_libera(p, k)
			s["g"][p]["passato"] = true
			if not sl.is_empty():
				cambia_assetto(p, 1, "cedere l'iniziativa con controllo")
			_scrivi("%s passa%s." % [s["g"][p]["nome"], "" if sl.is_empty() else " e libera " + plurale(sl.size(), "spazio", "spazi")])
			_evento({"t": "dadi", "p": p})
			_dopo_azione(p, false)
			return ""
		"sferra":
			if s["fase"] != "rinforzo":
				return "Nessun colpo da sferrare."
			_vai_reazione()
			return ""
		"risolvi":
			if s["fase"] != "reazione":
				return "Nessun colpo da subire."
			_risolvi_attacco()
			return ""
		"rilancia":
			return _rilancia(p, int(op["dado"]))
		"scarica":
			return _scarica(p, String(op["key"]))
		"passo":
			return _passo(p, op["b"])
		"ferma":
			if s["fase"] != "azzardo":
				return "Nessun azzardo in corso."
			var az: Dictionary = s["azz"]
			s["fase"] = "azione"
			s["azz"] = {}
			_scrivi("%s si ferma a %d." % [s["g"][p]["nome"], az["tot"]])
			_dichiara_attacco(p, az["sl"], az["tot"], az["vd"], az.get("extra", {}))
			return ""
		"slot":
			return _slot(p, op)
	return "Opzione sconosciuta."

static func _stesso_bersaglio(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k):
			return false
		if a[k] is Array:
			if not (b[k] is Array):
				return false
			var x: Array = a[k].duplicate()
			var y: Array = b[k].duplicate()
			x.sort()
			y.sort()
			if x != y:
				return false
		elif a[k] != b[k]:
			return false
	return true

func _slot(p: int, op: Dictionary) -> String:
	var tok: String = op["tok"]
	var sl := slot_def(tok, op["slot"])
	if sl.is_empty() or (not s["g"][p]["pg"]["token"].has(tok) and tok != "base"):
		return "Spazio inesistente."
	if occupato(p, tok, sl["id"]):
		return "%s è occupato: prima va liberato." % sl["nome"]
	if not slot_attivabile(p, tok, sl):
		return "Ora non puoi usare %s." % sl["nome"]
	var ids := ordina_dadi(p, sl, op["dadi"])
	if ids.is_empty():
		return "Questi dadi non vanno bene per %s." % sl["nome"]
	var b: Dictionary = op.get("b", {})
	var trovato := false
	if sl["effetto"] == "pesca":
		var n := mini(quantita(p, sl, ids), dadi_di(p, "mucchio").size())
		var scelti: Array = b.get("dadi", [])
		trovato = n > 0 and scelti.size() == n
		var visti := {}
		for id in scelti:
			var d := dado(p, int(id))
			if d.is_empty() or d["st"] != "mucchio" or visti.has(id):
				trovato = false
			visti[id] = true
	elif sl["effetto"] in ["movimento", "assalto"]:
		if b.has("pos") and b.has("dir"):
			var mp0 := (quantita(p, sl, ids) if sl["effetto"] == "movimento" else int(dado(p, ids[0])["v"])) + int(s["g"][p]["mov"])
			var r0 := raggiungibili(p, mp0)
			var st0 := Vector3i(b["pos"].x, b["pos"].y, int(b["dir"]))
			var qui := Vector3i(s["g"][p]["pos"].x, s["g"][p]["pos"].y, s["g"][p]["dir"])
			trovato = r0["costo"].has(st0)
			if sl["effetto"] == "movimento":
				trovato = trovato and st0 != qui
			else:
				var tp: Vector2i = s["g"][1 - p]["pos"]
				trovato = trovato and dist(b["pos"], tp) == 1 and in_fronte(b["pos"], int(b["dir"]), tp)
	else:
		for v in bersagli(p, tok, sl, ids):
			if _stesso_bersaglio(v, b):
				trovato = true
				break
	if not trovato:
		return "Bersaglio non valido."
	var fase: String = s["fase"]
	var q := quantita(p, sl, ids)
	var vals := _valori(p, ids)
	_spendi_ritmo(p, ids)
	_piazza(p, tok, sl["id"], ids, sl)
	s["g"][p]["bonus_ritmo"] = 0
	var colore_azione := _colore_attitudine(tok, sl)
	if colore_azione != "":
		s["g"][p]["ultimo_colore_azione"] = colore_azione
	aggiorna_attitudine(p)
	if sl.get("una_volta", false):
		s["g"][p]["usi"]["slot:" + chiave(tok, sl["id"])] = 1
	_evento({"t": "dadi", "p": p})
	var g: Dictionary = s["g"][p]
	var o := 1 - p
	match sl["effetto"]:
		# ---------------- reazioni e supporti durante un colpo
		"schiva":
			cambia_assetto(p, 1, "schivata")
			s["pend"]["annullato"] = true
			_scrivi("%s: %s!" % [g["nome"], sl["nome"]])
			_evento({"t": "schiva", "p": p})
			_risolvi_attacco()
			return ""
		"para", "supp_difesa":
			cambia_assetto(p, 1, "parata")
			if sl["tipo"] == "supporto_difesa":
				s["pend"]["supp_dif"] = int(s["pend"].get("supp_dif", 0)) + 1
			s["pend"]["riduz"] += q
			if sl.get("no_spinta", false):
				s["pend"]["no_spinta"] = true
			s["pend"]["respingi"] = int(s["pend"].get("respingi", 0)) + int(sl.get("respingi", 0))
			_scrivi("%s: %s, -%d." % [g["nome"], sl["nome"], q])
			_evento({"t": "para", "p": p})
			_dopo_risposta()
			return ""
		"contrattacco":
			cambia_assetto(p, 1, "contrattacco")
			var pe: Dictionary = s["pend"]
			pe["contro"] = maxi(1, q)
			pe["ruba"] = true
			if sl.get("para_pieno", false):
				pe["annullato"] = true
			_scrivi("%s: %s!" % [g["nome"], sl["nome"]])
			_evento({"t": "para", "p": p})
			if pe["annullato"]:
				_risolvi_attacco()
			else:
				_dopo_risposta()
			return ""
		"supp_danno":
			var pe: Dictionary = s["pend"]
			pe["supp_att"] = int(pe.get("supp_att", 0)) + 1
			pe["danno"] += q
			if sl.get("ignora_armatura", false):
				pe["ignora"] = true
			if sl.get("non_schivabile", false):
				pe["non_schivabile"] = true
			if sl.get("catena", false):
				pe["catena"] = true
			pe["spingi"] += int(sl.get("spingi", 0))
			pe["gira"] = int(pe.get("gira", 0)) + int(sl.get("gira", 0))
			pe["rompi"] = int(pe.get("rompi", 0)) + int(sl.get("rompi_guardia", 0))
			if sl.has("poi"):
				pe["poi"] = sl["poi"]
			var extra := []
			if sl.get("ignora_armatura", false):
				extra.append("ignora l'armatura")
			if sl.get("non_schivabile", false):
				extra.append("non si schiva")
			_scrivi("%s: %s%s%s." % [g["nome"], sl["nome"], (", +%d" % q) if q > 0 else "", (", " + " e ".join(extra)) if not extra.is_empty() else ""])
			_dopo_risposta()
			return ""
		# ---------------- azioni
		"attacco":
			var vd := 0
			for v in vals:
				vd = maxi(vd, v)
			var extra := {}
			if b.has("lato"):
				if sl.get("guardia", false):
					var kg := chiave(tok, sl["id"])
					if not dadi_su(p, kg).is_empty():
						g["guardie"][kg] = {"lato": int(b["lato"])}
						_evento({"t": "guardia", "p": p})
				if sl.get("esagono", "") == "mira":
					extra["mira"] = (int(g["dir"]) + int(b["lato"])) % 6
			if sl.get("azzardo", false):
				s["fase"] = "azzardo"
				s["azz"] = {"p": p, "sl": sl, "tot": q, "vd": vd, "key": chiave(tok, sl["id"]), "extra": extra}
				_scrivi("%s scatena %s: %d. Rilancia o fermati." % [g["nome"], sl["nome"], q])
				return ""
			_dichiara_attacco(p, sl, q, vd, extra)
			return ""
		"guardia":
			var kg := chiave(tok, sl["id"])
			if not dadi_su(p, kg).is_empty():
				g["guardie"][kg] = {"lato": int(b["lato"])}
				_scrivi("%s si mette in guardia %s (%d)." % [g["nome"], NOMI_LATO[int(b["lato"])], valore_guardia(p, kg)])
				_evento({"t": "guardia", "p": p})
		"ritocca_guardia":
			var ids3 := dadi_su(p, String(b["key"]))
			var dg := dado(p, ids3[0])
			dg["v"] = mini(6, int(dg["v"]) + q)
			_scrivi("%s rafforza la guardia: ora vale %d." % [g["nome"], valore_guardia(p, String(b["key"]))])
			_evento({"t": "guardia", "p": p})
		"gira_guardia":
			g["guardie"][String(b["key"])]["lato"] = int(b["lato"])
			_scrivi("%s sposta la guardia %s." % [g["nome"], NOMI_LATO[int(b["lato"])]])
			_evento({"t": "guardia", "p": p})
			if fase == "reazione":
				_evento({"t": "dadi", "p": p})
				_dopo_risposta()
				return ""
		"scarta":
			var da0 := Vector3i(g["pos"].x, g["pos"].y, g["dir"])
			g["pos"] = b["pos"]
			_scrivi("%s scarta di lato." % g["nome"])
			_evento({"t": "muovi", "p": p, "percorso": [da0, Vector3i(g["pos"].x, g["pos"].y, g["dir"])]})
			_pericolo(p)
			if s["vinc"] >= 0:
				return ""
			if fase == "reazione":
				s["pend"]["scartato"] = true
				_evento({"t": "dadi", "p": p})
				_dopo_risposta()
				return ""
		"gira_nemico":
			var go2: Dictionary = s["g"][o]
			go2["dir"] = (int(go2["dir"]) + int(b["d"])) % 6
			_scrivi("%s fa girare %s." % [g["nome"], go2["nome"]])
			_evento({"t": "muovi", "p": o, "percorso": [Vector3i(go2["pos"].x, go2["pos"].y, go2["dir"])]})
		"movimento":
			var prima_pos: Vector2i = g["pos"]
			var prima_lato := lato(s["g"][o]["pos"], s["g"][o]["dir"], prima_pos)
			var rag := raggiungibili(p, q + int(g["mov"]))
			var per := percorso(rag, Vector3i(b["pos"].x, b["pos"].y, b["dir"]))
			g["pos"] = b["pos"]
			g["dir"] = b["dir"]
			var nuovo_lato := lato(s["g"][o]["pos"], s["g"][o]["dir"], g["pos"])
			if dist(g["pos"], s["g"][o]["pos"]) < dist(prima_pos, s["g"][o]["pos"]) or (prima_lato == "fronte" and nuovo_lato != "fronte"):
				cambia_assetto(p, 1, "movimento fluido")
			_scrivi("%s si muove." % g["nome"])
			_evento({"t": "muovi", "p": p, "percorso": per})
			_pericolo(p)
			_dopo_movimento(p)
		"assalto":
			var rag := raggiungibili(p, vals[0] + int(g["mov"]))
			var per := percorso(rag, Vector3i(b["pos"].x, b["pos"].y, b["dir"]))
			g["pos"] = b["pos"]
			g["dir"] = b["dir"]
			_scrivi("%s carica!" % g["nome"])
			_evento({"t": "muovi", "p": p, "percorso": per})
			_pericolo(p)
			_dopo_movimento(p)
			if s["vinc"] < 0:
				var att := sl.duplicate()
				att["portata"] = 1
				_dichiara_attacco(p, att, q, vals[1])
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
			_dopo_movimento(p)
		"stordisci":
			var best := {}
			for d in dadi_di(o, "mucchio") + dadi_di(o, "mano"):
				if d["v"] <= q and (best.is_empty() or d["v"] > best["v"]):
					best = d
			if not best.is_empty():
				best["st"] = "stordito"
				_scrivi("%s: %s, stordito un %d di %s." % [g["nome"], sl["nome"], best["v"], s["g"][o]["nome"]])
				_evento({"t": "blocco", "p": o, "n": 1})
				_evento({"t": "dadi", "p": o})
		"prepara_attesa":
			var preparato := dado(p, int(b["dado"]))
			preparato["min_rientro"] = maxi(int(preparato.get("min_rientro", 1)), int(sl.get("soglia", 4)))
			_scrivi("%s prepara un dado %s in Attesa: al recupero uscira almeno %d." % [g["nome"], preparato["col"], preparato["min_rientro"]])
		"recupera":
			var quanti := 0
			for id_att in b["dadi"]:
				var recuperato := dado(p, int(id_att))
				if recuperato.get("st", "") != "attesa":
					continue
				_al_mucchio(recuperato)
				if int(sl.get("bonus_dado", 0)) != 0:
					recuperato["v"] = clampi(int(recuperato["v"]) + int(sl["bonus_dado"]), 1, 6)
				quanti += 1
			if int(sl.get("cura", 0)) > 0 and quanti > 0:
				var salute := mini(int(sl["cura"]), g["vita_max"] - g["vita"])
				g["vita"] += salute
				if salute > 0:
					_evento({"t": "cura", "p": p, "n": salute})
			_scrivi("%s: %s, recupera %s dall'Attesa." % [g["nome"], sl["nome"], plurale(quanti, "dado", "dadi")])
		"sblocca":
			for k in b["slots"]:
				_libera(p, k, sl.get("in_mano", false))
			if int(sl.get("cura", 0)) > 0:
				var c := mini(int(sl["cura"]), g["vita_max"] - g["vita"])
				g["vita"] += c
				if c > 0:
					_evento({"t": "cura", "p": p, "n": c})
			_scrivi("%s: %s, %s." % [g["nome"], sl["nome"], plurale(b["slots"].size(), "spazio liberato", "spazi liberati")])
		"cura":
			var n := mini(q, g["vita_max"] - g["vita"])
			g["vita"] += n
			_scrivi("%s si rigenera: +%d." % [g["nome"], n])
			_evento({"t": "cura", "p": p, "n": n})
		"concentrazione":
			var bassi := dadi_di(p, "mucchio") + dadi_di(p, "mano")
			bassi.sort_custom(func(a, b2): return a["v"] < b2["v"])
			var k := 0
			for d in bassi:
				if k >= q or d["v"] > 3:
					break
				d["v"] = _tira()
				k += 1
			_scrivi("%s si concentra e ritira %s." % [g["nome"], plurale(k, "dado", "dadi")])
		"pesca":
			for id in b["dadi"]:
				dado(p, int(id))["st"] = "mano"
			_scrivi("%s: %s, prende %s dal mucchio." % [g["nome"], sl["nome"], plurale(b["dadi"].size(), "dado", "dadi")])
		"segreto":
			g["armati"][chiave(tok, sl["id"])] = {"q": q}
			_scrivi("%s prepara un segreto." % g["nome"])
		"accumula":
			_scrivi("%s: %s (%s sopra)." % [g["nome"], sl["nome"], plurale(dadi_su(p, chiave(tok, sl["id"])).size(), "dado", "dadi")])
		"contatore":
			var k := chiave(tok, sl["id"])
			var somma := 0
			for id in dadi_su(p, k):
				somma += int(dado(p, id)["v"])
			var soglia := int(sl.get("soglia", 10))
			if somma >= soglia:
				g["carichi"][k] = true
				_scrivi("%s: %s è carico (%d su %d)!" % [g["nome"], sl["nome"], somma, soglia])
			else:
				_scrivi("%s: %s a %d su %d." % [g["nome"], sl["nome"], somma, soglia])
		"disarma":
			var k := _miglior_attacco_libero(o)
			if k != "":
				s["g"][o]["disarmati"][k] = true
				var parti: PackedStringArray = k.split("/")
				_scrivi("%s disarma %s: %s bloccato fino a fine scambio." % [g["nome"], s["g"][o]["nome"], slot_def(parti[0], parti[1])["nome"]])
				_evento({"t": "blocco", "p": o, "n": 1})
		"congela":
			var best := {}
			for d in dadi_di(o, "mucchio") + dadi_di(o, "mano"):
				if best.is_empty() or d["v"] > best["v"]:
					best = d
			if not best.is_empty():
				_scrivi("%s: %s, il %d di %s diventa 1." % [g["nome"], sl["nome"], best["v"], s["g"][o]["nome"]])
				best["v"] = 1
				_evento({"t": "blocco", "p": o, "n": 1})
				_evento({"t": "dadi", "p": o})
		"eco":
			var d := dado(p, int(b["dado"]))
			d["v"] = vals[0]
			_scrivi("%s: %s, un dado in mano diventa %d." % [g["nome"], sl["nome"], d["v"]])
		"rimetti":
			var k := 0
			for d in dadi_di(p, "stordito"):
				d["st"] = "mano"
				d["v"] = _tira()
				k += 1
			_scrivi("%s: %s, %s di nuovo in mano." % [g["nome"], sl["nome"], plurale(k, "dado", "dadi")])
		"elimina":
			for d in dadi_di(p, "mucchio"):
				if d["col"] == b["col"]:
					d["st"] = "eliminato"
					break
			var k := _pesca_migliori(p, int(sl.get("pesca", 0)))
			_scrivi("%s elimina un dado %s dal mucchio e prende %s." % [g["nome"], NOMI_COLORE.get(b["col"], b["col"]), plurale(k, "dado", "dadi")])
		"scambia":
			var da := dado(p, int(b["a"]))
			var db := dado(p, int(b["b"]))
			var t: int = da["v"]
			da["v"] = db["v"]
			db["v"] = t
			_scrivi("%s scambia i valori di due dadi in mano (%d e %d)." % [g["nome"], db["v"], da["v"]])
		"rovescia":
			var d := dado(p, int(b["dado"]))
			d["v"] = 7 - int(d["v"])
			_scrivi("%s: %s, il dado diventa %d." % [g["nome"], sl["nome"], d["v"]])
		"ritocca":
			var d := dado(p, int(b["dado"]))
			d["v"] = clampi(int(d["v"]) + int(b["d"]), 1, 6)
			_scrivi("%s: %s, il dado diventa %d." % [g["nome"], sl["nome"], d["v"]])
	_evento({"t": "dadi", "p": p})
	if sl["tipo"] in ["azione", "segreto"]:
		_dopo_azione(p, sl.get("catena", false))
	elif fase == "rinforzo" and s["fase"] == "rinforzo" and not _ha_risposte(p):
		_vai_reazione()
	return ""

func _dopo_risposta() -> void:
	if s["vinc"] >= 0:
		return
	match s["fase"]:
		"rinforzo":
			if not _ha_risposte(int(s["pend"]["att"])):
				_vai_reazione()
		"reazione":
			if not _ha_risposte(int(s["pend"]["dif"])):
				_risolvi_attacco()

func _rilancia(p: int, id: int) -> String:
	if s["fase"] != "azzardo":
		return "Nessun azzardo in corso."
	var d := dado(p, id)
	if d.is_empty() or not (d["st"] in ["mucchio", "mano"]) or not colore_ok(d["col"], ["rosso"]):
		return "Serve un tuo dado rosso disponibile."
	var az: Dictionary = s["azz"]
	var g: Dictionary = s["g"][p]
	d["v"] = _tira()
	d["st"] = "token"
	var key: String = az["key"]
	g["occupati"][key] = g["occupati"].get(key, []) + [id]
	_evento({"t": "dadi", "p": p})
	if d["v"] == 1:
		var n: int = g["occupati"][key].size()
		for x in g["occupati"][key]:
			dado(p, x)["st"] = "stordito"
		g["occupati"].erase(key)
		s["fase"] = "azione"
		s["azz"] = {}
		_scrivi("%s esagera: esce 1! Il colpo fallisce e restano storditi %s." % [g["nome"], plurale(n, "dado", "dadi")])
		_evento({"t": "fallito", "p": p})
		_dopo_azione(p, false)
		return ""
	az["tot"] += d["v"]
	az["vd"] = maxi(az["vd"], d["v"])
	_scrivi("%s rilancia: %d (totale %d)." % [g["nome"], d["v"], az["tot"]])
	return ""

func _dichiara_attacco(p: int, sl: Dictionary, q: int, vd: int, extra: Dictionary = {}) -> void:
	var o := 1 - p
	var g: Dictionary = s["g"][p]
	var go: Dictionary = s["g"][o]
	g["usi"]["attacchi"] = int(g["usi"].get("attacchi", 0)) + 1
	var d := dist(g["pos"], go["pos"])
	var l := lato(go["pos"], go["dir"], g["pos"])
	# La selezione differita dal mucchio trova più facilmente il dado ideale.
	# Un punto di attrito compensa questa flessibilità sui danni base, senza
	# aumentare vita o armatura e senza toccare bonus, fianchi ed effetti.
	var impatto := maxi(0, q - int(regole.get("attrito_mucchio", 0)))
	var bonus := 0
	# L'Assetto positivo può essere convertito in precisione. Si spende al
	# massimo un punto per colpo, evitando esplosioni di danno.
	if int(g.get("assetto", 0)) > 0:
		bonus += 1
		cambia_assetto(p, -1, "precisione dell'attacco")
	if l == "fianco":
		bonus += 1
	elif l == "retro":
		bonus += 2
	if g["flag"].has("berserker") and g["vita"] * 2 <= g["vita_max"]:
		bonus += 1
	if g["flag"].has("tiro") and d >= 2:
		bonus += 1
	if l != "fronte":
		bonus += int(sl.get("bonus_spalle", 0))
	if g["vita"] * 2 <= g["vita_max"]:
		bonus += int(sl.get("bonus_ferito", 0))
	if sl.has("bonus_occupati"):
		bonus += mini(int(sl["bonus_occupati"]), g["occupati"].size())
	if vd == 6:
		bonus += int(sl.get("se_sei", 0))
	bonus += _accumulo(p, "accumulo_attacco")
	# l'arena si scalda: più si combatte, più i colpi fanno male
	bonus += int(s["round"]) / 10
	s["pend"] = {"att": p, "dif": o, "danno": impatto, "bonus": bonus, "vd": vd, "mischia": d <= 2 and int(sl.get("portata", 1)) <= 2,
		"lato": l, "ignora": sl.get("ignora_armatura", false), "non_schivabile": sl.get("non_schivabile", false),
		"riduz": 0, "annullato": false, "contro": 0, "spingi": int(sl.get("spingi", 0)), "attira": int(sl.get("attira", 0)),
		"blocca": int(sl.get("blocca", 0)), "catena": sl.get("catena", false), "nome": sl["nome"], "ruba": false, "no_spinta": false,
		"imparabile": sl.get("imparabile", false), "mira": int(extra.get("mira", -1)), "portata": int(sl.get("portata", 1)),
		"area": sl.has("area"), "gira": int(sl.get("gira", 0)), "spingi_lato": int(sl.get("spingi_lato", 0)), "lancia": sl.get("lancia", false),
		"poi": sl.get("poi", {}), "rompi": int(sl.get("rompi_guardia", 0)), "respingi": 0, "scartato": false}
	if sl.get("esecuzione", false):
		s["pend"]["danno"] = 99
		s["pend"]["non_schivabile"] = true
		s["pend"]["ignora"] = true
		s["pend"]["imparabile"] = true
	var latotxt := "" if l == "fronte" else (" sul fianco" if l == "fianco" else " alle spalle")
	_scrivi("%s: %s%s, %s." % [g["nome"], sl["nome"], latotxt, plurale(impatto + bonus, "danno", "danni")])
	_evento({"t": "attacco", "p": p, "bers": o, "dist": d})
	if s["pend"]["mischia"]:
		_innesca(o, "attaccato_mischia")
	if s["vinc"] < 0:
		_innesca(o, "attaccato")
	if s["vinc"] >= 0:
		return
	s["fase"] = "rinforzo"
	if not _ha_risposte(p):
		_vai_reazione()

func _vai_reazione() -> void:
	s["fase"] = "reazione"
	if not _ha_risposte(int(s["pend"]["dif"])):
		_risolvi_attacco()

func _risolvi_attacco() -> void:
	var pe: Dictionary = s["pend"]
	var att: int = pe["att"]
	var dif: int = pe["dif"]
	var ga: Dictionary = s["g"][att]
	var gd: Dictionary = s["g"][dif]
	s["fase"] = "azione"
	s["pend"] = {}
	if not pe["annullato"] and pe.get("scartato", false):
		var dd := dist(ga["pos"], gd["pos"])
		var arriva: bool = dd <= (1 if pe["area"] else int(pe["portata"])) and (pe["area"] or in_fronte(ga["pos"], ga["dir"], gd["pos"]))
		if not arriva:
			pe["annullato"] = true
			_scrivi("%s si è scansato: il colpo va a vuoto." % gd["nome"])
			_evento({"t": "schiva", "p": dif})
	if not pe["annullato"]:
		s["pend"] = pe
		_innesca(dif, "colpito")
		s["pend"] = {}
		pe["riduz"] += _accumulo(dif, "accumulo_difesa")
		if int(pe.get("mira", -1)) >= 0:
			var sc := scarto_lati(int(pe["mira"]), dir_verso(ga["pos"], gd["pos"]))
			if sc > 0:
				pe["danno"] = maxi(0, int(pe["danno"]) - sc)
				_scrivi("Il colpo mirato arriva di sbieco: -%d." % sc)
		if int(pe.get("rompi", 0)) > 0 and not gd["guardie"].is_empty():
			_scrivi("%s sfonda la guardia di %s." % [ga["nome"], gd["nome"]])
			for k in gd["guardie"].keys():
				_erodi_guardia(dif, k, int(pe["rompi"]))
		var cop := copertura(dif, ga["pos"])
		if int(cop[0]) > 0:
			pe["riduz"] += int(cop[0])
			_scrivi("%s ferma il colpo con la guardia: -%d." % [gd["nome"], cop[0]])
			_evento({"t": "para", "p": dif})
			_erodi_guardia(dif, String(cop[1]), 1)
		var arm: int = 0 if pe["ignora"] else int(gd["armatura"])
		var tot: int = maxi(0, int(pe["danno"]) + int(pe["bonus"]) - int(pe["riduz"]))
		# l'armatura da sola non annulla un colpo andato a segno: almeno 1 danno passa
		tot = maxi(mini(tot, 1), tot - arm)
		_ferisci(dif, tot)
		if tot > 0:
			cambia_assetto(dif, -1, "colpo subito")
		# colpo pesante: chi incassa molti danni arretra di un esagono
		var soglia := int(regole.get("colpo_pesante", 4))
		if s["vinc"] < 0 and soglia > 0 and tot >= soglia and pe["spingi"] == 0 and int(pe.get("spingi_lato", 0)) == 0 and pe["attira"] == 0 and not pe["no_spinta"]:
			_scrivi("Il colpo è pesante: %s arretra." % gd["nome"])
			_spingi(att, dif, 1, false)
		if s["vinc"] < 0 and pe["blocca"] > 0:
			var mano := dadi_di(dif, "mucchio") + dadi_di(dif, "mano")
			mano.sort_custom(func(a, b): return a["v"] > b["v"])
			var n := 0
			for d in mano:
				if n >= pe["blocca"]:
					break
				d["st"] = "stordito"
				n += 1
			if n > 0:
				_scrivi("%s ha %s." % [gd["nome"], plurale(n, "dado stordito", "dadi storditi")])
				_evento({"t": "blocco", "p": dif, "n": n})
				_evento({"t": "dadi", "p": dif})
		if s["vinc"] < 0 and pe["spingi"] > 0 and not pe["no_spinta"]:
			_spingi(att, dif, pe["spingi"], false, 0, pe.get("lancia", false))
		if s["vinc"] < 0 and int(pe.get("spingi_lato", 0)) > 0 and not pe["no_spinta"]:
			var dv := dir_verso(ga["pos"], gd["pos"])
			var dev := 1 if libero(gd["pos"] + DIRS[(dv + 1) % 6], dif) else 5
			_spingi(att, dif, int(pe["spingi_lato"]), false, dev, pe.get("lancia", false))
		if s["vinc"] < 0 and int(pe.get("gira", 0)) > 0 and not pe["no_spinta"]:
			_sbilancia(att, dif, int(pe["gira"]))
		if s["vinc"] < 0 and pe["attira"] > 0 and not pe["no_spinta"]:
			_spingi(att, dif, pe["attira"], true)
	if s["vinc"] < 0 and pe["contro"] > 0:
		var dn: int = maxi(0, int(pe["contro"]) - int(ga["armatura"]))
		_evento({"t": "attacco", "p": dif, "bers": att, "dist": 1})
		_ferisci(att, dn)
	if s["vinc"] < 0 and int(pe.get("respingi", 0)) > 0:
		_scrivi("%s respinge %s." % [gd["nome"], ga["nome"]])
		_spingi(dif, att, int(pe["respingi"]), false)
	if s["vinc"] < 0 and not pe.get("poi", {}).is_empty():
		_mossa_obbligata(att, dif, pe["poi"])
	if s["vinc"] >= 0:
		return
	if pe["ruba"] and puo_agire(dif):
		_scrivi("%s prende l'iniziativa!" % gd["nome"])
		s["attivo"] = dif
		_evento({"t": "iniziativa", "p": dif})
		return
	_dopo_azione(att, pe["catena"])

func _ferisci(p: int, n: int) -> void:
	var g: Dictionary = s["g"][p]
	g["vita"] = maxi(0, g["vita"] - n)
	_evento({"t": "danno", "p": p, "n": n})
	if n > 0:
		_scrivi("%s subisce %s (%d/%d)." % [g["nome"], plurale(n, "ferita", "ferite"), g["vita"], g["vita_max"]])
	else:
		_scrivi("%s non subisce danni." % g["nome"])
	if g["vita"] <= 0:
		s["vinc"] = 1 - p
		s["fase"] = "fine"
		_scrivi("%s è a terra. Vince %s!" % [g["nome"], s["g"][1 - p]["nome"]])
		_evento({"t": "ko", "p": p})
	elif n > 0:
		_innesca(p, "ferito")

func _spingi(att: int, dif: int, n: int, verso: bool, deviazione := 0, lancia := false) -> void:
	var gd: Dictionary = s["g"][dif]
	var d := (dir_verso(s["g"][att]["pos"], gd["pos"]) + deviazione) % 6
	if verso:
		d = (d + 3) % 6
	var per := [Vector3i(gd["pos"].x, gd["pos"].y, gd["dir"])]
	var urto := false
	for i in n:
		var nh: Vector2i = gd["pos"] + DIRS[d]
		if not libero(nh, dif):
			urto = not verso
			break
		gd["pos"] = nh
		per.append(Vector3i(nh.x, nh.y, gd["dir"]))
	_evento({"t": "spinto", "p": dif, "percorso": per})
	if urto:
		_scrivi("%s sbatte contro un ostacolo!" % gd["nome"])
		_ferisci(dif, DANNO_URTO + (1 if lancia else 0))
		if lancia and s["vinc"] < 0:
			var mano := dadi_di(dif, "mucchio") + dadi_di(dif, "mano")
			mano.sort_custom(func(a, b): return a["v"] > b["v"])
			if not mano.is_empty():
				mano[0]["st"] = "stordito"
				_scrivi("%s è stordito dall'urto: perde un %d." % [gd["nome"], mano[0]["v"]])
				_evento({"t": "blocco", "p": dif, "n": 1})
				_evento({"t": "dadi", "p": dif})
	if s["vinc"] < 0:
		_pericolo(dif)

## Il colpo sbilancia il difensore: si gira di n lati, offrendo il fianco o la schiena.
func _sbilancia(att: int, dif: int, n: int) -> void:
	var gd: Dictionary = s["g"][dif]
	var ap: Vector2i = s["g"][att]["pos"]
	var a := (int(gd["dir"]) + n) % 6
	var b := (int(gd["dir"]) + 6 - n) % 6
	gd["dir"] = a if angolo(gd["pos"], a, ap) >= angolo(gd["pos"], b, ap) else b
	_scrivi("%s perde l'equilibrio e si gira." % gd["nome"])
	_evento({"t": "muovi", "p": dif, "percorso": [Vector3i(gd["pos"].x, gd["pos"].y, gd["dir"])]})

## Movimento che una mossa impone a chi l'ha usata: indietro, avanti, di lato, oltre il nemico.
## Se non riesce a muoversi perde l'equilibrio: un suo dado in mano resta stordito.
func _mossa_obbligata(att: int, dif: int, poi: Dictionary) -> void:
	var ga: Dictionary = s["g"][att]
	var gd: Dictionary = s["g"][dif]
	var tipo := String(poi.get("mossa", "indietro"))
	var n := int(poi.get("n", 1))
	var per := [Vector3i(ga["pos"].x, ga["pos"].y, ga["dir"])]
	var visti := {ga["pos"]: true}
	match tipo:
		"indietro":
			var d := dir_verso(gd["pos"], ga["pos"])
			for i in n:
				var nh: Vector2i = ga["pos"] + DIRS[d]
				if not libero(nh, att):
					break
				ga["pos"] = nh
				per.append(Vector3i(nh.x, nh.y, ga["dir"]))
		"avanti":
			for i in n:
				if dist(ga["pos"], gd["pos"]) <= 1:
					break
				var nh: Vector2i = ga["pos"] + DIRS[dir_verso(ga["pos"], gd["pos"])]
				if not libero(nh, att):
					break
				ga["pos"] = nh
				per.append(Vector3i(nh.x, nh.y, ga["dir"]))
		"attraversa":
			var nh: Vector2i = gd["pos"] + DIRS[dir_verso(ga["pos"], gd["pos"])]
			if dist(ga["pos"], gd["pos"]) == 1 and libero(nh, att):
				ga["pos"] = nh
				per.append(Vector3i(nh.x, nh.y, ga["dir"]))
			else:
				tipo = "lato"
				n = 2
	if tipo == "lato":
		for i in n:
			var best := Vector2i.ZERO
			var bv := -INF
			var dmax := maxi(dist(ga["pos"], gd["pos"]), 1)
			for k in 6:
				var nh: Vector2i = ga["pos"] + DIRS[k]
				if visti.has(nh) or not libero(nh, att) or dist(nh, gd["pos"]) > dmax:
					continue
				var v := angolo(gd["pos"], gd["dir"], nh)
				if v > bv:
					bv = v
					best = nh
			if bv == -INF:
				break
			visti[best] = true
			ga["pos"] = best
			per.append(Vector3i(best.x, best.y, ga["dir"]))
	if per.size() == 1:
		var mano := dadi_di(att, "mucchio") + dadi_di(att, "mano")
		mano.sort_custom(func(a, b): return a["v"] > b["v"])
		if not mano.is_empty():
			mano[0]["st"] = "stordito"
			_evento({"t": "blocco", "p": att, "n": 1})
			_evento({"t": "dadi", "p": att})
		_scrivi("%s non riesce a completare il movimento e perde l'equilibrio." % ga["nome"])
		return
	if tipo != "indietro":
		ga["dir"] = dir_verso(ga["pos"], gd["pos"])
		per[per.size() - 1] = Vector3i(ga["pos"].x, ga["pos"].y, ga["dir"])
	var testi := {"indietro": "arretra", "avanti": "incalza", "attraversa": "passa oltre", "lato": "gira attorno al nemico"}
	_scrivi("%s %s." % [ga["nome"], testi.get(tipo, "si sposta")])
	_evento({"t": "muovi", "p": att, "percorso": per})
	_pericolo(att)
	if s["vinc"] < 0:
		_dopo_movimento(att)

func _pericolo(p: int) -> void:
	if s["per"].has(s["g"][p]["pos"]):
		_scrivi("%s è finito nel braciere!" % s["g"][p]["nome"])
		_ferisci(p, DANNO_PERICOLO)

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

# ================================================================ fortuna e azioni libere

func puo_azioni_libere(p: int) -> bool:
	return chi_decide() == p and s["fase"] in ["azione", "rinforzo", "reazione"]

func spinta_disponibile(p: int) -> bool:
	return int(s["g"][p]["spinte"]) == 0

## Spingere la fortuna: una volta per scambio ritiri i dadi in mano che vuoi; ogni 1 resta stordito.
func _spinta(p: int, ids: Array) -> String:
	if not puo_azioni_libere(p):
		return "Non puoi spingere la fortuna adesso."
	if ids.is_empty():
		return "Scegli i dadi da ritirare."
	if not selezione_attitudine_ok(p, ids):
		return "La Spinta supera il Ritmo o i limiti dell'Attitudine."
	var g: Dictionary = s["g"][p]
	_spendi_ritmo(p, ids)
	if not spinta_disponibile(p):
		return "Hai già spinto la fortuna in questo scambio."
	for id in ids:
		var d := dado(p, id)
		if d.is_empty() or not (d["st"] in ["mucchio", "mano"]):
			return "Si ritirano solo dadi disponibili."
	g["spinte"] += 1
	var storditi := 0
	var esiti := []
	for id in ids:
		var d := dado(p, id)
		d["v"] = _tira()
		esiti.append(str(d["v"]))
		if d["v"] == 1:
			if g["flag"].has("temerario") and g["usi"].get("temerario", 0) == 0:
				g["usi"]["temerario"] = 1
			else:
				d["st"] = "stordito"
				storditi += 1
	_scrivi("%s spinge la fortuna: %s%s." % [g["nome"], ", ".join(esiti), ("" if storditi == 0 else " (%s)" % plurale(storditi, "stordito", "storditi"))])
	_evento({"t": "dadi", "p": p})
	return ""

func _conserva(p: int, id: int) -> String:
	if not puo_azioni_libere(p):
		return "Non puoi farlo adesso."
	var g: Dictionary = s["g"][p]
	var d := dado(p, id)
	if d.is_empty() or not (d["st"] in ["mucchio", "mano"]):
		return "Si conservano solo dadi disponibili."
	if dadi_di(p, "conservato").size() >= int(g["conserva_max"]):
		return "Puoi conservare al massimo %s." % plurale(g["conserva_max"], "dado", "dadi")
	d["st"] = "conservato"
	_scrivi("%s conserva un %d per lo scambio seguente." % [g["nome"], d["v"]])
	_evento({"t": "dadi", "p": p})
	return ""

func _riprendi(p: int, id: int) -> String:
	if not puo_azioni_libere(p):
		return "Non puoi farlo adesso."
	var d := dado(p, id)
	if d.is_empty() or d["st"] != "conservato":
		return "Questo dado non è conservato."
	d["st"] = "mano"
	_evento({"t": "dadi", "p": p})
	return ""

# ================================================================ scambi

func _fine_round() -> void:
	for p in 2:
		_innesca(p, "fine_scambio")
	for p in 2:
		for d in s["g"][p]["dadi"]:
			if d["st"] in ["mano", "stordito"]:
				_al_mucchio(d)
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
	s["da_pescare"] = []
	for p in 2:
		var g: Dictionary = s["g"][p]
		if int(s["round"]) > 1:
			if int(g["usi"].get("attacchi", 0)) == 0:
				g["scambi_senza_attacco"] = mini(3, int(g.get("scambi_senza_attacco", 0)) + 1)
			else:
				g["scambi_senza_attacco"] = 0
		g["passato"] = false
		g["spinte"] = 0
		g["usi"] = {}
		g["ritmo_speso"] = 0
		g["colori_spesi"] = {}
		g["disarmati"] = {}
		for d in dadi_di(p, "conservato"):
			d["st"] = "mano"
		# Respiro di base: un solo dado completa il circuito a ogni nuovo
		# scambio. I token di recupero restano necessari quando l'Attesa si
		# riempie, ma un attacco semplice non resta spento per diversi turni.
		var in_attesa := dadi_di(p, "attesa")
		if not in_attesa.is_empty():
			_al_mucchio(in_attesa[0])
			_scrivi("%s recupera naturalmente 1 dado dall'Attesa." % g["nome"])
			_evento({"t": "dadi", "p": p})
	s["fase"] = "azione"
	_scrivi("--- Scambio %d: i dadi si scelgono direttamente dal mucchio per ogni azione." % s["round"])
	_evento({"t": "round", "n": s["round"], "p": -1})
	_inizia_azioni()

## Scelta dei dadi dal mucchio a inizio scambio (tanti quanto il Ritmo).
func _prendi(p: int, ids: Array) -> String:
	if s["fase"] != "pesca":
		return "Ora non si scelgono dadi dal mucchio."
	var n := da_prendere(p)
	if ids.size() != n:
		return "Devi scegliere %s." % plurale(n, "dado", "dadi")
	var visti := {}
	for id in ids:
		var d := dado(p, int(id))
		if d.is_empty() or d["st"] != "mucchio" or visti.has(id):
			return "Si scelgono solo dadi del mucchio."
		visti[id] = true
	for id in ids:
		dado(p, int(id))["st"] = "mano"
	s["g"][p]["bonus_ritmo"] = 0
	s["da_pescare"].erase(p)
	_evento({"t": "dadi", "p": p})
	if s["da_pescare"].is_empty():
		_inizia_azioni()
	return ""

func _inizia_azioni() -> void:
	var ini := [0, 0]
	for p in 2:
		var blu := []
		for d in dadi_di(p, "mucchio") + dadi_di(p, "mano"):
			if d["col"] == "blu":
				blu.append(d)
		blu.sort_custom(func(a, b): return a["v"] > b["v"])
		for i in mini(ritmo_azione(p), blu.size()):
			ini[p] += int(blu[i]["v"])
		ini[p] += int(s["g"][p]["ini"])
	var primo: int
	if ini[0] != ini[1]:
		primo = 0 if ini[0] > ini[1] else 1
	else:
		primo = 1 - int(s["primo"]) if s["primo"] >= 0 else rng.randi_range(0, 1)
	s["primo"] = primo
	s["attivo"] = primo
	s["fase"] = "azione"
	_scrivi("Iniziativa a %s (%d contro %d)." % [s["g"][primo]["nome"], ini[primo], ini[1 - primo]])
	_evento({"t": "iniziativa", "p": primo})
	for p in 2:
		_evento({"t": "dadi", "p": p})

# ================================================================ segreti

func _dopo_movimento(p: int) -> void:
	if s["vinc"] < 0 and dist(s["g"][p]["pos"], s["g"][1 - p]["pos"]) == 1:
		_innesca(1 - p, "nemico_adiacente")

## Fa scattare i segreti caricati di `p` che aspettano questo innesco.
func _innesca(p: int, innesco: String) -> void:
	var g: Dictionary = s["g"][p]
	var o := 1 - p
	for key in g["armati"].keys():
		if s["vinc"] >= 0:
			return
		if not g["armati"].has(key):
			continue
		var parti: PackedStringArray = key.split("/")
		var sl := slot_def(parti[0], parti[1])
		if sl.get("innesco", "") != innesco:
			continue
		var q: int = g["armati"][key]["q"]
		g["rivelati"][parti[0]] = true
		_libera(p, key)
		_scrivi("%s rivela un segreto: %s!" % [g["nome"], sl["nome"]])
		_evento({"t": "segreto", "p": p, "nome": sl["nome"]})
		match sl.get("esito", ""):
			"danno":
				var dn := maxi(0, q - int(s["g"][o]["armatura"]))
				_evento({"t": "attacco", "p": p, "bers": o, "dist": 1})
				_ferisci(o, dn)
			"riduci":
				if not s["pend"].is_empty():
					s["pend"]["riduz"] += q
			"sorte":
				var t := _tira()
				_scrivi("La sorte dice %d." % t)
				if t >= 5 and not s["pend"].is_empty():
					s["pend"]["annullato"] = true
					_evento({"t": "schiva", "p": p})
					_ferisci(o, 2)
				elif t >= 3 and not s["pend"].is_empty():
					s["pend"]["riduz"] += 3
			"annulla":
				if not s["pend"].is_empty() and q >= int(s["pend"]["vd"]) and not s["pend"]["non_schivabile"]:
					s["pend"]["annullato"] = true
					_evento({"t": "schiva", "p": p})
			"stordisci":
				var mano := dadi_di(o, "mucchio") + dadi_di(o, "mano")
				mano.sort_custom(func(x, y): return x["v"] > y["v"])
				for i in mini(2, mano.size()):
					mano[i]["st"] = "stordito"
				_evento({"t": "blocco", "p": o, "n": mini(2, mano.size())})
				_evento({"t": "dadi", "p": o})
			"cura":
				var c := mini(q, g["vita_max"] - g["vita"])
				g["vita"] += c
				_evento({"t": "cura", "p": p, "n": c})
			"pesca":
				var k := _pesca_migliori(p, q)
				_scrivi("%s prende %s dal mucchio." % [g["nome"], plurale(k, "dado", "dadi")])
			"rito":
				var chiavi: Array = g["occupati"].keys()
				chiavi.sort_custom(func(a, b): return _peso_spazio(a) > _peso_spazio(b))
				for i in mini(q, chiavi.size()):
					_libera(p, chiavi[i])
				g["bonus_ritmo"] = 1
		_evento({"t": "dadi", "p": p})

## Bonus dato dai dadi lasciati sugli spazi che accumulano (rabbia, guardia...).
func _accumulo(p: int, campo: String) -> int:
	var tot := 0
	for k in s["g"][p]["occupati"]:
		var parti: PackedStringArray = k.split("/")
		var sl := slot_def(parti[0], parti[1])
		if sl.has(campo):
			tot += int(sl[campo]) * s["g"][p]["occupati"][k].size()
	return tot

func _scarica(p: int, key: String) -> String:
	if not opzioni_scarica(p).has(key):
		return "Questo contatore non può scaricarsi ora."
	var g: Dictionary = s["g"][p]
	var parti: PackedStringArray = key.split("/")
	var sl := slot_def(parti[0], parti[1])
	var car: Dictionary = sl["carica"]
	g["carichi"].erase(key)
	_libera(p, key)
	_scrivi("%s scarica %s!" % [g["nome"], sl["nome"]])
	_evento({"t": "dadi", "p": p})
	match car.get("effetto", ""):
		"attacco":
			var att := car.duplicate()
			att["nome"] = sl["nome"]
			att["tutti_lati"] = true
			_dichiara_attacco(p, att, int(car.get("fisso", 6)), 6)
			return ""
		"cura":
			var n := mini(int(car.get("fisso", 4)), g["vita_max"] - g["vita"])
			g["vita"] += n
			_evento({"t": "cura", "p": p, "n": n})
		"sblocca":
			for k in g["occupati"].keys():
				_libera(p, k)
			_scrivi("%s libera tutti gli spazi." % g["nome"])
	_dopo_azione(p, car.get("catena", false))
	return ""

func _peso_spazio(key: String) -> int:
	var parti: PackedStringArray = key.split("/")
	var sl := slot_def(parti[0], parti[1])
	match sl.get("effetto", ""):
		"attacco", "assalto":
			return 3
		"movimento", "sblocca", "pesca":
			return 2
	return 1

# ================================================================ diario ed eventi

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
