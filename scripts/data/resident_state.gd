## One per resident, saved; Story.gd drives it.
class_name ResidentState
extends Resource

enum Phase { UNMET, ENCOUNTERED, ARRIVED, RESTORED }

@export var id: StringName
@export var phase: Phase = Phase.UNMET
@export var encounters: int = 0
## The Mole: 3.
@export var encounters_to_arrive: int = 1


## Counts one encounter. True when this call moved the resident to ARRIVED.
func encounter() -> bool:
	if phase == Phase.ARRIVED or phase == Phase.RESTORED:
		return false
	encounters += 1
	phase = Phase.ENCOUNTERED
	if encounters >= encounters_to_arrive:
		phase = Phase.ARRIVED
		return true
	return false


## ARRIVED -> RESTORED; false from any other phase.
func restore() -> bool:
	if phase != Phase.ARRIVED:
		return false
	phase = Phase.RESTORED
	return true


func to_save() -> Dictionary:
	return {"phase": int(phase), "encounters": encounters}


func load_save(data: Dictionary) -> void:
	phase = clampi(int(data.get("phase", 0)), 0, Phase.RESTORED) as Phase
	encounters = int(data.get("encounters", 0))
