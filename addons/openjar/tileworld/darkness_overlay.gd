## Depth darkness and the light pass for a TileWorld, shape-agnostic (docs/contracts.md "Tile art and
## the light pass"). One Sprite2D per loaded chunk (skipped when the whole chunk is lit): a tiny
## image, one texel per cell of the chunk's cell bounding box, scaled by cell_size so it lines up
## with the tiles. Texel: R = band darkness, G = band index (tint from a uniform table), B = occlusion
## (0 air, 128 solid with an open side, 255 solid all round), A = 255 inside this chunk, 0 outside
## (a neighbouring chunk draws there). The shader works the light out per cell (each light's
## distance falloff, shortened in solid ground) and blends the four nearest cells of this chunk
## bilinearly, so light is soft from cell to cell and leaks into rock less than along a tunnel.
## Darkness never reaches black: d renders as alpha d * darkness_floor of the band tint mixed toward
## darkness_night. Every sprite has its own copy of one ShaderMaterial holding only the lights that
## reach it (cull_lights); lights are in world space, so two SubViewports looking at the same world
## both see them. `one_tap` (a low graphics tier) works the light out once per pixel instead.
## A dig rewrites only the touched texels.
extends Node2D

const MAX_LIGHTS := 32
const MAX_BANDS := 16
## How far light reaches, as a share of its radius, by occlusion (air, open solid, closed solid).
const REACH := [1.0, 0.72, 0.4]
const SHADER_CODE := """
shader_type canvas_item;

uniform vec4 lights[32];          // xy world position, z radius px, w strength
uniform int light_count = 0;
uniform vec3 tints[16];
uniform vec3 night : source_color = vec3(0.06, 0.07, 0.16);
uniform float floor_alpha = 0.8;
uniform float cell_size = 16.0;
uniform vec3 reach = vec3(1.0, 0.72, 0.4);
varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Light reaching the centre of cell `t` (texel), 0..1.
float light_at(vec2 centre, float occ) {
	float r_k = occ < 0.25 ? reach.x : (occ < 0.75 ? reach.y : reach.z);
	float l = 0.0;
	for (int k = 0; k < 32; k++) {
		if (k >= light_count) {
			break;
		}
		vec4 L = lights[k];
		float r = L.z * r_k;
		float d = distance(centre, L.xy);
		l = max(l, L.w * (1.0 - smoothstep(r * 0.3, r, d)));
	}
	return clamp(l, 0.0, 1.0);
}

#ifndef ONE_TAP
void fragment() {
	ivec2 sz = textureSize(TEXTURE, 0);
	vec2 p = UV * vec2(sz);
	ivec2 own = clamp(ivec2(floor(p)), ivec2(0), sz - 1);
	if (texelFetch(TEXTURE, own, 0).a < 0.5) {
		discard;
	}
	vec2 q = p - 0.5;
	ivec2 i0 = ivec2(floor(q));
	vec2 f = fract(q);
	vec4 acc = vec4(0.0);
	float wsum = 0.0;
	for (int j = 0; j < 2; j++) {
		for (int i = 0; i < 2; i++) {
			ivec2 ti = clamp(i0 + ivec2(i, j), ivec2(0), sz - 1);
			vec4 t = texelFetch(TEXTURE, ti, 0);
			float w = (i == 0 ? 1.0 - f.x : f.x) * (j == 0 ? 1.0 - f.y : f.y);
			w *= step(0.5, t.a);
			if (w <= 0.0) {
				continue;
			}
			vec2 centre = world_pos + (vec2(ti) + 0.5 - p) * cell_size;
			float a = t.r * floor_alpha * (1.0 - light_at(centre, t.b));
			vec3 col = mix(tints[int(t.g * 255.0 + 0.5)], night, 0.5);
			acc += vec4(col * a, a) * w;
			wsum += w;
		}
	}
	acc /= max(wsum, 0.0001);
	COLOR = vec4(acc.rgb / max(acc.a, 0.0001), acc.a);
}
#else
// One light evaluation per pixel (a low graphics tier): the four nearest cells' darkness, tint and
// reach blend first, then the light is worked out once at the pixel itself.
void fragment() {
	ivec2 sz = textureSize(TEXTURE, 0);
	vec2 p = UV * vec2(sz);
	ivec2 own = clamp(ivec2(floor(p)), ivec2(0), sz - 1);
	if (texelFetch(TEXTURE, own, 0).a < 0.5) {
		discard;
	}
	vec2 q = p - 0.5;
	ivec2 i0 = ivec2(floor(q));
	vec2 f = fract(q);
	vec4 acc = vec4(0.0);
	float r_k = 0.0;
	float wsum = 0.0;
	for (int j = 0; j < 2; j++) {
		for (int i = 0; i < 2; i++) {
			ivec2 ti = clamp(i0 + ivec2(i, j), ivec2(0), sz - 1);
			vec4 t = texelFetch(TEXTURE, ti, 0);
			float w = (i == 0 ? 1.0 - f.x : f.x) * (j == 0 ? 1.0 - f.y : f.y);
			w *= step(0.5, t.a);
			float a = t.r * floor_alpha;
			vec3 col = mix(tints[int(t.g * 255.0 + 0.5)], night, 0.5);
			acc += vec4(col * a, a) * w;
			r_k += (t.b < 0.25 ? reach.x : (t.b < 0.75 ? reach.y : reach.z)) * w;
			wsum += w;
		}
	}
	acc /= max(wsum, 0.0001);
	r_k /= max(wsum, 0.0001);
	float l = 0.0;
	for (int k = 0; k < 32; k++) {
		if (k >= light_count) {
			break;
		}
		vec4 L = lights[k];
		float r = L.z * r_k;
		l = max(l, L.w * (1.0 - smoothstep(r * 0.3, r, distance(world_pos, L.xy))));
	}
	float lit = 1.0 - clamp(l, 0.0, 1.0);
	COLOR = vec4(acc.rgb / max(acc.a, 0.0001), acc.a * lit);
}
#endif
"""

