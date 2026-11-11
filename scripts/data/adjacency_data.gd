## Town adjacency tuning (C-23, C-26): which buildings like each other and how near "near" is.
## One row: data/adjacency.tres. Ids are BuildingData ids, or the town landmarks &"shaft" and
## &"pond". A resident's home counts once it is restored (lost_and_found, gnome_village, museum,
## dragon_perch). Content lane tunes it; TownAdjacency reads it.
class_name AdjacencyData
extends Resource

## Pairs that like each other: each entry is two ids (order does not matter).
@export var pairs: Array[PackedStringArray] = []
## How many empty plots may lie between two footprints and still count as "near".
@export var radius_plots := 3

@export_group("Look")
## Hearts on the arc between a happy pair at once.
@export var hearts := 3
## Seconds for one heart to float from one building to the other.
@export var heart_time := 2.4
## Flowers per plot of ground between a happy pair (at least three per pair).
@export var flowers_per_plot := 4
## Seconds for a new pair's flowers to grow.
@export var grow_time := 1.4
## Sparkles in the burst when a new pair is made.
@export var sparkles := 16
## How strong the ghost's preview hearts are (0..1).
@export var preview_alpha := 0.75


## True when `a` and `b` like each other.
func likes(a: StringName, b: StringName) -> bool:
	for p in pairs:
		if p.size() < 2:
			continue
		if (StringName(p[0]) == a and StringName(p[1]) == b) or (StringName(p[0]) == b and StringName(p[1]) == a):
			return true
	return false
