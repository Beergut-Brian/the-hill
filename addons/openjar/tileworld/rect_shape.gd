## A width x height rectangle of cells, (0, 0) top-left, square chunks, gravity straight down.
class_name RectShape
extends WorldShape

var width: int
var height: int
var chunk_size: int


func _init(p_width: int = 200, p_height: int = 300, p_chunk_size: int = 32) -> void:
	width = p_width
	height = p_height
	chunk_size = p_chunk_size


func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(cell.x / float(chunk_size)), floori(cell.y / float(chunk_size)))


func chunk_cells(key: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var from := key * chunk_size
	for y in range(maxi(from.y, 0), mini(from.y + chunk_size, height)):
		for x in range(maxi(from.x, 0), mini(from.x + chunk_size, width)):
			cells.append(Vector2i(x, y))
	return cells


func neighbourhood(key: Vector2i, radius: int = 1) -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	var last := chunk_of(Vector2i(width - 1, height - 1))
	for cy in range(maxi(key.y - radius, 0), mini(key.y + radius, last.y) + 1):
		for cx in range(maxi(key.x - radius, 0), mini(key.x + radius, last.x) + 1):
			keys.append(Vector2i(cx, cy))
	return keys


func gravity_at(_pos: Vector2) -> Vector2:
	return Vector2(0.0, gravity)


func below(cell: Vector2i) -> Vector2i:
	return cell + Vector2i.DOWN


func sides(cell: Vector2i) -> Array[Vector2i]:
	return [cell + Vector2i.LEFT, cell + Vector2i.RIGHT]


func depth_of(cell: Vector2i) -> int:
	return cell.y
