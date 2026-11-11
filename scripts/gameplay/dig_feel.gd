## PT10-4 / PT10-5, the dig lane: how a dig feels and what it may break underground.
## - Hit points: every block has BlockData.toughness; a hit takes the digger's power (DigTuning,
##   from the Workshop level on foot or the vehicle's dig_tier). A hit that does not break the
##   tile cracks it (crack stages drawn here, a white flash, crumbs, the block's dig sound, soft);
##   the hit that breaks it pops (a ring, sparks, `pop`). Cracks stay until the tile goes.
## - Unlock zones: the generator lays a band of Gate Rock (DepthGate rows) over each layer
##   boundary. Signs in the band show the picture of what opens it (glowing gold once someone has
##   earned it). A dig into a band you cannot break yet, a vehicle-only block on foot, or a block
##   too hard for your vehicle bonks (`dig_blocked`, sparks) and pops that picture over your head.
## Underground adds one as a child of the TileWorld; HillPlayer finds it with DigFeel.of(world).
## Without one (bare test worlds) the player digs the old way: one hit, any shovel-tier block.
class_name DigFeel
extends Node2D

const SIGN_EVERY := 14              # columns between signs in a band
const SIGN_NEAR := Vector2i(44, 26) # signs are drawn this near (cells) to a player
const SIGN_SIZE := 30.0
const CRACK := Color(0.1, 0.07, 0.12, 0.85)
const GOLD := Color("ffd23f")
const POP_TIME := 0.32
## The scripted --demo and the older lanes' beats (HillGame sets it): bands and Hard Rock break
## like any block (tier rules only), so their timelines still play. Never set in play or tests.
static var demo_open := false

## Underground (untyped so tests can hand in a stand-in with world / generator / story).
var u: Node
var world: TileWorld
var generator: HillGenerator
var tuning: DigTuning
## cell -> hit points taken so far.
var damage := {}
var _flash := {}
var _pops: Array = []   # [{pos: Vector2, t: float, color: Color}]
var _sign_pop := {}     # gate id -> 1..0 (a sign wiggles after a bonk on its band)
var _t := 0.0


static func of(w: TileWorld) -> DigFeel:
	return w.get_node_or_null(^"DigFeel") as DigFeel if w != null else null


func setup(p_u: Node) -> void:
	u = p_u
	world = u.world
	generator = u.generator
	tuning = DigTuning.instant() if demo_open else DigTuning.get_default()
	name = "DigFeel"
	z_index = 4
	if not world.tile_dug.is_connected(_on_tile_dug):
		world.tile_dug.connect(_on_tile_dug)


func _on_tile_dug(cell: Vector2i, _block: StringName, _p: int) -> void:
	damage.erase(cell)
	_flash.erase(cell)


# --- rules -------------------------------------------------------------------------------------

func block_at(cell: Vector2i) -> BlockData:
	return world.tile_def(world.get_tile(cell)) as BlockData


## The DepthGate whose band holds `cell`, or null.
func gate_at(cell: Vector2i) -> DepthGate:
	if generator == null:
		return null
	var b := generator.gate_band_at(cell.y)
	return b.get("gate") as DepthGate


## True when someone has earned what opens `g` (the signs glow gold): its treasure or resident,
## a Workshop level, or an unlocked vehicle strong enough.
func gate_earned(g: DepthGate) -> bool:
	if _opened_for_all(g):
		return true
	if g.shovel_level > 0 and Progress.tool_level() >= g.shovel_level:
		return true
	if g.vehicle_tier > 0:
		for v: VehicleData in Progress.vehicle_rows():
			if Progress.has_vehicle(v.id) and v.dig_tier >= g.vehicle_tier:
				return true
	return false


func _opened_for_all(g: DepthGate) -> bool:
	if g.treasure != &"" and Progress.has_treasure(g.treasure):
		return true
	var story: Variant = u.get("story") if u != null else null
	return g.resident != &"" and story != null and bool(story.arrived(g.resident))


## True when `pl` (as it is now: on foot with its Workshop level, or in its vehicle) breaks `g`.
func gate_open_for(pl: HillPlayer, g: DepthGate) -> bool:
	if _opened_for_all(g):
		return true
	if pl.vehicle != null:
		return g.vehicle_tier > 0 and pl.vehicle.dig_tier >= g.vehicle_tier
	return g.shovel_level > 0 and pl.tool_level() >= g.shovel_level


