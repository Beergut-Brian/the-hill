# Report: hill-balance-recheck-2 (C-27 balance re-check)

Branch `feature/hill-balance-recheck-2`, based on `origin/dev` at `39a2212` (nothing merged in). Not pushed.

## Starting point

The brief said `data/BALANCE.md` still had the old miss (about 2 h 58 min, no depth gates). That was out
of date: re-check 1 (`hill-balance-recheck-1`) re-derived the sheet on `feature/hill-dig-1`, and that
sheet came to dev with PR 48. On dev at `39a2212`, `tests/test_balance.gd` was green (7/7), and every
`name = value` line already matched the data, including the Gate Rock bands.

What dev gained after that re-check: PR 49 (C-22 underground engineering: a boulder wall with a Hard
Rock slab and unbreakable side columns, plus a 2×2 block only the Front Loader can clear, both in Clay;
`boulder_breaks` on Hard Rock), and PRs 50 to 53 (audio, barks, gap-close-4, roster). None of them
touches dig hit points, gates, vehicles, building costs or treasures, so **no floor moved**.

## What the sheet now says

| Target | Floor | Status |
| --- | --- | --- |
| Buried Car about 5 min | `car_floor_s = 128` (Workshop first, Sturdy Shovel through the Clay band) | meets, 2 min 52 s early |
| Excavator by 15 min | `excavator_floor_s = 196` | meets, 11 min 44 s early |
| Bottom 3 to 4 h | `bottom_floor_s = 399` (Workshop, car, 4 Garages, Giant Tooth, Drill Rig) | **misses by 2 h 53 min** (10 800 − 399 = 10 401 s; about 1/27 of the target) |

Depth gates (the band table, computed): Clay band at row 28 (`gate_clay_foot_s = 70` on foot), Stone
band at row 68 (`gate_stone_foot_s = 134`, Workshop first), Ice at 128, Crystal at 188, Bottom at 258.
You can't reach Ice or anything deeper on foot (`-1`). Each vehicle-only band opens for a vehicle the
player can already have when they get there: the Excavator, built from the Buried Car above the Stone
band; the Crane or the Gnome crew for Ice; the Drill Rig for Crystal and the Bottom, which needs the
Giant Tooth, in Stone above the Crystal band. No band is out of reach.

**New in this pass (computed by the test):** the C-22 puzzles are now checked against the floors'
straight-line routes over seeds 0 to 199. A puzzle sits in the car tunnel on `puzzle_car_seeds = 6`
seeds and in the Clay shaft on `puzzle_shaft_seeds = 13` seeds. The game's own seed is clear
(`Underground.DEFAULT_SEED`, which every new game uses): `puzzle_default_seed_clear = true`. So the
floors hold for the hill people actually play. On other seeds the floors leave out a short detour.

## The gap (Gary's pick needed; no data changed)

Unchanged from re-check 1, and still in BALANCE.md under "Gary's pick needed". Closing the bottom gap
with dig rates alone would take every tile about 27 times as long. The one change I'd make is
`data/gates/5_bottom.tres` `vehicle_tier = 3` → `0`: then only the Dragon Egg opens the Bottom. That
makes the end a story beat. It adds `egg_detour_s = 16` (bottom floor about 415 s). The car and
Excavator floors stay the same, and it does not close the time gap. The hours have to come from play
and need a timed playtest. Nothing contradicts GAME.md's own text, so no data was changed as a bug.

## Files

- `tests/test_balance.gd`: `floors()` also plans `PUZZLE_SEEDS = 200` seeds and counts C-22 puzzle
  cells (wall slab, wall sides, vehicle block) in the car tunnel and the Clay shaft, plus the default
  seed. Then it re-plans the default seed. These are four new `name = value` lines, all recomputed
  from data, with no hard-coded copy.
- `data/BALANCE.md`: provenance line for re-check 2, the new "C-22 puzzles on the routes" section,
  and "What changed in data" updated.
- `PLAN-STATUS.md`: rows updated, Next-up item 3 struck (gates are on dev; only the pick is left).

## Moved PLAN-STATUS IDs

None changed status. Notes updated: **C-27** (stays partial: Gary's pick on the bottom target, then
a timed playtest), **PT10-4** (stays built), **PT10-5** (stays built).

## Tests

`tests/test_balance.gd`: 7/7 pass. It has the same 7 test cases as before; four more sheet lines
are checked in `test_the_sheet_prints_what_the_data_gives`.

**On `origin/dev` at `39a2212` the full command fails before any test runs, and the cause is not this
branch.** After a clean import,
`godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests --ignoreHeadlessMode --continue`
stops at test discovery with "Abnormal exit with 105". The parse error is in
`tests/test_hill_barks_freed.gd` (audio, PR 50, `e08213d`). It uses `BarkBubble`, a class that
`cf0c2a8` (gap-close-4, PR 51, barks moved onto PictoBubble) deleted. `-i` doesn't skip it, because
discovery still parses the file. So I passed the other 53 suites by name (`-a res://tests/<file>`
for each). Result: **53/53 suites, 477/477 test cases, 0 errors, 0 failures, 0 orphans.** That file
belongs to the audio and barks lanes and I left it alone. **Needs the audio lane:** port
`test_hill_barks_freed.gd` to whatever replaced `BarkBubble`, or delete it if PR 52's lambda fix
already covers it.
