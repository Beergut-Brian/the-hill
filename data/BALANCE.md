# The Hill: balance sheet (C-27)

Pacing targets from the plan (`GAME.md`, Content lane deliverables): **the Buried Car in about
5 minutes, the Excavator by minute 15, the bottom of the hill in 3 to 4 hours of total play.**

Written 2026-11-11 by the Balance lane from `dev` at `52d17db`. `tests/test_balance.gd` recomputes
every number in a `name = value` line below from the data rows and code constants, so a data
change that moves one fails CI until this sheet is updated.

## What these numbers are

Each figure is a **floor**: the fastest one player who knows the way can do it, digging on foot
with the starting shovel, with no wandering, no hazards and no help from Player 2. Real play with a
5-year-old will be slower by a factor nobody has measured yet; only the F-4 playtest can time it.
So a floor **under** a target means "the target is reachable"; a floor far under a target means
the numbers alone do not make the game take that long.

## The building blocks

| Quantity | Value | Arithmetic | Source |
| --- | --- | --- | --- |
| Cell | 16 px | | `addons/openjar/tileworld/world_shape.gd` `cell_size` |
| Underground gravity | 980 px/s² | | `world_shape.gd` `gravity` (RectShape, straight down) |
| Shovel dig interval | 0.14 s | no Workshop yet (`TOOL_DIG` 0.35 per level only after one) | `scenes/players/hill_player.gd` `DIG_EVERY`, `dig_every()` |
| Walk speed | 200 px/s | | `hill_player.gd` `WALK` |
| Front Loader scoop interval | 0.35 s, 1 tile per scoop (clear area 1x1) | | `hill_player.gd` `SCOOP_EVERY`; `data/vehicles/front_loader.tres` |
| One row down on foot | `row_down_ms = 321` | 0.14 + √(2 × 16 / 980) = 0.14 + 0.181 | dig, then fall one cell |
| One column sideways on foot | `col_side_ms = 220` | 0.14 + 16 / 200 = 0.14 + 0.08 | dig, then walk one cell |
| Elevator ride | 1.6 s | 1.0 door wait + 0.6 ride | `scenes/game/elevator.gd` `DOOR_WAIT`, `RIDE_TIME` |
| Backpack | `backpack = 40` | 2 sizes × 20 (no Barn) | `scripts/autoload/Progress.gd` `BACKPACK_START`, `BACKPACK_PER_SIZE` |
| Topsoil landing floor | row 12 | landing top 9 + 3 rows of air | `scripts/gameplay/hill_generator.gd` `_plan`, `ROOM_H` |
| Clay landing floor | row 34 | Clay `depth_from` 30 + 1 + 3 | `data/layers/clay.tres`; `_plan` |
| Buried Car | rows 36–37, its right edge 10 to 25 columns left of the shaft | landing floor + 2; `CAR_REACH` (10, 25) by seed | `hill_generator.gd`; `data/treasures/buried_car.tres` (3x2) |
| Cavern roof | row 266 | | `hill_generator.gd` `CAVERN` |
| Garage cost | 20 clay, 10 stone (needs the Buried Car) | | `data/buildings/garage.tres` |
| Excavator unlock | Garage 1 rolls it out | | `data/vehicles/excavator.tres` (`order` 1, `needs_treasure` buried_car) |
| Shovel-proof blocks | none | every breakable block has `dig_tier` 0 | `data/blocks/*.tres` |

### Assumptions (in no file; kept generous)

| Allowance | Value | Why |
| --- | --- | --- |
| Intro cutscene, watched | 41 s | `docs/cutscenes.md` ("about 41 s"); A skips it |
| Spawn to the cage, once | 10 s | the bot does it in 3.3 s (demo log) |
| Front Loader: drive to rocks, clear the Garage plot | 30 s | the bot's P2 gets 11 stone and a cleared yard in about 6 s |
| Open the book and place the Garage | 10 s | the bot takes 1.7 s |
| Garage roll-out | 1 s | demo log 0.97 s |
| `vehicle_unlock` cutscene | 6 s | `docs/cutscenes.md` |
| Climb one row (dig a step, hop) | 0.75 s | |

The Mole's first theft needs 75 s underground and 12 tiles dug in Topsoil or Clay
(`data/story/mole_arc.json`); every floor below spends under 30 s underground in those layers, so
no theft lands inside a floor.

## Target 1: the Buried Car in about 5 minutes

