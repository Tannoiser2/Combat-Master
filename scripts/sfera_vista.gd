class_name SferaVista
extends Control
## La sfera di un combattente: al centro i dadi in mano, attorno i tre token base (sei azioni),
## poi l'anello dei misti (tre posti a cavallo di due colori, alternati alle Attese) e l'anello
## esterno (quattro posti, alternati a quattro Attese) che si carica con i dadi dei misti che scattano.
## Tutto disegnato (niente simboli Unicode). premuto() dice cosa è stato toccato.

signal premuto(cosa: Dictionary)

const COL_TOKEN := {
	"rosso": Color("#c8372d"), "giallo": Color("#d9a420"), "blu": Color("#2f6fd0"),
	"arancio": Color("#d96c22"), "verde": Color("#2f9a52"), "viola": Color("#8a4fc4"),
	"scena": Color("#8a6a3e"), "raro": Color("#b8a06a"), "esterno": Color("#b08a3a")
}
## Anello dei misti: centro di ogni posto e delle Attese (sopra i token base).
const POSTO_MISTO := {"rosso": -90.0, "arancio": -30.0, "giallo": 30.0, "verde": 90.0, "blu": 150.0, "viola": 210.0}
const LARGO_MISTO := 57.0
## Anello esterno: quattro posti in diagonale, quattro Attese ai punti cardinali.
## Anello esterno: sei posti a cavallo fra un posto di colore base e il misto accanto (rosso|arancio …);
## le Attese nei buchi, sopra il centro di ogni posto del mediano.
const POSTO_ESTERNO := [-60.0, 0.0, 60.0, 120.0, 180.0, 240.0]
const LARGO_ESTERNO := 62.0
const COL_DADO := {"r": "rosso", "g": "giallo", "b": "blu", "n": "bianco", "x": "bianco"}
const COL_SETTORE := {"F": "rosso", "A": "giallo", "P": "blu"}
## Angoli in gradi (0 = destra, 90 = giù): Forza in alto, Agilità in basso a destra, Percezione in basso a sinistra.
const AZ_ANG := {"colpo": [-150, -90], "presa": [-90, -30], "passo": [-30, 30], "scarto": [30, 90], "parata": [90, 150], "leggi": [150, 210]}
const POSTO := {"rosso": -90, "arancio": -30, "giallo": 30, "verde": 90, "blu": 150, "viola": 210}
const NOMI_AZ := {"colpo": "Colpo", "presa": "Presa", "passo": "Passo", "scarto": "Scarto", "parata": "Parata", "leggi": "Leggere"}
const FACCE := {"colpo": "Colpo pesante", "presa": "Presa forte", "passo": "Balzo", "scarto": "Riposizionarsi", "parata": "Parata ferrea", "leggi": "Lettura profonda"}

var m: Sfera
var p := 0
var attiva := true
var sel_dado := -1
var sel_fermo := -1
var evid_azioni: Array = []
var evid_token: Array = []
var evid_fermi: Array = []
var evid_raro := false
var evid_dadi: Array = []
var evid_attesa := false
## con una scelta in corso, tutto ciò che non è illuminato si spegne
var filtro := false
## token che si capovolgono sulla faccia potenziata: chiave -> avanzamento 0..1
var _flip := {}
var _pot_prima := {}
const DURATA_FLIP := 0.55
## Trasformazione di base per i disegni (serve al capovolgimento dei token).
static var _base := Transform2D.IDENTITY
## Dadi che scivolano da un posto all'altro: [{da, a, c, v, t}] e chiavi dei posti d'arrivo da non disegnare.
var _scivoli: Array = []
var _prima: Array = []
var _prima_p := -1
var _nascosti := {}
const DURATA_SCIVOLO := 0.42

func _process(dt: float) -> void:
	if _scivoli.is_empty() and _flip.is_empty():
		return
	for x in _scivoli:
		x["t"] = float(x["t"]) + dt / DURATA_SCIVOLO
	_scivoli = _scivoli.filter(func(x): return float(x["t"]) < 1.0)
	for k in _flip.keys():
		_flip[k] = float(_flip[k]) + dt / DURATA_FLIP
		if float(_flip[k]) >= 1.0:
			_flip.erase(k)
	queue_redraw()

