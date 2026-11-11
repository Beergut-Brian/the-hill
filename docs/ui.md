# Menu UI: Showtime

**Menus are for the grown-up holding the pad.** Kaden, 2026-11-09: "Those should all be designed
for me. He's not using them, I am." Then, on the first kit: "It's a game, not a website." He picked
direction **B, Showtime** (D48 d, `feature/menu-direction-options`, `art/menu-direction/`), plus
the game's own world blurred behind the stage (from A) and the squash on press (from C).

The start screen (lobby), pause, settings and the leave question look like a console game's
menus. Gameplay keeps the kid rules (`docs/kid-design.md`). Everything lives in `scenes/ui/` and
`scenes/ui/kit/` and is drawn in code, so it is crisp at 1080p and 4K.

## The look

- **A stage that belongs to the menu.** A slowly turning sunburst in the game's colours, each
  player's chosen character (P1 left, green `#3cc24a` podium; P2 right, red `#e4393c`; Jeff and
  Chuck by default) on spotlit podiums with name plates and READY! stamps, and the game's title
  big, tilted, with a hard ink outline.
- **The game's world behind it**, out of focus, if the game opts in (`MenuSkin.backdrop`).
- **Everything leans the same way** (`UiStyle.LEAN` = 0.2), as if it is moving: a dark wedge
  cuts in from the right with racing stripes on its edge, and carries slanted bars.
- **The chosen bar is the only light thing on screen**: cream, bigger, with the accent block and
  chevrons. Unfocused bars are the deep colour, lifted, with cream text.
- Type: **Baloo 2** 800, slanted (`UiStyle.show_font()`), for titles, bars, plates and stamps;
  Nunito for hints and sentences. Ink `#1b1630`, cream `#fff5e6`. Nothing smaller than 24 px at 1080p.
- P1 green and P2 red only ever mean "this player" (podiums, plates, the pause stripe, the wipe).

## Motion

| What | How |
| --- | --- |
| Menu opens | The title drops in, bars slam in from off screen one after another, past their mark, and settle (`MenuItem.slam_in()`, `slam_all()`). |
| Move | The new bar grows out past its mark and settles (TRANS_BACK), the old one shrinks back. |
| Press | The bar flashes the accent and squashes (y 0.8, x 1.05), then springs back (TRANS_ELASTIC). |
| Ready | The player's podium lights, their READY! stamp slams on from big. |
| Choose | Left / right: the arrow beside the name kicks out, the character squashes down (70 ms), becomes the next one in a cream poof, and pops up past full size (TRANS_BACK, 320 ms); the name bounces in; the `char_swap` cue. When the scrolling stops, the character says its catchphrase ("Chooser voice"). Nobody free: a little head-shake and a low tak. |
| Round starts | On the countdown's last beat the stamps flip to GO!, Play flashes and squashes, both characters jump, then three leaning stripes (cream, green, red) chase across pulling the deep colour behind them, a "ROUND 1" card holds for a beat, and the stripes wipe off into the game. |
| Pause | The game stays visible, softened and tinted; a wedge slides in from the left edged in the pauser's colour. |
| Settings | Its wider wedge slams in from the right; the title shrinks and the podiums step left. Meters bump when a value changes. |
| Idle | Sunburst turns, 3D characters on a slow turntable, the placeholder bobs. |

## The skin: one resource per game

`MenuSkin` (`scenes/ui/kit/menu_skin.gd`). Save one as **`res://data/menu_skin.tres`** and the kit
picks it up by itself. Or set it in code (main.gd `_ready()`):

```gdscript
UiStyle.use_skin(preload("res://data/menu_skin.tres"))   # redraws every open menu
```

