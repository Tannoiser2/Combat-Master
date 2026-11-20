class_name Disegno
extends RefCounted
## Funzioni di disegno condivise: dadi con i pallini, icone tracciate a mano
## (niente simboli Unicode: sul web diventerebbero quadratini), colori e caratteri.

const COLORI := {
	"rosso": Color("#c8372d"), "blu": Color("#2f6fd0"), "verde": Color("#2f9a52"),
	"viola": Color("#8a4fc4"), "giallo": Color("#d9a420"), "bianco": Color("#ece6d6")
}
const NOMI_COLORE := {"rosso": "rossi", "blu": "blu", "verde": "verdi", "viola": "viola", "giallo": "gialli", "bianco": "bianchi"}
const CATEGORIE := {
	"attributo": Color("#b08d57"), "arma": Color("#9a5b3c"), "armatura": Color("#6f7b86"),
	"mossa": Color("#a8433a"), "talento": Color("#5d7f4a")
}
const NOME_CATEGORIA := {"attributo": "Caratteristica", "arma": "Arma", "armatura": "Armatura", "mossa": "Mossa", "talento": "Talento"}
const ORO := Color("#e0b964")
const PERGAMENA := Color("#efe3c8")
const INCHIOSTRO := Color("#2a1f17")
const SCURO := Color("#1b1612")
const GIOCATORI := [Color("#d9a441"), Color("#5aa0d8")]

static var _font_testo: Font
static var _font_titolo: Font
static var _font_deco: Font

static func font_testo() -> Font:
	if _font_testo == null:
		_font_testo = load("res://assets/fonts/Alegreya.ttf")
	return _font_testo

static func font_titolo() -> Font:
	if _font_titolo == null:
		_font_titolo = load("res://assets/fonts/Cinzel.ttf")
	return _font_titolo

static func font_deco() -> Font:
	if _font_deco == null:
		_font_deco = load("res://assets/fonts/CinzelDecorative-Bold.ttf")
	return _font_deco

static func colore(c: String) -> Color:
	return COLORI.get(c, Color.GRAY)

## Disegna un dado. stato: pronto, usato, bloccato, conservato, riserva, vuoto.
static func dado(ci: CanvasItem, r: Rect2, col: String, v: int, stato: String = "pronto", sel: bool = false) -> void:
	var base := colore(col)
	var raggio := r.size.x * 0.18
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(raggio))
	sb.bg_color = base
	sb.border_color = base.darkened(0.45)
	sb.set_border_width_all(maxi(1, int(r.size.x * 0.05)))
	if stato == "usato":
		sb.bg_color = base.darkened(0.35)
	elif stato == "bloccato":
		sb.bg_color = base.darkened(0.6)
	elif stato == "riserva":
		sb.bg_color = base.darkened(0.15)
		sb.bg_color.a = 0.45
	if sel:
		var hs := StyleBoxFlat.new()
		hs.set_corner_radius_all(int(raggio * 1.4))
		hs.bg_color = Color(0, 0, 0, 0)
		hs.border_color = ORO
		hs.set_border_width_all(maxi(2, int(r.size.x * 0.08)))
		ci.draw_style_box(hs, r.grow(r.size.x * 0.1))
	ci.draw_style_box(sb, r)
	if stato == "riserva":
		return
	var pip := Color("#1d1d1d") if col == "bianco" else Color("#fbf6ea")
	if stato == "bloccato":
		pip = pip.darkened(0.4)
	var c := r.get_center()
	var o := r.size.x * 0.26
	var pr := r.size.x * 0.085
	var pts := []
	match v:
		1: pts = [Vector2.ZERO]
		2: pts = [Vector2(-o, -o), Vector2(o, o)]
		3: pts = [Vector2(-o, -o), Vector2.ZERO, Vector2(o, o)]
		4: pts = [Vector2(-o, -o), Vector2(o, -o), Vector2(-o, o), Vector2(o, o)]
		5: pts = [Vector2(-o, -o), Vector2(o, -o), Vector2.ZERO, Vector2(-o, o), Vector2(o, o)]
		6: pts = [Vector2(-o, -o), Vector2(o, -o), Vector2(-o, 0), Vector2(o, 0), Vector2(-o, o), Vector2(o, o)]
	for p in pts:
		ci.draw_circle(c + p, pr, pip)
	if stato == "bloccato":
		catena(ci, r.grow(-r.size.x * 0.12), Color("#d8d0c0"))
	elif stato == "conservato":
		var rr := Rect2(r.position + Vector2(r.size.x * 0.62, -r.size.y * 0.12), Vector2(r.size.x * 0.5, r.size.x * 0.5))
		icona(ci, "clessidra", rr, ORO)

