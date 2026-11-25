class_name Arena3D
extends Node3D
## Arena 3D a esagoni: tessere, colonne, bracieri, combattenti, evidenziazioni,
## animazioni degli eventi del motore e telecamera orbitale (mouse e tocco su iPad:
## un dito trascina, due dita pizzicano per lo zoom e ruotano).

signal esagono_premuto(h: Vector2i, punto: Vector3)
signal animazioni_finite

const S := 1.0
const SQ3 := 1.7320508

var m: Motore
var blocca_input: Callable = func(_p): return false

var pivot := Node3D.new()
var cam := Camera3D.new()
var yaw := 0.0
var pitch := deg_to_rad(52.0)
var distanza := 15.0
var spostamento_v := 0.0     # sposta l'immagine in su per lasciare spazio ai pannelli in basso
var spostamento_h := 0.0     # e a sinistra per il diario

var _tessere := Node3D.new()
var _evid := Node3D.new()
var _effetti := Node3D.new()
var figure: Array[Node3D] = []
var _corpi: Array[MeshInstance3D] = []
var _frecce: Array = []        # [Vector3 centro, dir]

var _coda: Array = []
var _occupato := false
var _n_colpi := 0
var _colpo := {}   # colpo dichiarato che aspetta l'esito: {att, dif, clip, para}

var _tocchi := {}
var _trascinato := false
var _premuto_pos := Vector2.ZERO
var _tasto := -1

func _ready() -> void:
	add_child(pivot)
	pivot.add_child(cam)
	cam.fov = 45
	cam.current = true
	add_child(_tessere)
	add_child(_evid)
	add_child(_effetti)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#120e0b")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#8a7a68")
	e.ambient_light_energy = 0.55
	e.fog_enabled = true
	e.fog_light_color = Color("#1d1612")
	e.fog_density = 0.012
	env.environment = e
	add_child(env)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-55, -35, 0)
	sole.light_energy = 1.05
	sole.light_color = Color("#ffe6c4")
	sole.shadow_enabled = true
	sole.directional_shadow_max_distance = 40
	add_child(sole)
	_aggiorna_cam()
	get_viewport().size_changed.connect(_aggiorna_cam)

# ---------------------------------------------------------------- coordinate

static func mondo(h: Vector2i) -> Vector3:
	return Vector3(1.5 * h.x * S, 0, SQ3 * (h.y + h.x * 0.5) * S)

## altezza in metri di un livello del terreno
const ALT := 0.55

## posizione del piano d'appoggio di un esagono, con il suo dislivello
func posizione(h: Vector2i) -> Vector3:
	return mondo(h) + Vector3(0, ALT * (m.altezza(h) if m != null else 0), 0)

static func da_mondo(p: Vector3) -> Vector2i:
	var q := p.x / (1.5 * S)
	var r := p.z / (SQ3 * S) - q * 0.5
	return Motore._arrotonda_cubo(q, r)

static func vettore_dir(d: int) -> Vector3:
	return mondo(Motore.DIRS[d]).normalized()

static func angolo_y(d: int) -> float:
	var v := vettore_dir(d)
	return atan2(-v.x, -v.z)

# ---------------------------------------------------------------- costruzione

