## The Phase 1 risk prototype (--proto / --proto-auto): one ScreenDirector hosting Hillville and the
## underground, two players dropping in, an automatic elevator between the cage zones, and the
## wiring the modules leave to the game (TileWorld and director signals -> Events, Inventory,
## Audio, particle bursts). With nobody joined a hidden anchor holds the view on the shaft.
## Prints "proto: <t> <event>" lines (physics time) so screenshot times can be picked from the log.
class_name FoundationProto
extends Node

const ProtoAuto := preload("res://scenes/proto/proto_auto.gd")
const HILLVILLE := &"hillville"
const UNDERGROUND := &"underground"
const SPAWN_X := {0: -140.0, 1: -200.0}
const LIGHT_RADIUS := 110.0

## Scripted, input-free run-through (proto_auto.gd).
@export var auto := false
## Print the "proto:" event lines.
@export var verbose := true

var director: ScreenDirector
var hillville: ProtoHillville
var underground: ProtoUnderground
var world: TileWorld
var elevator: ProtoElevator
var players: Dictionary = {}   # int -> ProtoPlayer
var clock := 0.0
var runner: Node

var _anchor: Node2D
var _anchor_on := false
var _dug_once := false


func _ready() -> void:
	director = ScreenDirector.new()
	director.name = "Director"
	director.zoom = 2.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--split-tween="):
			director.tween_time = float(arg.trim_prefix("--split-tween="))
	add_child(director)
	hillville = ProtoHillville.new()
	underground = ProtoUnderground.new()
	director.add_scene(HILLVILLE, hillville)
	director.add_scene(UNDERGROUND, underground)
	world = underground.world
	elevator = ProtoElevator.new()
	elevator.name = "Elevator"
	elevator.director = director
	elevator.scenes = {HILLVILLE: hillville, UNDERGROUND: underground}
	elevator.arrival = {HILLVILLE: ProtoHillville.ARRIVAL, UNDERGROUND: ProtoUnderground.ARRIVAL}
	add_child(elevator)
	elevator.ride_started.connect(func(p: int, from: StringName) -> void:
		log_event("elevator start P%d %s" % [p + 1, from]))
	elevator.ride_finished.connect(_on_arrived)
	world.tile_dug.connect(_on_tile_dug)
	world.dig_blocked.connect(_on_dig_blocked)
	world.body_landed.connect(_on_body_landed)
	world.prop_broke.connect(_on_prop_broke)
	world.water_entered.connect(_on_water_entered)
	director.split_changed.connect(_on_split_changed)
	director.entered_scene.connect(func(p: int, s: StringName) -> void: Events.entered_scene.emit(p, s))
	_anchor = Node2D.new()
	_anchor.name = "Anchor"
	_anchor.position = Vector2(0, -40)
	_set_anchor(true)
	Players.player_joined.connect(_on_player_joined)
	Players.player_left.connect(_on_player_left)
	for p in Players.active_players():
		spawn(p)
	if auto:
		runner = ProtoAuto.new()
		runner.name = "Auto"
		runner.proto = self
		add_child(runner)


func log_event(text: String) -> void:
	if verbose:
		print("proto: %.2f %s" % [clock, text])


func _physics_process(delta: float) -> void:
	clock += delta
	elevator.check(players, delta)


# --- players -----------------------------------------------------------------------------------

func spawn(player: int) -> ProtoPlayer:
	if players.has(player):
		return players[player]
	_set_anchor(false)
	var p := ProtoPlayer.new()
	p.name = "P%d" % (player + 1)
	p.player = player
	p.position = Vector2(SPAWN_X.get(player, -100.0), -2)
	players[player] = p
	director.add_player(player, p, HILLVILLE)
	if runner != null and runner.has_method("intent_for"):
		p.intent_source = runner.intent_for.bind(player)
	return p


func despawn(player: int) -> void:
	var p: ProtoPlayer = players.get(player)
	if p == null:
		return
	players.erase(player)
	elevator.forget(player)
	world.untrack(p)
	world.remove_light(p)
	director.remove_player(player)
	p.queue_free()
	if players.is_empty():
		_set_anchor(true)


func _on_player_joined(player: int, _device: int) -> void:
	spawn(player)
	log_event("join P%d" % (player + 1))


func _on_player_left(player: int) -> void:
	despawn(player)
	log_event("leave P%d" % (player + 1))


## The director shows nothing with zero players; the anchor stands in as player 0 at the shaft.
func _set_anchor(on: bool) -> void:
	if on == _anchor_on:
		return
	_anchor_on = on
	if on:
		director.add_player(0, _anchor, HILLVILLE)
	else:
		director.remove_player(0)


## Moves a player to a scene without a ride (tests, debugging) and sets them up there.
func teleport(player: int, scene: StringName, pos: Vector2) -> void:
	director.move_player(player, scene, pos)
	_enter(player, scene)


func _on_arrived(player: int, scene: StringName) -> void:
	_enter(player, scene)
	log_event("elevator arrive P%d %s" % [player + 1, scene])


## Underground: the world knows the player, keeps chunks around them and lights a headlamp.
func _enter(player: int, scene: StringName) -> void:
	var p: ProtoPlayer = players[player]
	if scene == UNDERGROUND:
		p.world = world
		world.track(p)
		world.add_light(p, LIGHT_RADIUS)
		world.update_chunks()
	else:
		p.world = null
		world.untrack(p)
		world.remove_light(p)


# --- module wiring -----------------------------------------------------------------------------

func _on_tile_dug(cell: Vector2i, block: StringName, player: int) -> void:
	Events.tile_dug.emit(cell, block, player)
	Inventory.add(block)
	var data: BlockData = underground.blocks.get(block)
	var cue := String(data.dig_sound) if data != null and data.dig_sound != &"" else "dig_%s" % block
	Audio.play(cue)
	_burst(world.shape.center_of(cell), data.color if data else Color.SADDLE_BROWN, 10)
	if not _dug_once:
		_dug_once = true
		log_event("first tile dug P%d %s" % [player + 1, block])


func _on_dig_blocked(cell: Vector2i, _block: StringName, _player: int) -> void:
	Audio.play("dig_blocked")
	_burst(world.shape.center_of(cell), Color.WHITE, 6)


func _on_body_landed(body: Node2D, _speed: float) -> void:
	Audio.play("fall")
	if body == underground.boulder:
		log_event("boulder landed")


func _on_prop_broke(_prop: Node2D, pieces: Array) -> void:
	Audio.play("prop_break")
	for piece in pieces:
		# Pieces are loot, not walls: they land on tiles but never block a player.
		(piece as FallingBody).collision_layer = 4
	_burst(underground.prop.position + Vector2(24, 16), underground.prop.color, 16)
	log_event("prop broke")


func _on_water_entered(cell: Vector2i) -> void:
	Audio.play("flood")
	_burst(world.shape.center_of(cell), Color(0.4, 0.7, 1.0), 8)
	log_event("flood %d,%d" % [cell.x, cell.y])


func _on_split_changed(on: bool) -> void:
	Events.split_changed.emit(on)
	Audio.play("split")
	log_event("split %s" % ("on" if on else "off"))


## A one-shot particle puff in the underground, freed when it finishes.
func _burst(pos: Vector2, color: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 5
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.gravity = Vector2(0, 400)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	p.color = color
	p.finished.connect(p.queue_free)
	world.add_child(p)
	p.emitting = true
