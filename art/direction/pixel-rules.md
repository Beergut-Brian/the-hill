> Copied from the-hill `feature/art-direction-options-2` (round 2). Images it mentions live on that branch, not here.

# The Hill: pixel rules

Every art lane on this game follows these. They hold for whichever palette Kaden picks; only the hex
values change. Reference sheet: `pixel-rules.png`. Reference implementation: `art/tools/hillpix.py`
(the mocks in this folder are drawn by it, so when a rule and the kit disagree, fix the kit).

## Scale and grid

- Design canvas is **640x360**, shown at **x3** on a 1080p TV. Split-screen halves are 320x360 at x3.
- Camera zoom is a whole number only: x3 is the design scale, x2 when the split director pulls out, x4 for
  the Dragon cutscene. Everything must still read at x2.
- Tiles 16x16. Characters 32 px tall in a 20x32 cell, feet on the bottom row, pivot bottom-centre.
  Vehicles 48 to 96 px long, wheels on the bottom row. Buildings are whole tiles wide (Barn 5x5 tiles,
  House 4x4, Old Shed 4x3, mine headframe 4x5) and sit on the ground row with no gap.
  The option mocks are a few pixels off these footprints; final art snaps to them.
- Nearest-neighbour everywhere. No rotation or non-integer scaling at runtime; things that turn (boulder,
  wheels, drill) get frames. Mirroring left/right is fine.
- No anti-aliasing against the background, no gradients, no soft glows, no sub-pixel motion.

## Outline policy

- **Sprites get a 1 px outer outline** in the palette's outline colour: characters, vehicles, props,
  treasures, buildings, residents. The outline colour is a tinted dark (plum, brown or navy depending on
  the palette), never `#000000`.
- **No interior outlines.** Inside a sprite, separate forms with the ramp's `low` or `deep` shade. The
  only interior use of the outline colour is faces: eyes, brows, mouths.
- **Tiles have no outline.** A tile next to open space gets lit and shaded edges instead: top row and
  left column in `high`, bottom two rows `low` then `deep`, right column `deep`, and outer corners lose
  one pixel. Tiles buried among neighbours show texture only.
- **Backdrop has no outline** (sky, clouds, the far hill, the Ruined Keep on the peak) and uses at most
  two shades per shape. Outlined means "you can touch it".
- Dug-out tunnel wall is the layer's `wall` colour with sparse `wall dark` specks and a 3 px `wall dark`
  lip under any ceiling. Nothing else goes on the wall, so anything standing in a tunnel pops.

## Shading

- **Four shades per ramp: deep, low, mid, high.** `mid` covers most of the form. Pure white is extra and
  only for glints, teeth, eyes, sparkles and water foam.
- Ramps are **hue-shifted**, never plain darkened: shadows lean toward the palette's shadow hue (a
  blue-violet), highlights toward its light hue (a warm yellow). The numbers are in `palettes.md`.
- A 32 px character uses about 16 colours including outline and white. A tile uses its four ramp shades
  plus at most two accents (ore gold, rune glow, lava).
- No dithering in sprites or tiles. The two allowed uses are sky band seams and the headlamp ring seams
  (50% checker, 2 px deep).
- **Light comes from the top-left**, above ground and below. Round things get a `high` spot up-left and a
  `low` crescent down-right. The headlamp and the Lighthouse darken or reveal the scene in stepped rings;
  they never relight a sprite.
- **Reserved hues.** P1 green `#3cc24a` and P2 red `#e4393c` are identity only. No environment colour
  with saturation and value above 45% may sit at hue 100° to 150° or 345° to 8°. So grass is
  yellow-green, trees are teal-green, barns are brick (orange-red), lava is orange, and Jeff's comb is
  the palette `pink`. `make_direction.py` checks this and prints any trespass.

## How a character reads at 32 px

- **Two heads tall.** Hat and head take 15 of the 30 rows, torso 7, legs and feet 8. The face is the
  biggest thing on the sprite because the face is the joke.
- **Read order: hat colour, body colour, silhouette.** Squint (or halve the sprite to 16 px): Jeff is a
  green cap on a yellow blob, Chuck is a red cap on a black block. If a new frame fails that, redraw it.
- Eyes are 2 or 3 dark pixels wide; brows and mouths are 1 px lines. No pupils, no nose line (one `low`
  pixel at most).
- The player colour appears in at least three places on the sprite, top, middle and bottom, so a
  half-hidden character (in a cab, behind a tree, in water) still says whose it is.
- Hands are 2x2 blobs. Tools are held, never floating: the grip touches the hand.
- Residents (Mole, Gnome Foreman, Caveman) follow the same proportions, never wear green or red, and
  are 24 to 32 px tall. The Dragon is the one sprite allowed to break the size rules.

### Jeff (P1) in pixels

Same character as his Jarling: chicken costume, bare feet, delighted.

- **Hard hat is the P1 green**, worn over the chicken hood, with a `high` glint up-left. It replaces the
  green headband as his main green mark.
- **The comb pokes out through the top of the hat**, 3 px wide, in the palette `pink` (the library says
  "not the player red"; in this game red is off-limits to everything but Chuck).
- Under the brim: a 4 px orange beak tip, a green band either side of it, then the yellow hood framing
  his real face. Costume yellow `#ffd84d` is fixed.
