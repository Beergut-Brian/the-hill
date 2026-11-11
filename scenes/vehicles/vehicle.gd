## A parked vehicle (VehicleData), drawn from assets/sprites/vehicles (no face; lamps via VehicleGlow).
## The Front Loader has a bucket, the Excavator a cab and an arm; an id without art is a plain box. Origin at the wheels'
## contact point (feet). While someone drives it, this node is out of the tree and the HillPlayer
## draws itself with draw_vehicle() and uses body_size() for its collision; on hop-out it comes back.
## No collision: players walk through a parked vehicle (B next to it hops in).
class_name Vehicle
extends Node2D

const DARK := Color(0.07, 0.06, 0.09)
const COLORS := {&"front_loader": Color("f2b134"), &"excavator": Color("f2994a"), &"dump_truck": Color("3f86e0"),
		&"crane": Color("1fbfb0"), &"drill_rig": Color("8a5cd6")}
const SIZES := {&"front_loader": Vector2(28, 26), &"excavator": Vector2(40, 40), &"dump_truck": Vector2(50, 32),
		&"crane": Vector2(44, 38), &"drill_rig": Vector2(56, 48)}
## Crane rope length (px below the boom tip) at rest.
const ROPE := 12.0

var data: VehicleData
var facing := 1
## 0..1: the bucket tips forward (P2 tumbling out, a scoop).
var bucket_tip := 0.0:
	set(v):
		bucket_tip = v
		queue_redraw()
## A sleeping player drawn in the bucket (-1: nobody). Front Loader only.
var sleeper := -1:
	set(v):
		sleeper = v
		queue_redraw()

var _t := 0.0


static func body_size(d: VehicleData) -> Vector2:
	if d == null:
		return Vector2(12, 28)
	return SIZES.get(d.id, Vector2(32, 28))


func _ready() -> void:
	name = "Vehicle_%s" % (data.id if data else &"none")
	z_index = 1
	VehicleGlow.attach(self)


func _process(delta: float) -> void:
	if sleeper >= 0:
		_t += delta
		queue_redraw()


func _draw() -> void:
	draw_vehicle(self, data, facing, Color(0, 0, 0, 0), bucket_tip, 0.0, _t)
	if sleeper >= 0:
		_draw_sleeper()


func _draw_sleeper() -> void:
	draw_sleeper(self, data, facing, sleeper, bucket_tip, _t)


## A sleeping figure in the bucket (that player's `sleep` frames), with "z z" puffs drawn as shapes.
static func draw_sleeper(ci: CanvasItem, d: VehicleData, face: int, who: int, tip: float, t: float) -> void:
	var file := "vehicles/%s.png" % (d.id if d else &"")
	var bucket := SpriteArt.point(file, "bucket", Vector2(face * 22, -12)) * Vector2(face, 1)
	var cf := SpriteArt.char_file(who)
	var sr := SpriteArt.row(cf, "sleep")
	if not sr.is_empty():
		# Lying in the bucket; a tipped bucket tips her out a little.
		var at := bucket + Vector2(face * 2.0, -2.0 + tip * 4.0)
		SpriteArt.draw(ci, cf, SpriteArt.frame_at(cf, "sleep", t), int(sr.row), at, face < 0)
	if tip > 0.0:
		return
	# Zs as little zig-zag polylines drifting up.
	for k in 2:
		var ph := fmod(t * 0.6 + k * 0.5, 1.0)
		var p := bucket + Vector2(-4 * face + ph * 10.0 * face, -26.0 - ph * 18.0)
		var z := 2.0 + k * 1.5
		var col := Color(1, 1, 1, 1.0 - ph)
		ci.draw_polyline(PackedVector2Array([p + Vector2(-z, -z), p + Vector2(z, -z), p + Vector2(-z, z), p + Vector2(z, z)]), col, 1.5)


## The sheet row of the driver: cream (nobody), green (P1), red (P2).
static func row_name(who: int) -> String:
	return "green" if who == 0 else ("red" if who == 1 else "cream")


## Which player a driver tint belongs to (-1: transparent / unknown).
static func who_of(driver: Color) -> int:
	if driver.a <= 0.0:
		return -1
	for p in [0, 1]:
		if Players.COLOR.get(p, Color.WHITE).is_equal_approx(driver):
			return p
	return -1


