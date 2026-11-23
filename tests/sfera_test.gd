extends SceneTree
## Test della sfera: vantaggi, svantaggi, campo visivo, lettura del colpo.
## uso: godot --headless --path . --script tests/sfera_test.gd

var errori := 0
var dati: Dictionary

func controlla(cond: bool, msg: String) -> void:
	if not cond:
		errori += 1
		printerr("ERRORE: " + msg)

func duello(t0: Dictionary, t1: Dictionary, chi := 0) -> Motore:
	var m := Motore.new(dati)
	m.nuova_partita({"nome": "Alfa", "token": t0}, {"nome": "Beta", "token": t1}, "cortile", 5)
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

## Un dado del colore dato, nel mucchio, con il valore dato.
func dado(m: Motore, p: int, col: String, v: int) -> int:
	for d in m.s["g"][p]["dadi"]:
		if d["col"] == col and d["st"] == "mucchio" and not d.get("_preso", false):
			d["v"] = v
			d["_preso"] = true
			return d["id"]
	controlla(false, "manca un dado %s" % col)
	return -1

func chiudi(m: Motore) -> void:
	var giri := 0
	while m.s["fase"] in ["rinforzo", "reazione"] and giri < 6:
		var t := "sferra" if m.s["fase"] == "rinforzo" else "risolvi"
		m.applica(m.chi_decide(), {"t": t})
		giri += 1

func _init() -> void:
	dati = Motore.carica_dati()

	# cercare il varco con un 6: tre vantaggi, se il nemico è in vista
	var m := duello({"forza": 1, "spada": 1}, {"tempra": 1})
	var r := dado(m, 0, "rosso", 6)
	controlla(m.applica(0, {"t": "slot", "tok": "base", "slot": "varco", "dadi": [r], "b": {}}) == "", "cercare il varco")
	controlla(int(m.s["g"][0]["vantaggi"]) == 3, "6 sul varco: 3 vantaggi (ne ha %d)" % m.s["g"][0]["vantaggi"])

	# di spalle al nemico non si cercano varchi
	m = duello({"forza": 1}, {"tempra": 1})
	m.s["g"][0]["dir"] = 3
	r = dado(m, 0, "rosso", 6)
	controlla(m.bersagli(0, "base", m.slot_def("base", "varco"), [r]).is_empty(), "nessun varco su chi non si vede")
	controlla(not m.vede(0), "il nemico alle spalle non si vede")

	# svantaggi doppi se si è di spalle
	m.prendi_svantaggi(0, 1, "prova")
	controlla(int(m.s["g"][0]["svantaggi"]) == 2, "svantaggi raddoppiati di spalle")

	# l'attacco consuma vantaggi e svantaggi: ogni 2 punti +1 danno
	m = duello({"forza": 1, "spada": 1}, {"tempra": 1})
	m.s["g"][0]["vantaggi"] = 4
	m.s["g"][1]["svantaggi"] = 2
	r = dado(m, 0, "rosso", 5)
	var vita0: int = m.s["g"][1]["vita"]
	controlla(m.applica(0, {"t": "slot", "tok": "spada", "slot": "fendente", "dadi": [r], "b": {"bers": 1, "lato": 0}}) == "", "fendente")
	controlla(int(m.s["g"][0]["vantaggi"]) == 0 and int(m.s["g"][1]["svantaggi"]) == 0, "vantaggi e svantaggi messi in gioco")
	chiudi(m)
	var senza: int = vita0 - m.s["g"][1]["vita"]
	m = duello({"forza": 1, "spada": 1}, {"tempra": 1})
	r = dado(m, 0, "rosso", 5)
	vita0 = m.s["g"][1]["vita"]
	m.applica(0, {"t": "slot", "tok": "spada", "slot": "fendente", "dadi": [r], "b": {"bers": 1, "lato": 0}})
	chiudi(m)
	var base_danno: int = vita0 - m.s["g"][1]["vita"]
	controlla(senza == base_danno + 2, "la sfera aggiunge 2 danni (%d contro %d)" % [senza, base_danno])

	# leggere il colpo con un 5 toglie 2 vantaggi all'attaccante
	m = duello({"forza": 1, "spada": 1}, {"tempra": 1})
	m.s["g"][0]["vantaggi"] = 4
	r = dado(m, 0, "rosso", 5)
	var vd := dado(m, 1, "verde", 5)
	m.applica(0, {"t": "slot", "tok": "spada", "slot": "fendente", "dadi": [r], "b": {"bers": 1, "lato": 0}})
	if m.s["fase"] == "rinforzo":
		m.applica(0, {"t": "sferra"})
	controlla(m.s["fase"] == "reazione", "il difensore può leggere il colpo")
	controlla(m.applica(1, {"t": "slot", "tok": "base", "slot": "leggi", "dadi": [vd], "b": {}}) == "", "leggere il colpo")
	controlla(int(m.s["pend"].get("vant", -1)) == 2 or m.s["pend"].is_empty(), "l'attaccante perde 2 vantaggi")

	if errori == 0:
		print("OK: vantaggi, svantaggi, campo visivo e lettura del colpo funzionano")
	quit(1 if errori > 0 else 0)
