class_name CartaToken
extends Control
## Un token della scheda personaggio, disegnato a mano: intestazione, dadi che porta nel mucchio,
## e uno spazio per ogni azione con gli alloggiamenti dei dadi. I segreti dell'avversario
## restano coperti finché non si rivelano.

signal slot_premuto(tok: String, sid: String)
signal carta_premuta(tok: String)
signal rimuovi(tok: String)
signal livello(tok: String, delta: int)
signal dettaglio(tok: String)

const W := 256.0
const SOCK := 34.0
const SOCKC := 24.0            # alloggi nella versione compatta (a corpo 11; crescono col testo)

var tok: Dictionary = {}
var lv := 1
var modo := "catalogo"        # catalogo, scheda, gioco
var motore: Motore = null
var giocatore := 0
var evidenzia: Dictionary = {} # sid -> true (usabile) / false (no)
var disattivo := false         # nel catalogo: non entra nel budget o già preso
var scelta_spazi: Dictionary = {} # sid -> 0 (selezionabile) / 1 (scelto)
var coperta := false           # segreto dell'avversario non ancora rivelato
var in_volo: Dictionary = {}   # id dei dadi ancora in volo verso questo token: non si disegnano
# versione compatta, in battaglia: tutte le carte devono stare sullo schermo senza scorrere
var compatta := false
var larg := W
var fs := 11                   # corpo del testo delle regole
var righe := 0                 # righe di testo per spazio (0 = tutte)

var _rect_slot := {}
var _rect_btn := {}
var _premuto := Vector2.ZERO
var _h := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE

func imposta(t: Dictionary, livello_: int = 1, modo_: String = "catalogo") -> void:
	tok = t
	lv = clampi(livello_, 1, t["livelli"].size()) if t.has("livelli") else livello_
	modo = modo_
	_ricalcola()
	queue_redraw()

## Dadi che il token mette nel mucchio: [[colore, quanti], ...]
func dadi_prodotti() -> Array:
	var out := []
	if tok.has("livelli"):
		out.append([tok["colore"], int(tok["livelli"][clampi(lv, 1, tok["livelli"].size()) - 1]["dadi"])])
	for c in tok.get("produce", {}):
		out.append([c, int(tok["produce"][c])])
	return out

func _alloggi(sl: Dictionary) -> Array:
	var n := int(sl.get("capienza", 0))
	if n == 0:
		return sl["dadi"]
	var out := []
	for i in n:
		out.append(sl["dadi"][0])
	return out

func _ricalcola() -> void:
	_rect_slot.clear()
	_rect_btn.clear()
	if compatta:
		_ricalcola_compatta()
		return
	var y := 44.0
	if coperta:
		_h = 150.0
		custom_minimum_size = Vector2(W, _h)
		size = custom_minimum_size
		return
	if not dadi_prodotti().is_empty():
		y += 30.0
	var info := _testo_passivo()
	if info != "":
		y += Disegno.altezza_testo(info, 15, W - 20) + 6
	for sl in tok.get("slot", []):
		var n: int = _alloggi(sl).size()
		var sw := mini(n, 4) * (SOCK + 4)
		var th := Disegno.altezza_testo(sl["testo"], 14, W - 24 - sw - _largo_esagono(sl))
		var extra := 18.0 if sl["tipo"] in ["contatore", "segreto"] or sl.has("capienza") else 0.0
		var h := 26.0 + maxf(SOCK, th) + 8 + extra
		_rect_slot[sl["id"]] = Rect2(6, y, W - 12, h)
		y += h + 4
	if modo == "catalogo":
		if Illustrazioni.ha(tok["id"]):
			_rect_btn["aggiungi"] = Rect2(10, y + 2, W - 104, 30)
			_rect_btn["vedi"] = Rect2(W - 88, y + 2, 78, 30)
		else:
			_rect_btn["aggiungi"] = Rect2(10, y + 2, W - 20, 30)
		y += 36
	if modo == "scheda" and not tok.has("caratteristica"):
		_rect_btn["rimuovi"] = Rect2(W - 30, 8, 22, 22)
		if tok.has("livelli") and tok["livelli"].size() > 1:
			_rect_btn["meno"] = Rect2(W - 66, 47, 24, 24)
			_rect_btn["piu"] = Rect2(W - 36, 47, 24, 24)
	_h = y + 6
	custom_minimum_size = Vector2(W, _h)
	size = custom_minimum_size

