## Which sprite sheet draws a roster character in The Hill, by Roster id.
##
## - A character the game has drawn itself (assets/sprites/characters/<id>.png with player rows in
##   the manifest: Jeff, Chuck) uses that sheet: side view, shovel, every row hand-made.
## - Any other roster character (synced from openjar-characters with only a static front-view
##   `pixel.png`) gets a sheet built here at runtime from that pixel form, in the same row layout
##   (idle, walk, air, dig_side, dig_down, ride, sleep) with a shovel drawn in: bob, lean,
##   squash-and-stretch. It is registered as a virtual sheet "roster/<id>.png" (manifest entry +
##   texture) so SpriteArt / SheetSprite draw it like any other sheet. New characters therefore play
##   the night they are synced, with no art step; a hand-made sheet later simply replaces it.
## Residents (mole, dragon, ...) are never roster ids, and their sheets have no dig rows, so a
## resident sheet can never be picked up as a player body.
class_name CharacterSheet
extends RefCounted

const FRAME := Vector2i(48, 32)
const PIVOT := Vector2i(20, 32)
## The ride frame's head is the front view's top shrunk by this (fits the cab window).
const RIDE_SCALE := 0.7
const DARK := Color("2b2a3f")
const BLADE := Color("c9ccd6")
const BLADE_LIT := Color("eef0f5")
const HANDLE := Color("a0683a")

## id -> virtual sheet file ("roster/<id>.png").
static var _built: Dictionary = {}


## The sheet that draws player `player` (0 = P1): their Roster pick, else the slot's default.
static func file_of_player(player: int) -> String:
	var f := file_of(id_of(player))
	if f == "":
		f = file_of(Roster.default_for(player))
	if f == "":
		f = "characters/%s.png" % ("jeff" if player == 0 else "chuck")
	return f


## The Roster id player `player` plays (their pick; the slot's default if nothing resolved).
static func id_of(player: int) -> String:
	var id := Roster.pick(player)
	return id if id != "" else Roster.default_for(player)


## The game's own sheet for `id` if it has one with player rows, else a sheet built from the
## character's pixel form (cached), else "".
static func file_of(id: String) -> String:
	if id == "":
		return ""
	var own := "characters/%s.png" % id
	if not SpriteArt.row(own, "dig_side").is_empty() and SheetSprite.has_sheet(own):
		return own
	if _built.has(id):
		return _built[id]
	var who := Roster.info(id)
	var path: String = who.get("pixel", "")
	if path == "" or not ResourceLoader.exists(path):
		return ""
	var tex: Texture2D = load(path)
	var img := tex.get_image() if tex else null
	if img == null or img.is_empty():
		return ""
	return register(id, img)


## Builds and registers the sheet for `id` from a front-view image; returns its virtual file.
static func register(id: String, src: Image) -> String:
	var file := "roster/%s.png" % id
	var sheet := build(src)
	SheetSprite.add_virtual(file, ImageTexture.create_from_image(sheet), entry(file))
	SpriteArt.forget(file)
	_built[id] = file
	return file


## Drops built sheets (tests swap roster files between cases).
static func clear() -> void:
	for id: String in _built:
		SheetSprite.remove_virtual(_built[id])
		SpriteArt.forget(_built[id])
	_built.clear()


static func is_built(id: String) -> bool:
	return _built.has(id)


## The manifest entry of a built sheet: same row names, frames and fps as the game's own sheets.
static func entry(file: String) -> Dictionary:
	return {
		"file": file, "frame": [FRAME.x, FRAME.y], "pivot": [PIVOT.x, PIVOT.y], "hand": [PIVOT.x + 15, 22],
		"facing": "right", "note": "built at runtime from the Roster pixel form (CharacterSheet)",
		"rows": {
			"idle": {"row": 0, "frames": 2, "fps": 2},
			"walk": {"row": 1, "frames": 4, "fps": 8},
			"air": {"row": 2, "frames": 2, "fps": 0, "names": ["jump", "fall"]},
			"dig_side": {"row": 3, "frames": 3, "fps": 10, "hold": {"1": 2}},
			"dig_down": {"row": 4, "frames": 3, "fps": 10, "hold": {"1": 2}},
			"ride": {"row": 5, "frames": 1, "fps": 0},
			"sleep": {"row": 6, "frames": 2, "fps": 2},
		},
	}


