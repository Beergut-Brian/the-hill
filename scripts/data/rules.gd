## Game rules that are pure functions of data: ruin restoring and the gnome crew.
class_name Rules
extends RefCounted

## Under 30 minutes away: nothing, no clip.
const GNOME_MIN_AWAY := 1800.0
const GNOME_FLOOR := 20
const GNOME_CAP := 50
## Blocks per hour away.
const GNOME_RATE := 10.0


## True when the card may be paid: a ruin, its own resident ARRIVED, and the pile affords it.
static func can_restore(ruin: BuildingData, state: ResidentState, afford: bool) -> bool:
	return ruin.is_ruin and state.id == ruin.resident and state.phase == ResidentState.Phase.ARRIVED and afford


## Content test: every block in the ruin's cost starts at or above met_depth.
static func restore_cost_is_fair(ruin: BuildingData, met_depth: int, blocks: Array) -> bool:
	for k in ruin.cost:
		var found := false
		for b in blocks:
			if b is BlockData and b.id == StringName(str(k)):
				found = b.depth_from <= met_depth
				break
		if not found:
			return false
	return true


## Blocks the gnome crew leaves at the shaft after `away_seconds` away.
static func gnome_award(away_seconds: float, cap_bonus: int = 0) -> int:
	if away_seconds < GNOME_MIN_AWAY:
		return 0
	return clampi(roundi(GNOME_RATE * away_seconds / 3600.0), GNOME_FLOOR, GNOME_CAP + cap_bonus)