## Misura unica dei dadi su tutta la sfera.
func lato_dado() -> float:
	return clampf(_R() * 0.088, 14.0, 30.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func imposta(motore: Sfera, giocatore: int) -> void:
	m = motore
	p = giocatore
	queue_redraw()

# ------------------------------------------------------------------ geometria

func _centro() -> Vector2:
	return size / 2.0

func _R() -> float:
	return minf(size.x, size.y) / 2.0 - 4.0

func raggi() -> Array:
	var R := _R()
	return [R * 0.25, R * 0.49, R * 0.75, R * 0.995]

static func punto(c: Vector2, r: float, a_gradi: float) -> Vector2:
	var a := deg_to_rad(a_gradi)
	return c + Vector2(cos(a), sin(a)) * r

static func settore(c: Vector2, ri: float, ro: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var passi := maxi(6, int(absf(a1 - a0) / 4.0))
	for i in passi + 1:
		pts.append(punto(c, ro, lerpf(a0, a1, float(i) / passi)))
	for i in range(passi, -1, -1):
		pts.append(punto(c, ri, lerpf(a0, a1, float(i) / passi)))
	return pts

## Testo curvo lungo l'arco (dritto per chi guarda): si rimpicciolisce finché non ci sta.
static func testo_arco(ci: CanvasItem, c: Vector2, r: float, a_gradi: float, larghezza_gradi: float, t: String, fs: int, col: Color, f: Font = null) -> void:
	if f == null:
		f = Disegno.font_titolo()
	var arco := deg_to_rad(larghezza_gradi) * r * 0.92
	var dim := fs
	while dim > 9 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, dim).x > arco:
		dim -= 1
	# ancora troppo lungo: tiene le prime parole, poi accorcia con il punto
	var parole := t.split(" ", false)
	while parole.size() > 1 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, dim).x > arco:
		parole.remove_at(parole.size() - 1)
		if parole.size() > 1 and String(parole[parole.size() - 1]).length() <= 2:
			parole.remove_at(parole.size() - 1)
		t = " ".join(parole)
	while t.length() > 3 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, dim).x > arco:
		t = t.substr(0, t.length() - 2) + "."
	var a := deg_to_rad(a_gradi)
	var giu := sin(a) > 0.15
	# lettera per lettera lungo l'arco, così il testo segue la curva
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, dim).x
	var ang_tot := w / r
	var verso := -1.0 if giu else 1.0
	var start := a - verso * ang_tot / 2.0
	var x := 0.0
	for ch in t:
		var cw := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, dim).x
		var am := start + verso * (x + cw / 2.0) / r
		var pos := c + Vector2(cos(am), sin(am)) * r
		var rot := am + PI / 2.0 if not giu else am - PI / 2.0
		ci.draw_set_transform_matrix(_base * Transform2D(rot, pos))
		ci.draw_string(f, Vector2(-cw / 2.0, dim * 0.36), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, dim, col)
		x += cw
	ci.draw_set_transform_matrix(_base)

static func freccia_su(ci: CanvasItem, pos: Vector2, a_gradi: float, l: float, col: Color) -> void:
	var a := deg_to_rad(a_gradi)
	var d := Vector2(cos(a), sin(a))
	var n := Vector2(-d.y, d.x)
	ci.draw_colored_polygon(PackedVector2Array([pos + d * l, pos - d * l * 0.4 + n * l * 0.7, pos - d * l * 0.4 - n * l * 0.7]), col)

## Un token curvo: settore d'anello colorato, nome lungo l'arco, posti per i dadi, freccia e stato.
## e può essere vuoto (token di catalogo, senza stato di gioco).
static func disegna_token(ci: CanvasItem, c: Vector2, ri: float, ro: float, a0: float, a1: float, t: Dictionary, e: Dictionary, evid := false, colore := "", nascosti: Array = [], ds := 0.0, spento := false) -> void:
	var col: Color = COL_TOKEN.get(colore if colore != "" else String(t.get("col", "scena")), COL_TOKEN["scena"])
	var pronto: bool = e.get("pronto", false)
	var bloccato: bool = e.get("bloccato", false)
	var pot: bool = e.get("pot", false)
	var base := col.darkened(0.55) if not bloccato else Color(0.25, 0.23, 0.21)
	var alto := col.darkened(0.3) if not bloccato else Color(0.32, 0.3, 0.28)
	if pot:
		# faccia potenziata: colori più accesi, bordo d'oro
		base = col.darkened(0.25)
		alto = col.lightened(0.05)
	if evid:
		base = base.lightened(0.22)
		alto = alto.lightened(0.22)
	if spento:
		base = base.darkened(0.55)
		alto = alto.darkened(0.55)
	ci.draw_colored_polygon(settore(c, ri, ro, a0, a1), base)
	ci.draw_colored_polygon(settore(c, ri + (ro - ri) * 0.58, ro, a0, a1), alto)
	var bordo := Disegno.ORO if (pronto or evid or pot) else col.lightened(0.2)
	if spento:
		bordo = bordo.darkened(0.5)
	var pts := settore(c, ri, ro, a0, a1)
	pts.append(pts[0])
	ci.draw_polyline(pts, bordo, 3.5 if evid else (2.5 if (pronto or pot) else 1.5), true)
	var am := (a0 + a1) / 2.0
	var span := absf(a1 - a0)
	var testo_col := Color.WHITE if not spento else Color(1, 1, 1, 0.45)
	var fs := int(clampf((ro - ri) * 0.3, 10, 18))
	testo_arco(ci, c, ri + (ro - ri) * 0.8, am, span, String(t.get("nome", "")), fs, testo_col)
	testo_arco(ci, c, ri + (ro - ri) * 0.5, am, span, breve(t, pot), maxi(10, fs - 1), Disegno.ORO if pot else Color(1, 0.96, 0.86, 1.0 if not spento else 0.4), Disegno.font_testo())
	# solo i dadi che ci sono, della misura di tutti gli altri
	var dadi: Array = e.get("dadi", [])
	if ds <= 0.0:
		ds = clampf((ro - ri) * 0.42, 12, 26)
	var rects := rect_dadi(c, ri, ro, a0, a1, dadi.size(), ds)
	for i in dadi.size():
		if not nascosti.has(i):
			Disegno.dado(ci, rects[i], COL_DADO.get(String(dadi[i]["c"]), "bianco"), int(dadi[i]["v"]))
	# stato
	var st := ""
	if bloccato:
		st = "BLOCCATO"
	elif pronto:
		st = "ARMATA" if String(t.get("modo", "")) == "armato" else "PRONTO"
	if t.get("a", {}).get("varianti", false):
		st = (st + ", " if st != "" else "") + String(e.get("variante", "irimi")).to_upper()
	if st != "":
		testo_arco(ci, c, ro + 9, am, span, st, 11, Disegno.ORO if not bloccato else Color(0.7, 0.7, 0.7))