## Sbarre incrociate sopra un dado bloccato.
static func catena(ci: CanvasItem, r: Rect2, c: Color) -> void:
	var w := maxf(2.0, r.size.x * 0.1)
	ci.draw_line(r.position, r.end, Color(0, 0, 0, 0.6), w + 2)
	ci.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Color(0, 0, 0, 0.6), w + 2)
	ci.draw_line(r.position, r.end, c, w)
	ci.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), c, w)

## Alloggiamento vuoto per un dado: bordo coi colori ammessi.
static func alloggio(ci: CanvasItem, r: Rect2, colori: Array) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(r.size.x * 0.18))
	sb.bg_color = Color(0, 0, 0, 0.18)
	sb.border_color = Color(0, 0, 0, 0.35)
	sb.set_border_width_all(1)
	ci.draw_style_box(sb, r)
	var n := colori.size()
	var w := (r.size.x - 8) / maxi(1, n)
	for i in n:
		ci.draw_rect(Rect2(r.position + Vector2(4 + i * w, r.size.y - 9), Vector2(w - 2, 5)), colore(colori[i]))

static func testo(ci: CanvasItem, pos: Vector2, t: String, size: int, c: Color, f: Font = null, larghezza: float = -1, allinea := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if f == null:
		f = font_testo()
	ci.draw_string(f, pos, t, allinea, larghezza, size, c)

static func testo_a_capo(ci: CanvasItem, pos: Vector2, t: String, size: int, c: Color, larghezza: float, righe: int = -1, f: Font = null) -> void:
	if f == null:
		f = font_testo()
	ci.draw_multiline_string(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, larghezza, size, righe, c)

static func altezza_testo(t: String, size: int, larghezza: float, f: Font = null) -> float:
	if f == null:
		f = font_testo()
	return f.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, larghezza, size).y

## Icone disegnate a mano.
static func icona(ci: CanvasItem, nome: String, r: Rect2, c: Color, spessore: float = -1) -> void:
	var w := spessore if spessore > 0 else maxf(2.0, r.size.x * 0.12)
	var cx := r.get_center()
	var h := r.size * 0.5
	match nome:
		"piu":
			ci.draw_line(cx - Vector2(h.x * 0.7, 0), cx + Vector2(h.x * 0.7, 0), c, w)
			ci.draw_line(cx - Vector2(0, h.y * 0.7), cx + Vector2(0, h.y * 0.7), c, w)
		"meno":
			ci.draw_line(cx - Vector2(h.x * 0.7, 0), cx + Vector2(h.x * 0.7, 0), c, w)
		"croce":
			ci.draw_line(cx - h * 0.6, cx + h * 0.6, c, w)
			ci.draw_line(cx + Vector2(h.x, -h.y) * 0.6, cx + Vector2(-h.x, h.y) * 0.6, c, w)
		"cuore":
			var pts := PackedVector2Array()
			for i in 33:
				var t := TAU * i / 32.0
				var x := 16 * pow(sin(t), 3)
				var y := -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))
				pts.append(cx + Vector2(x, y) * (h.x / 17.0))
			ci.draw_colored_polygon(pts, c)
		"scudo":
			var pts := PackedVector2Array([cx + Vector2(-h.x * 0.8, -h.y * 0.8), cx + Vector2(h.x * 0.8, -h.y * 0.8),
				cx + Vector2(h.x * 0.75, h.y * 0.1), cx + Vector2(0, h.y * 0.9), cx + Vector2(-h.x * 0.75, h.y * 0.1)])
			ci.draw_colored_polygon(pts, c)
		"clessidra":
			var a := PackedVector2Array([cx + Vector2(-h.x * 0.6, -h.y * 0.8), cx + Vector2(h.x * 0.6, -h.y * 0.8), cx + Vector2(0, 0)])
			var b := PackedVector2Array([cx + Vector2(-h.x * 0.6, h.y * 0.8), cx + Vector2(h.x * 0.6, h.y * 0.8), cx + Vector2(0, 0)])
			ci.draw_colored_polygon(a, c)
			ci.draw_colored_polygon(b, c)
		"freccia_su":
			ci.draw_colored_polygon(PackedVector2Array([cx + Vector2(0, -h.y * 0.8), cx + Vector2(h.x * 0.7, h.y * 0.1), cx + Vector2(-h.x * 0.7, h.y * 0.1)]), c)
			ci.draw_line(cx, cx + Vector2(0, h.y * 0.8), c, w * 1.4)
		"freccia_giu":
			ci.draw_colored_polygon(PackedVector2Array([cx + Vector2(0, h.y * 0.8), cx + Vector2(h.x * 0.7, -h.y * 0.1), cx + Vector2(-h.x * 0.7, -h.y * 0.1)]), c)
			ci.draw_line(cx, cx - Vector2(0, h.y * 0.8), c, w * 1.4)
		"ritmo":
			ci.draw_circle(cx, h.x * 0.55, c)
		"ritmo_vuoto":
			ci.draw_arc(cx, h.x * 0.5, 0, TAU, 20, c, w * 0.7)
		"spada":
			ci.draw_line(cx + Vector2(-h.x * 0.7, h.y * 0.7), cx + Vector2(h.x * 0.75, -h.y * 0.75), c, w)
			ci.draw_line(cx + Vector2(-h.x * 0.65, h.y * 0.15), cx + Vector2(-h.x * 0.15, h.y * 0.65), c, w)
		"dado":
			dado(ci, r, "bianco", 5)
		"menu":
			for i in 3:
				var y := cx.y + (i - 1) * h.y * 0.55
				ci.draw_line(Vector2(cx.x - h.x * 0.7, y), Vector2(cx.x + h.x * 0.7, y), c, w)
		"occhio":
			ci.draw_arc(cx, h.x * 0.75, PI * 1.15, PI * 1.85, 16, c, w)
			ci.draw_arc(cx, h.x * 0.75, PI * 0.15, PI * 0.85, 16, c, w)
			ci.draw_circle(cx, h.x * 0.25, c)

