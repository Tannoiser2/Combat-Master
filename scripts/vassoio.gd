class_name Vassoio
extends Control
## Vassoio circolare dei dadi: il mucchio è la riserva operativa da cui si
## seleziona direttamente per ogni azione; Attesa e fuori gioco sono separati.
## I dadi piazzati restano disegnati sugli spazi dei token.

signal dado_premuto(id: int)

var D := 44.0
const GAP := 10.0

var motore: Motore
var giocatore := 0
var selezionati: Array = []
var evidenziati: Array = []   # dadi selezionabili come bersaglio (scambio, rovescio...)
var interattivo := true
var scegli_mucchio := false   # true quando il mucchio è selezionabile per un'azione
var _rect := {}
var _tutti := {}              # id -> rettangolo di ogni dado disegnato
var in_volo: Dictionary = {}  # dadi che stanno arrivando in volo: non si disegnano ancora
var _premuto := Vector2.ZERO

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(270, 300)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

## Il mucchio è un cerchio centrale; le condizioni eccezionali orbitano sotto.
func _draw() -> void:
	_rect.clear()
	_tutti.clear()
	if motore == null:
		return
	var w := maxf(size.x, 240.0)
	var fuori: Array = motore.dadi_di(giocatore, "stordito") + motore.dadi_di(giocatore, "eliminato")
	var mucchio: Array = motore.dadi_di(giocatore, "mucchio")
	var g: Dictionary = motore.s["g"][giocatore]
	var col_att: String = g.get("attitudine_colore", "")
	var nomi_col := {"rosso": "rossi", "blu": "blu", "verde": "verdi", "viola": "viola"}
	var max_col := motore.limite_colore(giocatore, col_att if col_att != "" else "rosso")
	var limite_txt := "max %d %s" % [max_col, nomi_col.get(col_att, "per colore")]
	var centro := Vector2(w * 0.5, 132)
	var raggio := clampf(w * 0.36, 92.0, 122.0)
	draw_circle(centro, raggio + 7, Color(0.73, 0.55, 0.24, 0.16))
	draw_circle(centro, raggio, Color(0.10, 0.085, 0.065, 0.92))
	draw_arc(centro, raggio, 0, TAU, 64, Disegno.ORO if scegli_mucchio else Color("#6f5b3e"), 2.5 if scegli_mucchio else 1.2, true)
	var titolo := "MUCCHIO · Ritmo %d/%d" % [motore.ritmo_disponibile(giocatore), motore.ritmo_azione(giocatore)]
	Disegno.testo(self, Vector2(centro.x - raggio + 8, centro.y - raggio + 22), titolo, 14, Disegno.ORO if scegli_mucchio else Disegno.PERGAMENA.darkened(0.1), Disegno.font_titolo(), raggio * 2.0 - 16, HORIZONTAL_ALIGNMENT_CENTER)
	Disegno.testo(self, Vector2(centro.x - raggio + 8, centro.y + raggio - 18), "%s · %s" % [String(g.get("attitudine", "neutrale")).capitalize(), limite_txt], 12, Disegno.ORO if col_att != "" else Disegno.PERGAMENA, Disegno.font_titolo(), raggio * 2.0 - 16, HORIZONTAL_ALIGNMENT_CENTER)
	var dim := 38.0 if scegli_mucchio else 32.0
	var colonne := maxi(3, int((raggio * 2.0 - 28.0) / (dim + 5.0)))
	var righe := int(ceil(float(maxi(1, mucchio.size())) / colonne))
	var larghezza := mini(colonne, maxi(1, mucchio.size())) * (dim + 5.0) - 5.0
	var altezza := righe * (dim + 5.0) - 5.0
	var origine := Vector2(centro.x - larghezza * 0.5, centro.y - altezza * 0.5 + 12)
	for i in mucchio.size():
		var d: Dictionary = mucchio[i]
		var rr := Rect2(origine + Vector2((i % colonne) * (dim + 5.0), (i / colonne) * (dim + 5.0)), Vector2(dim, dim))
		_tutti[d["id"]] = rr
		if not in_volo.has(d["id"]):
			Disegno.dado(self, rr, d["col"], d["v"], "pronto", selezionati.has(d["id"]))
		if scegli_mucchio:
			_rect[d["id"]] = rr

	var y := centro.y + raggio + 34.0
	var attesa_dadi := motore.dadi_di(giocatore, "attesa")
	if not attesa_dadi.is_empty():
		# Due frecce sottili rendono visibile il circuito Attesa -> Mucchio.
		var freccia := Color("#9e8357")
		draw_line(Vector2(centro.x - 24, centro.y + raggio + 3), Vector2(centro.x - 24, y - 8), freccia, 2)
		draw_colored_polygon(PackedVector2Array([Vector2(centro.x - 29, y - 13), Vector2(centro.x - 19, y - 13), Vector2(centro.x - 24, y - 5)]), freccia)
		draw_line(Vector2(centro.x + 24, y - 8), Vector2(centro.x + 24, centro.y + raggio + 3), freccia, 2)
		draw_colored_polygon(PackedVector2Array([Vector2(centro.x + 19, centro.y + raggio + 11), Vector2(centro.x + 29, centro.y + raggio + 11), Vector2(centro.x + 24, centro.y + raggio + 3)]), freccia)

	var gruppi := [["IN ATTESA", attesa_dadi, false],
		["Preparati", motore.dadi_di(giocatore, "mano"), scegli_mucchio],
		["Conservati", motore.dadi_di(giocatore, "conservato"), not scegli_mucchio],
		["Fuori gioco", fuori, false]]
	for k in gruppi.size():
		var nome: String = gruppi[k][0]
		var lista: Array = gruppi[k][1]
		var tocc: bool = gruppi[k][2]
		if lista.is_empty():
			continue
		Disegno.testo(self, Vector2(8, y + 16), "%s (%d)" % [nome, lista.size()], 13, Disegno.PERGAMENA.darkened(0.15), Disegno.font_titolo(), w - 16, HORIZONTAL_ALIGNMENT_CENTER)
		y += 22
		var dim2 := D if tocc else D * 0.62
		var ordinati := lista.duplicate()
		ordinati.sort_custom(func(a, b): return Motore.COLORI.find(a["col"]) < Motore.COLORI.find(b["col"]))
		var totale := ordinati.size() * (dim2 + 5.0) - 5.0
		var x := maxf(8.0, (w - totale) * 0.5)
		for d in ordinati:
			if x + dim2 > w - 4:
				x = 4.0
				y += dim2 + 6
			var rr := Rect2(x, y, dim2, dim2)
			if evidenziati.has(d["id"]):
				draw_rect(rr.grow(6), Color(0.6, 0.85, 0.5, 0.45))
			_tutti[d["id"]] = rr
			if not in_volo.has(d["id"]):
				Disegno.dado(self, rr, d["col"], d["v"], "bloccato" if k in [0, 3] else d["st"], selezionati.has(d["id"]))
			if tocc:
				_rect[d["id"]] = rr
			x += dim2 + 5.0
		y += dim2 + 10
	if absf(custom_minimum_size.y - y) > 1.0:
		custom_minimum_size.y = y

## Rettangoli in coordinate dello schermo di tutti i dadi disegnati.
func rect_globali() -> Dictionary:
	var out := {}
	var t := get_global_transform()
	for id in _tutti:
		var r: Rect2 = _tutti[id]
		out[id] = Rect2(t * r.position, r.size * t.get_scale())
	return out

func _gui_input(e: InputEvent) -> void:
	if not interattivo:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_premuto = e.position
		elif e.position.distance_to(_premuto) < 14:
			for id in _rect:
				if _rect[id].grow(5).has_point(e.position):
					dado_premuto.emit(id)
					return
