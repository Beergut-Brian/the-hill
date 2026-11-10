## A generated TileArt for the demos and the stress run: per tile id 4 variants x 16 open masks
## (lighter edge on each open side), and 4 darker back-wall variants with a ceiling lip. Same per-cell
## work as a real art set, no image files. `stress.tscn -- --tile-art=<this script's path>`.
extends TileArt

var colors: Array[Color] = [Color(0.36, 0.66, 0.27), Color(0.55, 0.38, 0.22), Color(0.45, 0.45, 0.5), Color(0.2, 0.18, 0.22)]
var cs := 16
var collision_layer := 1
var _ts: TileSet


func tile_set() -> TileSet:
	if _ts:
		return _ts
	var n := colors.size()
	var img := Image.create_empty(cs * n * 4, cs * 16, false, Image.FORMAT_RGBA8)
	for id in n:
		for v in 4:
			for open in 16:
				var r := Rect2i((id * 4 + v) * cs, open * cs, cs, cs)
				var col := colors[id].darkened(0.04 * v)
				img.fill_rect(r, col)
				if open & OPEN_UP:
					img.fill_rect(Rect2i(r.position, Vector2i(cs, 2)), col.lightened(0.3))
				if open & OPEN_DOWN:
					img.fill_rect(Rect2i(r.position + Vector2i(0, cs - 2), Vector2i(cs, 2)), col.darkened(0.3))
				if open & OPEN_LEFT:
					img.fill_rect(Rect2i(r.position, Vector2i(2, cs)), col.lightened(0.15))
				if open & OPEN_RIGHT:
					img.fill_rect(Rect2i(r.position + Vector2i(cs - 2, 0), Vector2i(2, cs)), col.darkened(0.15))
	var wall := Image.create_empty(cs * 4, cs * 2, false, Image.FORMAT_RGBA8)
	for v in 4:
		wall.fill_rect(Rect2i(v * cs, 0, cs, cs * 2), Color(0.16, 0.12, 0.1).darkened(0.05 * v))
		wall.fill_rect(Rect2i(v * cs, cs, cs, 3), Color(0.08, 0.06, 0.05))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(cs, cs)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, collision_layer)
	var h := cs * 0.5
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(cs, cs)
	ts.add_source(src, SOLID_SOURCE)
	for y in 16:
		for x in n * 4:
			src.create_tile(Vector2i(x, y))
			var td := src.get_tile_data(Vector2i(x, y), 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, square)
	var ws := TileSetAtlasSource.new()
	ws.texture = ImageTexture.create_from_image(wall)
	ws.texture_region_size = Vector2i(cs, cs)
	ts.add_source(ws, WALL_SOURCE)
	for y in 2:
		for x in 4:
			ws.create_tile(Vector2i(x, y))
	_ts = ts
	return ts


func solid_coords(c: Vector2i, id: int, open: int) -> Vector2i:
	return Vector2i(clampi(id - 1, 0, colors.size() - 1) * 4 + cell_hash(c) % 4, open)


func wall_coords(c: Vector2i, base_id: int, ceiling: bool) -> Vector2i:
	if base_id <= 0:
		return NO_TILE
	return Vector2i(cell_hash(c) % 4, 1 if ceiling else 0)