func _k() -> float:
	return fs / 11.0

func _sc() -> float:
	return SOCKC * _k()

func _cols_c(n: int) -> int:
	return mini(n, 3)

## Lato della miniatura dell'azione nella versione compatta (0 se l'azione non ha illustrazione).
func _mini(sl: Dictionary) -> float:
	if Illustrazioni.azione(tok["id"], sl["id"]) == null:
		return 0.0
	return round(30.0 * _k())

func _ricalcola_compatta() -> void:
	var k := _k()
	var y := 22.0 * k
	_rect_btn["dettaglio"] = Rect2(0, 0, larg, 22.0 * k)
	if coperta:
		_h = 46.0 * k
	else:
		for sl in tok.get("slot", []):
			var n: int = _alloggi(sl).size()
			var sw := _cols_c(n) * (_sc() + 2) + 6
			var mi := _mini(sl)
			var tw := larg - 14 - sw - (22.0 * k if sl.has("esagono") else 0.0) - (mi + 3.0 if mi > 0 else 0.0)
			var th := _alt_testo(_testo_compatto(sl), tw)
			var hs := _sc() + 6 if n <= 3 else _sc() * 2 + 8
			var h := maxf(maxf(hs, mi + 6), 15.0 * k + th + 4)
			_rect_slot[sl["id"]] = Rect2(3, y, larg - 6, h)
			y += h + 2
		_h = y + 2
	custom_minimum_size = Vector2(larg, _h)
	size = custom_minimum_size

## Regola dello spazio, con davanti il tipo quando non lo dice già (Reazione, Supporto, Libera...).
func _testo_compatto(sl: Dictionary) -> String:
	var t: String = sl["testo"]
	if sl["tipo"] == "azione":
		return t
	var nome_tipo: String = String(TIPI_C.get(sl["tipo"], ["AZIONE"])[0]).capitalize()
	if t.to_lower().begins_with(nome_tipo.to_lower().left(5)):
		return t
	return nome_tipo + ". " + t

func _alt_testo(t: String, w: float) -> float:
	var h := Disegno.altezza_testo(t, fs, w)
	if righe > 0:
		h = minf(h, righe * Disegno.font_testo().get_height(fs))
	return h

## Rettangolo dell'alloggio i-esimo dentro lo spazio r (coordinate della carta).
func _rect_sock(sl: Dictionary, r: Rect2, i: int) -> Rect2:
	var n: int = _alloggi(sl).size()
	if compatta:
		var c := _cols_c(n)
		var q := _sc()
		var mi := _mini(sl)
		var ox := mi + 3.0 if mi > 0 else 0.0
		return Rect2(r.position.x + 4 + ox + (i % c) * (q + 2), r.position.y + 3 + (i / c) * (q + 2), q, q)
	var cols := mini(n, 4)
	return Rect2(r.position.x + 6 + (i % cols) * (SOCK + 4) + (i / cols) * 6, r.position.y + 26 + (i / cols) * 6, SOCK, SOCK)

func _testo_passivo() -> String:
	var parti := []
	if tok.has("testo"):
		parti.append(tok["testo"])
	if tok.has("livelli"):
		var L: Dictionary = tok["livelli"][clampi(lv, 1, tok["livelli"].size()) - 1]
		if L.has("vita"):
			parti.append("+%d ferite massime." % L["vita"])
		if L.has("iniziativa"):
			parti.append("+%d all'iniziativa." % L["iniziativa"])
		if L.has("recupero"):
			parti.append("Recupero +%d." % L["recupero"])
		if tok["slot"].is_empty() and parti.is_empty():
			parti.append("Solo dadi per il mucchio.")
	return " ".join(parti)

func costo() -> int:
	return Motore.costo_token(tok, lv)