| | |
| --- | --- |
| Target | about 300 s |
| Current floor | `car_floor_s = 66` (about 1 min 6 s) |
| Path | watch the intro, walk to the cage, ride down to Topsoil, dig straight down to the car's rows, tunnel left to it |
| Calculation | 41 intro + 10 walk + 1.6 ride + `car_rows = 26` rows × 0.321 + `car_cols = 25` columns × 0.220 = 41 + 10 + 1.6 + 8.34 + 5.50 = **66.4 s** |
| Rows | from the Topsoil landing floor (row 12) down through row 37, the car's bottom row: 38 − 12 = 26 |
| Columns | the worst seed, `CAR_REACH.y` = 25 (the default seed is nearer) |
| Cross-check | `--demo` (two bots, no intro, default seed): **buried car found at 9.22 s** of game time. Without the intro and the walk allowance the floor is 15.4 s for the worst seed; the bot is faster because the default seed's car is nearer and it drives the Front Loader to the cage |
| Status | **Meets.** The car is reachable well inside 5 minutes; the floor is 3 min 54 s under the target, so the minutes come from play, not from the numbers |

## Target 2: the Excavator by minute 15

| | |
| --- | --- |
| Target | at most 900 s |
| Current floor | `excavator_floor_s = 131` (about 2 min 11 s) |
| Path | the car (above); walk back and ride up; a second trip for the Garage's clay; Front Loader scoops 10 stone from surface rocks; build the Garage; it rolls out the Excavator |
| Why two trips | on the way down the bag fills with dirt first: 18 Topsoil rows × up to 2 cells = 36 of 40, so the worst case brings up only 4 clay on trip 1 |
| Calculation | 66.4 car |
| | + 6.6 back: 25 cols × 16 / 200 = 2.0 walk, 4 rows × 0.75 = 3.0 climb (row 38 to the Clay landing floor 34), 1.6 ride |
| | + 7.1 trip 2: 1.6 ride down, `clay_cols = 13` tunnel columns × 0.220 = 2.86 (20 clay ÷ (2 cells × 0.8 clay share)), 13 × 0.08 = 1.04 walk back, 1.6 ride up |
| | + 3.5 stone: 10 scoops × 0.35 |
| | + 30 Front Loader driving and plot clearing + 10 build + 1 roll-out + 6 `vehicle_unlock` |
| | = **130.6 s** |
| Stone supply | the default Hillville layout has at least 10 rock tiles (the test counts them); stone from the Stone layer (row 70+) is the fallback |
| Cross-check | `--demo`: **Excavator rolls out at 29.87 s**, Garage placed at 28.90 s, pile at that point dirt 53, clay 33, stone 11 |
| Status | **Meets.** The floor is 12 min 49 s under the target |

## Target 3: the bottom in 3 to 4 hours of total play

| | |
| --- | --- |
| Target | 10 800 to 14 400 s |
| Current floor | `bottom_floor_s = 134` (about 2 min 14 s) |
| Path | watch the intro, ride down to Topsoil, dig straight down to the cavern roof |
| Calculation | 41 intro + 10 walk + 1.6 ride + `bottom_rows = 254` rows × 0.321 = 41 + 10 + 1.6 + 81.5 = **134.1 s** |
| Rows | Topsoil landing floor (row 12) to the cavern roof (row 266) |
| Why nothing stops it | every breakable block has `dig_tier` 0, so the starting shovel digs Stone, Ice and Crystal; no layer needs a vehicle, a treasure or a Workshop; nothing in the code asks for one either. A full backpack does not stop digging (blocks just puff) |
| Status | **Misses, by about 2 h 58 min at the 3 h end** (the floor is about 1/80 of the target). The game cannot take hours if the hill can be dug through in two minutes |

### Even the whole checklist is minutes, not hours

Everything the hill can ask for in blocks today: Garage 1 (30), Garages 2 to 4 (3 × 30 = 90 more), two Workshops
(30 stone), the four ruins (Old Shed 10, Crooked Watchtower 35, Flooded Cabin 30, Ruined Keep 40 =
115), the Barn, House, Lighthouse and Water Tower (10 + 20 + 25 + 25 = 80). That is 345 blocks,
about 9 full backpacks, each trip well under a minute at the rates above. So even if depth gates
make the player collect all of it first, the mechanical floor stays well under an hour.

## Depth gates and unlock zones (dig lane, hill-dig-1)

Written by the Dig progression lane (hill-dig-1, 2026-11-11, playtest items 4 and 5) from
`data/dig.tres`, `data/blocks/*.tres` and `data/gates/*.tres`; `tests/test_dig_progression.gd`
checks their shape.