var world: TileWorld
var bands: Array = []
## node -> Vector2(radius_px, strength)
var lights: Dictionary[Node2D, Vector2] = {}
var material_shared: ShaderMaterial
## At most this many lights reach the shader (the nearest to tracked nodes). A game's low graphics
## tier lowers it (every light is a loop step per pixel); never above MAX_LIGHTS.
var max_lights := MAX_LIGHTS
## Each chunk's sprite gets only the lights that can reach its rectangle (the rest add exactly
## nothing there), so a pixel loops over a few lights, not every picked one. Same picture either way.
var cull_lights := true
## One light evaluation per pixel instead of one per each of the four nearest cells (a game's low
## graphics tier): the light falls off smoothly per pixel instead of blending from cell to cell.
var one_tap := false:
	set(v):
		if v == one_tap:
			return
		one_tap = v
		if material_shared:
			material_shared.shader = _shader_for(v)
			for m: ShaderMaterial in _mats.values():
				m.shader = material_shared.shader
## darkness 1 renders as this alpha (never pure black).
var darkness_floor := 0.8:
	set(v):
		darkness_floor = v
		_set_param("floor_alpha", v)
## The dim navy the band tint is mixed toward in the dark.
var darkness_night := Color(0.06, 0.07, 0.16):
	set(v):
		darkness_night = v
		_set_param("night", v)
## Last update_lights: chunk sprites, and the lights summed over them (what the shader loops over).
var stat_sprites := 0
var stat_light_sum := 0
var _sprites: Dictionary[Vector2i, Sprite2D] = {}
## Per chunk sprite its own copy of material_shared (its own light list when cull_lights).
var _mats: Dictionary[Vector2i, ShaderMaterial] = {}
## Per chunk the light list last handed to its material, so a chunk whose lights did not move
## costs no upload.
var _uploaded: Dictionary[Vector2i, PackedVector4Array] = {}
## Per chunk with a sprite: {"img": Image, "lo": Vector2i (top-left cell)}.
var _images: Dictionary[Vector2i, Dictionary] = {}
var _dirty: Dictionary[Vector2i, bool] = {}


func _init(p_world: TileWorld) -> void:
	world = p_world
	name = "Darkness"
	z_index = 10
	material_shared = ShaderMaterial.new()
	material_shared.shader = _shader_for(one_tap)
	material_shared.set_shader_parameter("floor_alpha", darkness_floor)
	material_shared.set_shader_parameter("night", darkness_night)
	material_shared.set_shader_parameter("reach", Vector3(REACH[0], REACH[1], REACH[2]))


static var _shaders: Dictionary[bool, Shader] = {}


## The darkness shader, compiled once per variant for the whole run.
static func _shader_for(p_one_tap: bool) -> Shader:
	var sh: Shader = _shaders.get(p_one_tap)
	if sh == null:
		sh = Shader.new()
		sh.code = ("#define ONE_TAP\n" if p_one_tap else "") + SHADER_CODE
		_shaders[p_one_tap] = sh
	return sh


