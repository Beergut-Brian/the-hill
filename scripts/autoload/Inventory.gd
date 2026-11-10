## The shared block pile for both players. Costs are Dictionary block id -> count.
extends Node

var _counts: Dictionary = {}   # StringName -> int


func count(block: StringName) -> int:
	return int(_counts.get(block, 0))


func add(block: StringName, n: int = 1) -> void:
	if n <= 0:
		return
	_counts[block] = count(block) + n
	Events.inventory_changed.emit(block, _counts[block])


func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if count(StringName(str(k))) < int(cost[k]):
			return false
	return true


## All or nothing: returns false and changes nothing if the pile is short.
func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for k in cost:
		var n := int(cost[k])
		if n <= 0:
			continue
		var b := StringName(str(k))
		_counts[b] = count(b) - n
		Events.inventory_changed.emit(b, _counts[b])
	return true


## String keys so it survives JSON.
func to_save() -> Dictionary:
	var out := {}
	for b in _counts:
		if _counts[b] > 0:
			out[String(b)] = int(_counts[b])
	return out


func load_save(data: Dictionary) -> void:
	_counts.clear()
	for k in data:
		var n := int(data[k])
		if n > 0:
			_counts[StringName(str(k))] = n
	for b in _counts:
		Events.inventory_changed.emit(b, _counts[b])


func clear() -> void:
	var old := _counts.keys()
	_counts.clear()
	for b in old:
		Events.inventory_changed.emit(b, 0)
