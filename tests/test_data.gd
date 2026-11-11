## gdUnit4: data rows load as the right class, and the pure rules behave.
class_name TestData
extends GdUnitTestSuite

const FOLDERS := {
	"blocks": "BlockData", "layers": "LayerData", "treasures": "TreasureData",
	"buildings": "BuildingData", "vehicles": "VehicleData", "puzzles": "PuzzleData",
}


func _load(folder: String, id: String) -> Resource:
	return load("res://data/%s/%s.tres" % [folder, id])


func _all_blocks() -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at("res://data/blocks"):
		out.append(load("res://data/blocks/" + f))
	return out


func test_every_row_loads_with_class_and_id() -> void:
	for folder in FOLDERS:
		var files := DirAccess.get_files_at("res://data/" + folder)
		assert_int(files.size()).is_greater(0)
		for f in files:
			if not f.ends_with(".tres"):
				continue
			var r := load("res://data/%s/%s" % [folder, f]) as Resource
			assert_object(r).is_not_null()
			assert_str(r.get_script().get_global_name()).is_equal(FOLDERS[folder])
			assert_str(String(r.id)).is_equal(f.get_basename())


func test_unbreakable_blocks_by_version() -> void:
	for id in ["edgestone", "strangestone"]:
		var b := _load("blocks", id) as BlockData
		assert_bool(b.breakable).is_false()
		assert_bool(b.is_breakable_in("1.9.9")).is_false()
		assert_bool(b.is_breakable_in("2.0.0")).is_true()
		assert_bool(b.is_breakable_in("2.1.0")).is_true()
		assert_bool(b.is_breakable_in("2.0.0-dev.3")).is_true()
		assert_bool(b.is_breakable_in("10.0.0")).is_true()
	assert_bool((_load("blocks", "dirt") as BlockData).is_breakable_in("0.0.1")).is_true()


func test_version_compare_is_numeric() -> void:
	var b := BlockData.new()
	b.breakable = false
	b.breakable_from_version = "1.2.0"
	assert_bool(b.is_breakable_in("1.10.0")).is_true()
	b.breakable_from_version = ""
	assert_bool(b.is_breakable_in("9.9.9")).is_false()


func test_layers_tile_0_to_300() -> void:
	var layers: Array = []
	for f in DirAccess.get_files_at("res://data/layers"):
		layers.append(load("res://data/layers/" + f))
	layers.sort_custom(func(a, b): return a.depth_from < b.depth_from)
	assert_int(layers[0].depth_from).is_equal(0)
	for i in range(1, layers.size()):
		assert_int(layers[i].depth_from).is_equal(layers[i - 1].depth_to)
	assert_int(layers[-1].depth_to).is_equal(300)
	for d in 300:
		var n := 0
		for l in layers:
			if l.contains(d):
				n += 1
		assert_int(n).is_equal(1)
	assert_bool(layers[0].contains(30)).is_false()


func test_mole_arrives_on_third_encounter() -> void:
	var s := ResidentState.new()
	s.id = &"mole"
	s.encounters_to_arrive = 3
	assert_bool(s.restore()).is_false()
	assert_bool(s.encounter()).is_false()
	assert_int(s.phase).is_equal(ResidentState.Phase.ENCOUNTERED)
	assert_bool(s.encounter()).is_false()
	assert_bool(s.encounter()).is_true()
	assert_int(s.phase).is_equal(ResidentState.Phase.ARRIVED)
	assert_bool(s.encounter()).is_false()
	assert_int(s.encounters).is_equal(3)
	assert_bool(s.restore()).is_true()
	assert_int(s.phase).is_equal(ResidentState.Phase.RESTORED)
	assert_bool(s.restore()).is_false()
	assert_bool(s.encounter()).is_false()


func test_resident_save_round_trip_through_json() -> void:
	var s := ResidentState.new()
	s.encounters_to_arrive = 3
	s.encounter()
	s.encounter()
	var back = JSON.parse_string(JSON.stringify(s.to_save()))
	var t := ResidentState.new()
	t.load_save(back)
	assert_int(t.phase).is_equal(ResidentState.Phase.ENCOUNTERED)
	assert_int(t.encounters).is_equal(2)


func test_can_show_in_book() -> void:
	var garage := _load("buildings", "garage") as BuildingData
	var barn := _load("buildings", "barn") as BuildingData
	var shed := _load("buildings", "old_shed") as BuildingData
	var unmet := ResidentState.Phase.UNMET
	assert_bool(barn.can_show_in_book([], unmet)).is_true()
	assert_bool(garage.can_show_in_book([], unmet)).is_false()
	assert_bool(garage.can_show_in_book([&"buried_car"], unmet)).is_true()
	assert_bool(shed.can_show_in_book([], unmet)).is_false()
	assert_bool(shed.can_show_in_book([], ResidentState.Phase.ENCOUNTERED)).is_false()
	assert_bool(shed.can_show_in_book([], ResidentState.Phase.ARRIVED)).is_true()
	assert_bool(shed.can_show_in_book([], ResidentState.Phase.RESTORED)).is_false()


func test_can_restore_truth_table() -> void:
	var shed := _load("buildings", "old_shed") as BuildingData
	var mole := ResidentState.new()
	mole.id = &"mole"
	mole.phase = ResidentState.Phase.ARRIVED
	assert_bool(Rules.can_restore(shed, mole, true)).is_true()
	assert_bool(Rules.can_restore(shed, mole, false)).is_false()
	mole.phase = ResidentState.Phase.ENCOUNTERED
	assert_bool(Rules.can_restore(shed, mole, true)).is_false()
	mole.phase = ResidentState.Phase.RESTORED
	assert_bool(Rules.can_restore(shed, mole, true)).is_false()
	var other := ResidentState.new()
	other.id = &"gnome_foreman"
	other.phase = ResidentState.Phase.ARRIVED
	assert_bool(Rules.can_restore(shed, other, true)).is_false()
	mole.phase = ResidentState.Phase.ARRIVED
	assert_bool(Rules.can_restore(_load("buildings", "barn") as BuildingData, mole, true)).is_false()


func test_restore_cost_is_fair() -> void:
	var shed := _load("buildings", "old_shed") as BuildingData
	var tower := _load("buildings", "crooked_watchtower") as BuildingData
	var blocks := _all_blocks()
	assert_bool(Rules.restore_cost_is_fair(shed, 10, blocks)).is_true()
	assert_bool(Rules.restore_cost_is_fair(tower, 10, blocks)).is_false()
	assert_bool(Rules.restore_cost_is_fair(tower, 100, blocks)).is_true()
	assert_bool(Rules.restore_cost_is_fair(shed, 10, [])).is_false()


func test_gnome_award() -> void:
	assert_int(Rules.gnome_award(0.0)).is_equal(0)
	assert_int(Rules.gnome_award(1799.0)).is_equal(0)
	assert_int(Rules.gnome_award(-500.0)).is_equal(0)
	assert_int(Rules.gnome_award(1800.0)).is_equal(20)
	assert_int(Rules.gnome_award(3600.0)).is_equal(20)
	assert_int(Rules.gnome_award(3.0 * 3600.0)).is_equal(30)
	assert_int(Rules.gnome_award(5.0 * 3600.0)).is_equal(50)
	assert_int(Rules.gnome_award(100.0 * 3600.0)).is_equal(50)
	assert_int(Rules.gnome_award(100.0 * 3600.0, 10)).is_equal(60)


func before() -> void:
	SuiteSandbox.enter("data")   # never the real profile, settings or picks file


func after() -> void:
	SuiteSandbox.leave()
