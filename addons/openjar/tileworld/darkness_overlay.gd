## Depth darkness for a TileWorld, shape-agnostic. One Sprite2D per loaded chunk (skipped when the
## whole chunk is lit): a tiny image, one pixel per cell of the chunk's cell bounding box, scaled by
## cell_size so it lines up with the tiles. Pixel = band tint, alpha = darkness_at(depth_of(cell)),
## stored as 1/255 + d * 254/255 so the shader can tell "in this chunk" (alpha > 0) from "outside"
## (0, where a neighbouring chunk draws) and blend smoothly without seams where bounding boxes
## overlap. All sprites share one ShaderMaterial: up to 8 lights cut smooth holes, in world space,
## so two SubViewports looking at the same world both see them.
extends Node2D

const MAX_LIGHTS := 8
const SHADER_CODE := """
shader_type canvas_item;

uniform vec3 lights[8];
uniform int light_count = 0;
varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	ivec2 sz = textureSize(TEXTURE, 0);
	vec2 p = UV * vec2(sz);
	ivec2 own = clamp(ivec2(floor(p)), ivec2(0), sz - 1);
	if (texelFetch(TEXTURE, own, 0).a < 0.5 / 255.0) {
		discard;
	}
	// Bilinear over the texels of this chunk only.
	vec2 q = p - 0.5;
	ivec2 i0 = ivec2(floor(q));
	vec2 f = fract(q);
	vec4 acc = vec4(0.0);
	float wsum = 0.0;
	for (int j = 0; j < 2; j++) {
		for (int i = 0; i < 2; i++) {
			vec4 t = texelFetch(TEXTURE, clamp(i0 + ivec2(i, j), ivec2(0), sz - 1), 0);
			float w = (i == 0 ? 1.0 - f.x : f.x) * (j == 0 ? 1.0 - f.y : f.y);
			w *= step(0.5 / 255.0, t.a);
			acc += t * w;
			wsum += w;
		}
	}
	vec4 c = acc / max(wsum, 0.0001);
	float a = clamp((c.a * 255.0 - 1.0) / 254.0, 0.0, 1.0);
	for (int k = 0; k < 8; k++) {
		if (k >= light_count) {
			break;
		}
		float d = distance(world_pos, lights[k].xy);
		a *= smoothstep(lights[k].z * 0.5, lights[k].z, d);
	}
	COLOR = vec4(c.rgb, a);
}
"""

var world: TileWorld
var bands: Array = []
var lights: Dictionary[Node2D, float] = {}
var material_shared: ShaderMaterial
var _sprites: Dictionary[Vector2i, Sprite2D] = {}


func _init(p_world: TileWorld) -> void:
	world = p_world
	name = "Darkness"
	z_index = 10
	var shader := Shader.new()
	shader.code = SHADER_CODE
	material_shared = ShaderMaterial.new()
	material_shared.shader = shader


func darkness_at(depth: int) -> float:
	var b := _band_at(depth)
	return float(b.get("darkness", 0.0)) if not b.is_empty() else 0.0


func _band_at(depth: int) -> Dictionary:
	for b in bands:
		if depth >= int(b.get("from", 0)) and depth < int(b.get("to", 1 << 30)):
			return b
	return {}


func set_bands(p_bands: Array) -> void:
	bands = p_bands.duplicate(true)
	for key in _sprites.keys():
		remove_chunk(key)
	for key in world._chunk_cells:
		add_chunk(key, world._chunk_cells[key])


func add_chunk(key: Vector2i, cells: Array) -> void:
	remove_chunk(key)
	if bands.is_empty() or cells.is_empty():
		return
	var shape := world.shape
	var lo: Vector2i = cells[0]
	var hi: Vector2i = cells[0]
	for c: Vector2i in cells:
		lo = lo.min(c)
		hi = hi.max(c)
	var w := hi.x - lo.x + 1
	var h := hi.y - lo.y + 1
	var data := PackedByteArray()
	data.resize(w * h * 4)
	var any := false
	var cache := {}
	for c: Vector2i in cells:
		var depth := shape.depth_of(c)
		var px: PackedByteArray = cache.get(depth, PackedByteArray())
		if px.is_empty():
			var b := _band_at(depth)
			var d := clampf(float(b.get("darkness", 0.0)), 0.0, 1.0) if not b.is_empty() else 0.0
			var tint: Color = b.get("tint", Color.BLACK) if not b.is_empty() else Color.BLACK
			px = PackedByteArray([tint.r8, tint.g8, tint.b8, 1 + roundi(d * 254.0)])
			cache[depth] = px
		if px[3] > 1:
			any = true
		var i := ((c.y - lo.y) * w + (c.x - lo.x)) * 4
		data[i] = px[0]
		data[i + 1] = px[1]
		data[i + 2] = px[2]
		data[i + 3] = px[3]
	if not any:
		return
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	var s := Sprite2D.new()
	s.centered = false
	s.texture = ImageTexture.create_from_image(img)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.position = Vector2(lo) * shape.cell_size
	s.scale = Vector2.ONE * shape.cell_size
	s.material = material_shared
	add_child(s)
	_sprites[key] = s


func remove_chunk(key: Vector2i) -> void:
	var s: Sprite2D = _sprites.get(key)
	if s:
		_sprites.erase(key)
		s.queue_free()


func sprite_keys() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(_sprites.keys())
	return out


func update_lights() -> void:
	if _sprites.is_empty():
		return
	var arr := PackedVector3Array()
	arr.resize(MAX_LIGHTS)
	var n := 0
	for node in lights.keys():
		if not is_instance_valid(node):
			lights.erase(node)
			continue
		if n < MAX_LIGHTS and node.is_inside_tree():
			var p: Vector2 = node.global_position
			arr[n] = Vector3(p.x, p.y, lights[node])
			n += 1
	material_shared.set_shader_parameter("lights", arr)
	material_shared.set_shader_parameter("light_count", n)
