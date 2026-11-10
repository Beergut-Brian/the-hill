# CLAUDE.md — Open Jar Games template

This repo is the starting point for every Open Jar Games title: small, loud, co-op games
Kaden plays with his 5-year-old on the living-room TV. Read this file first, then `GAME.md`,
then the lane doc for the lane you are working in (`docs/lanes/<lane>.md`).

## Non-negotiables

1. **Godot 4.x only.** The pinned version is in `.godot-version`. Never write Godot 3 syntax:
   - `await`, not `yield`
   - `signal_name.connect(callable)`, not `connect("signal_name", self, "method")`
   - `@export var`, not `export var`
   - `@onready var`, not `onready var`
   - `TileMapLayer`, not `TileMap`
   - `CharacterBody2D/3D` with `move_and_slide()` taking no arguments
   - `Callable(self, "method")` or `self.method` for callbacks
   - `PackedStringArray`, `PackedVector2Array`, not `PoolStringArray`
   When unsure, check the offline docs at `$GODOT_DOCS` (see `docs/setup.md`) instead of guessing.
2. **`main` is always playable.** If a change breaks the boot scene, revert first, fix second.
3. **Work on your lane's branch, PR into `dev`.** Never push to `dev` or `main` directly.
   Branch name: `feature/<lane>-<short-thing>`. One task per branch.
4. **Tests must pass before a PR.** Run:
   `godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests`
   A red test blocks merge. Add a test when you add a system.
5. **Stay in your lane's folders.** Ownership is in `docs/lanes/`. If you need a change in a
   folder you do not own, open a PR against that lane's branch, or ask Hermes.
6. **Contracts before code.** Shared signals and APIs live in `docs/contracts.md`. Code against
   the contract, not against another lane's branch. If the contract needs to change, change the
   doc first in its own PR.
7. **Sound on every action.** Every input that does something plays a sound and shows a visual.
   No exceptions. Use `Audio.play("cue_name")`.
8. **Kid-design checklist.** `docs/kid-design.md`. The Reviewer runs it on every gameplay or UI PR.
9. **Credits for every asset.** Nothing lands in `assets/` without a line in `assets/CREDITS.md`
   (tool or source, prompt if generated, license). Generated art must not depict or imitate
   recognisable characters, brands or artists.
10. **Performance budget:** 60 fps at 1920x1080 on a GTX 1060. Profile with the built-in monitors
    before optimising. Do not pre-optimise. C# is allowed for hot paths once profiling shows one.

## Project layout

```
GAME.md                 Design doc. Source of truth for this game. Hermes owns it.
.godot-version          Pinned Godot version.
project.godot           Input map, autoloads, display settings. Systems lane owns it.
scenes/main.tscn        Boot scene: title card, controller detection, drop-in P2.
scenes/players/         Player scenes. Systems lane owns.
scenes/levels/          Levels / rounds / arenas. Gameplay lane owns.
scenes/ui/              Pause, restart, HUD. Systems owns structure, Art owns theme.
scripts/autoload/       Game.gd, Save.gd, Audio.gd, Debug.gd, Players.gd, Roster.gd. Systems lane owns.
scripts/gameplay/       Gameplay lane owns.
data/                   .tres / .json content: upgrades, enemies, waves. Content lane owns
                        (except roster.json: written by scripts/tools/sync_characters.sh).
assets/characters/      Vendored playable characters (sync_characters.sh). Do not edit by hand.
assets/                 sprites, models, audio, fonts. Art and Audio lanes own.
art/prompts/            Generation prompt packs for this game's look. Art lane owns.
store/                  grid.png (600x900), hero.png (920x430), clip.mp4 for the launcher.
tests/                  gdUnit4 tests.
playtests/              Dated playtest reports. Hermes writes them from Kaden's notes.
docs/                   lanes/, contracts.md, kid-design.md, art-direction.md, setup.md.
addons/openjar/         Submodule → openjar-addons (shared input, UI theme, save, characters).
.github/workflows/      release.yml: on tag, test + export + attach to Release.
```

## Branching and releases

| Branch | Merged by | Produces | Runs where |
| --- | --- | --- | --- |
| `feature/<lane>-*` | the lane, via PR to `dev` | nothing | your session |
| `dev` | Reviewer lane | pre-release `vX.Y.Z-dev.N` on every merge | TV, the `(dev)` tile |
| `main` | Hermes, after a playtest | release `vX.Y.Z` | TV, the main tile |

Hotfixes to `main` are allowed only for a crash or a controller bug, from a branch off `main`,
merged back into `dev` the same day.

## Running things

```
godot --path . --editor                          # open the editor
godot --path .                                   # run the game
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests   # tests
godot --headless --path . --export-release "Linux" build/game.x86_64        # export
```

`Debug.gd` adds an FPS overlay (F3) and screenshot-to-disk (F12 → `user://screenshots/`).
Use screenshots to verify visual work; the Reviewer will ask for them on visual PRs.

**See your own work.** `--headless` has no renderer, so its screenshots are blank. To check visuals,
take real frames with `scripts/tools/shots.sh [scene] [times] [out_dir]` (for example
`scripts/tools/shots.sh res://scenes/main.tscn 1,3,6 /tmp/shots`), then look at the PNGs and fix what
looks wrong before you hand off. On the producer box it renders Forward+ on a software GPU (about
10 to 20 s per run, frame rate meaningless); on a desktop it uses the real display. Attach the PNGs
to visual PRs.

## Players and colours

Player 1 is always **green**, Player 2 is always **red**. The first controller to press a
button becomes P1. `Players.gd` owns the mapping; never hard-code device ids.

Players choose who they play as in the lobby (`Roster`, `docs/roster.md`). Jeff is the P1 default
and Chuck the P2 default; any playable character can be either player, never both at once. The
slot's colour (green / red) stays with the player whoever they pick. Spawn the player's character
from `Roster.info(Roster.pick(p))`, never a hard-coded Jeff or Chuck. Residents (Mole, Dragon, ...)
are never playable.

## Commit messages

Imperative, under 72 chars, lane prefix: `systems: add round state machine`,
`art: swap placeholder kicker for Jeff v1`, `content: add 12 tier-2 upgrades`.
