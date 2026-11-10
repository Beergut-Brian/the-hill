# Prompts: vehicles

FRAMING for every vehicle: `Side view, facing right, wheels on the bottom row, [W] by [H] pixel grid,
shown at 8x. A big rounded toy construction vehicle with oversized round wheels.`

FACE block, added to every SUBJECT (see "Vehicle face style" in `pixel-rules.md`):

```
It has a friendly face on the front of its hood: the two round white headlights are its eyes, each
with a dark pupil looking forward and one white glint; the bumper line under them is a small smile
with upturned ends; two tiny pink cheek squares. Happy, never angry.
```

STRIPE block: `A cream stripe along the body and a cream cab roof.` For a driven version say
`bright green {p1}` or `bright red {p2}` instead, and `the driver's head in a hard hat shows in the cab
window`.

| Vehicle | Grid | Body | SUBJECT |
| --- | --- | --- | --- |
| Front Loader | 90x52 | yellow `{veh}` | `A front loader: boxy cab at the back with a blue glass window, rounded engine hood in front, short exhaust stack, big rear wheel and smaller front wheel, a steel bucket with three teeth held low in front on a short arm.` |
| Excavator | 96x64 | orange | `An excavator: rounded cab on a turntable over two caterpillar tracks, a two-part steel arm reaching forward and down ending in a toothed scoop.` Face on the cab front, under the window |
| Dump Truck | 96x56 | blue | `A dump truck: small rounded cab in front, a huge open tipping bed behind piled with dirt blocks, three big wheels.` |
| Crane | 96x96 | teal | `A mobile crane: rounded truck body on four wheels, a tall steel lattice boom rising up and forward, a cable and a round hook.` Boom and hook are separate pieces |
| Drill Rig | 64x96 | steel grey with purple trim | `A drill rig: a tall rounded tower on caterpillar tracks with a big spiral steel drill bit pointing straight down beneath it and a small cab on the side.` Face on the cab |

No vehicle body is green or red; those are the stripe colours.

## Pieces to ask for per vehicle

1. Body, empty, happy face (2 idle frames: the body 1 px lower on its wheels in the second).
2. The three other faces as hood-only patches: blink, effort, surprised.
3. Wheels or tracks: 2 frames.
4. Tool in 3 positions (bucket low / mid / tipped; arm folded / mid / reached; bed flat / half / tipped;
   hook up / mid / down; drill bit 2 spin frames).
5. Stripe and roof mask, so the engine can tint it per driver.
6. Exhaust puff: 3 frames, cream, two shades.

v1.1 vehicles (Bulldozer, Cement Mixer, Steamroller, Paver, Tunneler) use the same FRAMING, FACE and
STRIPE blocks with a new body colour each, still never green or red.
