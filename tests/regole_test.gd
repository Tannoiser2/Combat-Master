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
			controlla(sl["tipo"] in ["azione", "reazione"], "%s/%s tipo" % [t["id"], sl["id"]])
			controlla(sl["dadi"].size() >= 1 and sl["dadi"].size() <= 3, "%s/%s dadi" % [t["id"], sl["id"]])
			controlla(sl.has("testo") and sl.has("nome"), "%s/%s testo" % [t["id"], sl["id"]])

	# geometria
	controlla(Motore.dist(Vector2i(0, 0), Vector2i(3, -1)) == 3, "distanza")
	controlla(Motore.lato(Vector2i(0, 0), 0, Vector2i(1, 0)) == "fronte", "fronte")
	controlla(Motore.lato(Vector2i(0, 0), 0, Vector2i(-1, 0)) == "retro", "retro")
	controlla(Motore.lato(Vector2i(0, 0), 0, Vector2i(0, -1)) == "fianco", "fianco")
	controlla(Motore.lato(Vector2i(0, 0), 0, Vector2i(1, -1)) == "fronte", "fronte diagonale")

	# meccaniche di base
	var m := Motore.new(dati)
	m.nuova_partita(dati["personaggi"][0], dati["personaggi"][1], "cortile", 7)
	controlla(m.s["round"] == 1, "primo scambio")
	for p in 2:
		controlla(m.dadi_di(p, "pronto").size() == m.s["g"][p]["dadi"].size(), "tutti i dadi tirati")
	var p: int = m.chi_decide()
	var opz := m.opzioni(p)
	controlla(opz.size() > 1, "ci sono opzioni all'inizio")
	# movimento: avanti costa 1
	var rag := m.raggiungibili(p, 1)
	var g: Dictionary = m.s["g"][p]
	var avanti: Vector2i = g["pos"] + Motore.DIRS[g["dir"]]
	controlla(rag["costo"].has(Vector3i(avanti.x, avanti.y, g["dir"])), "un passo avanti con 1 punto")
	var dietro: Vector2i = g["pos"] - Motore.DIRS[g["dir"]]
	controlla(not rag["costo"].has(Vector3i(dietro.x, dietro.y, g["dir"])), "indietro costa 2")
	# spinta: la prima è gratuita
	var r0: int = m.ritmo_libero(p)
	var ids := []
	for d in m.dadi_di(p, "pronto"):
		ids.append(d["id"])
	controlla(m.applica(p, {"t": "spinta", "dadi": [ids[0]]}) == "", "spinta")
	controlla(m.ritmo_libero(p) == r0, "prima spinta gratis")
	if m.dadi_di(p, "pronto").size() > 0:
		var r1: int = m.ritmo_libero(p)
		m.applica(p, {"t": "spinta", "dadi": [m.dadi_di(p, "pronto")[0]["id"]]})
		controlla(m.ritmo_libero(p) == r1 - 1, "seconda spinta costa ritmo")

	# attacco con reazione: due combattenti adiacenti
	var m2 := Motore.new(dati)
	m2.nuova_partita(dati["personaggi"][0], dati["personaggi"][1], "cortile", 3)
	m2.s["g"][0]["pos"] = Vector2i(0, 0)
	m2.s["g"][0]["dir"] = 0
	m2.s["g"][1]["pos"] = Vector2i(1, 0)
	m2.s["g"][1]["dir"] = 3
	m2.s["attivo"] = 0
	for d in m2.s["g"][0]["dadi"]:
		if d["col"] == "rosso":
			d["v"] = 5
	var rosso := -1
	for d in m2.dadi_di(0, "pronto"):
		if d["col"] == "rosso":
			rosso = d["id"]
			break
	var vita1: int = m2.s["g"][1]["vita"]
	var esito := m2.applica(0, {"t": "slot", "tok": "spada", "slot": "fendente", "dadi": [rosso], "b": {"bers": 1}})
	controlla(esito == "", "fendente valido: " + esito)
	if m2.s["fase"] == "reazione":
		m2.applica(1, {"t": "risolvi"})
	controlla(m2.s["g"][1]["vita"] == vita1 - (5 - m2.s["g"][1]["armatura"]), "danno del fendente meno armatura")

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
