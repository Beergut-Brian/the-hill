## The lobby's version label is the release tag CI stamped into data/build.json, or "dev".
class_name TestBuildInfo
extends GdUnitTestSuite

const FILE := "user://test_build_info/build.json"


func after() -> void:
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(FILE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE.get_base_dir()))
	SuiteSandbox.leave()


func _write(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(FILE.get_base_dir())
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_the_stamped_tag_is_the_label() -> void:
	_write('{ "version": "v0.0.2-dev.3", "commit": "abc" }')
	assert_str(BuildInfo.version(FILE)).is_equal("v0.0.2-dev.3")
	assert_str(BuildInfo.label(FILE)).is_equal("v0.0.2-dev.3")
	_write('{ "version": "1.2.0" }')
	assert_str(BuildInfo.label(FILE)).is_equal("v1.2.0")


func test_no_file_or_a_broken_one_says_dev() -> void:
	assert_str(BuildInfo.label("user://test_build_info/missing.json")).is_equal("dev")
	_write("{ not json")
	assert_str(BuildInfo.label(FILE)).is_equal("dev")
	_write('{ "version": "" }')
	assert_str(BuildInfo.label(FILE)).is_equal("dev")


func test_the_lobby_footer_shows_it() -> void:
	SuiteSandbox.enter("build_info")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var label: Label = main.get_node("UI/Lobby/Footer/Version")
	assert_str(label.text).is_equal(BuildInfo.label())
	if not FileAccess.file_exists(BuildInfo.FILE):
		assert_str(label.text).is_equal("dev")         # the editor / a local run
	main.free()
	var w := get_tree().root.get_node_or_null("ShowtimeWipe")
	if w:
		w.free()