- Face: half-lidded eyes (dark 3x1 bars under a `low` skin lid), and a grin 8 px wide with a white tooth
  row. He is never not smiling.
- Puffy yellow torso wider than his legs; **green wing tips** for hands; blue jeans `#3b5ba5` with two
  green stitch pixels; **bare feet** in skin tone, 5 px wide each, the biggest feet in the game.
- Posture: slouch. His idle leans 1 px and bobs.
- Shovel: wooden handle, steel blade up by his head so it reads in silhouette.

### Chuck (P2) in pixels

Same character as his Jarling: the hat is the silhouette, chest out, chin up, unimpressed.

- **Hard hat is the P2 red**, and it keeps the trucker hat's shape: flat top, brim sticking 3 px forward
  in the direction he faces. He has slapped the **T-Rex on the front as a sticker** in costume yellow
  (a 5x4 px lump with a jaw notch; do not try for more).
- He hates the hat, and the sprite says so: brows are 2 px thick and angled in, eyes are squints, mouth
  is a flat line. His idle has a two-frame gag where the hat slips over his eyes and he shoves it back.
- **Tie-dye**: near-black shirt (`#3a3846` lit, `#1e1e26` shaded) with one red swirl about 12 px across
  and a single white pixel. The swirl is his middle red mark.
- Blue jeans `#3b5ba5`. **Cowboy boots** in `#8a5a2b`: 4 px tall, toe pointing 2 px forward, a 1 px heel
  notch at the back. The heel must survive every frame.
- Posture: stiff. No idle bob, just a chest puff.

Never put green on Chuck or red on Jeff. In a vehicle only the head shows (top 13 rows), so the hat has
to carry the identity alone, and it does.

## Animation frame counts

| Thing | Animation | Frames | Notes |
| --- | --- | --- | --- |
| Character | idle | 2 | 2 fps. Jeff bobs, Chuck puffs. Plus a 2-frame gag every few seconds |
| Character | walk | 4 | 8 fps, contact / pass / contact / pass, 1 px head bob |
| Character | dig | 3 | wind up, hit (tool overshoots 2 px), recover. Hit frame holds 2 ticks |
| Character | jump, fall | 1 + 1 | squash 1 px on landing instead of a frame |
| Character | climb, carry, cheer, bonk, sleep | 2 each | bonk has circling stars as a separate 4-frame overlay |
| Vehicle | idle wobble | 2 | body shifts 1 px on its wheels; exhaust puff is a 3-frame particle |
| Vehicle | drive | 2 | wheel spokes swap; body bobs in code |
| Vehicle | tool (bucket, arm, tip, hook, drill) | 3 | rest, mid, full. Drill bit spins on 2 frames |
| Vehicle | lamp | 2 states | off, on (dusk, night, underground) |
| Building | unfold | 3 | flat pack, half up (squashed wide), overshoot; then the placed sprite. Plus one lit-window variant for dusk |
| Tile | water surface, lava surface | 2 | 3 fps |
| Tile | Strangestone | 4 | rune colour cycles; the tile itself does not move |
| Tile | crystal, ice glint | 2 | overlay twinkle on a few tiles, not on every tile |
| Prop | boulder roll | 4 | quarter turns |
| Prop | worm wave, cow chew, tree fall | 2, 2, 3 | |
| Treasure | sparkle | 4 | dot, small plus, big 4-point star, small plus. Drawn above the dirt, visible two tiles away |
| FX | dig particles | 1 | 2x2 px squares in the block's `mid` and `high`, moved in code |
| FX | dust, puff | 3 | cream circles, 2 shades |

## Vehicle style: no faces

- **No eyes, mouths, cheeks or expressions on any vehicle, in any option** (Kaden, round 2).
- **Headlights are lights.** One round lamp at the nose of the hood (about 6 px, metal rim, pale warm
  yellow lens, one white glint) plus one small square work light on the front of the cab roof. Pale warm
  yellow by day. At dusk, at night and underground they are the vehicle's real light source (a cone
  of light ahead). Never two round lamps side by side on the side view: that reads as eyes.
- **Friendly through shape and colour**: big rounded bodies, oversized round wheels, toy proportions
  (cab about a third of the length), one saturated body colour each (never green or red), a cream
  stripe and roof that tint to the driver's colour, chunky bucket teeth with rounded tips.
- **Personality comes from motion and sound**, not a face: idle bounce of 1 px on the wheels, exhaust
  puffs, the bucket "nods" when it picks something up, a horn toot.
- Bodies are big rounded boxes on big round wheels, one body colour per vehicle, none of them green or
  red: Front Loader yellow, Excavator orange, Dump Truck blue, Crane teal, Drill Rig steel with purple.
- **Stripe and cab roof** are cream when empty and turn the driver's green or red when a player is in.
  The driver's head shows in the cab window.
- Drawn facing right, mirrored for left. Tools (bucket, arm, hook) are separate sprites in steel `metal`.

## Checks before handing art on

1. View at 1:1 and at x3. Then halve it: does the read order still work?
2. Put both players on it. Do green and red still pop? (`make_direction.py` prints the numbers.)
3. Count shades. More than four in a ramp means something was blended; remove it.
4. Is the light top-left? Is the outline one pixel, unbroken, and not black?
5. Would a 5-year-old say what it is in one word?
