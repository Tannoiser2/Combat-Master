extends SceneTree
## Misura dove va il tempo: decisioni dell'IA, numero di opzioni, partite.
func _init() -> void:
	var dati := Motore.carica_dati()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("prof="):
			IA.profondita = int(a.substr(5))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var tot_ia := 0
	var n_dec := 0
	var n_opz := 0
	var lente := []
	var t0 := Time.get_ticks_msec()
	for i in 4:
		var a := Generatore.casuale(dati, 45, rng)
		var b := Generatore.casuale(dati, 45, rng)
		var m := Motore.new(dati)
		m.nuova_partita(a, b, "cortile", rng.randi())
		var passi := 0
		while m.s["vinc"] < 0 and passi < 3000:
			var chi := m.chi_decide()
			Motore.conta_cloni = 0
			Motore.conta_opzioni = 0
			var t := Time.get_ticks_usec()
			var o := m.opzioni(chi).size()
			var op := IA.scegli(m, chi, rng)
			var dt := Time.get_ticks_usec() - t
			tot_ia += dt
			n_dec += 1
			n_opz += o
			if dt > 200000:
				lente.append([dt / 1000, o, m.s["fase"], Motore.conta_cloni, Motore.conta_opzioni])
			if op.is_empty():
				break
			m.applica(chi, op)
			m.prendi_eventi()
			passi += 1
		print("partita %d: %d scambi, %d decisioni, %d ms" % [i, m.s["round"], passi, Time.get_ticks_msec() - t0])
	print("decisioni %d, media %.1f ms, opzioni medie %.1f" % [n_dec, tot_ia / 1000.0 / n_dec, float(n_opz) / n_dec])
	lente.sort_custom(func(x, y): return x[0] > y[0])
	print("piu lente: ", lente.slice(0, 10))
	quit()