## A shader parameter on material_shared and every chunk's copy.
func _set_param(param: StringName, v: Variant) -> void:
	if material_shared == null:
		return
	material_shared.set_shader_parameter(param, v)
	for m: ShaderMaterial in _mats.values():
		m.set_shader_parameter(param, v)


func is_active() -> bool:
	return not bands.is_empty()


func darkness_at(depth: int) -> float:
	var b := _band_at(depth)
	return float(b.get("darkness", 0.0)) if not b.is_empty() else 0.0


func _band_index(depth: int) -> int:
	for i in bands.size():
		var b: Dictionary = bands[i]
		if depth >= int(b.get("from", 0)) and depth < int(b.get("to", 1 << 30)):
			return i
	return -1


func _band_at(depth: int) -> Dictionary:
	var i := _band_index(depth)
	return bands[i] if i >= 0 else {}


func set_bands(p_bands: Array) -> void:
	bands = p_bands.duplicate(true)
	if bands.size() > MAX_BANDS:
		push_warning("TileWorld.set_darkness: only %d bands are tinted" % MAX_BANDS)
	var tints := PackedVector3Array()
	tints.resize(MAX_BANDS)
	for i in mini(bands.size(), MAX_BANDS):
		var t: Color = bands[i].get("tint", Color.BLACK)
		tints[i] = Vector3(t.r, t.g, t.b)
	_set_param("tints", tints)
	_set_param("cell_size", float(world.shape.cell_size) if world.shape else 16.0)
	for key in _sprites.keys():
		remove_chunk(key)
	if bands.is_empty():
		return
	for key in world._chunk_cells:
		var cells: Array = world._chunk_cells[key]
		add_chunk(key, cells, world._grid_now(cells) if not cells.is_empty() else {})


## grid: TileWorld's solid grid for the chunk ({lo, gw, gh, sol}, a one-cell ring included).
func add_chunk(key: Vector2i, cells: Array, grid: Dictionary = {}) -> void:
	remove_chunk(key)
	if bands.is_empty() or cells.is_empty():
		return
	if grid.is_empty():
		grid = world._grid_now(cells)
	var shape := world.shape
	var glo: Vector2i = grid.lo
	var gw: int = grid.gw
	var sol: PackedByteArray = grid.sol
	var lo := glo + Vector2i.ONE
	var w: int = gw - 2
	var h: int = int(grid.gh) - 2
	# One little-endian RGBA int per texel; 0 (alpha 0) marks cells outside this chunk.
	var data := PackedInt32Array()
	data.resize(w * h)
	data.fill(0)
	var any := false
	var cache: Dictionary[int, int] = {}
	for c: Vector2i in cells:
		var depth := shape.depth_of(c)
		var px = cache.get(depth)
		if px == null:
			px = _band_px(depth)
			any = any or (px & 0xff) > 0
			cache[depth] = px
		var g := (c.y - glo.y) * gw + c.x - glo.x
		var occ := 0
		if sol[g] == 1:
			occ = 255 if sol[g - gw] == 1 and sol[g + 1] == 1 and sol[g + gw] == 1 and sol[g - 1] == 1 else 128
		data[(c.y - lo.y) * w + (c.x - lo.x)] = px | (occ << 16)
	if not any:
		return
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data.to_byte_array())
	var s := Sprite2D.new()
	s.centered = false
	s.texture = ImageTexture.create_from_image(img)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = Vector2(lo) * shape.cell_size
	s.scale = Vector2.ONE * shape.cell_size
	var mat := material_shared.duplicate() as ShaderMaterial
	s.material = mat
	add_child(s)
	_sprites[key] = s
	_mats[key] = mat
	_images[key] = {"img": img, "lo": lo}


## R darkness, G band index, A in-chunk (B, the occlusion, is added per cell).
func _band_px(depth: int) -> int:
	var bi := _band_index(depth)
	var d := clampf(float(bands[bi].get("darkness", 0.0)), 0.0, 1.0) if bi >= 0 else 0.0
	return roundi(d * 255.0) | (clampi(bi, 0, MAX_BANDS - 1) << 8) | (255 << 24)


func remove_chunk(key: Vector2i) -> void:
	var s: Sprite2D = _sprites.get(key)
	if s:
		_sprites.erase(key)
		_mats.erase(key)
		_uploaded.erase(key)
		_images.erase(key)
		_dirty.erase(key)
		s.queue_free()


