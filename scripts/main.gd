extends Node
## Combat Master: menu, officina dei personaggi, preparazione dello scontro e battaglia.

const FILE_PG := "user://personaggi.json"
const PASSO_IA := 0.6
const CASUALE := "Avventuriero casuale"

var dati: Dictionary
var cat: Dictionary
var arena: Arena3D
var ui: Control
var pagina: Control
var tema: Theme

var miei: Array = []          # personaggi salvati
var rng := RandomNumberGenerator.new()

# officina
var pg_corrente := {"nome": "Nuovo combattente", "budget": 30, "token": {}}
var cat_corrente := "attributo"
var _off_catalogo: VBoxContainer
var _off_scheda: VBoxContainer
var _off_info: Label
var _off_nome: LineEdit
var _off_budget: OptionButton
var _off_lista: VBoxContainer
var _off_codice: LineEdit
var _off_msg: Label
var _off_cat_btn := {}

# preparazione
var _prep_modo := "ia"
var _prep_scenario := 0
var _prep_scelte := [0, 1]
var _prep_opt: Array = []
var _prep_desc: Array = []
var _prep_aspetto: Array = []
var _prep_sc_btn: Array = []

# battaglia
var m: Motore
var ia := [false, true]
var _scenario: Dictionary
var _pg := []
var sel: Array = []
var attesa := {}
var mostra := 0
var mostra_avversario := false
var _stati: Array = []
var _vassoio: Vassoio
var _lati: Array = []          # per ogni combattente: vassoio dei dadi e carte della scheda
const LATO := 360
var _ll := 360.0              # larghezza delle schede ai lati, secondo lo schermo
var _verticale := false        # schermo in verticale: mappa in alto, le due schede affiancate sotto
const ALTO_MAPPA := 0.36       # in verticale, frazione di schermo per barra e mappa
var _dettaglio: Control
var _carte: Array = []
var _carte_illustrate := true   # in battaglia: carte illustrate con i dadi sulle immagini (altrimenti carte di testo)
var _diario: Label
var _diario_scroll: ScrollContainer
var _msg: Label
var _scambio: Label
var _btn := {}
var _scelte: GridContainer
var _volo: Control
var _tieni_vista := -1         # mentre i dadi volano si resta sulla scheda di chi ha giocato
var _tieni_fino := 0
var _voli := 0                 # dadi ancora in volo
var _pannelli: Array[Control] = []
var _timer_ia := 0.0
var _fine: Control
var _demo := false
var passo_ia := PASSO_IA
var spettatore := false
var a_ripetizione := false
var _attesa_ripeti := 0.0
# allenamento continuo nella modalità spettatore: campione contro sfidante
var allenamento := false
var _pesi_lato: Array = [{}, {}]
var _sfidante: Dictionary = {}
var _lato_sfidante := 1
var _sfida := {"giocate": 0, "vinte": 0, "generazioni": 0, "adottate": 0}
var _registrato := false

func _ready() -> void:
	dati = Motore.carica_dati()
	cat = dati["per_id"]
	rng.randomize()
	tema = Disegno.tema()
	arena = Arena3D.new()
	add_child(arena)
	arena.blocca_input = _su_ui
	arena.esagono_premuto.connect(_esagono)
	arena.animazioni_finite.connect(_aggiorna)
	var cl := CanvasLayer.new()
	add_child(cl)
	ui = Control.new()
	ui.theme = tema
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(ui)
	_carica_miei()
	menu()

func _su_ui(p: Vector2) -> bool:
	for c in _pannelli:
		if is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	return false

func _pulisci() -> void:
	if pagina != null:
		pagina.queue_free()
	_pannelli.clear()
	pagina = Control.new()
	pagina.set_anchors_preset(Control.PRESET_FULL_RECT)
	pagina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(pagina)
	m = null
	attesa = {}
	sel = []
	_fine = null
	_stati = []
	_carte = []

func _label(t: String, size := 19, col := Disegno.PERGAMENA, f: Font = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if f != null:
		l.add_theme_font_override("font", f)
	return l

func _bottone(t: String, cb: Callable, minw := 0.0) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(minw, 46)
	b.pressed.connect(cb)
	return b

func _pannello(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	_pannelli.append(p)
	return p

# ================================================================= menu

func menu() -> void:
	_pulisci()
	_demo_arena()
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pagina.add_child(centro)
	var pan := _pannello(centro)
	pan.add_theme_stylebox_override("panel", Disegno.stile(Color(0.07, 0.055, 0.04, 0.88), Color("#8a6a3e"), 14, 2))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(640, 0)
	pan.add_child(v)
	var t := _label("COMBAT MASTER", 56, Disegno.ORO, Disegno.font_deco())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var st := _label("Schermaglie fantasy di dadi, token e destrezza", 20, Disegno.PERGAMENA)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	v.add_child(HSeparator.new())
	v.add_child(_bottone("Gioca contro l'IA", func(): preparazione("ia"), 420))
	v.add_child(_bottone("Due giocatori sullo stesso schermo", func(): preparazione("due"), 420))
	v.add_child(_bottone("Guarda l'IA combattere", func(): preparazione("spettatore"), 420))
	v.add_child(_bottone("Officina dei personaggi", officina, 420))
	v.add_child(_bottone("Regole del gioco", regole, 420))
	var nota := _label("Prova di gioco: si combatte uno contro uno. Il multigiocatore online arriverà in seguito.", 15, Color(1, 1, 1, 0.6))
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.custom_minimum_size = Vector2(540, 0)
	nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nota)

func _demo_arena() -> void:
	var mm := Motore.new(dati)
	mm.nuova_partita(dati["personaggi"][4], dati["personaggi"][5], "fossa", 5)
	mm.s["g"][0]["pos"] = Vector2i(-1, 1)
	mm.s["g"][0]["dir"] = 0
	mm.s["g"][1]["pos"] = Vector2i(0, 1)
	mm.s["g"][1]["dir"] = 3
	arena.visible = true
	arena.costruisci(mm)
	arena.pitch = deg_to_rad(30)
	arena.distanza = 13
	arena.spostamento_v = 0.0
	arena.spostamento_h = 0.0
	arena.pivot.position = Vector3.ZERO
	arena.ruota_vista(0)
	arena.mostra_nomi(false)
	_demo = true

func _process(dt: float) -> void:
	if _demo and arena != null:
		arena.ruota_vista(dt * 0.08)
	if m != null and m.s["vinc"] >= 0 and allenamento and not _registrato:
		_registra_sfida()
	if m != null and m.s["vinc"] >= 0 and (a_ripetizione or allenamento) and not arena.occupato():
		_attesa_ripeti += dt
		if _attesa_ripeti > 3.0:
			_attesa_ripeti = 0.0
			_scontro_casuale()
		return
	if m == null or m.s["vinc"] >= 0 or arena.occupato() or passo_ia < 0:
		return
	var chi := m.chi_decide()
	if chi >= 0 and ia[chi]:
		_timer_ia += dt
		if _timer_ia >= passo_ia:
			_timer_ia = 0.0
			var op := IA.scegli(m, chi, rng, _pesi_lato[chi])
			if op.is_empty():
				return
			var prima := _istantanea(chi)
			var e := m.applica(chi, op)
			_anima_dadi(chi, prima)
			if e != "":
				push_warning("IA: " + e)
				m.applica(chi, {"t": "passa"} if m.s["fase"] == "azione" else ({"t": "risolvi"} if m.s["fase"] == "reazione" else {"t": "ferma"}))
			_dopo_applica()
	else:
		_timer_ia = 0.0

# ================================================================= regole

func regole() -> void:
	_pulisci()
	_demo_arena()
	var pan := _pannello(pagina)
	pan.set_anchors_preset(Control.PRESET_FULL_RECT)
	pan.offset_left = 120
	pan.offset_right = -120
	pan.offset_top = 40
	pan.offset_bottom = -40
	var v := VBoxContainer.new()
	pan.add_child(v)
	var testa := HBoxContainer.new()
	v.add_child(testa)
	var t := _label("Regole del gioco", 34, Disegno.ORO, Disegno.font_titolo())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	testa.add_child(t)
	testa.add_child(_bottone("Torna al menu", menu, 200))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.custom_minimum_size = Vector2(700, 0)
	rt.add_theme_font_size_override("normal_font_size", 20)
	rt.add_theme_font_size_override("bold_font_size", 24)
	rt.add_theme_font_override("bold_font", Disegno.font_titolo())
	rt.add_theme_color_override("default_color", Disegno.PERGAMENA)
	var f := FileAccess.open("res://data/regole.md", FileAccess.READ)
	var bb := ""
	for riga in f.get_as_text().split("\n"):
		if riga.begins_with("# "):
			continue
		if riga.begins_with("## "):
			bb += "\n[b][color=#e0b964]%s[/color][/b]\n" % riga.substr(3)
		elif riga.begins_with("- "):
			bb += "[indent]%s[/indent]\n" % riga.substr(2)
		else:
			bb += riga + "\n"
	rt.text = bb
	sc.add_child(rt)

# ================================================================= salvataggi

func _carica_miei() -> void:
	miei = []
	if FileAccess.file_exists(FILE_PG):
		var f := FileAccess.open(FILE_PG, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Array:
			for x in d:
				if x is Dictionary and x.has("token"):
					for k in x["token"]:
						x["token"][k] = int(x["token"][k])
					Motore.pulisci_pg(cat, x)
					miei.append(x)

func _salva_miei() -> void:
	var f := FileAccess.open(FILE_PG, FileAccess.WRITE)
	f.store_string(JSON.stringify(miei, "  "))

func tutti_personaggi() -> Array:
	var out := []
	for x in dati["personaggi"]:
		var c: Dictionary = x.duplicate(true)
		c["pronto"] = true
		out.append(c)
	for x in miei:
		out.append(x)
	return out

static func codice_di(pg: Dictionary) -> String:
	var d := {"nome": pg["nome"], "budget": pg.get("budget", 30), "token": pg["token"]}
	return "CM1-" + Marshalls.utf8_to_base64(JSON.stringify(d))

static func da_codice(c: String) -> Dictionary:
	c = c.strip_edges()
	if not c.begins_with("CM1-"):
		return {}
	var d = JSON.parse_string(Marshalls.base64_to_utf8(c.substr(4)))
	if not (d is Dictionary) or not d.has("token"):
		return {}
	for k in d["token"]:
		d["token"][k] = int(d["token"][k])
	return d

# ================================================================= officina

func officina() -> void:
	_pulisci()
	arena.visible = false
	_demo = false
	var sfondo := ColorRect.new()
	sfondo.color = Color("#17110c")
	sfondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	sfondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pagina.add_child(sfondo)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.offset_top = 12
	h.offset_right = -12
	h.offset_bottom = -12
	h.add_theme_constant_override("separation", 12)
	pagina.add_child(h)
	# --- catalogo
	var pc := _pannello(h)
	pc.custom_minimum_size = Vector2(300, 0)
	var vc := VBoxContainer.new()
	vc.add_theme_constant_override("separation", 8)
	pc.add_child(vc)
	vc.add_child(_label("Token", 26, Disegno.ORO, Disegno.font_titolo()))
	var gcat := GridContainer.new()
	gcat.columns = 2
	vc.add_child(gcat)
	_off_cat_btn.clear()
	for c in dati["categorie"]:
		# le categorie di un'espansione nascosta (armi, magie...) non hanno token visibili: niente pulsante
		if not dati["token"].any(func(t): return t["categoria"] == c["id"]):
			continue
		var b := _bottone(c["nome"], func(): _off_categoria(c["id"]), 142)
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 14)
		gcat.add_child(b)
		_off_cat_btn[c["id"]] = b
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(276, 0)
	vc.add_child(sc)
	_off_catalogo = VBoxContainer.new()
	_off_catalogo.add_theme_constant_override("separation", 10)
	sc.add_child(_off_catalogo)
	# --- scheda
	var ps := _pannello(h)
	ps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vs := VBoxContainer.new()
	vs.add_theme_constant_override("separation", 8)
	ps.add_child(vs)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 10)
	vs.add_child(r1)
	r1.add_child(_label("Scheda", 26, Disegno.ORO, Disegno.font_titolo()))
	_off_nome = LineEdit.new()
	_off_nome.custom_minimum_size = Vector2(280, 44)
	_off_nome.placeholder_text = "Nome del combattente"
	_off_nome.max_length = 28
	_off_nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_off_nome.text_changed.connect(func(t): pg_corrente["nome"] = t)
	r1.add_child(_off_nome)
	r1.add_child(_label("Budget", 18))
	_off_budget = OptionButton.new()
	_off_budget.custom_minimum_size = Vector2(170, 44)
	for sc2 in dati["scenari"]:
		_off_budget.add_item("%d punti" % sc2["budget"])
	_off_budget.item_selected.connect(func(i):
		pg_corrente["budget"] = int(dati["scenari"][i]["budget"])
		_off_aggiorna())
	r1.add_child(_off_budget)
	_off_info = _label("", 18)
	_off_info.custom_minimum_size = Vector2(600, 0)
	_off_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vs.add_child(_off_info)
	var ss := ScrollContainer.new()
	ss.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ss.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vs.add_child(ss)
	_off_scheda = VBoxContainer.new()
	_off_scheda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_off_scheda.add_theme_constant_override("separation", 10)
	ss.add_child(_off_scheda)
	_off_msg = _label("", 17, Disegno.ORO)
	_off_msg.custom_minimum_size = Vector2(600, 24)
	vs.add_child(_off_msg)
	# --- personaggi salvati
	var pr := _pannello(h)
	pr.custom_minimum_size = Vector2(300, 0)
	var vr := VBoxContainer.new()
	vr.add_theme_constant_override("separation", 8)
	pr.add_child(vr)
	vr.add_child(_label("Combattenti", 26, Disegno.ORO, Disegno.font_titolo()))
	var gb := GridContainer.new()
	gb.columns = 2
	vr.add_child(gb)
	gb.add_child(_bottone("Nuovo", _off_nuovo, 132))
	gb.add_child(_bottone("Salva", _off_salva, 132))
	gb.add_child(_bottone("Elimina", _off_elimina, 132))
	gb.add_child(_bottone("Casuale", _off_casuale, 132))
	gb.add_child(_bottone("Menu", menu, 132))
	var ls := ScrollContainer.new()
	ls.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vr.add_child(ls)
	_off_lista = VBoxContainer.new()
	_off_lista.custom_minimum_size = Vector2(270, 0)
	ls.add_child(_off_lista)
	vr.add_child(_label("Codice da condividere", 16))
	_off_codice = LineEdit.new()
	_off_codice.custom_minimum_size = Vector2(270, 42)
	_off_codice.placeholder_text = "incolla qui un codice CM1-"
	vr.add_child(_off_codice)
	var gc := GridContainer.new()
	gc.columns = 2
	vr.add_child(gc)
	gc.add_child(_bottone("Esporta", _off_esporta, 132))
	gc.add_child(_bottone("Importa", _off_importa, 132))
	_off_categoria(cat_corrente)
	_off_carica_in_editor(pg_corrente)

