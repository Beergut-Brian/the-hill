> Copied from the-hill `feature/art-direction-options-2`, `art/prompts/` (text only).

# Prompts: characters

Jeff and Chuck are player-locked library characters. Their bibles and look notes in
`openjar-characters` win over anything here; this file only says how they translate to 32 px. The pixel
look sheets made from these go back into the library.

FRAMING for every character: `Full body, standing, facing right, 32 pixels tall on a 20 by 32 pixel
grid, feet on the bottom row. Two heads tall: the head and hat are half the height. Big readable face.
Shown at 8x so every pixel is a clear square.`

## Jeff (P1, green)

```
SUBJECT: A cheerful man in a yellow chicken costume and a bright green {p1} construction hard hat.
A small pink chicken comb pokes up through the top of the hat. Under the hat brim, an orange beak tip
and a green band, then a yellow hood around his real face. Half-closed happy eyes and a huge open grin
with white teeth. Puffy yellow body, bright green wing-tip hands, blue jeans with two green stitches,
big bare feet. Relaxed slouch. He holds a wooden shovel upright, steel blade up beside his head.
Green appears only on the hat, the band, the hands and the stitches. No red anywhere.
```

## Chuck (P2, red)

```
SUBJECT: A grumpy, proud man in a bright red {p2} construction hard hat shaped like a trucker cap:
flat top, brim sticking forward. A small yellow dinosaur sticker on the front of the hat. Thick angry
eyebrows, squinting eyes, flat unimpressed mouth; he hates the hat. Black tie-dye T-shirt with one red
swirl and a single white dot. Blue jeans. Brown cowboy boots with pointed toes and a clear heel.
Stiff posture, chest out, chin up. Red appears only on the hat and the swirl. No green anywhere.
```

## Sheets to ask for

One sheet per character, each frame in its own 20x32 cell, in this order (frame counts from
`pixel-rules.md`): idle 2, idle gag 2, walk 4, dig 3, jump 1, fall 1, climb 2, carry 2, cheer 2, bonk 2,
sleep 2, head-only for vehicle cabs 1. Brief each row as `the same character, same colours, [action]`
and include the previous approved frame as the reference image if the tool allows it.

Idle gags: Jeff holds up a rock and admires it. Chuck's hat slips over his eyes and he shoves it back.

## Residents (after their bibles are approved in the library)

Do not generate these until `openjar-characters` has the bible and look notes. When it does, use the
same FRAMING and these constraints:

| Resident | Size | Constraints for the SUBJECT |
| --- | --- | --- |
| The Mole | 24 px | Round, dusty brown-grey, big pink nose, tiny round glasses, squint. Holds a shovel that is obviously not his. Apologetic |
| The Gnome Foreman | 24 px | Tiny hard hat in `{veh}` yellow (never green or red), white beard, clipboard, whistle. Very serious |
| The Caveman | 32 px | Shaggy hair, fur wrap in `{wood}` brown, huge delighted smile, pointing. In ice: the same sprite behind a pale blue block |
| The Dragon | about 160 x 96 px | Round, sleepy, soft. A soft colour that stands off the chosen cavern (teal or lavender body, cream belly). Half-closed eyes, small rounded teeth or none, tiny wings. Curled around a gold pile. Enormous and not scary |

None of the residents wears green or red.
