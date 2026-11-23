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

## Orbita: il mucchio è il cerchio centrale; intorno ruotano le zone dove i dadi passano
## (sui token, in attesa, fuori gioco), con le frecce del ciclo:
## mucchio -> azione -> token -> sblocco -> attesa -> recupero -> mucchio.
func _draw() -> void:
	_rect.clear()
	_tutti.clear()
	if motore == null:
		return
	var w := maxf(size.x, 240.0)
	var fuori: Array = motore.dadi_di(giocatore, "stordito") + motore.dadi_di(giocatore, "eliminato")
	var mucchio: Array = motore.dadi_di(giocatore, "mucchio")
	var attesa_dadi: Array = motore.dadi_di(giocatore, "attesa")
	var sui_token: Array = motore.dadi_di(giocatore, "token")
	var g: Dictionary = motore.s["g"][giocatore]
	var col_att: String = g.get("attitudine_colore", "")
	var nomi_col := {"rosso": "rossi", "blu": "blu", "verde": "verdi", "viola": "viola"}
	var max_col := motore.limite_colore(giocatore, col_att if col_att != "" else "rosso")
	var limite_txt := "max %d %s" % [max_col, nomi_col.get(col_att, "per colore")]
	# geometria: cerchio a sinistra, tre satelliti in colonna a destra
	var raggio := clampf(w * 0.27, 78.0, 128.0)
	var centro := Vector2(raggio + 10.0, raggio + 12.0)
	var sx := centro.x + raggio + 30.0
	var sw := w - sx - 4.0
	var sh := (raggio * 2.0 + 4.0 - 16.0) / 3.0
	var box_tok := Rect2(sx, 6, sw, sh)
	var box_att := Rect2(sx, 6 + sh + 8, sw, sh)
	var box_fuori := Rect2(sx, 6 + (sh + 8) * 2, sw, sh)
	# mucchio
	draw_circle(centro, raggio + 7, Color(0.73, 0.55, 0.24, 0.16))
	draw_circle(centro, raggio, Color(0.10, 0.085, 0.065, 0.92))
	draw_arc(centro, raggio, 0, TAU, 64, Disegno.ORO if scegli_mucchio else Color("#6f5b3e"), 2.5 if scegli_mucchio else 1.2, true)
	var titolo := "MUCCHIO · Ritmo %d/%d" % [motore.ritmo_disponibile(giocatore), motore.ritmo_azione(giocatore)]
	Disegno.testo(self, Vector2(centro.x - raggio + 8, centro.y - raggio + 22), titolo, 13, Disegno.ORO if scegli_mucchio else Disegno.PERGAMENA.darkened(0.1), Disegno.font_titolo(), raggio * 2.0 - 16, HORIZONTAL_ALIGNMENT_CENTER)
	Disegno.testo(self, Vector2(centro.x - raggio + 8, centro.y + raggio - 16), "%s · %s" % [String(g.get("attitudine", "neutrale")).capitalize(), limite_txt], 11, Disegno.ORO if col_att != "" else Disegno.PERGAMENA, Disegno.font_titolo(), raggio * 2.0 - 16, HORIZONTAL_ALIGNMENT_CENTER)
	var dim := clampf(raggio * 0.34, 28.0, 40.0)
	var colonne := maxi(3, int((raggio * 1.7) / (dim + 5.0)))
	var righe := int(ceil(float(maxi(1, mucchio.size())) / colonne))
	var larghezza := mini(colonne, maxi(1, mucchio.size())) * (dim + 5.0) - 5.0
	var altezza := righe * (dim + 5.0) - 5.0
	var origine := Vector2(centro.x - larghezza * 0.5, centro.y - altezza * 0.5 + 6)
	for i in mucchio.size():
		var d: Dictionary = mucchio[i]
		var rr := Rect2(origine + Vector2((i % colonne) * (dim + 5.0), (i / colonne) * (dim + 5.0)), Vector2(dim, dim))
		_tutti[d["id"]] = rr
		if evidenziati.has(d["id"]):
			draw_rect(rr.grow(5), Color(0.6, 0.85, 0.5, 0.45))
		if not in_volo.has(d["id"]):
			Disegno.dado(self, rr, d["col"], d["v"], "pronto", selezionati.has(d["id"]))
		if scegli_mucchio:
			_rect[d["id"]] = rr
	# satelliti
	_satellite(box_tok, "Sui token", sui_token, Color("#6f5b3e"), false, "")
	_satellite(box_att, "In attesa", attesa_dadi, Color("#9e8357"), true, "")
	_satellite(box_fuori, "Fuori gioco", fuori, Color("#7a2a1e"), true, "tornano a fine scambio" if not fuori.is_empty() else "")
	# frecce del ciclo
	var cf := Color("#c9a35a")
	var a1 := centro + Vector2.from_angle(deg_to_rad(-38)) * (raggio + 4)
	_freccia(a1, Vector2(box_tok.position.x - 2, box_tok.get_center().y), cf, "azione")
	_freccia(Vector2(box_tok.get_center().x, box_tok.end.y + 1), Vector2(box_att.get_center().x, box_att.position.y - 1), cf, "sblocco", true)
	var a3 := centro + Vector2.from_angle(deg_to_rad(8)) * (raggio + 4)
	_freccia(Vector2(box_att.position.x - 2, box_att.get_center().y), a3, cf, "recupero")
	var a4 := centro + Vector2.from_angle(deg_to_rad(48)) * (raggio + 4)
	_freccia(a4, Vector2(box_fuori.position.x - 2, box_fuori.get_center().y), Color("#a0483a"), "stordito")
	var y := maxf(centro.y + raggio + 14.0, box_fuori.end.y + 10.0)
	# sotto il cerchio: dadi preparati e conservati (si toccano)
	var gruppi := [["Preparati", motore.dadi_di(giocatore, "mano"), true], ["Conservati", motore.dadi_di(giocatore, "conservato"), not scegli_mucchio]]
	for k in gruppi.size():
		var lista: Array = gruppi[k][1]
		if lista.is_empty():
			continue
		Disegno.testo(self, Vector2(8, y + 14), "%s (%d)" % [gruppi[k][0], lista.size()], 13, Disegno.PERGAMENA.darkened(0.15), Disegno.font_titolo(), w - 16)
		y += 20
		var x := 8.0
		for d in lista:
			if x + D * 0.8 > w - 4:
				x = 8.0
				y += D * 0.8 + 5
			var rr := Rect2(x, y, D * 0.8, D * 0.8)
			_tutti[d["id"]] = rr
			if not in_volo.has(d["id"]):
				Disegno.dado(self, rr, d["col"], d["v"], d["st"], selezionati.has(d["id"]))
			if gruppi[k][2]:
				_rect[d["id"]] = rr
			x += D * 0.8 + 5
		y += D * 0.8 + 8
	if absf(custom_minimum_size.y - y) > 1.0:
		custom_minimum_size.y = y

