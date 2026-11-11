## Store art and the launcher jar (V-08, S-16). The release manifest names store/jar.glb and the
## zip carries it; the jar fits the launcher contract (openjar-launcher docs/contracts.md "Jar
## world": <= 5,000 triangles, <= 8 materials, textures <= 512 px, no lights or cameras, stands on
## the origin inside r 0.8 x h 1.9); grid.png and hero.png exist at the TV's sizes.
## Rebuild: art/tools/make_jar.sh (Blender) and art/tools/render_store.sh (renderer).
class_name TestStore
extends GdUnitTestSuite

const JAR := "res://store/jar.glb"
const WORKFLOW := "res://.github/workflows/release.yml"

var _real_settings := ""
var _tmp := ""


func before_test() -> void:
	# Never the real settings file.
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_store.json"
	Save.reload_settings()
	_tmp = OS.get_cache_dir().path_join("the_hill_store_test_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(_tmp)


func after_test() -> void:
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	if _tmp.contains("the_hill_store_test_"):
		_rm(_tmp)


func _rm(dir: String) -> void:
	for d in DirAccess.get_directories_at(dir):
		_rm(dir.path_join(d))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


## The `run: |` body of a workflow step, dedented.
func _step(title: String) -> String:
	var lines := FileAccess.get_file_as_string(WORKFLOW).split("\n")
	var i := 0
	while i < lines.size() and not lines[i].strip_edges().ends_with("name: " + title):
		i += 1
	while i < lines.size() and not lines[i].strip_edges().begins_with("run:"):
		i += 1
	if i < lines.size() and not lines[i].strip_edges().begins_with("run: |"):
		return lines[i].strip_edges().trim_prefix("run:").strip_edges()   # a one-line step
	i += 1
	var body := PackedStringArray()
	var indent := -1
	while i < lines.size():
		var l := lines[i]
		var lead := l.length() - l.strip_edges(true, false).length()
		if l.strip_edges() != "":
			if indent < 0:
				indent = lead
			elif lead < indent:
				break
		body.append(l.substr(indent) if l.length() >= indent and indent >= 0 else "")
		i += 1
	return "\n".join(body)


func _copy(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to.get_base_dir())
	assert_int(DirAccess.copy_absolute(ProjectSettings.globalize_path(from), to)).is_equal(OK)


## Runs the workflow's own "Write launcher manifest" step in a scratch checkout (project.godot and
## store/ only) the way CI does, for a dev tag.
func _run_manifest_step() -> Dictionary:
	_copy("res://project.godot", _tmp.path_join("project.godot"))
	for f in ["jar.glb", "grid.png", "hero.png"]:
		_copy("res://store/" + f, _tmp.path_join("store").path_join(f))
	DirAccess.make_dir_recursive_absolute(_tmp.path_join("build"))
	var script := _tmp.path_join("manifest.sh")
	var fa := FileAccess.open(script, FileAccess.WRITE)
	fa.store_string("set -e\ncd '%s'\nexport GITHUB_REF_NAME=v0.3.0-dev.4 GITHUB_REPOSITORY=owner/the-hill\n%s\n" % [_tmp, _step("Write launcher manifest")])
	fa.close()
	var out := []
	var code := OS.execute("bash", [script], out, true)
	assert_int(code).override_failure_message("manifest step failed: %s" % str(out)).is_equal(0)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_tmp.path_join("build/openjar.json")))
	assert_bool(parsed is Dictionary).override_failure_message("openjar.json is not JSON: %s" % str(out)).is_true()
	return parsed if parsed is Dictionary else {}


func test_manifest_names_the_jar() -> void:
	var m := _run_manifest_step()
	assert_str(str(m.get("jar", ""))).is_equal("store/jar.glb")
	assert_str(str(m.get("grid", ""))).is_equal("store/grid.png")
	assert_str(str(m.get("hero", ""))).is_equal("store/hero.png")
	assert_str(str(m.get("slug", ""))).is_equal("the-hill")
	assert_bool(m.get("dev", false)).is_true()


