class_name DadoVolante
extends Control
## Un dado disegnato che vola dal vassoio a un alloggio di un token, o ritorna nel mucchio.

var col := "rosso"
var v := 1

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	Disegno.dado(self, Rect2(Vector2.ZERO, size), col, v, "pronto")
