# Contracts

Shared signals and APIs that lanes code against. Systems lane owns this file. Change it in its
own PR before changing code; every other lane reads the merged version.

## Autoloads (always available)

### `Game` (`scripts/autoload/Game.gd`)

State machine for the whole session. Boots into `LOBBY` (the start screen / main menu,
`scenes/ui/lobby.tscn`) unless `--demo` is passed, which skips straight to a round.

```gdscript
enum State { LOBBY, PLAYING, PAUSED, ROUND_END, TITLE = 0 }   # TITLE: old name of LOBBY, deprecated
var state: State
var round_index: int
var demo: bool                  # --demo: skip the lobby, both players join as virtual players
signal state_changed(from: State, to: State)
signal round_started(round_index: int)
signal round_ended(round_index: int, result: Dictionary)   # result is game-defined
signal lobby_ready(players: Array)   # the lobby countdown finished; players = who readied up
signal back_to_lobby()               # pause menu Restart: clear the level, show the lobby
signal quit_requested()              # emitted just before a clean quit; last chance to save

func start_round() -> void
func end_round(result: Dictionary = {}) -> void
func pause() -> void
func resume() -> void
func restart() -> void          # Select: back to a fresh round, no questions asked
func to_lobby() -> void         # back to the start screen; round_index resets to 0
func finish_lobby(players: Array) -> void   # the lobby calls this: emits lobby_ready, starts round 1
func quit(code: int = 0) -> void            # Save.flush(), then exit; the launcher resumes
```

Start (`pause`) toggles `PLAYING` <-> `PAUSED`. The pause menu (`scenes/ui/pause_menu.tscn`) is a
text menu over the blurred game: Resume, Restart (`to_lobby()`), Settings, Back to Open Jar
("Leave the game?" Stay / Leave, then `quit()`). It shows who paused (`paused_by`). Either pad
moves the cursor; A selects; B backs out of Settings / the question, else resumes; Start resumes.
Window close also goes through `quit()`. Menus are for the grown-up: see `docs/ui.md`.

### Lobby (`scenes/ui/lobby.tscn`, `scenes/ui/lobby.gd`)

Start screen and main menu in one, a text menu for the grown-up (`docs/ui.md`). Title on top,
Play / Settings / Back to Open Jar in the middle, a join panel per player (P1 green left, P2 red
right) with "Press A to join", the player's character and READY.

- A on a new pad: that pad joins and is ready; its panel lights up and its character waves.
- B: un-ready (or back out of Settings / the question). Both ready: "Starting in 3, 2, 1", then
  `Game.finish_lobby(ready_players)`. Un-readying cancels.
- A held on Play for 1.5 s by a ready player starts without the other (Play fills up).
- Back to Open Jar asks "Leave the game?" (Stay focused first), Leave calls `Game.quit()`.
- Solo mode readies both. A pad that joins mid-game plays from the next round.

Hooks a game uses (keep the node names):

```gdscript
@export var title_texture: Texture2D        # the logo / key art; empty: title_text in the display face
@export var title_text: String              # empty: the project name
signal player_readied(player: int, ready: bool)
signal countdown_started()
signal countdown_cancelled()
# Spots/P1/Character, Spots/P2/Character: swap in your character. The lobby calls
# set_joined(on: bool) and wave() on it if it has them.
# Backdrop (hide it to show the level), TitleArt, Spots/P*/fill_alpha (0..1, see-through panels),
# Buttons/Play, Buttons/Settings, Buttons/Door, Settings, Confirm. Customise in _ready(), in code.
```

Theme: `UiStyle.accent = Color(...)` sets the game's accent (focus, sliders, progress). The rest
of the look is shared; see `docs/ui.md`.

### Settings (`scenes/ui/settings_panel.gd`, class `SettingsPanel`)

Music volume, sound volume, screen shake, solo playtest mode; in the lobby and the pause menu.
Per install, through `Save.set_setting()`, written the moment a value changes.

```gdscript
const MUSIC := "music_volume"     # 0..1, default 0.8 -> Audio "Music" bus
const SOUND := "sound_volume"     # 0..1, default 1.0 -> Audio "SFX" bus
const SHAKE := "screen_shake"     # bool, default true
const SOLO := "solo_playtest"     # bool, default false; on at boot turns Players solo on
static func screen_shake() -> bool  # games check this before shaking the camera
```

