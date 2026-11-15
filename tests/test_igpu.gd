## hill-igpu-2: the low tier does the bench route's frame fewer ways on the TV box's Intel HD 530.
## The darkness shader (the GPU's biggest 2D cost) loops per chunk only over the lights that reach
## that chunk (both tiers, same picture), low works the light out once per pixel instead of once per
## each of four cells, and low's 3D draw distance, LOD bias and particle budget sit inside the chosen
## numbers. The tier pick and high are pinned in tests/test_graphics.gd.
extends GdUnitTestSuite

const GraphicsScript := preload("res://scripts/autoload/Graphics.gd")
const DarknessOverlay := preload("res://addons/openjar/tileworld/darkness_overlay.gd")
const DemoArt := preload("res://addons/openjar/tileworld/demo/demo_tile_art.gd")

var _g: Node


func before() -> void:
	SuiteSandbox.enter("igpu")


func after() -> void:
	SuiteSandbox.leave()


func after_test() -> void:
	if is_instance_valid(_g):
		_g.free()
	_g = null


func _graphics(tier_name: String) -> Node:
	_g = GraphicsScript.new()
	add_child(_g)
	_g.settings = (GraphicsScript.load_tiers().get(tier_name, {}) as Dictionary).duplicate(true)
	_g.tier = StringName(tier_name)
	return _g


func _palette() -> Array[TileDef]:
	var air := TileDef.new()
	air.id = &"air"
	air.solid = false
	air.breakable = false
	var dirt := TileDef.new()
	dirt.id = &"dirt"
	dirt.color = Color(0.5, 0.35, 0.2)
	return [air, dirt]


## A 4x2-chunk dark world (32-cell chunks, 16 px cells), every chunk loaded around one tracker.
func _dark_world() -> TileWorld:
	var g := LayeredGenerator.new()
	g.bands = [{"from": 0, "tile": 1}]
	g.cave_threshold = 2.0
	var w := TileWorld.new()
	w.water_hz = 0.0
	w.chunk_radius = 3
	w.tile_art = DemoArt.new()
	w.setup(RectShape.new(128, 64, 32), g, _palette(), 1234)
	add_child(w)
	auto_free(w)
	var t := Node2D.new()
	t.position = w.shape.center_of(Vector2i(40, 20))
	w.add_child(t)
	w.track(t)
	w.update_chunks()
	w.set_darkness([{"from": 0, "to": 9999, "darkness": 0.8}])
	return w


func _light(w: TileWorld, cell: Vector2i, radius: float) -> Node2D:
	var n := Node2D.new()
	n.position = w.shape.center_of(cell)
	w.add_child(n)
	auto_free(n)
	w.add_light(n, radius)
	return n


# --- the tier numbers ----------------------------------------------------------------------------

func test_low_draw_distance_lod_and_particles_are_lower_than_high_and_inside_the_numbers() -> void:
	var tiers := GraphicsScript.load_tiers()
	var high: Dictionary = tiers.high
	var low: Dictionary = tiers.low
	assert_dict(high).is_empty()   # high = today's look, nothing applied
	# Draw distance: high keeps each camera's own far plane (Camera3D default 4000).
	var cam := Camera3D.new()
	assert_float(float(low.camera_far)).is_less(cam.far)
	cam.free()
	assert_float(float(low.camera_far)).is_less_equal(80.0)
	# LOD bias: high keeps the project's mesh LOD threshold (1.0 px); low drops detail sooner.
	var high_lod := float(ProjectSettings.get_setting("rendering/mesh_lod/lod_change/threshold_pixels", 1.0))
	assert_float(float(low.mesh_lod_threshold)).is_greater(high_lod)
	assert_float(float(low.mesh_lod_threshold)).is_greater_equal(4.0)
	# Particles: high draws every emitter's amount; low at most half, and at most 12 per emitter.
	assert_float(float(low.particle_scale)).is_less_equal(0.5)
	assert_int(int(low.particle_max)).is_between(1, 12)
	# Darkness: at most 12 lights, worked out once per pixel.
	assert_int(int(low.max_lights)).is_less_equal(12)
	assert_bool(bool(low.darkness_one_tap)).is_true()


func test_low_caps_every_emitter_and_high_leaves_it() -> void:
	var g := _graphics("low")
	var big := CPUParticles2D.new()
	big.amount = 80
	var small := CPUParticles2D.new()
	small.amount = 6
	g.add_child(big)
	g.add_child(small)
	assert_int(big.amount).is_equal(int(g.settings.particle_max))
	assert_int(small.amount).is_equal(3)
	g.free()
	var h := _graphics("high")
	var p := CPUParticles2D.new()
	p.amount = 80
	h.add_child(p)
	assert_int(p.amount).is_equal(80)


# --- darkness: per-chunk lights ------------------------------------------------------------------