func costruisci(motore: Motore) -> void:
	m = motore
	for c in _tessere.get_children():
		c.queue_free()
	for f in figure:
		f.queue_free()
	figure.clear()
	_corpi.clear()
	_coda.clear()
	_occupato = false
	var R: int = m.s["raggio"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(m.s["arena"])
	var mesh_t := CylinderMesh.new()
	mesh_t.top_radius = 0.97 * S
	mesh_t.bottom_radius = 0.99 * S
	mesh_t.height = 0.3
	mesh_t.radial_segments = 6
	mesh_t.rings = 1
	var mesh_o := CylinderMesh.new()
	mesh_o.top_radius = 0.72 * S
	mesh_o.bottom_radius = 0.86 * S
	mesh_o.height = 1.7
	mesh_o.radial_segments = 6
	var pietre := []
	for i in 4:
		var mt := StandardMaterial3D.new()
		mt.albedo_color = Color("#8b7d6b").darkened(0.08 * i).lerp(Color("#7a6a52"), 0.25 * (i % 2))
		mt.roughness = 0.95
		pietre.append(mt)
	var mat_alto := StandardMaterial3D.new()
	mat_alto.albedo_color = Color("#8c785c")
	mat_alto.roughness = 0.95
	var mat_rocchio := StandardMaterial3D.new()
	mat_rocchio.albedo_color = Color("#9c8e72")
	mat_rocchio.roughness = 0.9
	var mat_o := StandardMaterial3D.new()
	mat_o.albedo_color = Color("#5d554c")
	mat_o.roughness = 1.0
	var mat_f := StandardMaterial3D.new()
	mat_f.albedo_color = Color("#3a2016")
	mat_f.emission_enabled = true
	mat_f.emission = Color("#ff6a1a")
	mat_f.emission_energy_multiplier = 1.6
	for q in range(-R, R + 1):
		for r in range(-R, R + 1):
			var h := Vector2i(q, r)
			if Motore.dist(h, Vector2i.ZERO) > R:
				continue
			var t := MeshInstance3D.new()
			var lv := m.altezza(h)
			t.mesh = mesh_t
			t.rotation.y = deg_to_rad(30)
			t.position = mondo(h) + Vector3(0, -0.15 - rng.randf() * 0.03, 0)
			t.material_override = pietre[rng.randi() % pietre.size()]
			if lv == 1:
				# piattaforma o roccia: un prisma esagonale alto un livello
				var pm1 := CylinderMesh.new()
				pm1.top_radius = 0.95 * S
				pm1.bottom_radius = 0.99 * S
				pm1.height = 0.3 + ALT
				pm1.radial_segments = 6
				pm1.rings = 1
				t.mesh = pm1
				t.position = mondo(h) + Vector3(0, ALT - (0.3 + ALT) / 2.0 - rng.randf() * 0.03, 0)
				t.material_override = mat_alto
			elif lv >= 2:
				# rocchio di colonna spezzata: ci si sale solo con un salto
				var pm2 := CylinderMesh.new()
				pm2.top_radius = 0.8 * S
				pm2.bottom_radius = 0.86 * S
				pm2.height = 0.3 + ALT * lv
				pm2.radial_segments = 18
				t.mesh = pm2
				t.position = mondo(h) + Vector3(0, ALT * lv - (0.3 + ALT * lv) / 2.0, 0)
				t.material_override = mat_rocchio
				var base := MeshInstance3D.new()
				base.mesh = mesh_t
				base.rotation.y = deg_to_rad(30)
				base.position = mondo(h) + Vector3(0, -0.16, 0)
				base.material_override = pietre[0]
				_tessere.add_child(base)
			if m.s["per"].has(h):
				t.material_override = mat_f
				_braciere(h)
			_tessere.add_child(t)
			if m.s.get("bassi", {}).has(h):
				# macerie basse: un muretto di pietre che si scavalca con un salto
				for k in 3:
					var bm := BoxMesh.new()
					bm.size = Vector3(rng.randf_range(0.5, 0.8), rng.randf_range(0.35, 0.6), rng.randf_range(0.45, 0.7))
					var bo := MeshInstance3D.new()
					bo.mesh = bm
					bo.material_override = pietre[(k + 1) % pietre.size()]
					bo.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))
					bo.position = mondo(h) + Vector3(rng.randf_range(-0.35, 0.35), bm.size.y / 2.0 + (0.25 if k == 2 else 0.0), rng.randf_range(-0.35, 0.35))
					_tessere.add_child(bo)
			elif m.s["ost"].has(h):
				var o := MeshInstance3D.new()
				o.mesh = mesh_o
				o.rotation.y = deg_to_rad(30 + rng.randf_range(-8, 8))
				o.position = mondo(h) + Vector3(0, 0.85, 0)
				o.material_override = mat_o
				_tessere.add_child(o)
				var cap := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.9 * S
				cm.bottom_radius = 0.9 * S
				cm.height = 0.18
				cm.radial_segments = 6
				cap.mesh = cm
				cap.rotation.y = o.rotation.y
				cap.position = mondo(h) + Vector3(0, 1.75, 0)
				cap.material_override = pietre[0]
				_tessere.add_child(cap)
	# terreno attorno e torce
	var suolo := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = (R + 5) * 1.8
	pm.bottom_radius = pm.top_radius
	pm.height = 0.1
	pm.radial_segments = 48
	suolo.mesh = pm
	suolo.position = Vector3(0, -0.36, 0)
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color("#2b2119")
	ms.roughness = 1.0
	suolo.material_override = ms
	_tessere.add_child(suolo)
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		_torcia(Vector3(cos(a), 0, sin(a)) * (R * 1.62 + 1.6))
	for i in 2:
		_crea_figura(i)
	sincronizza()
	distanza = 9.0 + R * 1.3
	_aggiorna_cam()

func _braciere(h: Vector2i) -> void:
	var f := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.5
	f.mesh = sm
	var mf := StandardMaterial3D.new()
	mf.albedo_color = Color("#ffb040")
	mf.emission_enabled = true
	mf.emission = Color("#ff7a20")
	mf.emission_energy_multiplier = 3.0
	mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	f.material_override = mf
	f.position = mondo(h) + Vector3(0, 0.2, 0)
	_tessere.add_child(f)
	var tw := f.create_tween().set_loops()
	tw.tween_property(f, "scale", Vector3(1.15, 1.35, 1.15), 0.5)
	tw.tween_property(f, "scale", Vector3(0.9, 0.85, 0.9), 0.6)

func _torcia(p: Vector3) -> void:
	var palo := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.08
	cm.bottom_radius = 0.12
	cm.height = 2.2
	palo.mesh = cm
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color("#3b2a1c")
	palo.material_override = mp
	palo.position = p + Vector3(0, 0.8, 0)
	_tessere.add_child(palo)
	var fi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.45
	fi.mesh = sm
	var mf := StandardMaterial3D.new()
	mf.albedo_color = Color("#ffc060")
	mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fi.material_override = mf
	fi.position = p + Vector3(0, 2.0, 0)
	_tessere.add_child(fi)
	var l := OmniLight3D.new()
	l.light_color = Color("#ff9a40")
	l.light_energy = 1.6
	l.omni_range = 7.0
	l.position = p + Vector3(0, 2.1, 0)
	_tessere.add_child(l)

