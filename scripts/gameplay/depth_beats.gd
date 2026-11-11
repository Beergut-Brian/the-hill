## --demo --demo-beat=<name> for the depth life lane (2026-11-10): each layer's own life.
##   worms  P1 and P2 in the Topsoil landing room, roots hanging from its ceiling. They walk to the
##          side walls: a worm pops out of each and waves, then ducks back in as they walk away.
##   sand   P1 in a little room in the lower Stone layer, digging sideways into Sand.
##   fish   P1 on the nearest Ice rink (snow drifts on the ice) above its frozen fish: digs down,
##          the fish is the treasure (reveal); then on a second rink a second fish wiggles free
##          and swims off (no second treasure).
class_name DepthBeats
extends HazardBeats

const DEPTH_BEATS := ["worms", "sand", "fish"]

var _rink_i := 0


func _physics_process(delta: float) -> void:
	super(delta)
	if game.player_node(P1) == null or t < START:
		return
	match beat:
		"worms": _worms()
		"sand": _sand()
		"fish": _fish()


func _worms() -> void:
	var u := _ug()
	var room: Rect2i = u.generator.landings[0]
	var y := room.end.y - 1
	match _stage:
		0:
			_place(P1, Vector2((room.position.x + 4.5) * 16.0, room.end.y * 16.0 - 1.0))
			if game.player_node(P2) != null:
				_place(P2, Vector2((room.end.x - 4.5) * 16.0, room.end.y * 16.0 - 1.0))
			_next("stage: Topsoil landing, %d roots in Topsoil" % u.life.roots.size())
		1:
			_hold(P1, Vector2(-1, 0))
			if game.player_node(P2) != null:
				_intent[P2] = {"move": Vector2(1, 0), "dig": false, "jump": false, "book": false, "horn": false}
			if _since() > 0.5:
				_next("at the walls")
		2:
			if not u.life.waving_worms().is_empty():
				_next("worms waving %s" % [u.life.waving_worms()])
			elif _since() > 3.0:
				_next("no worm waved (walls at %s, %s)" % [Vector2i(room.position.x - 1, y), Vector2i(room.end.x, y)])
		3:
			if _since() > 2.0:
				_next("walk away")
		4:
			_hold(P1, Vector2(1, 0))
			if _since() > 1.2:
				_next("worms in: %d waving" % u.life.waving_worms().size())
		5:
			if _since() > 1.0:
				_next("done")


## The first spot near the shaft with five Sand cells in a row, in the lower Stone layer.
func _sand_spot() -> Vector2i:
	var u := _ug()
	var sand := -1
	for i in u.world.palette.size():
		if u.world.palette[i].id == &"sand":
			sand = i
	for y in range(104, 126):
		for dx in 40:
			for x in [HillGenerator.SHAFT_X + 8 + dx, HillGenerator.SHAFT_X - 12 - dx]:
				var ok := true
				for k in 5:
					if u.world.get_tile(Vector2i(x + k, y)) != sand:
						ok = false
						break
				if ok:
					return Vector2i(x, y)
	return Vector2i(-1, -1)


func _sand() -> void:
	var u := _ug()
	match _stage:
		0:
			var at := _sand_spot()
			if at.x < 0:
				_next("no sand found")
				return
			var room := Rect2i(at.x - 5, at.y - 1, 5, 2)
			_stage_players(room, Vector2i(room.end.x - 1, at.y), Vector2i(room.position.x, at.y))
			u.world.tile_dug.connect(func(c: Vector2i, b: StringName, _p: int) -> void: log_event("dug %s at %s" % [b, c]))
			_next("stage: beside sand at %s" % at)
		1:
			if _since() > 1.0:
				_next("dig")
		2:
			_hold(P1, Vector2(1, 0), true)
			if _since() > 3.0:
				_next("done")


func _fish() -> void:
	var u := _ug()
	var g := u.generator
	match _stage:
		0:
			var ih := _rink()
			_rink_i = g.ice_holes.find(ih)
			if _rink_i < 0 or _rink_i >= g.fish_cells.size():
				_next("no rink")
				return
			_over_fish(_rink_i)
			u.treasure_dug.connect(func(id: StringName, _p: int) -> void: log_event("found %s" % id))
			_next("stage: over the fish at %s on rink %s" % [g.fish_cells[_rink_i], (ih.rink as Rect2i)])
		1:
			if _since() > 1.5:
				_next("dig")
		2:
			_hold(P1, Vector2(0, 1), true)
			if not u.life.has_fish(g.fish_cells[_rink_i]):
				_next("fish dug: treasure %s" % Progress.has_treasure(HillGenerator.FISH))
		3:
			if _since() > 2.8:
				_rink_i = (_rink_i + 1) % g.fish_cells.size()
				_over_fish(_rink_i)
				_next("second rink: fish at %s" % g.fish_cells[_rink_i])
		4:
			if _since() > 1.2:
				_next("dig again")
		5:
			_hold(P1, Vector2(0, 1), true)
			if not u.life.has_fish(g.fish_cells[_rink_i]):
				_next("second fish free (treasures found: %d frozen_fish)" % Progress.treasures.count(HillGenerator.FISH))
		6:
			if _since() > 2.0:
				_next("done")


func _over_fish(i: int) -> void:
	var c: Vector2i = _ug().generator.fish_cells[i]
	_place(P1, Vector2((c.x + 0.5) * 16.0, c.y * 16.0 - 1.0))
	if game.player_node(P2) != null:
		_place(P2, Vector2((c.x - 3.5) * 16.0, c.y * 16.0 - 1.0))
