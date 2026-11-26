class_name StatoSfera
extends Control
## Barra di un combattente nel duello della sfera: nome, ferite rimaste (barra), vantaggi e svantaggi,
## e se è a terra. Tutto disegnato, niente simboli dei font.

var m: Sfera
var p := 0

func _ready() -> void:
	custom_minimum_size = Vector2(260, 52)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	if m == null or m.s.is_empty():
		return
	var g: Dictionary = m.s["g"][p]
	var col: Color = Disegno.GIOCATORI[p]
	var w := size.x
	var decide := m.chi_decide() == p
	var nome := String(g["nome"]) + ("  -  a terra" if m.a_terra(p) else "")
	Disegno.testo(self, Vector2(4, 18), nome, 16, col.lightened(0.25) if not decide else Disegno.ORO, Disegno.font_titolo(), w - 8)
	# barra delle ferite
	var bw := w - 90.0
	var r := Rect2(4, 26, bw, 14)
	draw_rect(r, Color(0.12, 0.09, 0.07))
	var fr := clampf(float(g["vita"]) / maxf(1.0, float(g["vita_max"])), 0.0, 1.0)
	var cb := Color("#c0392b").lerp(Color("#4caf50"), fr)
	draw_rect(Rect2(r.position, Vector2(bw * fr, 14)), cb.darkened(0.1))
	draw_rect(r, Disegno.ORO.darkened(0.3), false, 1.5)
	Disegno.testo(self, Vector2(bw + 10, 39), "%d/%d" % [g["vita"], g["vita_max"]], 15, Disegno.PERGAMENA)
	# vantaggi (perle d'oro) e svantaggi (perle rosso scuro)
	var x := 8.0
	for i in int(g["vantaggi"]):
		draw_circle(Vector2(x, 47), 4.0, Disegno.ORO)
		x += 11
	if int(g["svantaggi"]) > 0:
		x += 6
	for i in int(g["svantaggi"]):
		draw_circle(Vector2(x, 47), 4.0, Color("#8e2a22"))
		x += 11
