## A-15 / P-06: how often each character's bark may play and what wakes it (data/barks.tres).
## Seconds are game time. Audio.bark() still keeps one voice at a time and its own gaps on top.
class_name BarkTuning
extends Resource

const PATH := "res://data/barks.tres"

## Jeff names every new kind of rock at once; after that, the same name at most this often.
@export var rock_every := 30.0
## Chuck narrates after this long driving faster than narrate_speed (fraction of top speed).
@export var narrate_every := 14.0
@export var narrate_speed := 0.5
## A resident speaks when a player walks within near_radius px of them, at most this often each.
@export var near_radius := 112.0   # 7 tiles
@export var mole_every := 25.0
@export var foreman_every := 25.0
@export var dragon_every := 30.0
## How long the picture bubble over the speaker stays up.
@export var bubble_secs := 1.6


## Cooldown in seconds for "<who>/<cue>".
func cooldown(key: String) -> float:
	match key:
		"jeff/rock_name":
			return rock_every
		"chuck/narrate":
			return narrate_every
		"mole/oh_dear":
			return mole_every
		"gnome_foreman/mutter":
			return foreman_every
		"dragon/rumble", "dragon/yawn":
			return dragon_every
	return 10.0


## The file at path, or the defaults if it is missing or not a BarkTuning.
static func load_from(path := PATH) -> BarkTuning:
	if ResourceLoader.exists(path):
		var r = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if r is BarkTuning:
			return r
	return BarkTuning.new()