## Stile di riquadro coerente con il tema.
static func stile(bg: Color, bordo: Color = Color("#5a4630"), raggio: int = 8, spessore: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = bordo
	sb.set_border_width_all(spessore)
	sb.set_corner_radius_all(raggio)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

static func tema() -> Theme:
	var t := Theme.new()
	t.default_font = font_testo()
	t.default_font_size = 19
	var bn := stile(Color("#3a2a1c"), Color("#8a6a3e"), 7)
	var bh := stile(Color("#4c3724"), ORO, 7)
	var bp := stile(Color("#2a1e14"), ORO, 7)
	var bd := stile(Color("#2a241f"), Color("#4a4038"), 7)
	for k in ["Button", "OptionButton"]:
		t.set_stylebox("normal", k, bn)
		t.set_stylebox("hover", k, bh)
		t.set_stylebox("pressed", k, bp)
		t.set_stylebox("disabled", k, bd)
		t.set_stylebox("focus", k, StyleBoxEmpty.new())
		t.set_color("font_color", k, PERGAMENA)
		t.set_color("font_hover_color", k, Color.WHITE)
		t.set_color("font_pressed_color", k, ORO)
		t.set_color("font_disabled_color", k, Color("#7d7468"))
		t.set_font("font", k, font_titolo())
		t.set_font_size("font_size", k, 17)
	t.set_stylebox("panel", "PanelContainer", stile(Color(0.09, 0.07, 0.055, 0.92), Color("#6b5234"), 10))
	t.set_stylebox("panel", "Panel", stile(Color(0.09, 0.07, 0.055, 0.92), Color("#6b5234"), 10))
	t.set_color("font_color", "Label", PERGAMENA)
	var le := stile(Color("#efe3c8"), Color("#8a6a3e"), 6)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", stile(Color("#f6eedb"), ORO, 6))
	t.set_color("font_color", "LineEdit", INCHIOSTRO)
	t.set_color("caret_color", "LineEdit", INCHIOSTRO)
	t.set_color("font_placeholder_color", "LineEdit", Color("#8b7d68"))
	var pm := stile(Color("#2a1e14"), Color("#8a6a3e"), 6)
	t.set_stylebox("panel", "PopupMenu", pm)
	t.set_color("font_color", "PopupMenu", PERGAMENA)
	t.set_color("font_hover_color", "PopupMenu", ORO)
	t.set_stylebox("hover", "PopupMenu", stile(Color("#4c3724"), ORO, 4))
	t.set_font_size("font_size", "PopupMenu", 18)
	return t
