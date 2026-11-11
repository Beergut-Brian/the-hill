## C-27: the pacing floors in data/BALANCE.md, computed from the real data rows and code constants.
## Each floor is the fastest a player who knows the way can do it (no wandering, no hazards). The
## sheet's `name = N` lines must match what this computes, so a data change that moves a floor
## fails here until BALANCE.md is updated; a floor past its target fails outright.
extends GdUnitTestSuite

const SHEET := "res://data/BALANCE.md"

const CAR_TARGET_S := 5 * 60
const EXCAVATOR_TARGET_S := 15 * 60
const BOTTOM_TARGET_S := 3 * 3600

## Stated allowances (BALANCE.md "Assumptions"): not in any file, kept generous.
const SURFACE_WALK_S := 10.0      # spawn to the cage, once
const SURFACE_WORK_S := 30.0      # drive to rocks and clear the Garage plot with the Front Loader
const BUILD_S := 10.0             # open the book, pick the Garage, place it
const ROLL_OUT_S := 1.0           # Garage door opens, the Excavator rolls out (demo log: 0.97 s)
const CLIMB_ROW_S := 0.75         # dig a step and hop up one row
const INTRO_S := 41.0             # docs/cutscenes.md
const UNLOCK_SCENE_S := 6.0       # docs/cutscenes.md, vehicle_unlock

var _u: Underground


func before_test() -> void:
	Progress.reset()
	Inventory.clear()


func after_test() -> void:
	Progress.reset()
	Inventory.clear()


func _gen() -> HillGenerator:
	_u = auto_free(load("res://scenes/levels/underground.tscn").instantiate())
	add_child(_u)
	return _u.generator


## One row down on foot: a dig, then a one-cell fall.
static func row_down_s(cell: float, gravity: float) -> float:
	return HillPlayer.DIG_EVERY + sqrt(2.0 * cell / gravity)


## One column sideways on foot: a dig, then a one-cell walk.
static func col_side_s(cell: float) -> float:
	return HillPlayer.DIG_EVERY + cell / HillPlayer.WALK


static func ride_s() -> float:
	return HillElevator.DOOR_WAIT + HillElevator.RIDE_TIME


## Everything the floors use, by name, so the sheet and the test print the same numbers.
func floors() -> Dictionary:
	var g := _gen()
	var cell := float(g.shape.cell_size)
	var grav: float = g.shape.gravity
	var down := row_down_s(cell, grav)
	var side := col_side_s(cell)
	var clay_li := g._layer_index(&"clay")
	var top_floor := g.landing_floor(0)
	var car: TreasureData = load("res://data/treasures/buried_car.tres")
	# Worst seed: the car as far from the shaft as CAR_REACH allows.
	var car_off := HillGenerator.CAR_REACH.y
	var car_top := g.landing_floor(clay_li) + 2
	var car_rows := car_top + car.footprint.y - top_floor
	var car_s := INTRO_S + SURFACE_WALK_S + ride_s() + car_rows * down + car_off * side

	# Excavator: trip 1 back up; trip 2 for the Garage's clay (the bag fills with dirt on the way
	# down in the worst case); 10 stone from surface rocks with the Front Loader; build; roll out.
	var garage: BuildingData = load("res://data/buildings/garage.tres")
	var clay_row: LayerData = load("res://data/layers/clay.tres")
	var clay_share := float(clay_row.block_mix.get(&"clay", 0.0))
	var clay_cols := ceili(float(garage.cost.get(&"clay", 0)) / (2.0 * clay_share))
	var back_rows := car_top + car.footprint.y - g.landing_floor(clay_li)
	var trip1_back := car_off * cell / HillPlayer.WALK + back_rows * CLIMB_ROW_S + ride_s()
	var trip2 := ride_s() + clay_cols * side + clay_cols * cell / HillPlayer.WALK + ride_s()
	var stone_s := float(garage.cost.get(&"stone", 0)) * HillPlayer.SCOOP_EVERY
	var exc_s := car_s + trip1_back + trip2 + stone_s + SURFACE_WORK_S + BUILD_S + ROLL_OUT_S + UNLOCK_SCENE_S

	# Bottom: straight down from the Topsoil landing to the cavern roof, if no block stops a shovel.
	var bottom_rows := HillGenerator.CAVERN.position.y - top_floor
	var bottom_s := INTRO_S + SURFACE_WALK_S + ride_s() + bottom_rows * down

	return {
		"row_down_ms": roundi(down * 1000.0), "col_side_ms": roundi(side * 1000.0),
		"car_rows": car_rows, "car_cols": car_off, "car_floor_s": roundi(car_s),
		"clay_cols": clay_cols, "excavator_floor_s": roundi(exc_s),
		"bottom_rows": bottom_rows, "bottom_floor_s": roundi(bottom_s),
		"backpack": Progress.backpack_capacity(),
	}


func test_the_sheet_prints_what_the_data_gives() -> void:
	var f := floors()
	var text := FileAccess.get_file_as_string(SHEET)
	assert_str(text).is_not_empty()
	for k in f:
		assert_str(text).override_failure_message("data/BALANCE.md is stale: want `%s = %s`" % [k, f[k]]) \
			.contains("`%s = %s`" % [k, f[k]])


func test_buried_car_is_reachable_in_five_minutes() -> void:
	assert_int(floors().car_floor_s).is_less_equal(CAR_TARGET_S)


func test_excavator_is_reachable_by_fifteen_minutes() -> void:
	var f := floors()
	assert_int(f.excavator_floor_s).is_less_equal(EXCAVATOR_TARGET_S)
	assert_int(f.excavator_floor_s).is_greater(f.car_floor_s)


func test_garage_costs_are_reachable_before_the_excavator() -> void:
	# The Garage's blocks must come without the Excavator: clay on foot, stone from surface rocks
	# (Front Loader) or the Stone layer. Every block in its cost must be shovel-diggable.
	var garage: BuildingData = load("res://data/buildings/garage.tres")
	for id in garage.cost:
		var b: BlockData = load("res://data/blocks/%s.tres" % id)
		assert_int(b.dig_tier).override_failure_message("%s needs a vehicle" % id).is_equal(0)
	assert_int(garage.cost.values().reduce(func(a, v): return a + v, 0)).is_less_equal(Progress.backpack_capacity())
	var hv: Hillville = auto_free(Hillville.new())
	add_child(hv)
	var rock := 0
	for c in Hillville.COLS:
		if hv.scrub_kind(c) == Hillville.Scrub.ROCK:
			rock += hv.scrub_at(c)
	assert_int(rock).is_greater_equal(int(garage.cost.get(&"stone", 0)))


## KNOWN MISS (BALANCE.md, decision for Gary): nothing gates depth yet, so the bottom is minutes
## away, not hours. When depth gates land (hill-dig-1), this flips: update the sheet and change
## the check to is_greater_equal(BOTTOM_TARGET_S).
func test_bottom_known_miss_is_still_what_the_sheet_says() -> void:
	var f := floors()
	var gated := false
	for path in DirAccess.get_files_at("res://data/blocks/"):
		if not path.ends_with(".tres"):
			continue
		var b: BlockData = load("res://data/blocks/" + path)
		if b.breakable and b.dig_tier > 0:
			gated = true
	assert_bool(gated).override_failure_message("a block now needs a vehicle: re-run the bottom floor in BALANCE.md").is_false()
	assert_int(f.bottom_floor_s).is_less(BOTTOM_TARGET_S)
