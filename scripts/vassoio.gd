class_name Vassoio
extends Control
## Vassoio dei dadi di un combattente: la mano (dadi pescati e tirati, si toccano per sceglierli),
## i conservati, il mucchio da cui si pesca, gli storditi e gli eliminati.
## I dadi piazzati restano disegnati sugli spazi dei token.

signal dado_premuto(id: int)

const D := 50.0
const GAP := 10.0

var motore: Motore
var giocatore := 0
var selezionati: Array = []
var evidenziati: Array = []   # dadi selezionabili come bersaglio (scambio, rovescio...)
var interattivo := true
var scegli_mucchio := false   # true quando si scelgono dadi dal mucchio
var _rect := {}
var _premuto := Vector2.ZERO

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(560, 84)

func _draw() -> void:
	_rect.clear()
	if motore == null:
		return
	var x := 4.0
	var gruppi := [["In mano", motore.dadi_di(giocatore, "mano"), not scegli_mucchio],
		["Conservati", motore.dadi_di(giocatore, "conservato"), not scegli_mucchio],
		["Mucchio", motore.dadi_di(giocatore, "mucchio"), scegli_mucchio],
		["Storditi", motore.dadi_di(giocatore, "stordito"), false]]
	for k in gruppi.size():
		var nome: String = gruppi[k][0]
		var lista: Array = gruppi[k][1]
		var tocc: bool = gruppi[k][2]
		if lista.is_empty() and k in [1, 3]:
			continue
		var titolo := "%s (%d)" % [nome, lista.size()] if k == 2 else nome
		if k == 2 and scegli_mucchio:
			titolo = "Mucchio: tocca i dadi da prendere"
		Disegno.testo(self, Vector2(x, 16), titolo, 14, Disegno.ORO if (k == 2 and scegli_mucchio) else Disegno.PERGAMENA.darkened(0.15), Disegno.font_titolo())
		var inizio := x
		var larg_titolo := Disegno.font_titolo().get_string_size(titolo, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var dim := D if tocc else D * 0.62
		var y := 24.0 + (D - dim) * 0.5
		if lista.is_empty():
			Disegno.testo(self, Vector2(x, 56), "vuoto", 15, Color(1, 1, 1, 0.45))
			x += 90
		var ordinati := lista.duplicate()
		if k == 2:
			ordinati.sort_custom(func(a, b): return Motore.COLORI.find(a["col"]) < Motore.COLORI.find(b["col"]))
		for d in ordinati:
			var r := Rect2(x, y, dim, dim)
			if evidenziati.has(d["id"]):
				draw_rect(r.grow(6), Color(0.6, 0.85, 0.5, 0.45))
			var st: String = "pronto" if k == 2 else ("bloccato" if k == 3 else d["st"])
			Disegno.dado(self, r, d["col"], d["v"], st, selezionati.has(d["id"]))
			if tocc:
				_rect[d["id"]] = r
			x += dim + GAP * (1.0 if tocc else 0.5)
		x = maxf(x, inizio + larg_titolo)
		x += 26
	var elim := motore.dadi_di(giocatore, "eliminato").size()
	if elim > 0:
		Disegno.testo(self, Vector2(x, 16), "Eliminati", 14, Disegno.PERGAMENA.darkened(0.15), Disegno.font_titolo())
		Disegno.testo(self, Vector2(x, 56), str(elim), 20, Color(1, 1, 1, 0.6))
		x += 100
	custom_minimum_size.x = maxf(560.0, x)

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
