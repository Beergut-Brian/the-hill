## Texture helpers for Hillville's art: manifest-driven sheet reads, per-row textures (so a
## row can repeat on its own), the baked ground image and the parallax material. Static only.
class_name HillvilleArt
extends RefCounted

const SPRITES := "res://assets/sprites/"
const PARALLAX_SHADER := "res://assets/shaders/parallax.gdshader"

static var _manifest := {}
static var _textures := {}


static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var f := FileAccess.open(SPRITES + "manifest.json", FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_manifest = parsed
	return _manifest


## An entry of the manifest (or {}).
static func entry(id: String) -> Dictionary:
	return manifest().get(id, {})


## A sheet by path under assets/sprites/ (cached; null when missing).
static func tex(path: String) -> Texture2D:
	if not _textures.has(path):
		var full := SPRITES + path
		_textures[path] = load(full) as Texture2D if ResourceLoader.exists(full) else null
	return _textures[path]


## Frame size of a manifest entry.
static func frame(id: String, fallback := Vector2.ZERO) -> Vector2:
	var fr: Array = entry(id).get("frame", [])
	return Vector2(fr[0], fr[1]) if fr.size() == 2 else fallback


static func point(id: String, key: String, fallback := Vector2.ZERO) -> Vector2:
	var p: Array = entry(id).get(key, [])
	return Vector2(p[0], p[1]) if p.size() == 2 else fallback


static func region(id: String, key: String) -> Rect2:
	var r: Array = entry(id).get("regions", {}).get(key, [])
	return Rect2(r[0], r[1], r[2], r[3]) if r.size() == 4 else Rect2()


## A region of a sheet as its own texture, so it can repeat by itself. Null when the image is
## not readable (headless has no pixels).
static func cut(path: String, rect: Rect2i) -> Texture2D:
	var key := "%s|%s" % [path, rect]
	if _textures.has(key):
		return _textures[key]
	var out: Texture2D = null
	var img := image(path)
	if img != null:
		out = ImageTexture.create_from_image(img.get_region(rect))
	_textures[key] = out
	return out


static func image(path: String) -> Image:
	var t := tex(path)
	if t == null:
		return null
	var img := t.get_image()
	if img == null or img.is_empty():
		return null
	if img.is_compressed():
		img.decompress()
	return img


## The parallax material: factor 1 moves with the world, 0 stays on screen; `anchor` is the
## sprite-local point under the rest camera.
static func parallax_material(factor: Vector2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(PARALLAX_SHADER) as Shader
	m.set_shader_parameter("factor", factor)
	return m


static func additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


## Cheap stable per-cell variant hash, 0..3.
static func variant(c: int, r: int) -> int:
	return ((c * 374761 + r * 668265 + c * r * 31) >> 3) & 3


## The ground as one image. `carved(c, r)` says which cells are open (the shaft); those get the
## topsoil back wall. Row 0 is capped with grass.
static func bake_ground(cols: int, rows: int, carved: Callable) -> Texture2D:
	var terrain := image("tiles/terrain.png")
	var grass := image("surface/grass.png")
	var walls := image("tiles/walls.png")
	if terrain == null:
		return null
	var out := Image.create(cols * 16, rows * 16, false, Image.FORMAT_RGBA8)
	for r in rows:
		for c in cols:
			var at := Vector2i(c * 16, r * 16)
			var v := variant(c, r)
			if carved.call(c, r):
				if walls != null:
					out.blend_rect(walls, Rect2i(v * 16, 0, 16, 16), at)
				continue
			var mask := 0
			if r == 0 or carved.call(c, r - 1):
				mask |= 1
			if c + 1 < cols and carved.call(c + 1, r):
				mask |= 2
			if r + 1 < rows and carved.call(c, r + 1):
				mask |= 4
			if c > 0 and carved.call(c - 1, r):
				mask |= 8
			out.blend_rect(terrain, Rect2i(v * 16, mask * 16, 16, 16), at)
			if r == 0 and grass != null:
				out.blend_rect(grass, Rect2i(((c * 7 + 3) % 4) * 16, 0, 16, 16), at)
	return ImageTexture.create_from_image(out)
