extends SceneTree
## Primo piano dei combattenti 3D in alcune pose, per controllare modello e animazioni.
## uso: xvfb-run godot --path . --resolution 1180x820 --script tests/figure_3d.gd -- out=/tmp/shots/fig

var out := "/tmp/shots/fig"
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
	await _attendi(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s_%s.png" % [out, nome])
	print("foto ", nome)

func _giro() -> void:
	await _attendi(10)
	var d: Dictionary = main.dati
	main.battaglia(d["personaggi"][0].duplicate(true), d["personaggi"][2].duplicate(true), d["scenari"][0], [true, true])
	main.ia = [false, false]
	await _attendi(30)
	var ar: Arena3D = main.arena
	# avvicina la camera alla prima figura
	ar.pivot.position = ar.figure[0].position + Vector3(0, 0.9, 0)
	ar.spostamento_v = 0.0
	ar.spostamento_h = 0.0
	ar.distanza = 4.5
	ar.pitch = deg_to_rad(18.0)
	ar._aggiorna_cam()
	await _foto("guardia")
	for nome in ["jab", "calcio", "parata", "schivata", "colpito_testa", "proiezione", "passo_avanti", "ko"]:
		ar.clip(0, nome, 1.0, "")
		await create_timer(0.45).timeout
		await _foto(nome)
	quit()
