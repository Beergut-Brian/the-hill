## Which residents have been met, as ResidentState rows (contract "Save keys": "residents" is
## {id: ResidentState.to_save()}). HillGame owns one, HillSave saves it, the residents' behaviour
## (UndergroundResidents, TownResidents) reads and advances it. The once-only moments (the
## Caveman's thaw, the Dragon's first meeting) are guarded here, so they fire once per save.
class_name Story
extends RefCounted

signal changed()

const MOLE := &"mole"
const FOREMAN := &"gnome_foreman"
const CAVEMAN := &"caveman"
const DRAGON := &"dragon"
## Encounters before a resident comes up to wait at the shaft. The Dragon's first meeting is
## only a meeting (the full arc is later), so one reveal never makes her ARRIVED.
const TO_ARRIVE := {MOLE: 3, FOREMAN: 1, CAVEMAN: 1, DRAGON: 2}

var states: Dictionary = {}          # StringName -> ResidentState


func _init() -> void:
	for id: StringName in TO_ARRIVE:
		var s := ResidentState.new()
		s.id = id
		s.encounters_to_arrive = TO_ARRIVE[id]
		states[id] = s


func state(id: StringName) -> ResidentState:
	return states.get(id)


func phase(id: StringName) -> ResidentState.Phase:
	var s := state(id)
	return s.phase if s != null else ResidentState.Phase.UNMET


func is_thawed() -> bool:
	return phase(CAVEMAN) != ResidentState.Phase.UNMET


func dragon_met() -> bool:
	return phase(DRAGON) != ResidentState.Phase.UNMET


## The Caveman thawed: met once, and he comes up to wait by the fire at the shaft (ARRIVED).
## False when he already had.
func thaw_caveman() -> bool:
	return _meet_once(CAVEMAN)


## The Dragon's first meeting. False when it already happened.
func meet_dragon() -> bool:
	return _meet_once(DRAGON)


func _meet_once(id: StringName) -> bool:
	var s := state(id)
	if s == null or s.phase != ResidentState.Phase.UNMET:
		return false
	var arrived := s.encounter()
	Events.resident_encountered.emit(id, s.encounters)
	if arrived:
		Events.resident_arrived.emit(id)
	changed.emit()
	return true


func to_save() -> Dictionary:
	var out := {}
	for id: StringName in states:
		out[String(id)] = (states[id] as ResidentState).to_save()
	return out


func load_save(data: Dictionary) -> void:
	for k in data:
		var s := state(StringName(str(k)))
		if s != null and data[k] is Dictionary:
			s.load_save(data[k])
	changed.emit()
