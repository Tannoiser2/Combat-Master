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
const TRAPPOLE := ["schivata", "irimi", "tenkan", "proiezione", "immobilizza", "contrattacco", "ukemi", "shiho", "kokyu", "juji"]
const COLPI := ["colpo", "colpo_stordente", "spinta", "carica", "affondo"]
const VALORE_TRAPPOLA := {"juji": 7, "shiho": 6, "kokyu": 6, "proiezione": 5, "immobilizza": 4, "contrattacco": 4, "irimi": 3, "tenkan": 3, "schivata": 2, "ukemi": 2}
## Anello mediano: sei posti da due pezzi (un token doppio o due singoli del colore del posto).
## Sopra ogni token base il posto del suo colore, fra due token base il posto a cavallo dei due colori.
const POSTI := ["rosso", "arancio", "giallo", "verde", "blu", "viola"]
const POSTI_MISTI := {"rosso": "F", "arancio": "FA", "giallo": "A", "verde": "AP", "blu": "P", "viola": "PF"}
## Anello esterno: sei posti a cavallo fra un posto del mediano di colore base e il misto accanto;
## i buchi fra un posto e l'altro, sopra il centro dei posti del mediano, sono le Attese.
const COPPIE := [["rosso", "arancio"], ["arancio", "giallo"], ["giallo", "verde"], ["verde", "blu"], ["blu", "viola"], ["viola", "rosso"]]
const MAX_ESTERNO := 6
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

## Punti e budget di un personaggio della sfera: caratteristiche, token del mediano e dell'esterno.
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
	var spesi3 := 0
	var coppie := {}
	for id in pg.get("coll", []):
		if tokp.has(id):
			if int(tokp[id].get("anello", 2)) == 3:
				spesi3 += int(tokp[id]["costo"])
				var k := posto_esterno(id)
				if coppie.has(k):
					prob.append("un solo token esterno per coppia di colori")
				coppie[k] = true
			else:
				spesi += int(tokp[id]["costo"])
	if punti != maxp:
		prob.append("le caratteristiche devono sommare %d (ora %d)" % [maxp, punti])
	if spesi > maxb:
		prob.append("i token del mediano costano %d, il budget è %d" % [spesi, maxb])
	var maxb3 := int(reg.get("budget_esterno", 12))
	if spesi3 > maxb3:
		prob.append("i token dell'anello esterno costano %d, il budget è %d" % [spesi3, maxb3])
	return {"punti": punti, "max_punti": maxp, "budget": spesi, "max_budget": maxb, "budget3": spesi3, "max_budget3": maxb3, "problemi": prob}

func casuale(gen: RandomNumberGenerator, nome := "Avventuriero") -> Dictionary:
	var R := 2
	var punti := int(reg["punti"]) - (int(reg["ritmo3_punti"]) if R == 3 else 0)
	var v := [1, 1, 1, 1]
	while true:
		v = [1, 1, 1, 1]
		for i in punti - 4:
			v[gen.randi() % 4] += 1
		if v.max() <= 4:
			break
	var budget := int(reg["budget"]) - (int(reg["ritmo3_budget"]) if R == 3 else 0)
	var budget3 := int(reg.get("budget_esterno", 12))
	var per_col := {}
	var esterni := []
	for t in sd["esterni"]:
		if int(t.get("anello", 2)) == 3:
			esterni.append(t["id"])
		else:
			if not per_col.has(t["col"]):
				per_col[t["col"]] = []
			per_col[t["col"]].append(t["id"])
	var coll := []
	# ogni posto del mediano: un doppio o fino a due singoli del suo colore, finché il budget basta
	var posti := POSTI.duplicate()
	for i in range(posti.size() - 1, 0, -1):
		var j := gen.randi() % (i + 1)
		var x = posti[i]
		posti[i] = posti[j]
		posti[j] = x
	for c in posti:
		var lista: Array = per_col.get(c, []).duplicate()
		for i in range(lista.size() - 1, 0, -1):
			var j := gen.randi() % (i + 1)
			var x = lista[i]
			lista[i] = lista[j]
			lista[j] = x
		var pz := 0
		var dopo: int = posti.size() - posti.find(c) - 1
		for id in lista:
			var n: int = tokp[id]["azioni"].size()
			if pz + n <= 2 and int(tokp[id]["costo"]) <= budget - dopo * 2:
				coll.append(id)
				budget -= int(tokp[id]["costo"])
				pz += n
			if pz >= 2:
				break
		if pz < 2:
			# il posto va riempito: i più economici
			lista.sort_custom(func(a, b): return int(tokp[a]["costo"]) < int(tokp[b]["costo"]))
			for id in lista:
				var n: int = tokp[id]["azioni"].size()
				if not coll.has(id) and pz + n <= 2:
					coll.append(id)
					budget -= int(tokp[id]["costo"])
					pz += n
				if pz >= 2:
					break
	for i in range(esterni.size() - 1, 0, -1):
		var j := gen.randi() % (i + 1)
		var x = esterni[i]
		esterni[i] = esterni[j]
		esterni[j] = x
	var coppie := {}
	for id in esterni:
		var k := posto_esterno(id)
		if not coppie.has(k) and int(tokp[id]["costo"]) <= budget3:
			coll.append(id)
			budget3 -= int(tokp[id]["costo"])
			coppie[k] = true
	return {"nome": nome, "F": v[0], "A": v[1], "P": v[2], "C": v[3], "R": R, "coll": coll, "raro": "", "casuale": true}

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
			"girate": {}, "flussi": 0, "tenuto": false, "occhio": false, "zanshin": 0, "slot": 2,
			"a_terra": false, "attesa": _attesa_vuota(), "esposto": false, "cambi": 0, "mezze": {}})
	_scrivi("Inizia il duello: %s contro %s." % [s["g"][0]["nome"], s["g"][1]["nome"]])
	s["scambio"] = 1
	s["cede"] = -1
	for p in 2:
		var g: Dictionary = s["g"][p]
		_assetto_iniziale(p)
		_metti_in_campo(p)
		for c in g["mucchio"]:
			g["mano"].append(_nuovo_dado(c))
	s["attivo"] = int(s["primo"])
	s["fase"] = "azione"
	gira_verso(0)
	gira_verso(1)
	_avanza()

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

## Gli svantaggi li spende l'avversario: +1 al danno che subisci; a 3 perdi l'iniziativa.
func _svant(p: int, n: int) -> void:
	var g: Dictionary = s["g"][p]
	g["svantaggi"] = clampi(int(g["svantaggi"]) + n, 0, int(reg["max_vant"]))
	_evento({"t": "svantaggi", "p": p})

## Regole d'iniziativa scritte sull'azione: "sicuro" la tiene anche se l'avversario reagisce
## (a prezzo di 1 svantaggio), "cede_svant" la fa perdere se hai già tanti svantaggi.
func _iniziativa_azione(p: int, a: Dictionary) -> void:
	var g: Dictionary = s["g"][p]
	if int(s["attivo"]) != p:
		return
	if a.get("sicuro", false) and int(s.get("cede", -1)) == p:
		s["cede"] = -1
		_svant(p, 1)
		_scrivi("%s non molla: tiene l'iniziativa e prende 1 svantaggio." % g["nome"])
	var n := int(a.get("cede_svant", 0))
	if n > 0 and int(g["svantaggi"]) >= n:
		g["svantaggi"] = 0
		s["cede"] = p
		_scrivi("%s è sbilanciato: perde l'iniziativa." % g["nome"])

func _valore(_p: int, v: int) -> int:
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
	var o: Vector2i = s["g"][1 - _chi_muove]["pos"]
	for i in out.size():
		var h: Vector2i = out[i]
		var dd: int = int(s["g"][_chi_muove]["dir"])
		if i > 0:
			# vicino all'avversario (fino a 3 esagoni) si resta in guardia verso di lui e si passa di lato
			# o all'indietro; da lontano si guarda dove si va, e all'ultimo passo ci si gira verso di lui
			if dist(h, o) <= 3 or i == out.size() - 1:
				dd = dir_verso(h, o) if h != o else dd
			else:
				dd = dir_verso(out[i - 1], h)
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

var _chi_muove := 0

func _muovi_a(p: int, vis: Dictionary, h: Vector2i) -> void:
	var g: Dictionary = s["g"][p]
	if h == g["pos"]:
		return
	_chi_muove = p
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

func _salta_a(p: int, h: Vector2i, capriola := false) -> void:
	var g: Dictionary = s["g"][p]
	var da := Vector3i(g["pos"].x, g["pos"].y, g["dir"])
	g["pos"] = h
	g["dir"] = dir_verso(h, s["g"][1 - p]["pos"])
	_evento({"t": "muovi", "p": p, "percorso": [da, Vector3i(h.x, h.y, g["dir"])], "salta": true, "capriola": capriola})
	_pericolo_s(p)

## Corsa (carica, affondo): se l'arrivo si raggiunge camminando si corre esagono per esagono, altrimenti si salta.
func _corri_a(p: int, h: Vector2i, k: int) -> void:
	var vis := cammino(p, k + 1)
	if vis.has(h):
		_muovi_a(p, vis, h)
	else:
		_salta_a(p, h)

