# hill-c22-underground-1: Underground engineering (C-22)

Branch `feature/hill-c22-underground-1`, from `dev` at 17ac5dd (already up to date on start). Not pushed.

## What changed

- **Merged `origin/feature/hill-puzzles-audit-1`** (the unmerged C-22 puzzles: boulder wall, Front Loader
  block, `Puzzles`, `PuzzleData`, `data/puzzles/`, `tests/test_puzzles.gd`, beats `wall|loader_block`) onto
  dev after the dig progression (PR 48). Conflicts in GAME.md, PLAN-STATUS.md, clay.tres, hill_game.gd and
  underground.gd were resolved by keeping both sides. `feature/hill-puzzles-1` and `-fix-1` can be closed unmerged.
- **The boulder rule is data in `data/blocks`:** new `BlockData.boulder_breaks`, `boulder_min_px` (20),
  `boulder_min_speed` (90 px/s), `boulder_reach` (1). Only `hardrock.tres` has it on. Any falling body that is
  big and fast enough and lands on such a block cracks it away: the cells under it plus `reach` more along the
  row, and the body keeps falling. A pebble only clinks. The wall's slab is now the puzzle row's `block`
  (Hard Rock) instead of edgestone, and it breaks whole. On foot the wall needs the boulder. With a vehicle
  you can also dig it, so it can be routed around.
- **A break always shows its cause** (`Puzzles.break_cells`): crack flashes on every cell, dust, the
  `wall_crash` cue (falls back to `cave_in`), a camera kick and pad rumble within 20 tiles, and a "rock + star"
  picture bubble. Anyone for whom the break is off screen gets a **camera peek**: new
  `CameraLead.peek(p, offset, secs)` slides their view to the break and back in 1.6 s. Nobody is moved.
- **The wall reads before it falls:** a cracked-brick slab, plus a "rock + wall" picture bubble while a player
  is within 10 tiles.
- **Walk-up vehicle picture:** walking up to Hard Rock on foot, or to a block too hard for your vehicle, pops
  the picture of the vehicle that breaks it over your head, once per visit, before any dig
  (`DigFeel.walk_up_need`). Gate Rock is skipped because its bands already have signs.
- **New beat `--demo-beat=hard_rock`** (real dig rules, through `PuzzleBeats.REAL_RULES`, read in
  `HillGame._ready`). It shows the walk-up picture, a bonk, then a boulder breaking a Hard Rock floor patch.
- **The boulder wall moved off the Clay landing** (`near_landing` 0; it is now about 35 tiles left of the
  shaft). Beside the landing it pushed the Controls lane's back-up bot test over 20 s. That bot tunnels in a
  straight line and is already known to stall at the Clay landing. I tested two in-test workarounds first and
  reverted both, so `test_controls.gd` is unchanged.
- Docs: GAME.md decisions (2026-11-11, hill-c22-underground-1), `docs/contracts.md` (BlockData fields,
  `CameraLead.peek`), `data/README.md`.

## PLAN-STATUS IDs moved

- **C-22** partial → **built** (row rewritten with tests and frames).
- F-3 note: dropped "underground puzzles on an unmerged branch". In Next up, item 2 (merge the puzzles) is
  struck through.

## Tests

- New `tests/test_underground_engineering.gd` (5 cases):
  - the rule follows the data: Stone does not break, Hard Rock does, and turning `boulder_breaks` on for
    Stone at runtime makes it break
  - a pebble clinks
  - a far break gives a camera peek and a near one does not
  - the walk-up picture shows
  - a **seeded route test over the real data** (5 seeds): from each layer's landing, a flood through
    on-foot-diggable cells (or cells the vehicle tier already required can dig) reaches the row above every
    Gate Rock band. It must also fail to get past the band itself on foot.
- `tests/test_puzzles.gd` updated for the Hard Rock slab and the data rule.
- Full run after a clean import: **468 test cases, 0 errors, 0 failures** (`--ignoreHeadlessMode --continue`).
- Commits: the audit-branch merge and this lane's work landed in one merge commit (the conflicts and my edits touched the same files); REPORT.md is a second commit.

## Frames (handoff/frames/, real renders from scripts/tools/shots.sh, each one looked at)

- `c22_wall_before.png`: `--demo-beat=wall` t=2.3. Cracked slab, boulder on the dirt pillar, and the "rock +
  wall" bubble over the room.
- `c22_wall_break.png`: wall t=2.85. The slab is gone: crack flashes, dust, the "rock + star" bubble, and the
  boulder dropping into the stone-floored chamber. A HillBarks "rock + smile" bark overlaps it a little.
- `c22_hardrock_walkup.png`: `--demo-beat=hard_rock` t=4.3. Jeff on foot faces a Hard Rock wall; the Front
  Loader picture is over his head and in the A hint.
- `c22_hardrock_boulder_break.png`: hard_rock t=7.65. A boulder has cracked the Hard Rock floor patch away
  (crack flashes, dust, "rock + star" bubble) and fallen into the Buried Car's cave below.

## Notes for other lanes

- Audio: the cues `wall_crash`, `heavy_thunk` and `heavy_clear` don't exist yet; fallbacks play for now.
- Audio (bark owner): in `--demo-beat=wall` the engine logs `ERROR: ... 'filter': Cannot convert argument 1
  from Object to Object` from the typed lambdas `func(b: BarkBubble)` in `scripts/audio/hill_barks.gd:74/106`
  when a freed bubble is filtered. It's off-limits for this lane and gdUnit doesn't catch it. Fix: make the
  lambda parameter untyped.
- Controls: `Puzzles.vehicle_hint()` is ready if you want the hint panel to show the Front Loader. The
  back-up bot (`test_from_deep_spots...`) is still fragile near the Clay landing.
- Camera: `CameraLead.peek` was added (small, additive). The shared one-screen camera does not peek.
