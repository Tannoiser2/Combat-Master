extends SceneTree
## Test del terreno a più livelli: gradini, salti acrobatici, contatto, cadute, parate che deviano.
## uso: godot --headless --path . --script tests/terreno_test.gd

var errori := 0

func controlla(cond: bool, msg: String) -> void:
	if not cond:
		errori += 1
		printerr("ERRORE: " + msg)

func piano(dati: Dictionary) -> Motore:
	var m := Motore.new(dati)
	m.nuova_partita(dati["personaggi"][0], dati["personaggi"][1], "cortile", 3)
	m.s["ost"] = {}
	m.s["alt"] = {}
	m.s["per"] = {}
	m.s["alt"] = {}
	m.s["bassi"] = {}
	m.s["ogg"] = {}
	m.s["sabbia"] = {}
	m.s["g"][0]["pos"] = Vector2i(0, 0)
	m.s["g"][0]["dir"] = 0
	m.s["g"][1]["pos"] = Vector2i(-3, 0)
	m.s["g"][1]["dir"] = 0
	return m

func libera_dado(m: Motore, p: int, v: int) -> int:
	for d in m.s["g"][p]["dadi"]:
		d["st"] = "mucchio"
	var d0: Dictionary = m.s["g"][p]["dadi"][0]
	d0["v"] = v
	return int(d0["id"])

