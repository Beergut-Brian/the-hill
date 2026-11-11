## --demo --demo-beat=<name> for the puzzles lane (C-22, 2026-11-10): each underground engineering
## puzzle solved by P1 with the stick and A, the real systems playing it out.
##   drain    P1 in the drain's nook: left + A digs the channel (the pocket floods the nook), right
##            + A opens the plug, the water runs down the chute into the sump; the gift pops.
##   boulder  P1 beside the strut: right + A knocks it out, the boulder drops onto the cracked wall
##            and breaks it; the gift pops.
##   heavy    P1 on foot pushes A at the heavy block (bounce, the Loader picture), then in the Front
##            Loader A lifts it out; the gift pops.
class_name PuzzleBeats
extends HazardBeats

const PUZZLE_BEATS := ["drain", "boulder", "heavy"]


func _physics_process(delta: float) -> void:
	super(delta)
	if game.player_node(P1) == null or t < START:
		return
	match beat:
		"drain": _drain()
		"boulder": _boulder()
		"heavy": _heavy()


func _pz(kind: StringName) -> Dictionary:
	for pz in _ug().generator.puzzles:
		if pz.kind == kind:
			return pz
	return {}


func _feet(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * 16.0, (c.y + 1) * 16.0 - 1.0)


func _solid(r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _ug().world.is_solid(Vector2i(x, y)):
				return true
	return false


func _solved(pz: Dictionary) -> bool:
	return _ug().puzzles.is_solved(_ug().generator.puzzles.find(pz))


func _drain() -> void:
	var pz := _pz(&"drain")
	if pz.is_empty():
		return
	var nook: Rect2i = pz.nook
	match _stage:
		0:
			_place(P1, _feet(Vector2i(nook.end.x - 1, nook.end.y - 1)))
			game.player_node(P1).facing = -1
			_next("stage: P1 in the drain nook %s" % nook)
		1:
			if _since() > 1.5:
				_next("dig the channel")
		2:
			_hold(P1, Vector2.LEFT, true)
			if not _solid(pz.wall):
				_hold(P1, Vector2.ZERO)
				_next("channel open")
		3:
			if _since() > 1.5:
				_next("open the plug")
		4:
			_hold(P1, Vector2.RIGHT, true)
			if not _solid(pz.plug):
				_hold(P1, Vector2.ZERO)
				_next("plug open")
		5:
			if _solved(pz):
				_next("solved")
			elif _since() > 15.0:
				_next("not solved")


func _boulder() -> void:
	var pz := _pz(&"boulder_wall")
	if pz.is_empty():
		return
	var nook: Rect2i = pz.nook
	match _stage:
		0:
			_place(P1, _feet(Vector2i(nook.end.x - 1, nook.end.y - 1)))
			game.player_node(P1).facing = 1
			_next("stage: P1 by the strut %s" % pz.strut)
		1:
			if _since() > 1.5:
				_next("knock the strut")
		2:
			_hold(P1, Vector2.RIGHT, true)
			if not _solid(pz.strut):
				_hold(P1, Vector2.ZERO)
				_next("strut out")
		3:
			if _solved(pz):
				_next("solved")
			elif _since() > 10.0:
				_next("not solved")


func _heavy() -> void:
	var pz := _pz(&"heavy_block")
	if pz.is_empty():
		return
	var block: Rect2i = pz.block
	match _stage:
		0:
			_place(P1, _feet(Vector2i(block.position.x - 2, block.end.y - 1)))
			game.player_node(P1).facing = 1
			_next("stage: P1 by the heavy block %s" % block)
		1:
			if _since() > 1.0:
				_next("dig by hand")
		2:
			_hold(P1, Vector2.RIGHT, true)
			if _since() > 1.2:
				_hold(P1, Vector2.ZERO)
				_next("bounced")
		3:
			if _since() > 1.5:
				_ride(P1, &"front_loader", HillGame.UNDERGROUND, _feet(Vector2i(block.position.x - 3, block.end.y - 1)))
				game.player_node(P1).facing = 1
				_next("in the loader")
		4:
			if _since() > 1.0:
				_next("lift")
		5:
			_hold(P1, Vector2.RIGHT, true)
			if not _solid(block):
				_hold(P1, Vector2.ZERO)
				_next("lifted")
			elif _since() > 4.0:
				_next("not lifted")
		6:
			if _solved(pz):
				_next("solved")
