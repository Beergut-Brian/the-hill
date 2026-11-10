## One kind of hazard in one layer (data/hazards/<id>.tres): how many HillGenerator places there.
## Kid-safe by contract: a boulder bonks (a short stun, stars), a water pocket gushes and floats you
## up, a cave-in traps you in a pocket until the Mole digs you out. None of them takes anything.
class_name HazardData
extends Resource

## &"boulder" | &"water_pocket" | &"cave_in"
@export var kind: StringName
@export var id: StringName
## LayerData id.
@export var layer: StringName
@export var count: int = 1
## Of `count`, how many sit near the layer's landing (met in the first minutes of a session).
@export var near_landing: int = 0
## Tiles: a pocket's water, a cave-in's loose ground. Boulders are always 2 x 2.
@export var size: Vector2i = Vector2i(2, 2)