## L'effetto di un'azione in poche parole, da scrivere sul token.
static func breve(t: Dictionary, pot := false) -> String:
	if not t.has("a"):
		return String(t.get("breve", ""))
	var a: Dictionary = t["a"].duplicate()
	if pot:
		for k in a.get("pot", {}):
			a[k] = a["pot"][k]
	var dn := ""
	var d = a.get("danno", null)
	if d != null:
		if typeof(d) == TYPE_STRING:
			dn = {"dado": "dado", "somma": "somma", "meta": "metà", "quarto": "un quarto"}.get(String(d), "")
		else:
			dn = str(int(d))
		var piu := int(a.get("piu", 0))
		if piu != 0:
			dn += ("+%d" % piu) if piu > 0 else str(piu)
	var extra := []
	if int(a.get("proietta", 0)) > 0:
		extra.append("proietta %d" % int(a["proietta"]))
	if int(a.get("spinta", 0)) > 0:
		extra.append("spinge %d" % int(a["spinta"]))
	if int(a.get("svant", 0)) > 0:
		extra.append("%d svant." % int(a["svant"]))
	if int(a.get("vant", 0)) > 0:
		extra.append("+%d vant." % int(a["vant"]))
	if int(a.get("cura", 0)) > 0:
		extra.append("cura %d" % int(a["cura"]))
	if int(a.get("pesca", 0)) > 0:
		extra.append("riprendi %d" % int(a["pesca"]))
	if a.get("a_terra", false):
		extra.append("a terra")
	if a.has("togli"):
		extra.append("toglie un dado")
	var out := ""
	match String(a.get("tipo", "")):
		"colpo":
			out = ("Carica " if int(a.get("entra", 0)) > 0 else ("Alle spalle " if a.get("alle_spalle", false) else "Colpo ")) + dn
		"presa":
			out = "Presa" + ((" " + dn) if dn != "" else "")
		"trappola":
			out = "Trappola" + (" prese" if String(a.get("contro", "")) == "presa" else (" colpi" if String(a.get("contro", "")) == "colpo" else ""))
			if int(a.get("riduci", 0)) > 0:
				extra.push_front("-%d" % int(a["riduci"]))
			elif a.get("schiva", false):
				extra.push_front("schiva")
		"guardia":
			out = "Guardia -%d" % int(a.get("riduci", 0))
		"effetto":
			out = ""
	if extra.size() > 0:
		out = (out + ", " if out != "" else "") + ", ".join(extra.slice(0, 2))
	return out

# ------------------------------------------------------------------ disposizione

