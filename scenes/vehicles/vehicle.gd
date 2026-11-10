## A parked vehicle (VehicleData): a placeholder box with wheels, no face. The Front Loader has a
## bucket, the Excavator a cab and an arm; anything else is a plain box. Origin at the wheels'
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


func _process(delta: float) -> void:
	if sleeper >= 0:
		_t += delta
		queue_redraw()


func _draw() -> void:
	draw_vehicle(self, data, facing, Color(0, 0, 0, 0), bucket_tip, 0.0)
	if sleeper >= 0:
		_draw_sleeper()


func _draw_sleeper() -> void:
	draw_sleeper(self, data, facing, sleeper, bucket_tip, _t)


## A sleeping figure curled in the bucket, with "z z" puffs drawn as shapes (no text).
static func draw_sleeper(ci: CanvasItem, d: VehicleData, face: int, who: int, tip: float, t: float) -> void:
	var s := body_size(d)
	var c: Color = Players.COLOR.get(who, Color.WHITE)
	var bucket := Vector2(face * (s.x * 0.5 + 8.0), -9.0)
	ci.draw_set_transform(bucket, tip * 0.9 * face, Vector2.ONE)
	ci.draw_rect(Rect2(-8, -10, 16, 8), DARK)
	ci.draw_rect(Rect2(-7, -9, 14, 6), c)
	ci.draw_circle(Vector2(-6 * face, -8), 5.0, DARK)
	ci.draw_circle(Vector2(-6 * face, -8), 4.0, c)
	ci.draw_rect(Rect2(-6 * face - 4, -13, 8, 3), Color("f2c94c"))
	ci.draw_set_transform(Vector2.ZERO)
	if tip > 0.0:
		return
	# Zs as little zig-zag polylines drifting up.
	for k in 2:
		var ph := fmod(t * 0.6 + k * 0.5, 1.0)
		var p := bucket + Vector2(-4 * face + ph * 10.0 * face, -18.0 - ph * 18.0)
		var z := 3.0 + k * 1.5
		var col := Color(1, 1, 1, 1.0 - ph)
		ci.draw_polyline(PackedVector2Array([p + Vector2(-z, -z), p + Vector2(z, -z), p + Vector2(-z, z), p + Vector2(z, z)]), col, 1.5)


## Draws a vehicle at the canvas item's origin (wheels on y = 0). driver: the cab window tint
## (transparent: empty). aim: -1 up .. 1 down, tilts the bucket or arm.
static func draw_vehicle(ci: CanvasItem, d: VehicleData, face: int, driver: Color, tip: float, aim: float) -> void:
	var id: StringName = d.id if d else &""
	var s := body_size(d)
	var col: Color = COLORS.get(id, Color("c8c8c8"))
	var hw := s.x * 0.5
	var wheel_r := 6.0 if s.x < 36 else 7.0
	# Body.
	var body := Rect2(-hw, -s.y + 6, s.x, s.y - 6 - wheel_r)
	if id == &"excavator":
		body = Rect2(-hw, -s.y * 0.55, s.x, s.y * 0.55 - wheel_r)
	ci.draw_rect(body.grow(1.5), DARK)
	ci.draw_rect(body, col)
	ci.draw_rect(Rect2(body.position.x, body.end.y - 3, body.size.x, 3), col.darkened(0.3))
	# Cab with a window; the driver shows as a coloured block in it.
	var cab := Rect2(-hw + 3 if face > 0 else hw - 15, -s.y, 12, 10)
	if id == &"excavator":
		cab = Rect2(-8 - 4 * face, -s.y, 16, s.y * 0.45)
	ci.draw_rect(cab.grow(1.5), DARK)
	ci.draw_rect(cab, col.lightened(0.15))
	var win := cab.grow(-2.5)
	ci.draw_rect(win, Color(0.55, 0.8, 0.95))
	if driver.a > 0.0:
		ci.draw_rect(Rect2(win.get_center() - Vector2(3, 2), Vector2(6, 6)), driver)
		ci.draw_rect(Rect2(win.get_center() - Vector2(4, 4), Vector2(8, 2)), Color("f2c94c"))
	# Wheels (or a track for the Excavator).
	if id == &"excavator":
		var tr := Rect2(-hw, -wheel_r * 2, s.x, wheel_r * 2)
		ci.draw_rect(tr.grow(1), DARK)
		ci.draw_rect(tr, Color(0.25, 0.25, 0.28))
		for k in 4:
			ci.draw_circle(Vector2(-hw + wheel_r + k * (s.x - wheel_r * 2) / 3.0, -wheel_r), wheel_r * 0.5, Color(0.5, 0.5, 0.55))
	else:
		for wx in [-hw + wheel_r, hw - wheel_r]:
			ci.draw_circle(Vector2(wx, -wheel_r), wheel_r + 1.5, DARK)
			ci.draw_circle(Vector2(wx, -wheel_r), wheel_r, Color(0.2, 0.2, 0.22))
			ci.draw_circle(Vector2(wx, -wheel_r), wheel_r * 0.4, Color(0.6, 0.6, 0.6))
	if id == &"front_loader":
		# Arms and the bucket in front, tilting with the aim and the tip.
		var pivot := Vector2(face * (hw - 2), -s.y * 0.55)
		var bucket := Vector2(face * (hw + 8), -9.0 + aim * 6.0)
		ci.draw_line(pivot, bucket, DARK, 5.0)
		ci.draw_line(pivot, bucket, col.darkened(0.15), 3.0)
		var a := (tip * 1.1 + aim * 0.4) * face
		var pts := PackedVector2Array([Vector2(-9, -9), Vector2(9, -9), Vector2(9, 2), Vector2(-9, 2)])
		var xf := Transform2D(a, bucket)
		var poly := PackedVector2Array()
		for p in pts:
			poly.append(xf * Vector2(p.x * face, p.y))
		ci.draw_colored_polygon(poly, DARK)
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(xf * Vector2(p.x * face * 0.8, p.y * 0.8 + 0.5))
		ci.draw_colored_polygon(inner, Color(0.55, 0.55, 0.58))
	elif id == &"excavator":
		# Boom up from the cab, a stick down to the bucket; the aim swings it.
		var root := Vector2(face * 6, -s.y * 0.75)
		var elbow := root + Vector2(face * 20, -12 + aim * 10)
		var tipp := elbow + Vector2(face * 8, 16 + aim * 8)
		for seg in [[root, elbow], [elbow, tipp]]:
			ci.draw_line(seg[0], seg[1], DARK, 6.0)
			ci.draw_line(seg[0], seg[1], col.darkened(0.15), 4.0)
		ci.draw_rect(Rect2(tipp - Vector2(5, 3), Vector2(10, 8)), DARK)
		ci.draw_rect(Rect2(tipp - Vector2(4, 2), Vector2(8, 6)), Color(0.55, 0.55, 0.58))