func _off_categoria(c: String) -> void:
	cat_corrente = c
	for k in _off_cat_btn:
		_off_cat_btn[k].button_pressed = (k == c)
	_off_aggiorna()

func _off_carica_in_editor(pg: Dictionary) -> void:
	pg_corrente = pg.duplicate(true)
	pg_corrente.erase("pronto")
	if not pg_corrente.has("budget"):
		pg_corrente["budget"] = 30
	_off_nome.text = pg_corrente["nome"]
	for i in dati["scenari"].size():
		if int(dati["scenari"][i]["budget"]) == int(pg_corrente["budget"]):
			_off_budget.select(i)
	_off_aggiorna()

func _off_aggiorna() -> void:
	for c in _off_catalogo.get_children():
		c.queue_free()
	for c in _off_scheda.get_children():
		c.queue_free()
	for c in _off_lista.get_children():
		c.queue_free()
	var costo := Motore.costo_personaggio(cat, pg_corrente)
	var budget: int = int(pg_corrente["budget"])
	var gruppo := ""
	for t in dati["token"]:
		if t["categoria"] != cat_corrente:
			continue
		if t["categoria"] == "attributo" and t.get("caratteristica", "") != gruppo:
			# le caratteristiche si scelgono una per tipo
			gruppo = t.get("caratteristica", "")
			var scelta := ""
			for id in pg_corrente["token"]:
				if cat.has(id) and cat[id].get("caratteristica", "") == gruppo:
					scelta = cat[id]["nome"]
			var tl := _label("%s: scegline una%s" % [Motore.NOMI_CARATTERISTICA.get(gruppo, gruppo), ("  (ora: %s)" % scelta) if scelta != "" else ""], 17, Disegno.colore(gruppo).lightened(0.25), Disegno.font_titolo())
			tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tl.custom_minimum_size = Vector2(260, 0)
			_off_catalogo.add_child(tl)
		var carta := CartaToken.new()
		carta.imposta(t, 1, "catalogo")
		var gia: bool = pg_corrente["token"].has(t["id"])
		var al_posto := 0
		if t["categoria"] == "attributo":
			for id in pg_corrente["token"]:
				if cat.has(id) and cat[id]["categoria"] == "attributo" and cat[id].get("caratteristica", "") == t.get("caratteristica", ""):
					al_posto += Motore.costo_token(cat[id], int(pg_corrente["token"][id]))
		carta.disattivo = gia or costo - al_posto + Motore.costo_token(t, 1) > budget
		carta.carta_premuta.connect(_off_aggiungi)
		carta.dettaglio.connect(_mostra_carta_illustrata)
		_off_catalogo.add_child(carta)
	var ordine := ["base", "attributo", "attacco", "tecnica", "arma", "mossa", "armatura", "oggetto", "talento", "magia", "segreto"]
	var ids: Array = pg_corrente["token"].keys()
	ids.sort_custom(func(a, b): return _ordine_carta(a, ordine) < _ordine_carta(b, ordine))
	# le quattro caratteristiche hanno sempre il loro posto in cima alla scheda
	_off_scheda.add_child(_label("Caratteristiche (obbligatorie, una per tipo: si cambiano dal catalogo)", 17, Disegno.ORO, Disegno.font_titolo()))
	var fc := HFlowContainer.new()
	fc.add_theme_constant_override("h_separation", 12)
	fc.add_theme_constant_override("v_separation", 12)
	_off_scheda.add_child(fc)
	for k in Motore.CARATTERISTICHE:
		var trovata := ""
		for id in ids:
			if cat[id].get("caratteristica", "") == k:
				trovata = id
		if trovata != "":
			var carta := CartaToken.new()
			carta.imposta(cat[trovata], 1, "scheda")
			fc.add_child(carta)
		else:
			var vuoto := _pannello(fc)
			vuoto.custom_minimum_size = Vector2(CartaToken.W, 120)
			vuoto.add_theme_stylebox_override("panel", Disegno.stile(Color(1, 1, 1, 0.04), Disegno.colore(k), 10, 2))
			var lv := _label("%s: manca.\nScegline una dal catalogo, categoria Caratteristiche." % Motore.NOMI_CARATTERISTICA[k], 16, Disegno.colore(k).lightened(0.3))
			lv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lv.custom_minimum_size = Vector2(CartaToken.W - 24, 0)
			vuoto.add_child(lv)
	_off_scheda.add_child(_label("Altri token (facoltativi)", 17, Disegno.ORO, Disegno.font_titolo()))
	var fa := HFlowContainer.new()
	fa.add_theme_constant_override("h_separation", 12)
	fa.add_theme_constant_override("v_separation", 12)
	_off_scheda.add_child(fa)
	var altri := 0
	for id in ids:
		if cat[id]["categoria"] == "attributo":
			continue
		altri += 1
		var carta := CartaToken.new()
		carta.imposta(cat[id], int(pg_corrente["token"][id]), "scheda")
		carta.rimuovi.connect(_off_rimuovi)
		carta.livello.connect(_off_livello)
		fa.add_child(carta)
	if altri == 0:
		var l := _label("Nessuno per ora: aggiungi armi, strategie, equipaggiamento, oggetti, talenti, magie e segreti dal catalogo a sinistra, finché il budget lo permette.", 17, Color(1, 1, 1, 0.65))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(520, 0)
		fa.add_child(l)
	var st := Motore.statistiche(cat, pg_corrente)
	var dadi := []
	for c in Motore.COLORI:
		if st["dadi"].has(c):
			dadi.append("%d %s" % [st["dadi"][c], Disegno.NOMI_COLORE[c]])
	_off_info.text = "Punti %d su %d   |   Dadi nel mucchio: %s   |   Ferite %d   |   Ritmo %d (dadi pescati)   |   Recupero %d   |   Armatura %d" % [costo, budget, ", ".join(dadi) if not dadi.is_empty() else "nessuno", st["vita"], st["ritmo"], st["recupero"], st["armatura"]]
	var probl := Motore.problemi_caratteristiche(cat, pg_corrente)
	if not probl.is_empty():
		_off_info.text += "\nCaratteristiche: serve una scheda per ognuna fra Forza, Destrezza, Tempra e Mente (%s)." % ", ".join(probl)
	elif not Generatore.valido(cat, pg_corrente):
		_off_info.text += "\nAttenzione: servono almeno 4 dadi e un attacco semplice che i tuoi dadi possano pagare."
	_off_info.add_theme_color_override("font_color", Color("#ff8a70") if costo > budget or (not ids.is_empty() and not Generatore.valido(cat, pg_corrente)) else Disegno.PERGAMENA)
	for pg in tutti_personaggi():
		var b := Button.new()
		b.text = "%s  (%d)" % [pg["nome"], Motore.costo_personaggio(cat, pg)]
		if pg.get("pronto", false):
			b.text += "  base"
		b.custom_minimum_size = Vector2(260, 42)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(func(): _off_carica_in_editor(pg))
		_off_lista.add_child(b)

func _off_aggiungi(id: String) -> void:
	var tolta := ""
	if cat[id]["categoria"] == "attributo":
		for k in pg_corrente["token"].keys():
			if cat.has(k) and cat[k]["categoria"] == "attributo" and cat[k].get("caratteristica", "") == cat[id].get("caratteristica", ""):
				tolta = cat[k]["nome"]
				pg_corrente["token"].erase(k)
	pg_corrente["token"][id] = 1
	_off_msg.text = ("%s al posto di %s" % [cat[id]["nome"], tolta]) if tolta != "" else ("Aggiunto: %s" % cat[id]["nome"])
	_off_aggiorna()

