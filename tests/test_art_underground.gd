## The Underground's art wiring: HillTileArt walls by layer (none on base air), the look's lamps and
## residents, and a driven vehicle's nose lamp as a registered light.
class_name TestArtUnderground
extends GdUnitTestSuite

const UNDERGROUND := preload("res://scenes/levels/underground.tscn")


func _underground() -> Underground:
	var u: Underground = UNDERGROUND.instantiate()
	add_child(u)
	auto_free(u)
	return u


func test_hill_tile_art_walls() -> void:
	if not HillTileArt.available():
		return
	var u := _underground()
	var art := u.world.tile_art as HillTileArt
	assert_object(art).is_not_null()
	# A landing room is air in the base world: no wall, the parallax shows.
	var room: Rect2i = u.generator.landings[2]
	assert_object(art.wall_coords(room.position, u.world.base_tile_of(room.position), false)).is_equal(TileArt.NO_TILE)
	# A dug stone cell in layer 2 gets a stone wall, the lip row under a ceiling.
	var c := Vector2i(50, 100)
	var layer := u.generator.layer_of_depth(c.y)
	var wc := art.wall_coords(c, 3, true)
	assert_int(wc.x / HillTileArt.VARIANTS).is_equal(layer)
	assert_int(wc.y).is_equal(1)
	assert_int(art.solid_coords(c, 3, 5).y).is_equal(5)
	assert_int(art.solid_coords(c, 3, 5).x / HillTileArt.VARIANTS).is_equal(2)


func test_look_lamps_and_residents() -> void:
	var u := _underground()
	assert_object(u.look).is_not_null()
	assert_int(u.look.lamps.size()).is_equal(u.generator.landings.size())
	for lamp in u.look.lamps:
		assert_bool(u.world._darkness.lights.has(lamp)).is_true()
	if SheetSprite.has_sheet("characters/dragon.png"):
		for id: StringName in [&"mole", &"caveman", &"dragon"]:
			assert_bool(u.look.residents.has(id)).is_true()
		# Residents are pictures: no collision anywhere under them.
		for s: Node in u.look.residents.values():
			assert_int(s.get_child_count()).is_equal(0)


func test_vehicle_nose_lamp_is_a_light_only_while_driving() -> void:
	var u := _underground()
	var p := HillPlayer.new()
	p.intent_source = func() -> Dictionary: return {"move": Vector2.ZERO}
	p.position = u.landing(0)
	p.world = u.world
	u.players_root.add_child(p)
	var lamp := VehicleLamp.attach(p, u.world)
	assert_bool(u.world._darkness.lights.has(lamp)).is_false()
	p.drive(Progress.vehicle_data(&"front_loader"))
	await get_tree().process_frame
	assert_bool(u.world._darkness.lights.has(lamp)).is_true()
	assert_float(u.world._darkness.lights[lamp].x).is_equal(VehicleLamp.RADIUS)
	assert_float(lamp.position.x * p.facing).is_greater(0.0)
	p.stop_driving()
	await get_tree().process_frame
	assert_bool(u.world._darkness.lights.has(lamp)).is_false()


func before() -> void:
	SuiteSandbox.enter("art_underground")   # never the real profile, settings or picks file


func after() -> void:
	SuiteSandbox.leave()