### `Players` (`scripts/autoload/Players.gd`)

Who is holding which controller. Never read device ids directly.

```gdscript
const P1 := 0
const P2 := 1
const COLOR := { P1: Color("3cc24a"), P2: Color("e4393c") }   # green, red
const VIRTUAL := -2             # device of a keyboard or --demo player

signal player_joined(player: int, device: int)
signal player_left(player: int)
signal solo_changed(on: bool)

var solo: bool                  # playtest only: one pad plays both players
var solo_focus: int             # the player the solo pad drives right now; the game sets it

func is_active(player: int) -> bool
func device_of(player: int) -> int
func active_players() -> Array[int]
func action(player: int, action: String) -> String   # "p1_move_left" etc. for Input.*
func move_vector(player: int) -> Vector2
func join_virtual(player: int) -> void
func set_solo(on: bool, device: int = VIRTUAL) -> void
func set_solo_focus(player: int) -> void   # the game calls this when the other player's turn comes
func reset() -> void                       # tests: nobody joined, solo off, InputMap restored
```

Solo mode: `--solo` on the command line, or hold Select + Start together for 2 s on a pad (again
to turn it off). Both players join on that pad; only `solo_focus`'s actions get its events. A
two-heads icon shows top-left while it is on. A keyboard key from a player's action joins that player.

Input map actions (defined in `project.godot`, per player, prefix `p1_` / `p2_`):
`move_left`, `move_right`, `move_up`, `move_down`, `action`, `jump`.
Global: `pause`, `restart`, `debug_overlay`, `debug_screenshot`.

### `Save` (`scripts/autoload/Save.gd`)

JSON under `user://saves/<profile>.json`. Autosave at every natural stopping point.

```gdscript
var profile: String                 # set by the launcher via --profile=<id>, default "p1"
signal saved()
signal loaded()

func get_value(key: String, default = null)
func set_value(key: String, value) -> void   # marks dirty
func flush() -> void                         # writes if dirty; Game.end_round() calls this
func wipe() -> void

# Per install, not per profile: user://settings.json, written on every set_setting().
var settings_path: String                    # tests point this elsewhere
func get_setting(key: String, default = null)
func set_setting(key: String, value) -> void
func reload_settings() -> void
func wipe_settings() -> void
```

### `Audio` (`scripts/autoload/Audio.gd`)

```gdscript
func play(cue: String, position = null) -> void   # cue = file stem in assets/audio/sfx/
func music(track: String, fade: float = 0.5) -> void
func stop_music(fade: float = 0.5) -> void
func bark(character: String, bark: String) -> void   # from openjar-characters voice packs
func set_volume(bus: String, linear: float) -> void  # "Music" / "SFX", 0..1; Settings calls it
func get_volume(bus: String) -> float
```

Audio creates the `Music` and `SFX` buses at start if the project has no bus layout, and applies
the saved volumes.

Every action must call `Audio.play`. Missing cue files log a warning (once per cue), never crash.
While `synth_missing` is on (the default), a missing SFX cue plays a short synth beep whose pitch
comes from the cue name, so placeholder builds are never silent; a real file replaces it by existing.

```gdscript
var synth_missing: bool = true                       # false: missing cues are silent
func has_cue(cue: String) -> bool                    # a real file exists for this SFX cue
```

Menu cues (Audio lane supplies the files): `ui_move`, `ui_confirm`, `ui_back`, `player_join`,
`player_ready`, `player_unready`, `count_tick`, `round_start`, `pause`, `solo_on`, `solo_off`.

### `Debug` (`scripts/autoload/Debug.gd`)

F3 toggles the overlay (fps, state, player count). F12 saves `user://screenshots/<timestamp>.png`
and prints the path. `--screenshot-after=<seconds>` CLI flag does it headlessly for the Reviewer.

### Boot flags (user args, after `--`; an exported binary takes them directly)

`--demo` (skip the lobby, two virtual players), `--solo`, `--profile=<id>`, `--shots=`,
`--shot-dir=`, `--screenshot-after=`, and for The Hill: `--proto` boots
`scenes/proto/foundation_proto.tscn` (the Phase 1 risk prototype) instead of the lobby, and
`--proto-auto` does the same with a scripted, input-free run-through (for shots and smoke boots).

