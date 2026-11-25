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
var debug_eventi := false
var _ogg_nodi := {}   # esagono -> nodo dell'oggetto di scena
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
	# cielo a 360 gradi: la città di cupole nel deserto (panorama equirettangolare)
	if ResourceLoader.exists(CIELO):
		var cielo := Sky.new()
		var pm := PanoramaSkyMaterial.new()
		pm.panorama = load(CIELO)
		pm.energy_multiplier = 0.85
		cielo.sky_material = pm
		e.background_mode = Environment.BG_SKY
		e.sky = cielo
	else:
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color("#120e0b")
	# luce d'ambiente propria, morbida: il cielo si vede ma non brucia i colori
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#9a8a74")
	e.ambient_light_energy = 0.55
	e.fog_enabled = true
	e.fog_light_color = Color("#c9b08a")
	e.fog_density = 0.006
	e.fog_sky_affect = 0.0
	env.environment = e
	add_child(env)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-55, -35, 0)
	sole.light_energy = 0.9
	sole.light_color = Color("#ffe6c4")
	sole.shadow_enabled = true
	sole.directional_shadow_max_distance = 40
	add_child(sole)
	_aggiorna_cam()
	get_viewport().size_changed.connect(_aggiorna_cam)

# ---------------------------------------------------------------- coordinate

static func mondo(h: Vector2i) -> Vector3:
	return Vector3(1.5 * h.x * S, 0, SQ3 * (h.y + h.x * 0.5) * S)

const CIELO := "res://assets/scena/cielo.jpg"
const SABBIA := preload("res://shaders/sabbia.gdshader")
const ACQUA := preload("res://shaders/acqua.gdshader")

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
	# esagoni di pietra con sabbia portata dal vento (shader); quelli di sabbia ne sono coperti
	var pietre := []
	for i in 4:
		var mt := ShaderMaterial.new()
		mt.shader = SABBIA
		mt.set_shader_parameter("tinta", -0.6 + 0.4 * i)
		mt.set_shader_parameter("quanta_sabbia", 0.35 + 0.05 * i)
		pietre.append(mt)
	var mat_sabbia := ShaderMaterial.new()
	mat_sabbia.shader = SABBIA
	mat_sabbia.set_shader_parameter("quanta_sabbia", 0.95)
	mat_sabbia.set_shader_parameter("increspature", 0.9)
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
	mat_f.emission_energy_multiplier = 0.7
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
			if lv == 1 and not m.s.get("ogg", {}).has(h) and _colonna("bassa", mondo(h), ALT + 0.02, 1.75, rng.randf() * TAU):
				# rocchio basso: un livello, ci si sale con un passo
				pass
			elif lv == 1:
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
			elif lv >= 2 and _colonna("media", mondo(h), ALT * lv + 0.02, 1.5, rng.randf() * TAU):
				# rocchio alto: ci si sale solo con un salto
				pass
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
			if m.s.get("sabbia", {}).has(h) and lv == 0:
				t.material_override = mat_sabbia
			if m.s["per"].has(h):
				t.material_override = mat_f
				_braciere(h)
			_tessere.add_child(t)
			if m.s.get("bassi", {}).has(h) and _colonna("bassa", mondo(h) + Vector3(0, -0.05, 0), 0.6, 1.3, rng.randf() * TAU, rng.randf_range(-0.12, 0.12)):
				pass
			elif m.s.get("bassi", {}).has(h):
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
			elif m.s["ost"].has(h) and _colonna("alta", mondo(h), 2.7, 1.0, rng.randf() * TAU):
				pass
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
	_ogg_nodi.clear()
	for h in m.s.get("ogg", {}):
		_crea_oggetto(h, String(m.s["ogg"][h]["tipo"]))
	# terreno attorno e torce
	var suolo := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = (R + 5) * 2.4
	pm.bottom_radius = pm.top_radius
	pm.height = 0.1
	pm.radial_segments = 48
	suolo.mesh = pm
	suolo.position = Vector3(0, -0.36, 0)
	var ms := ShaderMaterial.new()
	ms.shader = SABBIA
	ms.set_shader_parameter("quanta_sabbia", 0.9)
	ms.set_shader_parameter("colore_sabbia", Color("#a8875c"))
	suolo.material_override = ms
	_tessere.add_child(suolo)
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		_torcia(Vector3(cos(a), 0, sin(a)) * (R * 1.62 + 1.6))
	# alberi del deserto attorno all'arena (alberi faretra, fotografici)
	for i in 9:
		var a := TAU * i / 9.0 + 0.55 + rng.randf_range(-0.15, 0.15)
		var dist := R * 1.62 + 4.0 + rng.randf_range(0.0, 5.0)
		_albero(_tessere, Vector3(cos(a), -0.3, sin(a)) * dist, rng.randf_range(2.6, 3.8), 1 + i % 2, rng.randf() * TAU)
	for i in 2:
		_crea_figura(i)
	sincronizza()
	distanza = 9.0 + R * 1.3
	_aggiorna_cam()

