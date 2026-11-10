# The Hill: prompt pack

How to brief a later art lane or an image model for this game's art. Rules live in
`art/direction/pixel-rules.md`; colours live in `art/direction/palettes.md`. Read both first.

| File | For |
| --- | --- |
| `tiles.md` | The eight block types, tunnel walls, fluids, surface |
| `characters.md` | Jeff, Chuck, and the four residents once their bibles are approved |
| `vehicles.md` | The five construction vehicles and their faces |
| `buildings.md` | Town buildings, the ruins, scrub props |
| `treasures.md` | Treasures, sparkle, block icons |

## How to use it

1. **Pick the palette first.** Until Kaden chooses, prompts carry colour words plus tokens like
   `{clay.mid}`. Once chosen, replace tokens with the hex from that option's table in `palettes.md`.
2. Build a prompt as **STYLE + SUBJECT + FRAMING + AVOID**. STYLE and AVOID are below and never change.
   SUBJECT and FRAMING come from the per-category file.
3. **An image model's output is a concept, not an asset.** Models do not hold a pixel grid. Ask for the
   subject at 8x on a flat magenta background, then redraw or reduce it by hand to the true size, snap it
   to the palette ramps, add the 1 px outline, and check it against the rules. A lane that draws in code
   (as `art/tools/hillpix.py` does) can skip the model and use the SUBJECT text as its brief.
4. Every asset that lands in `assets/` gets a line in `assets/CREDITS.md`: tool, the full prompt if
   generated, licence.
5. Never name a game, studio, brand, artist or real place in a prompt. The reference feel in `GAME.md`
   is for people, not for models.

## STYLE (paste first, unchanged)

```
Chunky 2D pixel art game asset, side view, orthographic, for a cheerful co-op digging game for a
5-year-old. Hard square pixels on a strict grid, no anti-aliasing, no gradients, no blur, no glow.
Big simple shapes that read from across a room. Four flat shades per colour: deep, low, mid, high;
shadows lean blue-violet, highlights lean warm yellow. Light from the top-left. One-pixel dark tinted
outline around the object, never pure black; no outlines inside the shape. Friendly, round, toy-like.
Flat solid magenta background, nothing else in frame, no text.
```

For tiles, swap the outline sentence for: `No outline; seamless on all four sides.`

## AVOID (paste last, unchanged)

```
Avoid: photo, 3D render, painterly, smooth shading, soft shadows, dithering, noise, isometric or
three-quarter view, perspective, tiny details, thin lines, text, letters, logos, watermark, frame,
scenery behind the object, pure black outline, bright green or pure red anywhere except where the
brief asks for the player colour, anything scary, weapons, blood, real brands, real places, real
people, recognisable characters.
```

## Colour words to use with the tokens

| Token | Say |
| --- | --- |
| `{topsoil}` | warm dirt brown |
| `{clay}` | terracotta orange |
| `{stone}` | grey-blue |
| `{ice}` | pale blue |
| `{crystal}` | purple |
| `{bottom}` | the warm Dragon cavern colour of the chosen palette (rose in A, amber in B, wine in C) |
| `{strange}` | dark teal with pale glowing runes |
| `{edge}` | plain flat grey with a yellow and dark hazard stripe |
| `{p1}` | bright green `#3cc24a` (Jeff only) |
| `{p2}` | bright red `#e4393c` (Chuck only) |
| `{veh}`, `{metal}`, `{wood}`, `{wall}`, `{barn}`, `{weath}`, `{gold}`, `{pink}` | as named in `palettes.md` |

## Accept or redo

A result goes forward only if it passes the five checks at the end of `pixel-rules.md`. The two that
generated art fails most: more than four shades in a ramp, and green or red leaking into scenery.
