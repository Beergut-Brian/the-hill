extends GdUnitTestSuite

const TOD := preload("res://scripts/autoload/TimeOfDay.gd")


func _fresh() -> Node:
	var n: Node = auto_free(TOD.new())
	n._ready()
	n.frozen = false
	return n


func test_flag_parser() -> void:
	assert_float(TOD.parse_time_flag(PackedStringArray(["--demo", "--time=night"]))).is_equal(0.82)
	assert_float(TOD.parse_time_flag(PackedStringArray(["--time=dusk"]))).is_equal(0.62)
	assert_float(TOD.parse_time_flag(PackedStringArray(["--time=0.4"]))).is_equal_approx(0.4, 0.001)
	assert_float(TOD.parse_time_flag(PackedStringArray(["--time=9"]))).is_equal(1.0)
	assert_float(TOD.parse_time_flag(PackedStringArray(["--demo"]))).is_less(0.0)


func test_phases() -> void:
	assert_str(String(TOD.phase_at(0.3))).is_equal("day")
	assert_str(String(TOD.phase_at(0.62))).is_equal("dusk")
	assert_str(String(TOD.phase_at(0.8))).is_equal("night")
	assert_str(String(TOD.phase_at(0.97))).is_equal("dawn")
	assert_str(String(TOD.phase_at(0.0))).is_equal("dawn")


func test_blend() -> void:
	var t := _fresh()
	t.set_time(0.3)
	assert_that(t.world_tint()).is_equal(Color(1, 1, 1))
	assert_float(t.lights()).is_equal(0.0)
	t.set_time(0.82)
	assert_float(t.world_tint().r).is_equal_approx(0.5, 0.001)
	assert_float(t.lights()).is_equal(1.0)
	assert_float(t.band().a).is_equal(0.0)
	t.set_time(0.62)
	assert_float(t.band().a).is_equal_approx(0.7, 0.001)
	t.set_time(0.67)   # between dusk and night
	assert_float(t.lights()).is_between(0.5, 1.0)
	t.set_time(0.995)  # wraps toward morning
	assert_float(t.world_tint().r).is_equal_approx(1.0, 0.001)
	assert_float(t.world_tint().b).is_between(0.84, 0.92)


func test_phase_signal_and_clock() -> void:
	var t := _fresh()
	t.set_time(0.3)
	var seen: Array = []
	t.phase_changed.connect(func(p: StringName) -> void: seen.append(p))
	t.set_time(0.35)
	assert_array(seen).is_empty()
	t.set_time(0.8)
	assert_array(seen).contains_exactly([&"night"])
	t.running = false
	t._process(100.0)
	assert_float(t.time).is_equal(0.8)
	t.running = true
	t._process(72.0)   # 10 percent of 720 s
	assert_float(t.time).is_equal_approx(0.9, 0.001)


func test_save_round_trip() -> void:
	var t := _fresh()
	t.set_time(0.66)
	var d: Dictionary = t.to_save()
	var u := _fresh()
	u.load_save(d)
	assert_float(u.time).is_equal_approx(0.66, 0.0001)