## Salto o carica: arrivi a contatto se entro k esagoni. Dritto: atterri davanti, non sul fianco.
func porta_contatto(p: int, k: int, dritto := false) -> void:
	var o: Vector2i = s["g"][1 - p]["pos"]
	var cand := []
	var da_qui: Vector2i = s["g"][p]["pos"]
	for d in DIRS:
		var h: Vector2i = o + d
		# mai oltre l'avversario: si arriva dalla propria parte, senza scavalcarlo
		if libero_s(h, p) and absi(altezza(h) - altezza(o)) <= 1 and dist(h, da_qui) <= k and dist(h, da_qui) <= dist(o, da_qui):
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
		if dritto:
			_corri_a(p, best, k)
		else:
			_salta_a(p, best)
	gira_verso(p)

## Balzo: si atterra con un salto davanti al nemico (l'esagono libero più vicino a contatto).
func _balzo(p: int, k: int) -> void:
	var o: Vector2i = s["g"][1 - p]["pos"]
	var best := Vector2i(9999, 9999)
	var bd := 999
	for d in DIRS:
		var h: Vector2i = o + d
		if libero_s(h, p) and absi(altezza(h) - altezza(o)) <= 1 and dist(h, s["g"][p]["pos"]) <= k:
			var dd := dist(h, s["g"][p]["pos"])
			if dd < bd:
				bd = dd
				best = h
	if best.x == 9999:
		avvicina(p, k)
	elif best != s["g"][p]["pos"]:
		_salta_a(p, best)
	gira_verso(p)

## Irimi: tori entra sul fianco di chi attacca camminando attorno a lui, non attraverso.
func _entra_al_fianco(p: int) -> void:
	aggira(p, 2)

func alle_spalle(p: int) -> void:
	var o := 1 - p
	var cand := []
	for d in DIRS:
		var h: Vector2i = s["g"][o]["pos"] + d
		if libero_s(h, p) and absi(altezza(h) - altezza(s["g"][o]["pos"])) <= 1:
			cand.append(h)
	if cand.is_empty():
		return
	if contatto():
		# a contatto si gira attorno a lui, esagono per esagono
		aggira(p, 3)
		return
	# da lontano si arriva sul suo fianco, dalla propria parte, con una capriola che non lo scavalca
	var da_qui: Vector2i = s["g"][p]["pos"]
	var buoni := cand.filter(func(h): return dist(h, da_qui) <= dist(s["g"][o]["pos"], da_qui))
	if buoni.is_empty():
		buoni = cand
	buoni.sort_custom(func(a, b): return absi(lato_rel(o, a) - 3) < absi(lato_rel(o, b) - 3))
	_salta_a(p, buoni[0], true)
	gira_verso(p)

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

## Proiezione: uke continua lo slancio del suo attacco, gira attorno a tori e vola oltre di lui
## (dietro o di fianco). Se dall'altra parte non c'è spazio sbatte contro l'ostacolo.
func proietta(tori: int, uke: int, k: int, danno_urto := true) -> void:
	var gu: Dictionary = s["g"][uke]
	var tp: Vector2i = s["g"][tori]["pos"]
	var d := dir_verso(gu["pos"], tp)
	var partenza: Vector2i = gu["pos"]
	var per := [Vector3i(partenza.x, partenza.y, gu["dir"])]
	var arrivo := partenza
	var urto := false
	# dietro tori lungo lo slancio, poi di fianco se dietro è chiuso; per arrivare dietro serve
	# un fianco libero da cui girargli attorno, altrimenti uke passerebbe attraverso tori
	var fianco_libero := libero_s(tp + DIRS[(d + 1) % 6], uke) or libero_s(tp + DIRS[(d + 5) % 6], uke)
	var linee := [d, (d + 1) % 6, (d + 5) % 6] if fianco_libero else [(d + 1) % 6, (d + 5) % 6]
	var trovato := false
	for dd in linee:
		var ultimo := Vector2i(9999, 9999)
		for j in range(1, k + 1):
			var h: Vector2i = tp + DIRS[dd] * j
			if not libero_s(h, uke) or altezza(h) > altezza(tp) + 1:
				break
			ultimo = h
		if ultimo.x != 9999:
			arrivo = ultimo
			trovato = true
			if dist(arrivo, tp) < k and dd == d:
				urto = true
			break
	if not trovato:
		# nessuno spazio attorno: resta dov'è e sbatte
		urto = true
	else:
		# passa di fianco a tori (dal lato libero più vicino all'arrivo), poi atterra
		var fianco := tp + DIRS[(d + 1) % 6]
		if not libero_s(fianco, uke) or dist(fianco, arrivo) > 1:
			var altro := tp + DIRS[(d + 5) % 6]
			if libero_s(altro, uke) and (dist(altro, arrivo) <= 1 or not libero_s(fianco, uke)):
				fianco = altro
		if libero_s(fianco, uke) and fianco != arrivo and fianco != partenza:
			per.append(Vector3i(fianco.x, fianco.y, gu["dir"]))
		per.append(Vector3i(arrivo.x, arrivo.y, dir_verso(arrivo, tp)))
	var caduta := maxi(0, altezza(partenza) - altezza(arrivo))
	gu["pos"] = arrivo
	gu["dir"] = dir_verso(arrivo, tp)
	_evento({"t": "spinto", "p": uke, "percorso": per, "lancia": true, "urto": urto, "dir": d, "caduta": caduta})
	if caduta > 0:
		_scrivi("%s cade giù dal rialzo!" % gu["nome"])
		_ferisci(uke, caduta)
	if urto and danno_urto:
		_scrivi("%s finisce contro un ostacolo!" % gu["nome"])
		_ferisci(uke, int(reg["danno_urto"]))
	_pericolo_s(uke)
	# tori ruota sul posto con il lancio e resta rivolto verso dove è atterrato uke
	gira_verso(tori)

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

## 2 = anello dei misti (si carica dalle azioni base), 3 = anello esterno (si carica con i dadi che salgono
## dai token dei misti quando scattano). I token di scena stanno nell'anello esterno ma si caricano dalle azioni base.
func anello(e: Dictionary) -> int:
	if String(e["id"]).begins_with("scena_"):
		return 3
	return int(tok(e["id"]).get("anello", 2))

func a_terra(p: int) -> bool:
	return bool(s["g"][p].get("a_terra", false))

func _metti_a_terra(p: int) -> void:
	if s["vinc"] >= 0 or s["g"][p]["vita"] <= 0:
		return
	s["g"][p]["a_terra"] = true
	_scrivi("%s è a terra: deve rialzarsi." % s["g"][p]["nome"])
	_evento({"t": "a_terra", "p": p})

## I dadi liberati aspettano la pausa nelle Attese dell'anello esterno, sopra il posto da cui vengono.
func _in_attesa(p: int, zona: String, colore: String) -> void:
	var z: String = {"F": "rosso", "A": "giallo", "P": "blu", "E": "rosso"}.get(zona, zona)
	var att: Dictionary = s["g"][p]["attesa"]
	if not att.has(z):
		att[z] = []
	att[z].append(colore)

var _te_cache := {}
func te(e: Dictionary) -> Dictionary:
	var id: String = e["id"]
	if id.begins_with("scena_"):
		return tok(id)
	var parte := int(e.get("parte", 0))
	var key := "%s:%d" % [id, parte]
	if _te_cache.has(key):
		return _te_cache[key]
	var t: Dictionary = tok(id)
	if not t.has("azioni"):
		return t
	var out := parte_di(t, parte)
	_te_cache[key] = out
	return out

## Una metà di un token del catalogo, nella forma che usano motore e disegno.
static func parte_di(t: Dictionary, parte: int) -> Dictionary:
	if not t.has("azioni"):
		return t
	var az: Dictionary = t["azioni"][mini(parte, t["azioni"].size() - 1)]
	var a: Dictionary = az["a"]
	return {"id": t["id"], "nome": az["nome"], "col": String(az.get("col", t["col"])), "req": az["req"], "freccia": int(az["freccia"]),
		"modo": "armato" if String(a["tipo"]) in ["trappola", "guardia"] else "subito", "eff": "comp", "a": a,
		"testo": az["testo"], "testo_pot": az["testo_pot"], "bonus": 0, "anello": int(t.get("anello", 2)),
		"entrambi": t.get("entrambi", false), "costo": t.get("costo", 0), "testo_cond": t.get("testo_cond", "")}

func _nuove_parti(id: String) -> Array:
	var out := []
	var t := tok(id)
	var n: int = t["azioni"].size() if t.has("azioni") else 1
	for i in n:
		var e := _nuovo_token(id)
		e["parte"] = i
		out.append(e)
	return out

## Cambi di token che il combattente può fare a ogni pausa: il Ritmo, +1 sopra un rialzo.
func slot_di(p: int) -> int:
	return int(s["g"][p]["R"]) + (1 if altezza(s["g"][p]["pos"]) >= 1 else 0)

