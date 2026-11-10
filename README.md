# Open Jar Games — game template

Starter repo for every Open Jar Games title: small, loud, two-player couch games built in
Godot 4 by a producer agent (Hermes) and parallel agent lanes, played on the family TV box.

**Start here:** `CLAUDE.md` (rules for agents) → `GAME.md` (this game's design doc) →
`docs/lanes/<your lane>.md`.

## New game

1. "Use this template" → `Beergut-Brian/<game-slug>`, then create a `dev` branch and add the
   `openjar-game` topic.
2. `scripts/tools/rename_project.sh "<Game Name>" <game-slug>`
3. Design sprint with Kaden → fill `GAME.md` and `docs/art-direction.md`.
4. Systems lane builds the grey-box on `dev`, tags `v0.0.1-dev.1`.
5. All lanes go parallel. Reviewer merges to `dev`; Hermes promotes `dev` → `main` after a playtest.

## What is in the box

| Path | Purpose |
| --- | --- |
| `CLAUDE.md` | Agent guardrails: Godot 4 syntax, lanes, branches, tests, sound-on-every-action |
| `GAME.md` | Design-doc template; Hermes owns it |
| `docs/lanes/` | One file per agent lane: owns / never touches / hand-off / done |
| `docs/contracts.md` | Shared signals and autoload APIs lanes code against |
| `docs/kid-design.md` | The checklist every gameplay/UI PR must pass |
| `docs/art-direction.md` | House style + this game's technique and palette |
| `docs/setup.md` | Godot, docs, gdUnit4, submodule, export templates |
| `playtests/_TEMPLATE.md` | What Hermes fills from Kaden's voice note |
| `project.godot` | 1080p, Forward+, input map for P1/P2 (Xbox layout, 0.15 dead zone), autoloads |
| `scripts/autoload/` | `Players` (join, green/red), `Roster` (who you play as), `Game` (state machine), `Save`, `Audio`, `Debug` |
| `scenes/main.tscn` | Boot scene: press any button → spawn → round |
| `scenes/players/player.tscn` | Placeholder coloured-box player with move/jump/action + squash |
| `tests/test_smoke.gd` | gdUnit4: scene loads, input map complete, round cycle, save roundtrip |
| `export_presets.cfg` | Linux x86-64, embedded pck |
| `.github/workflows/release.yml` | Tests on PR; on `v*` tag, export + zip + GitHub Release (pre-release for `-dev`) |
| `.gitattributes` | Git LFS for png/glb/ogg/wav/mp4/ttf |

## Players

P1 is green (`#3cc24a`), P2 is red (`#e4393c`). First pad to press a button is P1.
Each player picks a character on their podium in the lobby (the chooser, `Roster`); Jeff is the P1
default and Chuck the P2 default. Picks are remembered across every Open Jar game and the launcher.
The roster is vendored from `openjar-characters` by `scripts/tools/sync_characters.sh` (`docs/roster.md`).

## Run

```
godot --path .                                                              # play
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests  # test
godot --headless --path . --export-release "Linux" build/game.x86_64       # export
```