## Posizioni dei token: [{i, a0, a1, anello}] (i = -1 per un pezzo vuoto, con "posto" e "colori").
## Mediano: sei posti da due pezzi, nell'ordine dell'assetto; esterno: sei posti da due metà.
func posizioni_token() -> Array:
	var out := []
	if m == null:
		return out
	var g: Dictionary = m.s["g"][p]
	var est: Array = g["esterni"]
	var per_parte := {}
	var scena := []
	for i in est.size():
		var e: Dictionary = est[i]
		if String(e["id"]).begins_with("scena_"):
			scena.append(i)
		else:
			per_parte["%s:%d" % [e["id"], int(e.get("parte", 0))]] = i
	var u2 := _unita(2)
	var ass: Dictionary = g.get("assetto", {})
	for posto in POSTO_MISTO:
		var c: float = POSTO_MISTO[posto]
		var a0 := c - u2
		var q := 0
		for id in ass.get(posto, []):
			for k in m.tok(id)["azioni"].size():
				var chiave := "%s:%d" % [id, k]
				var x := {"i": per_parte.get(chiave, -1), "a0": a0 + u2 * q + 0.4, "a1": a0 + u2 * (q + 1) - 0.4, "anello": 2, "posto": posto, "colori": [posto]}
				if x["i"] < 0:
					x["vuoto"] = "scattato"
				out.append(x)
				q += 1
		while q < 2:
			out.append({"i": -1, "a0": a0 + u2 * q + 0.4, "a1": a0 + u2 * (q + 1) - 0.4, "anello": 2, "posto": posto, "colori": [posto], "vuoto": "libero"})
			q += 1
	var u3 := _unita(3)
	var ass3: Dictionary = g.get("assetto3", {})
	for k in POSTO_ESTERNO.size():
		var c: float = POSTO_ESTERNO[k]
		var coppia: Array = Sfera.COPPIE[k]
		if ass3.has(k):
			var id: String = ass3[k]
			for h in 2:
				var x := {"i": per_parte.get("%s:%d" % [id, h], -1), "a0": c - u3 + u3 * h + 0.3, "a1": c + u3 * h - 0.3, "anello": 3, "colori": [coppia[h]]}
				if x["i"] < 0:
					x["vuoto"] = "scattato"
				out.append(x)
		else:
			var sc := -1
			for i in scena:
				if int(est[i].get("posto3", -1)) == k:
					sc = i
			if sc >= 0:
				out.append({"i": sc, "a0": c - u3 + 0.3, "a1": c + u3 - 0.3, "anello": 3})
			else:
				out.append({"i": -1, "a0": c - u3 + 0.3, "a1": c + u3 - 0.3, "anello": 3, "colori": coppia, "vuoto": "libero"})
	return out

## Gradi di un pezzo da un'azione nell'anello dato: lungo quanto nell'anello mediano (metà posto).
func _unita(anello: int) -> float:
	var r := raggi()
	var u := 30.0 - 0.6
	if anello == 2:
		return u
	var mid2: float = (float(r[1]) + float(r[2])) / 2.0
	var mid3: float = (float(r[2]) + float(r[3])) / 2.0
	return u * mid2 / mid3

## Posti dei dadi di un token, lungo l'arco interno.
static func rect_dadi(c: Vector2, ri: float, ro: float, a0: float, a1: float, n: int, ds := 0.0) -> Array:
	var out := []
	var am := (a0 + a1) / 2.0
	if ds <= 0.0:
		ds = clampf((ro - ri) * 0.42, 12, 26)
	var rr := ri + ds * 0.62
	# sempre della stessa misura: se non stanno in fila si accavallano un poco
	var passo := minf(rad_to_deg(ds * 1.12 / rr), absf(a1 - a0) * 0.92 / maxi(1, n))
	for i in n:
		var pc := punto(c, rr, am + (float(i) - (n - 1) / 2.0) * passo)
		out.append(Rect2(pc - Vector2(ds, ds) / 2.0, Vector2(ds, ds)))
	return out

## Zona d'Attesa: settore tratteggiato con i dadi che aspettano la pausa.
func _attesa(c: Vector2, ri: float, ro: float, a0: float, a1: float, dadi: Array) -> void:
	draw_colored_polygon(settore(c, ri, ro, a0, a1), Color(0.2, 0.17, 0.14, 0.95) if not evid_attesa else Color(0.36, 0.28, 0.16, 0.95))
	if evid_attesa:
		var pe := settore(c, ri, ro, a0, a1)
		pe.append(pe[0])
		draw_polyline(pe, Disegno.ORO, 3.0, true)
	# tratteggio diagonale: brevi segmenti dentro il settore
	var passi := 9
	for k in passi:
		var a := lerpf(a0, a1, (k + 0.5) / passi)
		draw_line(punto(c, ri + 3, a - 2.5), punto(c, ro - 3, a + 2.5), Color(0.5, 0.43, 0.34, 0.55), 2.0, true)
	var pts := settore(c, ri, ro, a0, a1)
	pts.append(pts[0])
	draw_polyline(pts, Color(0.6, 0.5, 0.35, 0.7), 1.2, true)
	testo_arco(self, c, ri + (ro - ri) * 0.78, (a0 + a1) / 2.0, absf(a1 - a0), "ATTESA", 10, Color(0.85, 0.78, 0.62, 0.8))
	_dadi_attesa(c, (ri + ro) / 2.0 - (ro - ri) * 0.08, (a0 + a1) / 2.0, absf(a1 - a0), lato_dado(), dadi)

