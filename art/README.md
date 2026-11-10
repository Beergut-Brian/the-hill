# The Hill: art

Godot ignores this folder (`art/.gdignore`). The game reads only `assets/sprites/`.

## The look

Kaden's pick: palette **A "Sandbox"** (bright toy box, plum outline `#3a2a44`, hue-shifted 4-shade
ramps, light from the top-left) with **D's depth**: back walls clearly darker than the tiles but still
the layer's hue, parallax caves behind open space, darkness that is never black, and light done by the
engine (`fx/` sprites + TileWorld's light pass). Day/dusk/night is a tint curve over the same art
(`direction/day-night.md`). Vehicles have no faces: one round nose lamp and one square roof lamp.

Rules: `direction/pixel-rules.md` (round-2 version), `direction/palettes.md`, `direction/day-night.md`.
Prompt packs (text only): `prompts/`.

## Regenerate

```
python3 art/tools/make_game_art.py
```

Writes every sheet under `assets/sprites/` plus `assets/sprites/manifest.json`, and prints a check
report: reserved-hue trespasses (must be 0), P1 green / P2 red CIE76 ΔE against every layer's tile
and back wall (under 25 fails), and frame counts. Exit code 1 if a check fails. It is seeded, so a
re-run is byte-identical. Python 3 + Pillow only; no Godot.

- `tools/hillpix.py`: palette A kit, copied unchanged from the round-2 direction branch.
- `tools/characters/px.py`, `residents.py`: approved resident drafts, copied unchanged from
  openjar-characters (`feature/the-hill-residents`). Do not edit; re-copy if the drafts change.

## Assets

The asset table (every file, size and layout) is the Art lane spec of 2026-11-10; the manifest is
the machine-readable version: `{"<name>": {"file", "frame": [w, h], "rows": {"<anim>": {"row",
"frames", "fps"}}, "pivot": [x, y], ...points}}`, frame pixels, y down. Code reads sizes, pivots and
points from it and never hard-codes them. Credits: `assets/CREDITS.md`.

## Where this differs from the spec

- `props/tree.png` has a second row, `trunk` (4, 3, 2, 1 tiles): the stump left after the crown is
  scooped. Row `tree` is the whole tree that tall (1 tile = a bush).
- `buildings/garage_lit.png` has the same 3 frames as `garage.png` (shut, half, open): the bulb inside
  only glows where the door is up.
- `surface/sky_bits.png` is one 256x96 sheet; `regions` in the manifest give `[x, y, w, h]` for sun,
  moon, `cloud0..2` and `stars`. `props/rock.png` is one 48x16 sheet with `small` and `wide` regions.
- Front Loader bucket frames are 40x40 with the hinge at (20, 20). The Excavator arm sheet
  (`excavator_arm.png`, 56x60 frames, pivot = boom root) includes its bucket; there is no separate
  excavator bucket file.
- Edgestone: an exposed left or right side gets the gold/plum hazard stripe instead of the lit/shaded
  rim (pixel-rules: "obviously the edge"); up and down sides get the normal rim. Strangestone is
  brickwork, so it has mortar joints by design (8 px courses, vertical joints offset every course).
- Jeff and Chuck: head and torso are the approved A sprites from `hillpix.py`. Chuck's hard hat is the
  P2 red per pixel-rules (the characters-repo front draft has a black hat with a red brim). Jeff's feet
  are bare skin per pixel-rules; his comb is the approved raspberry `#D63384`. The backpack is not in
  the sprite (code draws it). `sleep` is the idle body with eyes shut, lying down, head to the right.
- Other roster characters (picked in the chooser) have no sheet here yet: `CharacterSheet`
  (`scenes/players/character_sheet.gd`) builds one at runtime from the synced front-view `pixel.png`
  in the same rows and frame counts. To hand-make one, add `characters/<id>.png` with player rows
  (`dig_side` at least) to this tool and the manifest; the game prefers it automatically.
- Residents' `idle` frame 2 is a 1 px breath of the approved front draft (no new pose). The Dragon has
  a gold hoard added in front of her belly.
- The Flooded Cabin sprite includes its pond band (translucent water from y 82 down; `waterline` in
  the manifest).
- The reserved-hue check lets the exact P1/P2 ramp colours through on vehicle sheets only (the green
  and red stripe rows are the driver's identity, which is the point).