func _off_rimuovi(id: String) -> void:
	if cat[id]["categoria"] == "attributo":
		_off_msg.text = "Le caratteristiche non si tolgono: scegline un'altra dello stesso tipo dal catalogo."
		return
	pg_corrente["token"].erase(id)
	_off_msg.text = "Tolto: %s" % cat[id]["nome"]
	_off_aggiorna()

func _off_livello(id: String, d: int) -> void:
	var t: Dictionary = cat[id]
	var nv := clampi(int(pg_corrente["token"][id]) + d, 1, t["livelli"].size())
	pg_corrente["token"][id] = nv
	_off_aggiorna()

func _off_casuale() -> void:
	var pg := Generatore.casuale(dati, int(pg_corrente.get("budget", 30)), rng)
	_off_carica_in_editor(pg)
	_off_msg.text = "Ecco %s: premi Salva per tenerlo." % pg["nome"]

func _off_nuovo() -> void:
	# si parte con la prima scheda di ogni caratteristica: si cambiano dal catalogo
	var tk := {}
	for k in Motore.CARATTERISTICHE:
		for t in dati["token"]:
			if t["categoria"] == "attributo" and t.get("caratteristica", "") == k:
				tk[t["id"]] = 1
				break
	_off_carica_in_editor({"nome": "Nuovo combattente", "budget": pg_corrente.get("budget", 30), "token": tk})
	_off_msg.text = "Scheda nuova: cambia le quattro caratteristiche dal catalogo, poi aggiungi il resto."

func _off_salva() -> void:
	var nome: String = _off_nome.text.strip_edges()
	if nome == "":
		_off_msg.text = "Dai un nome al combattente."
		return
	var probl := Motore.problemi_caratteristiche(cat, pg_corrente)
	if not probl.is_empty():
		_off_msg.text = "Serve una scheda per ogni caratteristica: %s." % ", ".join(probl)
		return
	pg_corrente["nome"] = nome
	var nuovo: Dictionary = pg_corrente.duplicate(true)
	var trovato := false
	for i in miei.size():
		if miei[i]["nome"] == nome:
			miei[i] = nuovo
			trovato = true
	if not trovato:
		miei.append(nuovo)
	_salva_miei()
	var costo := Motore.costo_personaggio(cat, nuovo)
	_off_msg.text = "Salvato %s (%d punti)%s." % [nome, costo, "" if costo <= int(nuovo["budget"]) else ", ma supera il budget"]
	_off_aggiorna()

func _off_elimina() -> void:
	for i in miei.size():
		if miei[i]["nome"] == pg_corrente["nome"]:
			miei.remove_at(i)
			_salva_miei()
			_off_msg.text = "Eliminato %s." % pg_corrente["nome"]
			_off_aggiorna()
			return
	_off_msg.text = "Si eliminano solo i combattenti che hai salvato tu."

func _off_esporta() -> void:
	var c := codice_di(pg_corrente)
	_off_codice.text = c
	DisplayServer.clipboard_set(c)
	_off_msg.text = "Codice copiato negli appunti."

func _off_importa() -> void:
	var d := da_codice(_off_codice.text)
	if d.is_empty():
		_off_msg.text = "Codice non valido."
		return
	for k in d["token"].keys():
		if not cat.has(k):
			d["token"].erase(k)
	_off_carica_in_editor(d)
	_off_msg.text = "Importato %s: premi Salva per tenerlo." % d["nome"]

# ================================================================= preparazione

func preparazione(modo: String) -> void:
	_pulisci()
	_demo_arena()
	_prep_modo = modo
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pagina.add_child(centro)
	var pan := _pannello(centro)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(1040, 0)
	pan.add_child(v)
	v.add_child(_label("Prepara lo scontro", 32, Disegno.ORO, Disegno.font_titolo()))
	v.add_child(_label("Scenario", 20, Disegno.ORO, Disegno.font_titolo()))
	var hs := HBoxContainer.new()
	hs.add_theme_constant_override("separation", 10)
	v.add_child(hs)
	_prep_sc_btn.clear()
	for i in dati["scenari"].size():
		var sc: Dictionary = dati["scenari"][i]
		var b := Button.new()
		b.toggle_mode = true
		b.text = "%s\n%d punti" % [sc["nome"], sc["budget"]]
		b.custom_minimum_size = Vector2(336, 70)
		b.pressed.connect(func(): _prep_set_scenario(i))
		hs.add_child(b)
		_prep_sc_btn.append(b)
	var hp := HBoxContainer.new()
	hp.add_theme_constant_override("separation", 20)
	v.add_child(hp)
	_prep_opt.clear()
	_prep_desc.clear()
	_prep_aspetto.clear()
	for p in 2:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(510, 0)
		hp.add_child(col)
		var tit := "Giocatore %d" % (p + 1)
		if modo == "ia" and p == 1:
			tit = "Avversario (IA)"
		if modo == "spettatore":
			tit = "IA %d" % (p + 1)
		col.add_child(_label(tit, 20, Disegno.GIOCATORI[p], Disegno.font_titolo()))
		var ob := OptionButton.new()
		ob.custom_minimum_size = Vector2(500, 46)
		ob.item_selected.connect(func(_i): _prep_desc_aggiorna())
		col.add_child(ob)
		_prep_opt.append(ob)
		var d := _label("", 16)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(500, 96)
		col.add_child(d)
		_prep_desc.append(d)
		# aspetto del combattente in 3D
		var ha := HBoxContainer.new()
		ha.add_theme_constant_override("separation", 10)
		col.add_child(ha)
		var la := _label("Aspetto", 18)
		la.custom_minimum_size = Vector2(110, 0)
		ha.add_child(la)
		var oa := OptionButton.new()
		oa.custom_minimum_size = Vector2(380, 42)
		oa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for a in Arena3D.ASPETTI:
			oa.add_item(a["nome"])
		oa.select(p % Arena3D.ASPETTI.size())
		ha.add_child(oa)
		_prep_aspetto.append(oa)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	v.add_child(hb)
	hb.add_child(_bottone("Indietro", menu, 200))
	hb.add_child(_bottone("Officina", officina, 200))
	var spazio := Control.new()
	spazio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spazio)
	if modo == "spettatore":
		var rip := CheckButton.new()
		rip.text = "Scontri a ripetizione"
		rip.button_pressed = a_ripetizione
		rip.toggled.connect(func(on): a_ripetizione = on)
		rip.add_theme_color_override("font_color", Disegno.PERGAMENA)
		hb.add_child(rip)
		var all := CheckButton.new()
		all.text = "Allenamento dell'IA"
		all.button_pressed = allenamento
		all.toggled.connect(func(on): allenamento = on)
		all.add_theme_color_override("font_color", Disegno.PERGAMENA)
		hb.add_child(all)
	hb.add_child(_bottone("Guarda!" if modo == "spettatore" else "Combatti!", _prep_via, 220))
	_prep_set_scenario(_prep_scenario)

func _prep_validi() -> Array:
	var budget: int = int(dati["scenari"][_prep_scenario]["budget"])
	var out := [{"nome": CASUALE, "token": {}, "casuale": true}]
	for pg in tutti_personaggi():
		var c := Motore.costo_personaggio(cat, pg)
		if c <= budget and Motore.problemi_caratteristiche(cat, pg).is_empty():
			out.append(pg)
	return out

func _ordina_validi(validi: Array) -> Array:
	var primo: Dictionary = validi.pop_front()
	validi.sort_custom(func(a, b): return Motore.costo_personaggio(cat, a) > Motore.costo_personaggio(cat, b))
	validi.push_front(primo)
	return validi

func _prep_set_scenario(i: int) -> void:
	_prep_scenario = i
	for k in _prep_sc_btn.size():
		_prep_sc_btn[k].button_pressed = (k == i)
	var validi := _ordina_validi(_prep_validi())
	for p in 2:
		var ob: OptionButton = _prep_opt[p]
		ob.clear()
		for pg in validi:
			ob.add_item(pg["nome"] if pg.get("casuale", false) else "%s  (%d punti)" % [pg["nome"], Motore.costo_personaggio(cat, pg)])
		if validi.size() > 0:
			ob.select(0 if _prep_modo == "spettatore" else clampi(p + 1, 0, validi.size() - 1))
	_prep_desc_aggiorna()

func _prep_desc_aggiorna() -> void:
	var validi := _ordina_validi(_prep_validi())
	for p in 2:
		var ob: OptionButton = _prep_opt[p]
		if ob.selected < 0 or ob.selected >= validi.size():
			_prep_desc[p].text = "Nessun combattente entro il budget."
			continue
		var pg: Dictionary = validi[ob.selected]
		if pg.get("casuale", false):
			_prep_desc[p].text = "Un combattente generato a caso entro il budget dello scenario, diverso a ogni scontro."
			continue
		var st := Motore.statistiche(cat, pg)
		var nomi := []
		for id in pg["token"]:
			var t: Dictionary = cat[id]
			nomi.append(t["nome"] + ((" " + ["I", "II", "III"][int(pg["token"][id]) - 1]) if t.has("livelli") else ""))
		var dadi := []
		for c in Motore.COLORI:
			if st["dadi"].has(c):
				dadi.append("%d %s" % [st["dadi"][c], Disegno.NOMI_COLORE[c]])
		_prep_desc[p].text = "Dadi: %s. Ferite %d, ritmo %d, recupero %d, armatura %d.\n%s" % [", ".join(dadi), st["vita"], st["ritmo"], st["recupero"], st["armatura"], ", ".join(nomi)]

func _prep_via() -> void:
	var validi := _ordina_validi(_prep_validi())
	if validi.is_empty():
		return
	var budget: int = int(dati["scenari"][_prep_scenario]["budget"])
	var a: Dictionary = validi[maxi(0, _prep_opt[0].selected)].duplicate(true)
	var b: Dictionary = validi[maxi(0, _prep_opt[1].selected)].duplicate(true)
	if a.get("casuale", false):
		a = Generatore.casuale(dati, budget, rng)
	if b.get("casuale", false):
		b = Generatore.casuale(dati, budget, rng)
	if a["nome"] == b["nome"]:
		b["nome"] = b["nome"] + " (ombra)"
	a["aspetto"] = Arena3D.ASPETTI[maxi(0, _prep_aspetto[0].selected)]["id"]
	b["aspetto"] = Arena3D.ASPETTI[maxi(0, _prep_aspetto[1].selected)]["id"]
	spettatore = _prep_modo == "spettatore"
	if not spettatore:
		allenamento = false
	battaglia(a, b, dati["scenari"][_prep_scenario], [spettatore, _prep_modo != "due"])