## The bucket / arm frame (0 rest, 1 mid, 2 full) for the tip (0..1) and aim (-1 up .. 1 down).
static func tool_frame(tip: float, aim: float) -> int:
	var v := tip - aim * 0.5
	return 2 if v > 0.6 else (1 if v > 0.2 else 0)


## Draws a vehicle at the canvas item's origin (wheels on y = 0) from the sprite sheets. driver:
## the driver's tint (transparent: empty; picks the green / red body row and ride head; `who`
## overrides). aim: -1 up .. 1 down, raises the bucket or arm. t: seconds (idle bob, wheels);
## moving: the drive frames. state: VehicleAbility.draw_state() (bed, load, hook, reach, spin).
## Ids without art keep a plain box.
static func draw_vehicle(ci: CanvasItem, d: VehicleData, face: int, driver: Color, tip: float, aim: float,
		t := 0.0, moving := false, who := -2, state := {}) -> void:
	var id: StringName = d.id if d else &""
	var file := "vehicles/%s.png" % id
	if not SpriteArt.has(file):
		_draw_box(ci, d, face)
		_draw_tools_box(ci, d, face, state, t)
		return
	if who == -2:
		who = who_of(driver)
	var flip := face < 0
	var f := Vector2(face, 1)
	var fs := SpriteArt.frame_size(file)
	var piv := SpriteArt.pivot(file)
	var body_row := SpriteArt.row(file, row_name(who))
	var cols: Dictionary = SheetSprite.entry(file).get("columns", {})
	var span: Array = cols.get("drive" if moving else "idle", [0, 1])
	var col: int = int(span[0]) + int(t * float(body_row.get("fps", 2))) % (int(span[1]) - int(span[0]) + 1)
	# The driver's head first, behind the glass.
	if who >= 0:
		var head := SpriteArt.point(file, "head")
		var cf := SpriteArt.char_file(who)
		var rr := SpriteArt.row(cf, "ride")
		if not rr.is_empty():
			SpriteArt.draw(ci, cf, 0, int(rr.row), head * f, flip)
	var smoky := who >= 0 and id != &"crane"
	if smoky:
		_draw_exhaust(ci, id, Vector2(fs), piv, face, t, moving, true)
	SpriteArt.draw(ci, file, col, int(body_row.get("row", 0)), Vector2.ZERO, flip)
	if smoky:
		_draw_exhaust(ci, id, Vector2(fs), piv, face, t, moving, false)
	# Bucket or arm over the body.
	var tf := tool_frame(tip, aim)
	if id == &"front_loader":
		SpriteArt.draw(ci, "vehicles/front_loader_bucket.png", tf, 0, SpriteArt.point(file, "bucket") * f, flip)
	elif id == &"excavator":
		SpriteArt.draw(ci, "vehicles/excavator_arm.png", tf, 0, SpriteArt.point(file, "arm") * f, flip)
	elif id == &"dump_truck":
		_draw_bed(ci, file, f, flip, state)
	elif id == &"crane":
		_draw_crane(ci, file, f, flip, aim, state, t)
	elif id == &"drill_rig":
		var spin := float(state.get("spin", 0.0))
		var bf := int(t * 14.0 * spin * 2.0) % 4 if spin > 0.05 else 0
		var shake := Vector2(0, sin(t * 60.0)) * spin
		SpriteArt.draw(ci, "vehicles/drill_rig_bit.png", bf, 0, (SpriteArt.point(file, "bit") + shake) * f, flip)


## H-11: while someone drives, the vehicle's exhaust stack puffs smoke: slow round puffs idling,
## quicker ones streaming back while it rolls. Stateless (a function of t), shapes only.
const EXHAUST_IDLE := 1.6
const EXHAUST_DRIVE := 4.0
const SMOKE := Color(0.97, 0.96, 0.92)
const SMOKE_EDGE := Color(0.23, 0.16, 0.27, 0.45)
## Top of the stack in each sprite, from the pivot, facing right (read off the sheets). Ids marked
## in STACK_DRAWN have no stack in their art, so a small one is drawn behind the body.
const EXHAUST_AT := {
	&"front_loader": Vector2(4.5, -31), &"excavator": Vector2(3, -35),
	&"dump_truck": Vector2(3, -30), &"drill_rig": Vector2(-4.5, -49),
}
const STACK_DRAWN := [&"dump_truck"]


