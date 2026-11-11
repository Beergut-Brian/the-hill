## Depth life (W-03, C-17, W-11; depth life lane, 2026-11-10): every block has a data row and a
## tile, Sand sits in the lower Stone layer and digs like dirt, Topsoil worms wave only when a
## player is close, roots hang from dirt ceilings, and one frozen fish per ice rink is a treasure
## once.
class_name TestDepthLife
extends GdUnitTestSuite

const P1 := Players.P1
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}

var _game: HillGame
var _real_profile := ""
var _real_settings := ""
var _intent := {}


func before() -> void:
	_real_profile = Save.profile
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_depth_life.json"
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
	Save.profile = "test_depth_life"
	Save.wipe()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.PLAYING)
	_intent = {P1: IDLE.duplicate()}


func after_test() -> void:
	if is_instance_valid(_game):
		_game.free()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.LOBBY)


func _make() -> HillGame:
	_game = HillGame.new()
	_game.start_players = [P1]
	get_tree().root.add_child(_game)
	return _game


func _join() -> HillPlayer:
	Players.join_virtual(P1)
	var node := _game.player_node(P1)
	if node == null:
		node = _game.wake(P1)
	node.intent_source = func() -> Dictionary: return _intent[P1]
	return node


func _feet(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * 16.0, cell.y * 16.0 - 1.0)


func _put(cell: Vector2i) -> HillPlayer:
	var p := _game.player_node(P1)
	_game.place_player(P1, HillGame.UNDERGROUND, _feet(cell))
	p.velocity = Vector2.ZERO
	return p


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> int:
	var n := 0
	while not cond.call() and n < max_frames:
		await get_tree().physics_frame
		n += 1
	return n


func _palette_index(u: Underground, id: StringName) -> int:
	for i in u.world.palette.size():
		if u.world.palette[i].id == id:
			return i
	return -1


# --- blocks -----------------------------------------------------------------------------------

func test_every_block_resolves_to_a_data_row_and_a_tile() -> void:
	var m := HillTileArt.manifest()
	var terrain: Dictionary = m.get("terrain", {})
	var icons: Dictionary = m.get("block_icons", {})
	var sheet := load("res://assets/sprites/tiles/terrain.png") as Texture2D
	var icon_sheet := load("res://assets/sprites/icons/blocks.png") as Texture2D
	# Every row in data/blocks is in the palette, and the palette is every row.
	var rows: Array[StringName] = []
	for f in DirAccess.get_files_at("res://data/blocks/"):
		if f.trim_suffix(".remap").ends_with(".tres"):
			rows.append(StringName(f.trim_suffix(".remap").get_basename()))
	assert_int(rows.size()).is_equal(Underground.BLOCK_ORDER.size())
	for i in Underground.BLOCK_ORDER.size():
		var id: StringName = Underground.BLOCK_ORDER[i]
		assert_bool(rows.has(id)).override_failure_message("no data row for %s" % id).is_true()
		var b := load("res://data/blocks/%s.tres" % id) as BlockData
		assert_object(b).is_not_null()
		assert_str(String(b.id)).is_equal(String(id))
		# Palette index i + 1 is its terrain column block and its icon column.
		assert_str(str(terrain.ids.get(str(i + 1), ""))).override_failure_message("terrain id %d" % (i + 1)).is_equal(String(id))
		assert_str(str(icons.ids.get(str(i + 1), ""))).is_equal(String(id))
		assert_int(sheet.get_width()).is_greater_equal((i + 1) * HillTileArt.VARIANTS * 16)
		assert_int(icon_sheet.get_width()).is_greater_equal((i + 1) * 16)
		assert_int(int(Hillville.ICON_COL.get(id, -1))).is_equal(i)
		assert_int(int(LayerPick.ICON_COL.get(id, -1))).is_equal(i)
	# Sand: a real tile with pixels, in the order GAME.md lists (between Stone and Ice by depth).
	var col := (Underground.BLOCK_ORDER.find(&"sand")) * HillTileArt.VARIANTS * 16
	var img := sheet.get_image()
	assert_float(img.get_pixel(col + 8, 8).a).is_equal(1.0)
	var sand := load("res://data/blocks/sand.tres") as BlockData
	var stone := load("res://data/blocks/stone.tres") as BlockData
	var ice := load("res://data/blocks/ice.tres") as BlockData
	assert_bool(sand.depth_from > stone.depth_from and sand.depth_to <= ice.depth_from).is_true()
	assert_bool(Hillville.BLOCK_ORDER.has(&"sand")).is_true()