## Allenamento: lo sfidante gioca a lati alterni contro i pesi attuali; dopo 6 partite,
## se ne ha vinte almeno 4 i suoi pesi diventano quelli dell'IA (salvati sul dispositivo).
func _registra_sfida() -> void:
	_registrato = true
	_sfida["giocate"] += 1
	if int(m.s["vinc"]) == _lato_sfidante:
		_sfida["vinte"] += 1
	var nota := "Allenamento: lo sfidante ha vinto %d su %d." % [_sfida["vinte"], _sfida["giocate"]]
	if _sfida["giocate"] >= 6:
		_sfida["generazioni"] += 1
		if _sfida["vinte"] >= 4:
			_sfida["adottate"] += 1
			IA.adotta(_sfidante, _sfida["generazioni"])
			nota = "Allenamento: lo sfidante ha vinto %d su 6, l'IA adotta il suo modo di giocare." % _sfida["vinte"]
		else:
			nota = "Allenamento: lo sfidante ha vinto solo %d su 6, si prova una nuova variante." % _sfida["vinte"]
		_sfidante = IA.muta(IA.pesi(), rng)
		_sfida["giocate"] = 0
		_sfida["vinte"] = 0
	m.s["log"].append(nota)
	m.s["log"].append("Varianti provate %d, adottate %d." % [_sfida["generazioni"], _sfida["adottate"]])
	_aggiorna()

## Modalità spettatore a ripetizione: nuovo scenario e nuovi avventurieri casuali.
func _scontro_casuale() -> void:
	var sc: Dictionary = dati["scenari"][rng.randi() % dati["scenari"].size()]
	var a := Generatore.casuale(dati, int(sc["budget"]), rng)
	var b := Generatore.casuale(dati, int(sc["budget"]), rng)
	spettatore = true
	battaglia(a, b, sc, [true, true])

# ================================================================= battaglia

func battaglia(a: Dictionary, b: Dictionary, scenario: Dictionary, ia_: Array) -> void:
	_voli = 0
	_tieni_vista = -1
	_pulisci()
	spettatore = ia_[0] and ia_[1]
	if not spettatore:
		passo_ia = PASSO_IA
		allenamento = false
	_attesa_ripeti = 0.0
	_registrato = false
	_pesi_lato = [{}, {}]
	if spettatore and allenamento:
		if _sfidante.is_empty():
			_sfidante = IA.muta(IA.pesi(), rng)
		_lato_sfidante = _sfida["giocate"] % 2
		_pesi_lato[_lato_sfidante] = _sfidante
	_demo = false
	ia = ia_
	_scenario = scenario
	_pg = [a, b]
	m = Motore.new(dati)
	m.nuova_partita(a, b, scenario["arena"])
	arena.visible = true
	arena.costruisci(m)
	_centra()
	mostra = 1 if (ia[0] and not ia[1]) else 0
	mostra_avversario = false
	_costruisci_hud()
	m.prendi_eventi()
	_aggiorna()

func _costruisci_hud() -> void:
	var vw := get_viewport().get_visible_rect().size
	_verticale = vw.y > vw.x * 1.1
	_ll = vw.x * 0.5 - 12 if _verticale else clampf(vw.x * 0.25, 360.0, 600.0)
	# barra in alto
	var top := _pannello(pagina)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8
	top.offset_right = -8
	top.offset_top = 8
	top.add_theme_stylebox_override("panel", Disegno.stile(Color(0.07, 0.055, 0.04, 0.85), Color("#6b5234"), 10, 1))
	var ht := HBoxContainer.new()
	ht.add_theme_constant_override("separation", 10)
	top.add_child(ht)
	_stati.clear()
	for p in 2:
		var sg := StatoGiocatore.new()
		sg.motore = m
		sg.giocatore = p
		_stati.append(sg)
	ht.add_child(_stati[0])
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.custom_minimum_size = Vector2(380, 0)
	ht.add_child(mid)
	_scambio = _label("", 22, Disegno.ORO, Disegno.font_titolo())
	_scambio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_scambio)
	_msg = _label("", 17)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.custom_minimum_size = Vector2(380, 50)
	mid.add_child(_msg)
	ht.add_child(_stati[1])
	# schede dei due combattenti ai lati: dadi (in mano, mucchio, scartati) e tutti i token
	_lati.clear()
	for p in 2:
		var lato := _pannello(pagina)
		if _verticale:
			lato.anchor_left = 0.5 * p
			lato.anchor_right = 0.5 * (p + 1)
			lato.anchor_top = ALTO_MAPPA
			lato.anchor_bottom = 1.0
			lato.offset_left = 8 if p == 0 else 4
			lato.offset_right = -4 if p == 0 else -8
			lato.offset_top = 4
			lato.offset_bottom = -8
		else:
			lato.set_anchors_preset(Control.PRESET_LEFT_WIDE if p == 0 else Control.PRESET_RIGHT_WIDE)
			if p == 0:
				lato.offset_left = 8
				lato.offset_right = 8 + _ll
			else:
				lato.offset_left = -8 - _ll
				lato.offset_right = -8
			lato.offset_top = 112
			lato.offset_bottom = -8
		lato.add_theme_stylebox_override("panel", Disegno.stile(Color(0.07, 0.055, 0.04, 0.9), Disegno.GIOCATORI[p].darkened(0.3), 10, 2))
		var vl := VBoxContainer.new()
		vl.add_theme_constant_override("separation", 6)
		lato.add_child(vl)
		var titolo := _label("Scheda di %s" % m.s["g"][p]["nome"], 18, Disegno.GIOCATORI[p].lightened(0.25), Disegno.font_titolo())
		titolo.custom_minimum_size = Vector2(_ll - 24, 0)
		titolo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vl.add_child(titolo)
		var va := Vassoio.new()
		va.D = clampf(44.0 * _ll / 360.0, 44.0, 56.0)
		va.motore = m
		va.giocatore = p
		var pp := p
		va.dado_premuto.connect(func(id): if _umano_decide() == pp: _dado(id))
		vl.add_child(va)
		# tutte le carte in vista, su due colonne, senza scorrere
		var colonne := HBoxContainer.new()
		colonne.size_flags_vertical = Control.SIZE_EXPAND_FILL
		colonne.add_theme_constant_override("separation", 8)
		colonne.clip_contents = true
		vl.add_child(colonne)
		var cols := []
		for i in 4:
			var cx := VBoxContainer.new()
			cx.add_theme_constant_override("separation", 6)
			cx.visible = i < 2
			colonne.add_child(cx)
			cols.append(cx)
		_lati.append({"vassoio": va, "colonne": colonne, "col": cols, "carte": [], "vh": -1.0})
		colonne.resized.connect(func(): _adatta_lato.call_deferred(pp))
	_vassoio = _lati[0]["vassoio"]
	if not get_viewport().size_changed.is_connected(_rifai_lati):
		get_viewport().size_changed.connect(_rifai_lati)
	# diario in alto a destra, fra la mappa e la scheda di destra
	var dr := _pannello(pagina)
	dr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var mar := 8.0 if _verticale else 16 + _ll
	dr.offset_left = -mar - 250
	dr.offset_right = -mar
	dr.offset_top = 112
	dr.offset_bottom = 112 + 170
	var vd := VBoxContainer.new()
	dr.add_child(vd)
	var hv := HBoxContainer.new()
	vd.add_child(hv)
	var dt := _label("Diario", 20, Disegno.ORO, Disegno.font_titolo())
	dt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(dt)
	hv.add_child(_bottone("Menu", _chiedi_menu, 90))
	_diario_scroll = ScrollContainer.new()
	_diario_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_diario_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vd.add_child(_diario_scroll)
	_diario = _label("", 15)
	_diario.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diario.custom_minimum_size = Vector2(220, 0)
	_diario_scroll.add_child(_diario)
	# comandi di vista (grandi, per il tocco), in alto a sinistra della mappa
	var vista := _pannello(pagina)
	vista.set_anchors_preset(Control.PRESET_TOP_LEFT)
	vista.offset_left = 8 if _verticale else 16 + _ll
	vista.offset_top = 112
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 6)
	vista.add_child(gv)
	var voci_vista := [["Ruota a sinistra", func(): arena.ruota_vista(-0.4)], ["Ruota a destra", func(): arena.ruota_vista(0.4)],
			["Avvicina", func(): arena.zoom(0.85)], ["Allontana", func(): arena.zoom(1.18)], ["Centra", _centra]]
	if spettatore:
		voci_vista += [["Pausa", func(): passo_ia = -1.0], ["Lento", func(): passo_ia = 1.2], ["Normale", func(): passo_ia = PASSO_IA],
			["Veloce", func(): passo_ia = 0.12], ["Nuovo scontro", _scontro_casuale]]
	for k in voci_vista:
		var b := _bottone(k[0], k[1], 136)
		b.custom_minimum_size.y = 34
		b.add_theme_font_size_override("font_size", 12)
		gv.add_child(b)
	# comandi di gioco in basso, sotto la mappa
	var bot := _pannello(pagina)
	bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot.offset_left = 8 if _verticale else 16 + _ll
	bot.offset_right = -8 if _verticale else -16 - _ll
	if _verticale:
		bot.anchor_top = ALTO_MAPPA
		bot.anchor_bottom = ALTO_MAPPA
	bot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bot.offset_top = -8
	bot.offset_bottom = -8
	if _verticale:
		bot.offset_top = -4
		bot.offset_bottom = -4
	var flusso := HFlowContainer.new()
	flusso.add_theme_constant_override("h_separation", 6)
	flusso.add_theme_constant_override("v_separation", 6)
	bot.add_child(flusso)
	_btn.clear()
	var comandi := [["consigliata", "Scelta consigliata", _cmd_consigliata], ["passo", "Passo (2)", _cmd_passo],
		["spinta", "Spingi la fortuna", _cmd_spinta], ["conserva", "Conserva", _cmd_conserva],
		["passa", "Passa", _cmd_passa], ["riposo", "Riposo (+1)", _cmd_riposo],
		["flusso", "Flusso (2 vantaggi)", _cmd_flusso], ["rovescio", "Rovescio (3 vantaggi)", _cmd_rovescio],
		["emergenza", "Sblocca (dado)", _cmd_emergenza], ["sferra", "Sferra il colpo", _cmd_sferra], ["risolvi", "Subisci il colpo", _cmd_risolvi],
		["rilancia", "Rilancia", _cmd_rilancia], ["ferma", "Fermati", _cmd_ferma], ["conferma", "Conferma", _cmd_conferma],
		["annulla", "Annulla", _cmd_annulla]]
	for c in comandi:
		var b := _bottone(c[1], c[2], 176)
		b.custom_minimum_size.y = 42
		b.add_theme_font_size_override("font_size", 14)
		flusso.add_child(b)
		_btn[c[0]] = b
	_scelte = GridContainer.new()
	_scelte.columns = 2
	_scelte.add_theme_constant_override("h_separation", 6)
	_scelte.add_theme_constant_override("v_separation", 6)
	flusso.add_child(_scelte)
	_ricostruisci_carte()
	# strato sopra tutto per i dadi che volano dal vassoio ai token
	_volo = Control.new()
	_volo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_volo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_volo.z_index = 50
	pagina.add_child(_volo)

## Vista iniziale: giocatore 1 a sinistra, avversario a destra, arena nella parte libera dello schermo.
func _centra() -> void:
	var v := Arena3D.mondo(m.s["g"][1]["pos"]) - Arena3D.mondo(m.s["g"][0]["pos"])
	arena.yaw = -atan2(v.z, v.x) if v.length() > 0.1 else 0.0
	arena.pitch = deg_to_rad(58)
	var vw := get_viewport().get_visible_rect().size
	if vw.y > vw.x * 1.1:
		# in verticale la mappa sta nella parte alta, sopra le schede
		arena.distanza = 7.0 + m.s["raggio"] * 1.3
		arena.spostamento_v = 0.42
	else:
		arena.distanza = 9.0 + m.s["raggio"] * 1.6
		arena.spostamento_v = 0.1
	arena.spostamento_h = 0.0
	arena.pivot.position = Vector3.ZERO
	arena.ruota_vista(0)

