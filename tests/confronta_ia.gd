extends SceneTree
## Confronto fra due modi di giocare dell'IA (profondità 2 contro 1), stesse coppie a lati invertiti.
## uso: godot --headless --path . --script tests/confronta_ia.gd -- partite=40
func _init() -> void:
	var n := 40
	for a in OS.get_cmdline_user_args():
		if a.begins_with("partite="):
			n = int(a.split("=")[1])
	var dati := Motore.carica_dati()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var vinte := 0
	var giocate := 0
	var t0 := Time.get_ticks_msec()
	for i in n / 2:
		var budget: int = [30, 45, 60][i % 3]
		var pa: Dictionary = Generatore.casuale(dati, budget, rng)
		var pb: Dictionary = Generatore.casuale(dati, budget, rng)
		var seme := rng.randi()
		for lato in 2:
			var m := Motore.new(dati)
			m.nuova_partita(pa, pb, ["cortile", "rovine", "fossa"][i % 3], seme)
			var passi := 0
			while m.s["vinc"] < 0 and passi < 4000:
				var chi := m.chi_decide()
				IA.profondita = 2 if chi == lato else 1
				m.applica(chi, IA.scegli(m, chi))
				passi += 1
			giocate += 1
			if int(m.s["vinc"]) == lato:
				vinte += 1
	print("Profondità 2 contro 1: vince %d su %d (%.0f%%) in %d s" % [vinte, giocate, 100.0 * vinte / giocate, (Time.get_ticks_msec() - t0) / 1000])
	quit()
