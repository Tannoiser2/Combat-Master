extends SceneTree
## Disegna la copertina per la ludoteca. uso: xvfb-run godot --path . --resolution 900x1200 --script tests/copertina.gd
func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_vai.call_deferred(main)

func _vai(main) -> void:
	for i in 5:
		await process_frame
	main._pulisci()
	main._demo = false
	var d: Dictionary = main.dati
	var mm := Motore.new(d)
	mm.nuova_partita(d["personaggi"][4], d["personaggi"][5], "fossa", 9)
	mm.s["g"][0]["pos"] = Vector2i(-1, 1)
	mm.s["g"][0]["dir"] = 0
	mm.s["g"][1]["pos"] = Vector2i(0, 1)
	mm.s["g"][1]["dir"] = 3
	main.arena.visible = true
	main.arena.costruisci(mm)
	main.arena.mostra_nomi(false)
	main.arena.yaw = -0.5
	main.arena.pitch = deg_to_rad(28)
	main.arena.distanza = 6.5
	main.arena.spostamento_v = -0.08
	main.arena.pivot.position = Arena3D.mondo(Vector2i(0, 1)) * 0.5 + Arena3D.mondo(Vector2i(-1, 1)) * 0.5 + Vector3(0, 0.6, 0)
	main.arena.ruota_vista(0)
	var t: Label = main._label("COMBAT\nMASTER", 120, Disegno.ORO, Disegno.font_deco())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.set_anchors_preset(Control.PRESET_TOP_WIDE)
	t.offset_top = 40
	t.add_theme_constant_override("outline_size", 18)
	t.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
	t.add_theme_constant_override("line_spacing", -20)
	main.pagina.add_child(t)
	var st: Label = main._label("Schermaglie fantasy di dadi e token", 40, Disegno.PERGAMENA)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	st.offset_top = -110
	st.add_theme_constant_override("outline_size", 12)
	st.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
	main.pagina.add_child(st)
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/copertina.png")
	quit()
