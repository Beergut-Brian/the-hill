## A vehicle in the progression (data/vehicles/<id>.tres).
class_name VehicleData
extends Resource

@export var id: StringName
## 0 Front Loader .. 4 Drill Rig; Garage N unlocks order N.
@export var order: int
## Offsets for a dig facing right/down; rotated by the aim.
@export var dig_shape: Array[Vector2i]
## Removes BlockData with dig_tier <= this.
@export var dig_tier: int
## Up top, tiles.
@export var clear_area: Vector2i
## Pixels per second.
@export var speed: float
## Backpack multiplier.
@export var carry: float
## Extra unlock requirement, or &"".
@export var needs_treasure: StringName
## False: the Drill Rig parks at the shaft.
@export var works_up_top: bool = true
## What only this vehicle does (VehicleAbility): &"" none, &"tip" (Dump Truck: tips its load out
## up top, reverses with a beep), &"hook" (Crane: hooks a nearby boulder and hauls it out),
## &"auto_drill" (Drill Rig: A starts it drilling straight down on its own, A again stops).
@export var ability: StringName = &""
## &"engine" | &"horn" | &"dig" (+ &"tip", &"reverse", &"hook", &"spin" for abilities) -> Audio cue.
@export var sounds: Dictionary
@export var scene: PackedScene
