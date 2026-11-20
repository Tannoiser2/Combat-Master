class_name Vassoio
extends Control
## Vassoio dei dadi di un combattente: la mano (dadi pescati e tirati, si toccano per sceglierli),
## i conservati, il mucchio da cui si pesca, gli storditi e gli eliminati.
## I dadi piazzati restano disegnati sugli spazi dei token.

signal dado_premuto(id: int)

var D := 44.0
const GAP := 10.0

var motore: Motore
var giocatore := 0
var selezionati: Array = []
var evidenziati: Array = []   # dadi selezionabili come bersaglio (scambio, rovescio...)
var interattivo := true
var scegli_mucchio := false   # true quando si scelgono dadi dal mucchio
var _rect := {}
var _tutti := {}              # id -> rettangolo di ogni dado disegnato
var in_volo: Dictionary = {}  # dadi che stanno arrivando in volo: non si disegnano ancora
var _premuto := Vector2.ZERO

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(240, 120)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

## In colonna: in mano, conservati, mucchio, scartati (storditi ed eliminati). I dadi vanno a capo.
func _draw() -> void:
	_rect.clear()
	_tutti.clear()
	if motore == null:
		return
	var w := maxf(size.x, 200.0)
	var scartati: Array = motore.dadi_di(giocatore, "stordito") + motore.dadi_di(giocatore, "eliminato")
	var gruppi := [["In mano", motore.dadi_di(giocatore, "mano"), not scegli_mucchio],
		["Conservati", motore.dadi_di(giocatore, "conservato"), not scegli_mucchio],
		["Mucchio", motore.dadi_di(giocatore, "mucchio"), scegli_mucchio],
		["Scartati", scartati, false]]
	var y := 0.0
	for k in gruppi.size():
		var nome: String = gruppi[k][0]
		var lista: Array = gruppi[k][1]
		var tocc: bool = gruppi[k][2]
		if lista.is_empty() and k == 1:
			continue
		var titolo := "%s (%d)" % [nome, lista.size()] if k >= 2 else nome
		if k == 2 and scegli_mucchio:
			titolo = "Mucchio: tocca i dadi da prendere"
		Disegno.testo(self, Vector2(4, y + 16), titolo, 14, Disegno.ORO if (k == 2 and scegli_mucchio) else Disegno.PERGAMENA.darkened(0.15), Disegno.font_titolo(), w - 8)
		y += 22
		var dim := D if (tocc or k == 0) else D * 0.62
		if lista.is_empty():
			Disegno.testo(self, Vector2(6, y + 16), "vuoto", 14, Color(1, 1, 1, 0.45))
			y += 26
			continue
		var ordinati := lista.duplicate()
		if k >= 2:
			ordinati.sort_custom(func(a, b): return Motore.COLORI.find(a["col"]) < Motore.COLORI.find(b["col"]))
		var x := 4.0
		for d in ordinati:
			if x + dim > w - 2:
				x = 4.0
				y += dim + 6
			var r := Rect2(x, y, dim, dim)
			if evidenziati.has(d["id"]):
				draw_rect(r.grow(6), Color(0.6, 0.85, 0.5, 0.45))
			var st: String = "pronto" if k == 2 else ("bloccato" if k == 3 else d["st"])
			_tutti[d["id"]] = r
			if not in_volo.has(d["id"]):
				Disegno.dado(self, r, d["col"], d["v"], st, selezionati.has(d["id"]))
			if tocc:
				_rect[d["id"]] = r
			x += dim + GAP * (1.0 if tocc else 0.5)
		y += dim + 10
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
