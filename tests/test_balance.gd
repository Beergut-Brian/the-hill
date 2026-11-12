## C-27: the pacing floors in data/BALANCE.md, computed from the real data rows and code constants
## (data/dig.tres hit points, data/gates bands, data/blocks toughness, vehicles, buildings).
## Each floor is the fastest a player who knows the way can do it (no wandering, no hazards). The
## sheet's `name = N` lines must match what this computes, so a data change that moves a floor
## fails here until BALANCE.md is updated; a floor past its target fails outright.
extends GdUnitTestSuite

const SHEET := "res://data/BALANCE.md"

const CAR_TARGET_S := 5 * 60
const EXCAVATOR_TARGET_S := 15 * 60
const BOTTOM_TARGET_S := 3 * 3600
const BOTTOM_TARGET_MAX_S := 4 * 3600

## Stated allowances (BALANCE.md "Assumptions"): not in any file, kept generous.
const SURFACE_WALK_S := 10.0      # spawn to the cage, once
const SURFACE_WORK_S := 30.0      # drive to rocks and clear the Garage plot with the Front Loader
const BUILD_S := 10.0             # open the book, pick the Garage, place it
const ROLL_OUT_S := 1.0           # Garage door opens, the Excavator rolls out (demo log: 0.97 s)
const CLIMB_ROW_S := 0.75         # dig a step and hop up one row
const INTRO_S := 41.0             # docs/cutscenes.md
const UNLOCK_SCENE_S := 6.0       # docs/cutscenes.md, vehicle_unlock
const PUZZLE_SEEDS := 200         # seeds 0..199 swept for C-22 puzzles on the floors' routes

var _u: Underground
var _tun: DigTuning


func before_test() -> void:
	Progress.reset()
	Inventory.clear()


func after_test() -> void:
	Progress.reset()
	Inventory.clear()


func _gen() -> HillGenerator:
	_u = auto_free(load("res://scenes/levels/underground.tscn").instantiate())
	add_child(_u)
	_tun = DigTuning.get_default()
	return _u.generator


static func _block(id: StringName) -> BlockData:
	return load("res://data/blocks/%s.tres" % id)


## The layer's main block (the biggest share of its mix): what a straight shaft mostly digs.
static func _main_block(l: LayerData) -> BlockData:
	var best := &""
	var share := -1.0
	for k in l.block_mix:
		if float(l.block_mix[k]) > share:
			share = float(l.block_mix[k])
			best = k
	return _block(best)


## Seconds to take one tile with A held: every hit, the first included, costs one interval before
## the next tile's first hit can land (hill_player.gd `_dig_cd`). tier -1 = on foot.
func tile_s(tough: int, level: int, tier: int) -> float:
	return _tun.hits_for(tough, level, tier) * _tun.every_for(level, tier)


## The toughness a straight shaft meets at `row`: Gate Rock in a band, else the layer's main block.
func tough_at(g: HillGenerator, row: int) -> int:
	if not g.gate_band_at(row).is_empty():
		return _block(&"gaterock").toughness
	return _main_block(g.layer_rows[g.layer_of_depth(row)]).toughness


## Digging straight down from `from_row` (the floor stood on) to `to_row` (exclusive): each row a
## tile, then a one-cell fall.
func shaft_s(g: HillGenerator, from_row: int, to_row: int, level: int, tier: int) -> float:
	var fall := sqrt(2.0 * g.shape.cell_size / g.shape.gravity)
	var s := 0.0
	for r in range(from_row, to_row):
		s += tile_s(tough_at(g, r), level, tier) + fall
	return s


static func ride_s() -> float:
	return HillElevator.DOOR_WAIT + HillElevator.RIDE_TIME


static func _vehicle(id: StringName) -> VehicleData:
	return load("res://data/vehicles/%s.tres" % id)