func _pausa() -> void:
	s["scambio"] += 1
	s["da_piazzare"] = []
	_evento({"t": "pausa"})
	_scrivi("— Pausa: scambio %d." % s["scambio"])
	for p in 2:
		var g: Dictionary = s["g"][p]
		if s["scambio"] == 1 or not g.has("assetto"):
			_assetto_iniziale(p)
		g["slot"] = slot_di(p)
		g["cambi"] = g["slot"]
		# la sfera torna com'era: i token scattati rientrano vuoti, gli altri tengono i loro dadi
		_metti_in_campo(p)
		var pool: Array = g["mucchio"].duplicate()
		for e in g["esterni"]:
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
		g["esposto"] = false
		if g["a_terra"]:
			g["a_terra"] = false
			_evento({"t": "rialza", "p": p})
		g["attesa"] = _attesa_vuota()
		if s["scambio"] > 1:
			if g["umano"]:
				if not cambi_possibili(p).is_empty():
					s["da_piazzare"].append(p)
			else:
				for c in _scegli_token(p, int(g["cambi"])):
					_cambia(p, c[0], c[1])
	s["attivo"] = (int(s["primo"]) + int(s["scambio"])) % 2
	s["finito"] = [false, false]
	s["iniziativa_a"] = -1
	gira_verso(0)
	gira_verso(1)
	s["fase"] = "pausa" if not s["da_piazzare"].is_empty() else "azione"
	if s["fase"] == "azione":
		_avanza()

func _attesa_vuota() -> Dictionary:
	var a := {}
	for k in POSTI:
		a[k] = []
	return a

## Assetto di partenza dalla collezione: in ogni posto del mediano fino a due pezzi del suo colore
## (un doppio o due singoli), nell'esterno un token per coppia.
func _assetto_iniziale(p: int) -> void:
	var g: Dictionary = s["g"][p]
	var ass := {}
	for k in POSTI:
		ass[k] = []
	var ass3 := {}
	var ids: Array = g["coll"].filter(func(id): return tok(id).has("azioni"))
	var val := {}
	for id in ids:
		val[id] = _valore_token(p, id)
	ids.sort_custom(func(a, b): return val[a] > val[b])
	for id in ids:
		var t := tok(id)
		if int(t.get("anello", 2)) == 3:
			var k := posto_esterno(id)
			if k >= 0 and not ass3.has(k):
				ass3[k] = id
			continue
		var c: String = t["col"]
		if ass.has(c) and pezzi(ass[c]) + t["azioni"].size() <= 2:
			ass[c].append(id)
	g["assetto"] = ass
	g["assetto3"] = ass3

func pezzi(ids: Array) -> int:
	var n := 0
	for id in ids:
		n += tok(id)["azioni"].size()
	return n

## Indice del posto esterno (0-5) della coppia di colori di un token dell'anello esterno.
func posto_esterno(id: String) -> int:
	var c: Array = tok(id).get("coppia", [])
	for k in COPPIE.size():
		if (COPPIE[k][0] == c[0] and COPPIE[k][1] == c[1]) or (COPPIE[k][0] == c[1] and COPPIE[k][1] == c[0]):
			return k
	return -1

func _metti_in_campo(p: int) -> void:
	var g: Dictionary = s["g"][p]
	var vecchi := {}
	for e in g["esterni"]:
		vecchi["%s:%d" % [e["id"], int(e.get("parte", 0))]] = e
	var nuovi := []
	for k in POSTI:
		for id in g["assetto"][k]:
			for e in _nuove_parti(id):
				var x: Dictionary = vecchi.get("%s:%d" % [id, int(e["parte"])], e)
				x["posto"] = k
				x["bloccato"] = false
				nuovi.append(x)
	for k in g["assetto3"]:
		for e in _nuove_parti(g["assetto3"][k]):
			var x: Dictionary = vecchi.get("%s:%d" % [g["assetto3"][k], int(e["parte"])], e)
			x["posto3"] = int(k)
			x["bloccato"] = false
			nuovi.append(x)
	# token di scena: in un posto esterno libero, si caricano dalle azioni base
	var ogg := oggetto_vicino(g["pos"])
	if ogg != "":
		var liberi := []
		for k in COPPIE.size():
			if not g["assetto3"].has(k):
				liberi.append(k)
		if not liberi.is_empty():
			var e := _nuovo_token("scena_" + ogg)
			e["ogg_h"] = _casella_oggetto(g["pos"], ogg)
			e["posto3"] = liberi[0]
			nuovi.append(e)
	g["esterni"] = nuovi

func _nuovo_token(id: String) -> Dictionary:
	return {"id": id, "dadi": [], "pronto": false, "bloccato": false, "pot": false, "respinto": false}

func _n_token(lista: Array) -> int:
	var ids := {}
	for e in lista:
		if not String(e["id"]).begins_with("scena_") and anello(e) == 2:
			ids[e["id"]] = true
	return ids.size()

func _n_esterni(g: Dictionary) -> int:
	return g.get("assetto3", {}).size()

func _posto_esterno_libero(g: Dictionary) -> int:
	for k in COPPIE.size():
		if not g.get("assetto3", {}).has(k):
			return k
	return 0

## Posti del mediano con almeno un pezzo libero.
func posti_misti_liberi(g: Dictionary) -> Array:
	return POSTI.filter(func(k): return pezzi(g["assetto"][k]) < 2)

func posto_per(g: Dictionary, id: String) -> String:
	var c := String(tok(id).get("col", ""))
	if g["assetto"].has(c) and pezzi(g["assetto"][c]) + tok(id)["azioni"].size() <= 2:
		return c
	return ""

func posto_adatto(posto: String, id: String) -> bool:
	return String(tok(id).get("col", "")) == posto

func _metti_misto(g: Dictionary, id: String, _in_testa := false) -> bool:
	var posto := posto_per(g, id)
	if posto == "":
		return false
	g["assetto"][posto].append(id)
	for e in _nuove_parti(id):
		e["posto"] = posto
		g["esterni"].append(e)
	return true

## Token del mediano della collezione che non sono sulla sfera.
func token_disponibili(p: int) -> Array:
	var g: Dictionary = s["g"][p]
	var sopra := {}
	for k in POSTI:
		for id in g["assetto"][k]:
			sopra[id] = true
	return g["coll"].filter(func(id): return not sopra.has(id) and tok(id).has("azioni") and int(tok(id).get("anello", 2)) == 2)

func posti_da_piazzare(p: int) -> int:
	return int(s["g"][p].get("cambi", 0))

## Cambi possibili alla pausa: [esce, entra] ("" se si riempie un pezzo libero).
func cambi_possibili(p: int) -> Array:
	var g: Dictionary = s["g"][p]
	var out := []
	if int(g.get("cambi", 0)) <= 0:
		return out
	for nuovo in token_disponibili(p):
		var c := String(tok(nuovo)["col"])
		var pn: int = tok(nuovo)["azioni"].size()
		if pezzi(g["assetto"][c]) + pn <= 2:
			out.append(["", nuovo])
		for vecchio in g["assetto"][c]:
			if pezzi(g["assetto"][c]) - int(tok(vecchio)["azioni"].size()) + pn <= 2:
				out.append([vecchio, nuovo])
	return out

## Un cambio alla pausa: il token che esce lascia i suoi dadi nell'Attesa, quello che entra arriva vuoto.
func _cambia(p: int, vecchio: String, nuovo: String) -> bool:
	var g: Dictionary = s["g"][p]
	var c := String(tok(nuovo).get("col", ""))
	if not g["assetto"].has(c) or int(g.get("cambi", 0)) <= 0:
		return false
	var resto: Array = g["assetto"][c].duplicate()
	if vecchio != "":
		if not resto.has(vecchio):
			return false
		resto.erase(vecchio)
	if pezzi(resto) + tok(nuovo)["azioni"].size() > 2:
		return false
	if vecchio != "":
		for e in g["esterni"].duplicate():
			if e["id"] == vecchio:
				for dd in e["dadi"]:
					_in_attesa(p, c, String(dd["c"]))
				g["esterni"].erase(e)
	resto.append(nuovo)
	g["assetto"][c] = resto
	for e in _nuove_parti(nuovo):
		e["posto"] = c
		g["esterni"].append(e)
	g["cambi"] = int(g["cambi"]) - 1
	_scrivi("%s mette in campo %s%s." % [g["nome"], tok(nuovo)["nome"], (" al posto di " + String(tok(vecchio)["nome"])) if vecchio != "" else ""])
	return true

## Il giocatore umano fa i suoi cambi alla pausa: lista di [esce, entra].
func piazza(p: int, cambi: Array) -> String:
	if s["fase"] != "pausa" or not s["da_piazzare"].has(p):
		return "non è il momento di cambiare"
	for c in cambi:
		if c is Array and c.size() == 2:
			_cambia(p, String(c[0]), String(c[1]))
	s["da_piazzare"].erase(p)
	if s["da_piazzare"].is_empty():
		s["fase"] = "azione"
		_avanza()
	return ""

## Cambi dell'IA: sostituisce il token meno utile di un posto con uno migliore della collezione.
func _scegli_token(p: int, n: int) -> Array:
	var g: Dictionary = s["g"][p]
	var out := []
	var usati := {}
	var cand := cambi_possibili(p)
	var gu := {}
	for c in cand:
		gu["%s>%s" % c] = _guadagno(p, c)
	cand.sort_custom(func(a, b): return gu["%s>%s" % a] > gu["%s>%s" % b])
	for c in cand:
		if out.size() >= n:
			break
		if usati.has(c[0]) or usati.has(c[1]) or gu["%s>%s" % c] <= 0.3:
			continue
		usati[c[0]] = true
		usati[c[1]] = true
		out.append(c)
	return out

func _guadagno(p: int, c: Array) -> float:
	return _valore_token(p, c[1]) - (_valore_token(p, c[0]) if c[0] != "" else 0.0)

