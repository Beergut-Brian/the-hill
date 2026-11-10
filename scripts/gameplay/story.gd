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
## Each resident's ruin up top, and what it becomes once restored (data/buildings rows).
const RUIN_OF := {MOLE: &"old_shed", FOREMAN: &"crooked_watchtower", CAVEMAN: &"flooded_cabin", DRAGON: &"ruined_keep"}
const HOME_OF := {MOLE: &"lost_and_found", FOREMAN: &"gnome_village", CAVEMAN: &"museum", DRAGON: &"dragon_perch"}

## Saved beside the phases (save key "resident_arcs"): small arc facts that are not a phase,
## e.g. "found_waiting" (a Lost & Found bundle at the shed door). JSON-safe values only.
var extras: Dictionary = {}

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


## The Mole steals a shovel (and gives it straight back): one encounter. His third makes him
## ARRIVED. False once he has arrived (he never steals again).
func steal_shovel() -> bool:
	return _meet(MOLE)


## The gnome crew is found walled into the Gnome Room: the Foreman's encounter (ARRIVED at once).
func free_crew() -> bool:
	return _meet_once(FOREMAN)


## The Dragon's second meeting (after meet_dragon): she wakes properly and comes up (ARRIVED).
## False unless she was met and has not arrived yet.
func wake_dragon() -> bool:
	if phase(DRAGON) != ResidentState.Phase.ENCOUNTERED:
		return false
	return _meet(DRAGON)


func arrived(id: StringName) -> bool:
	return phase(id) == ResidentState.Phase.ARRIVED


func restored(id: StringName) -> bool:
	return phase(id) == ResidentState.Phase.RESTORED


## Up top: ARRIVED or RESTORED.
func in_town(id: StringName) -> bool:
	return arrived(id) or restored(id)


## The Dragon Perch stands: the Ice layer is warm (not slippery, once slipping exists).
func ice_warm() -> bool:
	return restored(DRAGON)


## The resident whose ruin is `ruin_id`, or &"".
static func resident_of(ruin_id: StringName) -> StringName:
	for id: StringName in RUIN_OF:
		if RUIN_OF[id] == ruin_id:
			return id
	return &""


## ARRIVED -> RESTORED and Events.ruin_restored. Paying is the caller's job (Inventory.spend).
func restore(id: StringName) -> bool:
	var s := state(id)
	if s == null or not s.restore():
		return false
	Events.ruin_restored.emit(RUIN_OF.get(id, &""), id)
	changed.emit()
	return true


func _meet(id: StringName) -> bool:
	var s := state(id)
	if s == null or s.phase == ResidentState.Phase.ARRIVED or s.phase == ResidentState.Phase.RESTORED:
		return false
	var arrived_now := s.encounter()
	Events.resident_encountered.emit(id, s.encounters)
	if arrived_now:
		Events.resident_arrived.emit(id)
	changed.emit()
	return true


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


func extras_to_save() -> Dictionary:
	return extras.duplicate(true)


func load_extras(data: Dictionary) -> void:
	extras = data.duplicate(true)
	changed.emit()


func load_save(data: Dictionary) -> void:
	for k in data:
		var s := state(StringName(str(k)))
		if s != null and data[k] is Dictionary:
			s.load_save(data[k])
	changed.emit()
