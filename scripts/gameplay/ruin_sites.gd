## The four ruins up top and what they become (the Fix-up beat of the residents' arcs):
## - silhouettes: a ruin shows its resident's dark shape in the door once they were met;
## - restoring: HillGame.restore_ruin pays, Story moves the resident to RESTORED, and here the
##   ruin rebuilds plank by plank (the Building's unfold plus a row-by-row reveal), the door light
##   comes on and stays on;
## - the payoffs that live at the buildings: Lost & Found bundles at the shed door, the Gnome
##   Village's overnight pile with its march clip, and the warm light on the Dragon Perch.
## (The residents themselves walk and talk in TownResidents; the Museum shelf is TreasureShelf.)
class_name RuinSites
extends Node2D

signal rebuilt(resident: StringName)
signal bundle_collected(block: StringName, count: int)
signal crew_delivered(count: int)

const PLOT := 48
const PLANKS := 10
const PLANK_TIME := 0.11
## Lost & Found: a bundle waits at the shed door every FOUND_EVERY seconds of play (one at a time).
const FOUND_EVERY := 150.0
const FOUND_BLOCKS := 5
const PICK_NEAR := 44.0
const CREW_CLIP := 4.5
const WARM := Color(1.0, 0.78, 0.45)
const OUTLINE := Color("3a2a44")
const GOLD := Color("ffd23f")

var game: Node
var hillville: Hillville
var homes := {}                  # resident -> Building
## FOUND_EVERY unless a test shortens it.
var found_every := FOUND_EVERY
var _lights := {}                # resident -> Sprite2D (door light)
var _t := 0.0
var _found_t := 0.0
var _building := {}              # resident -> {t, plank} while rebuilding
var _clip := {}                  # the overnight crew's march: {t, n, blocks: Array}


func setup(p_game: Node, hv: Hillville) -> void:
	game = p_game
	hillville = hv
	name = "RuinSites"
	sync_story(false)


func story() -> Story:
	var s = game.get("story") if game != null else null
	return s as Story


## Applies the Story: silhouettes for everyone met, restored buildings standing (no animation).
func sync_story(_animate := false) -> void:
	var st := story()
	if st == null:
		return
	for id: StringName in Story.RUIN_OF:
		var ruin: StringName = Story.RUIN_OF[id]
		hillville.show_silhouette(ruin, st.phase(id) != ResidentState.Phase.UNMET)
		if st.restored(id) and not homes.has(id):
			_stand(id).reveal = 1.0
			_light(id)


func home_rect(id: StringName) -> Rect2:
	return hillville.ruin_rect(Story.RUIN_OF.get(id, &""))


## The restored building's door (Hillville-local feet), or the ruin's middle.
func door_of(id: StringName) -> Vector2:
	var r := home_rect(id)
	var home: StringName = Story.HOME_OF.get(id, &"")
	var d := HillvilleArt.point(String(home), "door")
	var fr := HillvilleArt.frame(String(home))
	if d == Vector2.ZERO or fr == Vector2.ZERO:
		return Vector2(r.get_center().x, 0)
	return Vector2(r.position.x + d.x * r.size.x / fr.x, r.end.y - (fr.y - d.y) * r.size.y / fr.y)


func is_rebuilding(id: StringName = &"") -> bool:
	return _building.has(id) if id != &"" else not _building.is_empty()


## Plays the rebuild for a resident who was just RESTORED (Story already moved them).
func play_restore(id: StringName) -> void:
	if homes.has(id):
		return
	var r := home_rect(id)
	var mid := Vector2(r.get_center().x, 0)
	hillville.puff(mid + Vector2(0, -r.size.y * 0.4), Color(0.85, 0.75, 0.6), 22)
	hillville.puff(mid, Color(0.7, 0.6, 0.5), 14)
	Audio.play("ruin_rumble")
	var b := _stand(id)
	b.reveal = 0.0
	b.unfold()
	_building[id] = {"t": 0.0, "plank": 0}


