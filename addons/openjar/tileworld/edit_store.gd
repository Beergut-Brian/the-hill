## The differences between a TileWorld and its generator's base world: tile edits and water edits.
## Holds only differences (TileWorld clears an entry when a cell goes back to its base value).
## Save format (survives JSON): {"seed": int, "edits": [x, y, id, ...], "water": [x, y, on(0/1), ...]}.
class_name EditStore
extends RefCounted

var tiles: Dictionary[Vector2i, int] = {}
var water: Dictionary[Vector2i, bool] = {}


func clear() -> void:
	tiles.clear()
	water.clear()


func to_save(world_seed: int) -> Dictionary:
	var e := PackedInt32Array()
	e.resize(tiles.size() * 3)
	var i := 0
	for cell: Vector2i in tiles:
		e[i] = cell.x
		e[i + 1] = cell.y
		e[i + 2] = tiles[cell]
		i += 3
	var w := PackedInt32Array()
	w.resize(water.size() * 3)
	i = 0
	for cell: Vector2i in water:
		w[i] = cell.x
		w[i + 1] = cell.y
		w[i + 2] = 1 if water[cell] else 0
		i += 3
	# Plain Arrays so JSON.stringify writes numbers, not a packed-array string.
	return {"seed": world_seed, "edits": Array(e), "water": Array(w)}


## Accepts ints or floats (JSON.parse_string gives floats).
func load_save(data: Dictionary) -> void:
	clear()
	var e = data.get("edits", [])
	for i in range(0, e.size() - 2, 3):
		tiles[Vector2i(int(e[i]), int(e[i + 1]))] = int(e[i + 2])
	var w = data.get("water", [])
	for i in range(0, w.size() - 2, 3):
		water[Vector2i(int(w[i]), int(w[i + 1]))] = int(w[i + 2]) != 0