func _draw() -> void:
	if tok.is_empty():
		return
	var cc: Color = Disegno.CATEGORIE.get(tok["categoria"], Color.GRAY)
	if tok.has("caratteristica"):
		cc = Disegno.colore(tok["caratteristica"]).darkened(0.35)
	if compatta:
		_draw_compatta(cc)
		return
	if coperta:
		var dorso := Disegno.stile(Color("#2b2438"), Color("#8a7ab0"), 10, 3)
		draw_style_box(dorso, Rect2(0, 0, W, _h))
		for i in 5:
			draw_arc(Vector2(W / 2, _h / 2), 18.0 + i * 12, 0, TAU, 40, Color(0.7, 0.6, 0.9, 0.25), 2)
		Disegno.testo(self, Vector2(0, 36), "SEGRETO", 18, Color("#d8cff0"), Disegno.font_titolo(), W, HORIZONTAL_ALIGNMENT_CENTER)
		Disegno.testo(self, Vector2(0, _h / 2 + 12), "?", 44, Color("#d8cff0"), Disegno.font_titolo(), W, HORIZONTAL_ALIGNMENT_CENTER)
		var carico := false
		if motore != null:
			for k in motore.s["g"][giocatore]["armati"]:
				if k.begins_with(tok["id"] + "/"):
					carico = true
		Disegno.testo(self, Vector2(0, _h - 16), "carico" if carico else "non carico", 14, Color("#d8cff0"), null, W, HORIZONTAL_ALIGNMENT_CENTER)
		return
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
	if tok.has("livelli") and tok["livelli"].size() > 1:
		nome += " " + ["I", "II", "III"][lv - 1]
	var larg_nome := W - 70 if modo == "scheda" else W - 58
	# i nomi lunghi si rimpiccioliscono invece di essere tagliati
	var fs := 17
	var ft := Disegno.font_titolo()
	while fs > 12 and ft.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > larg_nome:
		fs -= 1
	Disegno.testo(self, Vector2(10, 21), nome, fs, Color.WHITE, ft, larg_nome)
	var sotto: String = Disegno.NOME_CATEGORIA.get(tok["categoria"], "")
	if tok.has("caratteristica"):
		sotto = "Caratteristica: " + String(Motore.NOMI_CARATTERISTICA.get(tok["caratteristica"], ""))
	Disegno.testo(self, Vector2(10, 35), sotto, 12, Color(1, 1, 1, 0.8))
	var cpos := Vector2(W - 22, 21) if modo != "scheda" else Vector2(W - 50, 21)
	draw_circle(cpos, 14, Color("#2a1f17"))
	draw_arc(cpos, 14, 0, TAU, 24, Disegno.ORO, 2)
	Disegno.testo(self, cpos + Vector2(-14, 6), str(costo()), 16, Disegno.ORO, Disegno.font_titolo(), 28, HORIZONTAL_ALIGNMENT_CENTER)
	if _rect_btn.has("rimuovi"):
		var r: Rect2 = _rect_btn["rimuovi"]
		draw_circle(r.get_center(), 11, Color("#5a1d16"))
		Disegno.icona(self, "croce", r.grow(-4), Color.WHITE, 2.5)
	var y := 44.0
	var prod := dadi_prodotti()
	if not prod.is_empty():
		Disegno.testo(self, Vector2(10, y + 19), "Dadi:", 15, Disegno.INCHIOSTRO)
		var x := 54.0
		for pc in prod:
			for i in int(pc[1]):
				if x < W - 80:
					Disegno.dado(self, Rect2(x, y + 2, 24, 24), pc[0], 6 if i == 0 else 4)
				x += 28
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
	for sl in tok.get("slot", []):
		_disegna_spazio(sl)
		if evidenzia.get(sl["id"], null) == false:
			var sbiadito := Disegno.PERGAMENA
			sbiadito.a = 0.45
			draw_rect(_rect_slot[sl["id"]], sbiadito)
	if _rect_btn.has("aggiungi"):
		var r: Rect2 = _rect_btn["aggiungi"]
		var c := Color("#3a2a1c") if not disattivo else Color("#8f8576")
		draw_style_box(Disegno.stile(c, Disegno.ORO if not disattivo else Color("#6d655b"), 6, 2), r)
		Disegno.icona(self, "piu", Rect2(r.position.x + 8, r.position.y + 7, 16, 16), Color.WHITE, 2.5)
		Disegno.testo(self, Vector2(r.position.x + 30, r.position.y + 21), "Aggiungi alla scheda" if r.size.x > 200 else "Aggiungi", 15, Color.WHITE, Disegno.font_titolo(), r.size.x - 36)
	if _rect_btn.has("vedi"):
		var rv: Rect2 = _rect_btn["vedi"]
		draw_style_box(Disegno.stile(Color("#4a3a26"), Disegno.ORO, 6, 2), rv)
		Disegno.testo(self, Vector2(rv.position.x + 14, rv.position.y + 21), "Carta", 15, Color.WHITE, Disegno.font_titolo(), rv.size.x - 16)