func _stand(id: StringName) -> Building:
	var d := Progress.building_data(Story.HOME_OF.get(id, &""))
	var b := Building.make(d)
	b.position = Vector2(home_rect(id).position.x, 0)
	add_child(b)
	homes[id] = b
	hillville.set_ruin_restored(Story.RUIN_OF[id])
	return b


func _light(id: StringName) -> void:
	if _lights.has(id):
		return
	var tex := HillvilleArt.tex("fx/glow.png")
	if tex == null:
		return
	var sp := Sprite2D.new()
	sp.name = "DoorLight_%s" % id
	sp.texture = tex
	sp.material = HillvilleArt.additive()
	sp.position = door_of(id) + Vector2(0, -18)
	sp.scale = Vector2(2.4, 2.4)
	sp.modulate = Color(WARM, 0.0)
	add_child(sp)
	_lights[id] = sp


func light_on(id: StringName) -> bool:
	return _lights.has(id)


func _physics_process(delta: float) -> void:
	_t += delta
	for id in _building.keys():
		_step_rebuild(id, delta)
	var st := story()
	if st != null and st.restored(Story.MOLE):
		if not bool(st.extras.get("found_waiting", false)):
			_found_t += delta
			if _found_t >= found_every:
				leave_bundle()
		elif _player_near(door_of(Story.MOLE) + Vector2(-26, 0), PICK_NEAR):
			collect_bundle()
	if not _clip.is_empty():
		_clip.t += delta
		if _clip.t >= CREW_CLIP:
			_clip = {}
	for id in _lights:
		var lit := 0.55 + 0.45 * Building.current_lights()
		(_lights[id] as Sprite2D).modulate = Color(WARM, lit * (0.85 + 0.15 * sin(_t * 3.0 + float(hash(id) % 7))))
	queue_redraw()


func _step_rebuild(id: StringName, delta: float) -> void:
	var s: Dictionary = _building[id]
	s.t += delta
	var b: Building = homes[id]
	var want := mini(PLANKS, int(s.t / PLANK_TIME) + 1)
	while s.plank < want:
		s.plank += 1
		b.reveal = float(s.plank) / PLANKS
		Audio.play("plank")
		var y := -b.size_px().y * b.reveal
		hillville.puff(b.position + Vector2(randf_range(8.0, b.size_px().x - 8.0), y), Color(0.85, 0.7, 0.5), 3)
	if s.plank >= PLANKS and s.t >= PLANKS * PLANK_TIME + 0.25:
		_building.erase(id)
		b.reveal = 1.0
		b.bump()
		Audio.play("build_unfold")
		Audio.play("cheer")
		Audio.play("light_on")
		_light(id)
		hillville.puff(door_of(id) + Vector2(0, -20), GOLD, 14)
		rebuilt.emit(id)


# --- Lost & Found -------------------------------------------------------------------------------

func has_bundle() -> bool:
	var st := story()
	return st != null and bool(st.extras.get("found_waiting", false))


## A found bundle appears at the shed door (saved until someone picks it up).
func leave_bundle() -> void:
	var st := story()
	if st == null:
		return
	_found_t = 0.0
	st.extras["found_waiting"] = true
	st.extras["found_block"] = String(_bundle_block())
	Audio.play("mole_found")
	hillville.puff(door_of(Story.MOLE) + Vector2(-26, -6), GOLD, 10)


func collect_bundle() -> void:
	var st := story()
	if st == null or not has_bundle():
		return
	var b := StringName(str(st.extras.get("found_block", "dirt")))
	st.extras["found_waiting"] = false
	Inventory.add(b, FOUND_BLOCKS)
	Audio.play("bundle_pop")
	Audio.play("treasure")
	hillville.puff(door_of(Story.MOLE) + Vector2(-26, -8), GOLD, 16)
	bundle_collected.emit(b, FOUND_BLOCKS)


## The deepest layer anyone has visited, one of its blocks.
func _bundle_block() -> StringName:
	var deepest := maxi(Progress.deepest_of(0), Progress.deepest_of(1))
	var order := [&"dirt", &"clay", &"stone", &"ice", &"crystal", &"crystal"]
	return order[clampi(deepest, 0, order.size() - 1)]