| Field | What it does | Default |
| --- | --- | --- |
| `title_texture` | Logo art instead of text | none |
| `title_text` | The title, in the slanted display face | project name |
| `accent` | Title, focused-bar block, READY line, meters; becomes `UiStyle.accent` | `#ffc23a` |
| `accent2` | The sunburst | `#8a5cf6` |
| `deep` | Wedge, bars, wipe cover; keep it dark | `#281a5c` |
| `p1_character`, `p2_character` | Scenes on the podiums (Control, Node2D or Node3D, see below) | the player's `Roster` pick |
| `p1_name`, `p2_name` | Fixed name plates (only for a game whose characters are fixed) | the pick's name |
| `pixel_art`, `character_scale` | Nearest filtering and whole-number scale for 2D art | off, 1 |
| `camera_3d_distance`, `camera_3d_height` | Podium shot for Node3D characters | 3.4, 0.9 |
| `backdrop` | `SUNBURST`, `SCENE`, `TEXTURE` or `SCREEN` (below) | `SUNBURST` |
| `backdrop_scene` | The live world for `SCENE` | none |
| `backdrop_camera_position/target/fov` | Camera for a 3D `backdrop_scene` that has none | a field view |
| `backdrop_texture` | The still for `TEXTURE`, and the fallback for `SCENE` | none |
| `sunburst_over_world` | How much sunburst covers the world (0..1) | 0.55 |
| `blur` | Blur strength for the world | 2.5 |
| `round_card`, `round_card_title` | The card between wipe and game; `%d` is the round | on, `ROUND %d` |