## Oggetti di scena: ognuno ha un uso in combattimento (vedi le azioni di scena nel motore).
func _crea_oggetto(h: Vector2i, tipo: String) -> void:
	var n := Node3D.new()
	var base := mondo(h) + Vector3(0, ALT * (m.altezza(h) - (1 if tipo == "cassa" else 0)), 0)
	n.position = base
	n.rotation.y = randf() * TAU if tipo != "cassa" else deg_to_rad(30)
	match tipo:
		"cassa":
			var bm := BoxMesh.new()
			bm.size = Vector3(1.05, ALT, 1.05)
			var c := MeshInstance3D.new()
			c.mesh = bm
			c.material_override = _mat(Color("#7a5634"), 0.9)
			c.position.y = ALT / 2.0
			n.add_child(c)
			for k in 2:
				var listello := BoxMesh.new()
				listello.size = Vector3(1.08, 0.08, 0.12)
				var l := MeshInstance3D.new()
				l.mesh = listello
				l.material_override = _mat(Color("#4e3520"), 0.9)
				l.position = Vector3(0, ALT * (0.25 + 0.5 * k), 0.5)
				n.add_child(l)
		"pietre":
			for k in 5:
				var sm := SphereMesh.new()
				sm.radius = randf_range(0.1, 0.16)
				sm.height = sm.radius * 1.6
				var pi := MeshInstance3D.new()
				pi.mesh = sm
				pi.material_override = _mat(Color("#77706a").darkened(randf() * 0.2), 1.0)
				pi.position = Vector3(randf_range(-0.3, 0.3), sm.radius * 0.6, randf_range(-0.3, 0.3))
				n.add_child(pi)
		"fontana":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.72
			cm.bottom_radius = 0.78
			cm.height = 0.55
			var v := MeshInstance3D.new()
			v.mesh = cm
			v.material_override = _mat(Color("#8a8070"), 0.9)
			v.position.y = 0.27
			n.add_child(v)
			var am := CylinderMesh.new()
			am.top_radius = 0.62
			am.bottom_radius = 0.62
			am.height = 0.04
			var acqua := MeshInstance3D.new()
			acqua.mesh = am
			var ma := ShaderMaterial.new()
			ma.shader = ACQUA
			acqua.material_override = ma
			acqua.position.y = 0.54
			n.add_child(acqua)
		"albero" when _albero(n, Vector3.ZERO, 3.0 if (h.x + h.y) % 2 == 0 else 2.4, 1 if (h.x + h.y) % 2 == 0 else 2):
			pass
		"albero":
			var tm := CylinderMesh.new()
			tm.top_radius = 0.12
			tm.bottom_radius = 0.2
			tm.height = 2.2
			var tronco := MeshInstance3D.new()
			tronco.mesh = tm
			tronco.material_override = _mat(Color("#4a3322"), 1.0)
			tronco.position.y = 1.1
			n.add_child(tronco)
			for k in 3:
				var fm := SphereMesh.new()
				fm.radius = randf_range(0.55, 0.75)
				fm.height = fm.radius * 1.7
				var fo := MeshInstance3D.new()
				fo.mesh = fm
				fo.material_override = _mat(Color("#3f5a2c").lightened(randf() * 0.1), 1.0)
				fo.position = Vector3(randf_range(-0.35, 0.35), 2.2 + 0.35 * k, randf_range(-0.35, 0.35))
				n.add_child(fo)
		"braciere":
			for k in 3:
				var gm := CylinderMesh.new()
				gm.top_radius = 0.04
				gm.bottom_radius = 0.04
				gm.height = 0.85
				var g := MeshInstance3D.new()
				g.mesh = gm
				g.material_override = _mat(Color("#2e2a26"), 0.6, 0.6)
				var a := TAU * k / 3.0
				g.position = Vector3(cos(a) * 0.25, 0.4, sin(a) * 0.25)
				g.rotation = Vector3(sin(a) * 0.25, 0, -cos(a) * 0.25)
				n.add_child(g)
			var cm2 := CylinderMesh.new()
			cm2.top_radius = 0.42
			cm2.bottom_radius = 0.22
			cm2.height = 0.22
			var conca := MeshInstance3D.new()
			conca.mesh = cm2
			conca.material_override = _mat(Color("#3a332c"), 0.5, 0.7)
			conca.position.y = 0.85
			n.add_child(conca)
			var fl := SphereMesh.new()
			fl.radius = 0.28
			fl.height = 0.6
			var fiamma := MeshInstance3D.new()
			fiamma.mesh = fl
			var mf := StandardMaterial3D.new()
			mf.albedo_color = Color("#ffb040")
			mf.emission_enabled = true
			mf.emission = Color("#ff7a20")
			mf.emission_energy_multiplier = 2.5
			mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fiamma.material_override = mf
			fiamma.queue_free()
			_fuoco(Vector3(0, 0.95, 0), 0.9, n)
			var luce := OmniLight3D.new()
			luce.light_color = Color("#ff9a40")
			luce.light_energy = 0.9
			luce.omni_range = 4.0
			luce.position.y = 1.3
			n.add_child(luce)
	_tessere.add_child(n)
	_ogg_nodi[h] = n