func _dadi_attesa(c: Vector2, r: float, am: float, span: float, ds: float, dadi: Array) -> void:
	var rects := _rect_attesa(c, r, am, span, ds, dadi.size())
	for i in dadi.size():
		if _nascosti.has("att:%d:%d" % [int(am), i]):
			continue
		Disegno.dado(self, rects[i], COL_DADO.get(String(dadi[i]), "bianco"), 0, "usato")

## Dadi in Attesa: in fila lungo l'arco, su due file se non ci stanno.
func _rect_attesa(c: Vector2, r: float, am: float, span: float, ds: float, n: int) -> Array:
	var out := []
	if n == 0:
		return out
	var per_fila := maxi(1, int(span * 0.85 / rad_to_deg(ds * 1.1 / r)))
	var file := int(ceil(n / float(per_fila)))
	var dd := ds
	for i in n:
		var f := i / per_fila
		var nf := mini(per_fila, n - f * per_fila)
		var rf := r + (f - (file - 1) / 2.0) * dd * 1.08
		var passo := rad_to_deg(dd * 1.12 / rf)
		var pc := punto(c, rf, am + (i % per_fila - (nf - 1) / 2.0) * passo)
		out.append(Rect2(pc - Vector2(dd, dd) / 2.0, Vector2(dd, dd)))
	return out

## Posto vuoto: solo il contorno, nei colori che accetta.
func _posto_vuoto(c: Vector2, ri: float, ro: float, a0: float, a1: float, colori: Array, testo: String) -> void:
	draw_colored_polygon(settore(c, ri, ro, a0, a1), Color(0.12, 0.1, 0.08, 0.9))
	var n := colori.size()
	for k in n:
		var b0 := lerpf(a0, a1, float(k) / n)
		var b1 := lerpf(a0, a1, float(k + 1) / n)
		draw_arc(c, ri + 3, deg_to_rad(b0), deg_to_rad(b1), 12, COL_TOKEN[colori[k]].darkened(0.1), 4.0, true)
	var pts := settore(c, ri, ro, a0, a1)
	pts.append(pts[0])
	draw_polyline(pts, Color(0.55, 0.47, 0.35, 0.6), 1.0, true)
	testo_arco(self, c, (ri + ro) / 2.0, (a0 + a1) / 2.0, absf(a1 - a0), testo, 10, Color(0.8, 0.74, 0.6, 0.6))

func _posizioni_dadi() -> Array:
	var out := []
	if m == null:
		return out
	var mano: Array = m.s["g"][p]["mano"]
	var n := mano.size()
	var r := raggi()
	var cols := 2 if n <= 4 else 3
	var righe := int(ceil(n / float(cols)))
	cols = 2 if n <= 4 else (3 if n <= 9 else 4)
	righe = int(ceil(n / float(cols)))
	var ds: float = lato_dado()
	var gap := ds * 0.16
	var c := _centro()
	for i in n:
		var riga := i / cols
		var nel := mini(cols, n - riga * cols)
		var col := i % cols
		var x := c.x + (col - (nel - 1) / 2.0) * (ds + gap) - ds / 2.0
		var y := c.y + (riga - (righe - 1) / 2.0) * (ds + gap) - ds / 2.0
		out.append({"id": int(mano[i]["id"]), "rect": Rect2(x, y, ds, ds), "d": mano[i]})
	return out

func _posizioni_fermi() -> Array:
	var out := []
	if m == null:
		return out
	var fermi: Array = m.s["g"][p]["fermi"]
	var r := raggi()
	var conta := {}
	var ds: float = lato_dado()
	for j in fermi.size():
		var az: String = fermi[j]["az"]
		var k: int = conta.get(az, 0)
		conta[az] = k + 1
		var aa: Array = AZ_ANG[az]
		var a := float(aa[0]) + 9 + k * rad_to_deg(ds * 1.1 / (r[0] + (r[1] - r[0]) * 0.28))
		var pc := punto(_centro(), r[0] + (r[1] - r[0]) * 0.28, a)
		out.append({"j": j, "rect": Rect2(pc - Vector2(ds, ds) / 2.0, Vector2(ds, ds)), "f": fermi[j]})
	return out

# ------------------------------------------------------------------ disegno