## Everything the floors use, by name, so the sheet and the test print the same numbers.
func floors() -> Dictionary:
	var g := _gen()
	var cell := float(g.shape.cell_size)
	var fall := sqrt(2.0 * cell / g.shape.gravity)
	var dirt := _block(&"dirt").toughness
	var clay_li := g._layer_index(&"clay")
	var stone_li := g._layer_index(&"stone")
	var top_floor := g.landing_floor(0)
	var clay_tough := _main_block(g.layer_rows[clay_li]).toughness
	var stone_tough := _main_block(g.layer_rows[stone_li]).toughness
	var workshop: BuildingData = load("res://data/buildings/workshop.tres")
	var garage: BuildingData = load("res://data/buildings/garage.tres")
	var car: TreasureData = load("res://data/treasures/buried_car.tres")
	var exc := _vehicle(&"excavator")
	var rig := _vehicle(&"drill_rig")
	var drive1 := 1.0 + HillPlayer.TOOL_DRIVE   # Workshop level 1

	# On foot in plain dirt: the starting shovel and the Sturdy Shovel (1 Workshop).
	var down0 := tile_s(dirt, 0, -1) + fall
	var down1 := tile_s(dirt, 1, -1) + fall
	var side1_clay := tile_s(clay_tough, 1, -1) + cell / HillPlayer.WALK

	# Stage 0: intro, walk to the cage.
	var start_s := INTRO_S + SURFACE_WALK_S
	# The Workshop first: the Clay band breaks only for the Sturdy Shovel or a tier-1 vehicle, and
	# the tier-1 vehicle needs the car, which is under that band. Its stone from surface rocks.
	var workshop_s := SURFACE_WORK_S + float(workshop.cost.get(&"stone", 0)) * HillPlayer.SCOOP_EVERY + BUILD_S

	# Target 1: the car (worst seed: CAR_REACH.y columns from the shaft).
	var car_off := HillGenerator.CAR_REACH.y
	var car_top := g.landing_floor(clay_li) + 2
	var car_bottom := car_top + car.footprint.y
	var car_rows := car_bottom - top_floor
	var car_dig := shaft_s(g, top_floor, car_bottom, 1, -1)
	var car_s := start_s + workshop_s + ride_s() + car_dig + car_off * side1_clay

	# Target 2: the Excavator. Back up, a second trip for the Garage's clay (worst case the bag
	# filled with dirt on the way down), its stone from surface rocks, build, roll out.
	var clay_row: LayerData = g.layer_rows[clay_li]
	var clay_share := float(clay_row.block_mix.get(&"clay", 0.0))
	var clay_cols := ceili(float(garage.cost.get(&"clay", 0)) / (2.0 * clay_share))
	var back_rows := car_bottom - g.landing_floor(clay_li)
	var trip1_back := car_off * cell / HillPlayer.WALK + back_rows * CLIMB_ROW_S + ride_s()
	var trip2 := ride_s() + clay_cols * side1_clay + clay_cols * cell / HillPlayer.WALK + ride_s()
	var garage_stone_s := float(garage.cost.get(&"stone", 0)) * HillPlayer.SCOOP_EVERY
	var roll_s := BUILD_S + ROLL_OUT_S + UNLOCK_SCENE_S
	var exc_s := car_s + trip1_back + trip2 + garage_stone_s + SURFACE_WORK_S + roll_s

	# Target 3: the bottom. The Crystal and Bottom bands break only for dig_tier 3 (the Drill Rig,
	# which needs the Giant Tooth in Stone and the 4th Garage). Route: the Excavator rides to Clay,
	# digs to the tooth (default seed); the player climbs to the Stone landing and rides up; three
	# more Garages (their blocks hauled with the Excavator); the Drill Rig rides to Stone and drills
	# to the cavern roof.
	var tooth := Rect2i()
	for t: Dictionary in g.treasure_spots:
		if t.id == &"giant_tooth":
			tooth = t.rect
	var tooth_bottom := tooth.end.y
	var tooth_cols := absi(tooth.get_center().x - HillGenerator.SHAFT_X)
	var exc_side := tile_s(stone_tough, 1, exc.dig_tier) + cell / (exc.speed * drive1)
	var tooth_s := ride_s() + shaft_s(g, g.landing_floor(clay_li), tooth_bottom, 1, exc.dig_tier) \
		+ tooth_cols * exc_side
	var stone_floor := g.landing_floor(stone_li)
	var tooth_back := tooth_cols * cell / HillPlayer.WALK \
		+ maxi(tooth_bottom - stone_floor, 0) * CLIMB_ROW_S + ride_s()
	var more_garages := rig.order - exc.order
	var haul: int = more_garages * garage.cost.values().reduce(func(a, v): return a + v, 0)
	var bag := int(Progress.backpack_capacity() * exc.carry)
	var haul_trips := ceili(float(haul) / float(bag))
	var haul_s := haul_trips * 2.0 * ride_s() \
		+ ceilf(float(haul) / exc.dig_shape.size()) * exc_side
	var garages_s := more_garages * roll_s
	var drill_s := ride_s() + shaft_s(g, stone_floor, HillGenerator.CAVERN.position.y, 1, rig.dig_tier)
	var bottom_s := exc_s + tooth_s + tooth_back + haul_s + garages_s + drill_s

	# Gary's pick (not in data): if the last band opened only for the Dragon Egg, the Drill Rig
	# would turn off its shaft in Crystal, drill to the egg and drive back (the shaft passes its rows).
	var egg_cols := 0
	for t: Dictionary in g.treasure_spots:
		if t.id == &"dragon_egg":
			egg_cols = absi(t.rect.get_center().x - HillGenerator.SHAFT_X)
	var crystal_tough := _main_block(g.layer_rows[g._layer_index(&"crystal")]).toughness
	var rig_side := tile_s(crystal_tough, 1, rig.dig_tier) + cell / (rig.speed * drive1)
	var egg_detour := egg_cols * rig_side + egg_cols * cell / (rig.speed * drive1)

	var f := {
		"egg_cols": egg_cols, "egg_detour_s": roundi(egg_detour),
		"row_down_ms": roundi(down0 * 1000.0), "row_down_sturdy_ms": roundi(down1 * 1000.0),
		"col_side_ms": roundi(side1_clay * 1000.0),
		"workshop_s": roundi(workshop_s),
		"car_rows": car_rows, "car_cols": car_off, "car_dig_s": roundi(car_dig),
		"car_floor_s": roundi(car_s),
		"clay_cols": clay_cols, "excavator_floor_s": roundi(exc_s),
		"tooth_row": tooth.position.y, "tooth_cols": tooth_cols, "tooth_s": roundi(tooth_s + tooth_back),
		"haul_blocks": haul, "haul_trips": haul_trips, "haul_s": roundi(haul_s),
		"drill_rows": HillGenerator.CAVERN.position.y - stone_floor, "drill_s": roundi(drill_s),
		"rig_crystal_row_s": roundi(tile_s(crystal_tough, 1, rig.dig_tier) + fall),
		"bottom_floor_s": roundi(bottom_s),
		"backpack": Progress.backpack_capacity(),
	}
	# The depth gates: the row each band starts at, and the fastest arrival at its top row on foot
	# (bands deeper than the first vehicle-only one cannot be reached on foot: -1).
	var foot_blocked := false
	for b: Dictionary in g.gate_bands:
		var gate: DepthGate = b.gate
		var key := "gate_%s" % gate.opens
		f[key + "_row"] = b.from
		if foot_blocked:
			f[key + "_foot_s"] = -1
		else:
			var first: bool = b.from == (g.gate_bands[0] as Dictionary).from
			var lvl := 0 if first else 1
			var pre := start_s + (0.0 if first else workshop_s)
			f[key + "_foot_s"] = roundi(pre + ride_s() + shaft_s(g, top_floor, b.from, lvl, -1))
		if gate.shovel_level <= 0 and gate.treasure == &"" and gate.resident == &"":
			foot_blocked = true
	# C-22 puzzles (data/puzzles, Clay): the cells that stop the floors' straight lines. A boulder
	# wall's slab is Hard Rock (vehicle-only) between unbreakable sides; a vehicle block opens only
	# for its vehicle. Count, over PUZZLE_SEEDS seeds, how often one sits in the car tunnel (on foot,
	# the Sturdy Shovel) or the Clay stretch of the shaft (the Excavator to the tooth). The floors
	# assume the line is clear, so these seeds pay a detour the floors leave out.
	var shaft_clay := Rect2i(HillGenerator.SHAFT_X, g.landing_floor(clay_li),
			2, g.landing_floor(stone_li) - g.landing_floor(clay_li))
	var on_car := 0
	var on_shaft := 0
	var default_seed := g.world_seed
	var default_clear := true
	for i in PUZZLE_SEEDS + 1:
		var s := default_seed if i == 0 else i - 1
		g._plan(s)
		var car_tunnel := Rect2i()
		for t: Dictionary in g.treasure_spots:
			if t.id == &"buried_car":
				var cr: Rect2i = t.rect
				car_tunnel = Rect2i(cr.end.x, cr.position.y, HillGenerator.SHAFT_X - cr.end.x, cr.size.y)
		var stops: Array[Rect2i] = []
		for w: Dictionary in g.walls:
			stops.append(w.slab)
			stops.append_array(w.sides)
		for vb: Dictionary in g.vehicle_blocks:
			stops.append(vb.rect)
		var hit_car := false
		var hit_shaft := false
		for r in stops:
			hit_car = hit_car or r.intersects(car_tunnel)
			hit_shaft = hit_shaft or r.intersects(shaft_clay)
		if i == 0:
			default_clear = not (hit_car or hit_shaft)
			continue
		on_car += int(hit_car)
		on_shaft += int(hit_shaft)
	g._plan(default_seed)
	f["puzzle_seeds"] = PUZZLE_SEEDS
	f["puzzle_car_seeds"] = on_car
	f["puzzle_shaft_seeds"] = on_shaft
	f["puzzle_default_seed_clear"] = default_clear
	return f


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


