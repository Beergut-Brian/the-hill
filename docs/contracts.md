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

Start screen and main menu in one, the Showtime menu kit (`docs/ui.md`): the game's slanted title
over a stage (sunburst, and the game's world blurred behind it if the skin asks), each player's
`Roster` pick (P1 green ring, left; P2 red, right; Jeff and Chuck by default) on podiums with name
plates and READY! stamps, and a wedge of slanted bars: Play / Settings / Back to Open Jar.

- A on a new pad: that pad joins and is ready; its podium lights up and its character waves.
- Left / right while joined and not ready: the character chooser (`Roster`, above).
- B: un-ready (or back out of Settings / the question). Both ready: a 3-beat countdown; on the last
  beat the stamps say GO!, both characters cheer, the three-stripe wipe covers the screen and
  `Game.finish_lobby(ready_players)` starts round 1 (with the skin's "ROUND 1" card). Un-readying
  cancels, except during the last beat.
- A held on Play for 1.5 s by a ready player starts without the other (Play fills up).
- Back to Open Jar asks "Leave the game?" (Stay focused first), Leave calls `Game.quit()`.
- Solo mode readies both. A pad that joins mid-game plays from the next round. Solo is never
  turned on at boot by the saved setting (playtest only): only `--solo` or Select + Start.

The look per game comes from one resource, `MenuSkin` (`scenes/ui/kit/menu_skin.gd`): title,
accent / sunburst / deep colours, the two character scenes and names, the backdrop
(`SUNBURST`, `SCENE` live world, `TEXTURE` still, `SCREEN` the level behind), the round card.
`res://data/menu_skin.tres` is used automatically; or `UiStyle.use_skin(skin)` in code.

```gdscript
@export var title_texture: Texture2D        # wins over the skin's title
@export var title_text: String              # wins over the skin's title
var round_card_subtitle: String             # "JEFF KICKS FIRST" under ROUND 1; set in code
var round_card_color: Color                 # its strip colour (default the skin's accent2)
signal player_readied(player: int, ready: bool)
signal countdown_started()
signal countdown_cancelled()
signal launching()                          # the last beat: the wipe is starting
# Spots/P1/Character, Spots/P2/Character: CharacterSlots hosting the skin's characters, by default
# the player's Roster pick; the lobby calls set_joined(on: bool), wave() and cheer() on the
# character if it has them, and set_character(id: String) when the pick changes.
# Backdrop, Wedge, TitleArt, Buttons/Play, Buttons/Settings, Buttons/Door, Settings, Confirm.
```

`ShowtimeWipe.run(on_cover, title, subtitle, color)` plays the same wipe anywhere (between rounds).
`UiSound.play(cue, pitch)` plays a menu cue: the `.ogg` in `assets/audio/sfx/` if there is one,
else a synthesized stand-in (cue list in `docs/ui.md`).

### Settings (`scenes/ui/settings_panel.gd`, class `SettingsPanel`)

Music volume, sound volume, screen shake, solo playtest mode; in the lobby and the pause menu.
Per install, through `Save.set_setting()`, written the moment a value changes.

```gdscript
const MUSIC := "music_volume"     # 0..1, default 0.8 -> Audio "Music" bus
const SOUND := "sound_volume"     # 0..1, default 1.0 -> Audio "SFX" bus
const SHAKE := "screen_shake"     # bool, default true
const SOLO := "solo_playtest"     # bool, default false; the toggle in Settings. Not restored at boot
static func screen_shake() -> bool  # games check this before shaking the camera
```

### `Roster` (`scripts/autoload/Roster.gd`)

Who each player is: the playable characters (from `openjar-characters`, vendored by
`scripts/tools/sync_characters.sh` into `assets/characters/<id>/` and `data/roster.json`) and each
slot's pick. Player colours stay with the slot (`Players.COLOR`), never the character.

```gdscript
signal pick_changed(player: int, id: String)
signal said(player: int, id: String, path: String)   # a voice line started; player -1: shared voice

var data_path := "res://data/roster.json"   # tests point this at a fixture, then reload()
var picks_path: String                       # the shared file; tests/scripted runs: user:// (boot_picks_path)
var characters_tag: String                   # the openjar-characters tag the roster came from

func roster() -> Array[String]               # playable ids in chooser order
func has(id: String) -> bool
func info(id: String) -> Dictionary          # {} if unknown, else:
	# id, name ("Jeff"), glb ("res://assets/characters/jeff/jeff.glb" or ""),
	# pixel ("res://assets/characters/jeff/pixel.png" or ""), voice ("res://.../voice/" or ""),
	# barks (Array of file stems in voice/), catchphrase ("res://.../voice/catchphrase.ogg" or ""),
	# default_for (1, 2 or 0)
func default_for(player: int) -> String      # data/roster.json defaults.P1 / .P2
func pick(player: int) -> String             # never "" while the roster has a character
func set_pick(player: int, id: String) -> bool   # false (no change) if unknown or the other's pick
func next_free(player: int, dir: int) -> String  # dir +1 / -1 through roster(), skipping the
                                                 # other player's pick; pick(player) if none free
func taken(id: String, by_other_than: int) -> bool
func reload() -> void                        # re-read roster.json, args, the shared file
func bark(id: String, player := -1) -> bool  # plays a random voice bark; false if it has none
func catchphrase(id: String, player := -1) -> bool  # the catchphrase, else bark(); false if neither
func voice_player(player := -1) -> AudioStreamPlayer  # P1 / P2: that slot's own panned voice
                                                 # (VoiceP1 / VoiceP2 bus); -1: the shared one.
                                                 # A new line cuts off only that voice's last one
var last_said: Dictionary                    # voice (player or -1) -> res:// path of its last line
```

**Resolving a slot** at start (`reload()`), first hit that is in `roster()`:
1. `--p1-char=<id>` / `--p2-char=<id>` (either side of `--`)
2. the shared file `players.json[Save.profile]["P1" | "P2"]`
3. `defaults.P1` / `defaults.P2`
4. the first roster id the other player has not got

Unknown, removed or resident ids are skipped, never an error. If both slots resolve to the same
id, P2 moves to `next_free(P2, 1)`. No two players are ever the same character.

**The shared picks file** (`picks_path`): `OS.get_data_dir() + "/openjar/players.json"` (Linux
`~/.local/share/openjar/players.json`), outside every game's `user://`. Shared with every Open Jar
game and the launcher:

```json
{ "p1": { "P1": "jeff", "P2": "chuck" }, "kid": { "P1": "chuck", "P2": "jeff" } }
```

Keyed by save profile, then slot. Written the moment a pick changes (`set_pick`): read the file,
change only this profile's slot, keep every other key, write `players.json.tmp`, rename over
`players.json` (folder created if missing). A missing or broken file reads as empty. Roster never
touches the game's own `user://` saves.

**Launch args**: the launcher passes `--profile=<id> --p1-char=<id> --p2-char=<id>`. They win over
the file; a pick changed in the game is still written to the file.

**Spawning the chosen character** (game code; `docs/ui.md` "Per game"):

```gdscript
var who := Roster.info(Roster.pick(player))
var body: Node = load(who.glb).instantiate()      # 3D; a pixel game uses load(who.pixel)
add_child(body)
```

**The chooser** (lobby): joined and not ready, left / right (stick or D-pad) calls
`Roster.set_pick(p, Roster.next_free(p, dir))`; the podium swaps with a squash/pop and a poof, the
plate shows the new name, the `char_swap` cue plays, and `SAY_SETTLE` (0.3 s) after the last step
the character says `Roster.catchphrase(id, p)` once (`docs/ui.md` "Chooser voice"). Ready: left / right does
nothing; B un-readies. Solo: Select picks which podium the pad drives (A, B and left / right).

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
var settings_path: String                    # tests point this elsewhere; scripted runs boot on user://scratch_settings.json
func get_setting(key: String, default = null)
func set_setting(key: String, value) -> void
func reload_settings() -> void
func wipe_settings() -> void
```

### `Audio` (`scripts/autoload/Audio.gd`)

```gdscript
func play(cue: String, position = null, volume_db: float = 0.0) -> bool  # false: rate-capped / nothing
func music(track: String, fade: float = 0.5) -> void       # one file, looped (menus)
func stop_music(fade: float = 0.5) -> void
func music_state(theme: StringName, zone: int, cavern: bool, fade: float = 1.5) -> void
	# theme &"up" | &"down"; zone 0 (Topsoil)..N brings in music_down_layer_1..zone; cavern adds
	# music_cavern. One AudioStreamSynchronized, crossfaded by stream volume. HillAudio drives it.
func engine(key, cue: String) -> void                      # looped engine per key (a player id)
func engine_speed(key, speed: float) -> void               # 0..1 -> pitch ENGINE_PITCH, level up
func engine_stop(key) -> void
func bark(character: String, cue: String) -> bool          # one line on the Voice bus, rate-capped
	# voice pack first (Roster info voice dir, else assets/characters/<id>/voice/<cue>[_n].ogg),
	# else the placeholder assets/audio/voice/<id>_<cue>[_n].ogg; false when skipped
func duck(db: float, secs: float) -> void                  # pull the music down (DUCKS does it per cue)
func set_volume(bus: String, linear: float) -> void        # "Music" / "SFX" (Voice follows SFX), 0..1
func get_volume(bus: String) -> float
```

Audio creates the `Music`, `SFX` and `Voice` buses at start if the project has no bus layout, puts
a hard limiter (-1 dB ceiling) on Master and a duck amplifier on Music, and applies the saved
volumes. A cue name is the file stem in `assets/audio/sfx/` (`.ogg`, or `.wav` for seamless loops);
`cue_1..cue_N` are variants, rotated without an immediate repeat. `ALIASES` map the GAME.md design
names (`engine_<vehicle>`, `horn_<vehicle>`, `gnome_whistle`, `tip`, `build_move`) onto the cue
names the code plays. Every cue has a rate cap (`CAPS`: minimum gap, maximum voices); the list of
cues, caps and ducks is `assets/audio/CUES.md`.

Every action must call `Audio.play`. Missing cue files log a warning (once per cue), never crash.
While `synth_missing` is on (the default), a missing SFX cue plays a short synth beep whose pitch
comes from the cue name, so placeholder builds are never silent; a real file replaces it by existing.

```gdscript
var synth_missing: bool = true                       # false: missing cues are silent
func has_cue(cue: String) -> bool                    # a real file exists for this SFX cue
```

Menu cues (Audio lane supplies the files): `ui_move`, `ui_confirm`, `ui_back`, `player_join`,
`player_ready`, `player_unready`, `count_tick`, `round_start`, `pause`, `solo_on`, `solo_off`.

Resident-arc cues (the arcs lane plays them, the Audio lane supplies the files): `plank` once per
plank of a restore (four rising variants), `light_on` when the restored building lights up,
`resident_arrive`, `resident_hope` / `resident_hm` / `resident_happy` / `resident_cheer` for the
picture bubbles, `payoff_mole` / `payoff_caveman` / `payoff_gnomes` / `payoff_dragon`.
`HillAudio` already plays `resident_arrive` on `Events.resident_arrived` and `light_on` +
`payoff_<resident>` on `Events.ruin_restored`, so the arcs lane only adds the per-plank call.

### `Debug` (`scripts/autoload/Debug.gd`)

F3 toggles the overlay (fps, state, player count). F12 saves `user://screenshots/<timestamp>.png`
and prints the path. `--screenshot-after=<seconds>` CLI flag does it headlessly for the Reviewer.

### Boot flags (user args, after `--`; an exported binary takes them directly)

`--demo` (skip the lobby, two virtual players), `--solo`, `--profile=<id>`, `--shots=`,
`--shot-dir=`, `--screenshot-after=`, and for The Hill: `--proto` boots
`scenes/proto/foundation_proto.tscn` (the Phase 1 risk prototype) instead of the lobby, and
`--proto-auto` does the same with a scripted, input-free run-through (for shots and smoke boots).
`--p1-char=<id>` / `--p2-char=<id>` (Roster, see below) pick the characters, and The Hill's
`--roster-data=res://tests/fixtures/<file>.json` (Debug.gd) swaps in a test roster such as the
stand-in "Pip"; it is ignored when the file is missing, so an export (no `tests/`) never honours it.
`--demo` boots straight into the game with both players virtual and plays the first-playable
path by script (clear scrub, ride down, dig to Clay, find the car, ride up, build a Barn and a
Garage, the Excavator rolls out); it starts from a wiped save in a throwaway profile (`demo`).

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
`&"tile_world"`; the game connects its `tile_dug` to `Events.tile_dug` and to the digging
player's backpack (below). `World.dig(cell, shape, player)` is `TileWorld.dig`.

### Backpack and the shaft pile

Each player carries a backpack underground. A dug block goes into the digger's backpack; when it
is full the block still pops out of the ground with its sound, but is not kept (the backpack icon
turns round and happy, digging never stops). Riding the elevator up empties every rider's
backpack into `Inventory` (the shaft pile). Up top, scooped scrub goes straight to `Inventory`.
Capacity is `Progress.backpack_capacity()`: `(BACKPACK_START + barns) * BACKPACK_PER_SIZE`
blocks, so a Barn's "+1 backpack size" is +20 blocks.

### `Progress` (`scripts/autoload/Progress.gd`): run state

Everything saved that is not tiles or blocks. Emits the `Events` signals for what it owns.

```gdscript
const BACKPACK_START := 2
const BACKPACK_PER_SIZE := 20
signal changed()
var treasures: Array[StringName]         # found ids
var vehicles: Array[StringName]          # unlocked ids, always has &"front_loader"
var buildings: Array                     # [{"id": StringName, "cell": Vector2i}]; index = handle
var deepest: Dictionary                  # player -> deepest layer index visited (0 = Topsoil)
var scene_of: Dictionary                 # player -> &"hillville" | &"underground" at last save
func reset() -> void
func has_treasure(id: StringName) -> bool
func find_treasure(id: StringName, player: int = -1) -> bool   # first time only: Events.treasure_found
func vehicle_rows() -> Array                                   # VehicleData by order
func vehicle_data(id: StringName) -> VehicleData
func has_vehicle(id: StringName) -> bool
func next_vehicle() -> VehicleData       # lowest order not unlocked; null if its needs_treasure is missing
func unlock_next_vehicle() -> StringName # the Garage hook: Events.vehicle_unlocked; &"" if none
func building_data(id: StringName) -> BuildingData
func count_buildings(id: StringName) -> int
func add_building(id: StringName, cell: Vector2i) -> int       # Events.building_placed
func move_building(index: int, to: Vector2i) -> void           # Events.building_moved (free, any vehicle or on foot)
func backpack_capacity() -> int
func tool_level() -> int                 # B-06: sum of `dig_power` (Workshop) effects, 0..TOOL_MAX (2). HillPlayer reads it:
                                         #   level 1+ on foot = the bigger shovel (one more cell per dig, a gold glint);
                                         #   each level digs 35% quicker and drives vehicles 15% faster
func visit_layer(player: int, layer_index: int) -> bool
func deepest_of(player: int) -> int
func to_save() -> Dictionary             # {"treasures", "vehicles", "buildings", "players"}
func load_save(data: Dictionary) -> void
```

### Voice lines (`scripts/audio/voice_lines.gd`, class `VoiceLines`; gap-close lane, 2026-11-10)

HillGame adds one `VoiceLines` node. The players' picked characters speak with their library voice pack
(Roster info `voice`) on `treasure_found` (the finder: `found`), a Workshop (`upgrade`, each player), other
buildings (`built`, at most every 20 s) and `resident_arrived` (`hello`). Game cues map to the library's
recorded lines in `Audio.LIBRARY_CUES` (`found` -> `win`/`cheer`, `rock_name` -> `cheer`, `narrate` ->
`ready`/`wait`, `upgrade` -> `cheer`/`win`, `built` -> `cheer`, `bonk` -> `oops`, `hello` -> `join`);
`Audio.bark_stream` tries the pack's own cue, then the pack's planned lines (`Audio.PACK_LINES`), then
those, then the synth placeholder. Characters without a pack say nothing from VoiceLines.

Resident barks (Audio lane, voice-packs-1): `Audio.PACK_LINES` maps `"<id>/<cue>"` to the line ids the
resident's openjar-characters pack plans (its `voice/README.md` bark table); every id found joins one
shuffled bag. Resident packs are vendored to `assets/characters/<id>/voice/` by `sync_characters.sh`
for the ids in `scripts/tools/sync_residents.txt`, listed under `"residents"` in `data/roster.json`
(`{id: {name, voice, barks}}`; absent when none has audio). Roster ignores that block: residents are
never playable. A missing pack or line keeps the placeholder; caps are the same for real lines.

### `TimeOfDay` (`scripts/autoload/TimeOfDay.gd`): the surface clock (Art lane, 2026-11-10)

One clock for Hillville's day/night cycle (Kaden: A = day, B = dusk, C = night). It is a tint and
light curve over the same art, never extra art sets. The curve and the cycle length live in
`data/time_of_day.tres` (`TimeOfDayData`, `scripts/data/time_of_day_data.gd`): `cycle_seconds`
(720 = 12 min) and keyframes `{t, sky_top, sky_horizon, band, tint, lights}`. **Underground ignores
it.** Players, their HUD and treasure sparkles are never tinted.

```gdscript
signal phase_changed(phase: StringName)  # &"day" | &"dusk" | &"night" | &"dawn"
var time: float                          # 0..1 through one cycle; 0.0 = morning, about 0.62 dusk, 0.70..0.95 night
var running: bool = false                # HillGame turns it on; menus, tests and the lobby leave it off
func set_time(t: float) -> void          # jumps, emits phase_changed when the phase changes
func phase() -> StringName
func sky_top() -> Color
func sky_horizon() -> Color
func band() -> Color                     # warm horizon band; alpha = strength (0 by day)
func world_tint() -> Color               # multiply for surface world art (1,1,1 at midday; 0.50,0.55,0.85 at night)
func lights() -> float                   # 0 = lamps off .. 1 = full night lamps (windows, lanterns, vehicle lamps up top)
func to_save() -> Dictionary             # {"time": float}
func load_save(data: Dictionary) -> void
```

Boot flag `--time=day|dusk|night|dawn|<0..1>` sets the clock at start and freezes it (for shots).
Save key `"time_of_day"`.

### Elevator rules (producer calls, 2026-11-10)

- Step into a cage (up top, or any landing underground) and the door starts to close: it waits
  `DOOR_WAIT` (1.0 s) so the other player can hop in; A skips the wait. Everyone in the cage
  when it closes rides together. Stepping out before it closes leaves the ride.
- Going down lands at the deepest layer any rider has visited (`Progress.deepest`), at that
  layer's landing beside the shaft. The ride itself is under one second.
- **Crane cable ride (Vehicles lane, 2026-11-10, H-05):** going down with the Crane aboard, the
  riders come in at the shaft mouth after the cage sinks and the Crane's cable lowers them down
  the shaft to that landing (`CraneRide.DROP`, 1.1 s; the whole ride stays under 2 s). They stay
  locked until they land; `ride_finished` fires when they come in at the mouth, `CraneRide.landed`
  when each one touches down.
- **Pick a layer on the way down (Camera lane, 2026-11-10, S-04):** while the cage goes down,
  up / down (edge presses of any rider's stick) moves the pick: pictures beside the shaft
  (`LayerPick`: the sun over Hillville on top, then every layer down to the deepest rider's) and
  a gold cage beside the picked one. It starts at the deepest layer; it never goes deeper than
  that; up past the top layer picks Hillville and the cage comes back up (riders step out where
  they were, `ride_finished(riders, &"hillville")`, no dump, no save). Each press keeps the cage
  going `PICK_LINGER` (0.7 s) longer, never past `PICK_MAX` (4 s). `HillElevator.pick_of(p)`,
  `nudge_pick(p, dir)`. Rides up are unchanged.
- Going up empties the riders' backpacks into the shaft pile.
- Every ride autosaves (also every 60 s, and on `Game.quit_requested`).
- A vehicle rides with its driver.

### Water gush (producer call, 2026-11-10)

Water stays conserved while it flows, but a breached pocket **gushes** for `GUSH_TIME` (about
2 s): its emptied cells refill from the source, so a tunnel floods and floats the player up.

### Hazards and residents (Gameplay lane, 2026-11-10)

Nothing underground can hurt a player or take anything from them (backpack, capacity, vehicle,
pile, progress). `Underground.hazards` (`Hazards`, `scripts/gameplay/hazards.gd`):

```gdscript
const STUN := 0.7          # a bonk: input reads idle this long; gravity still works
const TRAP_MAX := 4.0      # a trapped player is always free by then (the Mole usually at ~1.6 s)
signal bonked(player: int)
signal floated(player: int)                  # entered water (the world's buoyancy lifts)
signal rumbled(player: int, zone: int)       # dug into a cave-in zone; the ceiling drops in 0.4 s
signal trapped(player: int, pocket: Rect2i)  # air around the body filled with the layer's block
signal freed(player: int, by_mole: bool)
func is_stunned(p: int) -> bool
func is_trapped(p: int) -> bool
func cave_in(pl: HillPlayer, block: StringName = &"") -> bool
func free_player(p: int, by_mole := true) -> void
```

Deep-layer hazards (Hazards lane, 2026-11-10), same node, same rule (nothing is taken):

```gdscript
const HOLE_FALL := 210.0   # px/s: the fastest anyone sinks down an ice hole's chute
const LAVA_HOP := 360.0    # px/s up off a lava pool; hop_height() = LAVA_HOP^2 / 2g (about 66 px)
signal slid(player: int)                     # a glide on ice began (whoosh, spray)
signal dropped(player: int, hole: int)       # drifted into ice hole `hole` (generator.ice_holes)
signal nested(player: int, hole: int)        # landed on the snow pile a layer down (pop)
signal bounced(player: int)                  # launched off a lava pool (boing)
func is_sliding(p: int) -> bool
func is_dropping(p: int) -> bool
func on_ice(pl: HillPlayer) -> bool          # BlockData.slippery underfoot, unless Story.ice_warm()
func bounce(pl: HillPlayer) -> void
func hop_height() -> float
const HOT_SECS := 1.0      # hill-lava-1: after a bounce the player shows a flame icon and a warm flash this long
const LAVA_CUE := "lava_boing"   # the bounce's own cue; until the Audio lane adds it, `dragon_boing` plays
func is_hot(p: int) -> bool                  # since_bounce(p) < HOT_SECS (the "that's why" callback)
```

A bounce also kicks the bounced player's camera (`ScreenKick.kick(p, 2.5, 0.25)`), a small beat
on the cause. A bounce never checks the player's tool (`has_shovel`): no shovel, still a bounce.

The ice glide is applied inside the same `intent_source` wrapper (only `move.x` changes), so it
works for pads, demos and tests alike, on foot and driving. `Hazards` runs its physics before the
players (`process_physics_priority = -1`): the chute cap and the lava launch set `velocity` that
the player's own step then keeps. Placement: HazardData kinds `&"ice_hole"` (size = the rink) and
`&"lava_pocket"` (size = the room) on their own seeded stream, so no earlier placement moves:
`generator.ice_holes` `[{rink, hole, nest, dir, layer}]`, `generator.lava_pockets`
`[{room, pool, layer}]`. Lava is drawn by Hazards over the pool row, not a tile.

A stun wraps the player's `intent_source` (whatever drives it: pad, demo, test); code that
checks "has this player a source" treats a `Hazards` wrapper as none.

Placement is data: `data/hazards/<id>.tres` (`HazardData`: `kind` = `&"boulder"` |
`&"water_pocket"` | `&"cave_in"` | `&"ice_hole"` | `&"lava_pocket"`, `layer`, `count`, `near_landing`, `size`). HillGenerator keeps
the first-playable layout (the big Clay pocket, Clay and Stone boulders, whose counts now come
from these rows) and places the rest on its own seeded stream: `generator.pockets` (index 0 is
the big pocket; every pocket gushes once when breached) and `generator.cave_ins`.

Residents: `Underground.residents` (`UndergroundResidents`) and `HillGame.town`
(`TownResidents`, in Hillville). Residents have no collision. Their saved state is
`HillGame.story` (`Story`, `scripts/gameplay/story.gd`), one `ResidentState` per id
(`mole`, `gnome_foreman`, `caveman`, `dragon`), saved under `"residents"`. The Caveman's thaw
(`Story.thaw_caveman`: met and ARRIVED) and the Dragon's first meeting (`Story.meet_dragon`:
ENCOUNTERED only; she needs 2 encounters to arrive) each fire once per save and emit
`Events.resident_encountered` (and `resident_arrived` for the Caveman).

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
@export var from_ruin: StringName           # restored rows only (lost_and_found, gnome_village, museum, dragon_perch): never a card of its own
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

### Resident arcs (Gameplay lane, 2026-11-10)

`Story` (`scripts/gameplay/story.gd`) drives every arc; up top `HillGame.ruins` (`RuinSites`) and
`HillGame.town` (`TownResidents`) read it, underground `Underground.residents`.

```gdscript
const RUIN_OF := {mole: &"old_shed", gnome_foreman: &"crooked_watchtower", caveman: &"flooded_cabin", dragon: &"ruined_keep"}
const HOME_OF := {mole: &"lost_and_found", gnome_foreman: &"gnome_village", caveman: &"museum", dragon: &"dragon_perch"}
var extras: Dictionary                      # saved as "resident_arcs" (e.g. "found_waiting")
func steal_shovel() -> bool                 # Mole encounter; 3 -> ARRIVED
func free_crew() -> bool                    # Gnome Room opened -> Foreman ARRIVED
func thaw_caveman() -> bool                 # -> ARRIVED
func meet_dragon() -> bool                  # first meeting -> ENCOUNTERED
func wake_dragon() -> bool                  # second meeting -> ARRIVED
func restore(id) -> bool                    # ARRIVED -> RESTORED, Events.ruin_restored(ruin, id)
func ice_warm() -> bool                     # Dragon RESTORED
func HillGame.restore_ruin(ruin_id) -> bool # Rules.can_restore, Inventory.spend, rebuild, Story.restore
```

The build book's restore cards come from `BuildController.restore_rows(player)`: copies of the
restored row at the ruin's cost. Restored buildings are not in `Progress.buildings`.

### Story and cutscenes (Story lane, 2026-11-10; GAME.md playtest items 1-3)

`HillGame.story_scenes` (`HillStory`) hosts the reusable `CutscenePlayer` (`docs/cutscenes.md`):
scenes in `data/cutscenes/*.json`, spoken lines in `data/story/lines.json`, voice files (when Gary
makes them) at `res://assets/story/voice/<line id>.ogg`. Group `"hill_story"`: the pause menu's
Story entry calls `replay_intro()` on it.

**Shovel (the controls lane's dig code respects this; coordinate only through it):**

```gdscript
# HillPlayer
var has_shovel := true          # false while the Mole has it (between his theft and the return)
func can_dig() -> bool          # has_shovel or in a vehicle
signal no_shovel()              # a dig press on foot with no shovel: nothing is dug, the hands swing
```

A dig press on foot when `can_dig()` is false must dig nothing and emit `no_shovel` (HillStory
shows the shovel-and-question bubble and plays `dig_blocked`). Today the check sits at the top of
`HillPlayer._dig`; if the controls lane rewrites the dig path, keep that check. Vehicles always dig.
The flag is never saved (a reload always has the shovel).

**Cutscene input lock:** a scene sets `HillPlayer.locked` on every player that was not already
locked and releases only those (never one the elevator is carrying). Scenes do not start while any
player is locked (elevator ride, crane ride); they wait in `HillStory.queue`.

`resident_arcs` (`Story.extras`) also holds `"intro_seen"` (bool) and `"mole_arc"`
(`{secs, tiles, hints}` since the last theft). `UndergroundResidents.auto_steal` (false under
HillStory: the old quick theft no longer fires on digging; `steal()` stays for the "steal" beat) and
`hide_home` (the Mole is out of sight at home while he still steals).

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
`"gnome_stamp"` (unix seconds, written on every save), `"residents"` (`{id: ResidentState.to_save()}`), `"resident_arcs"` (`Story.extras`, including `intro_seen` and `mole_arc`), `"seed"`, and `"hillville"`
(`Hillville.to_save()`: which scrub is cleared), `"time_of_day"` (`TimeOfDay.to_save()`). `"treasures"`, `"vehicles"`, `"buildings"`
and `"players"` are `Progress.to_save()`'s keys. Placed buildings are rebuilt from `"buildings"`.

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
@export var flow_reach: int = 8               # cells water looks along a level line for a drop
func set_darkness(bands: Array) -> void       # [{from: int, to: int, darkness: float, tint: Color}] by depth_of
func darkness_at(depth: int) -> float
func add_light(node: Node2D, radius_px: float, strength: float = 1.0) -> void    # a headlamp: a hole in the dark that follows node
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

#### Tile art and the light pass (Art lane, 2026-11-10)

Additive; with neither set, a TileWorld looks and behaves exactly as before.

```gdscript
var tile_art: TileArt      # set before setup(); null = the generated flat-colour TileSet
class_name TileArt extends RefCounted
func tile_set() -> TileSet                                           # source 0: solid tiles (collision), source 1: back walls (no collision)
func solid_coords(cell: Vector2i, id: int, open: int) -> Vector2i     # open: neighbour bits 1 up, 2 right, 4 down, 8 left are not solid
func wall_coords(cell: Vector2i, base_id: int, ceiling: bool) -> Vector2i   # an air cell; (-1, -1) = no wall (shows the backdrop)
```

TileWorld redraws a cell and its four neighbours on every `set_tile`/`dig`. A dug cell (base solid,
now air) gets a back wall; a cell that was air in the base world (caves, the Bottom cavern)
returns what `wall_coords` says (The Hill: none, so the parallax backdrop shows through).

Light pass: `set_darkness` and `darkness_at` keep their meaning (0 daylight .. 1 darkest). The
overlay never draws pure black: darkness 1 renders as `darkness_floor` (default 0.8) of the band
tint mixed toward `darkness_night` (a dim navy). Light is worked out per cell and blended softly
from cell to cell; light reaching into solid ground falls off faster than through open space.

```gdscript
var darkness_floor: float = 0.8
func add_light(node: Node2D, radius_px: float, strength: float = 1.0) -> void   # up to 32; the nearest to tracked nodes win
```

Rules worth knowing: only chunks within `chunk_radius` of a tracked node have `TileMapLayer`
nodes and collision; `get_tile`/`set_tile`/`dig`/save work everywhere. The chunk manager only
ever talks to `WorldShape` (`chunk_of`, `chunk_cells`, `neighbourhood`), so a new shape is a new
`WorldShape` subclass and nothing else. Water is a set of full cells: it moves to `below`, else
toward the nearest drop (a free `sides` cell from which a free `below` is within `flow_reach`,
default 8, along the level line), else sideways when pressed from above, so it settles level; the
count never grows, it never enters a solid tile, an unloaded chunk or leaves the shape.

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

**The Hill's camera feel (Camera lane, 2026-11-10, S-06 / S-07):** `CameraLead` (in the play scene,
after the director each frame) leads each camera that follows one player a little ahead of where
they dig or drive (underground only) and eases back when they stop, and zooms out a little in
the Dump Truck and the Crane. It only moves the camera's position (so the scene's camera limits
hold) and zoom; the split rules above are untouched. The shared camera (one view, two players)
gets no lead and the wider zoom of the two. All values are in `data/camera.tres` (`CameraTuning`):
base zoom 2.0 (S-07, until the TV check), lead 64 x 40 world px, vehicle zoom 0.85x (1.7).
`ScreenKick` shakes use the camera offset and stack on top.

Split is always player 0 left, player 1 right, with a divider in the two players' colours. Each
scene lives in its own world (own physics space), so two scenes never collide with each other.