## Le carte di entrambi i combattenti: prima le azioni di base, poi le quattro caratteristiche, poi il resto.
func _ricostruisci_carte() -> void:
	var ordine := ["base", "attributo", "attacco", "tecnica", "arma", "mossa", "armatura", "oggetto", "talento", "magia", "segreto"]
	var proprio := _giocatore_proprio()
	for p in _lati.size():
		var lato: Dictionary = _lati[p]
		for cx in lato["col"]:
			for c in cx.get_children():
				c.queue_free()
		lato["carte"] = []
		lato["chiave"] = ""
		lato.erase("disp_min")
		var ids: Array = m.s["g"][p]["pg"]["token"].keys()
		ids.sort_custom(func(a, b): return _ordine_carta(a, ordine) < _ordine_carta(b, ordine))
		if cat.has("scena"):
			ids.push_front("scena")
		if cat.has("base"):
			ids.push_front("base")
		for id in ids:
			var carta := CartaToken.new()
			carta.motore = m
			carta.giocatore = p
			carta.coperta = cat[id]["categoria"] == "segreto" and not m.s["g"][p]["rivelati"].has(id) and proprio >= 0 and p != proprio
			carta.compatta = true
			carta.illustrata = _carte_illustrate
			carta.imposta(cat[id], int(m.s["g"][p]["pg"]["token"].get(id, 1)), "gioco")
			var pp := p
			carta.slot_premuto.connect(func(t, sid): if _umano_decide() == pp: _slot(t, sid))
			carta.dettaglio.connect(func(t): _mostra_dettaglio(pp, t))
			lato["col"][0].add_child(carta)
			lato["carte"].append(carta)
		_adatta_lato.call_deferred(p)
	_carte = _lati[mostra]["carte"] if not _lati.is_empty() else []
	_vassoio = _lati[mostra]["vassoio"] if not _lati.is_empty() else _vassoio

## Sceglie corpo del testo e righe in modo che tutte le carte del lato stiano nelle due colonne.
func _adatta_lato(p: int) -> void:
	if p >= _lati.size():
		return
	var lato: Dictionary = _lati[p]
	var colonne: HBoxContainer = lato["colonne"]
	if not is_instance_valid(colonne):
		return
	await get_tree().process_frame
	if not is_instance_valid(colonne):
		return
	var disp: float = maxf(colonne.size.y, 300.0)
	var colw := floorf((colonne.size.x - 8) / 2.0) if colonne.size.x > 100 else (_ll - 32) / 2.0
	var carte: Array = lato["carte"]
	# con le carte illustrate le altezze non cambiano: se spazio e carte sono gli stessi non si rifà
	# la disposizione (rifarla cambia le colonne visibili, che a loro volta ridimensionano: sfarfallio)
	# l'altezza libera cambia quando nel vassoio compaiono o spariscono righe (Preparati, Conservati):
	# per le carte illustrate si usa la più piccola vista finora, così le colonne non saltano avanti e indietro
	if _carte_illustrate:
		disp = minf(disp, float(lato.get("disp_min", disp)))
		lato["disp_min"] = disp
	var chiave := "%d|%d|%d" % [int(colonne.size.x), int(disp), carte.size()]
	if _carte_illustrate and lato.get("ok_ill", false) and lato.get("chiave", "") == chiave:
		for carta in carte:
			carta.queue_redraw()
		return
	lato["chiave"] = chiave
	var scelta := []
	var ncol := 2
	var ok_ill := false
	if _carte_illustrate:
		# carte illustrate: stessa larghezza per tutte, da 2 a 4 colonne finché stanno senza scorrere
		for nc in [2, 3, 4]:
			var cw: float = floorf((colonne.size.x - 8.0 * (nc - 1)) / nc) if colonne.size.x > 100 else (_ll - 32) / nc
			var alt_c := []
			for c in nc:
				alt_c.append(0.0)
			scelta = []
			for carta in carte:
				carta.illustrata = true
				carta.larg = cw
				carta.fs = 10
				carta.righe = 2
				carta._ricalcola()
				# ogni carta va nella colonna più bassa, così le colonne restano pari
				var cmin := 0
				for c in nc:
					if alt_c[c] < alt_c[cmin] - 0.5:
						cmin = c
				scelta.append(cmin)
				alt_c[cmin] += carta._h + 6
			if float(alt_c.max()) <= disp:
				ncol = nc
				ok_ill = true
				break
		if not ok_ill:
			for carta in carte:
				carta.illustrata = false
	if not ok_ill:
		for cfg in [[18, 0], [16, 0], [15, 0], [14, 0], [13, 0], [12, 0], [11, 0], [10, 0], [10, 4], [10, 3], [10, 2], [9, 2], [9, 1]]:
			var alt := []
			var tot := 0.0
			for carta in carte:
				carta.larg = colw
				carta.fs = cfg[0]
				carta.righe = cfg[1]
				carta._ricalcola()
				alt.append(carta._h + 6)
				tot += carta._h + 6
			# l'ordine resta quello della scheda: la prima colonna si riempie fino a metà circa
			scelta = []
			var h0 := 0.0
			for i in carte.size():
				if h0 + alt[i] * 0.5 <= tot / 2.0 or i == 0:
					scelta.append(0)
					h0 += alt[i]
				else:
					scelta.append(1)
			if maxf(h0, tot - h0) <= disp:
				break
	lato["ok_ill"] = ok_ill
	for c in lato["col"].size():
		lato["col"][c].visible = c < ncol
	for i in carte.size():
		var carta: CartaToken = carte[i]
		var dest: VBoxContainer = lato["col"][scelta[i]]
		if carta.get_parent() != dest:
			if carta.get_parent() != null:
				carta.get_parent().remove_child(carta)
			dest.add_child(carta)
		else:
			dest.move_child(carta, -1)
		carta.queue_redraw()
	lato["vh"] = lato["vassoio"].custom_minimum_size.y

## La carta a grandezza piena, per leggerla con calma (si gioca anche da qui).
func _immagine_carta(tex: Texture2D, quota: float) -> TextureRect:
	# le carte hanno altezze diverse (un modulo per azione): larghezza fissa, altezza limitata
	var ar := float(tex.get_height()) / float(tex.get_width())
	var h_max := clampf(pagina.size.y * quota, 240.0, 900.0)
	var w := minf(clampf(pagina.size.x * 0.34, 260.0, 380.0), h_max / ar)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(w, w * ar)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

## Solo la carta illustrata, a tutta altezza (dal catalogo dell'Officina).
func _mostra_carta_illustrata(id: String) -> void:
	var tex := Illustrazioni.carta(id)
	if tex == null:
		return
	if is_instance_valid(_dettaglio):
		_dettaglio.queue_free()
	_dettaglio = Control.new()
	_dettaglio.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dettaglio.z_index = 40
	pagina.add_child(_dettaglio)
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.7)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _chiudi_dettaglio())
	_dettaglio.add_child(fondo)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dettaglio.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	cc.add_child(v)
	v.add_child(_immagine_carta(tex, 0.84))
	var b := _bottone("Chiudi", _chiudi_dettaglio, 160)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)

func _mostra_dettaglio(p: int, id: String) -> void:
	if is_instance_valid(_dettaglio):
		_dettaglio.queue_free()
	_dettaglio = Control.new()
	_dettaglio.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dettaglio.z_index = 40
	pagina.add_child(_dettaglio)
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.55)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _chiudi_dettaglio())
	_dettaglio.add_child(fondo)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dettaglio.add_child(cc)
	var pan := _pannello(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pan.add_child(v)
	var carta := CartaToken.new()
	carta.motore = m
	carta.giocatore = p
	for c in _lati[p]["carte"]:
		if c.tok["id"] == id:
			carta.coperta = c.coperta
			carta.evidenzia = c.evidenzia
	carta.imposta(cat[id], int(m.s["g"][p]["pg"]["token"].get(id, 1)), "gioco")
	carta.scale = Vector2(1.25, 1.25)
	var spazio := Control.new()
	spazio.custom_minimum_size = carta.size * 1.25
	spazio.add_child(carta)
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 14)
	riga.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(riga)
	# la carta illustrata accanto a quella giocabile (non per i segreti ancora coperti)
	var tex := Illustrazioni.carta(id)
	if tex != null and not carta.coperta:
		riga.add_child(_immagine_carta(tex, 0.78))
	riga.add_child(spazio)
	carta.slot_premuto.connect(func(t, sid):
		_chiudi_dettaglio()
		if _umano_decide() == p:
			_slot(t, sid))
	var b := _bottone("Chiudi", _chiudi_dettaglio, 160)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)

func _rifai_lati() -> void:
	for q in _lati.size():
		_lati[q].erase("disp_min")
		_adatta_lato.call_deferred(q)

func _chiudi_dettaglio() -> void:
	if is_instance_valid(_dettaglio):
		_dettaglio.queue_free()
	_dettaglio = null

func _ordine_carta(id: String, ordine: Array) -> int:
	var t: Dictionary = cat[id]
	var o: int = ordine.find(t["categoria"]) * 1000 + dati["token"].find(t)
	if t.has("caratteristica"):
		o = ordine.find("attributo") * 1000 + Motore.CARATTERISTICHE.find(t["caratteristica"])
	return o

## Coperte o scoperte: i segreti si girano quando scattano o quando cambia chi guarda (partita a due).
func _aggiorna_coperte() -> void:
	var proprio := _giocatore_proprio()
	for p in _lati.size():
		for carta in _lati[p]["carte"]:
			var cop: bool = carta.tok["categoria"] == "segreto" and not m.s["g"][p]["rivelati"].has(carta.tok["id"]) and proprio >= 0 and p != proprio
			if cop != carta.coperta:
				carta.coperta = cop
				carta.imposta(carta.tok, carta.lv, "gioco")

## Chi sta davanti allo schermo: i suoi segreti si vedono, quelli dell'altro no (-1 = spettatore, si vede tutto).
func _giocatore_proprio() -> int:
	if ia[0] and ia[1]:
		return -2
	if not ia[0] and not ia[1]:
		var chi := m.chi_decide()
		return chi if chi >= 0 else int(m.s["attivo"])
	return 0 if not ia[0] else 1

## Quale delle due schede si comanda: chi deve decidere, se è un umano.
func _giocatore_mostrato() -> int:
	var chi := m.chi_decide()
	if chi >= 0 and not ia[chi]:
		return chi
	if not ia[0] and ia[1]:
		return 0
	if ia[0] and not ia[1]:
		return 1
	return mostra

func _umano_decide() -> int:
	if m == null or arena.occupato():
		return -1
	var chi := m.chi_decide()
	if chi < 0 or ia[chi]:
		return -1
	return chi

