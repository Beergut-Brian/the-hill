# Cutscenes (Story lane, 2026-11-10)

A reusable, data-driven cutscene player: `scripts/gameplay/cutscene_player.gd`, `class_name
CutscenePlayer extends Control`. The Hill uses it for the intro, the Mole's thefts and every major
NPC moment (`scripts/gameplay/hill_story.gd`, `HillStory`). It is written so Life of a Worm can
lift it as is: nothing in it knows about The Hill; the game talks to it through a small host
interface.

## What a scene does

1. Locks input (the host's `cutscene_lock(true)`).
2. Slides black letterbox bars in (11% of the screen each, 0.45 s) and shows the **A** glyph with a
   fast-forward arrow in the bottom bar (no words).
3. Runs its steps: the camera eases to the moment and zooms, actors walk, hop and turn, a voiced line
   plays per beat with a picture bubble over the speaker, items (a deed, a shovel) arc from one actor
   to another, the screen fades, the host is called for game changes.
4. Slides the bars out, hands the camera back (eased) and unlocks input.

**A skips the whole scene** (any player, after a 0.5 s grace so the press that started it does not
skip it). A skip runs every remaining step marked `"always": true` at once (state changes such as
"take the shovel", "wake up top", "give the shovel back"), so a skipped scene leaves the game exactly
where the full scene would. A scene never runs longer than `MAX_SECS` (90 s): past that it skips
itself. If the host is freed, it skips. So it never softlocks.

## Split screen (logged decision)

Both halves show it when both players are in the scene's world: every view whose camera looks at
the actors' world eases to the moment. A view showing another scene (one player up top, one below)
keeps its own camera under the bars; input is locked for both. The bars and the fade cover the
whole screen. Bubbles are drawn per view, in screen space (above the underground darkness),
clamped inside their view and below the top bar.

## Data: `data/cutscenes/<id>.json`

```json
{"id": "intro", "scene": "hillville", "steps": [
  {"do": "camera", "to": "players_mid", "dy": -20, "zoom": 3.0, "time": 1.0, "wait": 0.9},
  {"do": "spawn", "who": "pip", "sheet": "mayor_pip", "at": "players_left", "dx": -150},
  {"do": "walk", "who": "pip", "to": "players_left", "dx": -34, "time": 2.0},
  {"do": "line", "who": "pip", "line": "intro_pip_hello", "pics": ["face_happy"]},
  {"do": "call", "fn": "take_shovel", "always": true}
]}
```

`scene` is where spawned actors go (`hillville`, `underground`, or a host value such as `@victim`).
Steps run in order; each blocks for its `wait` (default: its own `time`, except `camera`, `hop`,
`face`, `show`/`hide`, `hold`/`drop`, `sound` and `bars`, which do not block unless given a `wait`).

| `do` | Fields | What happens |
| --- | --- | --- |
| `camera` | `to` (actor, anchor or `[x, y]`), `dx`, `dy`, `zoom`, `time` | Eases the camera(s) there; follows a moving actor |
| `camera_back` | | Eases back to the game's camera |
| `spawn` | `who`, `sheet`, `at`, `dx`, `dy`, `face` | A temporary actor (freed at the end) |
| `walk` | `who`, `to` or `dx`, `time` | Walks there with a little bob (the sheet's `walk` row if it has one) |
| `hop` | `who`, `height`, `times`, `time`, `sound` | Hops in place |
| `face` | `who`, `dir` or `toward` | Turns |
| `show` / `hide` | `who` | |
| `line` | `who`, `line` (id), `pics`, `time` | Plays the voiced line and shows the bubble for its length |
| `bubble` | `who`, `pics`, `time` | A picture bubble with no voice |
| `item` | `pic`, `from`, `to`, `time`, `sound` | A picture arcs from one actor to another with sparkles |
| `hold` / `drop` | `who`, `pic` | A picture held at the actor's hands |
| `sound` | `cue` | `Audio.play(cue)` |
| `fade` | `to` (0..1), `time` | Fades to / from black |
| `bars` | `on` | Bars in or out mid-scene |
| `call` | `fn`, `args`, `always` | `host.cutscene_call(fn, args)` |
| `wait` | `time` | |

Any step can have `"needs": "<actor>"` (skipped when that actor is missing, e.g. P2 asleep),
`"if": "<ctx key>"` / `"unless": "<ctx key>"`. Values are filled from the play context: `"@key"`
becomes `ctx[key]` (any type), and `"{key}"` inside a string becomes `str(ctx[key])`. In a line id,
`{char}` becomes the speaker's character id, falling back to `any` (so `theft_hey_{char}` is Jeff's
line for Jeff, Chuck's for Chuck, and `theft_hey_any` for anyone else picked in the lobby).

## Lines: `data/story/lines.json`

`{"lines": [{id, character, text, delivery, fallback}]}`. `text` is in the character's voice (from
the character library's `voice.md` / `voice/README.md` and bible) and may hold ElevenLabs v3 tags
(`[laughs]`, `[whispers]`); every line is 12 words or fewer (a test checks). Residents stay
wordless or nearly (the Mole's "oh dear" family, hums, hoots, whistles), as their voice READMEs say.

Playback, in order: `res://assets/story/voice/<id>.ogg` if it exists (Gary generates them); else
`fallback`: `bark:<cue>` is the speaker's library bark (`Audio.bark_stream`, which falls back to the
synth placeholder) and `sfx:<cue>` an `Audio` cue. A line on a player is voiced for whoever the
player picked: the Jeff/Chuck file plays only when that character is the pick, else that pick's
library bark. Music ducks under a line. The picture bubble always shows, voiced or not.

## Host interface (duck-typed)

```gdscript
func cutscene_actor(name: String) -> Node2D                     # an existing actor, or null
func cutscene_spawn(name, sheet, scene, pos: Vector2) -> Node2D # a temporary actor
func cutscene_anchor(name: String) -> Vector2                   # INF when unknown
func cutscene_views() -> Array                                  # [{camera: Camera2D, rect: Rect2}]
func cutscene_lock(on: bool) -> void
func cutscene_call(fn: String, args: Dictionary) -> void
func cutscene_skip_pressed() -> bool
func cutscene_character(actor: String) -> String                # the voice an actor speaks with
func cutscene_head(actor: String) -> Vector2                    # optional: bubble tip offset
func cutscene_anim(actor: String, anim: String) -> void         # optional: "walk" / "idle" rows
```

API: `play(id, ctx) -> bool`, `skip()`, `is_playing()`, `current()`, `context()`,
`pop_bubble(actor, pics, secs)` (a bubble outside any scene), `speed` (tests run scenes fast),
signals `started(id)`, `finished(id, skipped)`, `beat(kind, detail)`.

## The Hill's scenes (`HillStory`)

| Scene | When | Length |
| --- | --- | --- |
| `intro` | A new save (once, `resident_arcs.intro_seen`); the pause menu's **Story** entry replays it | about 41 s |
| `mole_theft` | MoleArc: after the three hints and the gap (`data/story/mole_arc.json`) | about 12 s |
| `mole_return` | 3 s after the theft (`NO_SHOVEL_SECS`): fade, wake up top, shovel back | about 12 s |
| `crew_freed`, `caveman_thaw`, `dragon_reveal`, `dragon_wake` | Each resident's encounter (the residents' own animation plays; the scene frames it) | 3 to 6 s |
| `arrive` | A resident arrived and someone is up top (not after the Mole's third return: that scene already shows it) | about 4 s |
| `movein` | A restored ruin finished rebuilding | about 5 s |
| `vehicle_unlock` | A Garage rolls out a vehicle; Foreman Dot shows it off | about 6 s |

A moment that comes while a scene plays, or while a player is locked by the elevator or the crane,
waits in a queue. Only a real game plays them by itself (`HillStory.auto`): the full `--demo` and
bare test games do not, so other lanes' beats and tests keep their timing. `--demo-beat=intro|hints|
theft|unlock|arrive_scene|movein_scene|crew_scene|dragon_scene` show each one
(`scripts/gameplay/story_beats.gd`).

## For Life of a Worm

Copy `cutscene_player.gd` and `picto_bubble.gd` (or lift both into `openjar-addons`), write a host
with the methods above (Worm never splits the screen, so `cutscene_views` is one camera), and put
scenes in `data/cutscenes/`. Nothing else is needed.
