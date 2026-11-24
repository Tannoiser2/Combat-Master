extends SceneTree
func _init():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_g.call_deferred(main)
func _g(main):
	for i in 10: await process_frame
	var d: Dictionary = main.dati
	main.battaglia(d["personaggi"][0].duplicate(true), d["personaggi"][2].duplicate(true), d["scenari"][0], [true, true])
	main.ia = [false, false]
	for i in 20: await process_frame
	var ar: Arena3D = main.arena
	ar.pivot.position = ar.figure[0].position + Vector3(0, 0.5, 0)
	ar.distanza = 5.0
	ar.pitch = deg_to_rad(25.0)
	ar.spostamento_v = 0.0
	ar.spostamento_h = 0.0
	ar._aggiorna_cam()
	for nome in ["ko", "proiettato", "sconfitta"]:
		var ap: AnimationPlayer = ar._ap(0)
		ap.play(nome)
		ap.seek(ap.get_animation(nome).length - 0.02, true)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/shots/fine_%s.png" % nome)
	quit()