## Launcher handshake

The launcher starts a game with `--profile=<id>` and expects the game to:

- read `store/openjar.json` at export time (name, version, card art, clip) — produced by CI;
- exit with code 0 on a clean quit (`Game.quit()`: the door button in the lobby or the pause menu);
- not change display mode (the launcher owns fullscreen).

## Game-specific contracts

The Hill. Three parts: the game's signal bus and autoloads, the data schemas, and the two
game-agnostic modules under `addons/openjar/` (they move to `openjar-addons` unchanged, so they
never reference a game autoload, `Players`, `Audio` or `Events`; the game wires them).

### `Events` (`scripts/autoload/Events.gd`): the signal bus

Emitters call `Events.<signal>.emit(...)`; anyone may connect. `player` is `Players.P1`/`P2`,
or `-1` for "nobody" (gnome crew, a falling boulder).

```gdscript
signal tile_dug(cell: Vector2i, block: StringName, player: int)
signal treasure_found(id: StringName, player: int)
signal inventory_changed(block: StringName, count: int)
signal building_placed(id: StringName, cell: Vector2i)
signal building_moved(id: StringName, from: Vector2i, to: Vector2i)
signal vehicle_unlocked(id: StringName)
signal entered_scene(player: int, scene: StringName)   # &"hillville" | &"underground"
signal split_changed(is_split: bool)
signal resident_encountered(id: StringName, count: int)
signal resident_arrived(id: StringName)
signal ruin_restored(id: StringName, resident: StringName)
signal dragon_woken()
```

### `Inventory` (`scripts/autoload/Inventory.gd`): the shared block pile

One pile for both players. A cost is always `Dictionary[StringName, int]` (block id -> count).

```gdscript
func count(block: StringName) -> int
func add(block: StringName, n: int = 1) -> void      # emits Events.inventory_changed
func can_afford(cost: Dictionary) -> bool            # {} is affordable
func spend(cost: Dictionary) -> bool                 # all or nothing; false changes nothing
func to_save() -> Dictionary                         # {"dirt": 12, ...}
func load_save(data: Dictionary) -> void
func clear() -> void
```

### `World`: the underground

`World` in GAME.md is the underground scene's `TileWorld` node (below). It is in the group
`&"tile_world"`; the game connects its `tile_dug` to `Events.tile_dug` and `Inventory.add`.
`World.dig(cell, shape, player)` is `TileWorld.dig`.

### Data schemas (`scripts/data/*.gd`, rows in `data/`)

All are `Resource` classes with `@export` fields; ids are `StringName` and equal the file stem.
Costs and requirements are data, never code. Content lane owns the rows.

