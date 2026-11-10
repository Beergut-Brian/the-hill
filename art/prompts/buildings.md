> Copied from the-hill `feature/art-direction-options-2`, `art/prompts/` (text only).

# Prompts: buildings, ruins and scrub

FRAMING for every building: `Front view, flat, no perspective, standing on the bottom row of a [W] by
[H] pixel grid (multiples of 16), shown at 8x. Warm, sunny, storybook small-town building, chunky and
simple, with one charming detail.`

Hillville is the warm half of the game. Walls are cream `{wall}`, timber is `{wood}`, roofs are slate
blue `{roof}` or dark plum `{roof2}`, barns are brick `{barn}` (orange-red, deliberately not the player
red). Grass is yellow-green and trees are teal-green so Jeff's green stays his.

| Building | Tiles | SUBJECT |
| --- | --- | --- |
| Barn | 5x5 | `A barn with a rounded gambrel roof, brick-red {barn} plank walls, cream trim, big double doors with a cream X brace on each, a small hayloft window with yellow hay.` |
| House | 4x4 | `A small cottage with cream clapboard walls, a slate blue shingle roof, a brick chimney, a wooden door with a brass knob, one four-pane window with a flower box.` Dusk variant: `the window glows warm yellow` |
| Garage | 5x4 | `A wide workshop garage with a roll-up door half open, a striped awning, a tyre leaning on the wall.` |
| Workshop | 4x4 | `A timber workshop with a big anvil sign, a crooked stovepipe and a workbench outside.` |
| Lighthouse | 3x8 | `A tall round lighthouse with cream and blue bands and a glass lamp room on top.` |
| Water Tower | 3x6 | `A round wooden water tank on four tall legs with a little pointed roof. Generic; no lettering.` |
| Mine headframe | 4x5 | `A timber mine headframe: two braced legs, a small pointed roof, a steel pulley wheel at the top, a cable down the middle, a steel elevator cage at the bottom, a small lantern.` |

**Unfold animation** (3 frames before the placed sprite): `the same building as a flat stack of its own
panels on the ground` / `half popped up, squashed wide and short` / `fully up and stretched 2 pixels
too tall`. Add a dust puff in the engine, not in the art.

## Ruins

Ruins read **broken and waiting**, not spooky: weathered grey-brown `{weath}` boards, missing planks,
a lean, a little yellow-green moss. No cobwebs, bones, bats or dark windows with eyes.

| Ruin | Tiles | SUBJECT |
| --- | --- | --- |
| Old Shed | 4x3 | `A small collapsed garden shed of weathered grey boards, leaning to one side, half its roof slid off onto the ground, the door hanging from one hinge, gaps where planks are missing, tufts of moss.` |
| Flooded Cabin | 5x4 | `A log cabin sunk to its windows in a clear blue puddle, roof sagging, a rubber duck floating by the door.` |
| Crooked Watchtower | 3x7 | `A tall thin timber watchtower bent in a gentle S, its little roof askew, a rope ladder with missing rungs.` |
| Ruined Keep | 6x6 | `A small round stone castle keep with a broken corner, tumbled blocks at its foot, a tattered cream flag.` Also a 22 px backdrop silhouette for the hilltop, two shades, no outline |

Each ruin needs its restored twin (Lost & Found, Museum, Gnome Village, Dragon Perch) on the same
footprint, in the warm building colours above.

## Scrub and props

FRAMING: `Side view, standing on the bottom row, shown at 8x.`

| Prop | Size | SUBJECT |
| --- | --- | --- |
| Tree | 44x60 | `A round leafy tree made of four overlapping teal-green {leaf} blobs with pale spots up-left, on a short brown trunk with two root flares.` Fall: 3 frames |
| Rock | 22x15 and 16x11 | `A smooth grey {rock} boulder, pale spot up-left, dark crescent down-right, one small crack.` |
| Boulder (falls underground) | 26x26 | `A round grey rock, same shading, two cracks.` Roll: 4 quarter turns |
| Stump | 18x13 | `A short tree stump with a pale ringed top and two root flares.` |
| Rusty fence | 14 px per post | `Weathered grey fence posts joined by two sagging rust-brown wires; one post snapped and leaning.` |
| Cow | 28x20 | `A round cream and brown cow, tiny legs, big pink nose, chewing.` |
| Block pile at the shaft | 8x8 each | The top-left 8x8 of each block tile, outlined; stack them |
