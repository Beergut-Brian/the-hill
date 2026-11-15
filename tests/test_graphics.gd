## S-20: graphics tiers (scripts/autoload/Graphics.gd, data/graphics.json) and --bench
## (scripts/gameplay/bench_runner.gd). The suite never changes the real root viewport: tier settings
## go on throwaway Graphics instances and nodes made here.
extends GdUnitTestSuite

const GraphicsScript := preload("res://scripts/autoload/Graphics.gd")
const Bench := preload("res://scripts/gameplay/bench_runner.gd")
const DarknessOverlay := preload("res://addons/openjar/tileworld/darkness_overlay.gd")

var _g: Node


func before() -> void:
	SuiteSandbox.enter("graphics")


func after() -> void:
	SuiteSandbox.leave()


func after_test() -> void:
	if is_instance_valid(_g):
		_g.free()
	_g = null


## A Graphics node with `tier_name`'s settings, listening for nodes like the autoload, without
## touching the root window (set_tier would).
func _graphics(tier_name: String) -> Node:
	_g = GraphicsScript.new()
	add_child(_g)   # _ready: headless, so high and nothing applied
	_g.settings = (GraphicsScript.load_tiers().get(tier_name, {}) as Dictionary).duplicate(true)
	_g.tier = StringName(tier_name)
	return _g


func _tier(adapter: String, vendor: String, flag := "", headless := false) -> String:
	return String(GraphicsScript.pick_tier(adapter, vendor, flag, headless).tier)


# --- the pick ------------------------------------------------------------------------------------

func test_intel_hd_530_is_low() -> void:
	assert_str(_tier("Intel(R) HD Graphics 530 (SKL GT2)", "Intel")).is_equal("low")
	assert_str(_tier("Mesa Intel(R) HD Graphics 530 (SKL GT2)", "Intel Open Source Technology Center")).is_equal("low")
	assert_str(_tier("Intel(R) HD Graphics 530", "Intel Corporation")).is_equal("low")


func test_gtx_1060_is_high() -> void:
	assert_str(_tier("NVIDIA GeForce GTX 1060 6GB", "NVIDIA Corporation")).is_equal("high")
	assert_str(_tier("NVIDIA GeForce GTX 1060 3GB/PCIe/SSE2", "NVIDIA")).is_equal("high")


func test_amd_discrete_high_integrated_low() -> void:
	assert_str(_tier("AMD Radeon RX 580 Series (RADV POLARIS10)", "AMD")).is_equal("high")
	assert_str(_tier("AMD Radeon Graphics (RADV RENOIR)", "AMD")).is_equal("low")
	assert_str(_tier("AMD Radeon(TM) Vega 8 Graphics", "ATI Technologies Inc.")).is_equal("low")
	assert_str(_tier("AMD Custom GPU 0405 (RADV VANGOGH)", "AMD")).is_equal("low")


func test_software_and_unknown_are_low() -> void:
	assert_str(_tier("llvmpipe (LLVM 21.1.8, 256 bits)", "Mesa")).is_equal("low")
	assert_str(_tier("Some Brand New GPU", "")).is_equal("low")
	assert_str(_tier("", "")).is_equal("low")


func test_headless_without_a_renderer_stays_high() -> void:
	assert_str(_tier("", "", "", true)).is_equal("high")


func test_the_flag_overrides_the_gpu() -> void:
	assert_str(_tier("NVIDIA GeForce GTX 1060 6GB", "NVIDIA Corporation", "low")).is_equal("low")
	assert_str(_tier("Intel(R) HD Graphics 530 (SKL GT2)", "Intel", "high")).is_equal("high")
	assert_str(_tier("", "", "low", true)).is_equal("low")
	assert_str(GraphicsScript.flag_from_args(PackedStringArray(["--graphics=low"]))).is_equal("low")
	assert_str(GraphicsScript.flag_from_args(PackedStringArray(["--x", "--graphics=HIGH"]))).is_equal("high")
	assert_str(GraphicsScript.flag_from_args(PackedStringArray(["--graphics=ultra"]))).is_equal("")
	assert_str(GraphicsScript.flag_from_args(PackedStringArray())).is_equal("")