```gdscript
class_name BlockData extends TileDef        # data/blocks/<id>.tres. TileDef gives: id, color, solid, breakable
@export var dig_sound: StringName           # Audio cue, e.g. &"dig_dirt"
@export var depth_from: int                 # tiles; where it starts to appear
@export var depth_to: int
@export var value: int = 1                  # relative worth (BALANCE.md), never shown as a number
@export var dig_tier: int = 0               # lowest VehicleData.dig_tier that can remove it (0 = shovel)
@export var slippery: bool = false          # ice
@export var bouncy: bool = false            # lava pockets
@export var breakable_from_version: String = ""   # "" = by the `breakable` flag; else unbreakable until that game version
func is_breakable_in(version: String) -> bool     # breakable, or version >= breakable_from_version (semver compare)

class_name LayerData extends Resource       # data/layers/<id>.tres, ordered by depth_from
@export var id: StringName
@export var depth_from: int
@export var depth_to: int                   # exclusive
@export var block_mix: Dictionary           # block id -> weight (float)
@export var hazards: Array[StringName]      # &"water_pocket", &"boulder", &"mole", &"lava" ...
@export var darkness: float                 # 0 daylight .. 1 black, before Lighthouses
@export var light_tint: Color = Color.BLACK # colour of the darkness (blue glow in Ice)
@export var snore_volume: float             # 0..1, dragon_snore loudness in this layer
@export var hue: Color                      # the layer's dominant hue (art direction, depth strip)
func contains(depth: int) -> bool

class_name TreasureData extends Resource    # data/treasures/<id>.tres
@export var id: StringName
@export var layer: StringName
@export var sprite: Texture2D
@export var footprint: Vector2i = Vector2i.ONE     # tiles; > 1x1 is a multi-tile prop that breaks into chunks
@export var unlocks: StringName             # building / vehicle / resident id, or &""
@export var count: int = 1                  # how many the seed places in the layer
@export var museum_text: String             # for Hermes and the grown-up only, never on the kid's screen

class_name BuildingData extends Resource    # data/buildings/<id>.tres
@export var id: StringName
@export var footprint: Vector2i             # ground-grid cells, width x height
@export var cost: Dictionary                # block id -> count
@export var needs_treasure: StringName      # &"" or a TreasureData id that must be found first
@export var needs_vehicle: StringName       # &"" or the vehicle that can place it (crane for tall ones)
@export var effect: StringName              # &"backpack", &"next_vehicle", &"light_layer", &"dig_power", &"drain", &"gnome_crew", &"museum", &"warm_ice", &""
@export var effect_amount: float = 1.0
@export var scene: PackedScene
@export var is_ruin: bool = false           # a ruin: unclearable, unbuildable, restored instead of built
@export var resident: StringName            # ruins only: who it is for
@export var restores_into: StringName       # ruins only: the BuildingData id it becomes
func can_show_in_book(found_treasures: Array, resident_phase: int) -> bool

class_name VehicleData extends Resource     # data/vehicles/<id>.tres
@export var id: StringName
@export var order: int                      # 0 Front Loader .. 4 Drill Rig; Garage N unlocks order N
@export var dig_shape: Array[Vector2i]      # offsets for a dig facing right/down; rotated by the aim
@export var dig_tier: int                   # removes BlockData with dig_tier <= this
@export var clear_area: Vector2i            # up top, tiles
@export var speed: float                    # px/s
@export var carry: float                    # backpack multiplier
@export var needs_treasure: StringName      # extra unlock requirement, or &""
@export var works_up_top: bool = true       # false: Drill Rig parks at the shaft
@export var sounds: Dictionary              # &"engine" | &"horn" | &"dig" -> Audio cue
@export var scene: PackedScene

class_name ResidentState extends Resource   # one per resident, saved; Story.gd drives it
enum Phase { UNMET, ENCOUNTERED, ARRIVED, RESTORED }
@export var id: StringName
@export var phase: Phase = Phase.UNMET
@export var encounters: int = 0
@export var encounters_to_arrive: int = 1   # the Mole: 3
func encounter() -> bool                    # counts one; true when this call moved it to ARRIVED
func restore() -> bool                      # ARRIVED -> RESTORED; false from any other phase
func to_save() -> Dictionary                # {"phase": 1, "encounters": 2}
func load_save(data: Dictionary) -> void
```

`data/blocks/` includes `edgestone` and `strangestone` with `breakable = false`.

### The restore-cost rule (`scripts/data/rules.gd`, `class_name Rules`)

A ruin is a `BuildingData` with `is_ruin`. Its restore card is in the build book only while its
resident is `ARRIVED`. Its `cost` may only name blocks from layers at or above the layer where
the resident is met, so it is payable the moment they arrive. Paying is `Inventory.spend(cost)`,
then `ResidentState.restore()`, then `Events.ruin_restored`. It never times out, costs nothing
to delay, and a restored ruin cannot be moved or undone.

```gdscript
static func can_restore(ruin: BuildingData, state: ResidentState, afford: bool) -> bool
static func restore_cost_is_fair(ruin: BuildingData, met_depth: int, blocks: Array) -> bool   # content test
```

### The gnome-crew rule

On load, once the Gnome Village stands: `away = now - Save "gnome_stamp"` (unix seconds).

```gdscript
const GNOME_MIN_AWAY := 1800.0      # under 30 minutes: nothing, no clip
const GNOME_FLOOR := 20
const GNOME_CAP := 50
const GNOME_RATE := 10.0            # blocks per hour away
static func gnome_award(away_seconds: float, cap_bonus: int = 0) -> int
# away < GNOME_MIN_AWAY (or negative: the clock moved) -> 0
# else clampi(roundi(GNOME_RATE * hours), GNOME_FLOOR, GNOME_CAP + cap_bonus)
```