## Proiettile ad arco (pietra o tizzone) da una figura all'altra.
func _proiettile(da: Vector3, a: Vector3, tizzone: bool, tw: Tween) -> void:
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.22
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	if tizzone:
		var mf := _mat(Color("#ff8a30"))
		mf.emission_enabled = true
		mf.emission = Color("#ff6a1a")
		mf.emission_energy_multiplier = 2.0
		mi.material_override = mf
	else:
		mi.material_override = _mat(Color("#77706a"), 1.0)
	mi.position = da
	mi.visible = false
	_effetti.add_child(mi)
	tw.tween_callback(func(): mi.visible = true)
	tw.tween_method(func(t: float): mi.position = da.lerp(a, t) + Vector3(0, sin(PI * t) * 1.2, 0), 0.0, 1.0, 0.45)
	tw.tween_callback(mi.queue_free)

## Spruzzo di sabbia o d'acqua verso il volto del nemico.
func _spruzzo(da: Vector3, a: Vector3, acqua: bool) -> void:
	for k in 10:
		var sm := SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.1
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		var mt := _mat(Color("#4f9ac0") if acqua else Color("#c9a86a"), 0.5)
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = mt
		mi.position = da
		_effetti.add_child(mi)
		var fine := a + Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.3), randf_range(-0.3, 0.3))
		var tw := mi.create_tween()
		tw.tween_interval(randf() * 0.12)
		tw.tween_property(mi, "position", fine, 0.35)
		tw.parallel().tween_property(mt, "albedo_color:a", 0.0, 0.45)
		tw.tween_callback(mi.queue_free)

var _alberi_cache := {}

## Albero faretra fotografico (modelli Poly Haven, CC0), alto h metri. false se il modello manca.
func _albero(genitore: Node3D, pos: Vector3, h: float, quale := 1, rot := 0.0) -> bool:
	var file := "res://assets/scena/albero_%d.glb" % quale
	if not ResourceLoader.exists(file):
		return false
	if not _alberi_cache.has(file):
		_alberi_cache[file] = load(file)
	var n: Node3D = _alberi_cache[file].instantiate()
	var aabb := AABB()
	var prima := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.transform * mi.get_aabb()
		aabb = b if prima else aabb.merge(b)
		prima = false
	if prima:
		return false
	var k := h / maxf(aabb.size.y, 0.01)
	n.scale = Vector3.ONE * k
	n.position = pos - Vector3(0, aabb.position.y * k, 0)
	n.rotation.y = rot
	genitore.add_child(n)
	return true

var _colonne_cache := {}

## Colonna di pietra scolpita (modelli GLB in tre altezze), alta h e larga l (in metri).
## Restituisce false se il modello manca, così si usa la forma semplice.
func _colonna(tipo: String, pos: Vector3, h: float, l: float, rot := 0.0, incl := 0.0) -> bool:
	var file := "res://assets/scena/colonna_%s.glb" % tipo
	if not ResourceLoader.exists(file):
		return false
	if not _colonne_cache.has(tipo):
		var mt := StandardMaterial3D.new()
		var tex := "res://assets/scena/colonna_%s.jpg" % tipo
		if ResourceLoader.exists(tex):
			mt.albedo_texture = load(tex)
		mt.roughness = 0.9
		_colonne_cache[tipo] = [load(file), mt]
	var sc: PackedScene = _colonne_cache[tipo][0]
	var n: Node3D = sc.instantiate()
	# misure del modello: si scala alla larghezza e all'altezza volute
	var aabb := AABB()
	var prima := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _colonne_cache[tipo][1]
		var b: AABB = mi.get_aabb()
		aabb = b if prima else aabb.merge(b)
		prima = false
	if prima:
		return false
	var lar := maxf(aabb.size.x, aabb.size.z)
	n.scale = Vector3(l / lar, h / aabb.size.y, l / lar)
	n.position = pos
	n.rotation = Vector3(incl, rot, 0)
	_tessere.add_child(n)
	return true

