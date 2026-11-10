# Prompts: treasures

Treasures are the reward, so they are the brightest, cleanest things underground. Each one is a single
object a 5-year-old names in one word.

FRAMING: `A single object, side view, centred, on a [W] by [H] pixel grid, shown at 8x. Clean and
bright against where it will be buried; a white glint up-left.`

Colour rule: treasures use gold `{gold}`, pink `{pink}`, cream, steel `{metal}` and sky blue. Never the
player green or red, and never the dominant colour of the layer they are buried in.

| Layer | Treasure | Grid | SUBJECT |
| --- | --- | --- | --- |
| Topsoil | Bottle cap | 10x10 | `A round gold bottle cap with a crimped edge and a darker centre.` |
| Topsoil | Boot | 14x14 | `One old brown lace-up boot with a floppy tongue and a hole in the toe.` |
| Topsoil | Bike | 32x22 | `A small child's bicycle, sky blue frame, cream tyres, a bell.` |
| Clay | Buried car | 64x32 | `A rounded little old-fashioned car in faded sky blue, dusty, one headlight cracked.` Breaks into 4 chunks |
| Clay | Bathtub | 32x20 | `A white claw-foot bathtub with gold feet and one tap.` |
| Clay | Fossil | 16x16 | `A cream spiral shell fossil set in a small slab.` |
| Stone | Giant tooth | 16x24 | `A huge cream pointed tooth with two roots.` |
| Stone | Dinosaur skeleton | 96x48 | `A friendly cream dinosaur skeleton lying on its side, smiling skull, big round eye sockets.` Found in 6 pieces |
| Stone | Geode | 14x12 | `A grey rock cracked open showing pink crystals inside.` |
| Ice | Pirate chest | 24x18 | `A wooden chest with gold bands, lid ajar, gold coins showing.` |
| Ice | Frozen fish | 10x6 | `A small pale blue fish, surprised eye.` |
| Crystal | Dragon Egg | 20x24 | `A large cream egg with pink and gold spots and a tiny crack.` |
| The Bottom | The hoard | 48x16 | `A low heap of gold coins with a pale top and a few white glints.` |

## Sparkle

Not part of the treasure sprite. A separate 4-frame overlay drawn above the dirt so it shows through
solid tiles from two tiles away: `a white dot` / `a small white plus` / `a four-point star, white
centre, pale gold arms 4 pixels long, gold pixels in the diagonals` / `a small white plus`. Two smaller
one-pixel-arm twinkles orbit it. In the dark (no Lighthouse yet) the sparkle is not drawn at all.

## Icons for the build book and backpack

`The top-left 8 by 8 pixels of the block tile with a one-pixel outline.` Costs are shown as stacks of
these, never as numbers. Treasure icons for the Museum are the treasure sprite itself on a cream plinth.