func test_dev_builds_show_the_tier_next_to_the_version() -> void:
	assert_str(GraphicsScript.version_label("dev", &"low")).is_equal("dev · low")
	assert_str(GraphicsScript.version_label("v0.6.0-dev.2", &"high")).is_equal("v0.6.0-dev.2 · high")
	assert_str(GraphicsScript.version_label("v0.6.0", &"low")).is_equal("v0.6.0")


# --- high is today -------------------------------------------------------------------------------

func test_high_is_empty_and_changes_nothing() -> void:
	assert_dict(GraphicsScript.load_tiers().get("high", {"x": 1}) as Dictionary).is_empty()
	var g := _graphics("high")
	var vp := SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_4X
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.glow_enabled = true
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	vp.add_child(sun)
	var puff := CPUParticles2D.new()
	puff.amount = 20
	vp.add_child(puff)
	var dark := DarknessOverlay.new(null)
	vp.add_child(dark)
	add_child(vp)
	g.apply_tree(vp)
	assert_int(vp.msaa_3d).is_equal(Viewport.MSAA_4X)
	assert_float(vp.scaling_3d_scale).is_equal(1.0)
	assert_bool(env.environment.glow_enabled).is_true()
	assert_bool(sun.shadow_enabled).is_true()
	assert_int(puff.amount).is_equal(20)
	assert_int(dark.max_lights).is_equal(DarknessOverlay.MAX_LIGHTS)
	vp.free()