`UiStyle.accent = Color(...)` still works on its own (the first kit's API).

### Backdrop: the game's world behind the stage

- `SUNBURST`: the sunburst only. The template's default; costs one shader.
- `SCENE`: `backdrop_scene` is instanced into a SubViewport at **1/4 resolution** (so it is cheap
  and already soft), blurred, tinted toward `deep`, with the sunburst over it at
  `sunburst_over_world`. It runs live (crowds bob, flags wave). It is a separate world, so it
  needs no players and no game state; give it a Camera, or the skin's `backdrop_camera_*` is used.
  `Backdrop.world` is the instance, if the game wants to poke it.
- `TEXTURE`: a still (a screenshot of the level), blurred. Use it when the live world is heavy.
- `SCREEN`: blurs whatever the game already draws behind the menu (its level in `main.tscn`).
  The cheapest adoption if the level sits behind the lobby anyway.

### Characters on the podiums

`Spots/P1/Character` and `Spots/P2/Character` are `CharacterSlot`s. By default (skin slots empty)
they host the player's `Roster` pick (`RosterCharacter`): its Jarling `.glb` from
`assets/characters/<id>/`, idling, cheering when ready; with `pixel_art` its pixel form
(`pixel.png`, a Node2D, feet on the podium, scaled by `character_scale`). If the skin sets a scene,
the slot hosts that instead:

- **Node3D** (a Jarling `.glb` with a rig script): shown in its own little lit SubViewport with a
  transparent background (key light, rim light in `accent2`, ambient), on a slow turntable.
  Feet at y = 0.
- **Node2D** (a pixel sprite, an AnimatedSprite2D): stands with its origin on the podium, scaled by
  `character_scale`, nearest-filtered if `pixel_art`.
- **Control**: fills the slot.

The kit calls `set_joined(on: bool)`, `wave()` (on ready) and `cheer()` (round starting) on the
character if it has them; the slot itself also hops, so a character with no methods still jumps.
A skin scene with `set_character(id: String)` is told the player's pick when it is hosted and
whenever it changes, so a game can keep its own rig and gear and still have the chooser. A scene
without it is shown as it is (the chooser still changes the pick and the name).
Not joined: the character is a dark shadow and the plate pulses "[a] JOIN".

## The character chooser

On your podium, joined and not ready: **left / right** (stick, D-pad or keys) cycles your character
through `Roster.roster()`, skipping the other player's pick (never the same character twice).
Small arrows sit either side of your name and the tag above says "[lr] Pick  [a] Ready up".
**A** readies as before and locks the pick (arrows gone); **B** un-readies and you can change again.
Each change is written to the shared picks file at once, so the next game and the launcher start
you as that character (`docs/roster.md`).

Solo (playtest only): the one pad drives one podium at a time. **Select** (tapped on its own)
switches the pad to the other podium: A, B and left / right then act there. Solo readies both, so
to change: B, left / right, A; Select, B, left / right, A for the other one.

With only Jeff and Chuck in the roster (characters `v0.3.0`) and both players on the stage, there
is nobody free to switch to: left / right gives the head-shake. New characters land with a
`sync_characters.sh` rerun, no code change.

### Chooser voice

Kaden, 2026-11-10: "when a character is up on the screen, I'd like it to say its catchphrase
once. Give a little audio cue of who they are."

- **Each step** (left / right that changes the character) plays the `char_swap` cue and the swap
  animation at once, as before, so scrolling feels quick. It no longer barks.
- **`SAY_SETTLE` = 0.3 s** (`lobby.gd`) after the last step, the character now on the podium says
  its catchphrase, **once**. Scrolling fast through five characters says only the one you stop
  on; standing on it says nothing more; scrolling away and back says it again (every settle
  after a step speaks). A step restarts the settle.
- **Joining** shows your pick and says its catchphrase after the same settle (the join's own
  ready sound plays at once, as before). The ready-up (A) keeps its sound; a settle already
  running still finishes. Leaving, and the round starting, cancel a pending line.
- **Each player has their own voice** (`Roster.voice_player(p)`, on bus `VoiceP1` / `VoiceP2`,
  made at start, panned -0.3 / +0.3 toward their podium, sending to `SFX` so the Sound setting
  covers it). A new line cuts off only that player's previous one, so two players choosing at once
  never cut each other off.
- **The line**: `Roster.catchphrase(id, p)`: the character's `voice/catchphrase.ogg`; without one,
  a random bark; neither (Jeff, Chuck, Bloom, Old Reel in `v0.5.0`): nothing more, the step's
  `char_swap` already sounded.
- **Where the file comes from**: `sync_characters.sh` copies `voice/lib/catchphrase_big.ogg` from
  `openjar-characters` (only that file from `lib/`; `catchphrase_calm` and the rest stay in the
  library) to `assets/characters/<id>/voice/catchphrase.ogg` and writes its path as
  `"catchphrase"` in `data/roster.json` (`""` without one). It is not a bark: `barks` stays the
  top-level cues.
- The log says what played when: `Chooser voice: P1 boxbot res://.../catchphrase.ogg (t=8.98 s)`.

Copying it (a game's own lobby, the launcher's in-line chooser): on a successful step play the
swap cue and set `_say_in[p] = SAY_SETTLE`; each frame count it down and at zero call
`Roster.catchphrase(Roster.pick(p), p)` once; cancel on leave / launch. `lobby.gd` `say_soon()`,
`cancel_say()`, `voice_step()` are the whole of it; `tests/test_chooser_voice.gd` checks it.

## Screens

- **Lobby** (`scenes/ui/lobby.tscn`): title top left over the stage, podiums (with the chooser), the wedge with Play
  (with a "2P" chip and a dot per joined player), Settings, Back to Open Jar; under them a status
  headline in the accent ("WHO'S PLAYING?", "WAITING FOR PLAYER 2", "BOTH PLAYERS READY 3") and a
  hint line; the hint strip bottom right. Join, ready, hold-to-start-solo, solo mode and
  mid-game joins behave as before.
- **Pause** (`scenes/ui/pause_menu.tscn`): PAUSED in cream with a drop in the pauser's colour,
  "PLAYER 2 PAUSED" tag, Resume / Restart / Settings / Back to Open Jar bars bleeding off the
  left, hint strip "[b] Resume".
- **Settings** (`scenes/ui/settings_panel.tscn`): SETTINGS, "Saved on this TV", rows MUSIC and
  SOUND (10-segment meters and the number), SCREEN SHAKE and SOLO PLAYTEST (ON / OFF chips).
  Per install, saved the moment a value changes.
- **Leave the game?** (`scenes/ui/confirm_dialog.tscn`): a slanted card, STAY focused first.

### Round card and the wipe

The lobby plays `ShowtimeWipe` into round 1. Set what the card says in code:

```gdscript
lobby.round_card_subtitle = "JEFF KICKS FIRST"         # under ROUND 1; empty: no strip
lobby.round_card_color = UiStyle.player_color(0)       # the strip's colour; default accent2
# MenuSkin.round_card = false: no card, just the wipe. round_card_title = "WAVE %d" etc.
```

A game can play the wipe anywhere (between rounds, into a boss):

```gdscript
ShowtimeWipe.run(func(): load_next_level(), "ROUND 2", "CHUCK KICKS FIRST", UiStyle.player_color(1))
```

`on_cover` runs once the screen is fully covered; `covered` and `finished` signals too.

## Sound

Every move, select, back, ready and wipe makes a sound. `UiSound.play(cue, pitch)` plays
`assets/audio/sfx/<cue>.ogg` (or `<cue>_1.ogg`...) through `Audio` if the file exists, else a
synthesized stand-in, so nothing is silent before the Audio lane delivers. Drop in a file with the
same name and it replaces the synth; no code change.

| Cue | When | Brief for the Audio lane |
| --- | --- | --- |
| `ui_move` | focus moves, also bumping an end; pitch steps down the list | tight arcade "tak" |
| `ui_back` | B, close, Stay | the "tak" reversed |
| `ui_confirm` | select, open a panel, Leave | two-note brass stab over a low thump |
| `ui_tick` | settings meter step; pitch rises with the value | ratchet tick |
| `ui_toggle` | ON / OFF | switch clack |
| `player_ready` | a player readies; pitch 1.12 for P1, 0.89 for P2 | short sting + stamp "chunk" |
| `player_unready` | B un-readies | two descending notes |
| `player_join` | (reserved) a pad joins | quick upward blip |
| `count_tick` | countdown beat; pitch rises | short clean beep |
| `ui_go` | last beat: GO! | bright chord hit |
| `ui_wipe` | wipe in (and out, pitch 1.15) | three fast whooshes |
| `ui_card` | round card | cymbal swell |
| `ui_pause` | pause menu opens | record-scratch dip into a low pad |
| `char_swap` | chooser swap, when the character has no voice bark; pitch 1.08 P1, 0.92 P2 | soft puff + rising cartoon pop |

`Game` still plays its own `pause` and `round_start` cues through `Audio`.

## Building blocks (`scenes/ui/kit/`)

| File | What |
| --- | --- |
| `menu_skin.gd` | `MenuSkin`, the per-game resource |
| `ui_style.gd` | `UiStyle`: skin access, colours, `show_font()`, `draw_show()`, `para()` / `slab()` (slanted bars), `chevrons()`, `style_title()`, glyph text (`draw_rich`) |
| `menu_item.gd` | `MenuItem`: slanted bar; `bleed` RIGHT / LEFT / NONE, sizes, `chip`, `slam_in()`, `press()`, `progress` |
| `setting_row.gd` | `SettingRow`: bar with a meter or ON / OFF chips |
| `wedge.gd` | The dark wedge with racing stripes; tween `edge` |
| `menu_backdrop.gd` | The stage: world (SCENE / TEXTURE / SCREEN), sunburst, floor |
| `character_slot.gd` | `CharacterSlot`: hosts a Control, Node2D or Node3D character; `swap_to(id)` |
| `roster_character.gd` | `RosterCharacter.make(id, pixel)`: a Roster pick as a podium character (`roster_jarling.gd` 3D, `roster_sprite.gd` pixel) |
| `poof.gd` | `Poof.burst(parent, at)`: the chooser's puff |
| `showtime_wipe.gd` | `ShowtimeWipe`: the three-stripe wipe and round card |
| `ui_sound.gd` | `UiSound`: cues with a synth fallback |
| `hint_line.gd` | `HintLine`: glyph hints; `strip = true` for the dark strip |
| `sunburst.gdshader`, `soft_blur.gdshader`, `blur_dim.gdshader` | stage, world blur, pause blur |
| `menu_input.gd` | `MenuInput.read()`: one shared cursor from every joined pad |
| `ui_preview.gd` | `--ui=` screenshot states |

Controller glyphs: write `[a]`, `[b]`, `[x]`, `[y]`, `[start]`, `[select]`, `[lr]`, `[ud]` in hint
text; they draw as neutral Xbox-layout glyphs (no logos).

## How a game adopts it

1. Merge the template (`dev`) into the game. Keep your `main.gd` and level.
2. Make `data/menu_skin.tres` (new resource, script `MenuSkin`): title, three colours, your two
   character scenes, a backdrop. That's it for most games.
3. Remove old customisation that the skin now covers (e.g. `Backdrop.visible = false`,
   `fill_alpha`, swapping `Spots/P*/Character` by hand). Swapping the Character node still
   works, but the slot is easier.
4. Optional: `lobby.round_card_subtitle = ...` before the countdown ends; `ShowtimeWipe.run()` between
   rounds; `.ogg` files for the cues above.

Everything is set in code or in the skin resource, never as overrides on instanced `.tscn`
children (exported builds lose those).

### Per game

**Every game: spawn the chosen character.** The lobby needs nothing; the game's own player scene
must stop hard-coding Jeff and Chuck:

```gdscript
var who := Roster.info(Roster.pick(player))      # id, name, glb, pixel, voice, barks
var body: Node3D = load(who.glb).instantiate()   # pixel game: a Sprite2D with texture = load(who.pixel)
rig.add_child(body)                              # same rig, collision and gear for everyone
```

Every playable character is a standard Jarling, so one collision shape, the same animations
(`idle`, `run`, `kick`, `cheer`) and the same gear slots work for all of them. Keep player colours
on the slot (rings, HUD, arrows) from `Players.COLOR`, never from the character. Barks:
`Roster.bark(id)` (false until a character has recorded barks; fall back to your generic set).
Remove `p1_name` / `p2_name` from `data/menu_skin.tres` so the plates follow the pick.

- **Spaceballs** (3D): title "SPACEBALLS", accent `#ffc928`, sunburst `#2a9dff`, deep `#16296b`;
  characters: a Node3D scene holding `jeff.glb` / `chuck.glb` with the Jarling rig (play `idle`,
  `cheer()` plays `cheer`); `backdrop = SCENE`, `backdrop_scene = scenes/levels/field.tscn`
  (it has no camera, so the skin's default field camera is used). Verified in a scratch copy:
  `handoff/shots/`. **Chooser:** give `lobby_jarling.gd` a `set_character(id)` that swaps its
  `Jarling/Model` for `load(Roster.info(id).glb)` (equipment re-applied with `dress()`), point
  `lobby_jeff.tscn` / `lobby_chuck.tscn` at `assets/characters/<id>/` (drop
  `assets/models/characters/jeff.glb`, `chuck.glb` after a `sync_characters.sh` run), clear
  `p1_name` / `p2_name` in the skin, and have the kicker spawn from `Roster.info(Roster.pick(p)).glb`
  with the same `jarling_rig.gd`, gear and `windup_<id>` cue falling back to a generic windup.
- **Junk Yard Zap** (3D): title "JUNK YARD ZAP", accent `#ffb21f`, sunburst `#ff6a2b`, deep
  `#33201a`; the yard diorama as `backdrop_scene`, the JYZ Jarling rig as characters.
  **Chooser:** leave the skin's character slots empty (or give the JYZ rig scene
  `set_character(id)`), and spawn each zapper's body from `Roster.info(Roster.pick(p)).glb` with
  the JYZ equipment (tool in `slot_hand_r`, backpack in `slot_back`) on any standard body.
- **The Hill** (2D pixel art; in this repo: `data/menu_skin.tres`, `scenes/ui/hill_menu_*`): `pixel_art = true`, `character_scale = 4` (or whatever integer
  your sprites use), characters as Node2D scenes (an `AnimatedSprite2D` with feet at the origin;
  add `cheer()` to play a jump animation), title as a pixel logo PNG in `title_texture`
  (nearest-filtered), an earth-and-sky palette (e.g. accent `#ffd34a`, sunburst `#5fb4e8`, deep
  `#2b2a3f`). Backdrop: `SCREEN` if the hill is drawn behind the lobby, or `SCENE` with the level
  scene (2D renders into the SubViewport at 1/4 size with a `size_2d_override` of 1920x1080, so
  bring a Camera2D or design the scene for a 1920x1080 view). The bars, wedge, wipe and type stay
  vector: that is on purpose, the menu is the grown-up's layer. **Chooser:** with `pixel_art` and
  empty character slots the podiums show each pick's `pixel.png` (40x32, feet on the podium)
  scaled by `character_scale`; in game, build the player sprite from
  `Roster.info(Roster.pick(p)).pixel` (the front view; The Hill's own walk frames keyed by id until
  the library ships pixel sheets per character).
  **In this repo:** the skin keeps its own podium scenes (`hill_menu_jeff.tscn` / `_chuck.tscn`,
  `HillMenuCharacter` with `set_character(id)`) and clears `p1_name` / `p2_name`, so plates name
  the pick. Players, drivers (the `ride` frame in the cab), sleepers in the bucket and the podiums all
  draw `CharacterSheet.file_of(id)` (`scenes/players/character_sheet.gd`): the game's hand-made sheet
  `assets/sprites/characters/<id>.png` when it has player rows (Jeff, Chuck), else a sheet built at
  runtime from the roster `pixel.png` (idle, walk, air, dig_side, dig_down, ride, sleep; bob, lean,
  squash, a drawn shovel), registered as the virtual sheet `roster/<id>.png`. A newly synced
  character plays the same night with no art step; a hand-made sheet in `make_game_art.py` later
  replaces the built one just by existing. Slot colour (rings, arrows, plate, vehicle stripe) stays
  P1 green / P2 red whoever is picked. Shots with the test-only stand-in "Pip":
  `--roster-data=res://tests/fixtures/roster_standin.json --p1-char=pip` (Debug.gd; ignored in an
  export, which ships no `tests/`).

## Screenshots

`scripts/tools/shots.sh "" 1.5 /tmp/shots --ui=lobby-ready` (also `lobby`, `lobby-joined`,
`lobby-hold`, `lobby-settings`, `lobby-confirm`, `lobby-pick` (P1 choosing, arrows), `lobby-swap`
(P1 posed mid-swap, poof), `pause`, `pause-settings`, `pause-confirm`, and the
motion strip `lobby-go1` .. `lobby-go6`: SETTINGS focused, up to PLAY, A + GO!, wipe, round card,
into the game). Add `--ui-pixel` for a `pixel_art` skin (pixel forms on the podiums).

Performance: the sunburst is one full-screen shader; the `SCENE` backdrop renders at 1/16 of the
pixels; 3D characters render in two small SubViewports. All of it is gone once the round starts.

## Button hints (gameplay; the-hill PT10-8, ready for the template)

A small panel per player that shows **only the buttons that matter right now**: a controller
glyph (UiStyle's neutral Xbox-layout disc with a dark ring) and a **picture** of what it does.
No words, so it is allowed on gameplay screens (`docs/kid-design.md`). Rows pop (grow and settle)
when what a button does changes; the panel fits its rows and fades out when the list is empty.

```gdscript
var hints: ButtonHints = preload("res://scenes/ui/kit/button_hints.tscn").instantiate()
hints.accent = Players.COLOR[p]        # edge in the player's colour
hints.align_right = p == Players.P2    # P2's panel grows leftward from the right edge
hints.size = Vector2(320, 260)         # rows sit at the bottom of this box
add_child(hints)
# Every frame (it only redraws when the list changes):
hints.show_hints([{"button": "a", "icon": &"dig"}, {"button": "b", "icon": &"jump"}])
```

| API | What it does |
| --- | --- |
| `show_hints(list) -> bool` | `[{button: "a"\|"b"\|"x"\|"y", icon: StringName, dim?: bool}]`, sorted A, B, X, Y. Same list: no-op (false). |
| `hints()` | The current list. |
| `ButtonHints.register_icon(&"name", func(ci, rect, alpha))` | A game's own picture. Static: call `ButtonHints.unregister_icon(&"name")` before the lambda's owner is freed, or Godot aborts at exit. |
| `ButtonHints.draw_icon(ci, id, rect, alpha)` / `draw_button(ci, centre, h, "a", alpha, ring)` | The same drawings anywhere (the-hill draws the elevator's A over a player's head with `draw_button`). |
| `glyph_height` (44), `accent`, `align_right` | Look. |

Built-in pictures: `dig`, `jump`, `climb`, `enter`, `exit` (a person, a vehicle, an arrow toward it
or away), `ride` (a cage with up / down arrows), `book`, `scoop`, `tip`, `hook`, `drill`, `horn`,
`ok`, `back`.

**The context lives in the game, not the kit.** The Hill's `HillHintLayer`
(`scripts/gameplay/hill_hint_layer.gd`) puts one panel in the bottom outer corner of each
player's view (`ScreenDirector.view_rect_of`, inside the 5% safe area: P1 left, P2 right, each in
their own half in split) and asks `HillHintLayer.for_player(game, node)` every frame:

| Situation | Shows |
| --- | --- |
| Underground on foot | A dig (A climb while the stick points up), B jump |
| Up top on foot | B jump, X book (A only with a ghost to place) |
| Beside a parked vehicle | B get in |
| Driving | A the vehicle's job (scoop / tip / dig / drill / hook), B get out |
| Standing in the elevator cage | A ride (dim while the car comes or rides) |
| Build book open | A ok, B back, X book |

A game adopting it writes its own `for_player` with the same shape and keeps the kit as is.
