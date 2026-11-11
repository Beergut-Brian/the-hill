## Jar check: loads store/jar.glb the way the launcher does (GLTFDocument at runtime) and shows it
## from four sides of the turntable under a plain warm key light. Not game content.
##   godot-render --path . --resolution 1600x900 res://art/store/jar_preview.tscn -- --out=/abs/x.png [--jar=/abs/jar.glb]
extends Node3D


func _ready() -> void:
	var out := ""
	var path := ProjectSettings.globalize_path("res://store/jar.glb")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--jar="):
			path = a.trim_prefix("--jar=")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2b2440")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c8c0e0")
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff1d6")
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-45, 30, 0)
	add_child(sun)
	for i in 4:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(path, state) != OK:
			push_error("jar_preview: cannot load %s" % path)
			return
		var jar := doc.generate_scene(state) as Node3D
		jar.position = Vector3(-2.4 + i * 1.6, 0, 0)
		jar.rotation_degrees.y = i * 90.0
		add_child(jar)
	var cam := Camera3D.new()
	cam.fov = 40
	cam.position = Vector3(0, 1.6, 5.6)
	add_child(cam)
	cam.look_at(Vector3(0, 0.6, 0))
	if out != "":
		for i in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out)
		print("frame: ", out)
		get_tree().quit()