func _aggiorna() -> void:
	if m == null or _stati.is_empty():
		return
	var p := _giocatore_mostrato()
	if p != mostra:
		mostra = p
		sel.clear()
	_carte = _lati[mostra]["carte"]
	_vassoio = _lati[mostra]["vassoio"]
	_aggiorna_coperte()
	var chi := _umano_decide()
	for q in _lati.size():
		if absf(float(_lati[q]["vh"]) - _lati[q]["vassoio"].custom_minimum_size.y) > 20.0:
			_lati[q]["vh"] = _lati[q]["vassoio"].custom_minimum_size.y
			_adatta_lato.call_deferred(q)
		var va: Vassoio = _lati[q]["vassoio"]
		var attivo: bool = q == mostra
		va.scegli_mucchio = attivo and chi == q and attesa.is_empty() and m.s["fase"] in ["azione", "rinforzo", "reazione", "azzardo"]
		va.selezionati = (attesa["scelti"] if attesa.get("passo", "") in ["mucchio", "dadi"] else sel) if attivo else []
		va.interattivo = chi == q
		va.queue_redraw()
		for carta in _lati[q]["carte"]:
			carta.queue_redraw()
	for sg in _stati:
		sg.queue_redraw()
	_scambio.text = "Scambio %d" % m.s["round"]
	_diario.text = "\n".join(m.s["log"].slice(maxi(0, m.s["log"].size() - 60)))
	_diario_scroll.set_deferred("scroll_vertical", 100000)
	_msg.text = _messaggio()
	_aggiorna_evidenze()
	_aggiorna_comandi()
	if m.s["vinc"] >= 0 and not arena.occupato():
		_mostra_fine()

func _messaggio() -> String:
	if m.s["vinc"] >= 0:
		return "Vince %s!" % m.s["g"][m.s["vinc"]]["nome"]
	var chi := m.chi_decide()
	var nome: String = m.s["g"][chi]["nome"]
	if ia[chi]:
		return "%s sta decidendo..." % nome
	if not attesa.is_empty():
		match attesa["passo"]:
			"mucchio":
				return "%s: scegli %s dal mucchio (%d scelti), poi Conferma." % [nome, Motore.plurale(attesa["n"], "dado", "dadi"), attesa["scelti"].size()]
			"esagono":
				return "Tocca un esagono evidenziato."
			"direzione":
				if not attesa.get("bersagli", []).is_empty() and attesa["bersagli"][0].has("lato"):
					return "Scegli il lato dell'esagono: tocca una freccia dorata o un pulsante."
				return "Tocca una freccia dorata per scegliere dove guardare."
			"scelta":
				return "Scegli tra i pulsanti."
			"spazi":
				if attesa.get("emergenza", false):
					return "Sblocca di emergenza: scegli uno spazio da liberare. Il dado speso e quelli sbloccati vanno in Attesa."
				if attesa.get("flusso", false):
					return "Flusso: spendi 2 vantaggi e scegli lo spazio da liberare; i suoi dadi vanno in Attesa."
				if attesa.get("passa", false):
					return "Passi: tocca fino a %s da liberare, poi Conferma." % Motore.plurale(attesa["n"], "spazio occupato", "spazi occupati")
				return "Tocca %s da liberare, poi Conferma." % Motore.plurale(attesa["n"], "spazio occupato", "spazi occupati")
			"dadi":
				return "Tocca %s in mano." % ("due dadi da scambiare" if attesa["n"] == 2 else "il dado da cambiare")
			"segno":
				return "Alzi o abbassi il dado?"
			"colore":
				return "Scegli il colore del dado da eliminare dal mucchio."
	match m.s["fase"]:
		"rinforzo":
			var pe: Dictionary = m.s["pend"]
			return "%s: %s a %s. Aggiungi supporti o sferra il colpo." % [nome, pe["nome"], Motore.plurale(int(pe["danno"]) + int(pe["bonus"]), "danno", "danni")]
		"reazione":
			var pe: Dictionary = m.s["pend"]
			return "%s: arriva %s (%s, dado %d). Reagisci o subisci." % [nome, pe["nome"], Motore.plurale(int(pe["danno"]) + int(pe["bonus"]), "danno", "danni"), pe["vd"]]
		"azzardo":
			return "%s: Furia a %d. Rilancia un rosso (con 1 fallisce) o fermati." % [nome, m.s["azz"]["tot"]]
	var g: Dictionary = m.s["g"][chi]
	return "%s: Attitudine %s, Ritmo %d/%d disponibile. Scegli dal mucchio e tocca un'azione." % [nome, String(g.get("attitudine", "neutrale")).capitalize(), m.ritmo_disponibile(chi), m.ritmo_azione(chi)]

func _aggiorna_evidenze() -> void:
	var p := mostra
	var chi := _umano_decide()
	for lato in _lati:
		for carta in lato["carte"]:
			carta.evidenzia = {}
			carta.scelta_spazi = {}
			carta.queue_redraw()
	for carta in _carte:
		carta.evidenzia = {}
		carta.scelta_spazi = {}
		if attesa.get("passo", "") == "spazi":
			for sl in carta.tok["slot"]:
				var k := Motore.chiave(carta.tok["id"], sl["id"])
				if attesa["selezionabili"].has(k):
					carta.scelta_spazi[sl["id"]] = 1 if attesa["scelti"].has(k) else 0
		elif chi == p and attesa.is_empty():
			for sl in carta.tok["slot"]:
				carta.evidenzia[sl["id"]] = _slot_usabile(p, carta.tok["id"], sl)
		carta.queue_redraw()
	_vassoio.evidenziati = attesa.get("selezionabili", []) if attesa.get("passo", "") == "dadi" else []
	if attesa.is_empty() or attesa["passo"] in ["spazi", "dadi", "colore", "segno", "scelta"]:
		if attesa.is_empty():
			arena.pulisci_evidenza()

func _slot_usabile(p: int, tok: String, sl: Dictionary) -> bool:
	if not m.slot_attivabile(p, tok, sl):
		return false
	var combos := []
	if not sel.is_empty():
		var o := m.ordina_dadi(p, sl, sel)
		if o.is_empty():
			return false
		combos = [o]
	else:
		combos = m.combinazioni(p, sl, 24)
	for ids in combos:
		if not m.bersagli(p, tok, sl, ids).is_empty():
			return true
	return false

func _aggiorna_comandi() -> void:
	var chi := _umano_decide()
	var mio := chi >= 0 and chi == mostra
	var fase: String = m.s["fase"]
	for k in _btn:
		_btn[k].visible = false
		_btn[k].disabled = false
	if attesa.get("passo", "") == "mucchio":
		_btn["conferma"].visible = true
		_btn["conferma"].disabled = attesa["scelti"].size() != attesa["n"]
		if attesa.get("inizio", false):
			_btn["consigliata"].visible = true
		else:
			_btn["annulla"].visible = true
		return
	if not attesa.is_empty():
		_btn["annulla"].visible = true
		if attesa["passo"] == "spazi":
			_btn["conferma"].visible = true
			var n: int = attesa["scelti"].size()
			_btn["conferma"].disabled = n == 0 or n > attesa["n"] or (not attesa.get("passa", false) and n != attesa["n"])
		return
	if not mio:
		return
	var in_mano := []
	var cons_sel := []
	for id in sel:
		var d := m.dado(chi, id)
		if d.get("st", "") in ["mucchio", "mano"]:
			in_mano.append(id)
		elif d.get("st", "") == "conservato":
			cons_sel.append(id)
	if fase in ["azione", "rinforzo", "reazione"]:
		var b: Button = _btn["spinta"]
		b.visible = true
		b.disabled = in_mano.is_empty() or not m.spinta_disponibile(chi)
		var c: Button = _btn["conserva"]
		c.visible = true
		c.text = "Riprendi" if not cons_sel.is_empty() else "Conserva"
		c.disabled = not (sel.size() == 1 and (not cons_sel.is_empty() or m.dadi_di(chi, "conservato").size() < int(m.s["g"][chi]["conserva_max"])))
	match fase:
		"azione":
			_btn["passa"].visible = true
			_btn["riposo"].visible = not m.dadi_di(chi, "attesa").is_empty() and int(m.s["g"][chi]["usi"].get("riposo", 0)) == 0
			_btn["emergenza"].visible = in_mano.size() == 1 and not m.s["g"][chi]["occupati"].is_empty() and int(m.s["g"][chi]["usi"].get("emergenza", 0)) == 0
			_btn["passo"].visible = not m.bersagli_passo(chi).is_empty()
			_btn["flusso"].visible = int(m.s["g"][chi].get("vantaggi", 0)) >= 2 and not m.s["g"][chi]["occupati"].is_empty() and int(m.s["g"][chi]["usi"].get("flusso", 0)) == 0
		"rinforzo":
			_btn["sferra"].visible = true
		"reazione":
			_btn["risolvi"].visible = true
			for op in m.opzioni(chi):
				if op["t"] == "rovescio_fluido":
					_btn["rovescio"].visible = true
		"azzardo":
			_btn["rilancia"].visible = true
			_btn["ferma"].visible = true
			var ha := false
			for d in m.dadi_di(chi, "mucchio") + m.dadi_di(chi, "mano"):
				if Motore.colore_ok(d["col"], ["rosso"]):
					ha = true
			_btn["rilancia"].disabled = not ha

func _mostra_scelte(voci: Array) -> void:
	for c in _scelte.get_children():
		c.queue_free()
	for v in voci:
		var b := _bottone(v[0], v[1], 160)
		b.custom_minimum_size.y = 42
		b.add_theme_font_size_override("font_size", 14)
		_scelte.add_child(b)

# ----------------------------------------------------------------- input del giocatore

func _dado(id: int) -> void:
	if _umano_decide() != mostra:
		return
	if attesa.get("passo", "") == "mucchio":
		if m.dado(mostra, id).get("st", "") != "mucchio":
			return
		if attesa["scelti"].has(id):
			attesa["scelti"].erase(id)
		elif attesa["scelti"].size() < attesa["n"]:
			attesa["scelti"].append(id)
		_aggiorna()
		return
	if attesa.get("passo", "") == "dadi":
		if not attesa["selezionabili"].has(id):
			return
		if attesa["scelti"].has(id):
			attesa["scelti"].erase(id)
		else:
			attesa["scelti"].append(id)
		_vassoio.selezionati = attesa["scelti"]
		if attesa["scelti"].size() >= attesa["n"]:
			_dadi_scelti()
		else:
			_aggiorna()
		return
	if not attesa.is_empty():
		return
	if sel.has(id):
		sel.erase(id)
	else:
		var d := m.dado(mostra, id)
		if d.get("st", "") == "conservato":
			sel = [id]
		elif d.get("st", "") in ["mucchio", "mano"]:
			var prova := sel.duplicate()
			prova.append(id)
			if not m.selezione_attitudine_ok(mostra, prova):
				_msg.text = "Limite superato: restano %d punti Ritmo; Attitudine %s (max %d dadi %s nello scambio)." % [m.ritmo_disponibile(mostra), String(m.s["g"][mostra].get("attitudine", "neutrale")).capitalize(), m.limite_colore(mostra, d["col"]), d["col"]]
				return
			sel.append(id)
		else:
			return
	_aggiorna()
	_suggerisci_spazi()

