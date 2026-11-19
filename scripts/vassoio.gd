class_name Vassoio
extends Control
## Vassoio dei dadi di un combattente: pronti e conservati si toccano per sceglierli,
## usati e bloccati restano visibili a parte.

signal dado_premuto(id: int)

const D := 50.0
const GAP := 10.0

var motore: Motore
var giocatore := 0
var selezionati: Array = []
var interattivo := true
var _rect := {}
var _premuto := Vector2.ZERO

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(560, 84)

func _ordine() -> Array:
	var gruppi := {"pronto": [], "conservato": [], "usato": [], "bloccato": [], "riserva": []}
	for d in motore.s["g"][giocatore]["dadi"]:
		gruppi[d["st"]].append(d)
	return [gruppi["pronto"], gruppi["conservato"], gruppi["usato"] + gruppi["riserva"], gruppi["bloccato"]]

func _draw() -> void:
	_rect.clear()
	if motore == null:
		return
	var x := 4.0
	var etichette := ["Pronti", "Conservati", "Usati", "Bloccati"]
	var gr := _ordine()
	for k in gr.size():
		var lista: Array = gr[k]
		if lista.is_empty() and k > 0:
			continue
		Disegno.testo(self, Vector2(x, 16), etichette[k], 14, Disegno.PERGAMENA.darkened(0.15), Disegno.font_titolo())
		var dim := D if k <= 1 else D * 0.72
		var y := 24.0 + (D - dim) * 0.5
		if lista.is_empty():
			Disegno.testo(self, Vector2(x, 56), "nessuno", 15, Color(1, 1, 1, 0.45))
			x += 90
		for d in lista:
			var r := Rect2(x, y, dim, dim)
			Disegno.dado(self, r, d["col"], d["v"], d["st"], selezionati.has(d["id"]))
			if k <= 1:
				_rect[d["id"]] = r
			x += dim + GAP * (1.0 if k <= 1 else 0.6)
		x += 26
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
