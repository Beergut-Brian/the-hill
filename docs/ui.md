# Menu UI: Showtime

**Menus are for the grown-up holding the pad.** Kaden, 2026-11-09: "Those should all be designed
for me. He's not using them, I am." Then, on the first kit: "It's a game, not a website." He picked
direction **B, Showtime** (D48 d, `feature/menu-direction-options`, `art/menu-direction/`), plus
the game's own world blurred behind the stage (from A) and the squash on press (from C).

The start screen (lobby), pause, settings and the leave question look like a console game's
menus. Gameplay keeps the kid rules (`docs/kid-design.md`). Everything lives in `scenes/ui/` and
`scenes/ui/kit/` and is drawn in code, so it is crisp at 1080p and 4K.

## The look

- **A stage that belongs to the menu.** A slowly turning sunburst in the game's colours, Jeff
  (left, green `#3cc24a`) and Chuck (right, red `#e4393c`) on spotlit podiums with name plates
  and READY! stamps, and the game's title big, tilted, with a hard ink outline.
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
| `p1_character`, `p2_character` | Scenes on the podiums (Control, Node2D or Node3D, see below) | placeholder |
| `p1_name`, `p2_name` | Name plates | JEFF, CHUCK |
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

`Spots/P1/Character` and `Spots/P2/Character` are `CharacterSlot`s. They host the skin's scene:

- **Node3D** (a Jarling `.glb` with a rig script): shown in its own little lit SubViewport with a
  transparent background (key light, rim light in `accent2`, ambient), on a slow turntable.
  Feet at y = 0.
- **Node2D** (a pixel sprite, an AnimatedSprite2D): stands with its origin on the podium, scaled by
  `character_scale`, nearest-filtered if `pixel_art`.
- **Control**: fills the slot.

The kit calls `set_joined(on: bool)`, `wave()` (on ready) and `cheer()` (round starting) on the
character if it has them; the slot itself also hops, so a character with no methods still jumps.
Not joined: the character is a dark shadow and the plate pulses "[a] JOIN".

## Screens

- **Lobby** (`scenes/ui/lobby.tscn`): title top left over the stage, podiums, the wedge with Play
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
| `character_slot.gd` | `CharacterSlot`: hosts a Control, Node2D or Node3D character |
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

- **Spaceballs** (3D): title "SPACEBALLS", accent `#ffc928`, sunburst `#2a9dff`, deep `#16296b`;
  characters: a Node3D scene holding `jeff.glb` / `chuck.glb` with the Jarling rig (play `idle`,
  `cheer()` plays `cheer`); `backdrop = SCENE`, `backdrop_scene = scenes/levels/field.tscn`
  (it has no camera, so the skin's default field camera is used). Verified in a scratch copy:
  `handoff/shots/`.
- **Junk Yard Zap** (3D): title "JUNK YARD ZAP", accent `#ffb21f`, sunburst `#ff6a2b`, deep
  `#33201a`; the yard diorama as `backdrop_scene`, the JYZ Jarling rig as characters.
- **The Hill** (2D pixel art; in this repo: `data/menu_skin.tres`, `scenes/ui/hill_menu_*`): `pixel_art = true`, `character_scale = 4` (or whatever integer
  your sprites use), characters as Node2D scenes (an `AnimatedSprite2D` with feet at the origin;
  add `cheer()` to play a jump animation), title as a pixel logo PNG in `title_texture`
  (nearest-filtered), an earth-and-sky palette (e.g. accent `#ffd34a`, sunburst `#5fb4e8`, deep
  `#2b2a3f`). Backdrop: `SCREEN` if the hill is drawn behind the lobby, or `SCENE` with the level
  scene (2D renders into the SubViewport at 1/4 size with a `size_2d_override` of 1920x1080, so
  bring a Camera2D or design the scene for a 1920x1080 view). The bars, wedge, wipe and type stay
  vector: that is on purpose, the menu is the grown-up's layer.

## Screenshots

`scripts/tools/shots.sh "" 1.5 /tmp/shots --ui=lobby-ready` (also `lobby`, `lobby-joined`,
`lobby-hold`, `lobby-settings`, `lobby-confirm`, `pause`, `pause-settings`, `pause-confirm`, and the
motion strip `lobby-go1` .. `lobby-go6`: SETTINGS focused, up to PLAY, A + GO!, wipe, round card,
into the game).

Performance: the sunburst is one full-screen shader; the `SCENE` backdrop renders at 1/16 of the
pixels; 3D characters render in two small SubViewports. All of it is gone once the round starts.