Blocks are drawn from the deepest visited layer's `block_mix`. `cap_bonus` is the adjacency
bonus (barns beside the village). The stamp resets on every save, so it rewards coming back,
never idling. A pile appears at the shaft with the march clip; never a number.

### Save keys (`Save.set_value`)

`"world"` (`TileWorld.to_save()`), `"inventory"`, `"treasures"` (found ids), `"buildings"`
(`[{id, cell:[x,y]}]`), `"vehicles"` (unlocked ids), `"players"` (`[{deepest, scene}]`),
`"gnome_stamp"`, `"residents"` (`{id: ResidentState.to_save()}`), `"seed"`.

## Module: TileWorld (`addons/openjar/tileworld/`)

A chunked, diggable 2D tile world. Game-agnostic: The Hill uses it with a rectangle, Life of a
Worm with a disk. Cells are `Vector2i` on one plain Cartesian grid (`cell_size` px squares, y
down) for every shape; tile ids are `int`, `0` is air, and index a palette of `TileDef`.

```gdscript
class_name TileDef extends Resource         # one kind of tile
@export var id: StringName
@export var color: Color
@export var solid: bool = true
@export var breakable: bool = true

class_name WorldShape extends RefCounted    # which cells exist, how they group, which way is down
var cell_size: int = 16
func contains(cell: Vector2i) -> bool
func chunk_of(cell: Vector2i) -> Vector2i                  # the chunk key
func chunk_cells(key: Vector2i) -> Array[Vector2i]         # every cell of that chunk
func neighbourhood(key: Vector2i, radius: int = 1) -> Array[Vector2i]   # live chunks around a tracked node
func gravity_at(pos: Vector2) -> Vector2                   # px/s^2 at a world position
func below(cell: Vector2i) -> Vector2i                     # the cell that supports this one
func sides(cell: Vector2i) -> Array[Vector2i]              # the two cells level with it (water spreads there)
func depth_of(cell: Vector2i) -> int                       # tiles below the surface
func cell_at(pos: Vector2) -> Vector2i
func center_of(cell: Vector2i) -> Vector2
# RectShape.new(width, height, chunk_size = 32): keys are (cx, cy), gravity straight down.
# DiskShape.new(radius, band = 32): keys are (ring, sector), gravity toward the origin.

class_name WorldGenerator extends RefCounted   # the seeded base world; the game subclasses it
func setup(shape: WorldShape, world_seed: int) -> void
func base_tile(cell: Vector2i) -> int          # deterministic; must not depend on call order
func base_water(cell: Vector2i) -> bool        # true: this air cell starts full of water
func base_chunk(cells: Array[Vector2i]) -> PackedInt32Array   # a chunk at once: base_tile | WATER_BIT if base_water; override for speed

class_name TileWorld extends Node2D
signal tile_dug(cell: Vector2i, block: StringName, player: int)       # block = TileDef.id
signal dig_blocked(cell: Vector2i, block: StringName, player: int)    # unbreakable: bounce + sparkle
signal chunk_loaded(key: Vector2i)
signal chunk_freed(key: Vector2i)
signal body_landed(body: Node2D, speed: float)                        # fall / bonk cue
signal prop_broke(prop: Node2D, pieces: Array)
signal water_entered(cell: Vector2i)                                  # a pocket opened: flood cue

var shape: WorldShape
var max_awake_bodies: int = 60
var chunk_radius: int = 1                     # 1 = 3x3 around each tracked node
func setup(shape: WorldShape, generator: WorldGenerator, palette: Array[TileDef], world_seed: int) -> void
func get_tile(cell: Vector2i) -> int          # edits over the base; 0 outside the shape
func is_solid(cell: Vector2i) -> bool
func set_tile(cell: Vector2i, id: int) -> void             # records an edit (or clears it if id == base)
func dig(cell: Vector2i, shape: Array[Vector2i] = [Vector2i.ZERO], player: int = -1) -> Array[Vector2i]
     # removes every breakable solid tile at cell + offset; returns the cells removed
func track(node: Node2D) -> void              # keep chunks alive around it
func untrack(node: Node2D) -> void
func loaded_chunks() -> Array[Vector2i]
func update_chunks() -> void                  # runs every physics frame; tests call it directly
func add_body(body: FallingBody) -> void      # also done by FallingBody on entering the tree under a TileWorld
func awake_bodies() -> int
func has_water(cell: Vector2i) -> bool
func set_water(cell: Vector2i, on: bool) -> void
func water_count() -> int
func buoyancy_at(pos: Vector2) -> Vector2     # ZERO when dry; else against gravity_at(pos), stronger
func step_water() -> void                     # one cellular tick (10 Hz by default)
var drain_per_second: float = 0.0             # cells removed per second from open water (Water Towers raise it)
func set_darkness(bands: Array) -> void       # [{from: int, to: int, darkness: float, tint: Color}] by depth_of
func darkness_at(depth: int) -> float
func add_light(node: Node2D, radius_px: float) -> void    # a headlamp: a hole in the dark that follows node
func remove_light(node: Node2D) -> void
func to_save() -> Dictionary                  # {"seed", "edits": [x, y, id, ...], "water": [x, y, on, ...]}: only differences from the base
func load_save(data: Dictionary) -> void

class_name FallingBody extends RigidBody2D    # boulders, treasures, prop pieces
# Uses shape.gravity_at(position), never the project gravity. Sleeps when resting on a solid tile;
# wakes when a tile it rests on is removed (dig or set_tile), never on its own. Frozen while its
# chunk is not loaded. Never more than max_awake_bodies awake (also when physics wakes them); the rest wait their turn.

class_name BreakableProp extends Node2D       # a multi-tile prop: the car, the gnome room's wall
@export var footprint: Vector2i               # tiles
@export var support_needed: float = 0.5       # breaks when less than this share of the cells under it is solid
# On breaking: one FallingBody piece per footprint cell, prop_broke, then the prop frees itself.
```

