extends SceneTree
## Test headless delle regole e partite automatiche IA contro IA.
## uso: godot --headless --path . --script tests/regole_test.gd [-- partite=N]

var errori := 0

func controlla(cond: bool, msg: String) -> void:
	if not cond:
		errori += 1
		printerr("ERRORE: " + msg)

func _init() -> void:
	var dati := Motore.carica_dati()
	var cat: Dictionary = dati["per_id"]
	# costi dei personaggi pronti entro il budget
	for pg in dati["personaggi"]:
		var c := Motore.costo_personaggio(cat, pg)
		controlla(c <= int(pg["budget"]), "%s costa %d oltre %d" % [pg["nome"], c, pg["budget"]])
		for id in pg["token"]:
			controlla(cat.has(id), "%s: token %s inesistente" % [pg["nome"], id])
	# ogni slot ha campi coerenti
	for t in dati["token"]:
		for sl in t["slot"]:
			controlla(sl["tipo"] in ["azione", "reazione", "libera", "supporto_attacco", "supporto_difesa", "segreto", "contatore"], "%s/%s tipo" % [t["id"], sl["id"]])
			controlla(sl["dadi"].size() >= 1 and sl["dadi"].size() <= 3, "%s/%s dadi" % [t["id"], sl["id"]])
			controlla(sl.has("testo") and sl.has("nome"), "%s/%s testo" % [t["id"], sl["id"]])

	# geometria
	controlla(Motore.dist(Vector2i(0, 0), Vector2i(3, -1)) == 3, "distanza")
	controlla(Motore.lato(Vector2i(0, 0), 0, Vector2i(1, 0)) == "fronte", "fronte")
	controlla(Motore.lato(Vector2i(0, 0), 0, Vector2i(-1, 0)) == "retro", "retro")
	controlla(Motore.lato(Vector2i(0, 0), 0, Vector2i(0, -1)) == "fianco", "fianco")
	controlla(Motore.lato(Vector2i(0, 0), 0, Vector2i(1, -1)) == "fronte", "fronte diagonale")

	# meccaniche di base: si pesca il ritmo dal mucchio
	var m := Motore.new(dati)
	m.nuova_partita(dati["personaggi"][0], dati["personaggi"][1], "cortile", 7)
	controlla(m.s["round"] == 1, "primo scambio")
	controlla(m.s["fase"] == "pesca", "si comincia scegliendo dal mucchio")
	for d in m.s["g"][0]["dadi"]:
		controlla(d["v"] >= 1 and d["v"] <= 6, "il mucchio è già tirato")
	controlla(m.applica(m.chi_decide(), {"t": "prendi", "dadi": []}) != "", "bisogna prendere il ritmo giusto")
	while m.s["fase"] == "pesca":
		var chi := m.chi_decide()
		controlla(m.applica(chi, IA.scegli(m, chi)) == "", "scelta dal mucchio")
	for p in 2:
		var g0: Dictionary = m.s["g"][p]
		controlla(m.dadi_di(p, "mano").size() == mini(g0["ritmo"], g0["dadi"].size()), "in mano tanti dadi quanto il ritmo")
	var p: int = m.chi_decide()
	controlla(m.opzioni(p).size() > 1, "ci sono opzioni all'inizio")
	var rag := m.raggiungibili(p, 1)
	var g: Dictionary = m.s["g"][p]
	var avanti: Vector2i = g["pos"] + Motore.DIRS[g["dir"]]
	controlla(rag["costo"].has(Vector3i(avanti.x, avanti.y, g["dir"])), "un passo avanti con 1 punto")
	var dietro: Vector2i = g["pos"] - Motore.DIRS[g["dir"]]
	controlla(not rag["costo"].has(Vector3i(dietro.x, dietro.y, g["dir"])), "indietro costa 2")
	var ids := []
	for d in m.dadi_di(p, "mano"):
		ids.append(d["id"])
	controlla(m.applica(p, {"t": "spinta", "dadi": [ids[0]]}) == "", "spinta")
	controlla(m.applica(p, {"t": "spinta", "dadi": [ids[0]]}) != "", "una sola spinta per scambio")

	# un colpo occupa lo spazio; lo sblocco mette il dado in Attesa, il Riposo lo recupera
	var m2 := Motore.new(dati)
	m2.nuova_partita(dati["personaggi"][0], dati["personaggi"][1], "cortile", 3)
	m2.s["g"][0]["pos"] = Vector2i(0, 0)
	m2.s["g"][0]["dir"] = 0
	m2.s["g"][1]["pos"] = Vector2i(1, 0)
	m2.s["g"][1]["dir"] = 3
	m2.s["attivo"] = 0
	m2.s["fase"] = "azione"
	for d in m2.s["g"][0]["dadi"]:
		d["st"] = "mucchio"
	var rosso := -1
	for d in m2.s["g"][0]["dadi"]:
		if d["col"] == "rosso":
			d["st"] = "mano"
			d["v"] = 5
			rosso = d["id"]
			break
	for d in m2.s["g"][1]["dadi"]:
		d["st"] = "mucchio"
	var vita1: int = m2.s["g"][1]["vita"]
	var esito := m2.applica(0, {"t": "slot", "tok": "spada", "slot": "fendente", "dadi": [rosso], "b": {"bers": 1, "lato": 0}})
	controlla(esito == "", "fendente valido: " + esito)
	if m2.s["fase"] == "rinforzo":
		m2.applica(0, {"t": "sferra"})
	if m2.s["fase"] == "reazione":
		m2.applica(1, {"t": "risolvi"})
	controlla(m2.s["g"][1]["vita"] == vita1 - (5 - m2.s["g"][1]["armatura"]), "danno del fendente meno armatura")
	controlla(m2.occupato(0, "spada", "fendente"), "il fendente resta occupato")
	controlla(m2.dado(0, rosso)["st"] == "token", "il dado resta sul token")
	m2.s["attivo"] = 0
	m2.s["g"][0]["passato"] = false
	controlla(m2.applica(0, {"t": "passa", "slots": ["spada/fendente"]}) == "", "passando si libera uno spazio")
	controlla(not m2.occupato(0, "spada", "fendente"), "spazio liberato")
	controlla(m2.dado(0, rosso)["st"] == "attesa", "il dado sbloccato passa in Attesa")
	m2.s["fase"] = "azione"
	m2.s["attivo"] = 0
	m2.s["g"][0]["passato"] = false
	controlla(m2.opzioni(0).any(func(op): return op["t"] == "riposo"), "riposo disponibile con dadi in Attesa")
	controlla(m2.applica(0, {"t": "riposo"}) == "", "riposo recupera i dadi")
	controlla(m2.dado(0, rosso)["st"] == "mucchio", "riposo riporta il dado nel mucchio")
	m2.s["fase"] = "azione"
	m2.s["attivo"] = 0
	m2.s["g"][0]["passato"] = false
	controlla(m2.applica(0, {"t": "riposo"}) != "", "riposo solo una volta per scambio")
	# Una mossa di emergenza consuma un dado basso e libera un token, senza duplicare dadi.
	var libero := -1
	var occupato_dado := -1
	for d in m2.s["g"][0]["dadi"]:
		if d["st"] == "mucchio" and libero < 0:
			libero = d["id"]
			d["st"] = "mano"
			d["v"] = 1
		elif d["st"] == "mucchio" and occupato_dado < 0:
			occupato_dado = d["id"]
			d["st"] = "token"
	if libero >= 0 and occupato_dado >= 0:
		m2.s["g"][0]["occupati"]["spada/fendente"] = [occupato_dado]
		controlla(m2.applica(0, {"t": "emergenza", "key": "spada/fendente", "dado": libero}) == "", "sblocco emergenza")
		controlla(not m2.occupato(0, "spada", "fendente"), "emergenza libera lo spazio")
		controlla(m2.dado(0, libero)["st"] == "attesa" and m2.dado(0, occupato_dado)["st"] == "attesa", "emergenza non ricicla immediatamente")
		m2.s["fase"] = "azione"
		m2.s["attivo"] = 0
		m2.s["g"][0]["passato"] = false
		controlla(m2.applica(0, {"t": "emergenza", "key": "spada/fendente", "dado": libero}) != "", "emergenza una volta per scambio")
	else:
		controlla(false, "dadi sufficienti per test emergenza")

	# segreto: la trappola scatta quando si viene attaccati in mischia
	var m3 := Motore.new(dati)
	var pg_t := {"nome": "Trappolatore", "token": {"forza": 1, "tempra": 1, "trappola": 1}}
	var pg_a := {"nome": "Spadaccino", "token": {"forza": 2, "spada": 1}}
	m3.nuova_partita(pg_t, pg_a, "cortile", 9)
	m3.s["fase"] = "azione"
	m3.s["attivo"] = 0
	m3.s["g"][0]["pos"] = Vector2i(0, 0)
	m3.s["g"][0]["dir"] = 0
	m3.s["g"][1]["pos"] = Vector2i(1, 0)
	m3.s["g"][1]["dir"] = 3
	var r0 := -1
	for d in m3.s["g"][0]["dadi"]:
		if d["col"] == "rosso":
			d["st"] = "mano"
			d["v"] = 4
			r0 = d["id"]
	controlla(m3.applica(0, {"t": "slot", "tok": "trappola", "slot": "trappola", "dadi": [r0], "b": {}}) == "", "si carica la trappola")
	controlla(m3.s["g"][0]["armati"].size() == 1, "trappola carica")
	var r1 := -1
	for d in m3.s["g"][1]["dadi"]:
		if d["col"] == "rosso" and r1 < 0:
			d["st"] = "mano"
			d["v"] = 3
			r1 = d["id"]
	m3.s["attivo"] = 1
	var v1: int = m3.s["g"][1]["vita"]
	controlla(m3.applica(1, {"t": "slot", "tok": "spada", "slot": "fendente", "dadi": [r1], "b": {"bers": 0, "lato": 0}}) == "", "attacco sulla trappola")
	controlla(m3.s["g"][1]["vita"] == v1 - 4, "la trappola ferisce l'attaccante")
	controlla(m3.s["g"][0]["rivelati"].has("trappola"), "il segreto si rivela")

	# partite automatiche
	var n := 40
	for a in OS.get_cmdline_user_args():
		if a.begins_with("partite="):
			n = int(a.split("=")[1])
	var vittorie := {}
	var scambi := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var pgs: Array = dati["personaggi"]
	var t0 := Time.get_ticks_msec()
	for i in n:
		var a: Dictionary = pgs[rng.randi_range(0, pgs.size() - 1)]
		var b: Dictionary = pgs[rng.randi_range(0, pgs.size() - 1)]
		var arena: String = ["cortile", "rovine", "fossa"][i % 3]
		var mm := Motore.new(dati)
		mm.nuova_partita(a, b, arena, i)
		var passi := 0
		while mm.s["vinc"] < 0 and passi < 3000:
			var chi := mm.chi_decide()
			var op := IA.scegli(mm, chi, rng)
			var e := mm.applica(chi, op)
			if e != "":
				controlla(false, "IA ha scelto un'opzione rifiutata: %s %s" % [e, op])
				break
			passi += 1
		controlla(mm.s["vinc"] >= 0, "partita %d non finita (%s contro %s)" % [i, a["nome"], b["nome"]])
		scambi += int(mm.s["round"])
		var w: String = mm.s["g"][max(0, mm.s["vinc"])]["nome"]
		vittorie[w] = int(vittorie.get(w, 0)) + 1
	print("Partite: %d in %d ms, scambi medi %.1f" % [n, Time.get_ticks_msec() - t0, float(scambi) / max(1, n)])
	for k in vittorie:
		print("  %s: %d" % [k, vittorie[k]])
	if errori == 0:
		print("OK: tutti i test delle regole sono passati")
	quit(1 if errori > 0 else 0)
