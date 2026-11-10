## A parked vehicle (VehicleData), drawn from assets/sprites/vehicles (no face; lamps via VehicleGlow).
## The Front Loader has a bucket, the Excavator a cab and an arm; an id without art is a plain box. Origin at the wheels'
## contact point (feet). While someone drives it, this node is out of the tree and the HillPlayer
## draws itself with draw_vehicle() and uses body_size() for its collision; on hop-out it comes back.
## No collision: players walk through a parked vehicle (B next to it hops in).
class_name Vehicle
extends Node2D

const DARK := Color(0.07, 0.06, 0.09)
const COLORS := {&"front_loader": Color("f2b134"), &"excavator": Color("f2994a")}
const SIZES := {&"front_loader": Vector2(28, 26), &"excavator": Vector2(40, 40)}

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
	var cf := "characters/%s.png" % SpriteArt.char_of(who)
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
## moving: the drive frames. Ids without art keep a plain box.
static func draw_vehicle(ci: CanvasItem, d: VehicleData, face: int, driver: Color, tip: float, aim: float,
		t := 0.0, moving := false, who := -2) -> void:
	var id: StringName = d.id if d else &""
	var file := "vehicles/%s.png" % id
	if not SpriteArt.has(file):
		_draw_box(ci, d, face)
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
		var cf := "characters/%s.png" % SpriteArt.char_of(who)
		var rr := SpriteArt.row(cf, "ride")
		if not rr.is_empty():
			SpriteArt.draw(ci, cf, 0, int(rr.row), head * f, flip)
	SpriteArt.draw(ci, file, col, int(body_row.get("row", 0)), Vector2.ZERO, flip)
	# Bucket or arm over the body.
	var tf := tool_frame(tip, aim)
	if id == &"front_loader":
		SpriteArt.draw(ci, "vehicles/front_loader_bucket.png", tf, 0, SpriteArt.point(file, "bucket") * f, flip)
	elif id == &"excavator":
		SpriteArt.draw(ci, "vehicles/excavator_arm.png", tf, 0, SpriteArt.point(file, "arm") * f, flip)


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
