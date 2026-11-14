## Graphics tiers (S-20). Autoload: Graphics. Tiers live in data/graphics.json.
##   high  today's look (the GTX 1060). Its entry is empty: high applies nothing at all.
##   low   the TV box's Intel HD 530: no MSAA/AA, 3D at 0.75 with FSR 1, no shadows/SSAO/SSIL/SSR/
##         glow/volumetrics/SDFGI, LOD bias up, shorter 3D far plane, half the particles, at most
##         `max_lights` lights in the darkness shader, 60 fps cap, vsync on.
## Boot picks from the GPU (pick_tier): Intel integrated, software renderers and anything unknown get
## low; NVIDIA or AMD discrete get high. `--graphics=low|high` (either side of `--`) overrides.
## Headless runs have no renderer and stay on high (nothing applied, the test suite sees today).
## Low reaches every viewport, environment, light, camera, particle node and darkness overlay as it
## enters the tree (node_added), so no other lane has to know about tiers.
## `--bench [--bench-secs=N]`: the fixed two-player route (scripts/gameplay/bench_runner.gd).
extends Node

const DATA := "res://data/graphics.json"
const LOW := &"low"
const HIGH := &"high"
## Set on a node once low has scaled it (particles), so a node that re-enters the tree is not halved twice.
const META := &"graphics_low"
const DarknessOverlay := preload("res://addons/openjar/tileworld/darkness_overlay.gd")

var tier: StringName = HIGH
var reason := ""
var adapter := ""
var vendor := ""
var settings: Dictionary = {}
var bench := false
var bench_secs := 60.0
var _tiers: Dictionary = {}


## Tier from the GPU strings and the flag ("" / "low" / "high"). {"tier": StringName, "reason": String}.
static func pick_tier(adapter_name: String, vendor_name: String, flag: String = "", headless: bool = false) -> Dictionary:
	if flag == "low" or flag == "high":
		return {"tier": StringName(flag), "reason": "flag --graphics=%s" % flag}
	if headless and adapter_name == "":
		return {"tier": HIGH, "reason": "headless (no renderer, nothing to apply)"}
	var s := (adapter_name + " " + vendor_name).to_lower()
	if s.contains("llvmpipe") or s.contains("lavapipe") or s.contains("softpipe") or s.contains("swiftshader"):
		return {"tier": LOW, "reason": "software renderer"}
	if s.contains("nvidia") or s.contains("geforce") or s.contains("quadro"):
		if s.contains("tegra"):
			return {"tier": LOW, "reason": "NVIDIA Tegra (integrated)"}
		return {"tier": HIGH, "reason": "NVIDIA discrete"}
	if s.contains("amd") or s.contains("radeon") or s.contains("ati technologies"):
		if _amd_integrated(s):
			return {"tier": LOW, "reason": "AMD integrated"}
		return {"tier": HIGH, "reason": "AMD discrete"}
	if s.contains("intel"):
		return {"tier": LOW, "reason": "Intel graphics"}
	return {"tier": LOW, "reason": "unknown GPU"}


## AMD APUs report "Radeon Graphics", "Radeon(TM) Graphics", "Radeon Vega 8 Graphics" or a RADV chip
## code name; discrete cards carry a model number (RX 580, R9 390, Pro W5700...).
static func _amd_integrated(s: String) -> bool:
	for chip in ["renoir", "cezanne", "rembrandt", "phoenix", "vangogh", "raven", "picasso", "barcelo",
			"lucienne", "mendocino", "dali", "pollock", "stoney", "carrizo", "kaveri", "gfx1103", "gfx1150"]:
		if s.contains(chip):
			return true
	var re := RegEx.create_from_string("radeon(\\(tm\\))?( vega \\d+)? graphics")
	return re.search(s) != null


## "--graphics=low" -> "low" (either side of "--"); "" when absent or not a tier.
static func flag_from_args(args: PackedStringArray) -> String:
	for a in args:
		if a.begins_with("--graphics="):
			var v := a.trim_prefix("--graphics=").to_lower()
			return v if v == "low" or v == "high" else ""
	return ""


static func bench_secs_from_args(args: PackedStringArray, fallback: float = 60.0) -> float:
	for a in args:
		if a.begins_with("--bench-secs="):
			var v := float(a.trim_prefix("--bench-secs="))
			return v if v > 0.0 else fallback
	return fallback


