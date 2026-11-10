# The Hill: art direction options

Three palette options for Kaden to pick from, each shown as real pixel art at the real scale (16 px
tiles, 32 px characters, a 90 px Front Loader, composed at 640x360 and shown x3 at 1080p). These are
option mocks drawn in code, not final art. Start with **`compare.png`**: one column per option, rows are
the layer strip, Hillville, and a split-screen moment.

## The options

- **A Sandbox.** Bright toy box: candy-clean layers, a light cyan sky, soft plum outlines. The cavern is rose.
- **B Storybook.** Golden-hour picture book: dusty, cosy, cream light, an autumn tree, an amber cavern.
- **C Lantern.** Late-afternoon adventure: deep jewel layers, near-black tunnels, glowing finds, a wine cavern.

## Recommendation: A Sandbox

1. **It leaves room for the dark.** Depth in this game is gated by light, and darkness is laid on top of
   the palette. A starts bright, so an unlit Stone layer still shows its colour and its tunnels. C starts
   dark, so headlamp-only areas go close to black on a TV in a daylit room (compare the right halves of
   `a_split.png` and `c_split.png`).
2. **It reads from the sofa.** Highest values, cleanest hues; a 5-year-old can name every layer by colour,
   and treasures and both players stand out everywhere (worst player contrast ΔE 41).
3. **It matches the family.** The Jarlings and the first two games are bright, saturated and sunny. A is
   the pixel version of that; Jeff and Chuck look like themselves in it.
4. **Hillville stays the warm, sunny place.** B's town is the prettiest of the three, but its underground
   pays for it (below). C's saturated sky competes with its own underground.

What the others are better at, honestly: **C** separates the layers best by the numbers and makes
treasure glow hardest; if the game turns out to be played mostly in the evening, it is the dramatic
choice. **B** has the most charm up top, and its look is the natural *dusk* shift for whichever
palette wins (the day/night cycle is a palette shift, and B is a ready-made evening).

| | A Sandbox | B Storybook | C Lantern |
| --- | --- | --- | --- |
| Worst player pop (ΔE, 40+ is comfortable) | 41, red on the rose cavern | 35, red on clay | 40, red on clay |
| Closest two layers (ΔE, under 20 smears) | 26, Stone / Edgestone | 23, Stone / Edgestone | 33, Topsoil / Edgestone |
| Hoard gold on the cavern tile (ΔE) | 90 | 27 | 111 |
| Weak spot | Underground is cheerful rather than deep | Washes out at TV distance; gold nearly vanishes on amber | Dark before the darkness mechanic is even applied |

Mixing is cheap. Every colour comes from one spec in `art/tools/hillpix.py`, so "A, but with B's amber
cavern" or "A, with C's darker tunnel walls" is a one-line change and a re-render.

## What is the same in all three

- P1 green `#3cc24a` and P2 red `#e4393c` are identity only. No scenery colour in any option sits in
  either hue band (checked on every shade): grass is yellow-green, trees teal-green, barns brick, lava
  orange, Jeff's comb pink.
- Each layer owns a hue: topsoil brown, clay orange, stone grey-blue, ice pale blue, crystal purple, a
  warm cavern. Strangestone is dark teal with faint runes; Edgestone is flat grey with a hazard stripe.
- The pixel rules: `pixel-rules.md` and its sheet `pixel-rules.png`.

## Files

| File | What |
| --- | --- |
| `compare.png` | All nine mocks at 1:1 on one 1920x1080 sheet |
| `palette_{a,b,c}.png`, `palettes.md` | Swatch cards and every hex value, with the contrast numbers |
| `{a,b,c}_layers.png` | Every layer top to bottom: treasure sparkling in the dirt, falling boulder, water and lava pockets, Jeff with his shovel, and both players standing against each layer's tunnel wall |
| `{a,b,c}_hillville.png` | Old Shed (a ruin), House, Barn, block pile, mine shaft and headframe, Chuck, the Front Loader, scrub half cleared, the Hill with the Ruined Keep |
| `{a,b,c}_split.png` | Split screen: Chuck driving the Loader up top, Jeff digging by headlamp below |
| `pixel-rules.md`, `pixel-rules.png` | The rules for every later art lane |
| `../prompts/` | The prompt pack built on those rules |
| `../tools/` | `python3 art/tools/make_direction.py` redraws everything here |

## Known limits of the mocks

- One pose per character, one vehicle, three buildings. Enough to judge colour and scale, not a sprite set.
- Building sprites are a few pixels off whole-tile footprints; final art snaps (see the rules).
- The headlamp rings and the split divider are drawn into the mock; in the game they are engine effects.
- The residents and the Dragon are not shown: their bibles are not approved yet.
- The folder has a `.gdignore`, so Godot neither imports nor exports anything in it.
