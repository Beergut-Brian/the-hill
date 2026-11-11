## Generated textures stay out of res://. Godot's glTF importer used to extract every Jarling
## .glb's embedded images next to it (assets/characters/chuck/chuck_chuck_face.png ...) on
## import, so each run left the tree dirty. project.godot's [importer_defaults] now embeds them
## in the imported scene (.godot/imported/, Godot's own cache). These checks run the import /
## load path and assert nothing lands under res://assets and the faces still load.
class_name TestGeneratedTextures
extends GdUnitTestSuite

const CHARACTERS := "res://assets/characters/"
const EMBED_UNCOMPRESSED := 3  # GLTFState.HANDLE_BINARY_EMBED_AS_UNCOMPRESSED


func _glbs() -> PackedStringArray:
	var out := PackedStringArray()
	for id in DirAccess.get_directories_at(CHARACTERS):
		var glb := CHARACTERS + id + "/" + id + ".glb"
		if FileAccess.file_exists(glb):
			out.append(glb)
	return out


func _textures_of(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var m := mi.get_active_material(s) as BaseMaterial3D
				if m and m.albedo_texture:
					out.append(m.albedo_texture)
	for c in node.get_children():
		_textures_of(c, out)


func test_project_default_embeds_gltf_images() -> void:
	var d: Dictionary = ProjectSettings.get_setting("importer_defaults/scene", {})
	assert_int(int(d.get("gltf/embedded_image_handling", -1))).is_equal(EMBED_UNCOMPRESSED)


func test_every_character_glb_imported_with_embedded_images() -> void:
	var glbs := _glbs()
	assert_int(glbs.size()).is_greater(0)
	for glb in glbs:
		var cfg := ConfigFile.new()
		if cfg.load(glb + ".import") != OK:
			continue  # not imported yet on this machine; the default above covers it
		assert_int(int(cfg.get_value("params", "gltf/embedded_image_handling", -1))) \
			.override_failure_message("%s.import extracts textures into res://" % glb) \
			.is_equal(EMBED_UNCOMPRESSED)


func test_no_extracted_textures_beside_glbs() -> void:
	for glb in _glbs():
		var dir := glb.get_base_dir()
		var id := dir.get_file()
		for f in DirAccess.get_files_at(dir):
			assert_bool(f.begins_with(id + "_") and f.ends_with(".png")) \
				.override_failure_message("generated texture in res://: %s/%s" % [dir, f]) \
				.is_false()


func test_faces_load_from_the_import_cache() -> void:
	var before := DirAccess.get_files_at(CHARACTERS + "jeff").size()
	for id: String in ["jeff", "chuck"]:
		var glb := CHARACTERS + id + "/" + id + ".glb"
		var model: Node = (load(glb) as PackedScene).instantiate()
		var texs: Array = []
		_textures_of(model, texs)
		model.free()
		assert_int(texs.size()).override_failure_message("%s has no textures" % id).is_greater(0)
		for t: Texture2D in texs:
			assert_int(t.get_width()).is_greater(0)
			# Embedded: a sub-resource of the imported scene ("jeff.glb::ImageTexture_..."),
			# not a standalone extracted .png file.
			assert_bool(t.resource_path.contains("::") and not t.resource_path.ends_with(".png")) \
				.override_failure_message("%s texture is a file in res://: %s" % [id, t.resource_path]) \
				.is_true()
	assert_int(DirAccess.get_files_at(CHARACTERS + "jeff").size()).is_equal(before)


func before() -> void:
	SuiteSandbox.enter("generated_textures")   # never the real profile, settings or picks file


func after() -> void:
	SuiteSandbox.leave()