## True when `pl` can break the block at `cell` right now.
func can_break(pl: HillPlayer, cell: Vector2i, def: BlockData) -> bool:
	if def == null:
		return true
	if not def.breakable:
		return true   # TileWorld bonks it itself (dig_blocked)
	if demo_open:
		return def.dig_tier <= (pl.vehicle.dig_tier if pl.vehicle != null else 0)
	if def.id == &"gaterock":
		var g := gate_at(cell)
		return g == null or gate_open_for(pl, g)
	if pl.vehicle == null:
		return not def.vehicle_only and def.dig_tier <= 0
	return pl.vehicle.dig_tier >= def.dig_tier


## The picture of what breaks the block at `cell` (the bonk bubble and the hint panel).
func need_picture(cell: Vector2i, def: BlockData) -> StringName:
	if def != null and def.id == &"gaterock":
		var g := gate_at(cell)
		return g.picture if g != null else &"question"
	var want := def.dig_tier if def != null else 0
	for v: VehicleData in Progress.vehicle_rows():
		if v.dig_tier >= want:
			return StringName("vehicle:%s" % v.id)
	return &"question"


func power_of(pl: HillPlayer) -> int:
	return tuning.power_for(pl.tool_level(), pl.vehicle.dig_tier if pl.vehicle != null else -1)


func every_of(pl: HillPlayer) -> float:
	return tuning.every_for(pl.tool_level(), pl.vehicle.dig_tier if pl.vehicle != null else -1)


# --- hits --------------------------------------------------------------------------------------

## One hit by `pl` on `cells` (all breakable by it). Returns the cells that break now; the rest
## crack. Plays the hit or the pop.
func hit(pl: HillPlayer, cells: Array[Vector2i]) -> Array[Vector2i]:
	var broke: Array[Vector2i] = []
	var power := power_of(pl)
	var cracked := 0
	var cue := ""
	for c in cells:
		var def := block_at(c)
		var tough := def.toughness if def != null else 1
		var dmg: int = int(damage.get(c, 0)) + power
		var center := world.shape.center_of(c)
		if dmg >= tough:
			broke.append(c)
			damage.erase(c)
			_pops.append({"pos": center, "t": 0.0, "color": def.color if def != null else Color.WHITE})
		else:
			damage[c] = dmg
			_flash[c] = 1.0
			cracked += 1
			if u != null and u.has_method("burst"):
				u.burst(center, def.color.lightened(0.15) if def != null else Color.WHITE, tuning.crumbs, 70.0)
			if def != null and cue == "":
				cue = String(def.dig_sound) if def.dig_sound != &"" else "dig_%s" % def.id
	if not broke.is_empty():
		Audio.play("pop")
	elif cracked > 0 and cue != "":
		Audio.play(cue, null, -7.0)
	queue_redraw()
	return broke


## A dig at `cell` that `pl` cannot break: a bonk, sparks, and the picture of what would.
func bonk(pl: HillPlayer, cell: Vector2i) -> void:
	var def := block_at(cell)
	Audio.play("dig_blocked")
	if u != null and u.has_method("burst"):
		u.burst(world.shape.center_of(cell), Color(1.0, 0.92, 0.6), 8, 90.0)
	_flash[cell] = 1.0
	pl.show_need(need_picture(cell, def))
	var g := gate_at(cell) if def != null and def.id == &"gaterock" else null
	if g != null:
		_sign_pop[g.id] = 1.0
	queue_redraw()


## Stage 0..1 of the crack at `cell` (tests, beats).
func crack_of(cell: Vector2i) -> float:
	var def := block_at(cell)
	if def == null or not damage.has(cell):
		return 0.0
	return float(damage[cell]) / float(maxi(def.toughness, 1))


# --- drawing -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	for c in _flash.keys():
		_flash[c] = float(_flash[c]) - delta * 6.0
		if _flash[c] <= 0.0:
			_flash.erase(c)
	for p: Dictionary in _pops:
		p.t += delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return p.t < POP_TIME)
	for k in _sign_pop.keys():
		_sign_pop[k] = float(_sign_pop[k]) - delta * 1.5
		if _sign_pop[k] <= 0.0:
			_sign_pop.erase(k)
	queue_redraw()


