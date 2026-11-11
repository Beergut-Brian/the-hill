## Elevator feel for The Hill (data/elevator.tres), playtest 2026-11-10 items 9 and 7b.
## A in the cage rides; anyone else within pull_radius_tiles of that cage rides along. Underground
## the car hangs on a rope in the shaft: pressing A at a landing it is not at calls it there first.
class_name ElevatorTuning
extends Resource

## Another player this many tiles (16 px) or nearer to the cage is pulled along for the ride.
@export var pull_radius_tiles: float = 3.0
## The A glyph over a rider-to-be blinks this many times a second while the cage is ready.
@export var blink_hz: float = 2.5
## A called car takes this long to arrive (s): base + per layer it travels, at most call_max.
@export var call_base: float = 0.5
@export var call_per_layer: float = 0.15
@export var call_max: float = 1.2

const PATH := "res://data/elevator.tres"


static func load_default() -> ElevatorTuning:
	if ResourceLoader.exists(PATH):
		var t := load(PATH) as ElevatorTuning
		if t != null:
			return t
	return ElevatorTuning.new()


func pull_radius_px() -> float:
	return pull_radius_tiles * 16.0


## Seconds for the car to travel from landing `from` to `to` (-1 = up top); 0 when already there.
func call_time(from: int, to: int) -> float:
	if from == to:
		return 0.0
	return minf(call_base + call_per_layer * absi(to - from), call_max)
