## The surface clock (contract: docs/contracts.md "TimeOfDay"). Autoload: TimeOfDay.
## A tint and light curve over one 12 minute cycle; Hillville reads it, the Underground ignores it.
extends Node

signal phase_changed(phase: StringName)

const DATA_PATH := "res://data/time_of_day.tres"
const NIGHT_FROM := 0.70
const NIGHT_TO := 0.95
const DAY_FROM := 0.04
const DUSK_FROM := 0.56

## 0..1 through one cycle; 0.0 = morning, about 0.62 dusk, 0.70..0.95 night.
var time: float = 0.08
## HillGame turns it on while playing. Off = the clock holds still.
var running: bool = false
## Set by `--time=...`: the clock never advances.
var frozen: bool = false

var _data: TimeOfDayData
var _phase: StringName = &"day"


func _ready() -> void:
	_data = load(DATA_PATH) as TimeOfDayData
	if _data == null:
		_data = TimeOfDayData.new()
	time = _data.start_time
	_phase = phase()
	var t := parse_time_flag(OS.get_cmdline_user_args())
	if t >= 0.0:
		frozen = true
		set_time(t)


func _process(delta: float) -> void:
	if running and not frozen and _data != null and _data.cycle_seconds > 0.0:
		set_time(fposmod(time + delta / _data.cycle_seconds, 1.0))


## `--time=day|dusk|night|dawn|<0..1>` in `args`: the clock value, or -1.0 when there is no flag.
static func parse_time_flag(args: PackedStringArray) -> float:
	for a in args:
		if not a.begins_with("--time="):
			continue
		var v := a.substr(7).strip_edges().to_lower()
		match v:
			"day":
				return 0.30
			"dusk":
				return 0.62
			"night":
				return 0.82
			"dawn":
				return 0.97
		if v.is_valid_float():
			return clampf(v.to_float(), 0.0, 1.0)
	return -1.0


static func phase_at(t: float) -> StringName:
	t = fposmod(t, 1.0)
	if t >= NIGHT_TO or t < DAY_FROM:
		return &"dawn"
	if t < DUSK_FROM:
		return &"day"
	if t < NIGHT_FROM:
		return &"dusk"
	return &"night"


func set_time(t: float) -> void:
	time = fposmod(t, 1.0)
	var p := phase_at(time)
	if p != _phase:
		_phase = p
		phase_changed.emit(p)


func phase() -> StringName:
	return phase_at(time)


func cycle_seconds() -> float:
	return _data.cycle_seconds if _data != null else 720.0


func sky_top() -> Color:
	return _blend("sky_top") as Color


func sky_horizon() -> Color:
	return _blend("sky_horizon") as Color


func band() -> Color:
	return _blend("band") as Color


func world_tint() -> Color:
	return _blend("tint") as Color


func lights() -> float:
	return _blend("lights") as float


func to_save() -> Dictionary:
	return {"time": time}


func load_save(data: Dictionary) -> void:
	if data.has("time") and not frozen:
		set_time(clampf(float(data["time"]), 0.0, 1.0))


## Blends `key` between the two keyframes around `time` (the last wraps to the first).
func _blend(key: String) -> Variant:
	return blend_at(_data.keyframes if _data != null else [], key, time)


static func blend_at(kfs: Array, key: String, t: float) -> Variant:
	if kfs.is_empty():
		return 0.0 if key == "lights" else Color.WHITE
	var n := kfs.size()
	var lo: Dictionary = kfs[n - 1]
	var hi: Dictionary = kfs[0]
	var lo_t: float = float(lo.t) - 1.0
	var hi_t: float = float(hi.t)
	for i in n:
		if float(kfs[i].t) > t:
			hi = kfs[i]
			hi_t = float(hi.t)
			if i > 0:
				lo = kfs[i - 1]
				lo_t = float(lo.t)
			break
		if i == n - 1:
			lo = kfs[i]
			lo_t = float(lo.t)
			hi = kfs[0]
			hi_t = float(hi.t) + 1.0
	var u := 0.0 if hi_t <= lo_t else clampf((t - lo_t) / (hi_t - lo_t), 0.0, 1.0)
	var a: Variant = lo[key]
	var b: Variant = hi[key]
	if a is Color:
		return (a as Color).lerp(b as Color, u)
	return lerpf(float(a), float(b), u)
