extends SceneTree
## Schermate della sfera per controllarle a occhio.
## uso: xvfb-run godot --path . --resolution 1600x900 --script tests/screenshots_sfera.gd -- out=/tmp/shots/sf

var out := "/tmp/shots/sf"
var main: Node

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_giro.call_deferred()

func _attendi(n: int) -> void:
	for i in n:
		await process_frame

func _foto(nome: String) -> void:
	await _attendi(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s_%s.png" % [out, nome])
	print("foto ", nome)

func _giro() -> void:
	await _attendi(10)
	await _foto("menu")
	main.sf_prepara("ia")
	await _foto("prepara")
	main.sf_officina()
	await _foto("officina")
	var sf: Dictionary = main.sf
	main.sf_battaglia(sf["personaggi"][0].duplicate(true), sf["personaggi"][1].duplicate(true), "cortile", [false, true])
	for i in 400:
		await process_frame
		if main.ms.chi_decide() == 0 and not main.arena.occupato():
			break
	main._sf_aggiorna()
	await _foto("battaglia")
	var mano: Array = main.ms.s["g"][0]["mano"]
	if not mano.is_empty():
		main._sf_premuto({"tipo": "dado", "id": mano[0]["id"]})
		await _foto("dado_scelto")
		main._sf_azzera()
	# l'IA gioca per entrambi per un po'
	main._sf_ia = [true, true]
	Engine.time_scale = 6.0
	for i in 900:
		await process_frame
		if main.ms.s["vinc"] >= 0:
			break
		if main.ms.s["scambio"] >= 3 and main.ms.chi_decide() == 0 and main.ms.s["fase"] == "azione" and not main.arena.occupato():
			break
	Engine.time_scale = 1.0
	main._sf_ia = [false, true]
	for i in 300:
		await process_frame
		if not main.arena.occupato():
			break
	main._sf_aggiorna()
	await _foto("terzo_scambio")
	main._sf_avversario = true
	main._sf_aggiorna()
	await _foto("avversario")
	quit()
