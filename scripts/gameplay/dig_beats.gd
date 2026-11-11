## --demo --demo-beat=<name> for the Dig progression lane (2026-11-11, playtest items 4 and 5):
##   slow   P1 on foot in Topsoil holds A down: each hit cracks the dirt (crumbs, flash), the third
##          pops it. Then a Workshop goes up: the gold shovel pops and the same dig is quicker.
##   gate   P1 digs down onto the first unlock band (Gate Rock over Clay): a bonk and the gold
##          shovel picture over the head, the band's signs show it too. A Workshop goes up: the
##          signs glow gold and P1 digs through into Clay.
##   gate2  P1 on foot bonks the Stone band (an Excavator picture), then drives the Excavator
##          down through it.
##   hard   P1 on foot bonks Hard Rock in Clay (a Front Loader picture), then in the Front Loader
##          breaks it: a big haul (four stone a block, a gold burst).
##   scrub  Up top P1 on foot bonks a tree (it shakes, a Front Loader picture, the hint panel's A
##          shows the loader), then clears it in the Front Loader.
## Every step logs "beat:" lines (crack stages, backpack, depth) for shot times and proof.
class_name DigBeats
extends ControlsBeats

const DIG_BEATS := ["slow", "gate", "gate2", "hard", "scrub"]


func _physics_process(delta: float) -> void:
	super(delta)
	if game.player_node(P1) == null or t < START:
		return
	match beat:
		"slow": _slow()
		"gate": _gate(0, 0)
		"gate2": _gate(1, 1)
		"hard": _hard()
		"scrub": _scrub()


func _p1() -> HillPlayer:
	return game.player_node(P1)


func _band(i: int) -> Dictionary:
	return _ug().generator.gate_bands[i]


func _away_p2() -> void:
	if game.player_node(P2) != null:
		_yard(P2, Hillville.SHAFT_X - 300)


func _grant_workshop() -> void:
	if Progress.count_buildings(&"workshop") == 0:
		Progress.add_building(&"workshop", Vector2i(40, 0))
		Events.building_placed.emit(&"workshop", Vector2i(40, 0))


func _room(x0: int, y0: int, w: int, h: int) -> void:
	var wd := _ug().world
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			wd.set_tile(Vector2i(x, y), 0)


func _log_cell(c: Vector2i) -> void:
	var f := _ug().dig_feel
	log_event("cell %s solid=%s crack=%.2f bag=%d" % [c, _ug().world.is_solid(c), f.crack_of(c), _p1().backpack_count()])


func _slow() -> void:
	var under := Vector2i(63, 15)
	match _stage:
		0:
			_room(61, 12, 5, 3)
			_place(P1, Vector2(63.5 * 16.0, 15 * 16.0 - 1.0))
			_away_p2()
			_next("stage: P1 on foot in Topsoil, starting shovel")
		1:
			_hold(P1, Vector2(0, 1), true)
			if int(_since() * 10.0) != int((_since() - 1.0 / 60.0) * 10.0):
				_log_cell(under)
			if _since() > 3.0:
				_hold(P1, Vector2.ZERO)
				_grant_workshop()
				_next("workshop built: gold shovel")
		2:
			if _since() > 1.5:
				_next("digging with the sturdy shovel")
		3:
			_hold(P1, Vector2(0, 1), true)
			if int(_since() * 10.0) != int((_since() - 1.0 / 60.0) * 10.0):
				_log_cell(under + Vector2i(0, 3))
			if _since() > 3.0:
				_hold(P1, Vector2.ZERO)
				_next("done")