## Fuoco a particelle: lingue che salgono e sfumano dal giallo al rosso, con qualche scintilla.
func _fuoco(pos: Vector3, scala := 1.0, genitore: Node3D = null) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = int(28 * scala) + 6
	p.lifetime = 0.8
	p.preprocess = 0.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.18 * scala
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 1.2, 0)
	p.initial_velocity_min = 0.4 * scala
	p.initial_velocity_max = 0.9 * scala
	p.scale_amount_min = 0.35 * scala
	p.scale_amount_max = 0.7 * scala
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0.6))
	curva.add_point(Vector2(0.3, 1.0))
	curva.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curva
	var gr := Gradient.new()
	gr.set_color(0, Color(1.0, 0.9, 0.5, 0.9))
	gr.add_point(0.35, Color(1.0, 0.55, 0.15, 0.8))
	gr.set_color(gr.get_point_count() - 1, Color(0.6, 0.1, 0.05, 0.0))
	p.color_ramp = gr
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mt.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mt.vertex_color_use_as_albedo = true
	mt.albedo_texture = _tex_fiamma()
	q.material = mt
	p.mesh = q
	p.position = pos
	(genitore if genitore != null else _tessere).add_child(p)
	return p

var _fiamma_tex: Texture2D = null

## Macchia morbida e radiale per le particelle di fuoco (generata una volta sola).
func _tex_fiamma() -> Texture2D:
	if _fiamma_tex != null:
		return _fiamma_tex
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 64
	gt.height = 64
	_fiamma_tex = gt
	return gt

func _braciere(h: Vector2i) -> void:
	# braci a terra: fuoco a particelle e una luce che tremola
	_fuoco(posizione(h) + Vector3(0, 0.05, 0), 1.3)
	var luce := OmniLight3D.new()
	luce.light_color = Color("#ff8a30")
	luce.light_energy = 0.8
	luce.omni_range = 3.5
	luce.position = posizione(h) + Vector3(0, 0.8, 0)
	_tessere.add_child(luce)
	var tl := luce.create_tween().set_loops()
	tl.tween_property(luce, "light_energy", 1.1, 0.23)
	tl.tween_property(luce, "light_energy", 0.7, 0.31)

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
	fi.queue_free()
	_fuoco(p + Vector3(0, 1.95, 0), 0.7)
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
	{"id": "uomo3", "nome": "Lottatore brizzolato"},
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
## secondi dall'inizio della clip al momento dell'impatto (a velocità 1,3)
const IMPATTO := {"jab": 0.25, "cross": 0.3, "montante": 0.35, "calcio": 0.45, "calcio_girato": 0.75,
	"calcio_mma": 0.55, "calcio_volante": 1.1, "proiezione": 0.55, "gomitata": 0.55, "ginocchiata": 0.55, "gancio": 0.5}

func _sferra(tw: Tween, d: int, reazione: String, testo := "", colore := Color.WHITE) -> void:
	if _colpo.is_empty() or int(_colpo["dif"]) != d:
		# chi è già a terra (proiettato, immobilizzato) non ripete il colpo subito
		var ap := _ap(d)
		var a_terra := ap != null and String(ap.current_animation) in ["proiettato", "ko", "caduta", "rialzata", "volo_indietro"]
		if testo != "":
			_testo(figure[d].position + Vector3(0, 2.0, 0), testo, colore)
		if reazione != "" and not a_terra:
			clip(d, reazione, 1.2)
		return
	var a: int = _colpo["att"]
	var nome: String = _colpo["clip"]
	var gia: bool = _colpo.get("avviato", false)
	_colpo = {}
	var lento := 1.0 if nome == "proiezione" else 1.3
	if gia:
		tw.tween_callback(func():
			if testo != "":
				_testo(figure[d].position + Vector3(0, 2.0, 0), testo, colore)
			if reazione != "":
				clip(d, reazione, 1.2))
		tw.tween_interval(0.35)
		tw.tween_callback(func(): _ripristina_verso(a))
		return
	var fa := figure[a]
	var v := figure[d].position - fa.position
	var verso := atan2(-v.x, -v.z)
	verso = fa.rotation.y + wrapf(verso - fa.rotation.y, -PI, PI)
	tw.tween_property(fa, "rotation:y", verso, 0.12)
	tw.tween_callback(func(): clip(a, nome, lento))
	# impatto: il momento in cui il colpo arriva, diverso per ogni mossa; la difesa e la scritta
	# partono lì, insieme
	tw.tween_interval(float(IMPATTO.get(nome, 0.3)))
	tw.tween_callback(func():
		if testo != "":
			_testo(figure[d].position + Vector3(0, 2.0, 0), testo, colore)
		if reazione != "":
			clip(d, reazione, 1.2, "rialzata" if reazione == "proiettato" else "idle")
			if reazione == "proiettato" and _ap(d) != null:
				_ap(d).queue("idle"))
	if reazione == "proiettato":
		tw.tween_interval(0.8)
	# finito il colpo, l'attaccante torna a guardare dove dice il gioco
	tw.tween_interval(0.35)
	tw.tween_callback(func(): _ripristina_verso(a))

## Colpo rimasto senza esito (nessuna difesa, nessun danno annunciato): parte a vuoto.
func _colpo_a_vuoto() -> Tween:
	var tw := create_tween()
	_sferra(tw, int(_colpo["dif"]), "")
	return tw

