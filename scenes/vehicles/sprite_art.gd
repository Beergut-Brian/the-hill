## Draw helpers for manifest sheets (assets/sprites/manifest.json) used by players, vehicles,
## buildings and the lobby: cached textures, frame sizes, pivots and points read from the manifest
## (via SheetSprite), and a pixel-snapped, mirror-able frame draw. Nothing is hard-coded per sheet.
class_name SpriteArt
extends RefCounted

const ROOT := "res://assets/sprites/"

static var _tex: Dictionary = {}


## The texture of "characters/jeff.png" (cached: a texture loaded inline in _draw() and not held is
## freed before the frame renders and shows as a white box), or null when the file is not there.
static func texture(file: String) -> Texture2D:
	if not _tex.has(file):
		_tex[file] = SheetSprite.sheet_texture(file)
	return _tex[file]


## Drops a cached texture (a runtime-built sheet was replaced).
static func forget(file: String) -> void:
	_tex.erase(file)


static func has(file: String) -> bool:
	return texture(file) != null


static func frame_size(file: String) -> Vector2:
	return Vector2(SheetSprite.frame_size(file))


static func pivot(file: String) -> Vector2:
	var e := SheetSprite.entry(file)
	return Vector2(e.pivot[0], e.pivot[1]) if e.has("pivot") else frame_size(file) * 0.5


## A manifest row ({"row", "frames", "fps", ...}) of a sheet, or {}.
static func row(file: String, anim: String) -> Dictionary:
	return SheetSprite.entry(file).get("rows", {}).get(anim, {})


## A manifest point relative to the pivot (y down).
static func point(file: String, key: String, fallback := Vector2.ZERO) -> Vector2:
	return SheetSprite.point(file, key, fallback)


## The frame to show `t` seconds into animation `anim`: frames along the row at its fps, a frame
## listed in the row's "hold" lasting that many ticks. fps 0: frame 0.
static func frame_at(file: String, anim: String, t: float) -> int:
	var r := row(file, anim)
	var n := int(r.get("frames", 1))
	var fps := float(r.get("fps", 0))
	if n <= 1 or fps <= 0.0:
		return 0
	var hold: Dictionary = r.get("hold", {})
	var seq: Array[int] = []
	for i in n:
		for k in int(hold.get(str(i), 1)):
			seq.append(i)
	return seq[int(t * fps) % seq.size()]


## Draws frame `col` of sheet row `row_i` with its pivot at `at` (pixel-snapped), mirrored about the
## pivot's pixel column when `flip` (see dest_rect). `anchor` overrides the pivot (e.g. a ride frame placed on a vehicle's head).
static func draw(ci: CanvasItem, file: String, col: int, row_i: int, at: Vector2, flip := false,
		mod := Color.WHITE, anchor := Vector2(-1, -1)) -> void:
	var tex := texture(file)
	if tex == null:
		return
	var fs := frame_size(file)
	var pv := pivot(file) if anchor.x < 0.0 else anchor
	var src := Rect2(col * fs.x, row_i * fs.y, fs.x, fs.y)
	ci.draw_texture_rect_region(tex, dest_rect(fs, pv, at, flip), src, mod)


## The rect handed to draw_texture_rect_region for a frame of size `fs` with pivot `pv` drawn at
## `at`. PT1112-1: Godot flips a negative-width rect but keeps its left edge where it is (the
## painted area is [x, x + |w|]), so the mirrored frame must start at pivot + pv.x - fs.x. Before
## this, a flipped character or vehicle was painted one whole frame width to the right of where it
## stands: every turn left jumped the body sideways (Kaden's "teleport" in PT10-6 and PT1112-1).
## The mirror is about the centre of the pivot's pixel column (canvas x -> 1 - x around `at`), so a
## body drawn centred on that column (odd width, like Jeff and the built roster sheets) turns
## exactly in place. Parts drawn at a mirrored point (`point * Vector2(-1, 1)`) through this same
## function land consistently with the body.
static func dest_rect(fs: Vector2, pv: Vector2, at: Vector2, flip: bool) -> Rect2:
	var p := at.round()
	if flip:
		return Rect2(p.x + pv.x + 1.0 - fs.x, p.y - pv.y, -fs.x, fs.y)
	return Rect2(p.x - pv.x, p.y - pv.y, fs.x, fs.y)


## The opaque pixels of frame (col, row_i) as painted at `at` (canvas units of the drawing node),
## mirrored like the draw. Tests use it to check where a body really shows on screen. Falls back to
## the whole painted frame when the sheet's image can't be read.
static func body_box(file: String, col: int, row_i: int, at: Vector2, flip: bool) -> Rect2:
	var fs := frame_size(file)
	var pv := pivot(file)
	var painted := painted_rect(fs, pv, at, flip)
	var tex := texture(file)
	var img: Image = tex.get_image() if tex != null else null
	if img == null or img.is_empty():
		return painted
	if img.is_compressed():
		img.decompress()
	var used := img.get_region(Rect2i(col * int(fs.x), row_i * int(fs.y), int(fs.x), int(fs.y))).get_used_rect()
	var x := float(used.position.x)
	if flip:
		x = fs.x - used.end.x
	return Rect2(painted.position + Vector2(x, used.position.y), Vector2(used.size))


## The area dest_rect actually paints (Godot's rule above: position kept, size made positive).
static func painted_rect(fs: Vector2, pv: Vector2, at: Vector2, flip: bool) -> Rect2:
	var r := dest_rect(fs, pv, at, flip)
	return Rect2(r.position, r.size.abs())


## A character-sheet draw by Roster id (or sheet file) and animation name ("jeff", "walk", t). Any roster character:
## the game's own sheet, or one built from its pixel form (CharacterSheet).
static func draw_char(ci: CanvasItem, who: String, anim: String, t: float, at: Vector2, flip := false,
		mod := Color.WHITE, frame := -1) -> void:
	var file := who if who.ends_with(".png") else CharacterSheet.file_of(who)
	var r := row(file, anim)
	if r.is_empty():
		return
	var f := frame if frame >= 0 else frame_at(file, anim, t)
	draw(ci, file, clampi(f, 0, int(r.frames) - 1), int(r.row), at, flip, mod)


## The Roster id player `player` plays: their pick in the chooser (Jeff / Chuck by default).
static func char_of(player: int) -> String:
	return CharacterSheet.id_of(player)


## The sheet that draws player `player`'s character (see CharacterSheet).
static func char_file(player: int) -> String:
	return CharacterSheet.file_of_player(player)