func test_surface_stone_pays_for_the_workshop_and_the_garage() -> void:
	# Before the Excavator no stone layer is open (the Stone band), so the Workshop's and the first
	# Garage's stone must come from surface rocks (the Front Loader). Clay is dug on foot.
	var workshop: BuildingData = load("res://data/buildings/workshop.tres")
	var garage: BuildingData = load("res://data/buildings/garage.tres")
	assert_bool(_block(&"clay").vehicle_only).is_false()
	assert_int(garage.cost.values().reduce(func(a, v): return a + v, 0)).is_less_equal(Progress.backpack_capacity())
	var hv: Hillville = auto_free(Hillville.new())
	add_child(hv)
	var rock := 0
	for c in Hillville.COLS:
		if hv.scrub_kind(c) == Hillville.Scrub.ROCK:
			rock += hv.scrub_at(c)
	var want := int(workshop.cost.get(&"stone", 0)) + int(garage.cost.get(&"stone", 0))
	assert_int(rock).override_failure_message("surface rocks %d < %d stone" % [rock, want]).is_greater_equal(want)


## Every band opens for something the player can already have when they reach it: a Workshop
## shovel, a resident, or a vehicle whose treasure lies in a layer above the band.
func test_every_band_opens_with_something_reachable() -> void:
	var g := _gen()
	for b: Dictionary in g.gate_bands:
		var gate: DepthGate = b.gate
		var band_layer: int = b.layer
		var opener := ""
		if gate.shovel_level > 0:
			opener = "shovel"
		if gate.resident != &"":
			opener = "resident"
		if gate.vehicle_tier > 0:
			for v: VehicleData in Progress.vehicle_rows():
				if v.dig_tier < gate.vehicle_tier:
					continue
				if v.needs_treasure == &"":
					opener = String(v.id)
					break
				var t: TreasureData = load("res://data/treasures/%s.tres" % v.needs_treasure)
				if g._layer_index(t.layer) < band_layer:
					opener = String(v.id)
					break
		assert_str(opener).override_failure_message("%s: nothing reachable opens it" % gate.id).is_not_empty()


