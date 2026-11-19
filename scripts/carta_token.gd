class_name CartaToken
extends Control
## Un token della scheda personaggio, disegnato a mano: intestazione, dadi forniti,
## e uno spazio per ogni azione con gli alloggiamenti dei dadi.

signal slot_premuto(tok: String, sid: String)
signal carta_premuta(tok: String)
signal rimuovi(tok: String)
signal livello(tok: String, delta: int)

const W := 256.0
const SOCK := 34.0

var tok: Dictionary = {}
var lv := 1
var modo := "catalogo"        # catalogo, scheda, gioco
var motore: Motore = null
var giocatore := 0
var evidenzia: Dictionary = {} # sid -> true (usabile) / false (no)
var disattivo := false         # nel catalogo: non entra nel budget o già preso

var _rect_slot := {}
var _rect_btn := {}
var _premuto := Vector2.ZERO
var _h := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE

func imposta(t: Dictionary, livello_: int = 1, modo_: String = "catalogo") -> void:
	tok = t
	lv = livello_
	modo = modo_
	_ricalcola()
	queue_redraw()

func _ricalcola() -> void:
	_rect_slot.clear()
	_rect_btn.clear()
	var y := 44.0
	if tok.has("livelli"):
		y += 30.0
	var info := _testo_passivo()
	if info != "":
		y += Disegno.altezza_testo(info, 15, W - 20) + 6
	for sl in tok.get("slot", []):
		var n: int = sl["dadi"].size()
		var sw := n * (SOCK + 4)
		var th := Disegno.altezza_testo(sl["testo"], 14, W - 24 - sw)
		var h := 26.0 + maxf(SOCK, th) + 8
		_rect_slot[sl["id"]] = Rect2(6, y, W - 12, h)
		y += h + 4
	if modo == "catalogo":
		_rect_btn["aggiungi"] = Rect2(10, y + 2, W - 20, 30)
		y += 36
	if modo == "scheda":
		_rect_btn["rimuovi"] = Rect2(W - 30, 8, 22, 22)
		if tok.has("livelli"):
			_rect_btn["meno"] = Rect2(W - 66, 47, 24, 24)
			_rect_btn["piu"] = Rect2(W - 36, 47, 24, 24)
	_h = y + 6
	custom_minimum_size = Vector2(W, _h)
	size = custom_minimum_size

func _testo_passivo() -> String:
	var parti := []
	if tok.has("testo"):
		parti.append(tok["testo"])
	if tok.has("livelli"):
		var L: Dictionary = tok["livelli"][lv - 1]
		if L.has("vita"):
			parti.append("+%d ferite massime." % L["vita"])
	return " ".join(parti)

func costo() -> int:
	return Motore.costo_token(tok, lv)

