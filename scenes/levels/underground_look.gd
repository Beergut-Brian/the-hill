## The Underground's look (palette A "Sandbox" with D's light): visuals only, no collision and no
## gameplay. Built by Underground after its world and bodies exist:
## - a parallax backdrop per layer band (far and near strips of parallax/underground.png through
##   assets/shaders/parallax.gdshader, factor.y = 1 so bands stay on their layers);
## - water from tiles/water.png;
## - boulders drawn from props/boulder.png in quarter turns (the sprite never rotates);
## - treasure props from treasures/<id>.png with a sparkle, an additive glow and a small light;
## - a lamp per landing cage (registered light + fx/glow.png pool);
## - the residents idling where GAME.md puts them (the gnome crew of three walled into the Gnome
##   Room), and a warm light at the Bottom;
## - set_ice_warm: the Dragon Perch's warm Ice layer (softer, warmer darkness, a wash, drips).
## Every piece is skipped when its sheet is missing, so the game still runs on the flat look.
class_name UndergroundLook
extends Node2D

const PARALLAX_SHADER := "res://assets/shaders/parallax.gdshader"
const FAR_FACTOR := Vector2(0.3, 1.0)
const NEAR_FACTOR := Vector2(0.6, 1.0)
## How far the backdrop reaches past the world on each side (covers the parallax shift).
const BACK_MARGIN := 1400.0
const CAGE_LIGHT := Vector2(72.0, 0.8)          # radius px, strength
const TREASURE_LIGHT := Vector2(52.0, 0.7)
const BOTTOM_LIGHT := Vector2(300.0, 0.85)
const GLOW_Z := 11                              # above the darkness overlay (10)
const METAL := Color("aab4c4")
const METAL_DARK := Color("6c7488")
const OUTLINE := Color("3a2a44")
const GOLD := Color("ffd23f")
const WARM := Color("ffb45a")

## The Dragon Perch warms the Ice layer (set_ice_warm): softer, warmer darkness and drips.
const WARM_ICE_TINT := Color(0.55, 0.3, 0.12)
const WARM_ICE_DARK := 0.55                     # share of the band's darkness left
const WARM_ICE_BACK := Color(1.0, 0.62, 0.3, 0.16)
const DRIP_EVERY := 0.28
const DRIP := Color(0.75, 0.9, 1.0)

var u: Underground
var lamps: Array[Node2D] = []
var residents: Dictionary = {}       # StringName -> SheetSprite
var ice_warm := false
var _ice_back: Node2D                # warm wash over the Ice band's backdrop
var _ice_fx: Node2D                  # drips, above the darkness
var _drips: Array = []               # [{pos, vy, t, splash}]
var _drip_t := 0.0
var _rng := RandomNumberGenerator.new()


func build(p_u: Underground) -> void:
	u = p_u
	name = "Look"
	_backdrop()
	if SheetSprite.has_sheet("tiles/water.png"):
		u.world.water_texture = load(SheetSprite.ROOT + "tiles/water.png")
	_boulders()
	_treasures()
	_cage_lamps()
	_residents()


# --- backdrop ----------------------------------------------------------------------------------

func _backdrop() -> void:
	var file := "parallax/underground.png"
	if not SheetSprite.has_sheet(file):
		return
	var e := SheetSprite.entry(file)
	var strip := Vector2i(256, 128)
	if e.has("strip"):
		strip = Vector2i(int(e.strip[0]), int(e.strip[1]))
	var far_x := int(e.get("far", {}).get("x", 0))
	var near_x := int(e.get("near", {}).get("x", strip.x))
	var rows: Dictionary = e.get("rows", {})
	var img: Image = (load(SheetSprite.ROOT + file) as Texture2D).get_image()
	var shader: Shader = load(PARALLAX_SHADER)
	var w := Underground.WIDTH * 16.0
	var x0 := -BACK_MARGIN
	var mats := {}
	for f: Vector2 in [FAR_FACTOR, NEAR_FACTOR]:
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("factor", f)
		m.set_shader_parameter("anchor", Vector2(w * 0.5 - x0, 0.0))
		mats[f] = m
	var back := Node2D.new()
	back.name = "Parallax"
	back.z_index = -99
	u.add_child(back)
	u.move_child(back, 1)
	for i in u.layers().size():
		var l: LayerData = u.layers()[i]
		var row := int(rows.get(String(l.id), {}).get("row", i))
		var top := l.depth_from * 16.0
		var h := (mini(l.depth_to, Underground.HEIGHT) - l.depth_from) * 16.0
		for pair in [[far_x, FAR_FACTOR], [near_x, NEAR_FACTOR]]:
			var tex := ImageTexture.create_from_image(img.get_region(Rect2i(pair[0], row * strip.y, strip.x, strip.y)))
			var s := Sprite2D.new()
			s.name = "%s_%s" % [l.id, "far" if pair[1] == FAR_FACTOR else "near"]
			s.texture = tex
			s.centered = false
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			s.region_enabled = true
			# Strips end flush with the band's bottom.
			var off := fposmod(-h, strip.y)
			s.region_rect = Rect2(0, off, w + BACK_MARGIN * 2.0, h)
			s.position = Vector2(x0, top)
			s.material = mats[pair[1]]
			back.add_child(s)
	# The shaft over the backdrop: a darker column, so the elevator line reads.
	var shaft := ColorRect.new()
	shaft.name = "Shaft"
	shaft.color = Color(0.04, 0.03, 0.06, 0.6)
	shaft.position = Vector2(HillGenerator.SHAFT_X * 16.0, 0)
	shaft.size = Vector2(32, Underground.HEIGHT * 16.0)
	shaft.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(shaft)


