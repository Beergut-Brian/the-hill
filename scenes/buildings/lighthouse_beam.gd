## The Lighthouse's light up top (B-07): at night a soft beam sweeps the sky from its lamp; when one
## is placed, the lamp flares and a beam shines straight down into the hill (it just lit a layer
## underground, see UndergroundLook "lit layers"). Visuals only; Building adds it to Lighthouses.
class_name LighthouseBeam
extends Node2D

## The lamp in lighthouse.png (48x144, bottom-left pivot): middle of the lantern room.
const LAMP := Vector2(24, -124)
const BEAM := Color(1.0, 0.88, 0.5)
const REACH := 420.0
const FLARE_TIME := 2.2

var building: Building
var _t := 0.0
var _flare := 0.0


func _ready() -> void:
	name = "LighthouseBeam"
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


## The placement moment: the lamp flares and shines down the hill.
func flare() -> void:
	_flare = FLARE_TIME


func flaring() -> bool:
	return _flare > 0.0


func _process(delta: float) -> void:
	_t += delta
	_flare = maxf(0.0, _flare - delta)
	queue_redraw()


func _draw() -> void:
	if building == null or building.ghost:
		return
	var night := Building.current_lights()
	var f := clampf(_flare / FLARE_TIME, 0.0, 1.0)
	if f > 0.0:
		var k := sin(f * PI)                      # swells and fades
		var w := 10.0 + 18.0 * k
		draw_colored_polygon(PackedVector2Array([LAMP + Vector2(-5, 0), LAMP + Vector2(5, 0),
				Vector2(LAMP.x + w, 40), Vector2(LAMP.x - w, 40)]), Color(BEAM, 0.45 * k))
		draw_circle(LAMP, 10.0 + 22.0 * k, Color(BEAM, 0.35 * k))
	if night > 0.02:
		# Two opposite wedges turning slowly, squashed so they sweep along the skyline.
		var a := _t * 0.8
		for side in [0.0, PI]:
			var d: float = a + side
			var half := 0.09
			var p1 := Vector2(cos(d - half), sin(d - half) * 0.25) * REACH
			var p2 := Vector2(cos(d + half), sin(d + half) * 0.25) * REACH
			draw_colored_polygon(PackedVector2Array([LAMP, LAMP + p1, LAMP + p2]), Color(BEAM, 0.18 * night))
		draw_circle(LAMP, 9.0, Color(BEAM, 0.5 * night))
