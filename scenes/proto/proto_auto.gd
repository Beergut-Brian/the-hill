## --proto-auto: joins both players virtually and drives their intents from a deterministic timeline
## in physics time (no input, no randomness). Each step runs until its condition holds or its
## timeout passes, so it can never hang; each beat prints a "proto:" line through the proto root.
##   1 both up top walk right; 2 P1 rides down (split); 3 P1 digs right: boulder, car, water pocket;
##   4 P2 jumps and scoops, then rides down (join); 5 P2 digs left until the split opens;
##   6 P2 walks back and rides up (split, one up one down); then both idle.
extends Node

const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false}

var proto: FoundationProto
var step := 0
var step_time := 0.0
var done := false
var _intent := {0: IDLE.duplicate(), 1: IDLE.duplicate()}
var _wet_time := {0: 0.0, 1: 0.0}
var _floated := {}

## [name, timeout seconds]; conditions and intents live in _drive().
var _steps: Array = [
	["walk to the shaft", 6.0],
	["P1 rides down", 3.0],
	["P1 digs to the water", 25.0],
	["P2 rides down", 8.0],
	["both underground, joined", 4.0],
	["P2 digs left", 25.0],
	["P2 rides up", 15.0],
]


func _ready() -> void:
	Players.join_virtual(Players.P1)
	Players.join_virtual(Players.P2)
	for p in proto.players:
		(proto.players[p] as ProtoPlayer).intent_source = intent_for.bind(p)
	proto.log_event("auto: %s" % _steps[0][0])


func intent_for(player: int) -> Dictionary:
	return _intent.get(player, IDLE)


func _physics_process(delta: float) -> void:
	_log_floating(delta)
	if done or proto.players.size() < 2:
		return
	step_time += delta
	var finished := _drive()
	if not finished and step_time >= float(_steps[step][1]):
		proto.log_event("auto: timeout in '%s'" % _steps[step][0])
		finished = true
	if finished:
		step += 1
		step_time = 0.0
		_go(0, Vector2.ZERO)
		_go(1, Vector2.ZERO)
		if step >= _steps.size():
			done = true
			proto.log_event("auto: done")
		else:
			proto.log_event("auto: %s" % _steps[step][0])


## Sets this step's intents; true when its condition holds.
func _drive() -> bool:
	var p1: ProtoPlayer = proto.players[0]
	var p2: ProtoPlayer = proto.players[1]
	var d := proto.director
	var cs := float(proto.world.shape.cell_size)
	match step:
		0:
			_go(0, Vector2.RIGHT)
			_go(1, Vector2.RIGHT if p2.position.x < -90.0 else Vector2.ZERO)
			return proto.elevator.is_riding(0)
		1:
			_go(1, Vector2.ZERO)
			return d.scene_of(0) == FoundationProto.UNDERGROUND and not proto.elevator.is_riding(0)
		2:
			_go(0, Vector2.RIGHT, true)
			_idle_up_top(1)
			return p1.position.x >= 121.0 * cs
		3:
			_go(1, Vector2.RIGHT)
			return d.scene_of(1) == FoundationProto.UNDERGROUND and not proto.elevator.is_riding(1)
		4:
			return not d.is_split() and step_time > 1.0
		5:
			_go(1, Vector2.LEFT, true)
			return d.is_split() and step_time > 0.5
		6:
			_go(1, Vector2.RIGHT)
			return d.scene_of(1) == FoundationProto.HILLVILLE and not proto.elevator.is_riding(1)
	return true


## P2 waiting up top: a jump, then a scoop, then a pause, on repeat.
func _idle_up_top(player: int) -> void:
	var t := fmod(step_time, 3.0)
	_intent[player] = {"move": Vector2.ZERO, "dig": t > 1.2 and t < 1.5, "jump": t < 0.1}


func _go(player: int, move: Vector2, dig := false, jump := false) -> void:
	_intent[player] = {"move": move, "dig": dig, "jump": jump}


## "P<n> floating" once, after half a second in water without touching the floor.
func _log_floating(delta: float) -> void:
	for p in proto.players:
		var pl: ProtoPlayer = proto.players[p]
		if pl.world == null or not pl.in_water() or pl.is_on_floor():
			_wet_time[p] = 0.0
			continue
		_wet_time[p] = _wet_time.get(p, 0.0) + delta
		if _wet_time[p] >= 0.5 and not _floated.has(p):
			_floated[p] = true
			proto.log_event("P%d floating" % (p + 1))
