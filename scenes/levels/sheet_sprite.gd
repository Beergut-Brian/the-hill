## A Sprite2D cut from a sheet described in assets/sprites/manifest.json (frame size, pivot, rows),
## positioned by its pivot (the node's position is the pivot point, e.g. the feet) and animated
## along one row. Nothing here is hard-coded per sheet: a sheet without a manifest entry is cut into
## square frames as tall as the image.
class_name SheetSprite
extends Sprite2D

const ROOT := "res://assets/sprites/"
const MANIFEST := ROOT + "manifest.json"

static var _manifest: Dictionary = {}

var fps := 0.0
var frames := 1
var row := 0
## When set: the sprite never rotates; its frame is the quarter turn of this node's rotation
## (frames along the row = 0, 90, 180, 270 degrees), e.g. a rolling boulder.
var turn_with: Node2D
var _t := 0.0


static func manifest() -> Dictionary:
	if _manifest.is_empty() and FileAccess.file_exists(MANIFEST):
		var d = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		_manifest = d if d is Dictionary else {}
	return _manifest


## The manifest entry for a sheet file ("props/boulder.png"), or {}.
static func entry(file: String) -> Dictionary:
	for k in manifest():
		var e = _manifest[k]
		if e is Dictionary and e.get("file", "") == file:
			return e
	return {}


static func has_sheet(file: String) -> bool:
	return ResourceLoader.exists(ROOT + file)


## Frame size of a sheet: manifest "frame", else square frames as tall as the image.
static func frame_size(file: String) -> Vector2i:
	var e := entry(file)
	if e.has("frame"):
		return Vector2i(int(e.frame[0]), int(e.frame[1]))
	var tex: Texture2D = load(ROOT + file)
	return Vector2i(tex.get_height(), tex.get_height()) if tex else Vector2i(16, 16)


## A named manifest point relative to the pivot (pixels, y down), or `fallback`.
static func point(file: String, key: String, fallback := Vector2.ZERO) -> Vector2:
	var e := entry(file)
	if not e.has(key):
		return fallback
	var piv: Vector2 = Vector2(e.pivot[0], e.pivot[1]) if e.has("pivot") else Vector2.ZERO
	return Vector2(e[key][0], e[key][1]) - piv


## A sprite of `file` playing `anim` (a manifest row name; "" = row 0, all frames along it).
## Null when the sheet is not there.
static func make(file: String, anim := "") -> SheetSprite:
	if not has_sheet(file):
		return null
	var s := SheetSprite.new()
	s.texture = load(ROOT + file)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	var e := entry(file)
	var fs := frame_size(file)
	s.hframes = maxi(1, s.texture.get_width() / fs.x)
	s.vframes = maxi(1, s.texture.get_height() / fs.y)
	var piv: Vector2 = Vector2(e.pivot[0], e.pivot[1]) if e.has("pivot") else Vector2(fs) * 0.5
	s.offset = -piv
	s.frames = s.hframes
	var rows: Dictionary = e.get("rows", {})
	if anim != "" and rows.has(anim):
		var r: Dictionary = rows[anim]
		s.row = int(r.get("row", 0))
		s.frames = int(r.get("frames", 1))
		s.fps = float(r.get("fps", 0))
	s.frame_coords = Vector2i(0, s.row)
	return s


func _process(delta: float) -> void:
	if turn_with:
		global_rotation = 0.0
		frame_coords = Vector2i(posmod(roundi(turn_with.global_rotation / (PI * 0.5)), maxi(frames, 1)), row)
		return
	if fps <= 0.0 or frames <= 1:
		return
	_t += delta
	frame_coords = Vector2i(int(_t * fps) % frames, row)