## Mossa d'attacco adatta al colpo: le prese allungano le mani, i colpi numerati hanno la loro
## tecnica (shomen = fendente dall'alto, yokomen = di lato, tsuki = diretto), i calci si alternano.
func _clip_attacco(e: Dictionary) -> String:
	_n_colpi += 1
	var nome_azione := String(e.get("nome", "")).to_lower()
	if e.get("lancia", false):
		return "proiezione"
	if "gomit" in nome_azione:
		return "gomitata"
	if "ginocch" in nome_azione:
		return "ginocchiata"
	if "calci" in nome_azione or "spazzat" in nome_azione:
		return ["calcio", "calcio_girato", "calcio_mma"][_n_colpi % 3]
	if "contrattacco" in nome_azione:
		return "gancio"
	if e.get("genere", "colpo") == "presa":
		return ["cross", "gancio"][_n_colpi % 2]
	if int(e.get("spingi", 0)) > 0:
		return ["calcio", "calcio_mma", "calcio_girato"][_n_colpi % 3]
	match int(e.get("attacco_n", 0)):
		13:
			return "gomitata"
		14:
			return "gancio"
		15:
			return ["jab", "cross"][_n_colpi % 2]
		16:
			return ["calcio", "ginocchiata"][_n_colpi % 2]
		17:
			return ["calcio_girato", "montante"][_n_colpi % 2]
		18:
			return ["calcio_mma", "calcio_volante"][_n_colpi % 2]
	return ["jab", "calcio", "cross", "gancio", "calcio_girato", "montante", "ginocchiata", "calcio_mma", "gomitata", "calcio_volante"][_n_colpi % 10]

## Animazione per le azioni che non sono colpi né spostamenti.
const CLIP_AZIONE := {
	"stordisci": "provoca", "pesca": "urlo", "guardia": "blocco_interno", "sblocca": "respiro",
	"recupera": "respiro", "cura": "respiro", "concentrazione": "respiro", "eco": "respiro",
	"accumula": "urlo", "prepara_attesa": "respiro", "ritocca": "respiro", "ritocca_guardia": "blocco_alto",
	"rimetti": "respiro", "elimina": "respiro", "gira_nemico": "schiva_destra", "rovescia": "schiva_destra",
	"ruota": "schiva_destra", "scambia": "schiva_destra", "varco": "provoca", "disarma": "immobilizza",
	"leggi": "blocco_alto", "gira_guardia": "blocco_interno",
}

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

## lunghezza in metri di un ciclo delle clip di passo di Mixamo (spostamento delle anche del manichino)
const PASSO_LEN := {"passo_avanti": 0.92, "passo_indietro": 0.6, "passo_sinistra": 0.37, "passo_destra": 0.45}

func s_vivo(p: int) -> bool:
	return m != null and int(m.s["g"][p]["vita"]) > 0

## Passi veri da un esagono all'altro: la clip giusta (avanti, indietro, di lato) ripetuta
## tante volte quanto serve a coprire la distanza, così i piedi non scivolano.
func _tween_passi(tw: Tween, p: int, f: Node3D, da: Vector3, a: Vector3, r0: float, r1: float, vel: float) -> void:
	var nome := _clip_passo(a - da, r0, r1 - r0)
	var ap := _ap(p)
	if nome == "" or ap == null or not ap.has_animation(nome):
		tw.tween_property(f, "position", a, 0.4)
		return
	var lung: float = PASSO_LEN[nome] * SCALA_MODELLO * SCALA_FIGURA
	var d := Vector2(a.x - da.x, a.z - da.z).length()
	var n := clampi(roundi(d / lung), 1, 2)
	if nome != "passo_avanti":
		vel *= 1.25
	var durata := n * ap.get_animation(nome).length / vel
	tw.tween_callback(func():
		ap.play(nome, 0.1, vel)
		for k in n - 1:
			ap.queue(nome)
		ap.queue("idle"))
	tw.tween_property(f, "position", a, durata)
	tw.parallel().tween_property(f, "rotation:y", r1, minf(durata, 0.35))

## Salto acrobatico (due livelli o sopra le macerie): capriola in avanti, o all'indietro se si salta
## nel verso opposto a quello in cui si guarda.
func _tween_acrobazia(tw: Tween, p: int, f: Node3D, da: Vector3, a: Vector3, r0: float, ry: float) -> void:
	var dietro := _clip_passo(a - da, r0, 0.0) == "passo_indietro"
	var nome := "salto_indietro" if dietro else "salto_mortale"
	var ap := _ap(p)
	if ap == null or not ap.has_animation(nome):
		tw.tween_method(func(t: float): f.position = da.lerp(a, t) + Vector3(0, sin(PI * t) * 1.0, 0), 0.0, 1.0, 0.8)
		return
	var vel := 1.3
	var dur := ap.get_animation(nome).length / vel
	tw.tween_property(f, "rotation:y", ry, 0.15)
	tw.tween_callback(func(): clip(p, nome, vel))
	# lo stacco arriva dopo la rincorsa; in aria si copre la distanza, poi l'atterraggio
	var stacco := 0.3 if dietro else 0.2
	tw.tween_interval(dur * stacco)
	tw.tween_method(func(t: float): f.position = da.lerp(a, t) + Vector3(0, sin(PI * t) * 0.3, 0), 0.0, 1.0, dur * 0.5)
	tw.tween_interval(dur * (0.95 - stacco - 0.5))

