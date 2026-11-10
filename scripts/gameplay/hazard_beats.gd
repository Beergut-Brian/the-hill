## --demo --demo-beat=<name> for the hazards lane (2026-11-10): the deep layers' comedy hazards.
## Like the other beat runners it puts P1 at the spot, then the real systems play it out (the real
## ice glide, the real chute drift, the real lava bounce).
##   ice_slide  P1 on an Ice rink pushes toward its far end for half a second and lets go: they
##              skate on with spray and streaks, sail into the hole, drift down the chute with
##              snowflakes a layer down into Crystal and land on the snow pile (pop).
##   ice_drive  The same in the Front Loader: the vehicle skates and drops in too.
##   lava       P1 walks across a Crystal lava pocket: boing, boing, boing, and out the far side.
class_name HazardBeats
extends PolishBeats

const HAZARD_BEATS := ["ice_slide", "ice_drive", "lava"]


func _ready() -> void:
	super()
	# Before Hazards, so its ice glide wraps the beat's stick instead of being replaced by it.
	process_physics_priority = -2


func _physics_process(delta: float) -> void:
	super(delta)
	if game.player_node(P1) == null or t < START:
		return
	match beat:
		"ice_slide": _ice(false)
		"ice_drive": _ice(true)
		"lava": _lava()


## The rink nearest the Ice landing.
func _rink() -> Dictionary:
	var holes: Array = _ug().generator.ice_holes
	var best := {}
	var bd := 1 << 20
	for ih in holes:
		var d := absi((ih.rink as Rect2i).get_center().x - HillGenerator.SHAFT_X) + (ih.rink as Rect2i).position.y
		if d < bd:
			bd = d
			best = ih
	return best


func _ice(drive: bool) -> void:
	var u := _ug()
	var ih := _rink()
	if ih.is_empty():
		if _stage == 0:
			_next("no ice hole")
		return
	var rink: Rect2i = ih.rink
	var dir := int(ih.dir)
	match _stage:
		0:
			var start_x := rink.position.x + 2 if dir > 0 else rink.end.x - 3
			var feet := Vector2((start_x + 0.5) * 16.0, rink.end.y * 16.0 - 1.0)
			if drive:
				_ride(P1, &"front_loader", HillGame.UNDERGROUND, feet)
			else:
				_place(P1, feet)
			game.player_node(P1).facing = dir
			if game.player_node(P2) != null:
				_place(P2, u.landing(_layer(&"crystal")) + Vector2(-40, 0))
			u.hazards.slid.connect(func(_p: int) -> void: log_event("slide"), CONNECT_ONE_SHOT)
			u.hazards.dropped.connect(func(_p: int, _h: int) -> void: log_event("drop"), CONNECT_ONE_SHOT)
			u.hazards.nested.connect(func(_p: int, _h: int) -> void: log_event("nest"), CONNECT_ONE_SHOT)
			_next("stage: P1 on the Ice rink %s, hole %s" % [rink, ih.hole])
		1:
			if _since() > 1.0:
				_next("push")
		2:
			_hold(P1, Vector2(dir, 0))
			if _since() > (1.6 if drive else 0.8):
				_next("let go")
		3:
			if int(_since() * 60.0) % 30 == 0:
				var pl: HillPlayer = game.player_node(P1)
				log_event("p1 %s glide %.2f v %s" % [u.world.shape.cell_at(u.world.to_local(pl.global_position)), u.hazards.glide_of(P1), pl.velocity])
			if _since() > 8.0 or (u.hazards.since_bounce(P1) == INF and not u.hazards.is_dropping(P1) and _since() > 1.0 and game.player_node(P1).is_on_floor() and u.layer_index_at(u.world.to_local(game.player_node(P1).global_position)) == _layer(&"crystal")):
				_next("landed")
		4:
			if _since() > 2.0:
				_next("done")


func _lava() -> void:
	var u := _ug()
	var pockets: Array = u.generator.lava_pockets
	if pockets.is_empty():
		if _stage == 0:
			_next("no lava pocket")
		return
	var lp: Dictionary = pockets[0]
	var room: Rect2i = lp.room
	match _stage:
		0:
			_place(P1, Vector2((room.position.x + 0.5) * 16.0, room.end.y * 16.0 - 1.0))
			game.player_node(P1).facing = 1
			if game.player_node(P2) != null:
				_place(P2, Vector2((room.position.x + 1.5) * 16.0, room.end.y * 16.0 - 1.0))
			u.hazards.bounced.connect(func(p: int) -> void: log_event("boing P%d" % (p + 1)))
			_next("stage: P1 at the edge of a lava pocket")
		1:
			if _since() > 1.0:
				_next("walk")
		2:
			# Slowly across: a few bounces on the way.
			_hold(P1, Vector2(0.35, 0))
			if _since() > 1.2:
				_hold(P2, Vector2(0.3, 0))
			if _since() > 6.0:
				_next("done")