# --- bodies and props --------------------------------------------------------------------------

func _boulders() -> void:
	for b in u.boulders:
		var s := SheetSprite.make("props/boulder.png")
		if s == null:
			return
		s.offset = -Vector2(SheetSprite.frame_size("props/boulder.png")) * 0.5
		s.turn_with = b
		b.self_modulate.a = 0.0
		b.add_child(s)


func _treasures() -> void:
	for id: StringName in u.props:
		var file := "treasures/%s.png" % id
		for prop: BreakableProp in u.props[id]:
			var size := Vector2(prop.footprint) * 16.0
			if SheetSprite.has_sheet(file):
				var s := Sprite2D.new()
				s.name = "Art"
				s.texture = load(SheetSprite.ROOT + file)
				s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				s.centered = false
				# Bottom-centred on the footprint whatever the sheet's size.
				s.position = Vector2((size.x - s.texture.get_width()) * 0.5, size.y - s.texture.get_height())
				prop.self_modulate.a = 0.0
				prop.add_child(s)
			var sp := SheetSprite.make("treasures/sparkle.png")
			if sp:
				sp.name = "Sparkle"
				sp.fps = 6.0
				sp.position = Vector2(size.x * 0.7, size.y * 0.3)
				sp.z_index = GLOW_Z + 1
				prop.add_child(sp)
			var lamp := _light_node(prop, size * 0.5, TREASURE_LIGHT, GOLD, 0.45)
			lamp.name = "Glow"


# --- cages -------------------------------------------------------------------------------------

func _cage_lamps() -> void:
	for i in u.generator.landings.size():
		var r := u.cage_rect(i)
		var l: LayerData = u.layers()[i]
		var lamp := _light_node(u, Vector2(r.position.x - 10, r.position.y + 4), CAGE_LIGHT, l.hue.lightened(0.45), 0.55)
		lamp.name = "CageLamp%d" % i
		lamps.append(lamp)


## Draws the restyled cages (A metal) on Underground's Cages node.
func draw_cages(c: Node2D) -> void:
	var x0 := HillGenerator.SHAFT_X * 16.0
	for i in u.generator.landings.size():
		var r := u.cage_rect(i)
		r.size.y -= 4
		var flash := u.cage_flash if i == u.flash_layer else 0.0
		if i > 0:
			var top := u.generator.landing_floor(i - 1) * 16.0 + 16.0
			for rx in [x0 + 2.0, x0 + 29.0]:
				c.draw_rect(Rect2(rx - 1, top, 3, r.position.y - 3 - top), OUTLINE)
				c.draw_rect(Rect2(rx, top, 1, r.position.y - 3 - top), METAL_DARK)
		# Frame: outline, metal posts, a gold header bar with the layer's colour lamp housing.
		c.draw_rect(r.grow(2.0), OUTLINE, false, 2.0)
		c.draw_rect(Rect2(r.position.x - 1, r.position.y - 4, r.size.x + 2, 4), OUTLINE)
		c.draw_rect(Rect2(r.position.x, r.position.y - 3, r.size.x, 2), GOLD)
		c.draw_rect(Rect2(r.position.x - 1, r.end.y, r.size.x + 2, 2), METAL_DARK)
		if flash > 0.0:
			c.draw_rect(r, Color(GOLD, 0.6 * flash))
		var drop := r.size.y * maxf(flash, 0.15)
		for k in 4:
			var x := r.position.x + 3 + k * (r.size.x - 7) / 3.0
			c.draw_rect(Rect2(x, r.position.y, 2, drop), METAL)
			c.draw_rect(Rect2(x + 1, r.position.y, 1, drop), METAL_DARK)
		var l: LayerData = u.layers()[i]
		var lp := Vector2(r.position.x - 10, r.position.y + 4)
		c.draw_rect(Rect2(lp + Vector2(-3, -5), Vector2(7, 9)), OUTLINE)
		c.draw_rect(Rect2(lp + Vector2(-2, -4), Vector2(5, 7)), l.hue.lightened(0.45))
		c.draw_rect(Rect2(lp + Vector2(-1, -3), Vector2(2, 2)), Color.WHITE)