func _disegna_spazio(sl: Dictionary) -> void:
	var r: Rect2 = _rect_slot[sl["id"]]
	var ev = evidenzia.get(sl["id"], null)
	var key: String = tok["id"] + "/" + sl["id"]
	var occ: Array = []
	var g: Dictionary = {}
	if motore != null and modo == "gioco":
		g = motore.s["g"][giocatore]
		occ = g["occupati"].get(key, [])
	var pieno: bool = not occ.is_empty() and (int(sl.get("capienza", 0)) == 0 or occ.size() >= int(sl.get("capienza", 0)))
	var carico: bool = not g.is_empty() and g["carichi"].has(key)
	var armato: bool = not g.is_empty() and g["armati"].has(key)
	var disarmato: bool = not g.is_empty() and g["disarmati"].has(key)
	var sc = scelta_spazi.get(sl["id"], null)
	var bg := Color(0, 0, 0, 0.06)
	var bordo := Color(0, 0, 0, 0.15)
	var spess := 1
	if sc != null:
		bg = Color("#9fd18a") if sc == 1 else Color("#f7d77a")
		bg.a = 0.7
		bordo = Color("#2f7a2a") if sc == 1 else Color("#b07d1f")
		spess = 3
	elif carico:
		bg = Color("#e8a64a")
		bg.a = 0.6
		bordo = Color("#9a3324")
		spess = 3
	elif pieno or disarmato:
		bg = Color(0.25, 0.2, 0.15, 0.32)
	elif ev == true:
		bg = Color("#f7d77a")
		bg.a = 0.55
		bordo = Color("#b07d1f")
		spess = 2
	elif ev == false:
		bg = Color(0.2, 0.16, 0.12, 0.28)
	draw_style_box(Disegno.stile(bg, bordo, 6, spess), r)
	var tag := "AZIONE"
	var tagc := Color("#5a4630")
	match sl["tipo"]:
		"reazione":
			tag = "REAZIONE"
			tagc = Color("#2f5d8a")
		"supporto_attacco", "supporto_difesa":
			tag = "SUPPORTO"
			tagc = Color("#7a4a8a")
		"libera":
			tag = "LIBERA"
			tagc = Color("#2f7a4a")
		"segreto":
			tag = "SEGRETO"
			tagc = Color("#3d3550")
		"contatore":
			tag = "CONTATORE"
			tagc = Color("#8a5a1a")
	if sl.get("azzardo", false):
		tag = "AZZARDO"
		tagc = Color("#9a3324")
	var fnt := Disegno.font_titolo()
	var tw := fnt.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_style_box(Disegno.stile(tagc, tagc, 4, 1), Rect2(r.end.x - tw - 14, r.position.y + 5, tw + 10, 17))
	Disegno.testo(self, Vector2(r.end.x - tw - 9, r.position.y + 18), tag, 11, Color.WHITE, fnt)
	Disegno.testo(self, Vector2(r.position.x + 6, r.position.y + 19), sl["nome"], 15, Disegno.INCHIOSTRO, fnt, r.size.x - tw - 26)
	var all := _alloggi(sl)
	var n: int = all.size()
	var cols := mini(n, 4)
	for i in n:
		Disegno.alloggio(self, _rect_sock(sl, r, i), all[i])
	for i in occ.size():
		if in_volo.has(occ[i]):
			continue
		var d := motore.dado(giocatore, occ[i])
		Disegno.dado(self, _rect_sock(sl, r, i), d["col"], d["v"], "usato")
	var sw := cols * (SOCK + 4)
	var ew := _largo_esagono(sl)
	if ew > 0:
		_disegna_esagono(sl, key, g, Vector2(r.end.x - 24, r.position.y + 46))
	if pieno and not armato and not carico and not (not g.is_empty() and g["guardie"].has(key)):
		Disegno.testo_a_capo(self, Vector2(r.position.x + 10 + sw, r.position.y + 38), "Occupato: si riusa dopo averlo liberato.", 14, Color("#7a2a1e"), r.size.x - 16 - sw)
	elif disarmato:
		Disegno.testo_a_capo(self, Vector2(r.position.x + 10 + sw, r.position.y + 38), "Disarmato fino a fine scambio.", 14, Color("#7a2a1e"), r.size.x - 16 - sw)
	else:
		Disegno.testo_a_capo(self, Vector2(r.position.x + 10 + sw, r.position.y + 38), sl["testo"], 14, Disegno.INCHIOSTRO, r.size.x - 16 - sw - ew)
	var stato := ""
	if sl["tipo"] == "contatore":
		var somma := 0
		for id in occ:
			somma += int(motore.dado(giocatore, id)["v"])
		stato = "CARICO: toccalo per scaricarlo" if carico else "Somma %d su %d" % [somma, int(sl.get("soglia", 10))]
	elif sl["tipo"] == "segreto":
		stato = "Carico, in attesa" if armato else "Non carico"
	elif sl.has("capienza"):
		stato = "%d su %d dadi" % [occ.size(), int(sl["capienza"])]
	if stato != "" and modo == "gioco":
		Disegno.testo(self, Vector2(r.position.x + 8, r.end.y - 6), stato, 13, Color("#5a3a10"), Disegno.font_titolo(), r.size.x - 16)