static func exhaust_point(id: StringName, fs: Vector2, piv: Vector2, face: int) -> Vector2:
	var at: Vector2 = EXHAUST_AT.get(id, Vector2(-piv.x + 7.0, -fs.y * 0.62))
	return Vector2(at.x * face, at.y)


static func exhaust_rate(moving: bool) -> float:
	return EXHAUST_DRIVE if moving else EXHAUST_IDLE


static func _draw_exhaust(ci: CanvasItem, id: StringName, fs: Vector2, piv: Vector2, face: int, t: float, moving: bool, stack: bool) -> void:
	var top := exhaust_point(id, fs, piv, face)
	if not stack:
		_draw_puffs(ci, top, face, t, moving)
		return
	if not EXHAUST_AT.has(id) or STACK_DRAWN.has(id):
		ci.draw_rect(Rect2(top + Vector2(-2.5, 0), Vector2(5, 9)), Color(0.23, 0.16, 0.27))
		ci.draw_rect(Rect2(top + Vector2(-1.5, 1), Vector2(3, 8)), Color(0.49, 0.52, 0.62))


static func _draw_puffs(ci: CanvasItem, top: Vector2, face: int, t: float, moving: bool) -> void:
	var rate := exhaust_rate(moving)
	for k in 3:
		var ph := fposmod(t * rate / 3.0 + k / 3.0, 1.0)
		var drift := Vector2(-face * (2.0 + (20.0 if moving else 4.0)) * ph, -18.0 * ph - 2.0)
		var r := 2.5 + 4.5 * ph
		var a := 1.0 - ph * ph
		ci.draw_circle(top + drift, r + 1.0, Color(SMOKE_EDGE, SMOKE_EDGE.a * a))
		ci.draw_circle(top + drift, r, Color(SMOKE, 0.95 * a))


## The Dump Truck's bed (tipping about its hinge) and the heap in it.
static func _draw_bed(ci: CanvasItem, file: String, f: Vector2, flip: bool, state: Dictionary) -> void:
	var at := SpriteArt.point(file, "bed") * f
	var b := float(state.get("bed", 0.0))
	var bf := 0 if b < 0.2 else (1 if b < 0.65 else 2)
	if bf == 0 and float(state.get("load", 0.0)) > 0.0:
		var l := float(state.load)
		SpriteArt.draw(ci, "vehicles/dump_truck_load.png", 0 if l < 0.4 else (1 if l < 0.8 else 2), 0, at, flip)
	SpriteArt.draw(ci, "vehicles/dump_truck_bed.png", bf, 0, at, flip)


## The Crane's boom (frame from the aim), rope and hook; while hauling, the hook reaches for the
## boulder (state.hook, vehicle-local) and brings it up.
static func _draw_crane(ci: CanvasItem, file: String, f: Vector2, flip: bool, aim: float, state: Dictionary, t: float) -> void:
	var boom_file := "vehicles/crane_boom.png"
	var root := SpriteArt.point(file, "boom") * f
	var bf := 2 if aim < -0.3 else (0 if aim > 0.3 else 1)
	SpriteArt.draw(ci, boom_file, bf, 0, root, flip)
	var tips: Array = SheetSprite.entry(boom_file).get("tips", [])
	var tip := root + Vector2(0, -30)
	if bf < tips.size():
		tip = root + (Vector2(tips[bf][0], tips[bf][1]) - SpriteArt.pivot(boom_file)) * f
	if state.has("ball"):
		_draw_ball(ci, tip, float(state.ball), int(state.get("face", -1 if flip else 1)))
		return
	if state.has("lift"):
		_draw_lift(ci, tip, state.lift)
		return
	var hook := tip + Vector2(sin(t * 1.7) * 1.5, ROPE)
	var carry := false
	if state.has("hook"):
		var target: Vector2 = state.hook
		hook = tip.lerp(target, float(state.get("reach", 0.0)))
		carry = true
		if not bool(state.get("carry", false)):
			_draw_boulder(ci, target)
			carry = false
	ci.draw_line(tip, hook, Color(0.2, 0.18, 0.2), 1.0)
	if carry:
		_draw_boulder(ci, hook + Vector2(0, 14))
	SpriteArt.draw(ci, "vehicles/crane_hook.png", 0, 0, hook, flip)