func test_the_running_game_is_on_todays_settings_headless() -> void:
	# The autoload on this headless run: high, and the root window as project.godot says.
	assert_str(String(Graphics.tier)).is_equal("high")
	var root := get_tree().root
	assert_int(root.msaa_3d).is_equal(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d")))
	assert_int(root.screen_space_aa).is_equal(Viewport.SCREEN_SPACE_AA_DISABLED)
	assert_float(root.scaling_3d_scale).is_equal(1.0)
	assert_int(Engine.max_fps).is_equal(int(ProjectSettings.get_setting("application/run/max_fps", 0)))


# --- low reaches viewports and environments ------------------------------------------------------

func test_low_reaches_viewports_environments_lights_and_particles_as_they_enter() -> void:
	var g := _graphics("low")
	var s: Dictionary = g.settings
	assert_dict(s).is_not_empty()
	var vp := SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_4X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	for key in ["ssao_enabled", "ssil_enabled", "ssr_enabled", "glow_enabled", "volumetric_fog_enabled", "sdfgi_enabled"]:
		env.environment.set(key, true)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.far = 4000.0
	vp.add_child(cam)
	var puff := CPUParticles2D.new()
	puff.amount = 20
	vp.add_child(puff)
	var dark := DarknessOverlay.new(null)
	vp.add_child(dark)
	add_child(vp)   # node_added does the rest
	assert_int(vp.msaa_3d).is_equal(Viewport.MSAA_DISABLED)
	assert_int(vp.msaa_2d).is_equal(Viewport.MSAA_DISABLED)
	assert_int(vp.screen_space_aa).is_equal(Viewport.SCREEN_SPACE_AA_DISABLED)
	assert_int(vp.scaling_3d_mode).is_equal(Viewport.SCALING_3D_MODE_FSR)
	assert_float(vp.scaling_3d_scale).is_equal(0.75)
	assert_float(vp.mesh_lod_threshold).is_greater_equal(4.0)
	for key in ["ssao_enabled", "ssil_enabled", "ssr_enabled", "glow_enabled", "volumetric_fog_enabled", "sdfgi_enabled"]:
		assert_bool(env.environment.get(key)).override_failure_message(key).is_false()
	assert_bool(sun.shadow_enabled).is_false()
	assert_float(cam.far).is_equal(float(s.camera_far))
	assert_int(puff.amount).is_equal(10)
	assert_int(dark.max_lights).is_equal(int(s.max_lights))
	# Moving a node re-enters the tree: it is not halved twice.
	vp.remove_child(puff)
	add_child(puff)
	assert_int(puff.amount).is_equal(10)
	puff.free()
	vp.free()


func test_low_on_the_window_caps_fps_and_its_environment() -> void:
	# Environment set after the node is added (the deferred pass catches it).
	var g := _graphics("low")
	var env := WorldEnvironment.new()
	add_child(env)
	env.environment = Environment.new()
	env.environment.glow_enabled = true
	await get_tree().process_frame
	assert_bool(env.environment.glow_enabled).is_false()
	env.free()
	assert_int(int(g.settings.max_fps)).is_equal(60)
	assert_bool(g.settings.vsync).is_true()


func test_low_caps_the_darkness_lights_to_the_nearest() -> void:
	var w := TileWorld.new()
	var dark := DarknessOverlay.new(w)
	var nodes: Array[Node2D] = []
	for i in 20:
		var n := Node2D.new()
		n.position = Vector2(i * 16, 0)
		add_child(n)
		nodes.append(n)
		dark.lights[n] = Vector2(64, 1)
	assert_int(dark.pick_lights().size()).is_equal(20)
	dark.max_lights = 12
	assert_int(dark.pick_lights().size()).is_equal(12)
	for n in nodes:
		n.free()
	dark.free()
	w.free()


# --- bench ---------------------------------------------------------------------------------------

func test_bench_stats() -> void:
	var ms := PackedFloat32Array()
	for i in 99:
		ms.append(10.0)
	ms.append(50.0)
	var s := Bench.stats(ms)
	assert_int(int(s.frames)).is_equal(100)
	assert_float(float(s.avg)).is_equal_approx(1000.0 * 100 / 1040.0, 0.01)
	assert_float(float(s.low1)).is_equal_approx(20.0, 0.01)   # the slowest 1 % = the one 50 ms frame
	assert_float(float(s.worst)).is_equal(50.0)
	assert_float(float(Bench.stats(PackedFloat32Array()).avg)).is_equal(0.0)
	assert_int(GraphicsScript.bench_secs_from_args(PackedStringArray(["--bench-secs=5"])) as int).is_equal(5)
	assert_float(GraphicsScript.bench_secs_from_args(PackedStringArray([]))).is_equal(60.0)


func test_bench_quits_by_itself_and_prints_the_summary() -> void:
	var out := []
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--fixed-fps", "60", "--", "--bench", "--bench-secs=6", "--graphics=low"])
	var code := OS.execute(OS.get_executable_path(), args, out, true)
	var log := "\n".join(out)
	assert_int(code).override_failure_message("bench exit %d:\n%s" % [code, log.right(2000)]).is_equal(0)
	var re := RegEx.create_from_string("(?m)^BENCH avg=[\\d.]+ low1=[\\d.]+ ms=[\\d.]+ worst=[\\d.]+ frames=\\d+ secs=[\\d.]+ tier=low ")
	assert_object(re.search(log)).override_failure_message("no summary line:\n%s" % log.right(2000)).is_not_null()
	assert_str(log).contains("BENCH t=")
	# S-21: the hitch count line, and nothing over 33 ms logged without its cause.
	assert_object(RegEx.create_from_string("(?m)^HITCH count>33ms=\\d+ worst=[\\d.]+ frames=\\d+ worst_at t=[\\d.]+ leg=\\d").search(log)) \
			.override_failure_message("no HITCH line:\n%s" % log.right(2000)).is_not_null()
	# hill-igpu-2: the work line (draw calls, darkness chunks and the lights their shader loops over).
	assert_object(RegEx.create_from_string("(?m)^WORK draws=\\d+ dark_chunks=[\\d.]+ dark_lights=[\\d.]+ per_chunk=[\\d.]+ taps=1 ").search(log)) \
			.override_failure_message("no WORK line:\n%s" % log.right(2000)).is_not_null()
	assert_str(log).contains("graphics: tier=low (flag --graphics=low)")
	assert_str(log).not_contains("SCRIPT ERROR")