## The lobby footer: dev builds show the tier next to the version ("dev · low"); releases don't.
static func version_label(version: String, tier_name: StringName) -> String:
	return "%s · %s" % [version, tier_name] if version.contains("dev") else version


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tiers = load_tiers()
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	bench = args.has("--bench")
	bench_secs = bench_secs_from_args(args)
	var headless := DisplayServer.get_name() == "headless"
	adapter = RenderingServer.get_video_adapter_name()
	vendor = RenderingServer.get_video_adapter_vendor()
	var pick := pick_tier(adapter, vendor, flag_from_args(args), headless)
	reason = pick.reason
	print("graphics: tier=%s (%s) adapter=\"%s\" vendor=\"%s\"" % [pick.tier, reason, adapter, vendor])
	get_tree().node_added.connect(_on_node_added)
	set_tier(pick.tier)


static func load_tiers() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA)) if FileAccess.file_exists(DATA) else null
	if parsed is Dictionary and (parsed as Dictionary).get("tiers") is Dictionary:
		return parsed.tiers
	push_warning("graphics: %s missing or broken, every tier is high" % DATA)
	return {}


func is_low() -> bool:
	return tier == LOW


## Switch tier and apply it to the root window and everything already in the tree. Low is applied
## on top of what is there; going back to high at runtime needs a restart (logged).
func set_tier(t: StringName) -> void:
	if t == HIGH and tier == LOW:
		push_warning("graphics: back to high needs a restart")
	tier = t
	settings = (_tiers.get(String(t), {}) as Dictionary).duplicate(true)
	if settings.is_empty():
		return
	if settings.has("max_fps"):
		Engine.max_fps = int(settings.max_fps)
	if settings.get("vsync", false) and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	apply_tree(get_tree().root)


func apply_tree(root: Node) -> void:
	apply_node(root)
	for n in root.find_children("*", "", true, false):
		apply_node(n)


func _on_node_added(n: Node) -> void:
	if settings.is_empty():
		return
	apply_node(n)
	if n is WorldEnvironment:
		# Scenes often set the Environment after adding the node.
		(func() -> void:
			if is_instance_valid(n):
				apply_node(n)).call_deferred()


## Low's settings on one node (no-op on high, whose settings are empty).
func apply_node(n: Node) -> void:
	if settings.is_empty() or n == null:
		return
	if n is Viewport:
		_apply_viewport(n as Viewport)
	elif n is WorldEnvironment:
		_apply_environment((n as WorldEnvironment).environment)
	elif n is Light3D:
		if settings.has("shadows") and not settings.shadows:
			(n as Light3D).shadow_enabled = false
	elif n is Camera3D:
		if settings.has("camera_far"):
			var cam := n as Camera3D
			cam.far = minf(cam.far, float(settings.camera_far))
			_apply_environment(cam.environment)
	elif n is CPUParticles2D or n is GPUParticles2D or n is CPUParticles3D or n is GPUParticles3D:
		_apply_particles(n)
	elif n is DarknessOverlay:
		if settings.has("max_lights"):
			(n as DarknessOverlay).max_lights = clampi(int(settings.max_lights), 1, DarknessOverlay.MAX_LIGHTS)


func _apply_viewport(v: Viewport) -> void:
	if settings.has("msaa_2d"):
		v.msaa_2d = settings.msaa_2d as Viewport.MSAA
	if settings.has("msaa_3d"):
		v.msaa_3d = settings.msaa_3d as Viewport.MSAA
	if settings.has("screen_space_aa"):
		v.screen_space_aa = settings.screen_space_aa as Viewport.ScreenSpaceAA
	if settings.has("use_taa"):
		v.use_taa = bool(settings.use_taa)
	if settings.get("scaling_3d_mode", "") == "fsr":
		v.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	if settings.has("scaling_3d_scale"):
		v.scaling_3d_scale = float(settings.scaling_3d_scale)
	if settings.has("mesh_lod_threshold"):
		v.mesh_lod_threshold = maxf(v.mesh_lod_threshold, float(settings.mesh_lod_threshold))
	if settings.has("shadows") and not settings.shadows:
		v.positional_shadow_atlas_size = 0


func _apply_environment(env: Environment) -> void:
	if env == null:
		return
	if settings.has("ssao") and not settings.ssao:
		env.ssao_enabled = false
	if settings.has("ssil") and not settings.ssil:
		env.ssil_enabled = false
	if settings.has("ssr") and not settings.ssr:
		env.ssr_enabled = false
	if settings.has("glow") and not settings.glow:
		env.glow_enabled = false
	if settings.has("volumetric_fog") and not settings.volumetric_fog:
		env.volumetric_fog_enabled = false
	if settings.has("sdfgi") and not settings.sdfgi:
		env.sdfgi_enabled = false


func _apply_particles(n: Node) -> void:
	if not settings.has("particle_scale") or n.has_meta(META):
		return
	n.set_meta(META, true)
	var amount := int(n.get("amount"))
	n.set("amount", maxi(1, roundi(amount * float(settings.particle_scale))))