## Dopo aver scelto dei dadi dice dove possono andare (gli spazi giusti sono anche evidenziati in oro).
func _suggerisci_spazi() -> void:
	if sel.is_empty():
		return
	var nomi_dadi := []
	for i in sel:
		var d := m.dado(mostra, i)
		nomi_dadi.append("%d %s" % [d["v"], d["col"]])
	var dove := []
	var vicini := []
	for carta in _carte:
		for sl in carta.tok["slot"]:
			if carta.evidenzia.get(sl["id"], false):
				dove.append(sl["nome"])
			elif m.ordina_dadi(mostra, sl, sel).size() > 0 and not m.occupato(mostra, carta.tok["id"], sl["id"]):
				vicini.append(sl)
	if not dove.is_empty():
		_msg.text = "Con %s puoi usare: %s." % [", ".join(nomi_dadi), ", ".join(dove)]
	elif not vicini.is_empty():
		var sl: Dictionary = vicini[0]
		var quando := "adesso non c'è un bersaglio valido"
		if sl["effetto"] in ["attacco", "assalto"]:
			quando = "il nemico non è a portata o non è davanti a te"
		match sl["tipo"]:
			"reazione", "supporto_difesa":
				quando = "si usa quando ti attaccano"
			"supporto_attacco":
				quando = "si usa dopo aver dichiarato un tuo colpo"
			"azione":
				if m.s["fase"] != "azione":
					quando = "si usa solo quando hai l'iniziativa"
		_msg.text = "Con %s andrebbe bene %s, ma %s." % [", ".join(nomi_dadi), sl["nome"], quando]
	else:
		_msg.text = "Nessuno spazio accetta %s: guarda colori e condizioni scritti sugli spazi." % ", ".join(nomi_dadi)

func _dadi_scelti() -> void:
	var p := _umano_decide()
	var sc: Array = attesa["scelti"]
	match attesa["eff"]:
		"scambia":
			for b in attesa["bersagli"]:
				if (b["a"] == sc[0] and b["b"] == sc[1]) or (b["a"] == sc[1] and b["b"] == sc[0]):
					_esegui(p, _op_attesa(b))
					return
			_msg.text = "Questi due dadi hanno lo stesso valore: scegline altri."
			attesa["scelti"] = []
			_aggiorna()
		"rovescia":
			_esegui(p, _op_attesa({"dado": sc[0]}))
		"ritocca":
			attesa["passo"] = "segno"
			var d := m.dado(p, sc[0])
			var voci := []
			if d["v"] < 6:
				voci.append(["Alza a %d" % (d["v"] + 1), func(): _esegui(p, _op_attesa({"dado": sc[0], "d": 1}))])
			if d["v"] > 1:
				voci.append(["Abbassa a %d" % (d["v"] - 1), func(): _esegui(p, _op_attesa({"dado": sc[0], "d": -1}))])
			_mostra_scelte(voci)
			_aggiorna()

func _op_attesa(b: Dictionary) -> Dictionary:
	if attesa.get("passo_base", false):
		return {"t": "passo", "b": b}
	return {"t": "slot", "tok": attesa["tok"], "slot": attesa["slot"], "dadi": attesa["dadi"], "b": b}

func _slot(tok: String, sid: String) -> void:
	var p := _umano_decide()
	if p < 0 or p != mostra:
		return
	if attesa.get("passo", "") == "spazi":
		var k := Motore.chiave(tok, sid)
		if attesa["selezionabili"].has(k):
			if attesa["scelti"].has(k):
				attesa["scelti"].erase(k)
			elif attesa["scelti"].size() < attesa["n"]:
				attesa["scelti"].append(k)
			_aggiorna()
		return
	if not attesa.is_empty():
		_cmd_annulla()
	var sl := m.slot_def(tok, sid)
	var chiave := Motore.chiave(tok, sid)
	if m.s["g"][p]["carichi"].has(chiave):
		if m.opzioni_scarica(p).has(chiave):
			_esegui(p, {"t": "scarica", "key": chiave})
		else:
			_msg.text = "%s è carico, ma il nemico è fuori portata." % sl["nome"]
		return
	if m.occupato(p, tok, sid):
		_msg.text = "%s è occupato: per riusarlo devi liberarlo." % sl["nome"]
		return
	if not m.slot_attivabile(p, tok, sl):
		match sl["tipo"]:
			"reazione", "supporto_difesa":
				_msg.text = "%s si usa quando ti attaccano." % sl["nome"]
			"supporto_attacco":
				_msg.text = "%s si usa dopo aver dichiarato un tuo colpo." % sl["nome"]
			_:
				_msg.text = "Ora non puoi usare %s." % sl["nome"]
		return
	var ids := []
	if not sel.is_empty():
		ids = m.ordina_dadi(p, sl, sel)
		if ids.is_empty():
			_msg.text = m.spiega_dadi(p, sl, sel)
			if _msg.text == "":
				_msg.text = "I dadi scelti non vanno bene per %s." % sl["nome"]
			return
	else:
		var best := []
		var bv := -1
		var combo: Array = m.combinazioni(p, sl, 24)
		if combo.is_empty():
			_msg.text = m.spiega_mano(p, sl)
			return
		for c in combo:
			if m.bersagli(p, tok, sl, c).is_empty():
				continue
			var somma := 0
			for id in c:
				somma += int(m.dado(p, id)["v"])
			# senza scelta: il dado più alto per colpire, difendere e muovere, altrimenti il più basso
			var punteggio := 100 - somma
			if not sl.has("fisso") and sl["effetto"] in ["attacco", "para", "movimento", "assalto", "sblocca", "contrattacco", "stordisci", "supp_danno", "supp_difesa", "concentrazione"]:
				punteggio = somma
			if punteggio > bv:
				bv = punteggio
				best = c
		if best.is_empty():
			ids = combo[0]
		else:
			ids = best
	var bs := m.bersagli(p, tok, sl, ids)
	if bs.is_empty():
		match sl["effetto"]:
			"attacco":
				_msg.text = "Il nemico non è a portata o non è davanti a te."
			"assalto":
				_msg.text = "Non raggiungi il nemico per caricarlo frontalmente."
			"stordisci":
				_msg.text = "Il nemico è troppo lontano o non ha dadi in mano adatti."
			"sblocca":
				_msg.text = "Non hai altri spazi occupati da liberare."
			"recupera":
				_msg.text = "Non hai dadi in Attesa da recuperare."
			"cura":
				_msg.text = "Non hai ferite da recuperare."
			"pesca":
				_msg.text = "Il mucchio è vuoto."
			"rimetti":
				_msg.text = "Non hai dadi storditi."
			"scambia", "rovescia", "ritocca":
				_msg.text = "Ti servono altri dadi in mano su cui agire."
			_:
				_msg.text = "Nessun bersaglio valido."
		return
	var base := {"tok": tok, "slot": sid, "dadi": ids, "bersagli": bs, "eff": sl["effetto"], "scelti": []}
	if bs[0].has("lato") and not bs[0].has("key"):
		# token con l'esagono: si sceglie il lato toccando una freccia o un pulsante
		attesa = base
		attesa["passo"] = "direzione"
		attesa["pos"] = m.s["g"][p]["pos"]
		var g: Dictionary = m.s["g"][p]
		var lista := []
		var dirs := []
		var voci := []
		for b in bs:
			var bb: Dictionary = b.duplicate()
			bb["dir"] = (int(g["dir"]) + int(b["lato"])) % 6
			bb["pos"] = g["pos"]
			lista.append(bb)
			dirs.append(bb["dir"])
			var bx: Dictionary = b
			voci.append([Motore.NOMI_LATO[int(b["lato"])].capitalize(), func(): _esegui(p, _op_attesa(bx))])
		attesa["bersagli"] = lista
		arena.pulisci_evidenza()
		arena.mostra_direzioni(g["pos"], dirs)
		_mostra_scelte(voci)
		_aggiorna()
		return
	match sl["effetto"]:
		"gira_guardia", "ritocca_guardia", "gira_nemico":
			if bs.size() == 1:
				_esegui(p, {"t": "slot", "tok": tok, "slot": sid, "dadi": ids, "b": bs[0]})
				return
			attesa = base
			attesa["passo"] = "scelta"
			var voci := []
			for b in bs:
				var bx: Dictionary = b
				var t := ""
				match sl["effetto"]:
					"gira_guardia":
						t = "Guardia %s" % Motore.NOMI_LATO[int(b["lato"])]
					"ritocca_guardia":
						var parti: PackedStringArray = String(b["key"]).split("/")
						t = "Rinforza %s" % m.slot_def(parti[0], parti[1])["nome"]
					"gira_nemico":
						t = "Giralo a sinistra" if int(b["d"]) == 1 else "Giralo a destra"
				voci.append([t, func(): _esegui(p, _op_attesa(bx))])
			_mostra_scelte(voci)
			_aggiorna()
		"movimento", "assalto", "passo_ombra", "scarta":
			attesa = base
			attesa["passo"] = "esagono"
			var hex := {}
			for b in bs:
				hex[b["pos"]] = true
			arena.pulisci_evidenza()
			arena.evidenzia(hex.keys(), Color("#5aa0d8") if sl["effetto"] == "movimento" else Color("#d9a441"))
			_aggiorna()
		"ruota":
			attesa = base
			attesa["passo"] = "direzione"
			var dirs := []
			for b in bs:
				dirs.append(b["dir"])
			arena.pulisci_evidenza()
			arena.mostra_direzioni(m.s["g"][p]["pos"], dirs)
			_aggiorna()
		"sblocca":
			if bs.size() == 1:
				_esegui(p, {"t": "slot", "tok": tok, "slot": sid, "dadi": ids, "b": bs[0]})
				return
			attesa = base
			attesa["passo"] = "spazi"
			attesa["n"] = bs[0]["slots"].size()
			var tutte := {}
			for b in bs:
				for k in b["slots"]:
					tutte[k] = true
			attesa["selezionabili"] = tutte.keys()
			_aggiorna()
		"scambia", "rovescia", "ritocca":
			attesa = base
			attesa["passo"] = "dadi"
			attesa["n"] = 2 if sl["effetto"] == "scambia" else 1
			var cand := []
			for d in m.dadi_di(p, "mano"):
				if not ids.has(d["id"]):
					cand.append(d["id"])
			attesa["selezionabili"] = cand
			sel.clear()
			_aggiorna()
		"prepara_attesa":
			if bs.size() == 1:
				_esegui(p, {"t": "slot", "tok": tok, "slot": sid, "dadi": ids, "b": bs[0]})
				return
			attesa = base
			attesa["passo"] = "scelta"
			var voci := []
			for bb in bs:
				var bx: Dictionary = bb
				var dado_a := m.dado(p, int(bx["dado"]))
				voci.append(["Prepara " + str(dado_a["col"]), func(): _esegui(p, _op_attesa(bx))])
			_mostra_scelte(voci)
			_aggiorna()
		"recupera":
			if bs.size() == 1:
				_esegui(p, {"t": "slot", "tok": tok, "slot": sid, "dadi": ids, "b": bs[0]})
				return
			attesa = base
			attesa["passo"] = "scelta"
			var voci := []
			for bb in bs:
				var bx: Dictionary = bb
				var colori := []
				for did in bx["dadi"]:
					colori.append(str(m.dado(p, int(did))["col"]))
				voci.append(["Recupera: " + ", ".join(colori), func(): _esegui(p, _op_attesa(bx))])
			_mostra_scelte(voci)
			_aggiorna()
		"pesca":
			attesa = base
			attesa["passo"] = "mucchio"
			attesa["n"] = bs[0]["dadi"].size()
			_aggiorna()
		"elimina":
			attesa = base
			attesa["passo"] = "colore"
			var voci := []
			for b in bs:
				var col: String = b["col"]
				voci.append(["Dado %s" % col, func(): _esegui(p, _op_attesa({"col": col}))])
			_mostra_scelte(voci)
			_aggiorna()
		_:
			_esegui(p, {"t": "slot", "tok": tok, "slot": sid, "dadi": ids, "b": bs[0]})

