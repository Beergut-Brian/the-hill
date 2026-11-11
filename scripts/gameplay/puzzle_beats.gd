## --demo --demo-beat=<name> for the underground engineering lane (C-22, 2026-11-11). Like the other
## beat runners it sets the stage, then the real systems play it out (the real dig, the real fall,
## the real Front Loader dig).
##   wall          P1 walks into the Clay boulder wall's room and digs at the dirt pillar holding the
##                 boulder up: it drops onto the cracked slab and breaks it open (dust, crash, kick);
##                 P1 and the boulder drop into the chamber under it (a stone floor).
##   loader_block  P1 on foot beside the Clay heavy block: the Front Loader bubble shows, a dig clunks
##                 off. Then P1 in the Front Loader digs at it twice: a wobble, then it pops away.
## Loaded by path from HillGame (no class_name reference from there).
extends HazardBeats

const PUZZLE_BEATS := ["wall", "loader_block"]


func _physics_process(delta: float) -> void:
	super(delta)
	if game.player_node(P1) == null or t < START:
		return
	match beat:
		"wall": _wall()
		"loader_block": _loader_block()


func _wall() -> void:
	var u := _ug()
	if u.generator.walls.is_empty():
		if _stage == 0:
			_next("no boulder wall")
		return
	var wall: Dictionary = u.generator.walls[0]
	var slab: Rect2i = wall.slab
	var b: Rect2i = wall.boulder_rect
	var room: Rect2i = wall.room
	match _stage:
		0:
			# A tunnel in from the left, level with the room's floor; P1 at the room's left end.
			var tunnel := Rect2i(room.position.x - 6, slab.position.y - 2, 6, 2)
			_stage_players(tunnel, Vector2i(room.position.x - 3, slab.position.y - 1), Vector2i(tunnel.position.x, slab.position.y - 1))
			game.player_node(P1).facing = 1
			u.puzzles.wall_broke.connect(func(_i: int) -> void: log_event("wall broke"), CONNECT_ONE_SHOT)
			u.hazards.bonked.connect(func(p: int) -> void: log_event("bonk P%d" % (p + 1)), CONNECT_ONE_SHOT)
			_next("stage: P1 beside the room %s, boulder %s on the pillar" % [room, b])
		1:
			if _since() > 1.0:
				_next("walk in")
		2:
			_hold(P1, Vector2(1, 0))
			var pl: HillPlayer = game.player_node(P1)
			if u.world.to_local(pl.global_position).x >= (b.position.x - 0.9) * 16.0 or _since() > 3.0:
				_next("dig the pillar")
		3:
			_hold(P1, Vector2(1, 0), true)
			if not u.puzzles.wall_standing(0) or _since() > 4.0:
				_next("let go")
		4:
			if _since() > 6.0:
				_next("done")


func _loader_block() -> void:
	var u := _ug()
	if u.generator.vehicle_blocks.is_empty():
		if _stage == 0:
			_next("no vehicle block")
		return
	var r: Rect2i = u.generator.vehicle_blocks[0].rect
	var dir := 1 if r.position.x < HillGenerator.SHAFT_X else -1
	match _stage:
		0:
			# A room on the shaft side of the block, its floor level with the block's bottom.
			var room := Rect2i(r.end.x, r.position.y - 1, 9, r.size.y + 1) if dir > 0 else Rect2i(r.position.x - 9, r.position.y - 1, 9, r.size.y + 1)
			var near := Vector2i(r.end.x if dir > 0 else r.position.x - 1, r.end.y - 1)
			var far := Vector2i(room.end.x - 1 if dir > 0 else room.position.x, r.end.y - 1)
			_stage_players(room, near, far)
			game.player_node(P1).facing = -dir
			u.puzzles.block_hit.connect(func(_i: int, _p: int, left: int) -> void: log_event("block hit, %d left" % left))
			u.puzzles.block_cleared.connect(func(_i: int, _p: int) -> void: log_event("block cleared"), CONNECT_ONE_SHOT)
			_next("stage: P1 on foot beside the block %s" % r)
		1:
			if _since() > 1.2:
				_next("hand dig")
		2:
			_hold(P1, Vector2(-dir, 0), true)
			if _since() > 0.5:
				_next("bubble")
		3:
			if _since() > 1.4:
				var feet := Vector2(((r.end.x + 1.5) if dir > 0 else (r.position.x - 1.5)) * 16.0, r.end.y * 16.0 - 1.0)
				_ride(P1, &"front_loader", HillGame.UNDERGROUND, feet)
				game.player_node(P1).facing = -dir
				_next("in the Front Loader")
		4:
			if _since() > 1.0:
				_next("loader digs")
		5:
			_hold(P1, Vector2(-dir, 0), true)
			if not u.puzzles.block_standing(0) or _since() > 5.0:
				_next("let go")
		6:
			if _since() > 5.0:
				_next("done")
