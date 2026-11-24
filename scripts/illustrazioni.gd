class_name Illustrazioni
extends RefCounted
## Le carte illustrate dei token (assets/carte/<id>.webp), caricate solo quando servono.

const CARTELLA := "res://assets/carte/"
static var _cache := {}

static func ha(id: String) -> bool:
	return ResourceLoader.exists(CARTELLA + id + ".webp")

static func carta(id: String) -> Texture2D:
	if not _cache.has(id):
		_cache[id] = load(CARTELLA + id + ".webp") if ha(id) else null
	return _cache[id]

const AZIONI := "res://assets/azioni/"
static var _cache_az := {}

## Miniatura dell'illustrazione di un'azione (spazio sid del token tid).
static func azione(tid: String, sid: String) -> Texture2D:
	var k := tid + "__" + sid
	if not _cache_az.has(k):
		var p := AZIONI + k + ".webp"
		_cache_az[k] = load(p) if ResourceLoader.exists(p) else null
	return _cache_az[k]
