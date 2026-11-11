## Camera feel for The Hill (data/camera.tres). S-06: the underground camera leads a little ahead of
## the player in the direction they dig or drive and eases back when they stop; bigger vehicles
## zoom out a little so their load and reach stay in view. S-07: the base zoom.
class_name CameraTuning
extends Resource

## The ScreenDirector's zoom (screen px per world px). S-07: 2.0 until the TV check.
@export var zoom: float = 2.0
## How far ahead the camera sits at full lead (world px, x sideways, y up/down).
@export var lead_px: Vector2 = Vector2(64, 40)
## PT10-6: on foot the lead is this instead (no sideways lead: a kid turning to dig the other way
## saw the whole view swing 128 px and lost where they were; up / down still leads the dig).
@export var foot_lead_px: Vector2 = Vector2(0, 40)
## How fast the lead grows toward the move direction (1/s, exponential ease).
@export var lead_in: float = 2.5
## How fast it eases back to the player when they stop (1/s).
@export var ease_back: float = 1.6
## Stick deflection that counts as "going somewhere".
@export var dead_zone: float = 0.25
## Without a stick (the Drill Rig drilling on its own): speed (px/s) that still leads.
@export var lead_speed: float = 30.0
## Only lead underground (Hillville is wide and flat; the lead is for seeing what's coming).
@export var lead_up_top: bool = false
## Vehicle id -> zoom factor (1 = base zoom, 0.85 = 15% more world on screen).
@export var vehicle_zoom: Dictionary = {&"dump_truck": 0.85, &"crane": 0.85}
## Zoom-out applies up top too (the Crane's reach over buildings, the truck bed by the pile).
@export var vehicle_zoom_up_top: bool = true
## How fast the zoom eases to a new vehicle's zoom (1/s).
@export var zoom_ease: float = 2.0

const PATH := "res://data/camera.tres"


static func load_default() -> CameraTuning:
	if ResourceLoader.exists(PATH):
		var t := load(PATH) as CameraTuning
		if t != null:
			return t
	return CameraTuning.new()


## Zoom factor for a vehicle id (&"" = on foot).
func zoom_factor(vehicle_id: StringName) -> float:
	return float(vehicle_zoom.get(vehicle_id, 1.0))