func test_each_chunk_loops_only_over_the_lights_that_reach_it() -> void:
	var w := _dark_world()
	var d := w._darkness
	assert_int(d.sprite_keys().size()).is_equal(8)
	_light(w, Vector2i(10, 10), 64.0)    # chunk (0, 0), 4 cells of reach: stays inside it
	_light(w, Vector2i(64, 33), 64.0)    # the corner of four chunks: reaches all four
	_light(w, Vector2i(100, 60), 200.0)  # chunk (3, 1), 4.5 cells from (2, 1): reaches it too
	await get_tree().process_frame
	await get_tree().process_frame
	# material_shared still carries every picked light (tools and older tests read it).
	assert_int(d.material_shared.get_shader_parameter("light_count")).is_equal(3)
	assert_int(d.chunk_light_count(Vector2i(0, 0))).is_equal(1)
	assert_int(d.chunk_light_count(Vector2i(1, 0))).is_equal(1)
	assert_int(d.chunk_light_count(Vector2i(2, 0))).is_equal(1)
	assert_int(d.chunk_light_count(Vector2i(1, 1))).is_equal(1)
	assert_int(d.chunk_light_count(Vector2i(2, 1))).is_equal(2)
	assert_int(d.chunk_light_count(Vector2i(3, 1))).is_equal(1)
	assert_int(d.chunk_light_count(Vector2i(0, 1))).is_equal(0)
	assert_int(d.chunk_light_count(Vector2i(3, 0))).is_equal(0)
	assert_int(d.stat_light_sum).is_equal(7)
	assert_int(d.stat_sprites).is_equal(8)
	# Off: every chunk loops over all three (the old picture, the old cost).
	d.cull_lights = false
	await get_tree().process_frame
	assert_int(d.chunk_light_count(Vector2i(0, 1))).is_equal(3)
	assert_int(d.stat_light_sum).is_equal(24)


func test_a_dropped_light_reaches_no_cell_of_that_chunk() -> void:
	# Exactness: a light left out of a chunk's list is farther than its full radius from every
	# cell centre the chunk's shader evaluates, so it would have added exactly 0 there.
	var w := _dark_world()
	var d := w._darkness
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var placed: Array[Node2D] = []
	for i in 24:
		placed.append(_light(w, Vector2i(rng.randi_range(0, 127), rng.randi_range(0, 63)), rng.randf_range(20.0, 260.0)))
	await get_tree().process_frame
	await get_tree().process_frame
	var picked := d.pick_lights()
	for key in d.sprite_keys():
		var mat: ShaderMaterial = d._mats[key]
		var own: PackedVector4Array = mat.get_shader_parameter("lights")
		var n := int(mat.get_shader_parameter("light_count"))
		var kept := {}
		for i in n:
			kept[Vector2(own[i].x, own[i].y)] = true
		var cells: Array = w._chunk_cells[key]
		for node in picked:
			if kept.has(node.global_position):
				continue
			var r: float = d.lights[node].x
			for c: Vector2i in cells:
				assert_float(w.shape.center_of(c).distance_to(node.global_position)).is_greater(r)
	assert_int(d.stat_light_sum).is_less(picked.size() * d.stat_sprites)


func test_lights_follow_their_node_between_chunks() -> void:
	var w := _dark_world()
	var d := w._darkness
	var lamp := _light(w, Vector2i(10, 10), 64.0)
	await get_tree().process_frame
	assert_int(d.chunk_light_count(Vector2i(0, 0))).is_equal(1)
	assert_int(d.chunk_light_count(Vector2i(3, 1))).is_equal(0)
	lamp.position = w.shape.center_of(Vector2i(110, 50))
	await get_tree().process_frame
	assert_int(d.chunk_light_count(Vector2i(0, 0))).is_equal(0)
	assert_int(d.chunk_light_count(Vector2i(3, 1))).is_equal(1)


# --- darkness: one tap on low --------------------------------------------------------------------

func test_low_puts_the_darkness_on_one_tap_and_high_leaves_four() -> void:
	var w := _dark_world()
	var d := w._darkness
	assert_bool(d.one_tap).is_false()
	assert_str(d.material_shared.shader.code).not_contains("#define ONE_TAP")
	var h := _graphics("high")
	h.apply_node(d)
	assert_bool(d.one_tap).is_false()
	h.free()
	var g := _graphics("low")
	g.apply_node(d)
	assert_bool(d.one_tap).is_true()
	assert_int(d.max_lights).is_equal(int(g.settings.max_lights))
	assert_str(d.material_shared.shader.code).contains("#define ONE_TAP")
	for key in d.sprite_keys():
		assert_object((d._mats[key] as ShaderMaterial).shader).is_same(d.material_shared.shader)
	# A chunk loaded later copies the one-tap material too.
	w.set_darkness([{"from": 0, "to": 9999, "darkness": 0.6}])
	for key in d.sprite_keys():
		assert_object((d._mats[key] as ShaderMaterial).shader).is_same(d.material_shared.shader)
	# Both variants are valid canvas shaders sharing the uniforms the overlay sets.
	for one in [false, true]:
		var params := RenderingServer.get_shader_parameter_list(DarknessOverlay._shader_for(one).get_rid())
		var names := params.map(func(p: Dictionary) -> String: return p.name)
		for u in ["lights", "light_count", "tints", "night", "floor_alpha", "cell_size", "reach"]:
			assert_bool(names.has(u)).override_failure_message("%s missing (one_tap=%s)" % [u, one]).is_true()


func test_parameters_reach_every_chunk_material() -> void:
	var w := _dark_world()
	w.darkness_floor = 0.5
	w.darkness_night = Color(0.1, 0.2, 0.3)
	for key in w._darkness.sprite_keys():
		var m: ShaderMaterial = w._darkness._mats[key]
		assert_float(m.get_shader_parameter("floor_alpha")).is_equal_approx(0.5, 0.0001)
		assert_that(m.get_shader_parameter("night")).is_equal(Color(0.1, 0.2, 0.3))
