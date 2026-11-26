extends SceneTree
## Fotografa gli aspetti dei combattenti in alcune pose delle animazioni, per controllarli a occhio.
## uso: xvfb-run -a godot --path . --resolution 1400x700 --script tests/modelli_foto.gd -- out=/tmp/x ids=barbuto,formosa,snella

func _init() -> void:
	var arg := {"out": "/tmp/modelli", "ids": "barbuto,formosa,snella", "clip": "idle,jab,calcio,parata,proiezione,salto_mortale"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			arg[kv[0]] = kv[1]
	DirAccess.make_dir_recursive_absolute(arg["out"])
	var radice := Node3D.new()
	root.add_child(radice)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.25, 0.27)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.6)
	amb.environment = env
	radice.add_child(amb)
	var luce := DirectionalLight3D.new()
	luce.rotation_degrees = Vector3(-40, 30, 0)
	luce.light_energy = 0.9
	radice.add_child(luce)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.1, 5.2)
	radice.add_child(cam)
	var arena := Arena3D.new()
	radice.add_child(arena)
	var ids: PackedStringArray = arg["ids"].split(",")
	var players := []
	for i in ids.size():
		var m: Node3D = arena._modello_combattente(Color.RED, Color.GRAY, ids[i])
		if m == null:
			print("manca ", ids[i])
			continue
		radice.add_child(m)
		m.position = Vector3((i - (ids.size() - 1) / 2.0) * 1.5, 0, 0)
		m.rotation.y = 0
		players.append(arena._player(m))
	for clip in arg["clip"].split(","):
		for ap in players:
			if ap.has_animation(clip):
				ap.play(clip)
				ap.seek(ap.get_animation(clip).length * 0.45, true)
				ap.pause()
		for k in 4:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [arg["out"], clip])
		print("foto ", clip)
	quit()