## H-05: up top the Crane's rope carries a wrecking ball; `a` is the swing (+ = toward `face`).
static func _draw_ball(ci: CanvasItem, tip: Vector2, a: float, face: int) -> void:
	var at := tip + Vector2(sin(a) * face, cos(a)) * VehicleAbility.BALL_ROPE
	ci.draw_line(tip, at, Color(0.2, 0.18, 0.2), 1.5)
	ci.draw_circle(at, 9.5, DARK)
	ci.draw_circle(at, 8.0, Color("5d6670"))
	ci.draw_circle(at + Vector2(-2.5, -2.5), 3.0, Color("8d97a3"))
	ci.draw_rect(Rect2(at + Vector2(-2, -11), Vector2(4, 3)), DARK)


## H-05: lifting a building: the boom telescopes up past the roof, the rope drops to the hook on it.
static func _draw_lift(ci: CanvasItem, tip: Vector2, roof: Vector2) -> void:
	var top := Vector2(roof.x, minf(roof.y - 22.0, tip.y - 10.0))
	ci.draw_line(tip, top, DARK, 6.0)
	ci.draw_line(tip, top, Color("f2c94c"), 3.5)
	ci.draw_circle(top, 3.5, DARK)
	ci.draw_line(top, roof, Color(0.2, 0.18, 0.2), 1.5)
	ci.draw_rect(Rect2(roof + Vector2(-4, -5), Vector2(8, 6)), Color("c9ccd1"))
	ci.draw_rect(Rect2(roof + Vector2(-4, -5), Vector2(8, 6)), DARK, false, 1.0)


static func _draw_boulder(ci: CanvasItem, at: Vector2) -> void:
	if SpriteArt.has("props/boulder.png"):
		SpriteArt.draw(ci, "props/boulder.png", 0, 0, at)
	else:
		ci.draw_circle(at, 12.0, Color(0.62, 0.58, 0.54))


## Tools for an id without art (tests, missing sheets): a box bed, a line boom, a bit.
static func _draw_tools_box(ci: CanvasItem, d: VehicleData, face: int, state: Dictionary, t: float) -> void:
	if d == null:
		return
	var s := body_size(d)
	match d.id:
		&"dump_truck":
			var b := float(state.get("bed", 0.0))
			var hinge := Vector2(-face * s.x * 0.45, -s.y + 6)
			var a := -b * 0.9 * face
			var w := Vector2(face * s.x * 0.55, 0).rotated(a)
			var h := Vector2(0, -10).rotated(a)
			ci.draw_colored_polygon(PackedVector2Array([hinge, hinge + w, hinge + w + h, hinge + h]), Color("5d6670"))
		&"crane":
			var root := Vector2(face * 6, -s.y + 6)
			var tip := root + Vector2(face * 34, -30)
			ci.draw_line(root, tip, Color("f2c94c"), 3.0)
			var hook := tip + Vector2(0, ROPE)
			if state.has("hook"):
				hook = tip.lerp(state.hook, float(state.get("reach", 0.0)))
			ci.draw_line(tip, hook, DARK, 1.0)
			ci.draw_rect(Rect2(hook - Vector2(3, 0), Vector2(6, 6)), Color("c9ccd1"))
		&"drill_rig":
			var x := face * s.x * 0.4
			var k := float(state.get("spin", 0.0))
			for i in 4:
				var y := -4.0 + i * 3.0
				var off := sin(t * 30.0 * k + i) * 3.0
				ci.draw_line(Vector2(x - 4 + off, y), Vector2(x + 4 - off, y + 2), Color("c9ccd1"), 2.0)


## A plain box for a vehicle id without art.
static func _draw_box(ci: CanvasItem, d: VehicleData, face: int) -> void:
	var s := body_size(d)
	var hw := s.x * 0.5
	var col: Color = COLORS.get(d.id if d else &"", Color("c8c8c8"))
	var body := Rect2(-hw, -s.y + 6, s.x, s.y - 12)
	ci.draw_rect(body.grow(1.5), DARK)
	ci.draw_rect(body, col)
	for wx in [-hw + 6.0, hw - 6.0]:
		ci.draw_circle(Vector2(wx, -6), 7.5, DARK)
		ci.draw_circle(Vector2(wx, -6), 6.0, Color(0.2, 0.2, 0.22))
