## Gathers and applies every save key of the contract ("Save keys"): "world", "inventory",
## Progress's four keys ("treasures", "vehicles", "buildings", "players"), "hillville" and "seed".
## Autosaves every AUTOSAVE_EVERY seconds of play; HillGame also saves after every ride and on
## Game.quit_requested. Every save ends with Save.flush().
class_name HillSave
extends Node

const AUTOSAVE_EVERY := 60.0
const PROGRESS_KEYS := ["treasures", "vehicles", "buildings", "players"]

## HillGame (untyped so this script stands alone).
var game: Node
var _t := 0.0


## The seed the saved world was made from, or `fallback` on a fresh save.
static func saved_seed(fallback: int) -> int:
	return int(Save.get_value("seed", fallback))


func gather() -> void:
	game.note_scenes()
	Save.set_value("seed", int(game.underground.world_seed))
	Save.set_value("world", game.underground.world.to_save())
	Save.set_value("inventory", Inventory.to_save())
	var pd: Dictionary = Progress.to_save()
	for k in PROGRESS_KEYS:
		Save.set_value(k, pd[k])
	var hv: Node = game.hillville
	if hv != null and hv.has_method("to_save"):
		Save.set_value("hillville", hv.to_save())


func save_now() -> void:
	gather()
	Save.flush()
	_t = 0.0


## Restores a reboot: tiles, the pile, run state, the town, then rebuilds the buildings.
func apply() -> void:
	var w = Save.get_value("world")
	if w is Dictionary:
		game.underground.world.load_save(w)
	var inv = Save.get_value("inventory")
	Inventory.clear()
	if inv is Dictionary:
		Inventory.load_save(inv)
	var pd := {}
	for k in PROGRESS_KEYS:
		var v = Save.get_value(k)
		if v != null:
			pd[k] = v
	Progress.reset()
	Progress.load_save(pd)
	var hv: Node = game.hillville
	var hd = Save.get_value("hillville")
	if hv != null and hv.has_method("load_save") and hd is Dictionary:
		hv.load_save(hd)
	var build: Node = game.build
	if build != null and build.has_method("rebuild"):
		build.rebuild()


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= AUTOSAVE_EVERY:
		save_now()
