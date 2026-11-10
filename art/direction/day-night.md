> Copied from the-hill `feature/art-direction-options-2` (round 2). Images it mentions live on that branch, not here.

# Day/night cycle: A to B to C

![Day, dusk and night on the same corner of Hillville](day_night_strip.png)

Made by `art/tools/make_day_night.py`. The crop is the same in all three columns (the mine headframe,
Chuck, the Front Loader). The strip crop does not reach the Barn or the House, so their windows are
not shown; they follow the same rule as the headframe lantern.

## 1. What Kaden asked for

Kaden picked A and asked for a day/night cycle. Round 1's three palettes become the keyframes:

- **A Sandbox = day.**
- **B Storybook = dusk, and dawn.**
- **C Lantern = night**, with a night grade on top (cool, darker, still readable).

## 2. How it works

It is a palette shift, not three art sets. Art is drawn once, in A. The engine blends three things:
the sky gradient colours, one `CanvasModulate` tint on the surface world, and light sources fading in.

| Moment | Sky top | Sky horizon | World tint (R, G, B) | Lights |
| --- | --- | --- | --- | --- |
| Morning | `#58c4f0` | `#a5e3fa`, warm band 20% | 1.00, 0.96, 0.92 | off |
| Midday (A) | `#58c4f0` | `#a5e3fa` | 1.00, 1.00, 1.00 | off |
| Golden hour (toward B) | A to `#9fd4d8` | A to `#f9e7bd`, warm band 50% | 1.00, 0.95, 0.90 | lamps and windows start |
| Dusk (B) | `#9fd4d8` | `#f9e7bd` plus orange `#ff8048` band | 1.00, 0.90, 0.84 | on, small |
| Night (C + grade) | `#0b1030` | `#2a3270` | 0.50, 0.55, 0.85 | on, big, stars and moon |
| Dawn (B, mirrored) | `#9fd4d8` | `#f9e7bd` plus orange band | 1.00, 0.90, 0.84 | fading out |

The strip uses exactly these dusk and night numbers. The Morning and Golden hour rows are in-between
values and are not rendered in the strip. Sun and moon are sprites that ride the sky.

## 3. Rules

- **P1 green and P2 red never tint.** Players and their HUD are drawn above the tint, or get a soft
  pool of light (the strip gives Chuck one so his red hat stays red).
- Treasures keep their sparkle at every hour.
- **Night is never darker than the strip's night column.** A 5-year-old must never be lost or scared:
  no black screens on the surface.
- **Underground ignores time of day.** It has its own light: headlamps and torches.
- Vehicle lamps and windows turn on at dusk. Lamps are lights, not eyes: one nose lamp and a square
  roof lamp, with a cone ahead of the vehicle.

## 4. Length

A full day is about 12 minutes, night about 3 of them. Both are tunable. Night can be the cosy time:
residents go home, windows glow. Optional.

## 5. Cost

One tint curve, one sky gradient, and about 6 light sprites (lantern pool, window glow, lamp cone,
lamp glow, moon, stars). No extra tile art.

## 6. If Kaden picks D or E instead

The same three keyframes apply as a tint curve on top of that style: same sky colours per moment,
same tints, same lights.
