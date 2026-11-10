# The Hill: art direction, round 2

Kaden picked **A Sandbox** in round 1, asked for a day/night cycle, and asked to see two styles that are
actually different, not more palettes. This folder has those: **D Terraria-leaning** and **E Picture
book**, plus the day/night plan. These are option mocks drawn in code, not final art. Start with
**`compare_all.png`** (A, D and E side by side on the same spot in Hillville), then **`compare.png`**
(D on top, E below: layers and Hillville).

## What changed since round 1

- **A, B and C stay.** A is the day look; B and C are the dusk and night keyframes of one cycle. See
  `day-night.md` and `day_night_strip.png`. It is a tint curve over A's art, not three art sets.
- **No eyes or faces on vehicles, in any option.** Headlamps are lights: one round lamp at the nose,
  one square work light on the cab roof. Friendly comes from shape and colour: round bodies, big round
  wheels, one bright body colour, a cream stripe that tints to the driver's colour. Updated:
  `../direction/pixel-rules.md` (and its sheet), `../prompts/vehicles.md`, and the Loader in every mock
  here. Round 1's nine mocks in `../direction/` are left as Kaden saw them, face included; A is redrawn
  without it in `compare_all.png` and the day/night strip.

## D Terraria-leaning

Dense 16 px pixel tiles with real material in them: specks and pebbles in the dirt, banded clay,
cracked cobbled stone, streaked ice, faceted crystal, ember-flecked basalt at the Bottom, copper, gold
and gem veins. Every block has a dark edge and a lit rim where it meets air. Light is worked out per
tile (sky, torches, headlamp, lava, gems), fades softly from tile to tile and is multiplied over the
world, so there is a true lit/unlit boundary; dug tunnels show a darker back wall, and the big cavern
opens onto parallax cave layers. The surface has a smooth sky, two mountain ranges, the Hill and a
tree line as separate depths. Jeff and Chuck are about 2.6 heads tall instead of 2, in an earthier
palette with five shades per material. **Good at:** adventure, depth, the feeling of pushing light
into the dark; it is the look Kaden asked for and the one an adult will want to keep playing.
**Bad at:** reading from the sofa. Texture competes with treasure and players, the characters' faces
are about 7 px wide, and real darkness is close to black on a TV in a daylit room (`d_split.png`, right
half, is already lifted from true black). **Build cost vs A: about 2x the art.** Same engine grid, same
sprite sizes, same 2-tile collision box. Extra: 3 or 4 texture variants plus edge pieces per block
type, a back-wall tile per layer, 3 parallax layers per depth, five-shade ramps, and the tile light
pass. That light pass is the only engine cost, and the game needs some form of it anyway because
depth is gated by light.

## E Picture book (my pick for the second style)