## Gate i: P1 on foot over the band bonks it; then (i 0) a Workshop or (i 1) the Excavator.
func _gate(i: int, _k: int) -> void:
	var b := _band(i)
	var top: int = b.from
	match _stage:
		0:
			_room(60, top - 4, 7, 3)
			_place(P1, Vector2(63.5 * 16.0, (top - 1) * 16.0 - 1.0))
			_away_p2()
			_next("stage: P1 on foot over band %s (rows %d..%d)" % [b.gate.id, b.from, b.to - 1])
		1:
			_hold(P1, Vector2(0, 1), true)
			if _p1().need_hint() != &"":
				_next("bonk: need %s" % _p1().need_hint())
			elif _since() > 6.0:
				_next("no bonk (band open?)")
		2:
			_hold(P1, Vector2.ZERO)
			if _since() > 2.2:
				if i == 0:
					_grant_workshop()
					_next("workshop built: band signs glow")
				else:
					var at := _p1().global_position
					_ride(P1, &"excavator", HillGame.UNDERGROUND, at)
					_next("P1 in the Excavator")
		3:
			if _since() > 1.2:
				_next("digging through the band")
		4:
			_hold(P1, Vector2(0, 1), true)
			var row := _ug().world.shape.cell_at(_ug().world.to_local(_p1().global_position)).y
			if row > b.to + 1:
				_next("through: P1 at row %d (layer %s)" % [row, b.gate.opens])
			elif _since() > 10.0:
				var wd := _ug().world
				var below := []
				for c in _p1().dig_cells(Vector2i(0, 1)):
					below.append("%s:%s" % [c, wd.tile_def(wd.get_tile(c)).id])
				_next("stuck at row %d, dig cells %s targets %s" % [row, below, _p1().dig_targets(Vector2i(0, 1))])
		5:
			_hold(P1, Vector2.ZERO)
			if _since() > 1.5:
				_next("done")


func _hard() -> void:
	var y0 := 44
	match _stage:
		0:
			_room(58, y0, 12, 3)
			var wd := _ug().world
			var hid := wd.palette.find(_ug().blocks[&"hardrock"])
			for y in range(y0, y0 + 3):
				for x in range(66, 68):
					wd.set_tile(Vector2i(x, y), hid)
			_place(P1, Vector2(64.5 * 16.0, (y0 + 3) * 16.0 - 1.0))
			_p1().facing = 1
			_away_p2()
			_next("stage: P1 on foot beside Hard Rock in Clay")
		1:
			_hold(P1, Vector2(1, 0), true)
			if _p1().need_hint() != &"":
				_next("bonk: need %s" % _p1().need_hint())
			elif _since() > 4.0:
				_next("no bonk")
		2:
			_hold(P1, Vector2.ZERO)
			if _since() > 2.2:
				_ride(P1, &"front_loader", HillGame.UNDERGROUND, Vector2(62.5 * 16.0, (y0 + 3) * 16.0 - 1.0))
				_p1().facing = 1
				_next("P1 in the Front Loader")
		3:
			if _since() > 1.0:
				_next("loader digs the Hard Rock")
		4:
			_hold(P1, Vector2(1, 0), true)
			if _p1().backpack_count() >= 4 and _since() > 2.0 or _since() > 6.0:
				_next("haul: bag %d" % _p1().backpack_count())
		5:
			_hold(P1, Vector2.ZERO)
			if _since() > 1.5:
				_next("done")


func _scrub() -> void:
	var hv: Hillville = game.hillville
	match _stage:
		0:
			var x := hv.nearest_scrub(float(Hillville.SHAFT_X) - 260.0)
			_yard(P1, x - 22.0, 1)
			_away_p2()
			_next("stage: P1 on foot beside scrub at x %.0f" % x)
		1:
			_hold(P1, Vector2.ZERO, int(_since() * 3.0) % 2 == 0)
			if _since() > 2.4:
				_hold(P1, Vector2.ZERO)
				_next("bonks: need %s, scrub left %d" % [_p1().need_hint(), hv.scrub_left()])
		2:
			if _since() > 0.6:
				var at := _p1().global_position + Vector2(-30, 0)
				_ride(P1, &"front_loader", HillGame.HILLVILLE, at)
				_p1().facing = 1
				_next("P1 in the Front Loader")
		3:
			_hold(P1, Vector2(0.4, 0), int(_since() * 3.0) % 2 == 0)
			if _since() > 3.0:
				_hold(P1, Vector2.ZERO)
				_next("cleared: scrub left %d" % hv.scrub_left())
		4:
			if _since() > 1.0:
				_next("done")