## The whole sheet (4 columns x 7 rows of FRAME) from a front-view pixel form.
static func build(src: Image) -> Image:
	var s := src.duplicate() as Image
	if s.is_compressed():
		s.decompress()
	s.convert(Image.FORMAT_RGBA8)
	var bb := s.get_used_rect()
	if bb.size.x <= 0 or bb.size.y <= 0:
		bb = Rect2i(0, 0, 1, 1)
	var b := s.get_region(bb)
	if b.get_height() > FRAME.y:
		b.resize(maxi(1, b.get_width() * FRAME.y / b.get_height()), FRAME.y, Image.INTERPOLATE_NEAREST)
	var w := b.get_width()
	var h := b.get_height()
	var hand_y := -int(h * 0.38)   # hand height above the feet
	var sheet := Image.create_empty(FRAME.x * 4, FRAME.y * 7, false, Image.FORMAT_RGBA8)
	# idle: breathe (1 px squash).
	_put(sheet, 0, 0, b)
	_put(sheet, 1, 0, _scaled(b, w + 2, h - 1))
	_shovel_up(sheet, 0, 0, w, hand_y)
	_shovel_up(sheet, 1, 0, w + 2, hand_y + 1)
	# walk: bob and step.
	for f in 4:
		var lift := -1 if f % 2 == 1 else 0
		_put(sheet, f, 1, _stepped(b, [1, 0, -1, 0][f]), Vector2i(0, lift))
		_shovel_up(sheet, f, 1, w, hand_y + lift)
	# air: stretch up, then squash for the fall.
	_put(sheet, 0, 2, _scaled(b, w - 2, h))
	_put(sheet, 1, 2, _scaled(b, w + 2, h - 2))
	_shovel_up(sheet, 0, 2, w - 2, hand_y - 2)
	_shovel_up(sheet, 1, 2, w + 2, hand_y + 1)
	# dig_side: wind back, hit forward (squash + lean), recover.
	_put(sheet, 0, 3, _leaned(b, -1))
	_put(sheet, 1, 3, _leaned(_scaled(b, w + 1, h - 1), 2))
	_put(sheet, 2, 3, _leaned(b, 1))
	_shovel_up(sheet, 0, 3, w - 2, hand_y - 3)
	_shovel_side(sheet, 1, 3, w + 1, hand_y + 1, 4)
	_shovel_side(sheet, 2, 3, w, hand_y + 2, 2)
	# dig_down: rise, slam down (squash), recover.
	_put(sheet, 0, 4, _scaled(b, w - 1, h))
	_put(sheet, 1, 4, _scaled(b, w + 3, h - 3))
	_put(sheet, 2, 4, _scaled(b, w + 1, h - 1))
	_shovel_up(sheet, 0, 4, w - 1, hand_y - 3)
	_shovel_down(sheet, 1, 4, w + 3)
	_shovel_down(sheet, 2, 4, w + 1)
	# ride: head and shoulders at the frame top, shrunk to a side-view head's size so the face (not
	# just a big front-view hat) sits in the cab window; the cab covers the rest.
	var top := b.get_region(Rect2i(0, 0, w, mini(h, 18)))
	top.resize(maxi(1, roundi(w * RIDE_SCALE)), maxi(1, roundi(top.get_height() * RIDE_SCALE)), Image.INTERPOLATE_NEAREST)
	sheet.blend_rect(top, Rect2i(Vector2i.ZERO, top.get_size()), Vector2i(PIVOT.x - top.get_width() / 2, 5 * FRAME.y))
	# sleep: flopped flat (the bucket shows the top; "z z" puffs are drawn by the vehicle).
	_put(sheet, 0, 6, _scaled(b, w + 4, 14))
	_put(sheet, 1, 6, _scaled(b, w + 4, 13))
	return sheet


