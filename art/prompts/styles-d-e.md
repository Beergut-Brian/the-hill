# Prompts: style blocks for D and E (round 2 options)

Only use these if Kaden picks D or E; A's rules are `art/direction/pixel-rules.md`. Put the STYLE
block first, then the usual FRAMING and SUBJECT from the other files in this folder. Colours are in
`art/direction2/{d,e}_palette.png`. Mocks: `art/direction2/`.

## D Terraria-leaning

```
STYLE: Detailed 16-bit pixel art for a 2D mining adventure. Dense hand-placed texture: every surface
shows its material (wood grain and plank seams, shingles, cobbles, specks in dirt, cracks in stone).
Five shades per material, hue-shifted: shadows cooler and richer, highlights warmer and paler. A dark
near-black plum outline on the outside, darker shades of the material itself for inside lines. Light
from the upper left. Earthy, rich colours, not candy. Hard pixels, no anti-aliasing, no gradients, no
dithering bands. Friendly, never grim: no skulls, gore or horror.
NEGATIVE: smooth shading, blur, glow painted into the sprite (light is added by the game), text.
```

Sizes stay as in A: 16 px tiles, characters 32 px tall on a 16 px wide body, about 2.6 heads tall.
Tiles need 3 or 4 texture variants each, plus a darker back-wall version. Draw everything fully lit;
the engine darkens it.

## E Picture book

```
STYLE: A children's picture-book illustration come to life. Clean, slightly wobbly dark-brown ink
outline of even weight around every shape. Flat gouache colour fills with one soft painted shadow
on the lower right and a pale edge on the upper left. A few drawn marks say what a material is
(pebbles, wavy strata, a crack, a facet) instead of texture. Round, chunky, friendly shapes. Warm
cream paper grain shows through. High resolution, no pixels.
NEGATIVE: pixel art, 3D render, gradients, photo texture, thin sketchy lines, heavy black shadows.
```

Sizes: 48 px per cell at 1080p, characters 96 px tall and 2 heads tall, outline 2.5 px at that size.
Draw every asset at its final size; never scale, or the line weight changes. The dark is a blue wash
added by the game, so draw everything in daylight.

## Both

Vehicles have no eyes, mouth or face (see `vehicles.md`). P1 green and P2 red are for the players
only. Nothing may depict or imitate recognisable characters, brands or artists.
