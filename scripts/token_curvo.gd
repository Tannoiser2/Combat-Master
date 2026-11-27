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
	# l'altezza segue il testo: circa 34 caratteri per riga a 13-14 punti
	var lettere := 0
	for az in tok.get("azioni", []):
		lettere += String(az.get("testo", "")).length() + String(az.get("nome", "")).length() + 4
	lettere += String(tok.get("testo_cond", "")).length() + (30 if int(tok.get("anello", 2)) == 3 else 0)
	var righe: int = int(ceil(lettere / 34.0)) + tok.get("azioni", []).size() - 1
	custom_minimum_size = Vector2(250, maxf(235.0, 140.0 + righe * 18.5))
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
	var n_az: int = t["azioni"].size() if t.has("azioni") else 1
	if n_az == 2:
		# due azioni: due metà dello stesso pezzo d'anello
		SferaVista.disegna_token(self, c, ri, ro, -90 - 38, -90 - 0.5, Sfera.parte_di(t, 0), {}, scelto, colore)
		SferaVista.disegna_token(self, c, ri, ro, -90 + 0.5, -90 + 38, Sfera.parte_di(t, 1), {}, scelto, colore)
	else:
		# un'azione sola: mezzo pezzo, come sulla sfera
		SferaVista.disegna_token(self, c, ri, ro, -90 - 19, -90 + 19, Sfera.parte_di(t, 0), {}, scelto, colore)
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
		var righe := []
		for k in n_az:
			var pz := Sfera.parte_di(t, k)
			var r := String(pz["testo"])
			if n_az == 2:
				r = String(pz["nome"]) + ": " + r
			righe.append(r)
		var testo := "\n".join(righe)
		if int(t.get("anello", 2)) == 3:
			testo = "Anello esterno, %s. %s %s" % [" | ".join(t.get("coppia", [])), testo, String(t.get("testo_cond", ""))]
		Disegno.testo_a_capo(self, Vector2(10, alto + 14), testo, 13 if n_az == 2 else 14, Disegno.PERGAMENA, w - 20, 14)

func _gui_input(ev: InputEvent) -> void:
	if not selezionabile:
		return
	var premi: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed)
	if premi:
		accept_event()
		scelto = not scelto
		queue_redraw()
		cambiato.emit(scelto)
