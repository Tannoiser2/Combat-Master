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
	m.nuova_partita({"nome": "Alfa", "token": {}}, {"nome": "Beta", "token": {}}, "cortile", 3)
	m.s["ost"] = {}
	m.s["alt"] = {}
	m.s["per"] = {}
	m.s["alt"] = {}
	m.s["bassi"] = {}
	m.s["g"][0]["pos"] = Vector2i(0, 0)
	m.s["g"][0]["dir"] = 0
	m.s["g"][1]["pos"] = Vector2i(-3, 0)
	m.s["g"][1]["dir"] = 0
	return m

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
	if errori == 0:
		print("OK: gradini, salti, contatto, cadute e parate che deviano funzionano")
	quit(1 if errori > 0 else 0)
