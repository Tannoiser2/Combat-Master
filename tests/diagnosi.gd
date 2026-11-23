extends SceneTree
## Diagnosi: negli scambi in cui un combattente non attacca, perché?
## uso: godot --headless --path . --script tests/diagnosi.gd -- partite=40 seme=3
func _init() -> void:
	var arg := {"partite": "40", "seme": "3"}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv.size() == 2:
			arg[kv[0]] = kv[1]
	var dati := Motore.carica_dati()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(arg["seed"]) if arg.has("seed") else int(arg["seme"])
	var motivi := {}
	var scelte_al_posto := {}
	var tot_mancati := 0
	var tot_scambi := 0
	for n in int(arg["partite"]):
		var m := Motore.new(dati)
		m.nuova_partita(Generatore.casuale(dati, [30, 45, 60][n % 3], rng), Generatore.casuale(dati, [30, 45, 60][n % 3], rng), "cortile", rng.randi())
		var info := [{}, {}]
		var giro := int(m.s["round"])
		var passi := 0
		while m.s["vinc"] < 0 and passi < 3000:
			if int(m.s["round"]) != giro:
				for p in 2:
					tot_scambi += 1
					if not info[p].get("attaccato", false):
						tot_mancati += 1
						var mot: String
						if info[p].get("decisioni", 0) == 0:
							mot = "nessuna decisione in azione"
						elif info[p].get("poteva", 0) == 0:
							mot = "mai un attacco possibile (%s)" % ("lontano" if info[p].get("lontano", 0) > 0 else ("senza Ritmo" if info[p].get("senza_ritmo", 0) > 0 else info[p].get("perche", "altro")))
						else:
							mot = "poteva ma ha scelto altro"
						motivi[mot] = int(motivi.get(mot, 0)) + 1
				info = [{}, {}]
				giro = int(m.s["round"])
			var chi := m.chi_decide()
			var op := IA.scegli(m, chi, rng)
			if op.is_empty():
				break
			if m.s["fase"] == "azione":
				var ip: Dictionary = info[chi]
				ip["decisioni"] = int(ip.get("decisioni", 0)) + 1
				var puo := false
				for o in m.opzioni(chi):
					if (o["t"] == "slot" and m.slot_def(o["tok"], o["slot"])["effetto"] in ["attacco", "assalto"]) or o["t"] == "scarica":
						puo = true
						break
				if puo:
					ip["poteva"] = int(ip.get("poteva", 0)) + 1
					var t: String = op["t"]
					if t == "slot":
						t = m.slot_def(op["tok"], op["slot"])["effetto"]
					if not t in ["attacco", "assalto", "scarica"]:
						scelte_al_posto[t] = int(scelte_al_posto.get(t, 0)) + 1
				else:
					if Motore.dist(m.s["g"][chi]["pos"], m.s["g"][1 - chi]["pos"]) > 2:
						ip["lontano"] = 1
					if m.ritmo_disponibile(chi) == 0:
						ip["senza_ritmo"] = 1
					var g: Dictionary = m.s["g"][chi]
					var liberi := 0
					for ts in m.slot_del_giocatore(chi):
						if ts[1]["effetto"] in ["attacco", "assalto"] and not m.occupato(chi, ts[0], ts[1]["id"]) and m.slot_attivabile(chi, ts[0], ts[1]):
							liberi += 1
					var perche := ""
					if m.dadi_di(chi, "mucchio").is_empty():
						perche = "mucchio vuoto"
					elif liberi == 0:
						perche = "spazi d'attacco tutti occupati o già usati"
					elif not Motore.in_fronte(g["pos"], g["dir"], m.s["g"][1 - chi]["pos"]):
						perche = "nemico vicino ma non davanti"
					else:
						perche = "dadi del colore o valore sbagliato (%d nel mucchio, %d spazi liberi)" % [m.dadi_di(chi, "mucchio").size(), liberi]
					if not ip.has("perche") or perche.begins_with("dadi"):
						ip["perche"] = perche.split(" (")[0]
			m.applica(chi, op)
			for ev in m.prendi_eventi():
				if ev["t"] == "attacco":
					info[int(ev["p"])]["attaccato"] = true
			passi += 1
	print("scambi-combattente %d, senza attacco %d" % [tot_scambi, tot_mancati])
	var k := motivi.keys()
	k.sort_custom(func(a, b): return motivi[a] > motivi[b])
	for x in k:
		print("  %4d  %s" % [motivi[x], x])
	print("al posto dell'attacco l'IA ha scelto:")
	var k2 := scelte_al_posto.keys()
	k2.sort_custom(func(a, b): return scelte_al_posto[a] > scelte_al_posto[b])
	for x in k2:
		print("  %4d  %s" % [scelte_al_posto[x], x])
	quit()