func _init() -> void:
	var dati := Motore.carica_dati()
	var avanti := Motore.DIRS[0]
	# gradino di un livello: costa un punto in più
	var m := piano(dati)
	m.s["alt"][avanti] = 1
	var r: Dictionary = m.raggiungibili(0, 1)["costo"]
	controlla(not r.has(Vector3i(avanti.x, avanti.y, 0)), "con 1 punto non si sale un gradino")
	r = m.raggiungibili(0, 2)["costo"]
	controlla(r.has(Vector3i(avanti.x, avanti.y, 0)), "con 2 punti si sale un gradino")
	# due livelli: solo con un salto acrobatico
	m.s["alt"][avanti] = 2
	controlla(not m.raggiungibili(0, 4)["costo"].has(Vector3i(avanti.x, avanti.y, 0)), "due livelli senza salto")
	controlla(m.raggiungibili(0, Motore.SALTO_MIN)["costo"].has(Vector3i(avanti.x, avanti.y, 0)), "salto acrobatico su un rocchio")
	# scavalcare macerie basse
	m = piano(dati)
	m.s["ost"][avanti] = true
	m.s["bassi"][avanti] = true
	var oltre: Vector2i = avanti * 2
	controlla(not m.raggiungibili(0, 4)["costo"].has(Vector3i(oltre.x, oltre.y, 0)), "macerie senza salto")
	controlla(m.raggiungibili(0, Motore.SALTO_MIN)["costo"].has(Vector3i(oltre.x, oltre.y, 0)), "salto sopra le macerie")
	m.s["bassi"].erase(avanti)
	var c9: Dictionary = m.raggiungibili(0, 9)["costo"]
	controlla(int(c9.get(Vector3i(oltre.x, oltre.y, 0), 99)) > 3, "una colonna intera non si scavalca, si gira attorno")
	# a contatto ma due livelli più in alto: niente colpo
	m = piano(dati)
	m.s["g"][1]["pos"] = avanti
	m.s["g"][1]["dir"] = 3
	m.s["alt"][avanti] = 2
	controlla(not m._attacco_possibile(0, {"portata": 1}, Vector2i(0, 0), 0), "colpo su chi sta due livelli più su")
	m.s["alt"][avanti] = 1
	controlla(m._attacco_possibile(0, {"portata": 1}, Vector2i(0, 0), 0), "colpo su chi sta un livello più su")
	# spinto giù da un rialzo: cade e si ferisce
	m = piano(dati)
	m.s["g"][1]["pos"] = avanti
	m.s["alt"][avanti] = 2
	var v0: int = m.s["g"][1]["vita"]
	m._spingi(0, 1, 1, false)
	controlla(m.s["g"][1]["pos"] == avanti * 2, "spinto giù dal rocchio")
	controlla(m.s["g"][1]["vita"] == v0 - 2, "caduta di due livelli: 2 ferite (%d)" % (v0 - int(m.s["g"][1]["vita"])))
	# spinto contro un gradino: si ferma senza danni
	m = piano(dati)
	m.s["g"][1]["pos"] = avanti
	m.s["alt"][avanti * 2] = 1
	v0 = m.s["g"][1]["vita"]
	m._spingi(0, 1, 2, false)
	controlla(m.s["g"][1]["pos"] == avanti and m.s["g"][1]["vita"] == v0, "il gradino ferma la spinta")
	# parata che devia: l'attaccante scivola di fianco al difensore
	m = piano(dati)
	m.s["g"][1]["pos"] = avanti
	m.s["g"][1]["dir"] = 3
	m._devia(1, 0)
	var pa: Vector2i = m.s["g"][0]["pos"]
	controlla(pa != Vector2i(0, 0) and Motore.dist(pa, avanti) == 1, "la parata sposta l'attaccante di lato")
	# oggetti di scena
	m = piano(dati)
	m.s["ogg"] = {Vector2i(0, 1): {"tipo": "pietre", "cariche": 3}}
	m.s["g"][1]["pos"] = Vector2i(3, 0)
	m.s["g"][1]["dir"] = 3
	m.s["fase"] = "azione"
	m.s["attivo"] = 0
	var d0 := libera_dado(m, 0, 6)
	v0 = m.s["g"][1]["vita"]
	var es := m.applica(0, {"t": "slot", "tok": "scena", "slot": "lancia", "dadi": [d0], "b": {"bers": 1, "da": Vector2i(0, 1)}})
	controlla(es == "", "lancio di una pietra: " + es)
	controlla(int(m.s["g"][1]["vita"]) == v0 - 3, "la pietra fa metà del dado")
	# cassa che travolge
	m = piano(dati)
	var cassa: Vector2i = avanti
	m.s["ogg"] = {cassa: {"tipo": "cassa", "cariche": 0}}
	m.s["alt"][cassa] = 1
	m.s["g"][1]["pos"] = avanti * 3
	m.s["fase"] = "azione"
	m.s["attivo"] = 0
	d0 = libera_dado(m, 0, 6)
	v0 = m.s["g"][1]["vita"]
	es = m.applica(0, {"t": "slot", "tok": "scena", "slot": "spingi_ogg", "dadi": [d0], "b": {"ogg": cassa}})
	controlla(es == "", "spinta della cassa: " + es)
	controlla(m.oggetto(avanti * 2) == "cassa" and m.altezza(avanti * 2) == 1 and m.altezza(cassa) == 0, "la cassa scivola col suo gradino")
	controlla(int(m.s["g"][1]["vita"]) == v0 - 2, "la cassa travolge il nemico")
	# braciere rovesciato
	m = piano(dati)
	m.s["ogg"] = {avanti: {"tipo": "braciere", "cariche": 3}}
	m.s["g"][1]["pos"] = avanti * 2
	m.s["fase"] = "azione"
	m.s["attivo"] = 0
	d0 = libera_dado(m, 0, 4)
	v0 = m.s["g"][1]["vita"]
	es = m.applica(0, {"t": "slot", "tok": "scena", "slot": "spingi_ogg", "dadi": [d0], "b": {"ogg": avanti}})
	controlla(es == "" and m.s["per"].has(avanti * 2) and int(m.s["g"][1]["vita"]) == v0 - 2, "braciere rovesciato addosso")
	if errori == 0:
		print("OK: gradini, salti, contatto, cadute, parate che deviano e oggetti di scena funzionano")
	quit(1 if errori > 0 else 0)
