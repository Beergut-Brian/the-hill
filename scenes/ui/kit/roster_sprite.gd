## A Roster character's pixel form on a podium (MenuSkin.pixel_art): one Sprite2D, feet at the
## origin, a little 1-pixel bob. CharacterSlot scales it by MenuSkin.character_scale.
## set_character(id) swaps the sprite (RosterCharacter).
extends Node2D

var id := ""
var _sprite: Sprite2D
var _t := 0.0


func _init() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)


func set_character(to: String) -> void:
	var who := Roster.info(to)
	if who.is_empty() or who.pixel == "" or not ResourceLoader.exists(who.pixel):
		return
	id = to
	_sprite.texture = load(who.pixel)
	var s := _sprite.texture.get_size()
	_sprite.offset = Vector2(-floorf(s.x * 0.5), -s.y)


func _process(delta: float) -> void:
	_t += delta
	_sprite.position.y = -1.0 if fmod(_t, 1.0) < 0.5 else 0.0