func _esagono(h: Vector2i, punto: Vector3) -> void:
	if attesa.is_empty() or not (attesa["passo"] in ["esagono", "direzione"]):
		return
	var p := _umano_decide()
	if p < 0:
		return
	var bs: Array = attesa["bersagli"]
	if attesa["passo"] == "direzione":
		var d := arena.freccia_in(punto)
		if d < 0:
			return
		for b in bs:
			if b["dir"] == d and (not attesa.has("pos") or b["pos"] == attesa["pos"]):
				var bb: Dictionary = b.duplicate()
				if bb.has("lato"):
					bb.erase("dir")
					bb.erase("pos")
				_esegui(p, _op_attesa(bb))
				return
		return
	var qui := []
	for b in bs:
		if b["pos"] == h:
			qui.append(b)
	if qui.is_empty():
		return
	if qui.size() == 1:
		_esegui(p, _op_attesa(qui[0]))
		return
	attesa["passo"] = "direzione"
	attesa["pos"] = h
	var dirs := []
	for b in qui:
		dirs.append(b["dir"])
	arena.pulisci_evidenza()
	arena.evidenzia([h], Color("#5aa0d8"))
	arena.mostra_direzioni(h, dirs)
	_aggiorna()

func _esegui(p: int, op: Dictionary) -> void:
	var prima := _istantanea(p)
	var e := m.applica(p, op)
	if e != "":
		_msg.text = e
		return
	_anima_dadi(p, prima)
	sel.clear()
	attesa = {}
	_mostra_scelte([])
	arena.pulisci_evidenza()
	_dopo_applica()

## Dove si trovano ora sullo schermo i dadi di p: id -> [rettangolo, "vassoio" o "token"].
func _istantanea(p: int) -> Dictionary:
	var out := {}
	if p < 0 or p >= _lati.size():
		return out
	var rv: Dictionary = _lati[p]["vassoio"].rect_globali()
	for id in rv:
		out[id] = [rv[id], "vassoio"]
	for carta in _lati[p]["carte"]:
		for sl in carta.tok.get("slot", []):
			var k := Motore.chiave(carta.tok["id"], sl["id"])
			var occ: Array = m.s["g"][p]["occupati"].get(k, [])
			for i in occ.size():
				out[occ[i]] = [carta.rect_alloggio(sl["id"], i), "token"]
	return out

## I dadi che sono passati dalla mano a un token (o da un token al mucchio) volano al loro posto.
func _anima_dadi(p: int, prima: Dictionary) -> void:
	if prima.is_empty() or not is_instance_valid(_volo):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if m == null or not is_instance_valid(_volo) or p >= _lati.size():
		return
	var dopo := _istantanea(p)
	var va: Vassoio = _lati[p]["vassoio"]
	var ritardo := 0.0
	for id in prima:
		if not dopo.has(id) or prima[id][1] == dopo[id][1]:
			continue
		var da: Rect2 = prima[id][0]
		var a: Rect2 = dopo[id][0]
		if a.size == Vector2.ZERO or da.size == Vector2.ZERO:
			continue
		var d := m.dado(p, id)
		var verso_token: bool = dopo[id][1] == "token"
		var carta_dest: CartaToken = null
		if verso_token:
			for carta in _lati[p]["carte"]:
				for sl in carta.tok.get("slot", []):
					if m.s["g"][p]["occupati"].get(Motore.chiave(carta.tok["id"], sl["id"]), []).has(id):
						carta_dest = carta
			if carta_dest != null:
				carta_dest.in_volo[id] = true
				carta_dest.queue_redraw()
		else:
			va.in_volo[id] = true
			va.queue_redraw()
		_voli += 1
		var dv := DadoVolante.new()
		dv.col = d["col"]
		dv.v = d["v"]
		dv.size = da.size
		dv.position = da.position - _volo.get_global_rect().position
		_volo.add_child(dv)
		var arrivo := a.position - _volo.get_global_rect().position
		var tw := dv.create_tween()
		tw.tween_interval(ritardo)
		tw.tween_method(func(t: float):
			dv.position = (da.position - _volo.get_global_rect().position).lerp(arrivo, t) + Vector2(0, -60.0 * sin(PI * t))
			dv.size = da.size.lerp(a.size, t)
			dv.queue_redraw(), 0.0, 1.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		var id_carta := carta_dest.get_instance_id() if carta_dest != null else 0
		var id_vassoio := va.get_instance_id()
		tw.tween_callback(func():
			var cd = instance_from_id(id_carta) if id_carta != 0 else null
			if cd != null and is_instance_valid(cd):
				cd.in_volo.erase(id)
				cd.queue_redraw()
			var vv = instance_from_id(id_vassoio)
			if vv != null and is_instance_valid(vv):
				vv.in_volo.erase(id)
				vv.queue_redraw()
			_voli -= 1
			dv.queue_free())
		ritardo += 0.08

func _dopo_applica() -> void:
	arena.accoda(m.prendi_eventi())
	var tenuti := []
	for id in sel:
		if m.dado(mostra, id).get("st", "") in ["mano", "conservato"]:
			tenuti.append(id)
	sel = tenuti
	_aggiorna()

func _cmd_spinta() -> void:
	var p := _umano_decide()
	var ids := []
	for id in sel:
		if m.dado(p, id).get("st", "") == "mano":
			ids.append(id)
	_esegui(p, {"t": "spinta", "dadi": ids})

func _cmd_conserva() -> void:
	var p := _umano_decide()
	if sel.size() != 1:
		return
	var d := m.dado(p, sel[0])
	_esegui(p, {"t": "riprendi" if d["st"] == "conservato" else "conserva", "dado": sel[0]})

func _cmd_emergenza() -> void:
	var p := _umano_decide()
	if p < 0 or sel.size() != 1 or m.dado(p, sel[0]).get("st", "") != "mano":
		return
	var occ: Array = m.s["g"][p]["occupati"].keys()
	if occ.is_empty():
		return
	attesa = {"passo": "spazi", "emergenza": true, "dado": sel[0], "n": 1, "scelti": [], "selezionabili": occ}
	_aggiorna()

## Flusso: due vantaggi liberano uno spazio occupato (i suoi dadi vanno in Attesa).
func _cmd_flusso() -> void:
	var p := _umano_decide()
	if p < 0:
		return
	var occ: Array = m.s["g"][p]["occupati"].keys()
	if occ.size() == 1:
		_esegui(p, {"t": "flusso", "key": occ[0]})
		return
	attesa = {"passo": "spazi", "flusso": true, "n": 1, "scelti": [], "selezionabili": occ}
	_aggiorna()

func _cmd_rovescio() -> void:
	var p := _umano_decide()
	if p >= 0:
		_esegui(p, {"t": "rovescio_fluido"})

func _cmd_riposo() -> void:
	var p := _umano_decide()
	if p >= 0:
		_esegui(p, {"t": "riposo"})

func _cmd_passa() -> void:
	var p := _umano_decide()
	if p < 0:
		return
	var occ: Array = m.s["g"][p]["occupati"].keys()
	var n: int = m.s["g"][p]["recupero"]
	if occ.size() <= n:
		_esegui(p, {"t": "passa", "slots": occ})
		return
	attesa = {"passa": true, "passo": "spazi", "n": n, "scelti": [], "selezionabili": occ}
	_aggiorna()

func _cmd_consigliata() -> void:
	var p := _umano_decide()
	if p >= 0 and attesa.get("passo", "") == "mucchio":
		attesa["scelti"] = IA.scelta_mucchio(m, p, attesa["n"])
		_aggiorna()

func _cmd_passo() -> void:
	var p := _umano_decide()
	if p < 0:
		return
	var bs := m.bersagli_passo(p)
	if bs.is_empty():
		return
	attesa = {"passo": "esagono", "passo_base": true, "bersagli": bs, "scelti": []}
	var hex := {}
	for b in bs:
		hex[b["pos"]] = true
	arena.pulisci_evidenza()
	arena.evidenzia(hex.keys(), Color("#5aa0d8"))
	_aggiorna()

func _cmd_conferma() -> void:
	var p := _umano_decide()
	if attesa.get("passo", "") == "mucchio":
		if attesa.get("inizio", false):
			_esegui(p, {"t": "prendi", "dadi": attesa["scelti"].duplicate()})
		else:
			_esegui(p, _op_attesa({"dadi": attesa["scelti"].duplicate()}))
		return
	if attesa.get("passo", "") != "spazi":
		return
	if attesa.get("emergenza", false):
		_esegui(p, {"t": "emergenza", "key": attesa["scelti"][0], "dado": attesa["dado"]})
		return
	if attesa.get("flusso", false):
		_esegui(p, {"t": "flusso", "key": attesa["scelti"][0]})
		return
	if attesa.get("passa", false):
		_esegui(p, {"t": "passa", "slots": attesa["scelti"].duplicate()})
		return
	_esegui(p, _op_attesa({"slots": attesa["scelti"].duplicate()}))

func _cmd_sferra() -> void:
	_esegui(_umano_decide(), {"t": "sferra"})

func _cmd_risolvi() -> void:
	_esegui(_umano_decide(), {"t": "risolvi"})

func _cmd_rilancia() -> void:
	var p := _umano_decide()
	var scelto := -1
	for id in sel:
		var d := m.dado(p, id)
		if d.get("st", "") == "mano" and Motore.colore_ok(d["col"], ["rosso"]):
			scelto = id
	if scelto < 0:
		for d in m.dadi_di(p, "mano"):
			if Motore.colore_ok(d["col"], ["rosso"]):
				scelto = d["id"]
				break
	_esegui(p, {"t": "rilancia", "dado": scelto})

func _cmd_ferma() -> void:
	_esegui(_umano_decide(), {"t": "ferma"})

func _cmd_annulla() -> void:
	attesa = {}
	_mostra_scelte([])
	arena.pulisci_evidenza()
	_aggiorna()

func _cmd_scheda() -> void:
	mostra_avversario = not mostra_avversario
	sel.clear()
	_aggiorna()

func _chiedi_menu() -> void:
	m = null
	menu()

func _mostra_fine() -> void:
	if _fine != null and is_instance_valid(_fine):
		return
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pagina.add_child(centro)
	_fine = centro
	if arena != null and m.s["vinc"] >= 0:
		arena.fine_duello(m.s["vinc"])
	var pan := _pannello(centro)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(520, 0)
	pan.add_child(v)
	var w: int = m.s["vinc"]
	var t := _label("Vince %s" % m.s["g"][w]["nome"], 34, Disegno.GIOCATORI[w], Disegno.font_titolo())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(500, 0)
	v.add_child(t)
	var r := _label("Dopo %d scambi." % m.s["round"], 19)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(r)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	h.add_child(_bottone("Rivincita", func(): battaglia(_pg[0], _pg[1], _scenario, ia), 220))
	if spettatore:
		h.add_child(_bottone("Nuovo scontro", _scontro_casuale, 220))
		if a_ripetizione:
			var nota := _label("Il prossimo scontro casuale parte da solo.", 16)
			nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(nota)
	h.add_child(_bottone("Menu", menu, 220))