func _valore_token(p: int, id: String) -> float:
	var g: Dictionary = s["g"][p]
	var t := tok(id)
	var forze := {"F": g["F"] + g["C"] * 0.3, "A": g["A"] + g["C"] * 0.3, "P": g["P"] + g["C"] * 0.3}
	var v := float(t.get("costo", 1)) * 0.5
	var col := String(t.get("col", ""))
	if SETTORI_COL.has(col):
		var sett: String = SETTORI_COL[col]
		var f := 0.0
		for c in sett:
			f += forze[c]
		v += f / sett.length()
	return v + rng.randf() * 1.2

func posti_liberi(e: Dictionary) -> Array:
	var t0 := te(e)
	if String(t0["col"]) in ["arancio", "verde", "viola"] and not t0.get("entrambi", false) and anello(e) == 2:
		var n0: int = t0["req"].size() - e["dadi"].size()
		var out0 := []
		for i in maxi(0, n0):
			out0.append("o")
		return out0
	var liberi: Array = t0["req"].duplicate()
	for dd in e["dadi"]:
		var c: String = dd["c"]
		if liberi.has(c):
			liberi.erase(c)
		elif liberi.has("x"):
			liberi.erase("x")
		elif liberi.has("n"):
			liberi.erase("n")
		elif c == "n" and not liberi.is_empty():
			liberi.remove_at(0)
	return liberi

func puo_caricare(e: Dictionary, colore: String, settore: String) -> bool:
	if e["pronto"] or e["bloccato"]:
		return false
	if anello(e) == 3 and not String(e["id"]).begins_with("scena_"):
		return false
	var t := te(e)
	if not SETTORI_COL.has(String(t["col"])) or not settore in String(SETTORI_COL[t["col"]]):
		return false
	var liberi := posti_liberi(e)
	if liberi.is_empty():
		return false
	if liberi.has("x"):
		return true
	if liberi.has("o"):
		var due: String = SETTORI_COL[t["col"]]
		return colore == "n" or (SETTORE_DADO.has(colore) and SETTORE_DADO[colore] in due)
	if colore == "n":
		return true
	return liberi.has(colore)

func bersagli_salita(p: int, colore: String, settore: String) -> Array:
	var out := []
	var est: Array = s["g"][p]["esterni"]
	for i in est.size():
		if puo_caricare(est[i], colore, settore):
			out.append(i)
	return out

func freccia(e: Dictionary) -> int:
	return int(te(e).get("freccia", 1))

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
	var t := te(e)
	var eff: String = t["eff"]
	if eff == "comp":
		var a: Dictionary = t["a"]
		match String(a["tipo"]):
			"colpo":
				if a.get("alle_spalle", false):
					return distanza() <= 3
				if int(a.get("entra", 0)) > 0:
					return distanza() <= int(a["entra"])
				return contatto()
			"presa":
				return contatto()
			"effetto":
				if int(a.get("portata", 0)) > 0:
					return distanza() <= int(a["portata"])
				return true
		return true
	if eff in ["colpo", "colpo_stordente", "spinta", "sgambetto", "tenchi"]:
		return contatto()
	if t.has("portata"):
		return distanza() <= int(t["portata"])
	return true

# ================================================================ salire

## Passaggio verso l'esterno. scelta = {"tok": indice o -1 (il più vicino a riempirsi), "modo": "scala" | "ritira" | "no" | "auto"}.
## poi riceve true se il giocatore continua a giocare (ritiro riuscito durante la sua azione).
var _reaz_att := -1

func _sali(p: int, colore: String, settore: String, mia: bool, valore: int, scelta: Dictionary, poi: Callable) -> void:
	var g: Dictionary = s["g"][p]
	var cand := bersagli_salita(p, colore, settore)
	var modo := String(scelta.get("modo", "auto"))
	if cand.is_empty() or modo == "no":
		_reaz_att = -1
		if settore in ["F", "A", "P"]:
			_in_attesa(p, settore, colore)
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
	var nome_t: String = te(e)["nome"]
	if modo == "ritira":
		v = _tira()
		var fallo := 1 if int(g["zanshin"]) > 0 else int(reg["fallisce_fino"])
		if v <= fallo:
			_scrivi("%s ritira per salire su %s: esce %d, il dado va in Attesa." % [g["nome"], nome_t, v])
			_evento({"t": "fallito", "p": p})
			if int(s["attivo"]) == p and s["fase"] != "reazione":
				s["cede"] = p
			_reaz_att = -1
			if settore in ["F", "A", "P"]:
				_in_attesa(p, settore, colore)
			poi.call(false)
			return
		continua = true
		_vant(p, 1)
		_scrivi("%s ritira e sale su %s con un %d%s." % [g["nome"], nome_t, v, ", e continua" if continua else ""])
	else:
		_scrivi("%s sale su %s scalando: %d." % [g["nome"], nome_t, v])
	e["dadi"].append({"c": colore, "v": v})
	var att_reaz := _reaz_att
	_reaz_att = -1
	if not posti_liberi(e).is_empty():
		poi.call(continua)
		return
	e["pronto"] = true
	if e["dadi"].size() == 1 and int(e["dadi"][0]["v"]) >= 6:
		e["pot"] = true
		_scrivi("Un 6: %s si gira sulla faccia potenziata!" % nome_t)
		_evento({"t": "segreto", "p": p, "nome": nome_t})
	if e["dadi"].size() >= 2:
		var tutti_uguali := true
		for dd in e["dadi"]:
			if int(dd["v"]) != int(e["dadi"][0]["v"]):
				tutti_uguali = false
		if tutti_uguali:
			e["pot"] = true
			_scrivi("Combinazione: %s si gira sulla faccia potenziata!" % nome_t)
			_evento({"t": "segreto", "p": p, "nome": nome_t})
	if te(e)["modo"] == "subito" and in_portata(e):
		_scatta(p, e, func(): poi.call(continua))
	elif te(e)["modo"] == "armato" and att_reaz >= 0 and e_trappola(e) and s["vinc"] < 0:
		# la reazione stessa completa la trappola: scatta subito su questo attacco
		_scrivi("%s trasforma la difesa in %s!" % [g["nome"], nome_t])
		_trappola(p, e, 0, att_reaz, func(_r): poi.call(continua))
	else:
		if te(e)["modo"] == "armato":
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
	var t := te(e)
	var eff: String = t["eff"]
	if t["eff"] == "comp":
		if not in_portata(e):
			poi.call()
			return
		_scatta_comp(p, e, poi)
		return
	var sm := somma(e) + int(t["bonus"]) + (2 if e["pot"] else 0)
	if not in_portata(e):
		poi.call()
		return
	g["esterni"].erase(e)
	_usa_oggetto(e)
	_scrivi("%s: %s!" % [g["nome"], t["nome"]])
	var fine := func():
		_sali_esterno(p, e, poi)
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
			_balzo(p, 3)
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
		"tenchi":
			_evento({"t": "tecnica", "p": p, "bers": o, "nome": t["nome"], "genere": "proiezione", "a_terra": true})
			_ferisci(o, D(sm))
			if s["vinc"] < 0:
				s["g"][p]["tenuto"] = false
				proietta(p, o, 3)
				_togli_dado_caso(o)
				_metti_a_terra(o)
			fine.call()
		"kiai":
			_evento({"t": "azione", "p": p, "effetto": "stordisci", "nome": t["nome"]})
			for x in s["g"][o]["esterni"]:
				if x["pronto"]:
					x["pronto"] = false
					x["dadi"] = []
			_svant(o, 2)
			_vant(p, 2)
			_togli_dado_alto(o)
			fine.call()
		"ritorno":
			_evento({"t": "azione", "p": p, "effetto": "concentrazione", "nome": t["nome"]})
			for i in 3:
				g["mano"].append(_nuovo_dado(g["mucchio"][rng.randi() % g["mucchio"].size()]))
			fine.call()
		"atemi":
			if not contatto():
				porta_contatto(p, 2, true)
			var dopo_a := func(dmg: int) -> void:
				if s["vinc"] < 0 and dmg > 0:
					_svant(o, 2)
					_togli_dado_alto(o)
					_metti_a_terra(o)
				fine.call()
			_attacco(p, sm + 4, massimo(e), t["nome"], "colpo", dopo_a)
		"zanshin":
			_evento({"t": "azione", "p": p, "effetto": "concentrazione", "nome": t["nome"]})
			_vant(p, 2)
			g["zanshin"] = 2
			_cura(p, 1)
			g["mano"].append(_nuovo_dado(g["mucchio"][rng.randi() % g["mucchio"].size()]))
			fine.call()
		_:
			fine.call()

