## A disk planet: every cell whose centre is within `radius` tiles of the origin. Chunks are polar:
## key = (ring, sector), a ring band `band` tiles thick cut into sectors about `band` tiles of arc
## long (so outer rings have more sectors). Gravity points at the origin. Life of a Worm's world.
class_name DiskShape
extends WorldShape

var radius: int
var band: int
var _cells_cache: Dictionary[Vector2i, Array] = {}


func _init(p_radius: int = 200, p_band: int = 32) -> void:
	radius = p_radius
	band = p_band


func rings() -> int:
	return ceili(radius / float(band))


func sectors_in(ring: int) -> int:
	return maxi(4, ceili(TAU * (ring + 0.5)))


func _mid(cell: Vector2i) -> Vector2:
	return Vector2(cell) + Vector2(0.5, 0.5)


func contains(cell: Vector2i) -> bool:
	return _mid(cell).length_squared() < float(radius * radius)


func chunk_of(cell: Vector2i) -> Vector2i:
	var m := _mid(cell)
	var ring := mini(int(m.length() / band), rings() - 1)
	var n := sectors_in(ring)
	return Vector2i(ring, mini(int(fposmod(m.angle(), TAU) / TAU * n), n - 1))


## Computed once per key, then copied from a cache (shapes are not changed after use).
func chunk_cells(key: Vector2i) -> Array[Vector2i]:
	var cached = _cells_cache.get(key)
	if cached == null:
		cached = _compute_chunk_cells(key)
		_cells_cache[key] = cached
	var out: Array[Vector2i] = []
	out.assign(cached)
	return out


func _compute_chunk_cells(key: Vector2i) -> Array[Vector2i]:
	# Bounding box of the ring sector: its four corners plus where the arcs cross an axis.
	var n := sectors_in(key.x)
	var a0 := TAU * key.y / n
	var a1 := TAU * (key.y + 1) / n
	var r0 := float(key.x * band)
	var r1 := minf(float((key.x + 1) * band), float(radius))
	var box := Rect2(Vector2.from_angle(a0) * r0, Vector2.ZERO)
	for p in [Vector2.from_angle(a0) * r1, Vector2.from_angle(a1) * r0, Vector2.from_angle(a1) * r1]:
		box = box.expand(p)
	for q in 5:
		var axis := q * TAU / 4.0
		if axis >= a0 and axis <= a1:
			box = box.expand(Vector2.from_angle(axis) * r1)
	# contains() and chunk_of() inlined, with the same arithmetic, so the two always agree.
	var rr := float(radius * radius)
	var last := rings() - 1
	var cells: Array[Vector2i] = []
	for y in range(floori(box.position.y) - 1, ceili(box.end.y) + 1):
		for x in range(floori(box.position.x) - 1, ceili(box.end.x) + 1):
			var m := Vector2(Vector2i(x, y)) + Vector2(0.5, 0.5)
			if m.length_squared() >= rr or mini(int(m.length() / band), last) != key.x:
				continue
			if mini(int(fposmod(m.angle(), TAU) / TAU * n), n - 1) == key.y:
				cells.append(Vector2i(x, y))
	return cells


func neighbourhood(key: Vector2i, radius_chunks: int = 1) -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	var turn := (key.y + 0.5) / sectors_in(key.x)
	for ring in range(maxi(key.x - radius_chunks, 0), mini(key.x + radius_chunks, rings() - 1) + 1):
		var n := sectors_in(ring)
		# The sectors of this ring that touch the span of `key`, plus radius_chunks each way.
		var lo := floori((turn - 0.5 / sectors_in(key.x)) * n) - radius_chunks
		var hi := ceili((turn + 0.5 / sectors_in(key.x)) * n) - 1 + radius_chunks
		if key.x == ring:
			lo = key.y - radius_chunks
			hi = key.y + radius_chunks
		for s in range(lo, hi + 1):
			var k := Vector2i(ring, posmod(s, n))
			if not keys.has(k):
				keys.append(k)
	return keys


func gravity_at(pos: Vector2) -> Vector2:
	if pos.length_squared() < 1.0:
		return Vector2.ZERO
	return -pos.normalized() * gravity


func _toward_core(cell: Vector2i) -> Vector2i:
	var m := _mid(cell)
	if absf(m.x) > absf(m.y):
		return Vector2i(-signi(int(signf(m.x))), 0)
	return Vector2i(0, -signi(int(signf(m.y))))


func below(cell: Vector2i) -> Vector2i:
	if _mid(cell).length_squared() <= 1.0:
		return cell
	return cell + _toward_core(cell)


func sides(cell: Vector2i) -> Array[Vector2i]:
	var d := _toward_core(cell)
	return [cell + Vector2i(d.y, -d.x), cell + Vector2i(-d.y, d.x)]


func depth_of(cell: Vector2i) -> int:
	return maxi(0, int(radius - _mid(cell).length()))
