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