Every layer but Topsoil has a band of **Gate Rock** (3 rows, the whole width, ending on the
layer's first row) over it. Signs in the band show the picture of what opens it, glowing gold once
someone has earned it. Opening is by **what you dig with**, except a treasure or a resident's help,
which opens the band for everyone, on foot too.

| Band over | Rows | Breaks it | Picture on the signs | First-session target |
| --- | --- | --- | --- | --- |
| Clay | 28-30 | the Sturdy Shovel (1 Workshop, 15 stone from surface rocks the Front Loader scoops), or any vehicle of tier 1+ | gold shovel | **minute 6** |
| Stone | 68-70 | a vehicle of tier 1+: the Excavator (Buried Car in Clay, then the Garage), later the Dump Truck, Crane, Drill Rig | the Excavator | **minute 18** |
| Ice | 128-130 | the Gnome crew's help (open the Gnome Room in Stone: the Foreman ARRIVES), or the Crane (tier 2) | a hard hat | minute 45 (end of a long first session, or the second) |
| Crystal | 188-190 | the Drill Rig (tier 3: Giant Tooth + Garage 4) | the Drill Rig | about 2 h (later sessions) |
| The Bottom | 258-260 | the Dragon Egg found (in Crystal), or the Drill Rig | the Dragon Egg | about 3 h (the 3-4 h bottom target) |

The targets are design targets for the F-4 / next playtest, not measured play. What the data does
guarantee: nobody reaches Clay before a Workshop stands, nobody reaches Stone without a vehicle,
and the elevator only goes to layers someone has reached (it never skips a band).

### Dig speed (time per tile with A held)

`hits = ceil(toughness / power)`, `time = hits x seconds between hits`. Toughness: dirt 3, sand 3,
clay 4, pebbles 4, pipe 4, stone 5, ice 5, ore 6, geode 6, crystal 6, Hard Rock 6, Gate Rock 8.

| Digger | power | s / hit | dirt | clay | stone | crystal | Gate Rock | Hard Rock |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Starting shovel | 1 | 0.30 | 0.90 s | 1.20 s | 1.50 s | 1.80 s | closed | bonk |
| Sturdy Shovel (1 Workshop) | 2 | 0.22 | 0.44 s | 0.44 s | 0.66 s | 0.66 s | 0.88 s (band 1) | bonk |
| Big Shovel (2 Workshops) | 4 | 0.16 | 0.16 s | 0.16 s | 0.32 s | 0.32 s | 0.32 s (band 1) | bonk |
| Front Loader (tier 0) | 2 | 0.26 | 0.52 s | 0.52 s | 0.78 s | 0.78 s | closed | 0.78 s |
| Excavator, Dump Truck (tier 1) | 5 | 0.20 | 0.20 s | 0.20 s | 0.20 s | 0.40 s | 0.40 s | 0.40 s |
| Crane (tier 2) | 6 | 0.18 | 0.18 s | 0.18 s | 0.18 s | 0.18 s | 0.36 s | 0.18 s |
| Drill Rig (tier 3) | 9 | 0.16 | 0.16 s | 0.16 s | 0.16 s | 0.16 s | 0.16 s | 0.16 s |

Before this pass every dig on foot took one hit every 0.14 s (vehicles 0.22 s), any block. A
straight shaft through Topsoil on foot (30 rows) was about 4 s; now it is about 27 s with the
starting shovel, 13 s with the Sturdy Shovel (which also bites one more cell, B-06), 5 s with the
Big Shovel. Vehicles dig their whole body's cross-section plus their dig shape per hit.

### Hauls

- **Hard Rock** (Clay 3%, Stone 4%, in 3x3 patches, never in a layer's first 6 rows): only a
  vehicle breaks it (the Front Loader too, so it is worth driving down the shaft from minute one);
  each tile is **4 stone** at once (a gold burst), which a 40-block backpack fills fast and a
  vehicle (x1 to x5 carry) holds.
- **Gate Rock** keeps as 1 stone a tile.

## Decision for Gary (not changed here)

The bottom target is missed for a reason data cannot fix on its own:

1. **Depth gates are code**, playtest item 4 ("you can't dig straight to the bottom from the
   start"), being built now by `hill-dig-1`. Until they land, nothing makes the bottom slow.
2. **The one data-only gate, `BlockData.dig_tier`, needs a design call.** Setting `stone.dig_tier = 1`
   would make Stone Excavator-only, but the Garage that gives the Excavator costs 10 stone; it only
   works because surface rocks also give stone, and the Stone layer would then be unreachable
   below row 70 until the Excavator. Setting `ice = 2` (Crane) and `crystal = 3` (Drill Rig) is
   possible, but the Lighthouse (5 crystal, needs the Crane) would then need the Drill Rig, and
   `hill-dig-1` may gate layers its own way. Not done, so the two lanes don't fight.
3. **3 to 4 hours is a human-pace number.** Even with gates, the costs in `data/buildings/` add up
   to about 9 backpacks. Hours come from what a 5-year-old does between digs (exploring, residents,
   building, cutscenes, the Mole), not from dig rates; making digging slow enough to fill hours
   would break "big satisfying chunks". Suggest: keep 3 to 4 h as the playtest goal, and give this
   sheet a gated floor instead (for example "the bottom needs the Drill Rig, which needs Garages
   1 to 4 and the Giant Tooth"), then time real play at F-4.

When the gates land, re-run `tests/test_balance.gd`: its known-miss check fails as soon as any
breakable block needs a vehicle, which is the cue to redo Target 3 here.

## What changed in data

Nothing. Targets 1 and 2 are met with room to spare; Target 3 needs code and a design call.