## A cell turned solid or open: rewrite its texel and its four neighbours' (their occlusion).
func on_solid_changed(cell: Vector2i) -> void:
	if _sprites.is_empty():
		return
	_rewrite(cell)
	for o in TileWorld._NEIGHBOURS:
		_rewrite(cell + o)


func _rewrite(c: Vector2i) -> void:
	var shape := world.shape
	if not shape.contains(c):
		return
	var key := shape.chunk_of(c)
	var e: Dictionary = _images.get(key, {})
	if e.is_empty():
		return
	var img: Image = e.img
	var p: Vector2i = c - (e.lo as Vector2i)
	var occ := 0
	if world.is_solid(c):
		occ = 128
		if world.is_solid(c + Vector2i.UP) and world.is_solid(c + Vector2i.RIGHT) \
				and world.is_solid(c + Vector2i.DOWN) and world.is_solid(c + Vector2i.LEFT):
			occ = 255
	var col := img.get_pixelv(p)
	col.b8 = occ
	img.set_pixelv(p, col)
	_dirty[key] = true


func sprite_keys() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(_sprites.keys())
	return out


## The texel of a cell as Color (tests and tools), or transparent when it has none.
func texel(c: Vector2i) -> Color:
	var e: Dictionary = _images.get(world.shape.chunk_of(c), {})
	if e.is_empty():
		return Color(0, 0, 0, 0)
	return (e.img as Image).get_pixelv(c - (e.lo as Vector2i))


## Lights in shader order this frame: the max_lights nearest to a tracked node.
func pick_lights() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for node in lights.keys():
		if not is_instance_valid(node):
			lights.erase(node)
		elif node.is_inside_tree():
			out.append(node)
	var cap := clampi(max_lights, 0, MAX_LIGHTS)
	if out.size() > cap:
		var anchors: Array[Vector2] = []
		for t in world._tracked:
			if is_instance_valid(t) and t.is_inside_tree():
				anchors.append(t.global_position)
		var dist := {}
		for n in out:
			var best := INF
			for a in anchors:
				best = minf(best, a.distance_squared_to(n.global_position))
			dist[n] = best
		out.sort_custom(func(a: Node2D, b: Node2D) -> bool: return dist[a] < dist[b])
		out.resize(cap)
	return out


func update_lights() -> void:
	for key in _dirty:
		var s: Sprite2D = _sprites.get(key)
		if s:
			(s.texture as ImageTexture).update(_images[key].img)
	_dirty.clear()
	stat_sprites = _sprites.size()
	stat_light_sum = 0
	if _sprites.is_empty():
		return
	var arr := PackedVector4Array()
	arr.resize(MAX_LIGHTS)
	var picked := pick_lights()
	for i in picked.size():
		var node := picked[i]
		var p: Vector2 = node.global_position
		var l: Vector2 = lights[node]
		arr[i] = Vector4(p.x, p.y, l.x, l.y)
	material_shared.set_shader_parameter("lights", arr)
	material_shared.set_shader_parameter("light_count", picked.size())
	var reach_max: float = REACH.max()
	for key in _mats:
		var mat: ShaderMaterial = _mats[key]
		if not cull_lights:
			_upload(key, mat, arr, picked.size())
			stat_light_sum += picked.size()
			continue
		var spr := _sprites[key]
		var img: Image = _images[key].img
		var rect := Rect2(spr.global_position, Vector2(img.get_size()) * spr.global_scale).abs()
		var own := PackedVector4Array()
		own.resize(MAX_LIGHTS)
		var n := 0
		for i in picked.size():
			var v := arr[i]
			var at := Vector2(v.x, v.y)
			var r := v.z * reach_max
			if at.clamp(rect.position, rect.end).distance_squared_to(at) <= r * r:
				own[n] = v
				n += 1
		_upload(key, mat, own, n)
		stat_light_sum += n


## Hands a chunk's light list to its material unless it is the one it already has.
func _upload(key: Vector2i, mat: ShaderMaterial, list: PackedVector4Array, n: int) -> void:
	# Slots past n are zero, so the list alone says the count too.
	if _uploaded.get(key) == list:
		return
	_uploaded[key] = list
	mat.set_shader_parameter("lights", list)
	mat.set_shader_parameter("light_count", n)


## Lights the shader loops over in one chunk's sprite (tests and the bench).
func chunk_light_count(key: Vector2i) -> int:
	var m: ShaderMaterial = _mats.get(key)
	return int(m.get_shader_parameter("light_count")) if m else 0