func _draw() -> void:
	var c := _centro()
	var r := raggi()
	var R := _R()
	draw_circle(c, R, Color(0.07, 0.055, 0.045, 0.9))
	draw_arc(c, r[3], 0, TAU, 96, Color(0.55, 0.45, 0.3, 0.6), 1.5, true)
	# settori e azioni base
	if m == null:
		return
	var g: Dictionary = m.s["g"][p]
	_nascosti = _scivola_prepara(posizioni_token(), r[1] + 14, r[2] - 3, r[2] + 3, r[3] - 2)
	for az in AZ_ANG:
		var aa: Array = AZ_ANG[az]
		var sett: String = Sfera.AZ_SETTORE[az]
		var col: Color = COL_TOKEN[COL_SETTORE[sett]]
		var evid: bool = evid_azioni.has(az)
		draw_colored_polygon(settore(c, r[0] + 2, r[1] - 2, aa[0] + 0.8, aa[1] - 0.8), col.darkened(0.12 if evid else (0.8 if filtro else 0.62)))
		var pts := settore(c, r[0] + 2, r[1] - 2, aa[0] + 0.8, aa[1] - 0.8)
		pts.append(pts[0])
		draw_polyline(pts, Disegno.ORO if evid else col.darkened(0.2), 2.5 if evid else 1.0, true)
		var girata: bool = g["girate"].has(az)
		var nome: String = FACCE[az] if girata else NOMI_AZ[az]
		testo_arco(self, c, r[0] + (r[1] - r[0]) * 0.72, (aa[0] + aa[1]) / 2.0, 58, nome, int(clampf(R * 0.05, 11, 17)), Disegno.ORO if girata else Disegno.PERGAMENA)
	for sett in ["F", "A", "P"]:
		var ang: float = {"F": -90.0, "A": 30.0, "P": 150.0}[sett]
		var nomi := {"F": "FORZA", "A": "AGILITÀ", "P": "PERCEZIONE"}
		testo_arco(self, c, r[1] + 7, ang, 90, nomi[sett], 10, COL_TOKEN[COL_SETTORE[sett]].lightened(0.3))
	# centro: il mucchio
	draw_circle(c, r[0], Color(0.16, 0.13, 0.1))
	draw_arc(c, r[0], 0, TAU, 64, Disegno.ORO.darkened(0.3), 2.0, true)
	var pd := _posizioni_dadi()
	if pd.is_empty():
		Disegno.testo(self, c + Vector2(-r[0], 5), "nessun dado", 13, Color(1, 1, 1, 0.5), null, r[0] * 2, HORIZONTAL_ALIGNMENT_CENTER)
	for x in pd:
		if _nascosti.has("mano:%d" % int(x["id"])):
			continue
		var spento: bool = filtro and not evid_dadi.has(int(x["id"])) and int(x["id"]) != sel_dado
		Disegno.dado(self, x["rect"], COL_DADO[String(x["d"]["c"])], int(x["d"]["v"]), "usato" if spento else "pronto", int(x["id"]) == sel_dado)
		if evid_dadi.has(int(x["id"])) and int(x["id"]) != sel_dado:
			draw_rect(x["rect"].grow(3), Disegno.ORO, false, 2.0)
	# dadi fermi sulle azioni base
	for x in _posizioni_fermi():
		if _nascosti.has("fermo:%d" % int(x["j"])):
			continue
		Disegno.dado(self, x["rect"], COL_DADO[String(x["f"]["c"])], int(x["f"]["v"]), "usato", int(x["j"]) == sel_fermo)
		if evid_fermi.has(int(x["j"])):
			draw_rect(x["rect"].grow(3), Disegno.ORO, false, 2.0)
	# anello mediano: sei posti da due pezzi; anello esterno: sei posti a cavallo, Attese nei buchi
	var ri2: float = r[1] + 14
	var ro2: float = r[2] - 3
	var ri3: float = r[2] + 3
	var ro3: float = r[3] - 2
	var att: Dictionary = g.get("attesa", {})
	var pos := posizioni_token()
	var est: Array = g["esterni"]
	var u3 := _unita(3)
	var buco := 30.0 - u3
	for posto in POSTO_MISTO:
		var am: float = POSTO_MISTO[posto]
		_attesa(c, ri3, ro3, am - buco + 0.8, am + buco - 0.8, att.get(posto, []))
	for k in pos.size():
		var pt: Dictionary = pos[k]
		var ri: float = ri2 if pt["anello"] == 2 else ri3
		var ro: float = ro2 if pt["anello"] == 2 else ro3
		if int(pt["i"]) < 0:
			_posto_vuoto(c, ri, ro, pt["a0"], pt["a1"], pt["colori"], "scattato" if pt.get("vuoto", "") == "scattato" else ("posto libero" if pt["anello"] == 3 else "libero"))
			continue
		var e: Dictionary = est[pt["i"]]
		var chiave := "%s:%d" % [e["id"], int(e.get("parte", 0))]
		var ev: bool = evid_token.has(int(pt["i"]))
		var spento: bool = filtro and not ev
		if _flip.has(chiave):
			# capovolgimento: il pezzo si stringe sul suo asse, si gira e torna con la faccia potenziata
			var t := float(_flip[chiave])
			var mid := (float(pt["a0"]) + float(pt["a1"])) / 2.0
			var cp := punto(c, (ri + ro) / 2.0, mid)
			var ang := deg_to_rad(mid)
			var sc := absf(cos(PI * t))
			_base = Transform2D(0, cp) * Transform2D(ang, Vector2.ZERO) * Transform2D(0, Vector2(1, maxf(0.04, sc)), 0, Vector2.ZERO) * Transform2D(-ang, Vector2.ZERO) * Transform2D(0, -cp)
			draw_set_transform_matrix(_base)
			var faccia := e.duplicate()
			faccia["pot"] = t >= 0.5
			disegna_token(self, c, ri, ro, pt["a0"], pt["a1"], m.te(e), faccia, ev, "", [], lato_dado(), spento)
			_base = Transform2D.IDENTITY
			draw_set_transform_matrix(_base)
		else:
			disegna_token(self, c, ri, ro, pt["a0"], pt["a1"], m.te(e), e, ev, "", _nascosti.get("tok:%d" % int(pt["i"]), []), lato_dado(), spento)
		if pt["anello"] == 2 or true:
			_pot_nota(chiave, e)
	_scivola_disegna()

