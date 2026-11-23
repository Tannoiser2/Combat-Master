class_name StatoGiocatore
extends Control
## Riquadro in alto: nome, Attitudine, ferite, Ritmo, armatura e ciclo dei dadi.

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
	# Ritmo (massimo per azione), recupero e Attitudine dinamica
	var rx := ax + 56
	Disegno.testo(self, Vector2(rx, 53), "Ritmo %d/%d  Recupero %d" % [motore.ritmo_disponibile(giocatore), motore.ritmo_azione(giocatore), g["recupero"]], 14, Disegno.PERGAMENA.darkened(0.1), Disegno.font_titolo())
	var nomi_col := {"rosso": Color("#d96a5f"), "blu": Color("#5f9fd0"), "verde": Color("#65ad79"), "viola": Color("#9b79c9")}
	var plurali := {"rosso": "rossi", "blu": "blu", "verde": "verdi", "viola": "viola"}
	var col_att: String = g.get("attitudine_colore", "")
	var cap := motore.limite_colore(giocatore, col_att if col_att != "" else "rosso")
	var cap_txt := "max %d %s" % [cap, plurali.get(col_att, "per colore")]
	Disegno.testo(self, Vector2(w - 200, 77), "%s · %s" % [String(g.get("attitudine", "neutrale")).capitalize(), cap_txt], 12, nomi_col.get(col_att, Disegno.PERGAMENA.darkened(0.1)), Disegno.font_titolo(), 188, HORIZONTAL_ALIGNMENT_RIGHT)
	# la sfera: vantaggi costruiti sull'avversario e svantaggi propri
	var vx := x0 + 112
	Disegno.testo(self, Vector2(vx, 77), "Vantaggi %d" % int(g.get("vantaggi", 0)), 12, Disegno.ORO, Disegno.font_titolo(), 80)
	Disegno.testo(self, Vector2(vx + 82, 77), "Svantaggi %d" % int(g.get("svantaggi", 0)), 12, Color("#d96a5f"), Disegno.font_titolo(), 90)
	# dadi preparati o conservati in piccolo; il mucchio resta nel vassoio centrale
	var dx := x0
	for st in ["mano", "conservato", "stordito"]:
		for d in motore.dadi_di(giocatore, st):
			Disegno.dado(self, Rect2(dx, 62, 18, 18), d["col"], d["v"], "bloccato" if st == "stordito" else st)
			dx += 21
		if not motore.dadi_di(giocatore, st).is_empty():
			dx += 8
