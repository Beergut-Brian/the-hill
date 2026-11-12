# The Hill: balance sheet (C-27)

Pacing targets from the plan (`GAME.md`, Content lane deliverables): **the Buried Car in about
5 minutes, the Excavator by minute 15, the bottom of the hill in 3 to 4 hours of total play.**

First written 2026-11-11 by the Balance lane from `dev` at `52d17db`; re-derived the same day by
the Balance re-check lane (`hill-balance-recheck-1`) on `feature/hill-dig-1` after merging
`origin/dev` at `e773164`, so the floors now include the dig lane's hit points (`data/dig.tres`),
Gate Rock bands (`data/gates/`) and Hard Rock. Checked again by `hill-balance-recheck-2` on
`origin/dev` at `39a2212` (after PR 49, the C-22 boulder walls and vehicle blocks in Clay, and PRs
50 to 53): every floor below is unchanged, and the C-22 puzzles are now counted against the routes
("C-22 puzzles on the routes" below). On 2026-11-12 the Bottom-layer balance lane
(`hill-balance-bottom-1`, from `origin/dev` at `b04811e`) made the one data change that carries the
bottom floor into its 3 to 4 h target: **Crystal's hit points, `data/blocks/crystal.tres`
`toughness` 6 → 9000** ("The bottom: decided" below). `tests/test_balance.gd` recomputes every number in
a `name = value` line below from the data rows and code constants, so a data change that moves one
fails CI until this sheet is updated.

## What these numbers are

Each figure is a **floor**: the fastest one player who knows the way can do it, with no wandering,
no hazards and no help from Player 2. Real play with a 5-year-old will be slower by a factor nobody
has measured yet; only a timed playtest can measure it. So a floor **under** a target means "the
target is reachable"; a floor far under a target means the numbers alone do not make the game take
that long.