## Segna quando un token passa alla faccia potenziata, per farlo capovolgere.
func _pot_nota(chiave: String, e: Dictionary) -> void:
	var ora: bool = e.get("pot", false)
	if _pot_prima.has(chiave) and ora and not _pot_prima[chiave]:
		_flip[chiave] = 0.0
	_pot_prima[chiave] = ora

# ------------------------------------------------------------------ dadi che scivolano

## Dove sono adesso tutti i dadi visibili: [{k, c, v, rect}].
func _istantanea(pos: Array, ri2: float, ro2: float, ri3: float, ro3: float) -> Array:
	var out := []
	var c := _centro()
	var g: Dictionary = m.s["g"][p]
	for x in _posizioni_dadi():
		out.append({"k": "mano:%d" % int(x["id"]), "c": String(x["d"]["c"]), "v": int(x["d"]["v"]), "rect": x["rect"]})
	for x in _posizioni_fermi():
		out.append({"k": "fermo:%d" % int(x["j"]), "c": String(x["f"]["c"]), "v": int(x["f"]["v"]), "rect": x["rect"]})
	var est: Array = g["esterni"]
	for pt in pos:
		if int(pt["i"]) < 0:
			continue
		var e: Dictionary = est[pt["i"]]
		var dadi: Array = e["dadi"]
		if dadi.is_empty():
			continue
		var ri: float = ri2 if pt["anello"] == 2 else ri3
		var ro: float = ro2 if pt["anello"] == 2 else ro3
		var rects := rect_dadi(c, ri, ro, pt["a0"], pt["a1"], dadi.size(), lato_dado())
		for j in dadi.size():
			out.append({"k": "tok:%d" % int(pt["i"]), "j": j, "id": "%s:%d" % [e["id"], int(e.get("parte", 0))], "c": String(dadi[j]["c"]), "v": int(dadi[j]["v"]), "rect": rects[j]})
	var att: Dictionary = g.get("attesa", {})
	var buco := 30.0 - _unita(3)
	for posto in POSTO_MISTO:
		var am: float = POSTO_MISTO[posto]
		var dadi: Array = att.get(posto, [])
		var rr := (ri3 + ro3) / 2.0 - (ro3 - ri3) * 0.08
		var rects := _rect_attesa(c, rr, am, 2.0 * buco - 1.6, lato_dado(), dadi.size())
		for j in dadi.size():
			out.append({"k": "att:%d:%d" % [int(am), j], "c": String(dadi[j]), "v": 0, "rect": rects[j]})
	return out