# --- Gnome Village: the overnight crew -----------------------------------------------------------

## On load with the village standing: the crew's pile for `away_seconds` (Rules.gnome_award) goes
## onto the shaft pile, with the march clip. Returns the blocks given (0: nothing, no clip).
func crew_return(away_seconds: float) -> int:
	var st := story()
	if st == null or not st.restored(Story.FOREMAN):
		return 0
	var n := Rules.gnome_award(away_seconds)
	if n <= 0:
		return 0
	var deepest := maxi(Progress.deepest_of(0), Progress.deepest_of(1))
	var mix: Array = [&"dirt", &"clay", &"stone", &"ice", &"crystal"].slice(0, clampi(deepest + 1, 1, 5))
	var given := {}
	for i in n:
		var b: StringName = mix[i % mix.size()]
		given[b] = int(given.get(b, 0)) + 1
	for b in given:
		Inventory.add(b, given[b])
	_clip = {"t": 0.0, "n": 5, "blocks": given.keys()}
	Audio.play("whistle")
	Audio.play("crew_march")
	crew_delivered.emit(n)
	return n


func crew_clip_playing() -> bool:
	return not _clip.is_empty()


func _player_near(at: Vector2, r: float) -> bool:
	if game == null or not game.has_method("player_node"):
		return false
	var dir = game.get("director")
	for p in [0, 1]:
		var n = game.player_node(p)
		if n == null:
			continue
		if dir != null and dir.scene_of(p) != &"hillville":
			continue
		if hillville.to_local((n as Node2D).global_position).distance_to(at) < r:
			return true
	return false


func _draw() -> void:
	if has_bundle():
		_draw_bundle(door_of(Story.MOLE) + Vector2(-26, 0))
	if not _clip.is_empty():
		_draw_clip()


## A little crate with a ribbon and twinkles.
func _draw_bundle(at: Vector2) -> void:
	var bob := absf(sin(_t * 3.0)) * 2.0
	var r := Rect2(at + Vector2(-8, -14 - bob), Vector2(16, 14))
	draw_rect(r.grow(1.5), OUTLINE)
	draw_rect(r, Color("a47148"))
	draw_line(r.position + Vector2(0, 5), Vector2(r.end.x, r.position.y + 5), Color("8a5a3c"), 1.5)
	draw_rect(Rect2(r.get_center().x - 1.5, r.position.y, 3, r.size.y), Color("ff8fb1"))
	draw_circle(Vector2(r.get_center().x, r.position.y), 3.0, Color("ff8fb1"))
	for j in 3:
		var a := _t * 2.5 + j * TAU / 3.0
		var p := r.get_center() + Vector2(cos(a) * 14.0, sin(a) * 10.0)
		draw_line(p - Vector2(2, 0), p + Vector2(2, 0), Color(1, 1, 0.8, 0.9), 1.0)
		draw_line(p - Vector2(0, 2), p + Vector2(0, 2), Color(1, 1, 0.8, 0.9), 1.0)


## Five little gnomes march out of the shaft to the pile, each with a block on his head.
func _draw_clip() -> void:
	var t: float = _clip.t
	var tex := SpriteArt.texture("characters/foreman.png")
	var blocks: Array = _clip.blocks
	for i in int(_clip.n):
		var k := t - i * 0.35
		if k < 0.0:
			continue
		var x := Hillville.SHAFT_X + minf(k * 70.0, 150.0 + i * 14.0)
		var hop := absf(sin(k * 11.0)) * 3.0
		var feet := Vector2(x, -hop)
		if tex != null:
			var fs := SpriteArt.frame_size("characters/foreman.png")
			var sz := fs * 0.6
			draw_texture_rect_region(tex, Rect2(feet - Vector2(sz.x * 0.5, sz.y), sz), Rect2(Vector2.ZERO, fs))
		var b: StringName = blocks[i % blocks.size()]
		var br := Rect2(feet + Vector2(-5, -31), Vector2(10, 10))
		draw_rect(br.grow(1), OUTLINE)
		draw_rect(br, Hillville.block_color(b))