func _mat(c: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new()
	mt.albedo_color = c
	mt.roughness = rough
	mt.metallic = metal
	return mt

func _mesh(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

## Combattente fatto di forme semplici; l'arma dipende dai token della scheda.
func _crea_figura(i: int) -> void:
	var g: Dictionary = m.s["g"][i]
	var toks: Dictionary = g["pg"]["token"]
	var radice := Node3D.new()
	radice.scale = Vector3.ONE * SCALA_FIGURA
	add_child(radice)
	var corpo := Node3D.new()
	corpo.name = "Corpo"
	radice.add_child(corpo)
	var colp: Color = Disegno.GIOCATORI[i]
	var base := CylinderMesh.new()
	base.top_radius = 0.46
	base.bottom_radius = 0.5
	base.height = 0.1
	var basetta := _mesh(base, _mat(colp, 0.5, 0.3), Vector3(0, 0.05, 0), radice)
	var punta := PrismMesh.new()
	punta.size = Vector3(0.36, 0.3, 0.06)
	var freccia := _mesh(punta, _mat(colp.lightened(0.3), 0.4), Vector3(0, 0.11, -0.5), radice, Vector3(-PI / 2, 0, 0))
	# colore dominante della scheda per la veste
	var dom := "rosso"
	var maxd := -1
	var st := Motore.statistiche(m.cat, g["pg"])
	for c in st["dadi"]:
		if st["dadi"][c] > maxd:
			maxd = st["dadi"][c]
			dom = c
	var veste := Disegno.colore(dom).darkened(0.2)
	var modello := _modello_combattente(colp, veste, aspetto_di(g["pg"], i))
	if modello != null:
		corpo.add_child(modello)
		# le miniature animate poggiano direttamente sul terreno, senza basetta
		basetta.queue_free()
		# resta una freccia piccola sul terreno, davanti ai piedi, per leggere il verso
		freccia.scale = Vector3(0.8, 0.8, 0.8)
		freccia.position = Vector3(0, 0.03, -0.42)
	else:
		_figura_semplice(corpo, veste, toks, colp)
	var nome := Label3D.new()
	nome.text = g["nome"]
	nome.font = Disegno.font_titolo()
	nome.font_size = 52
	nome.pixel_size = 0.006
	nome.outline_size = 14
	nome.modulate = colp.lightened(0.35)
	nome.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nome.no_depth_test = true
	nome.position = Vector3(0, 2.25 + 0.32 * i, 0)
	nome.name = "Nome"
	radice.add_child(nome)
	figure.append(radice)

## Figura disegnata con forme semplici (se manca il modello animato).
func _figura_semplice(corpo: Node3D, veste: Color, toks: Dictionary, colp: Color) -> void:
	var busto := CapsuleMesh.new()
	busto.radius = 0.22
	busto.height = 0.95
	var mb := _mesh(busto, _mat(veste, 0.8), Vector3(0, 0.62, 0), corpo)
	_corpi.append(mb)
	var testa := SphereMesh.new()
	testa.radius = 0.15
	testa.height = 0.3
	_mesh(testa, _mat(Color("#d9b48f"), 0.8), Vector3(0, 1.22, 0), corpo)
	var elmo := SphereMesh.new()
	elmo.radius = 0.165
	elmo.height = 0.2
	elmo.is_hemisphere = true
	var metallo := _mat(Color("#9aa3ab"), 0.35, 0.8)
	if toks.has("piastre") or toks.has("maglia"):
		_mesh(elmo, metallo, Vector3(0, 1.26, 0), corpo)
		var spalle := BoxMesh.new()
		spalle.size = Vector3(0.62, 0.12, 0.3)
		_mesh(spalle, metallo, Vector3(0, 0.98, 0), corpo)
	elif toks.has("mente") and int(toks["mente"]) >= 2:
		var cappello := CylinderMesh.new()
		cappello.top_radius = 0.0
		cappello.bottom_radius = 0.2
		cappello.height = 0.45
		_mesh(cappello, _mat(Disegno.colore("viola").darkened(0.3)), Vector3(0, 1.5, 0), corpo)
	# armi: mano destra (x positivo) avanti
	var legno := _mat(Color("#6b4a2b"), 0.9)
	var lama := _mat(Color("#cfd6dc"), 0.25, 0.9)
	if toks.has("spada"):
		var b := BoxMesh.new()
		b.size = Vector3(0.06, 0.05, 0.85)
		_mesh(b, lama, Vector3(0.32, 0.75, -0.42), corpo)
		var el := BoxMesh.new()
		el.size = Vector3(0.24, 0.05, 0.05)
		_mesh(el, _mat(Color("#b08d57"), 0.4, 0.7), Vector3(0.32, 0.75, -0.02), corpo)
	if toks.has("ascia"):
		var manico := CylinderMesh.new()
		manico.top_radius = 0.03
		manico.bottom_radius = 0.03
		manico.height = 1.0
		_mesh(manico, legno, Vector3(0.34, 0.85, -0.2), corpo, Vector3(-0.5, 0, 0))
		var testa_a := BoxMesh.new()
		testa_a.size = Vector3(0.05, 0.32, 0.26)
		_mesh(testa_a, lama, Vector3(0.34, 1.25, -0.45), corpo, Vector3(-0.5, 0, 0))
	if toks.has("lancia"):
		var asta := CylinderMesh.new()
		asta.top_radius = 0.025
		asta.bottom_radius = 0.025
		asta.height = 1.9
		_mesh(asta, legno, Vector3(0.3, 0.8, -0.5), corpo, Vector3(-PI / 2 + 0.15, 0, 0))
		var pt := CylinderMesh.new()
		pt.top_radius = 0.0
		pt.bottom_radius = 0.06
		pt.height = 0.25
		_mesh(pt, lama, Vector3(0.3, 0.94, -1.45), corpo, Vector3(-PI / 2 + 0.15, 0, 0))
	if toks.has("pugnali"):
		for sx in [-1, 1]:
			var pg := BoxMesh.new()
			pg.size = Vector3(0.04, 0.04, 0.34)
			_mesh(pg, lama, Vector3(0.3 * sx, 0.7, -0.3), corpo)
	if toks.has("arco"):
		var arco := TorusMesh.new()
		arco.inner_radius = 0.42
		arco.outer_radius = 0.47
		_mesh(arco, legno, Vector3(-0.3, 0.8, -0.2), corpo, Vector3(0, 0, PI / 2))
	if toks.has("bastone"):
		var bs := CylinderMesh.new()
		bs.top_radius = 0.035
		bs.bottom_radius = 0.035
		bs.height = 1.5
		_mesh(bs, legno, Vector3(0.34, 0.8, -0.15), corpo)
		var gemma := SphereMesh.new()
		gemma.radius = 0.1
		gemma.height = 0.2
		var mg := _mat(Color("#c79cff"))
		mg.emission_enabled = true
		mg.emission = Color("#9d5cff")
		mg.emission_energy_multiplier = 2.0
		_mesh(gemma, mg, Vector3(0.34, 1.6, -0.15), corpo)
	if toks.has("scudo"):
		var sc := CylinderMesh.new()
		sc.top_radius = 0.32
		sc.bottom_radius = 0.32
		sc.height = 0.06
		_mesh(sc, _mat(colp.darkened(0.35), 0.6, 0.3), Vector3(-0.32, 0.7, -0.22), corpo, Vector3(PI / 2, 0, 0.3))
	if not (toks.has("spada") or toks.has("ascia") or toks.has("lancia") or toks.has("pugnali") or toks.has("bastone")):
		var pugno := SphereMesh.new()
		pugno.radius = 0.09
		pugno.height = 0.18
		_mesh(pugno, _mat(Color("#d9b48f")), Vector3(0.3, 0.7, -0.25), corpo)

## aspetti dei combattenti: modelli riggati su Mixamo, stesse ossa e animazioni.
## Il file è res://assets/modelli/<id>.glb con la texture <id>.jpg accanto.
const ASPETTI := [
	{"id": "donna", "nome": "Guerriera in rosso"},
	{"id": "uomo", "nome": "Lottatore in blu"},
	{"id": "uomo2", "nome": "Lottatore riccio"},
	{"id": "bionda", "nome": "Atleta bionda"},
	{"id": "mora", "nome": "Atleta mora"},
]

## aspetto di un combattente: quello scelto, altrimenti uno diverso per lato
static func aspetto_di(pg: Dictionary, lato: int) -> String:
	var id := String(pg.get("aspetto", ""))
	for a in ASPETTI:
		if a["id"] == id:
			return id
	return ASPETTI[lato % 2]["id"]
const SCALA_MODELLO := 1.12
## veste del secondo combattente quando il modello ha una texture (stessa mappa UV, colori diversi)
## la texture si carica a parte: quella incorporata nel GLB non sempre si importa nel web
const SCALA_FIGURA := 1.25

## Il combattente animato (manichino Mixamo): tuta del colore della caratteristica dominante,
## giunture del colore del giocatore. Guarda verso -Z come le pedine.
func _modello_combattente(colp: Color, veste: Color, aspetto := "donna") -> Node3D:
	var percorso := "res://assets/modelli/%s.glb" % aspetto
	if not ResourceLoader.exists(percorso):
		return null
	var tex_veste := percorso.get_basename() + ".jpg"
	var sc: PackedScene = load(percorso)
	var mod: Node3D = sc.instantiate()
	mod.name = "Modello"
	mod.scale = Vector3.ONE * SCALA_MODELLO
	mod.rotation.y = PI
	for mi in mod.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for k in mesh.get_surface_count():
			var orig := mesh.surface_get_material(k) as BaseMaterial3D
			if mi.name == "Pelle" and ResourceLoader.exists(tex_veste):
				# personaggio con texture: resta com'è
				var mt := orig.duplicate() as BaseMaterial3D if orig != null else StandardMaterial3D.new()
				mt.roughness = 0.75
				mt.metallic = 0.0
				mt.albedo_texture = load(tex_veste)
				mt.albedo_color = Color.WHITE
				mi.set_surface_override_material(k, mt)
				continue
			var nome_mat := String(mesh.surface_get_material(k).resource_name) if mesh.surface_get_material(k) != null else ""
			var c := colp.darkened(0.15) if nome_mat.contains("Joints") else veste
			mi.set_surface_override_material(k, _mat(c, 0.55, 0.1))
	var ap := _player(mod)
	if ap != null:
		if ap.has_animation("idle"):
			ap.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		ap.play("idle")
	return mod

func _player(n: Node) -> AnimationPlayer:
	var lista := n.find_children("*", "AnimationPlayer", true, false)
	return lista[0] if not lista.is_empty() else null

## AnimationPlayer della figura p (null se è la figura semplice).
func _ap(p: int) -> AnimationPlayer:
	if p < 0 or p >= figure.size():
		return null
	var mod := figure[p].get_node_or_null("Corpo/Modello")
	return _player(mod) if mod != null else null

## Fa partire un'animazione e poi torna in guardia; restituisce la durata reale.
func clip(p: int, nome: String, velocita := 1.0, poi := "idle") -> float:
	var ap := _ap(p)
	if ap == null or not ap.has_animation(nome):
		return 0.0
	ap.play(nome, 0.12, velocita)
	if poi != "":
		ap.queue(poi)
	return ap.get_animation(nome).length / maxf(velocita, 0.01)

## Il colpo in attesa parte adesso; la difesa del bersaglio d (parata, schivata, colpo subito)
## comincia nel momento dell'impatto.
func _sferra(tw: Tween, d: int, reazione: String) -> void:
	if _colpo.is_empty() or int(_colpo["dif"]) != d:
		# chi è già a terra (proiettato, immobilizzato) non ripete il colpo subito
		var ap := _ap(d)
		var a_terra := ap != null and String(ap.current_animation) in ["proiettato", "ko", "caduta", "rialzata"]
		if reazione != "" and not a_terra:
			clip(d, reazione, 1.2)
		return
	var a: int = _colpo["att"]
	var nome: String = _colpo["clip"]
	_colpo = {}
	var lento := 1.0 if nome == "proiezione" else 1.3
	var fa := figure[a]
	var v := figure[d].position - fa.position
	var verso := atan2(-v.x, -v.z)
	verso = fa.rotation.y + wrapf(verso - fa.rotation.y, -PI, PI)
	tw.tween_property(fa, "rotation:y", verso, 0.12)
	tw.tween_callback(func(): clip(a, nome, lento))
	# impatto: circa un terzo della mossa (la proiezione è più lunga)
	tw.tween_interval(0.55 if nome == "proiezione" else 0.28)
	if reazione != "":
		tw.tween_callback(func():
			clip(d, reazione, 1.2, "rialzata" if reazione == "proiettato" else "idle")
			if reazione == "proiettato" and _ap(d) != null:
				_ap(d).queue("idle"))
	if reazione == "proiettato":
		tw.tween_interval(0.8)
	# finito il colpo, l'attaccante torna a guardare dove dice il gioco
	tw.tween_interval(0.35)
	tw.tween_callback(func(): _ripristina_verso(a))

func _ripristina_verso(a: int) -> void:
	var fa := figure[a]
	var ry := angolo_y(int(m.s["g"][a]["dir"]))
	ry = fa.rotation.y + wrapf(ry - fa.rotation.y, -PI, PI)
	create_tween().tween_property(fa, "rotation:y", ry, 0.25)

## Chi viene spinto contro una colonna o un ostacolo si ferma nell'esagono prima e ci sbatte:
## un piccolo rimbalzo verso l'ostacolo, la scritta e il colpo subito.
func _urto(p: int, e: Dictionary) -> Tween:
	var f := figure[p]
	var dv := vettore_dir(int(e.get("dir", 0)))
	var verso := Vector3(dv.x, 0, dv.z).normalized() * 0.45
	_testo(f.position + Vector3(0, 2.2, 0), "Urto!", Color("#ff9a50"))
	var tw := create_tween()
	var base := f.position
	tw.tween_property(f, "position", base + verso, 0.1)
	tw.tween_property(f, "position", base, 0.18)
	var ap := _ap(p)
	if ap != null and not String(ap.current_animation) in ["proiettato", "caduta"]:
		clip(p, "colpito_corpo", 1.3)
	return tw

## Quale passo animare: avanti, indietro, di lato o una rotazione sul posto.
func _clip_passo(d: Vector3, ry: float, giro: float) -> String:
	d.y = 0
	if d.length() < 0.05:
		return ""
	var avanti := Vector3(-sin(ry), 0, -cos(ry))
	var destra := Vector3(cos(ry), 0, -sin(ry))
	var fa := d.normalized().dot(avanti)
	var fd := d.normalized().dot(destra)
	if absf(fa) >= absf(fd):
		return "passo_avanti" if fa > 0 else "passo_indietro"
	return "passo_destra" if fd > 0 else "passo_sinistra"

## Fine del duello: il vincitore esulta, lo sconfitto (se ancora in piedi) si arrende.
func fine_duello(vincitore: int) -> void:
	for i in figure.size():
		if m.s["g"][i]["vita"] > 0:
			clip(i, "vittoria" if i == vincitore else "sconfitta", 1.0, "")

func ha_modello(p: int) -> bool:
	return _ap(p) != null

## Mette le figure dove dice lo stato (senza animazione).
func mostra_nomi(si: bool) -> void:
	for f in figure:
		f.get_node("Nome").visible = si

func sincronizza() -> void:
	for i in figure.size():
		var g: Dictionary = m.s["g"][i]
		figure[i].position = posizione(g["pos"])
		figure[i].rotation = Vector3(0, angolo_y(g["dir"]), 0)
		var corpo: Node3D = figure[i].get_node("Corpo")
		corpo.rotation = Vector3.ZERO
		corpo.position = Vector3.ZERO
		if g["vita"] <= 0:
			var ap := _ap(i)
			if ap != null and ap.has_animation("caduta"):
				ap.play("caduta")
				ap.seek(ap.get_animation("caduta").length, true)
			else:
				corpo.rotation.x = -PI / 2.2
				corpo.position.y = 0.25
	aggiorna_guardie()

## Le guardie si vedono come muretti dorati sul lato protetto, alti quanto il loro valore.
## Sopra ogni figura: perle d'oro per i vantaggi che l'avversario ha costruito su di lei,
## perle rosso scuro per i suoi svantaggi (come i segnalini del vecchio regolamento).
func aggiorna_guardie() -> void:
	if m == null:
		return
	for i in figure.size():
		var f2 := figure[i]
		var vecchie := f2.get_node_or_null("Sfera")
		if vecchie != null:
			f2.remove_child(vecchie)
			vecchie.queue_free()
		var sf := Node3D.new()
		sf.name = "Sfera"
		f2.add_child(sf)
		var nv := int(m.s["g"][1 - i].get("vantaggi", 0))
		var ns := int(m.s["g"][i].get("svantaggi", 0))
		var tot := nv + ns
		for k in tot:
			var perla := SphereMesh.new()
			perla.radius = 0.07
			perla.height = 0.14
			var col := Disegno.ORO if k < nv else Color("#7a1f1a")
			var mt := _mat(col, 0.3, 0.5)
			if k < nv:
				mt.emission_enabled = true
				mt.emission = Disegno.ORO
				mt.emission_energy_multiplier = 0.3
			var ang := TAU * k / maxf(tot, 1.0)
			_mesh(perla, mt, Vector3(cos(ang) * 0.32, 2.4, sin(ang) * 0.32), sf)
	for i in figure.size():
		var f := figure[i]
		var vecchio := f.get_node_or_null("Guardie")
		if vecchio != null:
			f.remove_child(vecchio)
			vecchio.queue_free()
		var nodo := Node3D.new()
		nodo.name = "Guardie"
		f.add_child(nodo)
		var g: Dictionary = m.s["g"][i]
		for k in g["guardie"]:
			var l := int(g["guardie"][k]["lato"])
			var v := m.valore_guardia(i, k)
			var perno := Node3D.new()
			perno.rotation.y = angolo_y((int(g["dir"]) + l) % 6) - angolo_y(int(g["dir"]))
			nodo.add_child(perno)
			var alto := 0.1 + 0.07 * v
			var muro := BoxMesh.new()
			muro.size = Vector3(0.5, alto, 0.07)
			var mt := _mat(Disegno.ORO, 0.4, 0.6)
			mt.emission_enabled = true
			mt.emission = Disegno.ORO
			mt.emission_energy_multiplier = 0.35
			_mesh(muro, mt, Vector3(0, alto / 2 + 0.02, -0.6), perno)
			var et := Label3D.new()
			et.text = str(v)
			et.font = Disegno.font_titolo()
			et.font_size = 40
			et.pixel_size = 0.006
			et.outline_size = 10
			et.modulate = Disegno.ORO.lightened(0.3)
			et.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			et.position = Vector3(0, alto + 0.18, -0.6)
			perno.add_child(et)

# ---------------------------------------------------------------- evidenziazioni

func pulisci_evidenza() -> void:
	for c in _evid.get_children():
		c.queue_free()
	_frecce.clear()

func evidenzia(esagoni: Array, c: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.9 * S
	mesh.bottom_radius = 0.9 * S
	mesh.height = 0.04
	mesh.radial_segments = 6
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(c, 0.62)
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.emission_enabled = true
	mt.emission = c
	mt.emission_energy_multiplier = 1.4
	for h in esagoni:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mt
		mi.rotation.y = deg_to_rad(30)
		mi.position = posizione(h) + Vector3(0, 0.05, 0)
		_evid.add_child(mi)

## Frecce di orientamento attorno a un esagono; si scelgono toccandole.
func mostra_direzioni(h: Vector2i, dirs: Array) -> void:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.42, 0.36, 0.08)
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Disegno.ORO
	mt.emission_enabled = true
	mt.emission = Disegno.ORO
	mt.emission_energy_multiplier = 0.8
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for d in dirs:
		var c := posizione(h) + vettore_dir(d) * 0.62 + Vector3(0, 0.08, 0)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mt
		mi.position = c
		mi.rotation = Vector3(-PI / 2, angolo_y(d), 0)
		_evid.add_child(mi)
		_frecce.append([c, d])

func freccia_in(p: Vector3) -> int:
	var best := -1
	var bd := 0.36
	for f in _frecce:
		var dd := Vector2(p.x - f[0].x, p.z - f[0].z).length()
		if dd < bd:
			bd = dd
			best = f[1]
	return best

# ---------------------------------------------------------------- animazioni

func occupato() -> bool:
	return _occupato or not _coda.is_empty()

func accoda(eventi: Array) -> void:
	for e in eventi:
		_coda.append(e)
	if not _occupato:
		_prossimo()

func _prossimo() -> void:
	if _coda.is_empty():
		_occupato = false
		aggiorna_guardie()
		animazioni_finite.emit()
		return
	_occupato = true
	var e: Dictionary = _coda.pop_front()
	var tw := _anima(e)
	if tw == null:
		_prossimo.call_deferred()
	else:
		tw.finished.connect(_prossimo, CONNECT_ONE_SHOT)

func _anima(e: Dictionary) -> Tween:
	var p: int = e.get("p", 0)
	if p < 0 or p >= figure.size():
		return null
	var f := figure[p]
	var corpo: Node3D = f.get_node("Corpo")
	match e["t"]:
		"tecnica":
			# tori entra e lancia, uke vola nell'esagono d'arrivo e resta a terra, poi si rialza.
			# La spinta del lancio (evento successivo) si anima qui, insieme al volo.
			var u: int = int(e["bers"])
			var fu := figure[u]
			var tw := create_tween()
			_colpo = {}
			_testo(f.position + Vector3(0, 2.0, 0), String(e.get("nome", "")), Color("#ffe7a8"))
			var arrivo := fu.position
			for k in _coda.size():
				var e2: Dictionary = _coda[k]
				if e2["t"] == "attacco" or e2["t"] == "tecnica":
					break
				if e2["t"] == "spinto" and int(e2["p"]) == u:
					var per: Array = e2["percorso"]
					var ult: Vector3i = per[per.size() - 1]
					arrivo = posizione(Vector2i(ult.x, ult.y))
					e2["gia_animato"] = true
					break
			if not ha_modello(p):
				tw.tween_property(fu, "position", arrivo, 0.4)
				return tw
			var proiez: bool = e.get("genere", "proiezione") == "proiezione"
			# tori guarda uke e si avvicina per prenderlo
			var v := fu.position - f.position
			v.y = 0
			var ry := f.rotation.y + wrapf(atan2(-v.x, -v.z) - f.rotation.y, -PI, PI)
			var casa := f.position
			tw.tween_property(f, "rotation:y", ry, 0.12)
			tw.tween_callback(func():
				clip(p, "proiezione" if proiez else "parata", 1.2)
				clip(u, "proiettato" if proiez else "caduta", 1.2, ""))
			tw.parallel().tween_property(f, "position", casa + v * 0.35, 0.35)
			# volo: uke parte a circa metà della clip e atterra nell'esagono d'arrivo
			tw.tween_interval(0.45)
			tw.tween_property(fu, "position", arrivo, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(f, "position", casa, 0.55)
			tw.tween_interval(0.6)
			tw.tween_callback(func():
				if _ap(u) != null:
					_ap(u).play("rialzata", 0.2, 1.3)
					_ap(u).queue("idle")
				_ripristina_verso(p))
			return tw
		"guardia", "vantaggi", "svantaggi":
			aggiorna_guardie()
			# mettersi in guardia: un blocco alzato
			if e["t"] == "guardia" and ha_modello(p) and _colpo.is_empty():
				clip(p, "parata", 1.1)
			return null
		"muovi", "spinto":
			var per: Array = e["percorso"]
			if per.is_empty() or e.get("gia_animato", false):
				if e.get("urto", false):
					return _urto(p, e)
				return null
			var tw := create_tween()
			var anim := ha_modello(p)
			var dur := (0.5 if anim else 0.2) if e["t"] == "muovi" else (0.3 if anim else 0.12)
			var rot_prec := f.rotation.y
			var pos_prec := f.position
			var devia: bool = e.get("devia", false)
			if anim and e["t"] == "spinto":
				if devia:
					clip(p, "passo_avanti", 1.5)
				elif not e.get("lancia", false):
					clip(p, "colpito_corpo")
			for st in per:
				var pos := posizione(Vector2i(st.x, st.y))
				var ry := angolo_y(st.z) if e["t"] == "muovi" or devia else f.rotation.y
				ry = rot_prec + wrapf(ry - rot_prec, -PI, PI)
				if anim and e["t"] == "muovi":
					var nome := _clip_passo(pos - pos_prec, rot_prec, ry - rot_prec)
					if nome != "":
						tw.tween_callback(func(): clip(p, nome, 1.6))
				rot_prec = ry
				var da := pos_prec
				pos_prec = pos
				var dy := absf(pos.y - da.y)
				var lungo := Vector2(pos.x - da.x, pos.z - da.z).length() > 2.0 * S
				if dy > 0.05 or lungo:
					# gradino, salto acrobatico o caduta: un arco invece di uno scivolamento
					var hop := 0.25 + dy * 0.6 + (0.8 if lungo else 0.0)
					if e.get("caduta", 0) > 0 and pos.y < da.y:
						hop = 0.15
					var d2 := dur * (1.8 if lungo or dy > ALT * 1.5 else 1.2)
					if anim and (lungo or dy > ALT * 1.5) and e["t"] == "muovi":
						tw.tween_callback(func(): clip(p, "schivata", 1.4))
					tw.tween_method(func(t: float): f.position = da.lerp(pos, t) + Vector3(0, sin(PI * t) * hop, 0), 0.0, 1.0, d2)
					tw.parallel().tween_property(f, "rotation:y", ry, d2)
				else:
					tw.tween_property(f, "position", pos, dur).set_trans(Tween.TRANS_SINE)
					tw.parallel().tween_property(f, "rotation:y", ry, dur)
			if e.get("urto", false):
				tw.tween_callback(func(): _urto(p, e))
				tw.tween_interval(0.45)
			return tw
		"salto":
			var tw := create_tween()
			tw.tween_property(f, "scale", Vector3(0.05, 1.4, 0.05), 0.18)
			tw.tween_callback(func():
				f.position = posizione(e["pos"])
				f.rotation.y = angolo_y(e["dir"]))
			tw.tween_property(f, "scale", Vector3.ONE * SCALA_FIGURA, 0.2)
			return tw
		"attacco":
			var b: Node3D = figure[e["bers"]]
			var v := (b.position - f.position)
			v.y = 0
			var tw := create_tween()
			if ha_modello(p):
				# il colpo parte quando si conosce l'esito (parata, schivata o danno), insieme alla difesa
				_n_colpi += 1
				var nome: String = ["jab", "cross", "montante", "calcio"][_n_colpi % 4]
				if e.get("genere", "colpo") == "presa":
					nome = "cross"
				if e.get("lancia", false):
					nome = "proiezione"
				elif int(e.get("spingi", 0)) > 0:
					nome = "calcio" if _n_colpi % 2 == 0 else "cross"
				_colpo = {"att": p, "dif": int(e["bers"]), "clip": nome, "para": false}
				tw.tween_interval(0.05)
				return tw
			if int(e.get("dist", 1)) <= 2:
				var avanti := f.global_transform.basis.inverse() * (v.normalized() * 0.5)
				tw.tween_property(corpo, "position", avanti, 0.12).set_trans(Tween.TRANS_QUAD)
				tw.tween_property(corpo, "position", Vector3.ZERO, 0.2)
			else:
				var pr := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.1
				sm.height = 0.2
				pr.mesh = sm
				var mt := _mat(Color("#ffe9a0"))
				mt.emission_enabled = true
				mt.emission = Color("#ffd060")
				mt.emission_energy_multiplier = 3
				mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				pr.material_override = mt
				pr.position = f.position + Vector3(0, 0.9, 0)
				_effetti.add_child(pr)
				tw.tween_property(pr, "position", b.position + Vector3(0, 0.9, 0), 0.08 * v.length() + 0.1)
				tw.tween_callback(pr.queue_free)
			return tw
		"danno":
			var n: int = e["n"]
			_testo(f.position + Vector3(0, 2.0, 0), ("-%d" % n) if n > 0 else "nessun danno", Color("#ff5a40") if n > 0 else Color("#d8d0c0"))
			var tw := create_tween()
			if ha_modello(p):
				var reazione := ""
				if n > 0:
					reazione = "colpito_testa" if n >= 4 else "colpito_corpo"
				elif not _colpo.is_empty() and _colpo["para"]:
					reazione = "parata"
				if _colpo.get("clip", "") == "proiezione" and n > 0:
					reazione = "proiettato"
				_sferra(tw, p, reazione)
				tw.tween_interval(0.35)
				return tw
			if n > 0:
				for k in 3:
					tw.tween_property(corpo, "position:x", 0.08, 0.04)
					tw.tween_property(corpo, "position:x", -0.08, 0.04)
				tw.tween_property(corpo, "position:x", 0.0, 0.04)
			tw.tween_interval(0.35)
			return tw
		"schiva":
			_testo(f.position + Vector3(0, 2.0, 0), "Schivata!", Color("#8cc8ff"))
			var tw := create_tween()
			if ha_modello(p):
				_sferra(tw, p, "schivata")
				tw.tween_interval(0.35)
				return tw
			tw.tween_property(corpo, "position:x", -0.35, 0.12)
			tw.tween_property(corpo, "position:x", 0.0, 0.2)
			return tw
		"para":
			_testo(f.position + Vector3(0, 2.0, 0), "Parata", Disegno.ORO)
			var tw := create_tween()
			if ha_modello(p):
				# la parata si vede insieme al colpo, quando arriva l'esito
				if not _colpo.is_empty() and int(_colpo["dif"]) == p:
					_colpo["para"] = true
				else:
					clip(p, "parata", 1.3)
			tw.tween_interval(0.35)
			return tw
		"blocco":
			_testo(f.position + Vector3(0, 2.1, 0), ("%d dadi bloccati" % e["n"]) if e["n"] > 1 else "dado bloccato", Color("#c79cff"))
			var tw := create_tween()
			tw.tween_interval(0.4)
			return tw
		"cura":
			_testo(f.position + Vector3(0, 2.0, 0), "+%d" % e["n"], Color("#7fe08a"))
			var tw := create_tween()
			tw.tween_interval(0.4)
			return tw
		"segreto":
			_testo(f.position + Vector3(0, 2.2, 0), "Segreto: %s!" % e.get("nome", ""), Color("#c7b0ff"))
			var tw := create_tween()
			tw.tween_interval(0.9)
			return tw
		"fallito":
			_testo(f.position + Vector3(0, 2.0, 0), "Fallito!", Color("#ff8a40"))
			var tw := create_tween()
			tw.tween_interval(0.5)
			return tw
		"ko":
			var tw := create_tween()
			if ha_modello(p):
				tw.tween_interval(clip(p, "caduta", 1.0, ""))
				return tw
			tw.tween_property(corpo, "rotation:x", -PI / 2.2, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(corpo, "position:y", 0.25, 0.6)
			return tw
	return null

func _testo(p: Vector3, t: String, c: Color) -> void:
	var l := Label3D.new()
	l.text = t
	l.font = Disegno.font_titolo()
	l.font_size = 64
	l.pixel_size = 0.006
	l.outline_size = 16
	l.modulate = c
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = p
	_effetti.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", p.y + 0.9, 1.1)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.4)
	tw.tween_callback(l.queue_free)

# ---------------------------------------------------------------- telecamera e input

## In verticale (iPad girato) si fissa l'ampiezza orizzontale, così l'arena resta intera.
func _adatta_aspetto() -> void:
	var vs := get_viewport().get_visible_rect().size
	if vs.y <= 0:
		return
	if vs.x / vs.y < 1.25:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.fov = 62
	else:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.fov = 45

func _aggiorna_cam() -> void:
	_adatta_aspetto()
	pitch = clampf(pitch, deg_to_rad(18), deg_to_rad(85))
	distanza = clampf(distanza, 5.0, 36.0)
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distanza
	cam.transform = Transform3D(Basis.looking_at(-off, Vector3.UP), off)
	cam.v_offset = -distanza * spostamento_v
	cam.h_offset = distanza * spostamento_h
	var R := 8.0 if m == null else float(m.s["raggio"]) * 1.6
	pivot.position.x = clampf(pivot.position.x, -R, R)
	pivot.position.z = clampf(pivot.position.z, -R, R)

func ruota_vista(d: float) -> void:
	yaw += d
	_aggiorna_cam()

func zoom(f: float) -> void:
	distanza *= f
	_aggiorna_cam()

func _sposta(rel: Vector2) -> void:
	var k := distanza * 0.0022
	var destra := cam.global_transform.basis.x
	var avanti := -cam.global_transform.basis.z
	destra.y = 0
	avanti.y = 0
	pivot.position += (-destra.normalized() * rel.x + avanti.normalized() * rel.y) * k
	_aggiorna_cam()

func punto_suolo(sp: Vector2) -> Variant:
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	if absf(d.y) < 1e-4:
		return null
	var t := -o.y / d.y
	if t < 0:
		return null
	var pt := o + d * t
	# terreno a più livelli: si riprova alla quota dell'esagono trovato, dall'alto in basso
	if m != null:
		for lv: int in [2, 1]:
			var tl: float = (ALT * lv - o.y) / d.y
			if tl < 0:
				continue
			var pl: Vector3 = o + d * tl
			if m.altezza(da_mondo(pl)) >= lv:
				return pl
	return pt

func _unhandled_input(e: InputEvent) -> void:
	if m == null or not visible:
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			if blocca_input.call(e.position):
				return
			_tocchi[e.index] = e.position
			if _tocchi.size() == 1:
				_trascinato = false
				_premuto_pos = e.position
		else:
			_tocchi.erase(e.index)
		return
	if e is InputEventScreenDrag:
		if not _tocchi.has(e.index):
			return
		var prima: Vector2 = _tocchi[e.index]
		if _tocchi.size() == 1:
			if e.position.distance_to(_premuto_pos) > 10:
				_trascinato = true
			if _trascinato:
				_sposta(e.position - prima)
		elif _tocchi.size() >= 2:
			_trascinato = true
			var altro: Vector2
			for k in _tocchi:
				if k != e.index:
					altro = _tocchi[k]
					break
			var d0: float = prima.distance_to(altro)
			var d1: float = e.position.distance_to(altro)
			if d0 > 1 and d1 > 1:
				distanza *= d0 / d1
			var a0: float = (prima - altro).angle()
			var a1: float = (e.position - altro).angle()
			yaw -= wrapf(a1 - a0, -PI, PI)
			pitch += (e.position.y - prima.y) * 0.002
			_aggiorna_cam()
		_tocchi[e.index] = e.position
		return
	var emulato: bool = e.device == InputEvent.DEVICE_ID_EMULATION
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			zoom(0.9)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			zoom(1.1)
		elif e.pressed:
			if blocca_input.call(e.position):
				_tasto = -1
				return
			_tasto = e.button_index
			_premuto_pos = e.position
			if not emulato:
				_trascinato = false
		else:
			if _tasto == MOUSE_BUTTON_LEFT and e.button_index == MOUSE_BUTTON_LEFT and not _trascinato:
				var p = punto_suolo(e.position)
				if p != null:
					esagono_premuto.emit(da_mondo(p), p)
			_tasto = -1
	elif e is InputEventMouseMotion and not emulato and _tasto != -1:
		if e.position.distance_to(_premuto_pos) > 8:
			_trascinato = true
		if not _trascinato:
			return
		if _tasto == MOUSE_BUTTON_RIGHT:
			yaw -= e.relative.x * 0.006
			pitch += e.relative.y * 0.004
			_aggiorna_cam()
		else:
			_sposta(e.relative)
	elif e is InputEventMagnifyGesture:
		zoom(1.0 / e.factor)
	elif e is InputEventPanGesture:
		_sposta(-e.delta * 8)
