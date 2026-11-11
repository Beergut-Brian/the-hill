## Minor block kinds (content-2 lane, 2026-11-10): GAME.md's layer table asks for pebbles and old
## pipes in Clay, ore veins and geodes in Stone. Each has a data row and a drawn tile, lies only in
## its layer, digs like its layer's main block and goes into the bag once; a seeded world is the
## same as before everywhere else.
class_name TestMinorBlocks
extends GdUnitTestSuite

const P1 := Players.P1
## Kind -> [layer id, the layer's main block it sits in].
const KINDS := {&"pebbles": [&"clay", &"clay"], &"pipe": [&"clay", &"clay"], &"ore": [&"stone", &"stone"], &"geode": [&"stone", &"stone"]}

var _game: HillGame
var _real_profile := ""
var _real_settings := ""


func before() -> void:
	_real_profile = Save.profile
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_minor_blocks.json"
	Save.reload_settings()
	Game.quit_exits = false


func after() -> void:
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	Save.flush()
	Save.profile = _real_profile
	Save._load()
	Game.quit_exits = true


func before_test() -> void:
	Save.profile = "test_minor_blocks"
	Save.wipe()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.PLAYING)


func after_test() -> void:
	if is_instance_valid(_game):
		_game.free()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.LOBBY)


func _palette_index(u: Underground, id: StringName) -> int:
	for i in u.world.palette.size():
		if u.world.palette[i].id == id:
			return i
	return -1


func test_every_minor_kind_resolves_to_a_data_row_and_a_tile() -> void:
	var m := HillTileArt.manifest()
	var sheet := (load("res://assets/sprites/tiles/terrain.png") as Texture2D).get_image()
	var icons := (load("res://assets/sprites/icons/blocks.png") as Texture2D).get_image()
	for id: StringName in KINDS:
		var layer := load("res://data/layers/%s.tres" % KINDS[id][0]) as LayerData
		var main := load("res://data/blocks/%s.tres" % KINDS[id][1]) as BlockData
		var b := load("res://data/blocks/%s.tres" % id) as BlockData
		assert_object(b).override_failure_message("no row for %s" % id).is_not_null()
		assert_str(String(b.id)).is_equal(String(id))
		# In the layer GAME.md names, laid in by that layer's minor_kinds.
		assert_bool(layer.minor_kinds.has(id)).override_failure_message("%s not in %s" % [id, layer.id]).is_true()
		assert_bool(b.depth_from >= layer.depth_from and b.depth_to <= layer.depth_to).is_true()
		assert_str(String(b.minor_shape)).is_not_empty()
		# Digs like its neighbour: same cue, tool and solidity; a small worth.
		for k in ["solid", "breakable", "dig_tier", "slippery", "bouncy", "dig_sound"]:
			assert_str(str(b.get(k))).override_failure_message("%s.%s" % [id, k]).is_equal(str(main.get(k)))
		assert_int(b.value).is_between(1, main.value)
		# A drawn tile and an icon in its palette column, and a spot on the town pile.
		var i := Underground.BLOCK_ORDER.find(id)
		assert_int(i).is_greater(0)
		assert_str(str(m.terrain.ids.get(str(i + 1), ""))).is_equal(String(id))
		assert_str(str(m.block_icons.ids.get(str(i + 1), ""))).is_equal(String(id))
		var col := i * HillTileArt.VARIANTS * 16
		var base := Underground.BLOCK_ORDER.find(main.id) * HillTileArt.VARIANTS * 16
		var differs := 0
		for y in 16:
			for x in 16:
				assert_float(sheet.get_pixel(col + x, y).a).is_equal(1.0)
				if sheet.get_pixel(col + x, y) != sheet.get_pixel(base + x, y):
					differs += 1
		assert_int(differs).override_failure_message("%s looks like %s" % [id, main.id]).is_greater(12)
		assert_float(icons.get_pixel(i * 16 + 8, 8).a).is_equal(1.0)
		assert_int(int(Hillville.ICON_COL.get(id, -1))).is_equal(i)
		assert_int(int(LayerPick.ICON_COL.get(id, -1))).is_equal(i)
		assert_bool(Hillville.BLOCK_ORDER.has(id)).is_true()


