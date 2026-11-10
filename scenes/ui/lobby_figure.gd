## The Hill's lobby figures: Jeff (P1, green) and Chuck (P2, red), their idle frames from
## assets/sprites/characters scaled by a whole number to fill the old figure box (nearest). Unjoined
## they are a faint silhouette. The lobby calls set_joined(on) and wave() (see lobby_character.gd);
## wave is a little hop.
class_name LobbyFigure
extends Control

@export var player: int = 0

var _joined := false
var _hop := 0.0
var _t := 0.0
var _tw: Tween


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func set_joined(on: bool) -> void:
	_joined = on
	set_process(on)
	queue_redraw()


func is_joined() -> bool:
	return _joined


func wave() -> void:
	if _tw:
		_tw.kill()
	_tw = create_tween()
	for i in 2:
		_tw.tween_method(_set_hop, 0.0, 1.0, 0.12)
		_tw.tween_method(_set_hop, 1.0, 0.0, 0.16)


func _set_hop(h: float) -> void:
	_hop = h
	queue_redraw()


func _process(delta: float) -> void:
	var before := SpriteArt.frame_at("characters/%s.png" % SpriteArt.char_of(player), "idle", _t)
	_t += delta
	if SpriteArt.frame_at("characters/%s.png" % SpriteArt.char_of(player), "idle", _t) != before:
		queue_redraw()


func _draw() -> void:
	var who := SpriteArt.char_of(player)
	var file := "characters/%s.png" % who
	var fs := SpriteArt.frame_size(file)
	var k := maxi(1, int(minf(size.x / fs.x, size.y / fs.y)))
	var r := SpriteArt.row(file, "idle")
	if r.is_empty():
		return
	var f := SpriteArt.frame_at(file, "idle", _t)
	var mod := Color.WHITE if _joined else Color(0.3, 0.3, 0.4, 0.45)
	var pv := SpriteArt.pivot(file)
	var feet := Vector2(roundf(size.x * 0.5), size.y - roundf(_hop * 8.0))
	draw_texture_rect_region(SpriteArt.texture(file), Rect2(feet - pv * k, fs * k),
			Rect2(f * fs.x, int(r.row) * fs.y, fs.x, fs.y), mod)
