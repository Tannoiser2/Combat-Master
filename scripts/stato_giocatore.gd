class_name StatoGiocatore
extends Control
## Riquadro in alto: nome, ferite, ritmo, armatura e dadi del combattente.

var motore: Motore
var giocatore := 0
var a_destra := false

func _init() -> void:
	custom_minimum_size = Vector2(470, 86)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if motore == null:
		return
	var g: Dictionary = motore.s["g"][giocatore]
	var col: Color = Disegno.GIOCATORI[giocatore]
	var w := size.x
	var decide := motore.chi_decide() == giocatore
	var bg := Disegno.stile(Color(0.1, 0.08, 0.06, 0.9), col if decide else Color("#4a3a28"), 10, 3 if decide else 1)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	var x0 := 12.0
	Disegno.testo(self, Vector2(x0, 26), g["nome"], 20, col.lightened(0.2), Disegno.font_titolo(), w - 150)
	var stato := ""
	if motore.s["vinc"] < 0:
		if decide:
			stato = "decide"
		elif g["passato"]:
			stato = "ha passato"
		elif int(motore.s["attivo"]) == giocatore:
			stato = "iniziativa"
	if stato != "":
		Disegno.testo(self, Vector2(w - 130, 24), stato, 15, Disegno.ORO if decide else Disegno.PERGAMENA, Disegno.font_titolo(), 120, HORIZONTAL_ALIGNMENT_RIGHT)
	# ferite
	Disegno.icona(self, "cuore", Rect2(x0, 36, 20, 20), Color("#d64a3a"))
	var bw := 150.0
	draw_rect(Rect2(x0 + 26, 40, bw, 14), Color("#3a1712"))
	var fr: float = clampf(float(g["vita"]) / g["vita_max"], 0, 1)
	draw_rect(Rect2(x0 + 26, 40, bw * fr, 14), Color("#c8372d").lerp(Color("#d9a441"), fr * 0.5))
	draw_rect(Rect2(x0 + 26, 40, bw, 14), Color("#7a5a3a"), false, 1)
	Disegno.testo(self, Vector2(x0 + 26 + bw + 8, 53), "%d/%d" % [g["vita"], g["vita_max"]], 16, Disegno.PERGAMENA)
	# armatura
	var ax := x0 + 26 + bw + 66
	Disegno.icona(self, "scudo", Rect2(ax, 36, 20, 20), Color("#9aa3ab"))
	Disegno.testo(self, Vector2(ax + 24, 53), str(g["armatura"]), 16, Disegno.PERGAMENA)
	# ritmo
	var rx := ax + 56
	Disegno.testo(self, Vector2(rx, 53), "Ritmo", 14, Disegno.PERGAMENA.darkened(0.1), Disegno.font_titolo())
	var lib := motore.ritmo_libero(giocatore)
	for i in int(g["ritmo"]):
		Disegno.icona(self, "ritmo" if i < lib else "ritmo_vuoto", Rect2(rx + 54 + i * 18, 39, 15, 15), Disegno.ORO)
	# dadi in piccolo
	var dx := x0
	for st in ["pronto", "conservato", "bloccato"]:
		for d in motore.dadi_di(giocatore, st):
			Disegno.dado(self, Rect2(dx, 62, 18, 18), d["col"], d["v"], st)
			dx += 21
		if not motore.dadi_di(giocatore, st).is_empty():
			dx += 8