func test_minor_kinds_lie_in_their_layer_and_leave_the_rest_of_the_world_unchanged() -> void:
	var u: Underground = auto_free(load("res://scenes/levels/underground.tscn").instantiate())
	add_child(u)
	var g := u.generator
	var with_minor := PackedInt32Array()
	with_minor.resize(HillGenerator.WIDTH * HillGenerator.HEIGHT)
	for y in HillGenerator.HEIGHT:
		for x in HillGenerator.WIDTH:
			with_minor[y * HillGenerator.WIDTH + x] = g.base_tile(Vector2i(x, y))
	var kept: Array = g._minor
	g._minor = []
	var idx := {}
	var counts := {}
	for id: StringName in KINDS:
		idx[_palette_index(u, id)] = id
		counts[id] = 0
	for y in HillGenerator.HEIGHT:
		for x in HillGenerator.WIDTH:
			var c := Vector2i(x, y)
			var before := g.base_tile(c)
			var now := with_minor[y * HillGenerator.WIDTH + x]
			if now == before:
				assert_bool(idx.has(now)).override_failure_message("%s at %s without minor kinds" % [now, c]).is_false()
				continue
			# Only a minor kind, only in its layer, only over that layer's main block.
			assert_bool(idx.has(now)).override_failure_message("cell %s changed %d -> %d" % [c, before, now]).is_true()
			var id: StringName = idx[now]
			var li := g.layer_of_depth(y)
			assert_str(String((g.layer_rows[li] as LayerData).id)).is_equal(String(KINDS[id][0]))
			assert_int(before).is_equal(_palette_index(u, KINDS[id][1]))
			counts[id] += 1
	g._minor = kept
	# Each kind is really there (and not taking over its layer).
	for id: StringName in KINDS:
		assert_int(int(counts[id])).override_failure_message("%s cells: %d" % [id, counts[id]]).is_greater(20)
	prints("minor cells:", counts)
	# Landing rooms and their surroundings stay plain.
	for li in g.landings.size():
		var room: Rect2i = (g.landings[li] as Rect2i).grow(5)
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				if x >= 0 and x < HillGenerator.WIDTH and y >= 0 and y < HillGenerator.HEIGHT:
					assert_bool(idx.has(with_minor[y * HillGenerator.WIDTH + x])).is_false()


func test_digging_a_minor_kind_puts_it_in_the_bag_once() -> void:
	_game = HillGame.new()
	_game.start_players = [P1]
	get_tree().root.add_child(_game)
	Players.join_virtual(P1)
	var p := _game.player_node(P1)
	if p == null:
		p = _game.wake(P1)
	p.intent_source = func() -> Dictionary: return {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}
	var u := _game.underground
	var g := u.generator
	var heard: Array = []
	u.world.tile_dug.connect(func(_c: Vector2i, blk: StringName, _p: int) -> void: heard.append(blk))
	for id: StringName in KINDS:
		var pi := _palette_index(u, id)
		var li := g._layer_index(KINDS[id][0])
		var floor_y := g.landing_floor(li)
		_game.place_player(P1, HillGame.UNDERGROUND, Vector2((HillGenerator.SHAFT_X - 2.5) * 16.0, floor_y * 16.0 - 1.0))
		var at := Vector2i(-1, -1)
		var layer := g.layer_rows[li] as LayerData
		for y in range(layer.depth_from, layer.depth_to):
			for x in range(2, HillGenerator.WIDTH - 2):
				if at.x < 0 and u.world.get_tile(Vector2i(x, y)) == pi:
					at = Vector2i(x, y)
		assert_int(at.x).override_failure_message("no %s cell" % id).is_greater(0)
		var before := int(p.backpack.get(id, 0))
		var first := u.world.dig(at, [Vector2i.ZERO], P1)
		var again := u.world.dig(at, [Vector2i.ZERO], P1)
		assert_int(first.size()).is_equal(1)
		assert_int(again.size()).is_equal(0)
		assert_bool(u.world.is_solid(at)).is_false()
		assert_int(int(p.backpack.get(id, 0))).override_failure_message("%s in bag" % id).is_equal(before + 1)
		assert_int(heard.count(id)).is_equal(1)
		# The pile takes it on the ride up like any block.
		Inventory.add(id, int(p.backpack.get(id, 0)))
		assert_int(Inventory.count(id)).is_equal(1)
