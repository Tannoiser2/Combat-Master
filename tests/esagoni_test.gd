extends SceneTree
## Test delle guardie sull'esagono, dei colpi mirati e dei movimenti imposti dalle mosse.
## uso: godot --headless --path . --script tests/esagoni_test.gd

var errori := 0
var dati: Dictionary

func controlla(cond: bool, msg: String) -> void:
	if not cond:
		errori += 1
		printerr("ERRORE: " + msg)

## Due combattenti uno davanti all'altro al centro del cortile, tocca a `chi`.
func duello(t0: Dictionary, t1: Dictionary, chi := 0) -> Motore:
	var m := Motore.new(dati)
	m.nuova_partita({"nome": "Alfa", "token": t0}, {"nome": "Beta", "token": t1}, "cortile", 5)
	m.regole["attrito_mucchio"] = 1  # le prove di meccanica sono tarate su attrito 1
	m.s["g"][0]["pos"] = Vector2i(0, 0)
	m.s["g"][0]["dir"] = 0
	m.s["g"][1]["pos"] = Vector2i(1, 0)
	m.s["g"][1]["dir"] = 3
	m.s["fase"] = "azione"
	m.s["attivo"] = chi
	m.s["ost"] = {}
	m.s["per"] = {}
	for p in 2:
		for d in m.s["g"][p]["dadi"]:
			d["st"] = "mucchio"
	return m

## Mette in mano a p un dado del colore dato con il valore dato.
func in_mano(m: Motore, p: int, col: String, v: int) -> int:
	for d in m.s["g"][p]["dadi"]:
		if d["col"] == col and d["st"] == "mucchio":
			d["st"] = "mano"
			d["v"] = v
			return d["id"]
	controlla(false, "manca un dado %s" % col)
	return -1

## Porta a termine il colpo in corso senza altre risposte.
func chiudi(m: Motore) -> void:
	var giri := 0
	while m.s["fase"] in ["rinforzo", "reazione"] and giri < 6:
		var t := "sferra" if m.s["fase"] == "rinforzo" else "risolvi"
		m.applica(m.chi_decide(), {"t": t})
		giri += 1