func test_zip_carries_the_jar_and_store_art() -> void:
	_run_manifest_step()
	# The Zip step zips the whole build folder (`cd build && zip -r ... .`); do the same here.
	assert_str(_step("Zip")).contains("cd build && zip -r")
	var zip_path := _tmp.path_join("the-hill.zip")
	var zp := ZIPPacker.new()
	assert_int(zp.open(zip_path)).is_equal(OK)
	var build := _tmp.path_join("build")
	for rel in _files_under(build, ""):
		zp.start_file(rel)
		zp.write_file(FileAccess.get_file_as_bytes(build.path_join(rel)))
		zp.close_file()
	zp.close()
	var zr := ZIPReader.new()
	assert_int(zr.open(zip_path)).is_equal(OK)
	var names := zr.get_files()
	for want in ["openjar.json", "store/jar.glb", "store/grid.png", "store/hero.png"]:
		assert_bool(names.has(want)).override_failure_message("zip lacks %s: %s" % [want, str(names)]).is_true()
	var glb := zr.read_file("store/jar.glb")
	zr.close()
	assert_int(glb.size()).is_equal(FileAccess.get_file_as_bytes(JAR).size())
	assert_str(glb.slice(0, 4).get_string_from_ascii()).is_equal("glTF")


func _files_under(root: String, rel: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := root.path_join(rel)
	for f in DirAccess.get_files_at(dir):
		out.append(rel.path_join(f) if rel != "" else f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files_under(root, rel.path_join(d) if rel != "" else d))
	return out


func test_store_images_are_the_tv_sizes() -> void:
	for pair in [["res://store/grid.png", Vector2i(600, 900)], ["res://store/hero.png", Vector2i(920, 430)]]:
		var img := Image.load_from_file(ProjectSettings.globalize_path(pair[0]))
		assert_object(img).override_failure_message("%s missing" % pair[0]).is_not_null()
		if img != null:
			assert_vector(Vector2(img.get_size())).is_equal(Vector2(pair[1]))


func _load_jar() -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert_int(doc.append_from_file(ProjectSettings.globalize_path(JAR), state)).is_equal(OK)
	return doc.generate_scene(state) as Node3D


func test_jar_fits_the_launcher_budget() -> void:
	var root := _load_jar()
	assert_object(root).is_not_null()
	var tris := 0
	var mats := {}
	var textures_ok := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			assert_object(mat).is_not_null()
			mats[mat] = true
			var tex := mat.albedo_texture   # untextured glTF materials lose their colour in the launcher
			assert_object(tex).is_not_null()
			if tex != null and (tex.get_width() > 512 or tex.get_height() > 512):
				textures_ok = false
	assert_int(tris).is_greater(1000).is_less_equal(5000)
	assert_int(mats.size()).is_between(1, 8)
	assert_bool(textures_ok).is_true()
	assert_int(root.find_children("*", "Light3D", true, false).size()).is_equal(0)
	assert_int(root.find_children("*", "Camera3D", true, false).size()).is_equal(0)
	assert_int(root.find_children("*", "Label3D", true, false).size()).is_equal(0)
	root.free()


func test_jar_stands_on_its_floor_inside_the_jar() -> void:
	var root := _load_jar()
	var box := AABB()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var b := _xf(mi) * mi.get_aabb()
		box = b if box.size == Vector3.ZERO else box.merge(b)
	assert_float(box.position.y).is_equal_approx(0.0, 0.02)
	assert_float(box.get_center().x).is_equal_approx(0.0, 0.12)
	assert_float(box.get_center().z).is_equal_approx(0.0, 0.12)
	assert_float(box.end.y).is_less_equal(1.9)
	for edge: float in [box.position.x, box.end.x, box.position.z, box.end.z]:
		assert_float(absf(edge)).is_less_equal(0.8)
	assert_float(box.size.y).is_greater(1.0)   # a tall slice: the layers below, the town on top
	root.free()


static func _xf(n: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	while n != null:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


func before() -> void:
	SuiteSandbox.enter("store")   # never the real profile, settings or picks file


func after() -> void:
	SuiteSandbox.leave()