## Versione compatta: intestazione sottile, alloggi piccoli a sinistra, nome, tipo e regola in corpo minore.
func _draw_compatta(cc: Color) -> void:
	draw_style_box(Disegno.stile(Disegno.PERGAMENA, cc.darkened(0.3), 6, 2), Rect2(0, 0, larg, _h))
	var testa := StyleBoxFlat.new()
	testa.bg_color = cc
	testa.corner_radius_top_left = 5
	testa.corner_radius_top_right = 5
	var k := _k()
	draw_style_box(testa, Rect2(1, 1, larg - 2, 20 * k))
	var ft := Disegno.font_titolo()
	var nome: String = tok["nome"]
	var fn := int(round(12 * k))
	while fn > 9 and ft.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, fn).x > larg - 12:
		fn -= 1
	Disegno.testo(self, Vector2(6, 15 * k), nome, fn, Color.WHITE, ft, larg - 10)
	if coperta:
		Disegno.testo(self, Vector2(0, 38 * k), "Segreto coperto", int(12 * k), Disegno.INCHIOSTRO, ft, larg, HORIZONTAL_ALIGNMENT_CENTER)
		return
	for sl in tok.get("slot", []):
		_disegna_spazio_c(sl)
		if evidenzia.get(sl["id"], null) == false:
			var sbiadito := Disegno.PERGAMENA
			sbiadito.a = 0.45
			draw_rect(_rect_slot[sl["id"]], sbiadito)

const TIPI_C := {"azione": ["AZIONE", "#5a4630"], "reazione": ["REAZIONE", "#2f5d8a"], "supporto_attacco": ["SUPPORTO", "#7a4a8a"],
	"supporto_difesa": ["SUPPORTO", "#7a4a8a"], "libera": ["LIBERA", "#2f7a4a"], "segreto": ["SEGRETO", "#3d3550"], "contatore": ["CONTATORE", "#8a5a1a"]}

