## PT10-4: how digging feels (data/dig.tres). Every block has BlockData.toughness hit points; each
## hit takes `power` of them. On foot the power and the time between hits come from the Workshop
## level (index = Progress.tool_level()); in a vehicle from its dig_tier. A tile cracks on every
## hit (crack stages, crumbs, a tick) and pops when it breaks.
class_name DigTuning
extends Resource

## Seconds between shovel hits, per Workshop level (0 = the starting shovel).
@export var shovel_every: PackedFloat32Array = PackedFloat32Array([0.3, 0.22, 0.16])
## Hit points a shovel hit takes, per Workshop level.
@export var shovel_power: PackedInt32Array = PackedInt32Array([1, 2, 4])
## Seconds between vehicle hits, per VehicleData.dig_tier (0 Front Loader .. 3 Drill Rig).
@export var vehicle_every: PackedFloat32Array = PackedFloat32Array([0.26, 0.2, 0.18, 0.16])
## Hit points a vehicle hit takes, per dig_tier.
@export var vehicle_power: PackedInt32Array = PackedInt32Array([2, 5, 6, 9])
## Crumbs per hit that does not break the tile; a break gets the usual burst plus a pop ring.
@export var crumbs: int = 5
## Seconds the "need this" picture stays over a player after a bonk.
@export var need_secs: float = 1.8

static var _default: DigTuning


## The pre-PT10-4 dig (one hit breaks any shovel-tier block; 0.14 s on foot, 0.22 s driving):
## for the scripted --demo (DigFeel.demo_open) and for tests about dig shapes, not speed.
static func instant() -> DigTuning:
	var t := DigTuning.new()
	t.shovel_every = PackedFloat32Array([0.14, 0.14 / 1.35, 0.14 / 1.7])
	t.shovel_power = PackedInt32Array([99, 99, 99])
	t.vehicle_every = PackedFloat32Array([0.22, 0.22, 0.22, 0.22])
	t.vehicle_power = PackedInt32Array([99, 99, 99, 99])
	return t


static func get_default() -> DigTuning:
	if _default == null:
		_default = load("res://data/dig.tres") as DigTuning
		if _default == null:
			_default = DigTuning.new()
	return _default


func every_for(level: int, vehicle_tier: int) -> float:
	if vehicle_tier >= 0:
		return vehicle_every[clampi(vehicle_tier, 0, vehicle_every.size() - 1)]
	return shovel_every[clampi(level, 0, shovel_every.size() - 1)]


func power_for(level: int, vehicle_tier: int) -> int:
	if vehicle_tier >= 0:
		return vehicle_power[clampi(vehicle_tier, 0, vehicle_power.size() - 1)]
	return shovel_power[clampi(level, 0, shovel_power.size() - 1)]


## Hits to break a block of `toughness`.
func hits_for(toughness: int, level: int, vehicle_tier: int) -> int:
	return ceili(float(maxi(toughness, 1)) / float(maxi(power_for(level, vehicle_tier), 1)))


## Seconds to break one tile of `toughness` while A is held (the first hit lands at once).
func secs_for(toughness: int, level: int, vehicle_tier: int) -> float:
	return float(hits_for(toughness, level, vehicle_tier) - 1) * every_for(level, vehicle_tier)
