## The surface day/night curve (data/time_of_day.tres). Keyframes are sorted by `t` (0..1 through
## one cycle) and wrap: the last one blends back into the first. Each is a Dictionary
## {t, sky_top, sky_horizon, band, tint, lights}.
class_name TimeOfDayData
extends Resource

@export var cycle_seconds: float = 720.0
@export var start_time: float = 0.08
@export var keyframes: Array[Dictionary] = []