func _draw() -> void:
	var cs := float(world.shape.cell_size)
	for c: Vector2i in damage:
		_draw_crack(c, crack_of(c), cs)
	for c: Vector2i in _flash:
		draw_rect(Rect2(Vector2(c) * cs, Vector2(cs, cs)), Color(1, 1, 1, 0.45 * float(_flash[c])))
	for p: Dictionary in _pops:
		var k: float = p.t / POP_TIME
		var r := 4.0 + 14.0 * k
		draw_arc(p.pos, r, 0.0, TAU, 20, Color(1, 1, 0.9, 1.0 - k), 3.0 * (1.0 - k) + 1.0)
		for i in 4:
			var d := Vector2.from_angle(i * TAU / 4.0 + 0.4) * (6.0 + 16.0 * k)
			draw_circle(p.pos + d, 2.5 * (1.0 - k), Color((p.color as Color).lightened(0.4), 1.0 - k))
	_draw_signs(cs)


func _draw_crack(c: Vector2i, stage: float, cs: float) -> void:
	if stage <= 0.0:
		return
	var o := Vector2(c) * cs
	var h := absi(c.x * 92821 + c.y * 68917)
	var mid := o + Vector2(cs * 0.5 + float(h % 3) - 1.0, cs * 0.5 + float(h / 3 % 3) - 1.0)
	# Chunky: 2 branches on the first hit, up to 5 near breaking; each a dark gash with a lit edge.
	var n := 2 + int(stage * 3.5)
	var lit := Color(1, 0.95, 0.85, 0.55)
	for i in n:
		var a := float((h >> (i * 3)) % 8) * TAU / 8.0 + i * 2.1
		var p1 := mid + Vector2.from_angle(a) * cs * (0.3 + 0.12 * stage)
		var p2 := p1 + Vector2.from_angle(a + (0.7 if i % 2 else -0.7)) * cs * (0.18 + 0.12 * stage)
		draw_line(mid + Vector2(0.8, 0.8), p1 + Vector2(0.8, 0.8), lit, 1.2)
		draw_line(mid, p1, CRACK, 2.6)
		draw_line(p1, p2, CRACK, 2.0)
	draw_circle(mid, 1.6 + stage * 1.6, CRACK)
	if stage > 0.6:
		# Nearly gone: chips knocked out of two corners.
		var k := cs * 0.22
		draw_colored_polygon(PackedVector2Array([o, o + Vector2(k, 0), o + Vector2(0, k)]), Color(CRACK, 0.9))
		var e := o + Vector2(cs, cs)
		draw_colored_polygon(PackedVector2Array([e, e - Vector2(k, 0), e - Vector2(0, k)]), Color(CRACK, 0.9))


## The band's signs near any player: a plate with the picture of what opens it. Glowing gold
## with sparkles once earned; a bonk makes the nearest ones wiggle.
func _draw_signs(cs: float) -> void:
	if generator == null or generator.gate_bands.is_empty():
		return
	var near: Array[Vector2i] = []
	var root: Node = u.get("players_root") if u != null else null
	if root == null:
		return
	for n in root.get_children():
		var pl := n as HillPlayer
		if pl != null and pl.world == world:
			near.append(world.shape.cell_at(world.to_local(pl.global_position)))
	for b: Dictionary in generator.gate_bands:
		var g: DepthGate = b.gate
		var row_mid := (float(b.from) + float(b.to)) * 0.5 * cs
		var earned := gate_earned(g)
		var wig: float = _sign_pop.get(g.id, 0.0)
		for at in near:
			if absi(at.y - b.from) > SIGN_NEAR.y:
				continue
			var x0 := (at.x - SIGN_NEAR.x) / SIGN_EVERY * SIGN_EVERY
			for x in range(x0, at.x + SIGN_NEAR.x, SIGN_EVERY):
				if x < HillGenerator.EDGE + 2 or x > HillGenerator.WIDTH - HillGenerator.EDGE - 3:
					continue
				var cell := Vector2i(x, int(b.from) + 1)
				if not world.is_solid(cell) or block_at(cell) == null or block_at(cell).id != &"gaterock":
					continue
				var c := Vector2(x * cs + cs * 0.5, row_mid)
				draw_sign(self, c, g.picture, earned, _t + x * 0.37, wig)