func _disegna_spazio_c(sl: Dictionary) -> void:
	var r: Rect2 = _rect_slot[sl["id"]]
	var ev = evidenzia.get(sl["id"], null)
	var key: String = tok["id"] + "/" + sl["id"]
	var occ: Array = []
	var g: Dictionary = {}
	if motore != null:
		g = motore.s["g"][giocatore]
		occ = g["occupati"].get(key, [])
	var pieno: bool = not occ.is_empty() and (int(sl.get("capienza", 0)) == 0 or occ.size() >= int(sl.get("capienza", 0)))
	var carico: bool = not g.is_empty() and g["carichi"].has(key)
	var disarmato: bool = not g.is_empty() and g["disarmati"].has(key)
	var guardia: bool = not g.is_empty() and g["guardie"].has(key)
	var sc = scelta_spazi.get(sl["id"], null)
	var bg := Color(0, 0, 0, 0.06)
	var bordo := Color(0, 0, 0, 0.15)
	var spess := 1
	if sc != null:
		bg = Color("#9fd18a") if sc == 1 else Color("#f7d77a")
		bg.a = 0.7
		bordo = Color("#2f7a2a") if sc == 1 else Color("#b07d1f")
		spess = 2
	elif carico:
		bg = Color("#e8a64a")
		bg.a = 0.6
		bordo = Color("#9a3324")
		spess = 2
	elif pieno or disarmato:
		bg = Color(0.25, 0.2, 0.15, 0.3)
	elif ev == true:
		bg = Color("#f7d77a")
		bg.a = 0.6
		bordo = Color("#b07d1f")
		spess = 2
	draw_style_box(Disegno.stile(bg, bordo, 4, spess), r)
	var mi := _mini(sl)
	if mi > 0:
		var mr := Rect2(r.position.x + 3, r.position.y + 3, mi, mi)
		draw_texture_rect(Illustrazioni.azione(tok["id"], sl["id"]), mr, false, Color(1, 1, 1, 0.55) if (pieno or disarmato) else Color.WHITE)
		draw_rect(mr, Color(0.36, 0.25, 0.16), false, 1.0)
	var all := _alloggi(sl)
	for i in all.size():
		Disegno.alloggio(self, _rect_sock(sl, r, i), all[i])
	for i in occ.size():
		if in_volo.has(occ[i]):
			continue
		var d := motore.dado(giocatore, occ[i])
		Disegno.dado(self, _rect_sock(sl, r, i), d["col"], d["v"], "usato")
	var k := _k()
	var x0 := r.position.x + 4 + (mi + 3.0 if mi > 0 else 0.0) + _cols_c(all.size()) * (_sc() + 2) + 2
	var tipo: Array = TIPI_C.get(sl["tipo"], ["AZIONE", "#5a4630"])
	var tag: String = "AZZARDO" if sl.get("azzardo", false) else tipo[0]
	var tagc := Color("#9a3324") if sl.get("azzardo", false) else Color(tipo[1])
	var ft := Disegno.font_titolo()
	# il tipo è una striscia colorata sul bordo destro dello spazio (il nome si legge per intero)
	draw_rect(Rect2(r.end.x - 5, r.position.y + 2, 3, r.size.y - 4), tagc)
	var ln := r.end.x - x0 - 10
	var fnome := float(fs)
	while fnome > 8.0 and ft.get_string_size(sl["nome"], HORIZONTAL_ALIGNMENT_LEFT, -1, int(fnome)).x > ln:
		fnome -= 0.5
	Disegno.testo(self, Vector2(x0, r.position.y + 12 * k), sl["nome"], int(fnome), Disegno.INCHIOSTRO, ft, ln)
	var ew := 22.0 * k if sl.has("esagono") else 0.0
	if ew > 0:
		_disegna_esagono(sl, key, g, Vector2(r.end.x - 11 * k, r.end.y - 12 * k), 9.0 * k)
	var tw2 := r.end.x - x0 - 8 - ew
	var testo: String = _testo_compatto(sl)
	var colore := Disegno.INCHIOSTRO
	if pieno and not guardia and not carico:
		testo = "Occupato: si riusa dopo averlo liberato."
		colore = Color("#7a2a1e")
	elif disarmato:
		testo = "Disarmato fino a fine scambio."
		colore = Color("#7a2a1e")
	elif sl["tipo"] == "contatore":
		var somma := 0
		for id in occ:
			somma += int(motore.dado(giocatore, id)["v"])
		testo = ("CARICO: toccalo per scaricarlo. " if carico else "Somma %d su %d. " % [somma, int(sl.get("soglia", 10))]) + testo
	Disegno.testo_a_capo(self, Vector2(x0, r.position.y + 14 * k + fs), testo, fs, colore, tw2, righe if righe > 0 else -1)

