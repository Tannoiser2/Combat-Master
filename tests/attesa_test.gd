extends SceneTree
## Test mirati del circuito Mucchio -> Token -> Attesa -> Mucchio.
var errori := 0

func verifica(ok: bool, msg: String) -> void:
	if not ok:
		errori += 1
		printerr("ERRORE ATTESA: " + msg)

func _init() -> void:
	var dati := Motore.carica_dati()
	var pg: Dictionary = dati["personaggi"][0].duplicate(true)
	pg["token"]["respiro_profondo"] = 1
	var m := Motore.new(dati)
	m.nuova_partita(pg, dati["personaggi"][1], "cortile", 17)
	m.s["fase"] = "azione"
	m.s["attivo"] = 0
	var verde := -1
	var in_attesa := []
	for d in m.s["g"][0]["dadi"]:
		if d["col"] == "verde" and verde < 0:
			verde = d["id"]
			d["st"] = "mano"
		elif in_attesa.size() < 3:
			in_attesa.append(d["id"])
			d["st"] = "attesa"
	verifica(verde >= 0 and in_attesa.size() == 3, "dadi verdi e in Attesa")
	if verde >= 0 and in_attesa.size() == 3:
		var op := {"t": "slot", "tok": "respiro_profondo", "slot": "respiro",
			"dadi": [verde], "b": {"dadi": in_attesa.slice(0, 2)}}
		verifica(m.applica(0, op) == "", "recupero token attivato")
		verifica(m.dadi_di(0, "attesa").size() == 1, "resta un dado in Attesa")
		verifica(m.dado(0, in_attesa[0])["st"] == "mucchio", "primo recuperato")
		verifica(m.dado(0, in_attesa[1])["st"] == "mucchio", "secondo recuperato")
		verifica(m.dado(0, verde)["st"] == "token", "il costo rimane impegnato")
		var unici := {}
		for d in m.s["g"][0]["dadi"]:
			verifica(not unici.has(d["id"]), "nessun dado duplicato")
			unici[d["id"]] = true
			verifica(d["st"] in ["mucchio", "mano", "attesa", "token", "stordito", "conservato", "eliminato"], "stato noto")
	# I token devono riferirsi a effetti supportati e richiedere almeno un dado.
	for t in dati["token"]:
		for sl in t["slot"]:
			verifica(not sl["dadi"].is_empty(), t["id"] + ": manca costo in dadi")
			if sl["effetto"] == "recupera":
				verifica(sl["tipo"] in ["azione", "libera"], t["id"] + ": fase recupero")
				verifica(int(sl.get("fisso", 0)) >= 1 and int(sl.get("fisso", 0)) <= 3, t["id"] + ": recupero fuori scala")
	if errori == 0:
		print("OK: circuito Attesa, recupero da token e conservazione dadi")
	quit(1 if errori > 0 else 0)