## Blits `img` into frame (col, row), centred on the pivot with its bottom on the feet line.
static func _put(sheet: Image, col: int, row: int, img: Image, off := Vector2i.ZERO) -> void:
	var at := Vector2i(col * FRAME.x + PIVOT.x - img.get_width() / 2, row * FRAME.y + PIVOT.y - img.get_height()) + off
	var r := Rect2i(Vector2i.ZERO, img.get_size())
	# Clip to the frame so nothing bleeds into a neighbour.
	var fr := Rect2i(col * FRAME.x, row * FRAME.y, FRAME.x, FRAME.y)
	var dst := Rect2i(at, img.get_size()).intersection(fr)
	if dst.size.x <= 0 or dst.size.y <= 0:
		return
	r = Rect2i(r.position + dst.position - at, dst.size)
	sheet.blend_rect(img, r, dst.position)


static func _scaled(b: Image, w: int, h: int) -> Image:
	var c := b.duplicate() as Image
	c.resize(clampi(w, 1, FRAME.x), clampi(h, 1, FRAME.y), Image.INTERPOLATE_NEAREST)
	return c


## Top lean: each row shifted by up to `by` px (top most, feet not at all). Positive = forward (right).
static func _leaned(b: Image, by: int) -> Image:
	var w := b.get_width()
	var h := b.get_height()
	var pad := absi(by)
	var out := Image.create_empty(w + pad * 2, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var dx := roundi(by * (1.0 - float(y) / h))
		out.blit_rect(b, Rect2i(0, y, w, 1), Vector2i(pad + dx, y))
	return out


## A step: the bottom quarter (legs) shifted `dx` px, the rest still.
static func _stepped(b: Image, dx: int) -> Image:
	if dx == 0:
		return b
	var w := b.get_width()
	var h := b.get_height()
	var out := Image.create_empty(w + 2, h, false, Image.FORMAT_RGBA8)
	var legs := maxi(2, h / 4)
	out.blit_rect(b, Rect2i(0, 0, w, h - legs), Vector2i(1, 0))
	out.blit_rect(b, Rect2i(0, h - legs, w, legs), Vector2i(1 + dx, h - legs))
	return out


# --- the shovel (pixels relative to the frame's pivot, x forward / right, y up = negative) ---------

static func _px(sheet: Image, col: int, row: int, x: int, y: int, c: Color) -> void:
	var fx := PIVOT.x + x
	var fy := PIVOT.y + y
	if fx < 0 or fx >= FRAME.x or fy < 0 or fy >= FRAME.y:
		return
	sheet.set_pixel(col * FRAME.x + fx, row * FRAME.y + fy, c)


static func _blade(sheet: Image, col: int, row: int, x: int, y: int, w: int, h: int) -> void:
	for yy in range(y - 1, y + h + 1):
		for xx in range(x - 1, x + w + 1):
			_px(sheet, col, row, xx, yy, DARK)
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(sheet, col, row, xx, yy, BLADE_LIT if xx == x or yy == y else BLADE)


static func _handle(sheet: Image, col: int, row: int, from: Vector2i, to: Vector2i) -> void:
	var n := maxi(absi(to.x - from.x), absi(to.y - from.y))
	for i in n + 1:
		var p := Vector2i((Vector2(from).lerp(Vector2(to), float(i) / maxf(1.0, n))).round())
		_px(sheet, col, row, p.x, p.y, HANDLE)


## Carried upright at the side: handle from the hand up, blade on top.
static func _shovel_up(sheet: Image, col: int, row: int, w: int, hand_y: int) -> void:
	var x := w / 2 + 1
	_handle(sheet, col, row, Vector2i(x, hand_y + 2), Vector2i(x, hand_y - 12))
	_blade(sheet, col, row, x - 1, hand_y - 17, 4, 5)


## Held out forward at hand height, the blade `reach` px past the body.
static func _shovel_side(sheet: Image, col: int, row: int, w: int, hand_y: int, reach: int) -> void:
	var x := w / 2
	_handle(sheet, col, row, Vector2i(x - 2, hand_y), Vector2i(x + reach, hand_y))
	_blade(sheet, col, row, x + reach + 1, hand_y - 2, 5, 4)


## Driven into the ground in front of the feet.
static func _shovel_down(sheet: Image, col: int, row: int, w: int) -> void:
	var x := w / 2 + 2
	_handle(sheet, col, row, Vector2i(x, -16), Vector2i(x + 2, -5))
	_blade(sheet, col, row, x + 1, -5, 4, 5)