## The floors' bottom route is the only one: the deepest bands break for nothing below the Drill
## Rig's tier, and the Dragon Egg that also opens the last one lies behind the Crystal band.
func test_the_bottom_needs_the_drill_rig() -> void:
	var g := _gen()
	var rig := _vehicle(&"drill_rig")
	var last: Dictionary = g.gate_bands[g.gate_bands.size() - 1]
	var crystal: Dictionary = g.gate_bands[g.gate_bands.size() - 2]
	for b: Dictionary in [crystal, last]:
		var gate: DepthGate = b.gate
		assert_int(gate.shovel_level).is_equal(0)
		assert_str(String(gate.resident)).is_empty()
		assert_int(gate.vehicle_tier).is_equal(rig.dig_tier)
	var egg_gate: DepthGate = last.gate
	if egg_gate.treasure != &"":
		var egg: TreasureData = load("res://data/treasures/%s.tres" % egg_gate.treasure)
		assert_int(g._layer_index(egg.layer)).is_greater_equal(crystal.layer)


## C-27 (bottom-1 lane, 2026-11-12): Crystal's hit points carry the bottom floor into the 3 to 4 h
## target; the Drill Rig's auto-drill does the slow part on its own.
func test_bottom_lands_in_three_to_four_hours() -> void:
	var f := floors()
	assert_int(f.bottom_floor_s).is_greater(f.excavator_floor_s)
	assert_int(f.bottom_floor_s).is_greater_equal(BOTTOM_TARGET_S)
	assert_int(f.bottom_floor_s).is_less_equal(BOTTOM_TARGET_MAX_S)
