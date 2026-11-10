## The Hill's run state that is not tiles or blocks: found treasures, unlocked vehicles, placed
## buildings, each player's deepest layer and last scene, and the backpack size. Autoload: Progress.
## Emits the Events signals for what it owns. Saved by HillSave under the contract's save keys.
extends Node

## A backpack holds BACKPACK_PER_SIZE blocks per size. It starts at BACKPACK_START sizes and each
## Barn adds its effect_amount (1) more. Content can retune both; the kid never sees a number.
const BACKPACK_START := 2
const BACKPACK_PER_SIZE := 20
const VEHICLE_DIR := "res://data/vehicles/"
const BUILDING_DIR := "res://data/buildings/"

signal changed()

var treasures: Array[StringName] = []
var vehicles: Array[StringName] = [&"front_loader"]
## [{"id": StringName, "cell": Vector2i}], in placement order. The index is the building's handle.
var buildings: Array = []
## player -> deepest layer index visited (0 = Topsoil). Index into layers(), sorted by depth.
var deepest := {0: 0, 1: 0}
## player -> &"hillville" | &"underground", where they were when the game last saved.
var scene_of := {0: &"hillville", 1: &"hillville"}

var _vehicle_rows: Array = []
var _building_rows := {}


func reset() -> void:
	treasures.clear()
	vehicles = [&"front_loader"]
	buildings.clear()
	deepest = {0: 0, 1: 0}
	scene_of = {0: &"hillville", 1: &"hillville"}
	changed.emit()


# --- treasures ---------------------------------------------------------------------------------

func has_treasure(id: StringName) -> bool:
	return treasures.has(id)


## True (and Events.treasure_found) only the first time.
func find_treasure(id: StringName, player: int = -1) -> bool:
	if treasures.has(id):
		return false
	treasures.append(id)
	Events.treasure_found.emit(id, player)
	changed.emit()
	return true


# --- vehicles ----------------------------------------------------------------------------------

func vehicle_rows() -> Array:
	if _vehicle_rows.is_empty():
		for f in DirAccess.get_files_at(VEHICLE_DIR):
			var file := f.trim_suffix(".remap")
			if file.ends_with(".tres"):
				_vehicle_rows.append(load(VEHICLE_DIR + file))
		_vehicle_rows.sort_custom(func(a: VehicleData, b: VehicleData) -> bool: return a.order < b.order)
	return _vehicle_rows


func vehicle_data(id: StringName) -> VehicleData:
	for v: VehicleData in vehicle_rows():
		if v.id == id:
			return v
	return null


func has_vehicle(id: StringName) -> bool:
	return vehicles.has(id)


## The lowest-order vehicle not yet unlocked whose treasure (if any) is found; null when none.
func next_vehicle() -> VehicleData:
	for v: VehicleData in vehicle_rows():
		if vehicles.has(v.id):
			continue
		if v.needs_treasure != &"" and not treasures.has(v.needs_treasure):
			return null
		return v
	return null


## The Garage hook: unlocks next_vehicle(), emits Events.vehicle_unlocked. &"" when nothing is left.
func unlock_next_vehicle() -> StringName:
	var v := next_vehicle()
	if v == null:
		return &""
	vehicles.append(v.id)
	Events.vehicle_unlocked.emit(v.id)
	changed.emit()
	return v.id


# --- buildings ---------------------------------------------------------------------------------

func building_data(id: StringName) -> BuildingData:
	if not _building_rows.has(id):
		var path := BUILDING_DIR + String(id) + ".tres"
		_building_rows[id] = load(path) if ResourceLoader.exists(path) else null
	return _building_rows[id]


func count_buildings(id: StringName) -> int:
	var n := 0
	for b in buildings:
		if b.id == id:
			n += 1
	return n


## Records a placement and emits Events.building_placed. Returns the building's index.
func add_building(id: StringName, cell: Vector2i) -> int:
	buildings.append({"id": id, "cell": cell})
	Events.building_placed.emit(id, cell)
	changed.emit()
	return buildings.size() - 1


## Moves building `index` (free) and emits Events.building_moved.
func move_building(index: int, to: Vector2i) -> void:
	var b: Dictionary = buildings[index]
	var from: Vector2i = b.cell
	b.cell = to
	Events.building_moved.emit(b.id, from, to)
	changed.emit()


## Blocks one player's backpack holds: (BACKPACK_START + barn effects) * BACKPACK_PER_SIZE.
func backpack_capacity() -> int:
	var sizes := float(BACKPACK_START)
	for b in buildings:
		var d := building_data(b.id)
		if d != null and d.effect == &"backpack":
			sizes += d.effect_amount
	return int(sizes * BACKPACK_PER_SIZE)


# --- players -----------------------------------------------------------------------------------

## Raises the player's deepest layer; true when it went up.
func visit_layer(player: int, layer_index: int) -> bool:
	if layer_index <= int(deepest.get(player, 0)):
		return false
	deepest[player] = layer_index
	changed.emit()
	return true


func deepest_of(player: int) -> int:
	return int(deepest.get(player, 0))


# --- save --------------------------------------------------------------------------------------

## The contract's "treasures", "vehicles", "buildings" and "players" save values, JSON-safe.
func to_save() -> Dictionary:
	var bl: Array = []
	for b in buildings:
		bl.append({"id": String(b.id), "cell": [b.cell.x, b.cell.y]})
	var pl: Array = []
	for p in 2:
		pl.append({"deepest": deepest_of(p), "scene": String(scene_of.get(p, &"hillville"))})
	return {
		"treasures": treasures.map(func(t: StringName) -> String: return String(t)),
		"vehicles": vehicles.map(func(v: StringName) -> String: return String(v)),
		"buildings": bl,
		"players": pl,
	}


func load_save(data: Dictionary) -> void:
	treasures.clear()
	for t in data.get("treasures", []):
		treasures.append(StringName(str(t)))
	vehicles = [&"front_loader"]
	for v in data.get("vehicles", []):
		if not vehicles.has(StringName(str(v))):
			vehicles.append(StringName(str(v)))
	buildings.clear()
	for b in data.get("buildings", []):
		var c: Array = b.get("cell", [0, 0])
		buildings.append({"id": StringName(str(b.get("id", ""))), "cell": Vector2i(int(c[0]), int(c[1]))})
	var pl: Array = data.get("players", [])
	for p in 2:
		var row: Dictionary = pl[p] if p < pl.size() else {}
		deepest[p] = int(row.get("deepest", 0))
		scene_of[p] = StringName(str(row.get("scene", "hillville")))
	changed.emit()