## Volo di chi viene lanciato o cade da un rialzo: arco ampio, atterraggio sulla schiena.
func _tween_volo(tw: Tween, f: Node3D, da: Vector3, a: Vector3, ry: float, dur: float) -> void:
	var alto := 0.9 + maxf(0.0, da.y - a.y) * 0.3
	tw.tween_method(func(t: float): f.position = da.lerp(a, t) + Vector3(0, sin(PI * t) * alto, 0), 0.0, 1.0, dur).set_ease(Tween.EASE_OUT)

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

func clip_durata(p: int, nome: String) -> float:
	var ap := _ap(p)
	if ap == null or not ap.has_animation(nome):
		return 0.5
	return ap.get_animation(nome).length

func ha_modello(p: int) -> bool:
	return _ap(p) != null

## Mette le figure dove dice lo stato (senza animazione).
func mostra_nomi(si: bool) -> void:
	for f in figure:
		var n := f.get_node_or_null("Nome")
		if n != null:
			n.visible = si

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
	if debug_eventi:
		print("%6d ev %s p%s %s" % [Time.get_ticks_msec(), e["t"], e.get("p", ""), e.get("effetto", e.get("n", ""))])
	# un colpo dichiarato che non ha avuto esito parte a vuoto prima di qualunque altra mossa
	var passo_di_tori: bool = not _colpo.is_empty() and e["t"] == "muovi" and int(e.get("p", -1)) == int(_colpo["dif"])
	if passo_di_tori and not _colpo.get("avviato", false):
		# irimi o tenkan: chi difende si sposta mentre il colpo arriva
		_colpo["avviato"] = true
		var att: int = _colpo["att"]
		var nome_a: String = _colpo["clip"]
		var fa := figure[att]
		var vv := figure[int(_colpo["dif"])].position - fa.position
		fa.rotation.y = fa.rotation.y + wrapf(atan2(-vv.x, -vv.z) - fa.rotation.y, -PI, PI)
		clip(att, nome_a, 1.3)
	if not _colpo.is_empty() and not passo_di_tori and not String(e["t"]) in ["para", "schiva", "danno", "tecnica", "azione", "dadi", "blocco", "vantaggi", "svantaggi", "guardia", "attitudine", "sfera", "iniziativa"]:
		_coda.push_front(e)
		_colpo_a_vuoto().finished.connect(_prossimo, CONNECT_ONE_SHOT)
		return
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
		"lancio":
			var tw := create_tween()
			var bf := figure[int(e["bers"])]
			var v := bf.position - f.position
			f.rotation.y = f.rotation.y + wrapf(atan2(-v.x, -v.z) - f.rotation.y, -PI, PI)
			if ha_modello(p):
				clip(p, "lancia_oggetto", 1.5)
			tw.tween_interval(0.55)
			_proiettile(f.position + Vector3(0, 1.6, 0), bf.position + Vector3(0, 1.4, 0), e.get("oggetto", "") == "tizzone", tw)
			tw.tween_callback(func():
				if ha_modello(int(e["bers"])):
					clip(int(e["bers"]), "colpito_testa", 1.2))
			_testo(f.position + Vector3(0, 2.2, 0), "Pietra!" if e.get("oggetto", "") == "pietra" else "Tizzone!", Color("#ffcf8a"))
			return tw
		"getta":
			var tw := create_tween()
			var bf := figure[int(e["bers"])]
			if ha_modello(p):
				clip(p, "lancia_oggetto", 1.8)
			tw.tween_interval(0.4)
			tw.tween_callback(func():
				_spruzzo(f.position + Vector3(0, 1.4, 0), bf.position + Vector3(0, 1.6, 0), e.get("acqua", false))
				if ha_modello(int(e["bers"])):
					clip(int(e["bers"]), "colpito_testa", 1.2))
			_testo(bf.position + Vector3(0, 2.2, 0), "Accecato!", Color("#ffe7a8"))
			tw.tween_interval(0.4)
			return tw
		"oggetto_mosso":
			var da: Vector2i = e["da"]
			var a: Vector2i = e["a"]
			var nodo: Node3D = _ogg_nodi.get(da)
			var tw := create_tween()
			if nodo == null or da == a:
				return null
			for q in figure.size():
				if m.dist(m.s["g"][q]["pos"], da) == 1 and ha_modello(q):
					clip(q, "spingi_oggetto", 1.6)
					tw.tween_interval(0.35)
					break
			_ogg_nodi.erase(da)
			_ogg_nodi[a] = nodo
			var dest := mondo(a) + Vector3(0, ALT * (m.altezza(a) - 1), 0)
			tw.tween_property(nodo, "position", dest, 0.25 + 0.12 * Motore.dist(da, a)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			return tw
		"braciere":
			var da2: Vector2i = e["da"]
			var nodo2: Node3D = _ogg_nodi.get(da2)
			var tw := create_tween()
			for q in figure.size():
				if m.dist(m.s["g"][q]["pos"], da2) == 1 and ha_modello(q):
					clip(q, "calcio", 1.4)
					tw.tween_interval(0.4)
					break
			if nodo2 != null:
				_ogg_nodi.erase(da2)
				var asse := vettore_dir(Motore.dir_verso(da2, e["a"])).cross(Vector3.UP)
				tw.tween_method(func(t: float): nodo2.transform.basis = Basis(asse.normalized(), -t * PI / 2.2), 0.0, 1.0, 0.35)
				tw.tween_callback(func(): _braciere(e["a"]))
				tw.tween_interval(0.5)
				tw.tween_callback(nodo2.queue_free)
			_testo(posizione(e["a"]) + Vector3(0, 1.6, 0), "Fuoco!", Color("#ff9a50"))
			return tw
		"oggetto_via":
			var nodo3: Node3D = _ogg_nodi.get(e["pos"])
			if nodo3 != null:
				_ogg_nodi.erase(e["pos"])
				nodo3.queue_free()
			return null
		"tecnica":
			# tori entra e lancia, uke vola nell'esagono d'arrivo e resta a terra, poi si rialza.
			# La spinta del lancio (evento successivo) si anima qui, insieme al volo.
			var u: int = int(e["bers"])
			var fu := figure[u]
			var tw := create_tween()
			if not _colpo.is_empty() and int(_colpo["att"]) == u and ha_modello(u) and not _colpo.get("avviato", false):
				# l'attacco di uke parte, tori lo accoglie all'impatto
				var nome_u: String = _colpo["clip"]
				var vu := f.position - fu.position
				tw.tween_property(fu, "rotation:y", fu.rotation.y + wrapf(atan2(-vu.x, -vu.z) - fu.rotation.y, -PI, PI), 0.1)
				tw.tween_callback(func(): clip(u, nome_u, 1.3))
				tw.tween_interval(float(IMPATTO.get(nome_u, 0.3)) * 0.8)
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
				clip(p, "proiezione" if proiez else "immobilizza", 1.2)
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
			var spinto: bool = e["t"] == "spinto"
			var devia: bool = e.get("devia", false)
			var vola: bool = spinto and (e.get("lancia", false) or int(e.get("caduta", 0)) > 0)
			var rot_prec := f.rotation.y
			var pos_prec := f.position
			if anim and spinto and not devia and not vola:
				# il colpo arriva, poi si arretra barcollando con passi veri
				tw.tween_callback(func(): clip(p, "colpito_corpo", 1.6, ""))
				tw.tween_interval(0.22)
			if anim and vola:
				tw.tween_callback(func(): clip(p, "volo_indietro" if _ap(p) != null and _ap(p).has_animation("volo_indietro") else "proiettato", 1.4, ""))
			for st in per:
				var pos := posizione(Vector2i(st.x, st.y))
				var ry := angolo_y(st.z) if not spinto or devia else f.rotation.y
				ry = rot_prec + wrapf(ry - rot_prec, -PI, PI)
				var da := pos_prec
				var r0 := rot_prec
				rot_prec = ry
				pos_prec = pos
				if (pos - da).length() < 0.05:
					# rotazione sul posto
					tw.tween_property(f, "rotation:y", ry, 0.25 if anim else 0.12)
					continue
				if not anim:
					tw.tween_property(f, "position", pos, 0.2)
					tw.parallel().tween_property(f, "rotation:y", ry, 0.2)
					continue
				var dy := pos.y - da.y
				var lungo := Vector2(pos.x - da.x, pos.z - da.z).length() > 2.0 * S
				if vola:
					_tween_volo(tw, f, da, pos, ry, 0.55)
				elif lungo or absf(dy) > ALT * 1.5:
					_tween_acrobazia(tw, p, f, da, pos, r0, ry)
				elif absf(dy) > 0.05 and not spinto:
					# gradino: si sale con un balzo o si scende saltando giù
					var su := dy > 0
					var nome_g := "sali" if su else "scendi"
					var ap_g := _ap(p)
					var dur_g := (ap_g.get_animation(nome_g).length / 1.5) if ap_g != null and ap_g.has_animation(nome_g) else 0.6
					tw.tween_property(f, "rotation:y", ry, 0.15)
					tw.tween_callback(func(): clip(p, nome_g, 1.5))
					# lo slancio parte a metà clip quando si sale, presto quando si scende
					tw.tween_interval(dur_g * (0.35 if su else 0.15))
					tw.tween_method(func(t: float): f.position = da.lerp(pos, t) + Vector3(0, sin(PI * t) * 0.2, 0), 0.0, 1.0, dur_g * 0.4)
					tw.tween_interval(dur_g * (0.25 if su else 0.45))
				elif absf(dy) > 0.05:
					# spinto giù da un gradino: barcolla all'indietro e scende
					tw.tween_callback(func(): clip(p, "passo_indietro", 1.8))
					tw.tween_method(func(t: float): f.position = da.lerp(pos, t) + Vector3(0, sin(PI * t) * 0.15, 0), 0.0, 1.0, 0.45)
				else:
					_tween_passi(tw, p, f, da, pos, r0, ry, 1.9 if spinto else 1.35)
			if anim and vola:
				tw.tween_callback(func():
					if _ap(p) != null and s_vivo(p):
						_ap(p).play("rialzata", 0.2, 1.3)
						_ap(p).queue("idle"))
				tw.tween_interval(0.6)
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
				var nome := _clip_attacco(e)
				_colpo = {"att": p, "dif": int(e["bers"]), "clip": nome, "para": false, "scarto": false}
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
			var testo_d := ("-%d" % n) if n > 0 else "nessun danno"
			var col_d := Color("#ff5a40") if n > 0 else Color("#d8d0c0")
			var tw := create_tween()
			if ha_modello(p):
				var reazione := ""
				var parato: bool = not _colpo.is_empty() and int(_colpo["dif"]) == p and _colpo["para"]
				if n > 0:
					reazione = "parata_forte" if parato else ("colpito_testa" if n >= 4 else "colpito_corpo")
				elif parato:
					reazione = ["parata", "blocco_alto", "blocco_interno"][_n_colpi % 3]
				if _colpo.get("clip", "") == "proiezione" and n > 0:
					reazione = "proiettato"
				if parato:
					testo_d = "Parata, " + testo_d if n > 0 else "Parata!"
					col_d = Disegno.ORO if n == 0 else col_d
				_sferra(tw, p, reazione, testo_d, col_d)
				tw.tween_interval(0.35)
				return tw
			_testo(f.position + Vector3(0, 2.0, 0), testo_d, col_d)
			if n > 0:
				for k in 3:
					tw.tween_property(corpo, "position:x", 0.08, 0.04)
					tw.tween_property(corpo, "position:x", -0.08, 0.04)
				tw.tween_property(corpo, "position:x", 0.0, 0.04)
			tw.tween_interval(0.35)
			return tw
		"schiva":
			var tw := create_tween()
			if ha_modello(p):
				var sc: bool = not _colpo.is_empty() and _colpo.get("scarto", false)
				_sferra(tw, p, "scarto" if sc else ["schivata", "schiva_destra"][_n_colpi % 2], "Schivata!", Color("#8cc8ff"))
				tw.tween_interval(0.35)
				return tw
			_testo(f.position + Vector3(0, 2.0, 0), "Schivata!", Color("#8cc8ff"))
			tw.tween_property(corpo, "position:x", -0.35, 0.12)
			tw.tween_property(corpo, "position:x", 0.0, 0.2)
			return tw
		"para":
			# la parata si vede insieme al colpo, al momento dell'impatto (scritta compresa)
			if not _colpo.is_empty() and int(_colpo["dif"]) == p:
				_colpo["para"] = true
				return null
			_testo(f.position + Vector3(0, 2.0, 0), "Parata", Disegno.ORO)
			var tw := create_tween()
			if ha_modello(p):
				clip(p, ["parata", "blocco_alto", "blocco_interno"][_n_colpi % 3], 1.3)
			tw.tween_interval(0.35)
			return tw
		"azione":
			var ef := String(e.get("effetto", ""))
			# le reazioni a un colpo in arrivo si vedono all'impatto
			if not _colpo.is_empty() and int(_colpo["dif"]) == p:
				if ef == "scarta":
					_colpo["scarto"] = true
				return null
			if not ha_modello(p) or not CLIP_AZIONE.has(ef):
				return null
			var tw := create_tween()
			var nome_c: String = CLIP_AZIONE[ef]
			if ef == "stordisci" and ("rugg" in String(e.get("nome", "")).to_lower() or "urlo" in String(e.get("nome", "")).to_lower()):
				nome_c = "urlo"
			# chi provoca o colpisce a distanza guarda l'avversario
			if ef in ["stordisci", "varco", "disarma", "gira_nemico"]:
				var vv := figure[1 - p].position - f.position
				tw.tween_property(f, "rotation:y", f.rotation.y + wrapf(atan2(-vv.x, -vv.z) - f.rotation.y, -PI, PI), 0.15)
			tw.tween_callback(func(): clip(p, nome_c, 1.3))
			tw.tween_interval(minf(1.2, clip_durata(p, nome_c) / 1.3))
			tw.tween_callback(func(): _ripristina_verso(p))
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
	l.font_size = 48
	l.pixel_size = 0.0045
	l.outline_size = 12
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
