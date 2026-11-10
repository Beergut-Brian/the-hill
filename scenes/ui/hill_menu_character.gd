## Jeff (P1) or Chuck (P2) on a Showtime lobby podium, from the game's own sprite sheets
## (assets/sprites/characters/<name>.png, rows from the manifest). A Node2D with the feet at its
## origin; CharacterSlot scales it by MenuSkin.character_scale (a whole number) with nearest filtering.
## Idle breathes; wave() flips through the walk row; cheer() shows the jump frame, then fall, then
## idle again (the slot does the hop itself).
class_name HillMenuCharacter
extends Node2D

@export var player := 0

var sprite: SheetSprite
var _joined := false
var _tw: Tween


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite = SheetSprite.make(file(), "idle")
	if sprite == null:
		return
	sprite.name = "Sprite"
	# P2 faces P1 across the stage.
	sprite.flip_h = player == 1
	add_child(sprite)


func file() -> String:
	return "characters/%s.png" % SpriteArt.char_of(player)


func set_joined(on: bool) -> void:
	_joined = on
	if sprite:
		sprite.fps = float(_row("idle").get("fps", 2)) if on else 0.0


func is_joined() -> bool:
	return _joined


func wave() -> void:
	_play_once("walk", 0.5)


func cheer() -> void:
	if sprite == null:
		return
	if _tw:
		_tw.kill()
	var air := _row("air")
	sprite.fps = 0.0
	sprite.row = int(air.get("row", 0))
	sprite.frames = 1
	sprite.frame_coords = Vector2i(0, sprite.row)
	_tw = create_tween()
	_tw.tween_interval(0.16)
	_tw.tween_callback(func() -> void: sprite.frame_coords = Vector2i(1, sprite.row))
	_tw.tween_interval(0.22)
	_tw.tween_callback(_back_to_idle)


## The row the sprite shows now (manifest row name), for tests and shots.
func current_row() -> int:
	return sprite.frame_coords.y if sprite else -1


func _play_once(anim: String, secs: float) -> void:
	if sprite == null:
		return
	if _tw:
		_tw.kill()
	var r := _row(anim)
	sprite.row = int(r.get("row", 0))
	sprite.frames = int(r.get("frames", 1))
	sprite.fps = float(r.get("fps", 8))
	_tw = create_tween()
	_tw.tween_interval(secs)
	_tw.tween_callback(_back_to_idle)


func _back_to_idle() -> void:
	var r := _row("idle")
	sprite.row = int(r.get("row", 0))
	sprite.frames = int(r.get("frames", 1))
	sprite.frame_coords = Vector2i(0, sprite.row)
	set_joined(_joined)


func _row(anim: String) -> Dictionary:
	var rows: Dictionary = SheetSprite.entry(file()).get("rows", {})
	return rows.get(anim, {})