## Una zona intorno al mucchio, con i suoi dadi in piccolo.
func _satellite(r: Rect2, nome: String, lista: Array, bordo: Color, registra: bool, nota: String) -> void:
	draw_style_box(Disegno.stile(Color(0.08, 0.065, 0.05, 0.85), bordo, 8, 1), r)
	Disegno.testo(self, r.position + Vector2(6, 15), "%s (%d)" % [nome, lista.size()], 12, Disegno.PERGAMENA.darkened(0.1), Disegno.font_titolo(), r.size.x - 10)
	var dm := clampf((r.size.y - 26.0) * 0.62, 12.0, 22.0)
	var x := r.position.x + 6
	var y := r.position.y + 21
	var ordinati := lista.duplicate()
	ordinati.sort_custom(func(a, b): return Motore.COLORI.find(a["col"]) < Motore.COLORI.find(b["col"]))
	for d in ordinati:
		if x + dm > r.end.x - 4:
			x = r.position.x + 6
			y += dm + 3
		if y + dm > r.end.y - 2:
			break
		var rr := Rect2(x, y, dm, dm)
		if registra:
			_tutti[d["id"]] = rr
		if not in_volo.has(d["id"]):
			Disegno.dado(self, rr, d["col"], d["v"], "bloccato" if nome != "Sui token" else "usato")
		x += dm + 3
	if nota != "" and lista.size() <= 4:
		Disegno.testo(self, Vector2(r.position.x + 6, r.end.y - 5), nota, 10, Disegno.PERGAMENA.darkened(0.3), null, r.size.x - 10)

## Freccia del ciclo dei dadi, con una parola accanto.
func _freccia(da: Vector2, a: Vector2, col: Color, testo: String, verticale := false) -> void:
	var dirz := (a - da).normalized()
	var fine := a - dirz * 2
	draw_line(da, fine - dirz * 7, col, 2.0, true)
	var lat := Vector2(-dirz.y, dirz.x)
	draw_colored_polygon(PackedVector2Array([fine, fine - dirz * 9 + lat * 5, fine - dirz * 9 - lat * 5]), col)
	var mezzo := (da + a) * 0.5
	if verticale:
		Disegno.testo(self, mezzo + Vector2(6, 4), testo, 10, col, Disegno.font_titolo(), 70)
	else:
		Disegno.testo(self, mezzo + Vector2(-26, -5), testo, 10, col, Disegno.font_titolo(), 60, HORIZONTAL_ALIGNMENT_CENTER)

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