## Confronta con l'ultima immagine: i dadi spariti da un posto e comparsi in un altro scivolano.
## Restituisce i posti d'arrivo da non disegnare finché il dado non è arrivato.
func _scivola_prepara(pos: Array, ri2: float, ro2: float, ri3: float, ro3: float) -> Dictionary:
	var ora := _istantanea(pos, ri2, ro2, ri3, ro3)
	if _prima_p != p:
		_prima_p = p
		_prima = ora
		_scivoli = []
	var firma := func(x: Dictionary) -> String:
		return "%s|%s|%s|%d|%d" % [x["k"], x.get("id", ""), x["c"], int(x["v"]), int(x.get("j", 0))]
	var vecchi := {}
	for x in _prima:
		vecchi[firma.call(x)] = x
	var nuovi := {}
	for x in ora:
		nuovi[firma.call(x)] = x
	var partiti := []
	for f in vecchi:
		if not nuovi.has(f):
			partiti.append(vecchi[f])
	for f in nuovi:
		if vecchi.has(f):
			continue
		var x: Dictionary = nuovi[f]
		var bi := -1
		var bd := INF
		for q in partiti.size():
			var y: Dictionary = partiti[q]
			if y["c"] != x["c"] and not (y["c"] == "n" or x["c"] == "n"):
				continue
			var dd: float = (y["rect"].get_center() - x["rect"].get_center()).length() - (40.0 if int(y["v"]) == int(x["v"]) else 0.0)
			if dd < bd:
				bd = dd
				bi = q
		if bi < 0:
			continue
		var da: Dictionary = partiti[bi]
		partiti.remove_at(bi)
		if (da["rect"].get_center() - x["rect"].get_center()).length() < 3.0:
			continue
		_scivoli.append({"da": da["rect"], "a": x["rect"], "c": x["c"], "v": int(x["v"]), "t": 0.0, "k": x["k"], "j": int(x.get("j", -1))})
	_prima = ora
	var nasc := {}
	for sc in _scivoli:
		if String(sc["k"]).begins_with("tok:"):
			if not nasc.has(sc["k"]):
				nasc[sc["k"]] = []
			nasc[sc["k"]].append(int(sc["j"]))
		else:
			nasc[sc["k"]] = true
	return nasc

func _scivola_disegna() -> void:
	for sc in _scivoli:
		var t := clampf(float(sc["t"]), 0.0, 1.0)
		var e := t * t * (3.0 - 2.0 * t)
		var da: Rect2 = sc["da"]
		var a: Rect2 = sc["a"]
		var cc := _centro()
		# un arco leggero verso l'esterno, così il dado scivola sulla sfera invece di tagliarla
		var p0 := da.get_center()
		var p1 := a.get_center()
		var mezzo := (p0 + p1) / 2.0
		var fuori := (mezzo - cc).normalized() * minf(30.0, (p1 - p0).length() * 0.18)
		var pc := p0.lerp(mezzo + fuori, e).lerp((mezzo + fuori).lerp(p1, e), e)
		var dim := Vector2(lato_dado(), lato_dado())
		Disegno.dado(self, Rect2(pc - dim / 2.0, dim), COL_DADO.get(String(sc["c"]), "bianco"), int(sc["v"]), "pronto" if int(sc["v"]) > 0 else "usato")

# ------------------------------------------------------------------ tocco

func _gui_input(ev: InputEvent) -> void:
	if not attiva or m == null:
		return
	var premi := false
	var pos := Vector2.ZERO
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		premi = true
		pos = ev.position
	elif ev is InputEventScreenTouch and ev.pressed:
		premi = true
		pos = ev.position
	if not premi:
		return
	var cosa := cosa_in(pos)
	if cosa.is_empty() and (pos - _centro()).length() <= _R():
		cosa = {"tipo": "vuoto"}
	if not cosa.is_empty():
		accept_event()
		premuto.emit(cosa)

func cosa_in(pos: Vector2) -> Dictionary:
	for x in _posizioni_dadi():
		if x["rect"].grow(4).has_point(pos):
			return {"tipo": "dado", "id": x["id"]}
	for x in _posizioni_fermi():
		if x["rect"].grow(4).has_point(pos):
			return {"tipo": "fermo", "j": x["j"]}
	var c := _centro()
	var r := raggi()
	var v := pos - c
	var d := v.length()
	var a := rad_to_deg(atan2(v.y, v.x))
	if a < -150:
		a += 360
	if d > r[0] and d < r[1]:
		for az in AZ_ANG:
			if a >= AZ_ANG[az][0] and a < AZ_ANG[az][1]:
				return {"tipo": "azione", "az": az}
	if d >= r[2] and d <= r[3]:
		var buco := 30.0 - _unita(3)
		for posto in POSTO_MISTO:
			if absf(wrapf(a - float(POSTO_MISTO[posto]), -180.0, 180.0)) <= buco:
				return {"tipo": "attesa", "posto": posto}
	if d >= r[1] and d <= r[3]:
		var anello := 2 if d < r[2] else 3
		for pt in posizioni_token():
			if int(pt["i"]) < 0:
				continue
			var mid: float = (pt["a0"] + pt["a1"]) / 2.0
			if pt["anello"] == anello and absf(wrapf(a - mid, -180.0, 180.0)) <= absf(pt["a1"] - pt["a0"]) / 2.0 + 1.0:
				return {"tipo": "token", "i": pt["i"]}

	return {}