## Quando un token del mediano scatta, il suo dado più alto sale nella metà dell'anello esterno del suo
## colore (una delle due sopra di lui), scalando la freccia di quella metà; gli altri dadi vanno nell'Attesa.
func _sali_esterno(p: int, e: Dictionary, poi: Callable) -> void:
	var g: Dictionary = s["g"][p]
	var zona := String(e.get("posto", ""))
	if zona == "" and e.has("posto3"):
		zona = POSTI[int(e["posto3"])]
	if zona == "":
		zona = "rosso"
	if s["vinc"] >= 0 or anello(e) != 2 or e["dadi"].is_empty():
		for dd in e["dadi"]:
			_in_attesa(p, zona, String(dd["c"]))
		poi.call()
		return
	var dadi: Array = e["dadi"].duplicate()
	dadi.sort_custom(func(a, b): return int(a["v"]) > int(b["v"]))
	var su: Dictionary = dadi[0]
	for dd in dadi.slice(1):
		_in_attesa(p, zona, String(dd["c"]))
	var col := String(tok(e["id"]).get("col", ""))
	var cand := []
	for x in g["esterni"]:
		if anello(x) == 3 and not String(x["id"]).begins_with("scena_") and te(x)["col"] == col and not x["pronto"] and not x["bloccato"] and not posti_liberi(x).is_empty():
			cand.append(x)
	if cand.is_empty():
		_in_attesa(p, zona, String(su["c"]))
		poi.call()
		return
	cand.sort_custom(func(a, b): return posti_liberi(a).size() < posti_liberi(b).size())
	var e3: Dictionary = cand[0]
	var v := maxi(1, int(su["v"]) - freccia(e3))
	e3["dadi"].append({"c": su["c"], "v": v})
	if not g.has("mezze"):
		g["mezze"] = {}
	g["mezze"]["%s:%d" % [e3["id"], int(e3.get("parte", 0))]] = {"v": v, "scambio": int(s["scambio"])}
	var nome3: String = te(e3)["nome"]
	_scrivi("Un %d sale nell'anello esterno, su %s." % [v, nome3])
	_evento({"t": "sale_esterno", "p": p, "nome": nome3})
	if not posti_liberi(e3).is_empty():
		poi.call()
		return
	e3["pronto"] = true
	if te(e3)["modo"] == "subito" and in_portata(e3):
		_scatta(p, e3, poi)
		return
	if te(e3)["modo"] == "armato":
		_scrivi("%s arma %s." % [g["nome"], nome3])
		_evento({"t": "guardia", "p": p})
	poi.call()

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
				proietta(p, o, 3)
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
	if a_terra(d):
		extra += int(reg.get("danno_a_terra", 1))
	return [extra, not dietro and not a_terra(d)]

## Attacco di p. poi riceve il danno inflitto (-1 se annullato da una trappola).
## Se il difensore è umano e può reagire, il motore si ferma in fase "reazione".
var _flag_att := {}

func _attacco(p: int, danno: int, dado_max: int, nome: String, genere: String, poi: Callable, anima := true) -> void:
	var g: Dictionary = s["g"][p]
	var d := 1 - p
	var n: Dictionary = s["g"][d]
	if anima:
		_evento({"t": "attacco", "p": p, "bers": d, "dist": distanza(), "nome": nome, "genere": genere})
	danno = D(danno)
	var flag := _flag_att
	_flag_att = {}
	var mp := mod_posizione(p)
	danno += int(mp[0])
	if n.get("esposto", false):
		danno += 1
		n["esposto"] = false
	if int(n["svantaggi"]) > 0 and danno > 0:
		_scrivi("%s sfrutta %s di %s." % [s["g"][p]["nome"], plurale(int(n["svantaggi"]), "svantaggio", "svantaggi"), n["nome"]])
		danno += int(n["svantaggi"])
		n["svantaggi"] = 0
	if flag.get("non_scarta", false):
		mp[1] = false
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
		if e["pronto"] and not e["bloccato"] and te(e)["eff"] == "guardia":
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
	# guardie a componenti: riduzione passiva
	var gu := guardia_di(d)
	if gu > 0 and danno > 0:
		danno = maxi(0, danno - gu)
		_scrivi("La guardia di %s assorbe %d." % [n["nome"], gu])
		_evento({"t": "para", "p": d})
		if danno == 0:
			poi.call(0)
			return
	# trappole armate (quelle contro le prese non scattano sui colpi)
	var trap := trappola_contro(d, genere)
	if not trap.is_empty():
		_trappola(d, trap, danno, p, poi)
		return
	var pend := {"att": p, "dif": d, "danno": danno, "dado_max": dado_max, "scartare": bool(mp[1]), "nome": nome, "poi": poi, "non_para": flag.get("non_para", false)}
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
		if dd["c"] in ["b", "n"] and not pend.get("non_para", false):
			out.append({"t": "parata", "dado": dd["id"], "riduce": D(v - int(reg.get("parata_meno", 1)))})
		if pend["scartare"] and not a_terra(d) and dd["c"] in ["g", "n"] and v >= int(pend["dado_max"]) - int(reg["scarto_tolleranza"]):
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
		var rid := D(v - int(reg.get("parata_meno", 1)))
		if scelta.get("gira", false) and int(n["vantaggi"]) >= 1 and not n["girate"].has("parata") and danno - v > 0:
			_vant(d, -1)
			n["girate"]["parata"] = true
			rid += 1
			_scrivi("%s gira la Parata: Parata ferrea!" % n["nome"])
			_ferisci(p, 1)
		var k := mini(int(n["vantaggi"]), mini(1, maxi(0, danno - rid)))
		if k > 0:
			_vant(d, -k)
			rid += k
		var resto := maxi(0, danno - rid)
		_scrivi("%s para con un %d: %s." % [n["nome"], v, "nessun danno" if resto == 0 else "passa %d" % resto])
		if resto == 0:
			s["cede"] = p
		_ferisci(d, resto)
		if s["vinc"] >= 0:
			poi.call(resto)
			return
		if rid - danno >= 3:
			_ferisci(p, 1)
		if s["vinc"] >= 0:
			poi.call(resto)
			return
		# la parata arma le trappole ma non le fa scattare su questo colpo (lo fa solo lo scarto)
		_sali(d, c, "P", false, v, salita, func(_c): poi.call(resto))
	else:
		_evento({"t": "schiva", "p": d})
		_scrivi("%s scarta il colpo con un %d." % [n["nome"], v])
		s["cede"] = p
		allontana(d, 1)
		_vant(d, 1)
		if scelta.get("gira", false) and int(n["vantaggi"]) >= 1 and not n["girate"].has("scarto"):
			_vant(d, 1)
			n["girate"]["scarto"] = true
		_reaz_att = p
		_sali(d, c, "A", false, v, salita, func(_c): poi.call(0))

func _trappola(d: int, e: Dictionary, danno: int, att: int, poi: Callable) -> void:
	# chi finisce in una trappola perde l'iniziativa
	if int(s["attivo"]) == att:
		s["cede"] = att
	if te(e)["eff"] == "comp":
		_trappola_comp(d, e, danno, att, poi)
		return
	var n: Dictionary = s["g"][d]
	var t := te(e)
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
			if s["vinc"] < 0:
				proietta(d, att, 1, false)
		"irimi":
			_evento({"t": "azione", "p": d, "effetto": "gira_nemico", "nome": t["nome"]})
			_vant(d, 3 + (1 if e["pot"] else 0))
			_svant(att, 1)
			_ferisci(att, 1)
			s["iniziativa_a"] = d
			if s["vinc"] < 0:
				_entra_al_fianco(d)
		"tenkan":
			_evento({"t": "azione", "p": d, "effetto": "ruota", "nome": t["nome"]})
			_vant(d, 1)
			_svant(att, 1)
			_ferisci(att, 1 + (1 if e["pot"] else 0))
			for x in n["mano"]:
				x["v"] = mini(6, int(x["v"]) + 1)
			_togli_dado_caso(att)
		"proiezione":
			_evento({"t": "tecnica", "p": d, "bers": att, "nome": t["nome"], "genere": "proiezione", "a_terra": true})
			_ferisci(att, sm)
			n["tenuto"] = false
			if s["vinc"] < 0:
				_svant(att, 1)
				proietta(d, att, 2)
				_metti_a_terra(att)
		"shiho", "kokyu", "juji":
			_evento({"t": "tecnica", "p": d, "bers": att, "nome": t["nome"], "genere": "proiezione", "a_terra": true})
			n["tenuto"] = false
			var tot := somma(e) + int(t["bonus"]) + (2 if e["pot"] else 0)
			_ferisci(att, maxi(1, D(tot) - (1 if eff == "juji" else 0)))
			if s["vinc"] < 0:
				_svant(att, 1)
				if eff == "juji":
					_togli_dado_caso(att)
				proietta(d, att, 2 if eff == "kokyu" else 1)
				_metti_a_terra(att)
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
	_sali_esterno(d, e, func(): poi.call(r))

# ================================================================ token a componenti

func e_trappola(e: Dictionary) -> bool:
	var t := te(e)
	if t["eff"] == "comp":
		return String(t["a"]["tipo"]) == "trappola"
	return t["eff"] in TRAPPOLE

func valore_trappola(e: Dictionary) -> int:
	var t := te(e)
	if t["eff"] != "comp":
		return int(VALORE_TRAPPOLA.get(t["eff"], 1))
	var a: Dictionary = t["a"]
	return 2 + int(a.get("proietta", 0)) * 2 + (2 if a.get("a_terra", false) else 0) + (1 if a.get("danno") != null else 0) - (1 if a.get("riduci", 0) else 0)

## Una trappola vale contro questo genere d'attacco? (colpo, lancio o presa)
func contro_ok(e: Dictionary, genere: String) -> bool:
	var t := te(e)
	if t["eff"] != "comp":
		return genere != "presa"
	var c := String(t["a"].get("contro", "tutto"))
	if c == "tutto":
		return true
	if c == "presa":
		return genere == "presa"
	return genere != "presa"

