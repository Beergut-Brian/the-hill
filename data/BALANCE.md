# The Hill: balance sheet

Content lane's pacing floors live on `feature/hill-balance-1` (C-27, not on `dev` yet); when it
merges, keep both sections. This section is the Dig progression lane's (hill-dig-1, 2026-11-11,
playtest items 4 and 5). Numbers come from `data/dig.tres`, `data/blocks/*.tres` and
`data/gates/*.tres`; `tests/test_dig_progression.gd` checks the shape of them (slow start, each
upgrade at least halves the time per tile, bands toughest, Hard Rock a haul).

## Depth gates (unlock zones)

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

## Dig speed (time per tile with A held)

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

## Hauls

- **Hard Rock** (Clay 3%, Stone 4%, in 3x3 patches, never in a layer's first 6 rows): only a
  vehicle breaks it (the Front Loader too, so it is worth driving down the shaft from minute one);
  each tile is **4 stone** at once (a gold burst), which a 40-block backpack fills fast and a
  vehicle (x1 to x5 carry) holds.
- **Gate Rock** keeps as 1 stone a tile.
