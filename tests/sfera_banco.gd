extends SceneTree
## Banco della sfera nel motore del gioco: duelli IA contro IA con personaggi casuali sulle tre arene.
## Stampa vittorie per token e per caratteristica; con aggiusta=1 corregge i costi in data/sfera.json.
## uso: godot --headless --path . -s tests/sfera_banco.gd -- partite=3000 seme=1 aggiusta=0

func _init() -> void:
	var arg := {"partite": "3000", "seme": "1", "aggiusta": "0"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			arg[kv[0]] = kv[1]
	var dati := Motore.carica_dati()
	var sf := Sfera.carica_sfera()
	var n := int(arg["partite"])
	var gen := RandomNumberGenerator.new()
	gen.seed = int(arg["seme"])
	var pres := {}
	var dom := {}
	var scambi := 0
	var pari := 0
	var primo := 0
	var arene := ["cortile", "rovine", "fossa"]
	for i in n:
		var m := Sfera.new(dati, sf)
		var a := m.casuale(gen, "A")
		var b := m.casuale(gen, "B")
		m.nuova_sfera(a, b, arene[i % 3], [false, false], int(arg["seme"]) * 100000 + i)
		var v := m.gioca_da_sola()
		scambi += int(m.s["scambio"])
		if v < 0:
			pari += 1
			continue
		if v == (int(m.s["primo"]) + 1) % 2:
			primo += 1
		for q in 2:
			var pg: Dictionary = [a, b][q]
			var w := 1 if v == q else 0
			var ids: Array = pg["coll"].duplicate()
			if String(pg["raro"]) != "":
				ids.append(pg["raro"])
			for id in ids:
				if not pres.has(id):
					pres[id] = [0, 0]
				pres[id][0] += w
				pres[id][1] += 1
			var best := "equilibrato"
			var mx := 0
			var conta := 0
			for k in ["F", "A", "P", "C"]:
				if int(pg[k]) > mx:
					mx = int(pg[k])
					best = k
					conta = 1
				elif int(pg[k]) == mx:
					conta += 1
			if conta > 1:
				best = "equilibrato"
			if not dom.has(best):
				dom[best] = [0, 0]
			dom[best][0] += w
			dom[best][1] += 1
	print("duelli %d  scambi medi %.2f  pari %d  chi inizia vince %.1f%%" % [n, float(scambi) / n, pari, 100.0 * primo / maxi(1, n - pari)])
	var riga := ""
	for k in dom:
		riga += "%s %.1f  " % [k, 100.0 * dom[k][0] / dom[k][1]]
	print("caratteristica più alta: ", riga)
	var cambi := 0
	var costi := {}
	for t in sf["esterni"] + sf["rari"]:
		costi[t["id"]] = t
	var ids := pres.keys()
	ids.sort_custom(func(x, y): return pres[x][0] * 1.0 / pres[x][1] > pres[y][0] * 1.0 / pres[y][1])
	for id in ids:
		var pct: float = 100.0 * pres[id][0] / pres[id][1]
		print("  %-16s costo %d  presenze %5d  vittorie %.1f%%" % [id, int(costi[id]["costo"]), pres[id][1], pct])
		if arg["aggiusta"] == "1" and pres[id][1] >= 150:
			if pct > 52.5 and int(costi[id]["costo"]) < (10 if int(costi[id].get("anello", 2)) == 3 else 8):
				costi[id]["costo"] = int(costi[id]["costo"]) + 1
				cambi += 1
			elif pct < 47.5 and int(costi[id]["costo"]) > 1:
				costi[id]["costo"] = int(costi[id]["costo"]) - 1
				cambi += 1
	if arg["aggiusta"] == "1":
		for t in sf["esterni"] + sf["rari"]:
			t["costo"] = int(t["costo"])
		var f := FileAccess.open("res://data/sfera.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(sf, " ", false).replace(".0,", ",").replace(".0\n", "\n"))
		print("costi cambiati: %d" % cambi)
	quit()