No pixels. Warm ink lines that wobble a little, flat gouache colour with a painted shadow side, earth
that is cut in rounded shapes instead of squares, paper grain under everything. Material is said with
a few drawn marks (pebbles, strata lines, cracks, facets) rather than texture. The dark is a blue
night wash in two painted steps with pools of lamp light, so unlit ground stays readable and is never
black; things that shine get little glow ticks, the way a picture book draws them. Characters are 2
heads tall with big faces. I chose this over "modern pixel art with dynamic lighting" for two
reasons: that option would sit between A and D (bigger pixels plus D's light) and would not be a third
direction; and a picture book is the visual language a 5-year-old already reads, while the line and
paint quality is something an adult enjoys looking at for hours. **Good at:** sofa readability (big
flat shapes, outlines everywhere, both players pop on every layer), charm, and standing out; nothing
else in the dig-down genre looks like this. Image models are also much better at picture-book props
and characters than at strict pixel grids. **Bad at:** digging. The game removes one square cell at a
time and this style wants rounded, inked edges, so the terrain needs either a 47-piece edge set per
block type or a contour shader, and layer seams and fluids need the same care (the mock leaves the
seams as plain steps). Line weight must stay constant, so nothing can be scaled or zoomed freely.
**Build cost vs A: about 3x the art, plus engine work.** The grid stays 16 world units per cell, but
art is authored at **48 px per cell** (3x, nine times the pixels; 96 px per cell if 4K ever matters),
characters are 96 px tall drawings, pixel snap goes off, filtering goes to linear, and animation moves
from 4-frame pixel loops to cut-out rigs or 6 to 8 drawn frames per action. `pixel-rules.md` would be
replaced by a line-and-paint rules doc.

## Recommendation among A, D and E

**Keep A as the base, and take D's light and depth into it.** A is still the one a 5-year-old reads
fastest, it is the cheapest to build, and Kaden already likes it. What round 2 shows is that the
biggest step up is not the tile texture, it is the lighting model and the layered backdrop: soft
per-tile light, glowing finds, back walls, parallax, lamps that are real lights, and the day/night
cycle. All of that can sit on A's clean tiles, with A's floor on darkness (dim blue, never black).
Cost: roughly A plus a third.

If it has to be one of the two new styles: **E for the two of them together, D for Kaden alone.** E is
the better family game and the more distinctive one, but it is the expensive choice and its risk is
the dig terrain; I would want a one-day engine spike on the rounded edges before committing. D is the
safer build and the closest to what Kaden named, but it is the one where the 5-year-old loses the
most: smaller faces, busier ground, darker dark. A middle path that costs little: D's tiles under A's
characters and vehicles, with the darkness floor raised.

| | A Sandbox | D Terraria-leaning | E Picture book |
| --- | --- | --- | --- |
| Rendering | Flat pixel, 4 shades, soft outline | Textured pixel, 5 shades, tile light | Ink and paint, no pixels |
| Art per cell at 1080p | 16 px shown x3 | 16 px shown x3 | 48 px drawn |
| Characters | 2 heads, 32 px | 2.6 heads, 32 px | 2 heads, 96 px drawn |
| The dark | Overlay rings (mock) | Per-tile light, near black | Blue wash, pools of light |
| Reads from the sofa | Best | Weakest | Good |
| Feels like an adventure | Least | Most | Middle |
| Art build vs A | 1x | about 2x | about 3x, plus terrain edge work |
| Engine changes | None | Tile light pass | 3x textures, no pixel snap, edge set or shader, rigs |

## Files

| File | What |
| --- | --- |
| `compare_all.png` | A, D and E: headframe, Chuck and the Front Loader, same window, 1:1 |
| `compare.png` | 2x2: D layers, D Hillville, E layers, E Hillville (half size) |
| `{d,e}_layers.png` | Every layer top to bottom, coin, bone, gems, ore, boulder, water, lava, the hoard, tiny Jeff digging. Left of the fade is lit; right is real light only (one torch, gems, daylight down the shaft) |
| `{d,e}_hillville.png` | Old Shed ruin, House, Barn, block pile, shaft and headframe, Chuck, Front Loader, scrub half cleared, the Hill and the Ruined Keep |
| `{d,e}_split.png` | Split screen: Chuck driving the Loader up top, Jeff digging by headlamp below |
| `{d,e}_palette.png` | Swatches with hex values and the sprites at a larger size |
| `day-night.md`, `day_night_strip.png` | The A to B to C cycle |
| `../tools/` | `python3 art/tools/make_direction2.py` redraws D, E and the sheets; `make_day_night.py` the strip. `scenes2.py` holds the scenes and object shapes both styles draw from |
| `../prompts/styles-d-e.md` | Style blocks for briefing either look |

## Known limits of the mocks

- D and E draw the same scene data and the same object outlines so they can be compared like for
  like. Real art in either style would push proportions further apart (D leaner, E rounder).
- One pose per character, one vehicle, three buildings. Residents and the Dragon are not shown.
- E's layer seams and lava have no ink edge yet, and its glow ticks and wash are drawn into the mock;
  in the game they are a shader and sprites. D's light is the real algorithm at tile resolution.
- The lit half of the layer strips is a mock convenience (an ambient floor); the right side is honest.
- The folder has a `.gdignore`, so Godot neither imports nor exports anything in it.