# --- residents ---------------------------------------------------------------------------------

func _residents() -> void:
	# Mole: in the Topsoil landing room, left of the shaft.
	_resident(&"mole", "characters/mole.png", "idle", _floor_at(Vector2(u.landing(0).x - 72.0, u.landing(0).y)), -1)
	# The gnome crew (the Foreman is up top from the start): three of them walled into the gnome
	# room in Stone, in front of the prop, under UndergroundResidents' brick wall (z 7).
	var gr := _spot(&"gnome_room")
	if gr.size != Vector2i.ZERO:
		var cx := (gr.position.x + gr.size.x * 0.5) * 16.0
		for i in 3:
			var s := _resident(StringName("crew_%d" % i), "characters/foreman.png", "idle", Vector2(cx + (i - 1) * 18.0, gr.end.y * 16.0), 6, 1 if i < 2 else -1)
			s.scale = Vector2.ONE * UndergroundResidents.CREW_SCALE
			s.modulate = TownResidents.CREW_TINTS[i % TownResidents.CREW_TINTS.size()]
			s.name = "Crew%d" % i
		residents[&"foreman"] = residents[&"crew_0"]
	# Caveman: frozen in his ice block in the Ice landing room, right of the shaft.
	var ice := _layer_of(&"ice")
	if ice >= 0:
		_resident(&"caveman", "characters/caveman.png", "frozen", _floor_at(Vector2(u.landing(ice).x + 64.0, u.landing(ice).y)), -1)
	# Dragon: asleep on the floor of the Bottom cavern, right of the shaft, with a warm light.
	var cav := HillGenerator.CAVERN
	# The cavern's flat floor is its rect's bottom (pits under it stay hidden under her).
	var at := Vector2((cav.position.x + cav.size.x * 0.8) * 16.0, cav.end.y * 16.0)
	_resident(&"dragon", "characters/dragon.png", "asleep", at, -1)
	var warm := _light_node(u, at + Vector2(0, -48), BOTTOM_LIGHT, WARM, 0.3)
	warm.name = "BottomLight"


## Switches a resident's sprite to another row of its sheet (manifest rows), e.g. "frozen" -> "idle".
static func set_anim(s: SheetSprite, file: String, anim: String) -> void:
	var rows: Dictionary = SheetSprite.entry(file).get("rows", {})
	if s == null or not rows.has(anim):
		return
	var r: Dictionary = rows[anim]
	s.row = int(r.get("row", 0))
	s.frames = int(r.get("frames", 1))
	s.fps = float(r.get("fps", 0))
	if s.texture != null:
		s.frame_coords = Vector2i(0, s.row)


func _resident(id: StringName, file: String, anim: String, feet: Vector2, z := 0, face := 1) -> SheetSprite:
	var s := SheetSprite.make(file, anim)
	if s == null:
		# No sheet: an empty sprite still marks where the resident lives (their behaviour needs it).
		s = SheetSprite.new()
	s.name = String(id).capitalize()
	s.position = feet
	s.z_index = z
	s.flip_h = face < 0
	u.add_child(s)
	residents[id] = s
	return s


## The feet position on the first solid row at or below pos (cells of the base world).
func _floor_at(pos: Vector2) -> Vector2:
	var c := Vector2i(int(pos.x / 16.0), int(pos.y / 16.0))
	for k in 40:
		if u.world.is_solid(c + Vector2i(0, k)):
			return Vector2(pos.x, (c.y + k) * 16.0)
	return pos


func _spot(id: StringName) -> Rect2i:
	for s in u.generator.treasure_spots:
		if s.id == id:
			return s.rect
	return Rect2i()


func _layer_of(id: StringName) -> int:
	for i in u.layers().size():
		if (u.layers()[i] as LayerData).id == id:
			return i
	return -1


# --- lights ------------------------------------------------------------------------------------

