class_name TokenCurvo
extends Control
## Un token curvo della sfera da solo (officina, regole): il pezzo d'anello con nome, posti dei dadi,
## freccia, costo e, sotto, l'effetto. Si accende e spegne con un tocco se "scelta" è attiva.

signal cambiato(scelto: bool)

var t: Dictionary = {}
var colore := ""
var scelto := false
var selezionabile := true
var con_testo := true

func _init(tok: Dictionary = {}, col := "") -> void:
	t = tok
	colore = col
	custom_minimum_size = Vector2(250, 235)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _draw() -> void:
	var w := size.x
	var alto := 118.0
	# un arco di 60 gradi centrato in alto: il centro della sfera è sotto il pezzo
	var ro := w * 0.62
	var ri := ro - alto * 0.78
	var c := Vector2(w / 2.0, 8 + ro)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.06, 0.85) if not scelto else Color(0.24, 0.18, 0.08, 0.95)
	sb.border_color = Disegno.ORO if scelto else Color("#5a4630")
	sb.set_border_width_all(3 if scelto else 1)
	sb.set_corner_radius_all(10)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	if t.has("seconda"):
		# due azioni: due metà dello stesso pezzo d'anello
		var t2 := t.duplicate()
		t2.erase("seconda")
		for k in t["seconda"]:
			t2[k] = t["seconda"][k]
		SferaVista.disegna_token(self, c, ri, ro, -90 - 38, -90 - 0.5, t, {}, scelto, colore)
		SferaVista.disegna_token(self, c, ri, ro, -90 + 0.5, -90 + 38, t2, {}, scelto, colore)
	else:
		SferaVista.disegna_token(self, c, ri, ro, -90 - 27, -90 + 27, t, {}, scelto, colore)
	if t.has("costo"):
		var cr := Rect2(w - 44, 8, 36, 30)
		var sc := StyleBoxFlat.new()
		sc.bg_color = Color("#3a2a1c")
		sc.border_color = Disegno.ORO
		sc.set_border_width_all(1)
		sc.set_corner_radius_all(8)
		draw_style_box(sc, cr)
		Disegno.testo(self, cr.position + Vector2(0, 22), str(int(t["costo"])), 18, Disegno.ORO, Disegno.font_titolo(), cr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if con_testo:
		var modo := ""
		match String(t.get("modo", "")):
			"armato":
				modo = ""
			"subito":
				modo = "Scatta subito. "
		var testo := modo + String(t.get("testo", ""))
		if int(t.get("anello", 2)) == 3:
			testo = "Anello esterno, %s. %s" % ["1 dado" if t["req"].size() == 1 else "%d dadi" % t["req"].size(), testo]
		elif t.get("entrambi", false):
			testo += " Vuole un dado di ciascuno dei due colori."
		if t.has("seconda"):
			testo = String(t["nome"]) + ": " + testo + "\n" + String(t["seconda"]["nome"]) + ": " + String(t["seconda"]["testo"])
		Disegno.testo_a_capo(self, Vector2(10, alto + 14), testo, 14 if not t.has("seconda") else 12, Disegno.PERGAMENA, w - 20, 6)

func _gui_input(ev: InputEvent) -> void:
	if not selezionabile:
		return
	var premi: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed)
	if premi:
		accept_event()
		scelto = not scelto
		queue_redraw()
		cambiato.emit(scelto)
