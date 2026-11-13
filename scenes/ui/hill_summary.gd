## What a Hill save holds, in three numbers for the New Hill / Restore question: buildings put up,
## the deepest layer anyone reached, treasures found. Reads a save Dictionary (Save.read_save()).
class_name HillSummary
extends RefCounted

const LAYER_DIR := "res://data/layers/"


## {buildings, treasures, deepest (layer index), layer (name), layer_color}.
static func of(data: Dictionary) -> Dictionary:
	var deepest := 0
	var players = data.get("players", [])
	if players is Array:
		for p in players:
			if p is Dictionary:
				deepest = maxi(deepest, int(p.get("deepest", 0)))
	var rows := layers()
	var layer: LayerData = rows[clampi(deepest, 0, rows.size() - 1)] if not rows.is_empty() else null
	var b = data.get("buildings", [])
	var t = data.get("treasures", [])
	return {
		"buildings": b.size() if b is Array else 0,
		"treasures": t.size() if t is Array else 0,
		"deepest": deepest,
		"layer": String(layer.id).capitalize() if layer else "Topsoil",
		"layer_color": layer.hue if layer else Color("8a5a2b"),
	}


## The layers, top first.
static func layers() -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(LAYER_DIR):
		var file := f.trim_suffix(".remap")
		if file.ends_with(".tres"):
			out.append(load(LAYER_DIR + file))
	out.sort_custom(func(a: LayerData, b: LayerData) -> bool: return a.depth_from < b.depth_from)
	return out
