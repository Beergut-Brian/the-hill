## gdUnit4 tests for the menu sound synth fallback.
class_name TestUiSound
extends GdUnitTestSuite


func test_every_cue_synthesizes() -> void:
	for cue in UiSound.CUES:
		var s := UiSound.stream(cue)
		assert_object(s).is_not_null()
		assert_int(s.data.size()).is_greater(0)
		assert_float(s.get_length()).is_greater_equal(0.02)
		assert_int(s.mix_rate).is_equal(44100)
		assert_bool(UiSound.stream(cue) == s).is_true() # cached


func test_unknown_cue_has_no_stream() -> void:
	assert_object(UiSound.stream("nope_not_a_cue")).is_null()


func test_play_does_not_crash() -> void:
	for cue in UiSound.CUES:
		UiSound.play(cue)
		UiSound.play(cue, 1.3)
	UiSound.play("nope_not_a_cue")


func test_play_twice_reuses_pool_node() -> void:
	UiSound.play("ui_move")
	await get_tree().process_frame
	var first := get_tree().root.get_node_or_null("UiSound")
	assert_object(first).is_not_null()
	UiSound.play("ui_tick")
	await get_tree().process_frame
	assert_int(get_tree().root.get_children().filter(func(c): return c.name == "UiSound").size()).is_equal(1)
	assert_object(get_tree().root.get_node_or_null("UiSound")).is_same(first)


func before() -> void:
	SuiteSandbox.enter("ui_sound")   # never the real profile, settings or picks file


func after() -> void:
	SuiteSandbox.leave()
