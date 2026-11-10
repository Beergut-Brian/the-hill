## A building the player can place, or a ruin to restore (data/buildings/<id>.tres).
class_name BuildingData
extends Resource

@export var id: StringName
## Ground-grid cells, width x height.
@export var footprint: Vector2i
## Block id -> count.
@export var cost: Dictionary
## &"" or a TreasureData id that must be found first.
@export var needs_treasure: StringName
## &"" or the vehicle that can place it (crane for tall ones).
@export var needs_vehicle: StringName
## &"backpack", &"next_vehicle", &"light_layer", &"dig_power", &"drain", &"gnome_crew", &"museum", &"warm_ice", &"".
@export var effect: StringName
@export var effect_amount: float = 1.0
@export var scene: PackedScene
## A ruin: unclearable, unbuildable, restored instead of built.
@export var is_ruin: bool = false
## Ruins only: who it is for.
@export var resident: StringName
## Ruins only: the BuildingData id it becomes.
@export var restores_into: StringName


## Ruins show only once their resident has ARRIVED. Others show when their treasure is
## found (or none needed). Affordability never hides a card; it greys it.
func can_show_in_book(found_treasures: Array, resident_phase: int) -> bool:
	if is_ruin:
		return resident_phase == ResidentState.Phase.ARRIVED
	return needs_treasure == &"" or found_treasures.has(needs_treasure)
