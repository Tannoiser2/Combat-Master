extends SceneTree
## Test del gioco a mani nude: attacchi numerati, prese dorsali, tecniche di neutralizzazione.
## uso: godot --headless --path . --script tests/aikido_test.gd

var errori := 0
var dati: Dictionary

func controlla(cond: bool, msg: String) -> void:
	if not cond:
		errori += 1
		printerr("ERRORE: " + msg)

func duello(t0: Dictionary, t1: Dictionary) -> Motore:
	var m := Motore.new(dati)
	m.nuova_partita({"nome": "Alfa", "token": t0}, {"nome": "Beta", "token": t1}, "cortile", 5)
	m.s["g"][0]["pos"] = Vector2i(0, 0)
	m.s["g"][0]["dir"] = 0
	m.s["g"][1]["pos"] = Vector2i(1, 0)
	m.s["g"][1]["dir"] = 3
	m.s["fase"] = "azione"
	m.s["attivo"] = 0
	m.s["ost"] = {}
	m.s["per"] = {}
	for p in 2:
		for d in m.s["g"][p]["dadi"]:
			d["st"] = "mucchio"
	return m

func dado(m: Motore, p: int, col: String, v: int) -> int:
	for d in m.s["g"][p]["dadi"]:
		if d["col"] == col and d["st"] == "mucchio" and not d.get("_preso", false):
			d["v"] = v
			d["_preso"] = true
			return d["id"]
	controlla(false, "manca un dado %s" % col)
	return -1

func _init() -> void:
	dati = Motore.carica_dati()
	var cat: Dictionary = dati["per_id"]
	controlla(not cat.has("spada") and not cat.has("dardo_arcano"), "armi e magie nascoste (espansione fantasy)")
	controlla(cat.has("att01") and cat.has("tec_p28"), "carte attacco e tecnica presenti")
	for pg in dati["personaggi"]:
		for id in pg["token"]:
			controlla(cat.has(id), "%s usa %s, che non c'è" % [pg["nome"], id])

	var base := {"forza": 1, "agilita": 1, "tempra": 1, "mente": 1}
	# presa al polso (attacco 1) neutralizzata dalla proiezione a spirale (P1)
	var t1 := base.duplicate()
	t1["tec_p1"] = 1
	t1["tec_p7"] = 1
	var a0 := base.duplicate()
	a0["att01"] = 1
	a0["att07"] = 1
	var m := duello(a0, t1)
	var r := dado(m, 0, "rosso", 4)
	controlla(m.applica(0, {"t": "slot", "tok": "att01", "slot": "colpo", "dadi": [r], "b": {"bers": 1}}) == "", "presa al polso dichiarata")
	if m.s["fase"] == "rinforzo":
		m.applica(0, {"t": "sferra"})
	controlla(m.s["fase"] == "reazione", "dopo la presa il difensore può reagire (fase %s)" % m.s["fase"])
	controlla(m.reazione_possibile(1, m.slot_def("tec_p1", "tecnica")), "P1 vale contro l'attacco 1")
	controlla(not m.reazione_possibile(1, m.slot_def("tec_p7", "tecnica")), "P7 non vale contro l'attacco 1")
	var vita_att: int = m.s["g"][0]["vita"]
	var vita_dif: int = m.s["g"][1]["vita"]
	var pos_att: Vector2i = m.s["g"][0]["pos"]
	var b := dado(m, 1, "blu", 6)
	controlla(m.applica(1, {"t": "slot", "tok": "tec_p1", "slot": "tecnica", "dadi": [b], "b": {}}) == "", "proiezione eseguita")
	controlla(m.s["g"][1]["vita"] == vita_dif, "la tecnica annulla l'attacco: il difensore non subisce danni")
	controlla(m.s["g"][0]["vita"] < vita_att, "chi attaccava viene proiettato e si ferisce")
	controlla(m.s["g"][0]["pos"] != pos_att, "chi viene proiettato vola via dal suo esagono")

	# le prese dorsali si tentano solo da dietro
	m = duello(a0, t1)
	r = dado(m, 0, "blu", 4)
	var r2 := dado(m, 0, "rosso", 4)
	controlla(m.bersagli(0, "att07", m.slot_def("att07", "colpo"), [r, r2]).is_empty(), "presa dorsale impossibile di fronte")
	m.s["g"][1]["dir"] = 0
	controlla(not m.bersagli(0, "att07", m.slot_def("att07", "colpo"), [r, r2]).is_empty(), "presa dorsale possibile alle spalle")

	# i colpi delle schede (senza numero) valgono come colpi: le tecniche contro 13-15 rispondono
	var t2 := base.duplicate()
	t2["tec_i1"] = 1
	m = duello(base, t2)
	r = dado(m, 0, "rosso", 5)
	m.applica(0, {"t": "slot", "tok": "forza", "slot": "pugno", "dadi": [r], "b": {"bers": 1}})
	if m.s["fase"] == "rinforzo":
		m.applica(0, {"t": "sferra"})
	controlla(m.reazione_possibile(1, m.slot_def("tec_i1", "tecnica")), "il controllo del braccio risponde a un pugno")
	b = dado(m, 1, "verde", 3)
	var vant0: int = m.s["g"][0]["svantaggi"]
	controlla(m.applica(1, {"t": "slot", "tok": "tec_i1", "slot": "tecnica", "dadi": [b], "b": {}}) == "", "immobilizzazione eseguita")
	controlla(int(m.s["g"][0]["svantaggi"]) > vant0, "l'immobilizzato prende svantaggi")

	if errori == 0:
		print("OK: attacchi numerati, prese dorsali e tecniche di neutralizzazione funzionano")
	quit(errori)