## A registered light with an additive glow pool (fx/glow.png) on `parent` at `pos`.
func _light_node(parent: Node, pos: Vector2, light: Vector2, tint: Color, glow_alpha: float) -> Node2D:
	var n := Node2D.new()
	n.position = pos
	parent.add_child(n)
	u.world.add_light(n, light.x, light.y)
	if SheetSprite.has_sheet("fx/glow.png"):
		var g := Sprite2D.new()
		g.texture = load(SheetSprite.ROOT + "fx/glow.png")
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		g.material = mat
		g.modulate = Color(tint, glow_alpha)
		g.scale = Vector2.ONE * (light.x * 1.1 / g.texture.get_width())
		g.z_index = GLOW_Z
		g.z_as_relative = false
		n.add_child(g)
	return n


# --- the warm Ice layer ------------------------------------------------------------------------

## The Dragon Perch stands (Story.ice_warm): the Ice band's darkness turns warmer and softer, its
## backdrop gets a warm wash, and drips fall near players there. Off restores the data look.
func set_ice_warm(on: bool) -> void:
	if on == ice_warm:
		return
	ice_warm = on
	var bands: Array = []
	for l: LayerData in u.layers():
		var warm := on and l.id == &"ice"
		bands.append({"from": l.depth_from, "to": l.depth_to,
				"darkness": l.darkness * (WARM_ICE_DARK if warm else 1.0),
				"tint": WARM_ICE_TINT if warm else l.light_tint})
	u.world.set_darkness(bands)
	if on and _ice_back == null:
		_ice_back = Node2D.new()
		_ice_back.name = "IceWarm"
		_ice_back.z_index = -98
		_ice_back.draw.connect(_draw_ice_back)
		u.add_child(_ice_back)
		_ice_fx = Node2D.new()
		_ice_fx.name = "IceDrips"
		_ice_fx.z_as_relative = false
		_ice_fx.z_index = GLOW_Z
		_ice_fx.draw.connect(_draw_drips)
		u.add_child(_ice_fx)
		_rng.seed = 7311
	if _ice_back != null:
		_ice_back.visible = on
		_ice_fx.visible = on
		_drips.clear()


func _ice_band() -> Rect2:
	var i := _layer_of(&"ice")
	if i < 0:
		return Rect2()
	var l: LayerData = u.layers()[i]
	return Rect2(-BACK_MARGIN, l.depth_from * 16.0, Underground.WIDTH * 16.0 + BACK_MARGIN * 2.0, (mini(l.depth_to, Underground.HEIGHT) - l.depth_from) * 16.0)


func _draw_ice_back() -> void:
	_ice_back.draw_rect(_ice_band(), WARM_ICE_BACK)


func _process(delta: float) -> void:
	if not ice_warm or _ice_fx == null:
		return
	var band := _ice_band()
	_drip_t -= delta
	if _drip_t <= 0.0:
		_drip_t = DRIP_EVERY
		for c in u.players_root.get_children() if u.players_root != null else []:
			var at := u.to_local((c as Node2D).global_position)
			if band.has_point(at):
				_spawn_drip(at)
	for i in range(_drips.size() - 1, -1, -1):
		var d: Dictionary = _drips[i]
		d.t += delta
		if d.splash < 0.0:
			d.vy = minf(d.vy + 700.0 * delta, 420.0)
			d.pos.y += d.vy * delta
			var cell := Vector2i(int(d.pos.x / 16.0), int(d.pos.y / 16.0))
			if u.world.is_solid(cell) or d.t > 3.0:
				d.splash = 0.0
				d.pos.y = cell.y * 16.0
		else:
			d.splash += delta
			if d.splash > 0.3:
				_drips.remove_at(i)
	_ice_fx.queue_redraw()


## A drip from the nearest ceiling above a random spot near `at` (in air, under rock).
func _spawn_drip(at: Vector2) -> void:
	var x := at.x + _rng.randf_range(-220.0, 220.0)
	var c := Vector2i(int(x / 16.0), int(at.y / 16.0) - 1)
	for k in 10:
		var cell := c - Vector2i(0, k)
		if u.world.is_solid(cell):
			if k == 0:
				return
			_drips.append({"pos": Vector2(x, (cell.y + 1) * 16.0), "vy": 0.0, "t": 0.0, "splash": -1.0})
			return


func _draw_drips() -> void:
	for d in _drips:
		var p: Vector2 = d.pos
		if d.splash < 0.0:
			_ice_fx.draw_circle(p, 2.0, Color(DRIP, 0.85))
			_ice_fx.draw_line(p + Vector2(0, -1), p + Vector2(0, -4), Color(DRIP, 0.6), 1.5)
		else:
			var k: float = d.splash / 0.3
			_ice_fx.draw_arc(p, 2.0 + 5.0 * k, PI, TAU, 8, Color(DRIP, 0.8 * (1.0 - k)), 1.2)
