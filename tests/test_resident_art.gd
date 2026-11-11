## V-09: the Gnome crew sheet and the cow sheet (art/tools/make_crew_cow_art.py, traced from the 3D
## masters in openjar-characters). The manifest lists both, the game loads them, the code that draws
## the crew and the cows points at them, and the whistle reads as a whistle (below the beard at rest,
## out in front of the face when blown). Nothing here depends on the old in-code cow.
class_name TestResidentArt
extends GdUnitTestSuite

const CREW := "characters/gnome_crew.png"
const COW := "characters/cow.png"
const YELLOW := Color("ffd23f")
const BEARD := Color("ede6d6")


func before() -> void:
	SuiteSandbox.enter("resident_art")   # never the real profile, settings or picks file


func after() -> void:
	SuiteSandbox.leave()


func _entry(key: String) -> Dictionary:
	var e = SheetSprite.manifest().get(key, {})
	return e if e is Dictionary else {}


func _frame(file: String, anim: String, col := 0) -> Image:
	var img := SpriteArt.texture(file).get_image()
	if img.is_compressed():
		img.decompress()
	var fs := SpriteArt.frame_size(file)
	var r := int(SpriteArt.row(file, anim).row)
	return img.get_region(Rect2i(int(fs.x) * col, int(fs.y) * r, int(fs.x), int(fs.y)))


func _pixels(img: Image, c: Color) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a > 0.5 and p.is_equal_approx(c):
				out.append(Vector2i(x, y))
	return out


func test_manifest_lists_both_sheets_with_their_rows() -> void:
	var crew := _entry("gnome_crew")
	assert_str(String(crew.get("file", ""))).is_equal(CREW)
	for anim in ["idle", "march", "cheer", "whistle", "idle_side"]:
		assert_bool(crew.rows.has(anim)).override_failure_message("crew row " + anim).is_true()
	var cow := _entry("cow")
	assert_str(String(cow.get("file", ""))).is_equal(COW)
	for anim in ["idle", "walk", "trot", "graze", "hop", "pail", "pail_walk"]:
		assert_bool(cow.rows.has(anim)).override_failure_message("cow row " + anim).is_true()
	assert_str(String(cow.get("facing", ""))).is_equal("right")


func test_the_game_loads_both_sheets_at_their_frame_size() -> void:
	for file in [CREW, COW]:
		var tex := SpriteArt.texture(file)
		assert_object(tex).override_failure_message(file + " did not load").is_not_null()
		var fs := SpriteArt.frame_size(file)
		var e := SheetSprite.entry(file)
		var cols := 0
		for anim in e.rows:
			cols = maxi(cols, int(e.rows[anim].frames))
		assert_int(tex.get_width()).is_equal(int(fs.x) * cols)
		assert_int(tex.get_height()).is_equal(int(fs.y) * e.rows.size())
		for anim in e.rows:                     # no empty frame anywhere
			for c in int(e.rows[anim].frames):
				assert_bool(_frame(file, anim, c).get_used_rect().size.x > 0) \
					.override_failure_message("%s %s frame %d is empty" % [file, anim, c]).is_true()
	var s := SheetSprite.make(CREW, "idle")
	assert_object(s).is_not_null()
	assert_object(s.texture).is_not_null()
	s.free()


func test_the_crew_and_the_cows_draw_from_the_new_sheets() -> void:
	assert_str(TownResidents.CREW_FILE).is_equal(CREW)
	assert_str(BarnCows.COW_SHEET).is_equal(COW)
	var src := FileAccess.get_file_as_string("res://scenes/levels/underground_look.gd")
	assert_bool(src.contains("\"crew_%d\" % i), \"" + CREW + "\"")).is_true()


func test_feet_sit_on_the_bottom_row_of_every_frame() -> void:
	for file in [CREW, COW]:
		var e := SheetSprite.entry(file)
		var fh := int(SpriteArt.frame_size(file).y)
		for anim in e.rows:
			if anim == "hop" or anim == "cheer":
				continue                        # in the air on purpose
			var used := _frame(file, anim).get_used_rect()
			assert_int(used.end.y).override_failure_message("%s %s" % [file, anim]).is_equal(fh)


## At rest the whistle hangs on his chest BELOW the beard (never at the mouth, never a pipe).
func test_the_whistle_hangs_below_the_beard_at_rest() -> void:
	for anim in ["idle", "march", "idle_side"]:
		var img := _frame(CREW, anim)
		var yel := _pixels(img, YELLOW)
		var beard := _pixels(img, BEARD)
		assert_bool(yel.size() >= 3).override_failure_message(anim + ": no whistle").is_true()
		var beard_top := 99
		for p in beard:
			beard_top = mini(beard_top, p.y)
		for p in yel:                            # nothing yellow up at the face
			assert_bool(p.y > beard_top + 3).override_failure_message("%s: whistle at the face %s" % [anim, p]).is_true()


## Blown, the whistle is held out in front of his face (he faces right), clear of the beard.
func test_the_blown_whistle_is_in_front_of_the_face_not_in_the_beard() -> void:
	var img := _frame(CREW, "whistle")
	var beard := _pixels(img, BEARD)
	var front := 0
	for p in beard:
		front = maxi(front, p.x)
	var out_front := 0
	for p in _pixels(img, YELLOW):
		if p.x > front:
			out_front += 1
	assert_int(out_front).is_greater_equal(4)


## Every other cow carries the pail: the pail rows hold the pail's teal, the plain rows do not.
func test_the_pail_is_only_on_the_pail_rows() -> void:
	var teal := Color("1fb5a8")
	assert_int(_pixels(_frame(COW, "pail"), teal).size()).is_greater(8)
	assert_int(_pixels(_frame(COW, "pail_walk", 1), teal).size()).is_greater(8)
	assert_int(_pixels(_frame(COW, "idle"), teal).size()).is_equal(0)
	assert_int(_pixels(_frame(COW, "walk"), teal).size()).is_equal(0)