func trappola_contro(d: int, genere: String) -> Dictionary:
	var trap := []
	for e in s["g"][d]["esterni"]:
		if e["pronto"] and not e["bloccato"] and e_trappola(e) and contro_ok(e, genere):
			trap.append(e)
	if trap.is_empty():
		return {}
	trap.sort_custom(func(a, b): return valore_trappola(a) > valore_trappola(b))
	return trap[0]

## Componenti dell'azione, con la faccia potenziata se il token è potenziato.
func _a_eff(e: Dictionary) -> Dictionary:
	var a: Dictionary = te(e)["a"].duplicate()
	if e.get("pot", false):
		var pot: Dictionary = a.get("pot", {})
		for k in pot:
			a[k] = pot[k]
	return a

func _valore_comp(a: Dictionary, e: Dictionary) -> int:
	var d = a.get("danno", null)
	if d == null:
		return 0
	var v := 0
	if typeof(d) == TYPE_INT or typeof(d) == TYPE_FLOAT:
		v = int(d)
	else:
		match String(d):
			"dado":
				v = massimo(e)
			"somma":
				v = somma(e)
			"meta":
				v = D(somma(e))
			"quarto":
				v = maxi(1, D(somma(e)) / 2)
	return maxi(0, v + int(a.get("piu", 0)))

## Effetti sull'avversario o di chi agisce, scritti nei componenti dell'azione.
func _effetti_su(p: int, o: int, a: Dictionary) -> void:
	if s["vinc"] >= 0:
		return
	if int(a.get("spinta", 0)) > 0:
		spingi(p, o, int(a["spinta"]))
	if int(a.get("proietta", 0)) > 0:
		s["g"][p]["tenuto"] = false
		proietta(p, o, int(a["proietta"]))
	if s["vinc"] >= 0:
		return
	if int(a.get("svant", 0)) > 0:
		_svant(o, int(a["svant"]))
	if a.has("togli"):
		for i in int(a.get("ntogli", 1)):
			match String(a["togli"]):
				"alto":
					_togli_dado_alto(o)
				"basso":
					_togli_dado_basso(o)
				_:
					_togli_dado_caso(o)
	if a.get("esposto", false):
		s["g"][o]["esposto"] = true
	if a.get("tieni", false):
		s["g"][o]["tenuto"] = true
	if a.get("disarma", false):
		for x in s["g"][o]["esterni"]:
			if x["pronto"]:
				x["pronto"] = false
				x["dadi"] = []
	if a.get("a_terra", false):
		_metti_a_terra(o)

func _effetti_miei(p: int, a: Dictionary) -> void:
	if s["vinc"] >= 0:
		return
	var g: Dictionary = s["g"][p]
	if int(a.get("vant", 0)) > 0:
		_vant(p, int(a["vant"]))
	if int(a.get("cura", 0)) > 0:
		_cura(p, int(a["cura"]))
	if a.get("pulisci", false):
		g["svantaggi"] = 0
	for i in int(a.get("pesca", 0)):
		# riprende un dado dall'Attesa, ritirato
		for k in g["attesa"]:
			if not g["attesa"][k].is_empty():
				g["mano"].append(_nuovo_dado(String(g["attesa"][k].pop_back())))
				break
	if a.get("ritocca", false):
		for x in g["mano"]:
			x["v"] = mini(6, int(x["v"]) + 1)
	if a.get("rovescia", false) and not g["mano"].is_empty():
		var bi := 0
		for i in g["mano"].size():
			if int(g["mano"][i]["v"]) < int(g["mano"][bi]["v"]):
				bi = i
		g["mano"][bi]["v"] = 7 - int(g["mano"][bi]["v"])
	if a.get("libera", false):
		g["tenuto"] = false
	if int(a.get("passo", 0)) > 0 and not g["tenuto"]:
		if int(a.get("arretra", 0)) > 0:
			allontana(p, int(a["passo"]))
		else:
			avvicina(p, int(a["passo"]))
	elif int(a.get("arretra", 0)) > 0:
		allontana(p, int(a["arretra"]))
	if int(a.get("aggira", 0)) > 0 and contatto():
		aggira(p, int(a["aggira"]))
	if a.get("iniziativa", false):
		s["iniziativa_a"] = p

## Condizione con cui si potenzia un token dell'anello esterno, al momento dello scatto.
func cond_esterno(p: int, e: Dictionary) -> bool:
	var t := tok(e["id"])
	var o := 1 - p
	var g: Dictionary = s["g"][p]
	var mezze: Dictionary = g.get("mezze", {})
	var mia: Dictionary = mezze.get("%s:%d" % [e["id"], int(e.get("parte", 0))], {})
	var altra: Dictionary = mezze.get("%s:%d" % [e["id"], 1 - int(e.get("parte", 0))], {})
	match String(t.get("cond", "")):
		"uguali":
			return not mia.is_empty() and not altra.is_empty() and int(mia["v"]) == int(altra["v"])
		"catena":
			return not mia.is_empty() and not altra.is_empty() and int(mia["scambio"]) == int(altra["scambio"])
		"alto":
			return altezza(g["pos"]) > altezza(s["g"][o]["pos"])
		"a_terra":
			return a_terra(o)
		"spalle":
			return alle_spalle_di(o, g["pos"])
		"ferito":
			return int(g["vita"]) * 2 <= int(g["vita_max"])
		"vantaggi":
			return int(g["vantaggi"]) >= 3
		"presa":
			return g["tenuto"] or s["g"][o]["tenuto"]
		"svantaggi":
			return int(s["g"][o]["svantaggi"]) >= 2
	return false

func _effetto_anim(a: Dictionary) -> String:
	if int(a.get("cura", 0)) > 0:
		return "cura"
	if int(a.get("pesca", 0)) > 0 or a.get("ritocca", false):
		return "concentrazione"
	if int(a.get("svant", 0)) > 0 or a.has("togli"):
		return "stordisci"
	return "leggi"

func _scatta_comp(p: int, e: Dictionary, poi: Callable) -> void:
	var g: Dictionary = s["g"][p]
	var o := 1 - p
	var t := te(e)
	if anello(e) == 3:
		e["pot"] = cond_esterno(p, e)
	var a := _a_eff(e)
	g["esterni"].erase(e)
	_scrivi("%s: %s%s!" % [g["nome"], t["nome"], " potenziato" if e["pot"] else ""])
	var fine := func():
		_iniziativa_azione(p, a)
		_sali_esterno(p, e, poi)
	match String(a["tipo"]):
		"colpo":
			if a.get("alle_spalle", false):
				alle_spalle(p)
			elif int(a.get("entra", 0)) > 0 and not contatto():
				porta_contatto(p, int(a["entra"]), true)
			if not contatto():
				fine.call()
				return
			var dopo := func(dmg: int) -> void:
				if dmg > 0:
					_effetti_su(p, o, a)
				_effetti_miei(p, a)
				fine.call()
			_flag_att = {"non_scarta": a.get("non_scarta", false), "non_para": a.get("non_para", false)}
			_attacco(p, _valore_comp(a, e), massimo(e), t["nome"], "colpo", dopo)
		"presa":
			_evento({"t": "attacco", "p": p, "bers": o, "dist": 1, "nome": t["nome"], "genere": "presa"})
			var trap := trappola_contro(o, "presa")
			if not trap.is_empty():
				_trappola(o, trap, 0, p, func(_r): fine.call())
				return
			var dmg := D(_valore_comp(a, e))
			if dmg > 0:
				_ferisci(o, dmg)
			_effetti_su(p, o, a)
			_effetti_miei(p, a)
			fine.call()
		"effetto":
			_evento({"t": "azione", "p": p, "effetto": _effetto_anim(a), "nome": t["nome"]})
			_effetti_su(p, o, a)
			_effetti_miei(p, a)
			fine.call()
		_:
			fine.call()

func _trappola_comp(d: int, e: Dictionary, danno: int, att: int, poi: Callable) -> void:
	var n: Dictionary = s["g"][d]
	var t := te(e)
	if anello(e) == 3:
		e["pot"] = cond_esterno(d, e)
	var a := _a_eff(e)
	n["esterni"].erase(e)
	_scrivi("Scatta la trappola di %s: %s%s!" % [n["nome"], t["nome"], " potenziata" if e["pot"] else ""])
	var inflitto := -1
	if int(a.get("riduci", 0)) > 0:
		inflitto = maxi(0, danno - int(a["riduci"]))
		_evento({"t": "para", "p": d})
		if inflitto > 0:
			_ferisci(d, inflitto)
	elif a.get("schiva", false):
		_evento({"t": "schiva", "p": d})
		inflitto = 0
	elif int(a.get("proietta", 0)) > 0:
		_evento({"t": "tecnica", "p": d, "bers": att, "nome": t["nome"], "genere": "proiezione", "a_terra": a.get("a_terra", false)})
	else:
		_evento({"t": "azione", "p": d, "effetto": "ruota", "nome": t["nome"]})
	if inflitto < 0:
		n["tenuto"] = false
	if a.get("iniziativa", false):
		s["iniziativa_a"] = d
	if s["vinc"] < 0:
		if a.get("danno") != null:
			_ferisci(att, D(_valore_comp(a, e)))
		if a.get("contra", false) and s["vinc"] < 0:
			_evento({"t": "attacco", "p": d, "bers": att, "dist": 1, "nome": "contrattacco"})
			_ferisci(att, D(somma(e)))
		if a.get("schiva", false) and s["vinc"] < 0:
			proietta(d, att, 1, false)
		_effetti_su(d, att, a)
		_effetti_miei(d, a)
	_sali_esterno(d, e, func(): poi.call(inflitto))

