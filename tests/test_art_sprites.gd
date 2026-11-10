## The sprite wiring of players, vehicles, buildings and the lobby: manifest-driven frames, Jeff for
## P1 and Chuck for P2, the vehicle body row by driver, and a driver's lamps.
class_name TestArtSprites
extends GdUnitTestSuite


func test_sheet_frames_come_from_the_manifest() -> void:
	assert_vector(SpriteArt.frame_size("characters/jeff.png")).is_equal(Vector2(32, 32))
	assert_vector(SpriteArt.pivot("characters/jeff.png")).is_equal(Vector2(16, 32))
	assert_int(int(SpriteArt.row("characters/chuck.png", "walk").frames)).is_equal(4)
	assert_vector(SpriteArt.frame_size("vehicles/front_loader.png")).is_equal(Vector2(48, 34))
	# A hold frame lasts two ticks: dig_side at 10 fps is 0, 1, 1, 2.
	assert_int(SpriteArt.frame_at("characters/jeff.png", "dig_side", 0.05)).is_equal(0)
	assert_int(SpriteArt.frame_at("characters/jeff.png", "dig_side", 0.15)).is_equal(1)
	assert_int(SpriteArt.frame_at("characters/jeff.png", "dig_side", 0.25)).is_equal(1)
	assert_int(SpriteArt.frame_at("characters/jeff.png", "dig_side", 0.35)).is_equal(2)
	assert_bool(SpriteArt.has("characters/jeff.png")).is_true()
	assert_bool(SpriteArt.has("characters/nobody.png")).is_false()


func test_player_one_is_jeff_and_player_two_is_chuck() -> void:
	assert_str(SpriteArt.char_of(0)).is_equal("jeff")
	assert_str(SpriteArt.char_of(1)).is_equal("chuck")
	var lf := LobbyFigure.new()
	lf.player = 1
	assert_str(SpriteArt.char_of(lf.player)).is_equal("chuck")
	lf.free()


func test_vehicle_row_by_driver() -> void:
	assert_str(Vehicle.row_name(-1)).is_equal("cream")
	assert_str(Vehicle.row_name(0)).is_equal("green")
	assert_str(Vehicle.row_name(1)).is_equal("red")
	assert_int(Vehicle.who_of(Players.COLOR[0])).is_equal(0)
	assert_int(Vehicle.who_of(Players.COLOR[1])).is_equal(1)
	assert_int(Vehicle.who_of(Color(0, 0, 0, 0))).is_equal(-1)
	assert_int(Vehicle.tool_frame(0.0, 0.0)).is_equal(0)
	assert_int(Vehicle.tool_frame(0.3, 0.0)).is_equal(1)
	assert_int(Vehicle.tool_frame(1.0, 0.0)).is_equal(2)


func test_building_art_and_garage_door_frames() -> void:
	assert_bool(Building.has_art(&"barn")).is_true()
	assert_bool(Building.has_art(&"nothing")).is_false()
	assert_int(Building.door_frame(0.0)).is_equal(0)
	assert_int(Building.door_frame(0.5)).is_equal(1)
	assert_int(Building.door_frame(1.0)).is_equal(2)


func test_vehicle_glow_follows_lights_up_top() -> void:
	var v := Vehicle.new()
	v.data = Progress.vehicle_data(&"front_loader")
	add_child(v)
	auto_free(v)
	var g: VehicleGlow = v.get_node("Glow")
	assert_object(g).is_not_null()
	assert_float(g.strength()).is_between(0.0, 1.0)