func test_sand_lies_only_in_the_lower_stone_layer() -> void:
	var u: Underground = auto_free(load("res://scenes/levels/underground.tscn").instantiate())
	add_child(u)
	var sand := _palette_index(u, &"sand")
	var stone_li := u.generator._layer_index(&"stone")
	var b: BlockData = u.blocks[&"sand"]
	var n := 0
	for y in HillGenerator.HEIGHT:
		for x in HillGenerator.WIDTH:
			if u.generator.base_tile(Vector2i(x, y)) == sand:
				n += 1
				assert_int(y).is_greater_equal(b.depth_from)
				assert_int(u.generator.layer_of_depth(y)).is_equal(stone_li)
	assert_int(n).override_failure_message("sand cells: %d" % n).is_greater(100)


func test_digging_sand_behaves_like_dirt() -> void:
	var sand := load("res://data/blocks/sand.tres") as BlockData
	var dirt := load("res://data/blocks/dirt.tres") as BlockData
	for k in ["solid", "breakable", "dig_tier", "slippery", "bouncy", "dig_sound"]:
		assert_str(str(sand.get(k))).override_failure_message(k).is_equal(str(dirt.get(k)))
	_make()
	var p := _join()
	var u := _game.underground
	# A spot in the lower Stone layer with three sand cells in a row; a little room left of it.
	var id := _palette_index(u, &"sand")
	var at := Vector2i(-1, -1)
	for y in range(104, 126):
		for x in range(10, 185):
			if at.x < 0 and u.world.get_tile(Vector2i(x, y)) == id and u.world.get_tile(Vector2i(x + 1, y)) == id \
					and u.world.get_tile(Vector2i(x, y - 1)) == id and u.world.is_solid(Vector2i(x - 2, y + 1)) \
					and u.world.is_solid(Vector2i(x - 1, y + 1)):
				at = Vector2i(x, y)
	assert_int(at.x).is_greater(0)
	for c in [at + Vector2i(-1, 0), at + Vector2i(-2, 0), at + Vector2i(-1, -1), at + Vector2i(-2, -1)]:
		u.world.set_tile(c, 0)
	_put(at + Vector2i(-2, 0))
	p.facing = 1
	var dug: Array = []
	u.world.tile_dug.connect(func(_c: Vector2i, blk: StringName, _p: int) -> void: dug.append(blk))
	_intent[P1] = {"move": Vector2(1, 0), "dig": true, "jump": false, "book": false, "horn": false}
	await _until(func() -> bool: return dug.has(&"sand"), 90)
	_intent[P1] = IDLE.duplicate()
	assert_bool(dug.has(&"sand")).override_failure_message("dug %s" % [dug]).is_true()
	assert_bool(u.world.is_solid(at)).is_false()
	# It goes into the backpack like any block.
	assert_int(int(p.backpack.get(&"sand", 0))).is_greater(0)


# --- Topsoil: roots and worms ------------------------------------------------------------------

func test_roots_hang_only_from_topsoil_dirt_ceilings_and_go_when_dug() -> void:
	_make()
	var u := _game.underground
	var life := u.life
	assert_int(life.roots.size()).is_greater(5)
	var dirt := _palette_index(u, &"dirt")
	var top_to: int = (u.layers()[0] as LayerData).depth_to
	for c: Vector2i in life.roots:
		assert_int(u.world.get_tile(c)).is_equal(dirt)
		assert_bool(u.world.is_solid(c + Vector2i.DOWN)).is_false()
		assert_int(c.y).is_less(top_to)
	# The landing room's ceiling always has its two.
	var room: Rect2i = u.generator.landings[0]
	var c0 := Vector2i(room.position.x + 2, room.position.y - 1)
	assert_bool(life.roots.has(c0)).is_true()
	u.world.dig(c0, [Vector2i.ZERO], P1)
	assert_bool(life.roots.has(c0)).is_false()