How a tile is timed: A held, every hit (the first included) costs one hit interval before the next
can land (`hill_player.gd` `_dig_cd`), so **a tile = `hits × s/hit`**, `hits = ceil(toughness /
power)` (`DigTuning.hits_for`). A straight shaft meets, per row, Gate Rock inside a band and the
layer's main block (largest `block_mix` share) elsewhere. Then one cell of fall or walk. Landing
rooms on the way are counted as rock (a few rows' worth too slow) and vehicles are timed one row
per hit (a Drill Rig bite is taller), so the deep floors are a little high, never low.

## The building blocks

| Quantity | Value | Arithmetic | Source |
| --- | --- | --- | --- |
| Cell | 16 px | | `addons/openjar/tileworld/world_shape.gd` `cell_size` |
| Underground gravity | 980 px/s² | one-cell fall √(2 × 16 / 980) = 0.181 s | `world_shape.gd` `gravity` |
| Walk speed | 200 px/s | 0.08 s a cell | `hill_player.gd` `WALK` |
| Shovel hits | power 1 / 2 / 4, every 0.30 / 0.22 / 0.16 s (0, 1, 2 Workshops) | | `data/dig.tres` `shovel_power`, `shovel_every` |
| Vehicle hits | power 2 / 5 / 6 / 9, every 0.26 / 0.20 / 0.18 / 0.16 s (dig_tier 0 to 3) | | `data/dig.tres` `vehicle_power`, `vehicle_every` |
| Toughness | dirt 3, clay 4, stone 5, crystal 9000 (was 6; C-27, bottom-1), Gate Rock 8 (Hard Rock 6, vehicles only) | | `data/blocks/*.tres` `toughness` |
| Vehicle speed | Excavator 100, Drill Rig 60 px/s, × 1.15 with a Workshop | | `data/vehicles/*.tres`; `hill_player.gd` `TOOL_DRIVE` |
| Front Loader scoop up top | 0.35 s a tile | | `hill_player.gd` `SCOOP_EVERY` |
| One row down, starting shovel, dirt | `row_down_ms = 1081` | 3 hits × 0.30 + 0.181 | was 321 before the dig lane |
| One row down, Sturdy Shovel, dirt | `row_down_sturdy_ms = 621` | 2 hits × 0.22 + 0.181 | |
| One column sideways, Sturdy Shovel, clay | `col_side_ms = 520` | 2 hits × 0.22 + 0.08 | was 220 |
| Elevator ride | 1.6 s | 1.0 door wait + 0.6 ride | `scenes/game/elevator.gd` `DOOR_WAIT`, `RIDE_TIME` |
| Backpack | `backpack = 40` | 2 sizes × 20 (no Barn); × `carry` in a vehicle (Excavator 80) | `Progress.gd`; `hill_player.gd` |
| Landing floors | Topsoil row 12, Clay row 34, Stone row 74 | layer `depth_from` + 1 + 3 | `hill_generator.gd` `_plan`, `ROOM_H` |
| Buried Car | rows 36–37, its right edge 10 to 25 columns left of the shaft | Clay landing floor + 2; `CAR_REACH` | `hill_generator.gd`; `data/treasures/buried_car.tres` |
| Giant Tooth (default seed) | top row `tooth_row = 102`, `tooth_cols = 36` columns from the shaft | | `hill_generator.gd` `_plan`; `data/treasures/giant_tooth.tres` (Stone) |
| Cavern roof | row 266 | | `hill_generator.gd` `CAVERN` |
| Workshop cost | 15 stone | | `data/buildings/workshop.tres` |
| Garage cost | 20 clay, 10 stone, each of the four | Garage n rolls out vehicle `order` n | `data/buildings/garage.tres`; `data/vehicles/*.tres` |
| Drill Rig | Garage 4 and the Giant Tooth found | | `data/vehicles/drill_rig.tres` (`order` 4, `needs_treasure` giant_tooth) |

### Assumptions (in no file; kept generous)

| Allowance | Value | Why |
| --- | --- | --- |
| Intro cutscene, watched | 41 s | `docs/cutscenes.md` ("about 41 s"); A skips it |
| Spawn to the cage, once | 10 s | the bot does it in 3.3 s (demo log) |
| Front Loader: drive to rocks (and clear a plot) | 30 s, once for the Workshop, once for the Garage | the bot's P2 gets 11 stone and a cleared yard in about 6 s |
| Open the book and place a building | 10 s | the bot takes 1.7 s |
| Garage roll-out | 1 s | demo log 0.97 s |
| `vehicle_unlock` cutscene | 6 s | `docs/cutscenes.md` |
| Climb one row (dig a step, hop) | 0.75 s | |

The Mole's first theft needs 75 s underground and 12 tiles dug in Topsoil or Clay
(`data/story/mole_arc.json`); the car and Excavator floors spend under 75 s underground, so no theft
lands inside them. Hard Rock patches (vehicle-only, never in a layer's first 6 rows) can sit in
the car tunnel on an unlucky seed; the floor assumes the straight line is clear.

## Target 1: the Buried Car in about 5 minutes

| | |
| --- | --- |
| Target | about 300 s |
| Current floor | `car_floor_s = 128` (about 2 min 8 s; was 66 before the gates) |
| Path | watch the intro, walk; **build the Workshop first** (the Clay band breaks only for the Sturdy Shovel or a tier-1 vehicle, and the tier-1 vehicle needs this car); ride down to Topsoil, dig straight down through the Clay band to the car's rows, tunnel left to it |
| Workshop | `workshop_s = 45`: 30 Front Loader driving + 15 stone × 0.35 scoop + 10 build = 45.25 s |
| Shaft | `car_rows = 26` rows (row 12 to row 37) in `car_dig_s = 17`: 16 Topsoil rows × 0.621 + 3 Gate Rock rows × (4 hits × 0.22 + 0.181) + 7 clay rows × 0.621 = 9.93 + 3.18 + 4.35 |
| Calculation | 41 intro + 10 walk + 45.25 Workshop + 1.6 ride + 17.47 shaft + `car_cols = 25` × 0.520 = 41 + 10 + 45.25 + 1.6 + 17.47 + 13.0 = **128.3 s** |
| Columns | the worst seed, `CAR_REACH.y` = 25 |
| Status | **Meets.** 2 min 52 s under the target |

## Target 2: the Excavator by minute 15

| | |
| --- | --- |
| Target | at most 900 s |
| Current floor | `excavator_floor_s = 196` (about 3 min 16 s; was 131) |
| Path | the car (above); walk back and ride up; a second trip for the Garage's clay; Front Loader scoops 10 stone from surface rocks; build the Garage; it rolls out the Excavator |
| Why two trips | on the way down the bag fills with dirt first, so the worst case brings up only 4 clay on trip 1 |
| Calculation | 128.3 car |
| | + 6.6 back: 25 cols × 0.08 walk, 4 rows × 0.75 climb (row 38 to the Clay landing floor 34), 1.6 ride |
| | + 11.0 trip 2: 1.6 ride down, `clay_cols = 13` columns × 0.520 = 6.76 (20 clay ÷ (2 cells × 0.8 clay share)), 13 × 0.08 walk back, 1.6 ride up |
| | + 3.5 stone: 10 scoops × 0.35 |
| | + 30 Front Loader driving and plot clearing + 10 build + 1 roll-out + 6 `vehicle_unlock` |
| | = **196.4 s** |
| Stone supply | before the Excavator no stone layer is open (the Stone band), so the Workshop's 15 and the Garage's 10 come from surface rocks; the test checks the default Hillville layout holds at least 25 |
| Status | **Meets.** 11 min 44 s under the target |

## Target 3: the bottom in 3 to 4 hours of total play

| | |
| --- | --- |
| Target | 10 800 to 14 400 s |
| Current floor | `bottom_floor_s = 11108` (about 3 h 5 min; 399 before the Crystal hit points, 134 with no gates) |
| Why this route | the Crystal and Bottom bands break only for dig_tier 3, the Drill Rig (the Dragon Egg that also opens the Bottom lies in Crystal, behind the Crystal band). The Drill Rig needs the Giant Tooth (Stone) and Garage 4. The Ice band needs the Crane (tier 2) or the Gnome crew; the Drill Rig breaks it too, so the floor skips the Gnome Room |
| Calculation | 196.4 Excavator |
| | + `tooth_s = 68`: 1.6 ride to Clay; the Excavator digs rows 34 to 103 (34 clay × (0.20 + 0.181), 3 Gate Rock × (2 × 0.20 + 0.181), 33 stone × 0.381 = 27.25), then 36 columns × (0.20 + 16 / 115) = 12.21; the player walks back 36 × 0.08, climbs 30 rows to the Stone landing (row 74) × 0.75, rides up 1.6 |
| | + `haul_s = 17`: Garages 2 to 4 cost `haul_blocks = 90` blocks, `haul_trips = 2` Excavator loads (80 a bag): 2 × 2 rides + 90 ÷ 3 cells a bite × 0.339 |
| | + 51: three Garages × (10 build + 1 roll-out + 6 `vehicle_unlock`): Dump Truck, Crane, Drill Rig |
| | + `drill_s = 10776`: 1.6 ride to Stone; the Drill Rig drills `drill_rows = 192` rows (74 to 266): the 125 Stone, Ice, band and Bottom rows one hit each × (0.16 + 0.181) = 42.6, the 67 Crystal rows (191 to 257) 1000 hits each, `rig_crystal_row_s = 160` (1000 × 0.16 + 0.181) = 10 732 |
| | = **11 108 s** (was 399.0 before Crystal's hit points) |
| Status | **Meets: 3 h 5 min**, 5 min inside the 3 h end and 55 min under the 4 h end. Crystal is the Drill Rig's long, steady bore (about 2 min 40 s a row on auto-drill); everything above the Crystal band is as before |

### Even the whole checklist is minutes, not hours (true before bottom-1; still true above Crystal)

Everything the hill can ask for in blocks today: Garage 1 (30), Garages 2 to 4 (3 × 30 = 90 more), two Workshops
(30 stone), the four ruins (Old Shed 10, Crooked Watchtower 35, Flooded Cabin 30, Ruined Keep 40 =
115), the Barn, House, Lighthouse and Water Tower (10 + 20 + 25 + 25 = 80). That is 345 blocks,
about 9 full backpacks, about 5 Excavator loads. Even if a gate asked for all of it first, the
mechanical floor stays well under an hour.

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

### Where each band opens, and how you get there (re-check lane, computed)

From the generator's bands (`HillGenerator.gate_bands`, the default seed) and the floors above.
"On foot" = the fastest arrival at the band's top row from the start (intro included), digging
straight down from the Topsoil landing; deeper bands can't be reached on foot (`-1`): the Stone
band stops everyone on foot.

| Band over | Starts at | Fastest arrival on foot | Opens for | Can the player already have it there? |
| --- | --- | --- | --- | --- |
| Clay | `gate_clay_row = 28` | `gate_clay_foot_s = 70` (starting shovel, 16 rows × 1.081) | the Sturdy Shovel, at the Workshop (96 s into the floor) | yes: the Workshop needs only surface stone |
| Stone | `gate_stone_row = 68` | `gate_stone_foot_s = 134` (Workshop first, Sturdy Shovel) | a vehicle of tier 1+: the Excavator | yes: the Excavator rolls out at `excavator_floor_s` (196 s), its car is in Clay above the band |
| Ice | `gate_ice_row = 128` | `gate_ice_foot_s = -1` | the Gnome crew (Gnome Room in Stone; the Foreman ARRIVES on finding it, then on foot too), or the Crane | yes: the Gnome Room and Garage 3 (Crane, no treasure) are both above the band |
| Crystal | `gate_crystal_row = 188` | `gate_crystal_foot_s = -1` | the Drill Rig only | yes: the Giant Tooth is in Stone and Garage 4 needs only clay and stone |
| The Bottom | `gate_bottom_row = 258` | `gate_bottom_foot_s = -1` | the Dragon Egg (Crystal) or the Drill Rig | yes: the Drill Rig, already needed for Crystal |

No vehicle-only band is unreachable: `test_every_band_opens_with_something_reachable` checks that
each band opens for a shovel level, a resident, or a vehicle whose treasure lies above it.

### C-22 puzzles on the routes (re-check 2, computed)

PR 49 put one boulder wall (an 8-cell Hard Rock slab between two unbreakable side columns) and one
2×2 Front-Loader-only block into Clay (`data/puzzles/`, `HillGenerator._plan_puzzles`). Neither
can be dug on foot, so either one in the floors' straight lines would cost a detour the floors
leave out. The test plans seeds 0 to 199 (`puzzle_seeds = 200`) and counts the seeds where a slab,
a side or the block sits in the car tunnel (between the car's right edge and the shaft, the car's
rows) or in the Clay stretch of the shaft (Clay landing floor to Stone landing floor, the
Excavator's way to the tooth):

| Route | Seeds with a puzzle in it |
| --- | --- |
| Car tunnel (on foot, Sturdy Shovel) | `puzzle_car_seeds = 6` of 200 (3%) |
| Clay shaft (the Excavator to the Giant Tooth) | `puzzle_shaft_seeds = 13` of 200 (6.5%) |
| The game's seed (`Underground.DEFAULT_SEED`, which every new game uses) | `puzzle_default_seed_clear = true`: both lines clear |

So the floors hold for the hill the game actually builds. On another seed the car tunnel can need
a dig round the 2×2 block (a few extra tiles, seconds at the Sturdy Shovel) or a way round a wall; the
Excavator breaks the Hard Rock slab but not the side columns. None of this moves a floor past a
target.


### Dig speed (time per tile with A held)

`hits = ceil(toughness / power)`, `time = hits x seconds between hits`. Toughness: dirt 3, sand 3,
clay 4, pebbles 4, pipe 4, stone 5, ice 5, ore 6, geode 6, Hard Rock 6, Gate Rock 8, crystal 9000
(C-27 bottom-1: the only block tougher than Gate Rock, and only past the Drill Rig's band).

| Digger | power | s / hit | dirt | clay | stone | crystal | Gate Rock | Hard Rock |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Starting shovel | 1 | 0.30 | 0.90 s | 1.20 s | 1.50 s | 45 min | closed | bonk |
| Sturdy Shovel (1 Workshop) | 2 | 0.22 | 0.44 s | 0.44 s | 0.66 s | 16.5 min | 0.88 s (band 1) | bonk |
| Big Shovel (2 Workshops) | 4 | 0.16 | 0.16 s | 0.16 s | 0.32 s | 6 min | 0.32 s (band 1) | bonk |
| Front Loader (tier 0) | 2 | 0.26 | 0.52 s | 0.52 s | 0.78 s | 19.5 min | closed | 0.78 s |
| Excavator, Dump Truck (tier 1) | 5 | 0.20 | 0.20 s | 0.20 s | 0.20 s | 6 min | 0.40 s | 0.40 s |
| Crane (tier 2) | 6 | 0.18 | 0.18 s | 0.18 s | 0.18 s | 4.5 min | 0.36 s | 0.18 s |
| Drill Rig (tier 3) | 9 | 0.16 | 0.16 s | 0.16 s | 0.16 s | 160 s | 0.16 s | 0.16 s |

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

## The bottom: decided (bottom-1, 2026-11-12, the producer's call)

**The gap it closed:** with every block 1 hit for the Drill Rig the bottom floor was 399 s against
10 800 s, short by 2 h 53 min (re-check 2). Gary chose to close it in data.

**The lever:** Crystal's hit points, `data/blocks/crystal.tres` `toughness` 6 → 9000. One value,
one block, below Clay only. Why this one and not the others:

- **Gate Rock must stay 7 or 8** (the Sturdy Shovel's 4 hits in the Clay band are in the car floor),
  and Hard Rock, stone, ice and the Drill Rig's power are capped by it: a band is the toughest thing
  above it, and the tiers must keep rising (`test_dig_progression`). So only a block below the
  bands that matter can carry hours.
- **Not Stone or Ice:** Stone is the first long session (the Excavator held down, minute 18 to 45),
  and the Gnome crew opens Ice for walkers and the Crane; hours there would turn those promises into
  a wall. Crystal is past the Crystal band, which only the Drill Rig breaks.
- **The Drill Rig drills Crystal on its own** (A starts its auto-drill, A stops it), so the slow
  part is not a held button. Every hit still cracks the tile, flashes, throws crumbs and plays its
  sound; nothing is hidden and nothing moves anyone.
- **Not the Drill Rig's rate:** its auto-drill pace is a code constant, and a slower Rig would make
  the Crane the faster way through Stone and Ice, so the floor would stop being a floor.

**What it costs in play (for the playtest to judge):** a Crystal tile is 160 s for the Drill Rig,
6 min for the Big Shovel or the Excavator, 4.5 min for the Crane. The 40% stone in Crystal (and the
Bottom's mix) still digs as before, so walkers in Crystal can tunnel the stone veins. The Dragon Egg
in Crystal: the egg-only Bottom gate (the old suggestion: `data/gates/5_bottom.tres` `vehicle_tier
= 3` → `0`) would now cost `egg_cols = 25` columns of Crystal there and back, `egg_detour_s = 4012`
(about 1 h 7 min) and push the floor to about 4 h 12 min, past the 4 h end, so it is **not** taken.
The Bottom layer's own rows (stone and crystal half and half) are timed as stone, so the floor
there is a few minutes low, never high.

**Undo:** set `toughness` back to 6 and flip `test_bottom_lands_in_three_to_four_hours` back to a
known miss; nothing else depends on it.

## What changed in data

bottom-1 (2026-11-12): `data/blocks/crystal.tres` `toughness` 6 → 9000, the only change; it moves
`drill_s`, `bottom_floor_s` and `egg_detour_s` and nothing else (car, Excavator, every band row,
the puzzle counts unchanged). GAME.md's 2026-11-11 dig entry lists "crystal 6": superseded by the
2026-11-12 decision line. Before that: nothing (re-check 2 too: C-22's rows contradict no GAME.md text and move no floor). No number contradicts GAME.md's own text (toughness, dig powers and intervals, band
openers and target minutes all match "Playtest 2026-11-10 changes"), so there was no bug to fix.
