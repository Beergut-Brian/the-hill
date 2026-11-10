# The roster: who players can be (template copy)

Design: the character chooser plan (Kaden, 2026-11-10). Library side: `openjar-characters`
`docs/roster.md`. This page is the game side: how a game built from this template gets the
playable characters, remembers picks and spawns them. API: `docs/contracts.md` "`Roster`".

## 1. Vendoring the characters

```
scripts/tools/sync_characters.sh ~/openjar/openjar-characters v0.3.0
```

For every id in that tag's `characters.json` `roster` (playable characters only; residents such as
the Mole or the Dragon never appear) it copies into `assets/characters/<id>/`:

| File | What |
| --- | --- |
| `<id>.glb` | the 3D master (standard Jarling: `idle`, `run`, `kick`, `cheer`, ten gear slots). Godot extracts `<id>_*.png` textures on import; commit them too |
| `pixel.png` | the pixel form, front view at native size (40x32), drawn by the library's own sprite code (needs `python3` + Pillow) |
| `voice/*.ogg` | recorded barks (none yet in `v0.3.0`) |

and writes `data/roster.json` (roster order, names, defaults, player colours, `res://` paths, the
tag) and the characters block in `assets/CREDITS.md`. It reads the tag with `git show` (Git LFS
files are smudged), so the library checkout can be on any branch. Ids that left the roster are
removed. **New characters: rerun with the new tag, import, commit. No code change.**

Current: `v0.3.0`, Jeff (P1 default) and Chuck (P2 default).

## 2. Who each player is

`Roster` (autoload) resolves each slot at start, first hit that is in this game's roster:

1. `--p1-char=<id>` / `--p2-char=<id>` (the launcher passes them)
2. the shared picks file, `players.json[<profile>]["P1" | "P2"]`
3. `defaults` (Jeff, Chuck)
4. the first roster id the other player hasn't got

Unknown ids (a newer library's character, a resident, a typo) are skipped. Never the same character
twice: a clash moves P2 to the next free one.

## 3. The shared picks file

`OS.get_data_dir() + "/openjar/players.json"`, Linux `~/.local/share/openjar/players.json`,
outside every game's `user://`. Keyed by the launcher's save profile (`Save.profile`, from
`--profile=`), then slot:

```json
{ "p1": { "P1": "jeff", "P2": "chuck" } }
```

Written the moment a pick changes: read, change only this profile's two slots, keep every other
key, write `players.json.tmp`, rename. Tests point `Roster.picks_path` at `user://` so they never
write the real one.

## 4. The chooser

In the lobby, on your podium, before you ready up: left / right (stick, D-pad, keys) swaps your
character (squash, poof, pop, name bounce, bark or the `char_swap` cue), skipping the other
player's pick. A readies and locks it, B unlocks. Solo: Select switches which podium the pad
drives. Details and the per-game notes: `docs/ui.md` "The character chooser", "Per game".

## 5. Spawning the pick in game

```gdscript
var who := Roster.info(Roster.pick(player))
var body: Node3D = load(who.glb).instantiate()   # pixel game: a Sprite2D with texture = load(who.pixel)
rig.add_child(body)
```

- **Spaceballs**: the kicker rig loads `who.glb` under `jarling_rig.gd`; gear equips on any
  standard body; podium scene gets `set_character(id)`.
- **Junk Yard Zap**: the zapper rig loads `who.glb`; JYZ tools go in the standard gear slots.
- **The Hill**: pixel game; `who.pixel` on the podium and as the player's front sprite.

Player colours (`Players.COLOR`) stay with the slot: rings, arrows, HUD, glows. Never colour a
character green or red to mean a player.
