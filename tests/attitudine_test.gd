extends SceneTree
## Test del ciclo senza Mano e dell'Attitudine cromatica dinamica.

var errori := 0

func verifica(ok: bool, msg: String) -> void:
	if not ok:
		errori += 1
		printerr("ERRORE ATTITUDINE: " + msg)

func _init() -> void:
	var dati := Motore.carica_dati(true)
	var m := Motore.new(dati)
	m.nuova_partita(dati["personaggi"][0], dati["personaggi"][1], "cortile", 91)
	m.s["fase"] = "azione"
	m.s["attivo"] = 0
	var g: Dictionary = m.s["g"][0]
	verifica(m.dadi_di(0, "mano").is_empty(), "nessuna Mano all'inizio")
	verifica(m.ritmo_disponibile(0) == m.ritmo_azione(0), "Ritmo disponibile")

	# Costruiamo un campione deterministico di cinque dadi rossi.
	var ids := []
	for i in mini(5, g["dadi"].size()):
		var d: Dictionary = g["dadi"][i]
		d["col"] = "rosso"
		d["st"] = "mucchio"
		ids.append(d["id"])
	verifica(ids.size() == 5, "campione di dadi")
	if ids.size() == 5:
		verifica(not m.selezione_attitudine_ok(0, ids.slice(0, 3)), "neutrale non concentra tre rossi")
		g["occupati"]["spada/fendente"] = [ids[0], ids[1]]
		m.dado(0, ids[0])["st"] = "token"
		m.dado(0, ids[1])["st"] = "token"
		g["ultimo_colore_azione"] = "rosso"
		m.aggiorna_attitudine(0)
		verifica(g["attitudine"] == "aggressiva", "due dadi offensivi generano Aggressiva")
		verifica(m.limite_colore(0, "rosso") == m.ritmo_azione(0), "Aggressiva amplia il rosso")
		verifica(m.selezione_attitudine_ok(0, ids.slice(2, 5)), "Aggressiva consente tre rossi")
		m._spendi_ritmo(0, ids.slice(2, 4))
		verifica(m.ritmo_disponibile(0) == maxi(0, m.ritmo_azione(0) - 2), "il Ritmo è budget cumulativo")
		verifica(not m.selezione_attitudine_ok(0, ids.slice(4, 5)) if m.ritmo_disponibile(0) == 0 else m.selezione_attitudine_ok(0, ids.slice(4, 5)), "il residuo di Ritmo governa la selezione")

	if errori == 0:
		print("OK: selezione dal mucchio, Ritmo e Attitudine funzionano")
	quit(1 if errori > 0 else 0)