Rules worth knowing: only chunks within `chunk_radius` of a tracked node have `TileMapLayer`
nodes and collision; `get_tile`/`set_tile`/`dig`/save work everywhere. The chunk manager only
ever talks to `WorldShape` (`chunk_of`, `chunk_cells`, `neighbourhood`), so a new shape is a new
`WorldShape` subclass and nothing else. Water is a set of full cells: it moves to `below`, else
to a free `sides` cell; the count never grows, it never enters a solid tile or leaves the shape.

## Module: split screen (`addons/openjar/split_screen/`)

```gdscript
class_name ScreenDirector extends Control     # full-rect; the game adds one (The Hill: in the play scene)
signal split_changed(is_split: bool)          # when the decision flips (the tween starts)
signal entered_scene(player: int, scene: StringName)

@export var tween_time: float = 0.3
@export var zoom: float = 2.0                 # whole numbers for pixel art
@export var join_at: float = 0.6              # join when both fit inside this share of one screen...
@export var split_at: float = 0.8             # ...split when they pass this share (no flicker in between)
var colors: Array[Color]                      # per player; default green, red
var split_amount: float                       # 0 one view .. 1 fully split (read-only; the tween)

func add_scene(id: StringName, root: Node) -> void        # the director hosts it; it keeps ticking, seen or not
func scene_root(id: StringName) -> Node
func add_player(player: int, node: Node2D, scene: StringName) -> void   # reparents node under that scene
func remove_player(player: int) -> void
func move_player(player: int, scene: StringName, position: Vector2) -> void   # the elevator; emits entered_scene
func scene_of(player: int) -> StringName
func is_split() -> bool
func camera_of(player: int) -> Camera2D
func view_rect_of(player: int) -> Rect2       # where that player's view is on screen right now (HUD anchoring)
static func wants_split(was_split: bool, same_scene: bool, offset: Vector2, screen_world: Vector2,
		players: int, join_at: float = 0.6, split_at: float = 0.8) -> bool
```

| Situation | Screen |
| --- | --- |
| One player | Full screen, always |
| Same scene, both inside `join_at` of one screen | One camera on the midpoint |
| Same scene, past `split_at` of one screen on either axis | Split |
| Between the two | Whatever it was |
| Different scenes | Split, each half its own scene |

Split is always player 0 left, player 1 right, with a divider in the two players' colours. Each
scene lives in its own world (own physics space), so two scenes never collide with each other.