func _draw() -> void:
	if tok.is_empty():
		return
	var cc: Color = Disegno.CATEGORIE.get(tok["categoria"], Color.GRAY)
	var corpo := Disegno.stile(Disegno.PERGAMENA, cc.darkened(0.3), 10, 3)
	if disattivo:
		corpo.bg_color = Disegno.PERGAMENA.darkened(0.35)
	draw_style_box(corpo, Rect2(0, 0, W, _h))
	var testa := StyleBoxFlat.new()
	testa.bg_color = cc
	testa.corner_radius_top_left = 9
	testa.corner_radius_top_right = 9
	draw_style_box(testa, Rect2(2, 2, W - 4, 38))
	var nome: String = tok["nome"]
	if tok.has("livelli"):
		nome += " " + ["I", "II", "III"][lv - 1]
	var larg_nome := W - 70 if modo == "scheda" else W - 58
	Disegno.testo(self, Vector2(10, 21), nome, 17, Color.WHITE, Disegno.font_titolo(), larg_nome)
	Disegno.testo(self, Vector2(10, 35), Disegno.NOME_CATEGORIA.get(tok["categoria"], ""), 12, Color(1, 1, 1, 0.8))
	# costo
	var cpos := Vector2(W - 22, 21) if modo != "scheda" else Vector2(W - 50, 21)
	draw_circle(cpos, 14, Color("#2a1f17"))
	draw_arc(cpos, 14, 0, TAU, 24, Disegno.ORO, 2)
	Disegno.testo(self, cpos + Vector2(-14, 6), str(costo()), 16, Disegno.ORO, Disegno.font_titolo(), 28, HORIZONTAL_ALIGNMENT_CENTER)
	if _rect_btn.has("rimuovi"):
		var r: Rect2 = _rect_btn["rimuovi"]
		draw_circle(r.get_center(), 11, Color("#5a1d16"))
		Disegno.icona(self, "croce", r.grow(-4), Color.WHITE, 2.5)
	var y := 44.0
	if tok.has("livelli"):
		var n: int = tok["livelli"][lv - 1]["dadi"]
		Disegno.testo(self, Vector2(10, y + 19), "Dadi:", 15, Disegno.INCHIOSTRO)
		for i in n:
			Disegno.dado(self, Rect2(54 + i * 28, y + 2, 24, 24), tok["colore"], 6 if i == 0 else 4)
		for k in ["meno", "piu"]:
			if _rect_btn.has(k):
				var r: Rect2 = _rect_btn[k]
				var abil: bool = (k == "meno" and lv > 1) or (k == "piu" and lv < tok["livelli"].size())
				draw_style_box(Disegno.stile(Color("#3a2a1c") if abil else Color("#9c907c"), Disegno.ORO if abil else Color("#7d7468"), 5, 1), r)
				Disegno.icona(self, k, r.grow(-5), Color.WHITE, 2.5)
		y += 30.0
	var info := _testo_passivo()
	if info != "":
		Disegno.testo_a_capo(self, Vector2(10, y + 13), info, 15, Disegno.INCHIOSTRO.lightened(0.15), W - 20)
		y += Disegno.altezza_testo(info, 15, W - 20) + 6
	for sl in tok.get("slot", []):
		var r: Rect2 = _rect_slot[sl["id"]]
		var ev = evidenzia.get(sl["id"], null)
		var bg := Color(0, 0, 0, 0.06)
		var bordo := Color(0, 0, 0, 0.15)
		if ev == true:
			bg = Color("#f7d77a")
			bg.a = 0.55
			bordo = Color("#b07d1f")
		elif ev == false:
			bg = Color(0, 0, 0, 0.12)
		draw_style_box(Disegno.stile(bg, bordo, 6, 2 if ev == true else 1), r)
		var tag := "REAZIONE" if sl["tipo"] == "reazione" else ("AZZARDO" if sl.get("azzardo", false) else "AZIONE")
		var tagc := Color("#2f5d8a") if sl["tipo"] == "reazione" else (Color("#9a3324") if tag == "AZZARDO" else Color("#5a4630"))
		var fnt := Disegno.font_titolo()
		var tw := fnt.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_style_box(Disegno.stile(tagc, tagc, 4, 1), Rect2(r.end.x - tw - 14, r.position.y + 5, tw + 10, 17))
		Disegno.testo(self, Vector2(r.end.x - tw - 9, r.position.y + 18), tag, 11, Color.WHITE, fnt)
		Disegno.testo(self, Vector2(r.position.x + 6, r.position.y + 19), sl["nome"], 15, Disegno.INCHIOSTRO, fnt, r.size.x - tw - 26)
		var piazzati := []
		if motore != null and modo == "gioco":
			var key: String = tok["id"] + "/" + sl["id"]
			for id in motore.s["g"][giocatore]["piazzati"].get(key, []):
				piazzati.append(motore.dado(giocatore, id))
		var n: int = sl["dadi"].size()
		for i in n:
			var sr := Rect2(r.position.x + 6 + i * (SOCK + 4), r.position.y + 26, SOCK, SOCK)
			Disegno.alloggio(self, sr, sl["dadi"][i])
		for i in piazzati.size():
			var d: Dictionary = piazzati[i]
			var col := i % n
			var riga := i / n
			var sr := Rect2(r.position.x + 6 + col * (SOCK + 4) + riga * 6, r.position.y + 26 + riga * 6, SOCK, SOCK)
			Disegno.dado(self, sr, d["col"], d["v"], d["st"])
		var sw := n * (SOCK + 4)
		Disegno.testo_a_capo(self, Vector2(r.position.x + 10 + sw, r.position.y + 38), sl["testo"], 14, Disegno.INCHIOSTRO, r.size.x - 16 - sw)
	if _rect_btn.has("aggiungi"):
		var r: Rect2 = _rect_btn["aggiungi"]
		var c := Color("#3a2a1c") if not disattivo else Color("#8f8576")
		draw_style_box(Disegno.stile(c, Disegno.ORO if not disattivo else Color("#6d655b"), 6, 2), r)
		Disegno.icona(self, "piu", Rect2(r.position.x + 8, r.position.y + 7, 16, 16), Color.WHITE, 2.5)
		Disegno.testo(self, Vector2(r.position.x + 30, r.position.y + 21), "Aggiungi alla scheda", 15, Color.WHITE, Disegno.font_titolo(), r.size.x - 36)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_premuto = e.position
		elif e.position.distance_to(_premuto) < 14:
			_clic(e.position)

func _clic(p: Vector2) -> void:
	for k in _rect_btn:
		if _rect_btn[k].grow(4).has_point(p):
			match k:
				"aggiungi":
					if not disattivo:
						carta_premuta.emit(tok["id"])
				"rimuovi":
					rimuovi.emit(tok["id"])
				"meno":
					livello.emit(tok["id"], -1)
				"piu":
					livello.emit(tok["id"], 1)
			return
	for sid in _rect_slot:
		if _rect_slot[sid].has_point(p):
			slot_premuto.emit(tok["id"], sid)
			return
	if modo == "catalogo" and not disattivo:
		carta_premuta.emit(tok["id"])
