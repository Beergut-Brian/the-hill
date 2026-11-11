## One kind of block in the underground (data/blocks/<id>.tres).
class_name BlockData
extends TileDef

## Audio cue played when this block is dug, e.g. &"dig_dirt".
@export var dig_sound: StringName
## Tile depth where it starts to appear.
@export var depth_from: int
## Tile depth where it stops appearing (exclusive).
@export var depth_to: int
## Relative worth (BALANCE.md), never shown as a number.
@export var value: int = 1
## Lowest VehicleData.dig_tier that can remove it (0 = shovel).
@export var dig_tier: int = 0
## PT10-4: hit points (DigTuning: each hit takes the digger's power). 1 = breaks on any hit.
@export var toughness: int = 1
## PT10-4/5: only a vehicle breaks it (any dig_tier >= dig_tier); on foot it bonks.
@export var vehicle_only: bool = false
## PT10-4: the block a dig keeps (&"" = this one), and how many (a big haul: Hard Rock).
@export var keeps_as: StringName = &""
@export var haul: int = 1
## C-22: a boulder breaks it. A falling body at least `boulder_min_px` wide that lands on it at
## `boulder_min_speed` px/s or more cracks it away (Puzzles): the cells under the body, and the same
## block up to `boulder_reach` cells further along that row. A boulder-wall slab (data/puzzles) made of
## this block breaks whole. Smaller or slower bodies (a pebble) only clink.
@export var boulder_breaks: bool = false
@export var boulder_min_px: float = 20.0
@export var boulder_min_speed: float = 90.0
@export var boulder_reach: int = 1
## Ice: the player slides.
@export var slippery: bool = false
## Lava pockets: bounces the player.
@export var bouncy: bool = false
## Minor kinds only (pebbles, pipe, ore, geode): how LayerData.minor_kinds lays it into the
## layer's main block. &"patch" small clumps, &"run" short flat runs, &"vein" thin wiggly streaks,
## &"dot" lone cells. Empty for the main kinds (they come from block_mix).
@export var minor_shape: StringName = &""
## "" = decided by `breakable`; else unbreakable until that game version.
@export var breakable_from_version: String = ""


## True when breakable, or when `version` >= breakable_from_version (dotted integers).
func is_breakable_in(version: String) -> bool:
	if breakable:
		return true
	if breakable_from_version == "":
		return false
	return _cmp(version, breakable_from_version) >= 0


static func _parts(v: String) -> PackedInt32Array:
	var core := v.split("-")[0]
	var out := PackedInt32Array()
	for p in core.split("."):
		out.append(int(p))
	return out


static func _cmp(a: String, b: String) -> int:
	var pa := _parts(a)
	var pb := _parts(b)
	for i in maxi(pa.size(), pb.size()):
		var x := pa[i] if i < pa.size() else 0
		var y := pb[i] if i < pb.size() else 0
		if x != y:
			return 1 if x > y else -1
	return 0