## Una guardia pronta (token passivo) assorbe un colpo e si scarica: i suoi dadi vanno nell'Attesa.
func guardia_di(d: int) -> int:
	var g: Dictionary = s["g"][d]
	for e in g["esterni"]:
		if not e["pronto"] or e["bloccato"]:
			continue
		var t := te(e)
		if t["eff"] == "comp" and String(t["a"]["tipo"]) == "guardia":
			var r := int(_a_eff(e).get("riduci", 0))
			g["esterni"].erase(e)
			var zona := String(e.get("posto", "rosso"))
			for dd in e["dadi"]:
				_in_attesa(d, zona, String(dd["c"]))
			return r
	return 0

# ================================================================ azioni

func puo_agire(p: int) -> bool:
	if s["vinc"] >= 0:
		return false
	var g: Dictionary = s["g"][p]
	if not g["mano"].is_empty() or not g["fermi"].is_empty():
		return true
	for e in g["esterni"]:
		if e["pronto"] and not e["bloccato"] and te(e)["modo"] == "subito" and in_portata(e):
			return true
	return not g["raro"].is_empty() and g["raro"]["pronto"] and contatto()

## Azioni possibili di un dado in mano (per l'interfaccia): elenco di id di azione base.
func azioni_dado(p: int, dd: Dictionary) -> Array:
	var out := []
	var c: String = dd["c"]
	var cont := contatto()
	var g: Dictionary = s["g"][p]
	if a_terra(p):
		# a terra si può solo rialzarsi, con un dado qualsiasi
		return ["rialza"]
	if c in ["r", "n"] and cont:
		out.append_array(["colpo", "presa"])
	if c in ["g", "n"] and not g["tenuto"]:
		out.append("passo")
	elif c == "r" and not cont and not g["tenuto"]:
		# la Forza a distanza: un passo deciso verso l'avversario
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
	if a_terra(p) and t in ["colpo", "presa", "passo", "leggi", "gira"]:
		return "sei a terra: prima rialzati"
	match t:
		"rialza":
			var i := dado_in_mano(p, int(op.get("dado", -1)))
			if i < 0 or not a_terra(p):
				return "per rialzarti serve un dado"
			var dd: Dictionary = g["mano"][i]
			g["mano"].remove_at(i)
			g["a_terra"] = false
			_scrivi("%s si rialza." % g["nome"])
			_evento({"t": "rialza", "p": p})
			if dd["c"] in ["g", "n"]:
				# rialzarsi con l'Agilità (una ukemi): il dado prosegue e può salire, come uno scarto
				_sali(p, dd["c"], "A", true, _valore(p, int(dd["v"])), salita, func(cont): _fine_azione(p, cont))
			else:
				_in_attesa(p, {"r": "F", "b": "P"}.get(String(dd["c"]), "A"), String(dd["c"]))
				_fine_azione(p, false)
		"passa":
			s["cede"] = p
			_scrivi("%s cede l'iniziativa." % g["nome"])
			_fine_azione(p, false)
		"aumenta":
			# 1 vantaggio: +1 a un dado in mano
			var i := dado_in_mano(p, int(op.get("dado", -1)))
			if i < 0 or int(g["vantaggi"]) < 1 or int(g["mano"][i]["v"]) >= 6:
				return "serve 1 vantaggio e un dado sotto il 6"
			_vant(p, -1)
			g["mano"][i]["v"] = int(g["mano"][i]["v"]) + 1
			_evento({"t": "dado_su", "p": p})
			_scrivi("%s spende un vantaggio: il dado sale a %d." % [g["nome"], int(g["mano"][i]["v"])])
			_fine_azione(p, true)
		"potenzia":
			# 2 vantaggi: giri un token sulla faccia potenziata
			var j := int(op.get("tok", -1))
			if j < 0 or j >= g["esterni"].size() or g["esterni"][j].get("pot", false):
				return "token già potenziato"
			var costo_g := costo_gira(g["esterni"][j])
			if costo_g < 0 or int(g["vantaggi"]) < costo_g:
				return "servono %d vantaggi" % costo_g
			_vant(p, -costo_g)
			g["esterni"][j]["pot"] = true
			var nome_p: String = te(g["esterni"][j])["nome"]
			_scrivi("%s spende %s: %s si gira sulla faccia potenziata." % [g["nome"], plurale(costo_g, "vantaggio", "vantaggi"), nome_p])
			_evento({"t": "segreto", "p": p, "nome": nome_p})
			_fine_azione(p, true)
		"sblocca":
			# 3 vantaggi: un dado in mano salta le azioni base e va dritto su un token del suo colore
			var i := dado_in_mano(p, int(op.get("dado", -1)))
			var j := int(op.get("tok", -1))
			if i < 0 or j < 0 or j >= g["esterni"].size():
				return "servono un dado e un token"
			var dd: Dictionary = g["mano"][i]
			var e: Dictionary = g["esterni"][j]
			var costo_s := costo_sblocca(e)
			if not puo_sbloccare(e, String(dd["c"])) or costo_s < 0 or int(g["vantaggi"]) < costo_s:
				return "quel dado non entra in quel token"
			_vant(p, -costo_s)
			g["mano"].remove_at(i)
			_scrivi("%s spende %s: il dado va dritto su %s." % [g["nome"], plurale(costo_s, "vantaggio", "vantaggi"), te(e)["nome"]])
			_metti_su(p, e, String(dd["c"]), int(dd["v"]), func(): _fine_azione(p, true))
		"sacrifica":
			# un dado in mano va in Attesa: +1 vantaggio
			var i := dado_in_mano(p, int(op.get("dado", -1)))
			if i < 0:
				return "nessun dado da sacrificare"
			var dd: Dictionary = g["mano"][i]
			g["mano"].remove_at(i)
			_in_attesa(p, {"r": "rosso", "g": "giallo", "b": "blu"}.get(String(dd["c"]), "verde"), String(dd["c"]))
			_vant(p, 1)
			_scrivi("%s sacrifica un dado: +1 vantaggio." % g["nome"])
			_evento({"t": "sacrificio", "p": p})
			_fine_azione(p, true)
		"colpo":
			var i := dado_in_mano(p, int(op.get("dado", -1)))
			if i < 0 or not contatto() or not g["mano"][i]["c"] in ["r", "n"]:
				return "il colpo vuole un dado rosso o bianco e il contatto"
			var dd: Dictionary = g["mano"][i]
			g["mano"].remove_at(i)
			var v := _valore(p, int(dd["v"]))
			# la Forza: un colpo con il dado rosso pesa di più
			var dmg := v + (int(reg.get("colpo_rosso", 2)) if dd["c"] == "r" else 0)
			if op.get("pesante", false) and int(g["vantaggi"]) >= 1 and not g["girate"].has("colpo"):
				_vant(p, -1)
				g["girate"]["colpo"] = true
				dmg += 2
				_scrivi("%s gira il Colpo: Colpo pesante!" % g["nome"])
			var dopo := func(_dmg: int) -> void:
				if s["vinc"] >= 0:
					s["fase"] = "fine"
					return
				_iniziativa_azione(p, {"cede_svant": 3})
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
			var trap_p := trappola_contro(o, "presa")
			if not trap_p.is_empty():
				_in_attesa(p, "F", String(dd["c"]))
				_trappola(o, trap_p, 0, p, func(_r): _fine_azione(p, false))
				return ""
			_scrivi("%s afferra %s con un %d." % [g["nome"], s["g"][o]["nome"], v])
			_svant(o, 1)
			_togli_dado_alto(o)
			if v >= 5:
				s["g"][o]["tenuto"] = true
			if v >= int(reg["presa_soglia_spinta"]):
				spingi(p, o, 1)
			g["fermi"].append({"c": dd["c"], "az": "presa", "v": v})
			# la presa tiene l'iniziativa, ma sbilancia anche te
			_svant(p, 1)
			_fine_azione(p, false)
		"passo":
			var i := dado_in_mano(p, int(op.get("dado", -1)))
			var rosso_ok: bool = i >= 0 and g["mano"][i]["c"] == "r" and not contatto() and not op.get("via", false)
			if i < 0 or g["tenuto"] or not (g["mano"][i]["c"] in ["g", "n"] or rosso_ok):
				return "il passo vuole un dado giallo o bianco (o rosso, per avanzare verso l'avversario)"
			var dd: Dictionary = g["mano"][i]
			g["mano"].remove_at(i)
			var v := _valore(p, int(dd["v"]))
			var k := 1 if dd["c"] == "r" else (2 if v >= 5 else 1)
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
						_scrivi("%s è bloccato fino alla pausa." % te(cand[0])["nome"])
				"passo":
					_scrivi("%s gira il Passo: Balzo!" % g["nome"])
					_balzo(p, 3)
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
			if not e["pronto"] or e["bloccato"] or te(e)["modo"] != "subito" or not in_portata(e):
				return "il token non può scattare ora"
			_scatta(p, e, func(): _fine_azione(p, false))
		"raro":
			if g["raro"].is_empty() or not g["raro"]["pronto"] or not contatto():
				return "il token raro non è pronto"
			_scatta_raro(p, func(): _fine_azione(p, false))
		_:
			return "azione sconosciuta"
	return ""