func test_a_worm_waves_only_when_the_player_is_close_then_ducks_back() -> void:
	_make()
	var p := _join()
	var u := _game.underground
	var life := u.life
	var room: Rect2i = u.generator.landings[0]
	var wall := Vector2i(room.position.x - 1, room.end.y - 1)
	assert_bool(life.is_worm_home(wall)).is_true()
	# In the middle of the room (far from both walls): nobody pops out.
	_put(Vector2i(room.position.x + 7, room.end.y))
	p.set_physics_process(false)
	await _physics(90)
	assert_bool(life.is_waving(wall)).is_false()
	assert_float(life.worm_out(wall)).is_equal(0.0)
	assert_int(life.waving_worms().size()).is_equal(0)
	# Right beside the left wall: the worm pops out and waves.
	p.set_physics_process(true)
	_put(Vector2i(room.position.x, room.end.y))
	p.set_physics_process(false)
	var n := await _until(func() -> bool: return life.is_waving(wall), 60)
	assert_int(n).is_less(60)
	assert_bool(life.is_waving(wall)).is_true()
	assert_int(int(life.worms[wall].dir)).is_equal(1)
	# Walk away: it ducks back in, and rests (no wave) even after a moment.
	p.set_physics_process(true)
	_put(Vector2i(room.position.x + 7, room.end.y))
	p.set_physics_process(false)
	await _physics(int((DepthLife.LEAVE + DepthLife.DUCK) * 60.0) + 6)
	assert_bool(life.is_waving(wall)).is_false()
	assert_float(life.worm_out(wall)).is_equal(0.0)
	p.set_physics_process(true)


func test_a_dug_out_worm_cell_takes_its_worm_with_it() -> void:
	_make()
	var p := _join()
	var u := _game.underground
	var room: Rect2i = u.generator.landings[0]
	var wall := Vector2i(room.position.x - 1, room.end.y - 1)
	_put(Vector2i(room.position.x, room.end.y))
	p.set_physics_process(false)
	await _until(func() -> bool: return u.life.is_waving(wall), 60)
	u.world.dig(wall, [Vector2i.ZERO], P1)
	await _physics(2)
	assert_bool(u.life.worms.has(wall)).is_false()
	p.set_physics_process(true)


# --- Ice: snow and the frozen fish -------------------------------------------------------------

func test_one_frozen_fish_sits_in_the_ice_floor_of_every_rink() -> void:
	var u: Underground = auto_free(load("res://scenes/levels/underground.tscn").instantiate())
	add_child(u)
	var g := u.generator
	var ice := _palette_index(u, &"ice")
	assert_int(g.fish_cells.size()).is_equal(g.ice_holes.size())
	assert_int(g.fish_cells.size()).is_greater(0)
	for i in g.fish_cells.size():
		var c: Vector2i = g.fish_cells[i]
		var ih: Dictionary = g.ice_holes[i]
		assert_int(c.y).is_equal((ih.rink as Rect2i).end.y)
		assert_bool((ih.rink as Rect2i).has_point(c + Vector2i.UP)).is_true()
		assert_bool((ih.hole as Rect2i).has_point(c)).is_false()
		assert_int(g.base_tile(c)).is_equal(ice)
		assert_bool(u.life.has_fish(c)).is_true()
	# Not seeded as an ordinary pickup anywhere else.
	for s in g.treasure_spots:
		assert_str(String(s.id)).is_not_equal(String(HillGenerator.FISH))
	assert_object(Progress.treasure_data(HillGenerator.FISH)).is_not_null()
	assert_bool(Progress.treasure_data(HillGenerator.FISH).stays).is_false()
	assert_bool(ResourceLoader.exists("res://assets/sprites/treasures/frozen_fish.png")).is_true()


func test_the_frozen_fish_is_a_treasure_once() -> void:
	_make()
	var p := _join()
	var u := _game.underground
	var g := u.generator
	assert_int(g.fish_cells.size()).is_greater_equal(2)
	var found: Array = []
	var on_found := func(id: StringName, _p: int) -> void: found.append(id)
	Events.treasure_found.connect(on_found)
	var a: Vector2i = g.fish_cells[0]
	_put(a)
	p.set_physics_process(false)
	await _physics(2)
	u.world.dig(a, [Vector2i.ZERO], P1)
	assert_bool(Progress.has_treasure(HillGenerator.FISH)).is_true()
	assert_int(found.count(HillGenerator.FISH)).is_equal(1)
	assert_bool(u.life.has_fish(a)).is_false()
	# A second fish wiggles free and swims off: no second treasure.
	var b: Vector2i = g.fish_cells[1]
	_put(b)
	await _physics(2)
	u.world.dig(b, [Vector2i.ZERO], P1)
	assert_int(found.count(HillGenerator.FISH)).is_equal(1)
	assert_int(Progress.treasures.count(HillGenerator.FISH)).is_equal(1)
	assert_int(u.life._fish_free.size()).is_equal(1)
	assert_bool(u.life.has_fish(b)).is_false()
	Events.treasure_found.disconnect(on_found)
	p.set_physics_process(true)
