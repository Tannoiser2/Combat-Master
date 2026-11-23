extends SceneTree
## Banco di bilanciamento: avventurieri casuali, centinaia di partite IA contro IA,
## statistiche per token e per spazio, aggiustamento automatico dei costi.
## uso: godot --headless --path . --script tests/bilancia.gd -- partite=400 iterazioni=3 applica=1
##      opzioni: budget=30|45|60|0 (0 = misto)  ritmo=N recupero=N vita=N  rapporto=percorso.md

var dati: Dictionary
var cat: Dictionary
var rng := RandomNumberGenerator.new()

func _init() -> void:
	var arg := {"partite": "300", "iterazioni": "1", "applica": "0", "budget": "0", "seme": "1", "rapporto": "",
		"valida": "0", "min_scambi": "10", "quota_doppi": "0.5"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			arg[kv[0]] = kv[1]
	dati = Motore.carica_dati()
	cat = dati["per_id"]
	for k in ["ritmo", "recupero", "vita", "conserva"]:
		if arg.has(k):
			Motore.regole[k] = int(arg[k])
	rng.seed = int(arg["seme"])
	var ultimo := {}
	var fallimenti := 0
	for it in int(arg["iterazioni"]):
		ultimo = giro(int(arg["partite"]), int(arg["budget"]), int(arg["min_scambi"]), float(arg["quota_doppi"]))
		stampa(ultimo, it)
		fallimenti += int(ultimo["duelli_non_validi"])
		if arg["applica"] == "1":
			var n := aggiusta(ultimo)
			print("Iterazione %d: costi cambiati su %d token" % [it + 1, n])
	if arg["applica"] == "1" or arg.get("solo_pronti", "0") == "1":
		salva_catalogo()
	if arg["rapporto"] != "":
		scrivi_rapporto(ultimo, arg["rapporto"])
	if arg["valida"] == "1" and fallimenti > 0:
		push_error("Validazione duelli fallita: %d duelli non rispettano i criteri obbligatori." % fallimenti)
		quit(1)
	else:
		quit()

func giro(n: int, budget_fisso: int, min_scambi: int = 10, quota_doppi: float = 0.5) -> Dictionary:
	var st := {"partite": 0, "scambi": 0, "tempo": 0, "rifiuti": 0, "token": {}, "spazi": {}, "coppie": {},
		"budget": {}, "durate": [], "danno": 0, "senza_attacchi": 0, "esagoni": 0, "spinti": 0, "giri": 0, "riposi": 0, "emergenze": 0, "interrotte": 0, "passi": 0, "recuperi_token": 0, "sblocchi_token": 0, "preparazioni_attesa": 0, "azioni_offensive": 0, "attacchi_reali": 0, "senza_attacchi_pg": 0, "attesa_picco": 0, "somme_attesa": 0, "campioni_attesa": 0,
		"min_scambi": min_scambi, "quota_doppi": quota_doppi, "scambi_doppi": 0, "duelli_brevi": 0, "duelli_senza_entrambi": 0, "duelli_quota_doppi": 0, "duelli_non_validi": 0, "violazioni": [],
		"vantaggi_presi": 0, "vantaggi_spesi": 0, "svantaggi_presi": 0, "sblocchi_assetto": 0, "difese_assetto": 0, "attacchi_con_sfera": 0}
	var t0 := Time.get_ticks_msec()
	for i in n:
		var budget: int = budget_fisso if budget_fisso > 0 else [30, 45, 60][i % 3]
		var a: Dictionary = Generatore.casuale(dati, budget, rng)
		var b: Dictionary = Generatore.casuale(dati, budget, rng)
		var m := Motore.new(dati)
		m.nuova_partita(a, b, ["cortile", "rovine", "fossa"][rng.randi() % 3], rng.randi())
		var passi := 0
		var attacchi := [0, 0]
		var attacchi_per_scambio := {}
		while m.s["vinc"] < 0 and passi < 5000:
			var chi := m.chi_decide()
			var op := IA.scegli(m, chi, rng)
			if op.is_empty():
				break
			if op["t"] == "riposo":
				st["riposi"] += 1
			elif op["t"] == "emergenza":
				st["emergenze"] += 1
			elif op["t"] == "flusso":
				st["sblocchi_assetto"] += 1
			elif op["t"] == "adatta":
				st["difese_assetto"] += 1
			if op["t"] == "slot":
				var k: String = op["tok"] + "/" + op["slot"]
				st["spazi"][k] = int(st["spazi"].get(k, 0)) + 1
				var effetto: String = m.slot_def(op["tok"], op["slot"])["effetto"]
				match effetto:
					"recupera":
						st["recuperi_token"] += 1
					"sblocca":
						st["sblocchi_token"] += 1
					"prepara_attesa":
						st["preparazioni_attesa"] += 1
				if effetto in ["attacco", "assalto"]:
					st["azioni_offensive"] += 1
			elif op["t"] == "scarica":
				st["spazi"][op["key"]] = int(st["spazi"].get(op["key"], 0)) + 1
				st["azioni_offensive"] += 1
			var e := m.applica(chi, op)
			if e != "":
				st["rifiuti"] += 1
				print("RIFIUTATA: ", e, " ", op)
				break
			passi += 1
			for pp in 2:
				var attesa_n := m.dadi_di(pp, "attesa").size()
				st["attesa_picco"] = maxi(int(st["attesa_picco"]), attesa_n)
				st["somme_attesa"] += attesa_n
				st["campioni_attesa"] += 1
			for ev in m.prendi_eventi():
				if ev["t"] == "vantaggi":
					if int(ev["delta"]) > 0:
						st["vantaggi_presi"] += int(ev["delta"])
				elif ev["t"] == "svantaggi" and int(ev["delta"]) > 0:
					st["svantaggi_presi"] += int(ev["delta"])
				elif ev["t"] == "sfera":
					st["attacchi_con_sfera"] += 1
					st["vantaggi_spesi"] += int(ev["n"])
				if ev["t"] == "attacco":
					var round_attacco := int(m.s["round"])
					if not attacchi_per_scambio.has(round_attacco):
						attacchi_per_scambio[round_attacco] = [false, false]
					var autore := int(ev["p"])
					attacchi_per_scambio[round_attacco][autore] = true
					attacchi[autore] += 1
					st["attacchi_reali"] += 1
				if ev["t"] in ["muovi", "spinto"]:
					var per: Array = ev["percorso"]
					for j in range(1, per.size()):
						if Vector2i(per[j].x, per[j].y) != Vector2i(per[j - 1].x, per[j - 1].y):
							st["esagoni"] += 1
							if ev["t"] == "spinto":
								st["spinti"] += 1
					if per.size() == 1 or (per.size() > 1 and per[-1].z != per[0].z):
						st["giri"] += 1
				elif ev["t"] == "salto":
					st["esagoni"] += 1
		if m.s["vinc"] < 0 and passi < 5000:
			st["interrotte"] += 1
		st["passi"] += passi
		st["partite"] += 1
		st["scambi"] += int(m.s["round"])
		st["durate"].append(int(m.s["round"]))
		if int(m.s["round"]) >= Motore.ROUND_MAX:
			st["tempo"] += 1
		var scambi_duali := 0
		for numero_scambio in attacchi_per_scambio:
			var presenti: Array = attacchi_per_scambio[numero_scambio]
			if presenti[0] and presenti[1]:
				scambi_duali += 1
		st["scambi_doppi"] += scambi_duali
		var durata := int(m.s["round"])
		var breve: bool = durata < min_scambi
		var senza_entrambi: bool = int(attacchi[0]) == 0 or int(attacchi[1]) == 0
		var doppi_richiesti := int(ceil(float(durata) * quota_doppi))
		var quota_mancante: bool = scambi_duali < doppi_richiesti
		if breve:
			st["duelli_brevi"] += 1
		if senza_entrambi:
			st["duelli_senza_entrambi"] += 1
		if quota_mancante:
			st["duelli_quota_doppi"] += 1
		if breve or senza_entrambi or quota_mancante:
			st["duelli_non_validi"] += 1
			if st["violazioni"].size() < 20:
				st["violazioni"].append("duello %d: %d scambi, attacchi %d/%d, scambi con entrambi %d/%d" % [i + 1, durata, attacchi[0], attacchi[1], scambi_duali, doppi_richiesti])
		if senza_entrambi:
			st["senza_attacchi"] += 1
		for q in 2:
			if attacchi[q] == 0:
				st["senza_attacchi_pg"] += 1
		var w: int = maxi(0, m.s["vinc"])
		for p in 2:
			var pg: Dictionary = [a, b][p]
			var vinto := 1 if p == w else 0
			var ids: Array = pg["token"].keys()
			for id in ids:
				var r: Dictionary = st["token"].get(id, {"n": 0, "v": 0})
				r["n"] += 1
				r["v"] += vinto
				st["token"][id] = r
			ids.sort()
			for x in ids.size():
				for y in range(x + 1, ids.size()):
					var k: String = ids[x] + "+" + ids[y]
					var r2: Dictionary = st["coppie"].get(k, {"n": 0, "v": 0})
					r2["n"] += 1
					r2["v"] += vinto
					st["coppie"][k] = r2
	st["ms"] = Time.get_ticks_msec() - t0
	return st

func stampa(st: Dictionary, it: int) -> void:
	var d: Array = st["durate"]
	d.sort()
	print("--- Giro %d: %d partite in %d s, scambi medi %.1f (mediana %d, massimo %d), a tempo %d, senza attacchi %d, rifiuti %d" % [
		it + 1, st["partite"], st["ms"] / 1000, float(st["scambi"]) / st["partite"], d[d.size() / 2], d[-1], st["tempo"], st["senza_attacchi"], st["rifiuti"]])
	print("    Riposi %d, sblocchi emergenza %d, simulazioni interrotte %d, decisioni %d" % [st["riposi"], st["emergenze"], st["interrotte"], st["passi"]])
	print("    Motore: recuperi token %d, sblocchi token %d, preparazioni %d, attacchi %d, combattenti senza attacchi %d" % [
		st["recuperi_token"], st["sblocchi_token"], st["preparazioni_attesa"], st["attacchi_reali"], st["senza_attacchi_pg"]])
	print("    Criteri rigidi: non validi %d (brevi %d, senza entrambi %d, quota doppi insufficiente %d); scambi con attacchi di entrambi %d" % [
		st["duelli_non_validi"], st["duelli_brevi"], st["duelli_senza_entrambi"], st["duelli_quota_doppi"], st["scambi_doppi"]])
	for v in st["violazioni"]:
		print("      VIOLAZIONE: ", v)
	print("    Sfera: vantaggi presi %d, svantaggi presi %d, attacchi rinforzati %d (+%d danni), sblocchi con vantaggi %d" % [
		st["vantaggi_presi"], st["svantaggi_presi"], st["attacchi_con_sfera"], st["vantaggi_spesi"], st["sblocchi_assetto"]])
	print("    Attesa media %.2f dadi per combattente/decisione; picco %d" % [
		float(st["somme_attesa"]) / maxi(1, int(st["campioni_attesa"])), st["attesa_picco"]])
	print("    Movimento per partita: %.1f esagoni percorsi, di cui %.1f per spinte, %.1f rotazioni" % [float(st["esagoni"]) / st["partite"], float(st["spinti"]) / st["partite"], float(st["giri"]) / st["partite"]])
	var righe := []
	for id in st["token"]:
		var r: Dictionary = st["token"][id]
		if r["n"] >= 12:
			righe.append([float(r["v"]) / r["n"], id, r["n"]])
	righe.sort_custom(func(x, y): return x[0] > y[0])
	print("Più forti: ", righe.slice(0, 6).map(func(x): return "%s %.0f%% (%d)" % [x[1], x[0] * 100, x[2]]))
	print("Più deboli: ", righe.slice(maxi(0, righe.size() - 6)).map(func(x): return "%s %.0f%% (%d)" % [x[1], x[0] * 100, x[2]]))

## Intervallo Wilson al 95%: per singoli token, un campione esiguo non prova sbilanciamento.
static func intervallo_95(vinte: int, giocate: int) -> Array:
	if giocate <= 0:
		return [0.0, 1.0]
	var n := float(giocate)
	var p := float(vinte) / n
	var z := 1.96
	var z2 := z * z
	var centro := (p + z2 / (2.0 * n)) / (1.0 + z2 / n)
	var margine := z * sqrt((p * (1.0 - p) + z2 / (4.0 * n)) / n) / (1.0 + z2 / n)
	return [maxf(0.0, centro - margine), minf(1.0, centro + margine)]

## Alza il costo dei token che vincono troppo, abbassa quello dei token che perdono troppo.
func aggiusta(st: Dictionary) -> int:
	var cambiati := 0
	for id in st["token"]:
		var r: Dictionary = st["token"][id]
		if r["n"] < 100:
			continue
		var limiti := intervallo_95(int(r["v"]), int(r["n"]))
		var delta := 0
		# Solo se l'intero intervallo supera il corridoio neutro.
		if float(limiti[0]) > 0.57:
			delta = 1
		elif float(limiti[1]) < 0.43:
			delta = -1
		if delta == 0:
			continue
		var t: Dictionary = cat[id]
		if t.has("livelli"):
			for L in t["livelli"]:
				L["costo"] = maxi(1, int(L["costo"]) + delta)
		else:
			t["costo"] = maxi(1, int(t.get("costo", 3)) + delta)
		cambiati += 1
	return cambiati

## Dopo i ritocchi ai costi, i combattenti pronti devono restare nel loro budget:
## si abbassano i livelli o si tolgono i token passivi più costosi finché non rientrano.
func sistema_pronti() -> void:
	for pg in dati["personaggi"]:
		var guard := 0
		while Motore.costo_personaggio(cat, pg) > int(pg["budget"]) and guard < 20:
			guard += 1
			var tolto := false
			for id in pg["token"].keys():
				var t: Dictionary = cat[id]
				if t.has("livelli") and int(pg["token"][id]) > 1:
					pg["token"][id] = int(pg["token"][id]) - 1
					if Generatore.valido(cat, pg):
						tolto = true
						break
					pg["token"][id] = int(pg["token"][id]) + 1
			if tolto:
				continue
			var candidati: Array = pg["token"].keys()
			candidati.sort_custom(func(x, y): return Motore.costo_token(cat[x], 1) > Motore.costo_token(cat[y], 1))
			for id in candidati:
				var lv: int = pg["token"][id]
				pg["token"].erase(id)
				if Generatore.valido(cat, pg):
					tolto = true
					break
				pg["token"][id] = lv
			if not tolto:
				break
		print("%s: %d su %d" % [pg["nome"], Motore.costo_personaggio(cat, pg), pg["budget"]])

func salva_catalogo() -> void:
	sistema_pronti()
	var out: Dictionary = dati.duplicate()
	out.erase("per_id")
	var f := FileAccess.open("res://data/tokens.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " ", false))
	print("Catalogo salvato con i nuovi costi.")

func scrivi_rapporto(st: Dictionary, percorso: String) -> void:
	var t := "# Rapporto di bilanciamento\n\n"
	t += "%d partite simulate fra avventurieri casuali (30, 45 e 60 punti), IA contro IA.\n\n" % st["partite"]
	var d: Array = st["durate"]
	d.sort()
	t += "- Scambi per partita: media %.1f, mediana %d, massimo %d\n" % [float(st["scambi"]) / st["partite"], d[d.size() / 2], d[-1]]
	t += "- Movimento per partita: %.1f esagoni percorsi (%.1f per spinte e lanci), %.1f rotazioni\n" % [float(st["esagoni"]) / st["partite"], float(st["spinti"]) / st["partite"], float(st["giri"]) / st["partite"]]
	t += "- Partite finite al limite di tempo: %d\n- Partite in cui qualcuno non ha mai attaccato: %d\n- Opzioni rifiutate dal motore (errori): %d\n- Partite interrotte prima della vittoria: %d\n- Riposi: %d\n- Sblocchi di emergenza: %d\n- Decisioni elaborate: %d\n\n" % [st["tempo"], st["senza_attacchi"], st["rifiuti"], st["interrotte"], st["riposi"], st["emergenze"], st["passi"]]
	t += "## Criteri obbligatori per duello\n\n"
	t += "- Durata minima: %d scambi\n- Quota minima di scambi con attacchi di entrambi: %.0f%%\n- Duelli non validi: %d\n- Duelli troppo brevi: %d\n- Duelli in cui uno dei due non attacca: %d\n- Duelli sotto la quota di attacchi reciproci: %d\n\n" % [
		st["min_scambi"], float(st["quota_doppi"]) * 100.0, st["duelli_non_validi"], st["duelli_brevi"], st["duelli_senza_entrambi"], st["duelli_quota_doppi"]]
	t += "## Economia dell'Attesa\\n\\n"
	t += "- Assetto generato: %d\\n- Assetto speso: %d\\n- Sblocchi tramite Assetto: %d\\n- Difese tramite Assetto: %d\\n" % [st["assetto_generato"], st["assetto_speso"], st["sblocchi_assetto"], st["difese_assetto"]]
	t += "- Recuperi tramite token: %d\\n- Sblocchi tramite token: %d\\n- Dadi preparati in Attesa: %d\\n- Azioni offensive: %d\\n- Combattenti che non hanno attaccato: %d\\n- Dadi medi in Attesa per combattente e decisione: %.2f\\n- Picco Attesa: %d\\n\\n" % [
		st["recuperi_token"], st["sblocchi_token"], st["preparazioni_attesa"], st["azioni_offensive"], st["senza_attacchi_pg"],
		float(st["somme_attesa"]) / maxi(1, int(st["campioni_attesa"])), st["attesa_picco"]]
	t += "## Token: vittorie e incertezza statistica (Wilson 95%)\\n\\n"
	t += "Un rapporto vittorie/partite non misura da solo la forza del token: archetipi, sinergie e scelte IA sono fattori confondenti.\\n"
	t += "Servono almeno 100 presenze per considerare preliminarmente il dato; per modificare un costo non deve bastare il risultato puntuale.\\n\\n"
	t += "| Token | Categoria | Costo | Presenze | Vittorie | IC 95% | Giudizio |\\n| --- | --- | --- | --- | --- | --- | --- |\\n"
	var righe := []
	for id in st["token"]:
		var r: Dictionary = st["token"][id]
		righe.append([float(r["v"]) / maxi(1, r["n"]), id, r["n"]])
	righe.sort_custom(func(x, y): return x[0] > y[0])
	for x in righe:
		var tk: Dictionary = cat[x[1]]
		var costo := str(Motore.costo_token(tk, 1)) if not tk.has("livelli") else "/".join(tk["livelli"].map(func(L): return str(L["costo"])))
		var ri: Dictionary = st["token"][x[1]]
		var ic := intervallo_95(int(ri["v"]), int(ri["n"]))
		var giudizio := "campione insufficiente" if int(ri["n"]) < 100 else ("potenzialmente forte" if float(ic[0]) > 0.57 else ("potenzialmente debole" if float(ic[1]) < 0.43 else "inconcludente"))
		t += "| %s | %s | %s | %d | %.0f%% | %.0f–%.0f%% | %s |\\n" % [tk["nome"], tk["categoria"], costo, x[2], x[0] * 100, float(ic[0]) * 100, float(ic[1]) * 100, giudizio]
	t += "\n## Spazi mai usati dall'IA\n\n"
	var mai := []
	for tk in dati["token"]:
		for sl in tk["slot"]:
			var k: String = tk["id"] + "/" + sl["id"]
			if not st["spazi"].has(k) and st["token"].has(tk["id"]):
				mai.append("%s (%s)" % [sl["nome"], tk["nome"]])
	t += ("- " + "\n- ".join(mai) + "\n") if not mai.is_empty() else "Nessuno.\n"
	t += "\n## Coppie di token sospette (almeno 20 partite)\n\n| Coppia | Partite | Vittorie |\n| --- | --- | --- |\n"
	var cp := []
	for k in st["coppie"]:
		var r: Dictionary = st["coppie"][k]
		if r["n"] >= 20:
			cp.append([float(r["v"]) / r["n"], k, r["n"]])
	cp.sort_custom(func(x, y): return x[0] > y[0])
	for x in cp.slice(0, 12):
		var parti: PackedStringArray = x[1].split("+")
		t += "| %s + %s | %d | %.0f%% |\n" % [cat[parti[0]]["nome"], cat[parti[1]]["nome"], x[2], x[0] * 100]
	var f := FileAccess.open(percorso, FileAccess.WRITE)
	f.store_string(t)
	print("Rapporto scritto in ", percorso)