## One sign plate (also used by beats and tests for a look at it).
static func draw_sign(ci: CanvasItem, c: Vector2, pic: StringName, earned: bool, t: float, wig := 0.0) -> void:
	var s := SIGN_SIZE * (1.0 + 0.18 * sin(wig * PI))
	c += Vector2(sin(t * 18.0) * 2.5 * wig, 0.0)
	if earned:
		c.y += sin(t * 2.6) * 1.2
		ci.draw_circle(c, s * 0.62 + 2.0 + sin(t * 4.0), Color(GOLD, 0.35))
	var r := Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s))
	PictoBubble._round_rect(ci, r.grow(2.0), 6.0, Color(PictoBubble.OUTLINE))
	PictoBubble._round_rect(ci, r, 5.0, GOLD if earned else Color("cfc6dc"))
	PictoBubble._round_rect(ci, r.grow(-3.0), 4.0, Color(PictoBubble.PAPER))
	draw_picture(ci, pic, c, s - 8.0)
	if earned:
		for i in 3:
			var a := t * 1.3 + i * TAU / 3.0
			var p := c + Vector2.from_angle(a) * s * 0.62
			var k := 0.5 + 0.5 * sin(t * 5.0 + i)
			ci.draw_line(p - Vector2(3, 0) * k, p + Vector2(3, 0) * k, Color(1, 1, 0.8, k), 1.5)
			ci.draw_line(p - Vector2(0, 3) * k, p + Vector2(0, 3) * k, Color(1, 1, 0.8, k), 1.5)


## PictoBubble pictures plus the dig lane's: &"shovel_gold" (the Workshop's bigger shovel, gold)
## and &"treasure:<id>" (that treasure's sprite).
static func draw_picture(ci: CanvasItem, pic: StringName, c: Vector2, s: float, a := 1.0) -> void:
	var sid := String(pic)
	if sid.begins_with("treasure:"):
		PictoBubble._sprite(ci, "treasures/%s.png" % sid.get_slice(":", 1), c, s, a)
	elif pic == &"shovel_gold":
		_gold_shovel(ci, c, s, a)
	else:
		PictoBubble.picture(ci, pic, c, s, a)


## The pictures the hint panel may show on A after a bonk (ButtonHints icon ids "need:<pic>").
static func need_pictures() -> Array[StringName]:
	var out: Array[StringName] = [&"shovel_gold", &"hardhat", &"question", &"treasure:dragon_egg"]
	for id in [&"front_loader", &"excavator", &"dump_truck", &"crane", &"drill_rig"]:
		out.append(StringName("vehicle:%s" % id))
	return out


## ButtonHints icon for "A needs this": the picture on a gold disc.
static func draw_need_icon(ci: CanvasItem, r: Rect2, a: float, pic: StringName) -> void:
	var c := r.get_center()
	ci.draw_circle(c, r.size.x * 0.52, Color(GOLD, 0.5 * a))
	draw_picture(ci, pic, c, r.size.x * 0.95, a)


## The Workshop's bigger shovel: a wide gold blade on a short handle, with a sparkle.
static func _gold_shovel(ci: CanvasItem, c: Vector2, s: float, a: float) -> void:
	var u := s / 22.0
	var ol := Color(PictoBubble.OUTLINE, a)
	ci.draw_line(c + Vector2(8, -9) * u, c + Vector2(-1, 1) * u, ol, 4.5 * u)
	ci.draw_line(c + Vector2(8, -9) * u, c + Vector2(-1, 1) * u, Color("a47148", a), 2.5 * u)
	ci.draw_line(c + Vector2(5, -11) * u, c + Vector2(11, -7) * u, ol, 3.5 * u)
	var blade := PackedVector2Array([c + Vector2(0, -1) * u, c + Vector2(-9, 2) * u, c + Vector2(-10, 9) * u,
			c + Vector2(-4, 10) * u, c + Vector2(3, 3) * u])
	var out := PackedVector2Array()
	for p in blade:
		out.append(c + (p - c) * 1.18 + Vector2(-0.6, 0.6) * u)
	ci.draw_colored_polygon(out, ol)
	ci.draw_colored_polygon(blade, Color(GOLD, a))
	ci.draw_line(c + Vector2(-7, 3) * u, c + Vector2(-8, 7) * u, Color(1, 1, 0.85, a), 1.5 * u)
	var sp := c + Vector2(6, 6) * u
	ci.draw_line(sp - Vector2(3, 0) * u, sp + Vector2(3, 0) * u, Color(GOLD, a), 1.5 * u)
	ci.draw_line(sp - Vector2(0, 3) * u, sp + Vector2(0, 3) * u, Color(GOLD, a), 1.5 * u)