## Dopo ogni azione l'iniziativa resta a chi agisce, finché non la cede: reazione riuscita
## dell'avversario, ritiro fallito, 3 svantaggi, o passa.
func _fine_azione(p: int, _flusso: bool, aggirato := false) -> void:
	if s["vinc"] >= 0:
		s["fase"] = "fine"
		return
	if s["fase"] == "reazione":
		return
	if not aggirato:
		gira_verso(p)
	_rimetti_in_campo(0)
	_rimetti_in_campo(1)
	if int(s["iniziativa_a"]) >= 0:
		if int(s["iniziativa_a"]) != p:
			_cedi(p)
		s["iniziativa_a"] = -1
		s["cede"] = -1
	elif int(s.get("cede", -1)) == p:
		s["cede"] = -1
		_cedi(p)
	_avanza()

## Chi cede l'iniziativa riprende i dadi in Attesa e quelli fermi sulle azioni base, ritirati.
func _cedi(p: int) -> void:
	var g: Dictionary = s["g"][p]
	s["attivo"] = 1 - p
	s["scambio"] += 1
	var torna := []
	for k in g["attesa"]:
		torna.append_array(g["attesa"][k])
	g["attesa"] = _attesa_vuota()
	for f in g["fermi"]:
		torna.append(f["c"])
	g["fermi"] = []
	if torna.is_empty() and g["mano"].is_empty():
		# niente da riprendere: tornano anche i dadi dei token del mediano non ancora pieni
		for e in g["esterni"]:
			if anello(e) == 2 and not e["pronto"]:
				for dd in e["dadi"]:
					torna.append(dd["c"])
				e["dadi"] = []
	for c in torna:
		g["mano"].append(_nuovo_dado(c))
	g["girate"] = {}
	g["flussi"] = 0
	g["occhio"] = false
	# il token di scena dell'oggetto vicino, se non c'è già
	var ogg := oggetto_vicino(g["pos"])
	var ha_scena := false
	for e in g["esterni"]:
		if String(e["id"]).begins_with("scena_"):
			ha_scena = true
	if ogg != "" and not ha_scena:
		for k in COPPIE.size():
			if not g["assetto3"].has(k):
				var es := _nuovo_token("scena_" + ogg)
				es["ogg_h"] = _casella_oggetto(g["pos"], ogg)
				es["posto3"] = k
				g["esterni"].append(es)
				break
	g["zanshin"] = maxi(0, int(g["zanshin"]) - 1)
	# chi prende l'iniziativa si libera dalla presa; chi la cede, se è tenuto, resta tenuto
	# (un'immobilizzazione dura finché l'avversario non riprende l'iniziativa)
	s["g"][1 - p]["tenuto"] = false
	_evento({"t": "iniziativa", "p": 1 - p, "tornano": torna.size()})
	_scrivi("— L'iniziativa passa a %s (%d)." % [s["g"][1 - p]["nome"], int(s["scambio"])])
	gira_verso(0)
	gira_verso(1)

## I token scattati tornano vuoti al loro posto, subito.
func _rimetti_in_campo(p: int) -> void:
	var g: Dictionary = s["g"][p]
	var ci := {}
	for e in g["esterni"]:
		ci["%s:%d" % [e["id"], int(e.get("parte", 0))]] = true
	for k in POSTI:
		for id in g["assetto"].get(k, []):
			for e in _nuove_parti(id):
				if not ci.has("%s:%d" % [id, int(e["parte"])]):
					e["posto"] = k
					g["esterni"].append(e)
	for k in g["assetto3"]:
		for e in _nuove_parti(g["assetto3"][k]):
			if not ci.has("%s:%d" % [g["assetto3"][k], int(e["parte"])]):
				e["posto3"] = int(k)
				g["esterni"].append(e)

func costo_gira(e: Dictionary) -> int:
	return int(tok(e["id"]).get("gira", -1)) if not String(e["id"]).begins_with("scena_") else -1

func costo_sblocca(e: Dictionary) -> int:
	return int(tok(e["id"]).get("sblocca", -1)) if not String(e["id"]).begins_with("scena_") else -1

## Un token in cui un dado di quel colore può entrare direttamente (sblocco).
func puo_sbloccare(e: Dictionary, colore: String) -> bool:
	if e["pronto"] or e["bloccato"] or String(e["id"]).begins_with("scena_"):
		return false
	var t := te(e)
	if not SETTORI_COL.has(String(t["col"])):
		return false
	var sett: String = SETTORI_COL[t["col"]]
	if anello(e) == 3:
		return (colore == "n" or SETTORE_DADO.get(colore, "") in sett) and not posti_liberi(e).is_empty()
	if colore != "n" and not SETTORE_DADO.get(colore, "") in sett:
		return false
	return not posti_liberi(e).is_empty()

## Mette un dado su un token e lo fa scattare se è pieno.
func _metti_su(p: int, e: Dictionary, colore: String, v: int, poi: Callable) -> void:
	e["dadi"].append({"c": colore, "v": v})
	if not posti_liberi(e).is_empty():
		poi.call()
		return
	e["pronto"] = true
	if te(e)["modo"] == "subito" and in_portata(e):
		_scatta(p, e, poi)
		return
	if te(e)["modo"] == "armato":
		_scrivi("%s arma %s." % [s["g"][p]["nome"], te(e)["nome"]])
		_evento({"t": "guardia", "p": p})
	poi.call()

func _avanza() -> void:
	if s["vinc"] >= 0:
		s["fase"] = "fine"
		return
	if s["fase"] != "azione":
		return
	if int(s["scambio"]) >= int(reg["max_scambi"]):
		s["fase"] = "fine"
		var a: int = s["g"][0]["vita"]
		var b: int = s["g"][1]["vita"]
		s["vinc"] = 0 if a > b else (1 if b > a else 2)
		_scrivi("Il duello finisce ai punti.")
		return
	# chi non può fare più nulla cede l'iniziativa (al massimo due volte di fila)
	for i in 2:
		if puo_agire(int(s["attivo"])):
			return
		_cedi(int(s["attivo"]))

# ================================================================ intelligenza artificiale

func _trappole_nemiche(p: int) -> bool:
	for e in s["g"][1 - p]["esterni"]:
		if e["pronto"] and not e["bloccato"] and e_trappola(e):
			return true
	return false

## Scelta dell'IA per l'azione di p (stessa logica del simulatore).
func ia_scegli(p: int) -> Dictionary:
	var g: Dictionary = s["g"][p]
	var n: Dictionary = s["g"][1 - p]
	if a_terra(p) and not g["mano"].is_empty():
		var basso: Dictionary = g["mano"][0]
		for dd in g["mano"]:
			var pref := 0 if dd["c"] in ["g", "n"] else 10
			var pref_b := 0 if basso["c"] in ["g", "n"] else 10
			if pref - int(dd["v"]) * 0.1 < pref_b - int(basso["v"]) * 0.1:
				basso = dd
		return {"t": "rialza", "dado": basso["id"]}
	var op := []
	var trap := not trappola_contro(1 - p, "colpo").is_empty()
	var trap_presa := not trappola_contro(1 - p, "presa").is_empty()
	var cont := contatto()
	for j in g["esterni"].size():
		var e: Dictionary = g["esterni"][j]
		if e["pronto"] and not e["bloccato"] and te(e)["modo"] == "subito" and in_portata(e):
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
			# una trappola contro i colpi si aggira con una presa, e viceversa
			if trap and not trap_presa:
				pr += 3.0
			elif trap_presa:
				pr = 0.5
			op.append([pr, {"t": "presa", "dado": id}])
		if c == "r" and not cont and not g["tenuto"]:
			op.append([4.0, {"t": "passo", "dado": id}])
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
	# vantaggi: girare un token, sbloccare un dado, alzarne uno; dadi inutili si sacrificano
	var va := int(g["vantaggi"])
	for j in g["esterni"].size():
		var e: Dictionary = g["esterni"][j]
		var cg := costo_gira(e)
		if cg > 0 and cg <= va and not e.get("pot", false) and not e["bloccato"]:
			if e["pronto"]:
				op.append([4.6 + cg * 0.2, {"t": "potenzia", "tok": j}])
			elif posti_liberi(e).size() == 1 and va - cg >= 1:
				op.append([2.6, {"t": "potenzia", "tok": j}])
	for dd in g["mano"]:
		var id: int = dd["id"]
		var usabile := not azioni_dado(p, dd).is_empty()
		for j in g["esterni"].size():
			var e: Dictionary = g["esterni"][j]
			var cs := costo_sblocca(e)
			if cs > 0 and cs <= va and puo_sbloccare(e, String(dd["c"])):
				var vicino := posti_liberi(e).size() == 1
				op.append([(4.2 if vicino else 2.4) + (1.5 if not usabile else 0.0) + (0.8 if anello(e) == 3 else 0.0), {"t": "sblocca", "dado": id, "tok": j}])
		if not usabile and int(dd["v"]) <= 2 and va < int(reg["max_vant"]):
			op.append([1.2, {"t": "sacrifica", "dado": id}])
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