func _init() -> void:
	dati = Motore.carica_dati()
	controlla(Motore.scarto_lati(0, 3) == 3 and Motore.scarto_lati(5, 0) == 1 and Motore.scarto_lati(1, 4) == 3, "scarto tra lati")

	# guardia: il dado sul lato davanti ferma il colpo, poi perde 1
	var m := duello({"forza": 2, "spada": 1}, {"tempra": 1, "postura": 1}, 1)
	var v := in_mano(m, 1, "verde", 5)
	controlla(m.applica(1, {"t": "slot", "tok": "postura", "slot": "in_guardia", "dadi": [v], "b": {"lato": 0}}) == "", "si mette in guardia")
	controlla(m.s["g"][1]["guardie"].has("postura/in_guardia"), "guardia registrata")
	controlla(int(m.copertura(1, Vector2i(0, 0))[0]) == 5, "guardia piena davanti")
	m.s["g"][1]["guardie"]["postura/in_guardia"]["lato"] = 1
	controlla(int(m.copertura(1, Vector2i(0, 0))[0]) == 4, "guardia a un lato di distanza: -1")
	m.s["g"][1]["guardie"]["postura/in_guardia"]["lato"] = 3
	controlla(int(m.copertura(1, Vector2i(0, 0))[0]) == 2, "guardia dietro: -3")
	m.s["g"][1]["guardie"]["postura/in_guardia"]["lato"] = 0
	m.s["attivo"] = 0
	m.s["g"][0]["passato"] = false
	var r := in_mano(m, 0, "rosso", 6)
	var vita0: int = m.s["g"][1]["vita"]
	controlla(m.applica(0, {"t": "slot", "tok": "spada", "slot": "fendente", "dadi": [r], "b": {"bers": 1, "lato": 0}}) == "", "fendente mirato")
	chiudi(m)
	controlla(m.s["g"][1]["vita"] == vita0, "5 dopo attrito contro guardia 5: nessun danno (vita %d)" % m.s["g"][1]["vita"])
	controlla(m.valore_guardia(1, "postura/in_guardia") == 4, "la guardia si consuma di 1")

	# colpo mirato di sbieco e passo laterale che fa andare a vuoto
	m = duello({"forza": 2, "spada": 1}, {"agilita": 2, "passo_laterale": 1})
	r = in_mano(m, 0, "rosso", 6)
	var b := in_mano(m, 1, "blu", 4)
	vita0 = m.s["g"][1]["vita"]
	controlla(m.applica(0, {"t": "slot", "tok": "spada", "slot": "fendente", "dadi": [r], "b": {"bers": 1, "lato": 0}}) == "", "attacco")
	if m.s["fase"] == "rinforzo":
		m.applica(0, {"t": "sferra"})
	controlla(m.s["fase"] == "reazione", "si può reagire")
	# esagono dietro al difensore, fuori portata
	controlla(m.applica(1, {"t": "slot", "tok": "passo_laterale", "slot": "scarta", "dadi": [b], "b": {"pos": Vector2i(2, -1)}}) == "", "passo laterale")
	chiudi(m)
	controlla(m.s["g"][1]["vita"] == vita0, "il colpo va a vuoto se il nemico esce di portata")

	m = duello({"forza": 2, "spada": 1}, {"agilita": 2, "passo_laterale": 1})
	r = in_mano(m, 0, "rosso", 6)
	b = in_mano(m, 1, "blu", 4)
	vita0 = m.s["g"][1]["vita"]
	m.applica(0, {"t": "slot", "tok": "spada", "slot": "fendente", "dadi": [r], "b": {"bers": 1, "lato": 0}})
	if m.s["fase"] == "rinforzo":
		m.applica(0, {"t": "sferra"})
	# resta a contatto ma di sbieco: il colpo mirato perde 1
	controlla(m.applica(1, {"t": "slot", "tok": "passo_laterale", "slot": "scarta", "dadi": [b], "b": {"pos": Vector2i(1, -1)}}) == "", "passo laterale vicino")
	chiudi(m)
	controlla(m.s["g"][1]["vita"] == vita0 - 4, "colpo mirato di sbieco: 6-1 attrito-1 angolo (vita %d)" % m.s["g"][1]["vita"])

	# affondo e rientro: l'attaccante deve arretrare di 2
	m = duello({"forza": 2, "affondo_rientro": 1}, {"tempra": 1})
	r = in_mano(m, 0, "rosso", 4)
	controlla(m.applica(0, {"t": "slot", "tok": "affondo_rientro", "slot": "rientro", "dadi": [r], "b": {"bers": 1}}) == "", "affondo")
	chiudi(m)
	controlla(Motore.dist(m.s["g"][0]["pos"], m.s["g"][1]["pos"]) == 3, "arretra di 2 dopo l'affondo")

	# taglio di passaggio: finisce alle spalle del nemico, girato verso di lui
	m = duello({"forza": 2, "agilita": 2, "taglio_passaggio": 1}, {"tempra": 1})
	r = in_mano(m, 0, "rosso", 3)
	b = in_mano(m, 0, "blu", 3)
	controlla(m.applica(0, {"t": "slot", "tok": "taglio_passaggio", "slot": "passaggio", "dadi": [b, r], "b": {"bers": 1}}) == "", "taglio di passaggio")
	chiudi(m)
	controlla(m.s["g"][0]["pos"] == Vector2i(2, 0), "passa oltre il nemico (%s)" % m.s["g"][0]["pos"])
	controlla(Motore.lato(m.s["g"][1]["pos"], m.s["g"][1]["dir"], m.s["g"][0]["pos"]) == "retro", "si ritrova alle sue spalle")

	# sgambetto: il nemico si gira e offre il fianco, l'attaccante si sposta
	m = duello({"destrezza": 2, "sgambetto": 1}, {"tempra": 1})
	var y := in_mano(m, 0, "blu", 2)
	var dir0: int = m.s["g"][1]["dir"]
	controlla(m.applica(0, {"t": "slot", "tok": "sgambetto", "slot": "sgambetto", "dadi": [y], "b": {"bers": 1}}) == "", "sgambetto")
	chiudi(m)
	controlla(m.s["g"][1]["dir"] != dir0, "il nemico si gira")
	controlla(m.s["g"][0]["pos"] != Vector2i(0, 0), "l'attaccante si sposta di lato")

	# proiezione contro una colonna: urto con danno e dado stordito
	m = duello({"forza": 2, "tempra": 1, "proiezione": 1}, {"agilita": 2})
	m.s["ost"] = {Vector2i(2, 0): true}
	r = in_mano(m, 0, "rosso", 6)
	var vv := in_mano(m, 0, "verde", 4)
	in_mano(m, 1, "blu", 5)
	vita0 = m.s["g"][1]["vita"]
	controlla(m.applica(0, {"t": "slot", "tok": "proiezione", "slot": "proietta", "dadi": [r, vv], "b": {"bers": 1}}) == "", "proiezione")
	chiudi(m)
	controlla(m.s["g"][1]["vita"] == vita0 - 2 - 3, "proiezione: 2 di colpo e 3 d'urto (vita %d)" % m.s["g"][1]["vita"])
	controlla(m.dadi_di(1, "stordito").size() == 1, "l'urto stordisce un dado")

	# colpo pesante: con 4 danni o più il difensore arretra di uno
	m = duello({"forza": 2, "spada": 1}, {"tempra": 1})
	r = in_mano(m, 0, "rosso", 5)
	m.applica(0, {"t": "slot", "tok": "spada", "slot": "fendente", "dadi": [r], "b": {"bers": 1, "lato": 0}})
	chiudi(m)
	controlla(m.s["g"][1]["pos"] == Vector2i(2, 0), "il colpo pesante fa arretrare")

	if errori == 0:
		print("OK: guardie, colpi mirati e movimenti funzionano")
	quit(1 if errori > 0 else 0)