## Rettangolo (in coordinate dello schermo) dell'alloggio i-esimo di uno spazio.
func rect_alloggio(sid: String, i: int) -> Rect2:
	if not _rect_slot.has(sid):
		return Rect2()
	var sl := {}
	for x in tok.get("slot", []):
		if x["id"] == sid:
			sl = x
	var r: Rect2 = _rect_slot[sid]
	var lr := _rect_sock(sl, r, i)
	var t := get_global_transform()
	return Rect2(t * lr.position, lr.size * t.get_scale())

static func _largo_esagono(sl: Dictionary) -> float:
	return 44.0 if sl.has("esagono") else 0.0

## Esagono disegnato sul token: il lato pieno in oro, poi -1, -2, -3 sbiadendo.
## In gioco, se il dado è in guardia, il lato pieno è quello scelto e al centro c'è il valore.
func _disegna_esagono(sl: Dictionary, key: String, g: Dictionary, c: Vector2, raggio := 17.0) -> void:
	var pieno := 0
	var valore := ""
	if not g.is_empty() and g["guardie"].has(key):
		pieno = int(g["guardie"][key]["lato"])
		valore = str(motore.valore_guardia(giocatore, key))
	var colori := [Disegno.ORO, Color("#c9852f"), Color("#a07a52"), Color("#8c8070")]
	draw_colored_polygon(_punti_esagono(c, raggio), Color(0, 0, 0, 0.08))
	for k in 6:
		var a := deg_to_rad(-90.0 - 60.0 * k)
		var p1 := c + Vector2.from_angle(a - PI / 6) * raggio
		var p2 := c + Vector2.from_angle(a + PI / 6) * raggio
		var sc := Motore.scarto_lati(k, pieno)
		var k2 := raggio / 17.0
		draw_line(p1, p2, colori[sc], (5.0 if sc == 0 else 2.5 - 0.4 * sc) * k2)
	var q := raggio / 17.0
	if valore != "":
		Disegno.testo(self, c + Vector2(-12, 6) * q, valore, int(16 * q), Disegno.INCHIOSTRO, Disegno.font_titolo(), 24 * q, HORIZONTAL_ALIGNMENT_CENTER)
	elif sl.get("esagono", "") == "mira":
		draw_line(c + Vector2(0, 7) * q, c + Vector2(0, -8) * q, Disegno.INCHIOSTRO, 2.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12) * q, c + Vector2(-5, -5) * q, c + Vector2(5, -5) * q]), Disegno.INCHIOSTRO)
	else:
		draw_arc(c, 6.0 * q, PI, TAU, 12, Disegno.INCHIOSTRO, 2.0)

static func _punti_esagono(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(c + Vector2.from_angle(deg_to_rad(60.0 * i)) * r)
	return pts

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_premuto = e.position
		elif e.position.distance_to(_premuto) < 14:
			_clic(e.position)

func _clic(p: Vector2) -> void:
	if coperta:
		return
	for k in _rect_btn:
		if _rect_btn[k].grow(4).has_point(p):
			match k:
				"aggiungi":
					if not disattivo:
						carta_premuta.emit(tok["id"])
				"rimuovi":
					rimuovi.emit(tok["id"])
				"dettaglio", "vedi":
					dettaglio.emit(tok["id"])
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
