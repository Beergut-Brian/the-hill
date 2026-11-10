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
## pivot when `flip`. `anchor` overrides the pivot (e.g. a ride frame placed on a vehicle's head).
static func draw(ci: CanvasItem, file: String, col: int, row_i: int, at: Vector2, flip := false,
		mod := Color.WHITE, anchor := Vector2(-1, -1)) -> void:
	var tex := texture(file)
	if tex == null:
		return
	var fs := frame_size(file)
	var pv := pivot(file) if anchor.x < 0.0 else anchor
	var src := Rect2(col * fs.x, row_i * fs.y, fs.x, fs.y)
	var p := at.round()
	if flip:
		ci.draw_texture_rect_region(tex, Rect2(p.x + pv.x, p.y - pv.y, -fs.x, fs.y), src, mod)
	else:
		ci.draw_texture_rect_region(tex, Rect2(p.x - pv.x, p.y - pv.y, fs.x, fs.y), src, mod)


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

