# Prompts: tiles

FRAMING for every tile: `A single square ground tile filling the whole image edge to edge, 16 by 16
pixel grid, seamless when repeated in all four directions, viewed straight on as a cut-away of the
ground. Mostly the mid shade with a few marks; calm enough to sit behind characters.`

Make **four variants** of each so a wall of them does not repeat. Edges against open space are not
drawn into the tile; the engine or the lane adds them (see "Outline policy" in `pixel-rules.md`).

| Block | SUBJECT |
| --- | --- |
| Topsoil | `Warm dirt brown {topsoil.mid} soil with scattered darker specks, a few pale crumbs and one small pebble.` Variants add a thin pale root or nothing |
| Clay | `Terracotta orange {clay.mid} clay in two wavy horizontal bands with a thin darker seam under each and short pale highlights along the seams; one or two small dark pebbles.` |
| Stone | `Grey-blue {stone.mid} rock made of two rows of big irregular blocks, thin darker cracks between them, a short pale highlight on the top-left of each block.` Ore variant: `with a small cluster of six gold {gold.mid} nuggets.` |
| Ice | `Pale blue {ice.mid} ice, almost flat, with two short diagonal white scratches running up to the right and a few slightly darker flecks.` |
| Crystal | `Purple {crystal.mid} rock with two upright faceted crystal shards, each lit pale on the left facet and dark on the right, one white glint.` |
| The Bottom | `{bottom.mid} cavern rock, warm, with dark specks, two or three tiny gold flecks and sometimes a short glowing orange crack.` |
| Strangestone | `A dark teal {strange.mid} carved block with a thin bevelled frame, and in the centre one small pale glowing rune made of straight strokes on a 5 by 5 grid. Mysterious, not spooky.` About half the variants have no rune, only a centre stud. The rune is a separate colour so it can pulse |
| Edgestone | `A plain flat grey {edge.mid} block with a pale top-left bevel, a darker bottom-right bevel and four small rivet dots. Deliberately boring.` The hazard stripe is a separate 5 px wide overlay: `diagonal yellow and dark stripes` |

## Other tile pieces

| Piece | SUBJECT |
| --- | --- |
| Tunnel wall | `The same material as [block] but much darker and calmer, {layer.wall}, flat with a few slightly darker specks. Background, no highlights.` One per layer |
| Grass cap | `A strip of yellow-green grass {grass.mid} 4 to 6 pixels deep on top of dirt, ragged lower edge, a pale top row, a few taller blades.` Cleared plots use bare packed dirt with a pale top instead |
| Water | `Clear blue {water.mid} water, flat, with short pale horizontal dashes; the surface row is a pale line with white foam dashes.` 2 frames |
| Lava | `Bright orange {lava.mid} lava, flat, with short yellow horizontal dashes; friendly, like orange juice, not fiery.` 2 frames |
| Snow | `A flat white strip 4 pixels deep with a pale blue underside.` |

Check: lay all eight blocks in a column and squint. Each should be nameable by colour alone.
