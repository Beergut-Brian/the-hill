# tileworld: TileWorld

A chunked, diggable 2D tile world. Game-agnostic: no autoloads, nothing outside this folder.
Godot 4.7. The Hill uses a rectangle (`RectShape`), Life of a Worm a disk (`DiskShape`). The API
is in `docs/contracts.md` ("Module: TileWorld"); this file is the tour.

## Files

* `tile_world.gd`: `TileWorld`, the node. Chunks, tiles, digging, water, darkness, save.
* `world_shape.gd`, `rect_shape.gd`, `disk_shape.gd`: the shape interface, a rectangle, a disk.
* `world_generator.gd`, `layered_generator.gd`: the seeded base world; a ready generator for any shape.
* `edit_store.gd`: `EditStore`, the differences from the base world, and the save format.
* `tile_def.gd`: `TileDef`, one palette entry.
* `falling_body.gd`: `FallingBody`, a boulder / treasure / prop piece (RigidBody2D).
* `breakable_prop.gd`: `BreakableProp`, a multi-tile prop that breaks when undercut.
* `body_index.gd`, `water_sim.gd`, `darkness_overlay.gd`: internals of `TileWorld`.
* `demo/`: `shape_demo` (visual proof) and `stress` (performance run).

## Quick start

```gdscript
var shape := RectShape.new(200, 300)                 # or DiskShape.new(150)
var gen := LayeredGenerator.new()
gen.surface_depth = 8
gen.border_tile = 4                                  # unbreakable rim
gen.bands = [{"from": 8, "tile": 1}, {"from": 11, "tile": 2}, {"from": 60, "tile": 3}]
var palette: Array[TileDef] = []                     # index = tile id, 0 = air
for row in [[&"air", false], [&"grass", true], [&"dirt", true], [&"stone", true], [&"bedrock", false]]:
	var d := TileDef.new(); d.id = row[0]; d.solid = row[0] != &"air"; d.breakable = row[1]
	palette.append(d)
var world := TileWorld.new()
world.setup(shape, gen, palette, 1234)               # before add_child is fine
add_child(world)
world.track(player)                                  # chunks load around tracked nodes
world.dig(shape.cell_at(player.position), [Vector2i(0, 1)], 0)   # offsets from the cell; player index
var rock := FallingBody.new()
rock.position = shape.center_of(Vector2i(50, 20))
world.add_child(rock)                                # registers itself with the world
var data := world.to_save()                          # JSON-safe Dictionary
world.load_save(JSON.parse_string(JSON.stringify(data)))
```

Cells are `Vector2i` on one Cartesian grid (`cell_size` px squares, y down) for every shape. Tile id
`0` is air. Positions given to the world are local to the node (move it, do not rotate it).

## Shapes

The chunk manager only ever asks a `WorldShape` three things:

* `chunk_of(cell) -> Vector2i`: the key of the chunk a cell is in.
* `chunk_cells(key) -> Array[Vector2i]`: every cell of that chunk (only cells inside the shape).
* `neighbourhood(key, radius) -> Array[Vector2i]`: the keys to keep alive around a node in chunk
  `key`, including `key`, without duplicates.

Bodies and water ask:

* `gravity_at(pos) -> Vector2`: acceleration in px/s^2 at a world position.
* `below(cell) -> Vector2i`: the cell that supports this one (one step along gravity).
* `sides(cell) -> Array[Vector2i]`: the two cells level with it; water spreads there.

Generators and darkness ask `depth_of(cell)`: tiles below the surface.

| Shape | Constructor | Chunk key | Gravity |
| --- | --- | --- | --- |
| `RectShape` | `new(width, height, chunk_size = 32)` | `(cx, cy)`: square chunks, `(0, 0)` top-left | straight down |
| `DiskShape` | `new(radius, band = 32)` | `(ring, sector)`: a ring `band` tiles thick cut into sectors about `band` tiles of arc long, so outer rings have more sectors | toward the origin |

On a rectangle `depth_of` is the row (`cell.y`); on a disk it is the distance in tiles from the
rim. A disk's `below` / `sides` step along whichever axis points most at the centre.

Writing a new shape:

1. Extend `WorldShape`; set `cell_size` (and `gravity`) in `_init`; `contains` is true exactly for
   the cells that exist.
2. `chunk_of` and `chunk_cells` agree: every cell is in exactly one chunk, `chunk_of(c) == key` for
   every `c` in `chunk_cells(key)`, and only inside cells are returned.
3. `neighbourhood(key, radius)` includes `key`, has no duplicates, covers every adjacent chunk at
   radius 1.
4. `below(c)` is one cell step along gravity; `sides(c)` are the two level cells, one each way.
5. `depth_of` is 0 at the surface, grows downward, never negative.
6. Add checks to `tests/test_tileworld.gd` next to the Rect and Disk ones.

## Generators

`WorldGenerator.setup(shape, seed)` is called by `TileWorld.setup`. Override
`base_tile(cell) -> int` (0 is air) and `base_water(cell) -> bool` (this air cell starts full of
water). Both must be deterministic for a (shape, seed) and independent of call order, because
chunks load in any order and the base world is never stored. A chunk load asks for all its cells at
once through `base_chunk(cells) -> PackedInt32Array` (`base_tile | WorldGenerator.WATER_BIT` when
`base_water`); the default loops the two calls, override it when a chunk load is slow.

`LayeredGenerator` works with any shape (it only uses `depth_of`):

* `bands`: `[{"from": depth, "tile": id}, ...]`; the last band whose `from <= depth` wins.
* `surface_depth`: cells shallower than this are air.
* `border_tile`: when > 0, cells next to the outside of the shape get this tile (make it
  unbreakable).
* `cave_threshold` (0.55; above 1 means no caves), `cave_frequency`, `cave_min_depth`: noise caves.
* `water_from_depth` (-1 = none), `water_pockets`: caves at or below that depth start full of water.

Its `base_chunk` does a chunk in one pass (rim test only on cells at the chunk's edge). A subclass
that overrides `base_tile` or `base_water` falls back to the per-cell path unless it overrides
`base_chunk` too.

## Digging and edits

`dig(cell, offsets, player)` removes every breakable solid tile at `cell + offset`, emits
`tile_dug(cell, block, player)` for each, emits `dig_blocked` for unbreakable ones, and returns
the removed cells. `set_tile(cell, id)` is the lower-level edit.

`EditStore` (`world.edits`) keeps only differences from the generator's base: `tiles` (cell to id)
and `water` (cell to bool); write it through `set_tile` / `set_water` / `load_save` (TileWorld
remembers which chunks have edits, so the others load without per-cell lookups). An entry is dropped when the cell goes back to its base value, so a
dug-then-refilled cell costs nothing. `to_save()` returns plain JSON-safe data:

```
{"seed": 1234, "edits": [x, y, id, x, y, id, ...], "water": [x, y, 0_or_1, ...]}
```

`load_save` accepts ints or floats (what `JSON.parse_string` gives) and warns when the save seed
differs from the world seed. Use the same shape, generator settings and palette to load.

## Falling bodies and props

`FallingBody` (a `RigidBody2D`) ignores project gravity and applies `shape.gravity_at(position)`.
Set `color`, `size_px`, `round`; `floats = true` makes it rise in water. It finds its `TileWorld` by
walking up its parents.

* It sleeps when at rest; the world indexes the cells under and beside it. It wakes only when one
  of those stops being solid (`dig` / `set_tile`), never on its own.
* `max_awake_bodies` (default 60): a hard cap. Past it, wake requests wait in a FIFO queue and are
  released as other bodies fall asleep or are freed. Bodies the physics engine wakes by itself (a
  bump, a collision rebuild) are checked at the start of every physics tick: the fastest
  `max_awake_bodies` stay awake, the rest go back to sleep at the back of the queue (so a body put
  to sleep in mid-air falls again when its turn comes).
* Frozen while its chunk is not loaded; it returns asleep, or awake if its support is gone or it
  was falling. `body_landed(body, speed)` fires on a hard landing.

`BreakableProp` has a `footprint` in tiles (top-left at its position), static collision, and
`support_needed` (default 0.5): when the solid share of the cells under it drops below that (checked
when one of them is dug) it breaks into one awake `FallingBody` per footprint cell, emits
`prop_broke(prop, pieces)` and frees itself. `break_apart()` does it by hand.

## Water

Water is a set of full cells in loaded chunks. Each tick (`water_hz`, default 10) a cell moves to
`shape.below` if that is free, else to a free `shape.sides` cell (only when it could then fall, or
water presses from above, so flat water settles). It never enters a solid tile, a cell outside the
shape or an unloaded chunk, and the count never grows. Only cells near a change are checked, so a
still lake costs nothing. `water_entered(cell)` fires when water first flows into a dug-out cell.

`step_water()` runs one tick by hand (`water_hz <= 0` leaves ticking to you). `drain_per_second`
(default 0) removes surface cells. `buoyancy_at(pos)` is zero when dry and `-gravity_at(pos) * 1.6`
in water; `FallingBody.floats` uses it.

## Darkness and lights

`set_darkness([{from, to, darkness, tint}, ...])` darkens by `depth_of` (`darkness` 0..1, `tint` a
Color); `[]` removes it. `add_light(node, radius_px)` cuts a smooth hole in the dark that follows
the node; `remove_light(node)` undoes it. Up to 8 lights; each chunk that is fully lit costs
nothing. `darkness_at(depth)` reads a band.

## Performance knobs

* `chunk_radius` (1): chunks kept around each tracked node, 3x3 at 1. The biggest lever.
* `chunk_budget_per_frame` (1): new chunks built per physics frame; the rest wait. Chunks that
  left the neighbourhood are freed (two per frame) only in frames that built none, and the water
  tick waits one frame after a frame that built or freed a chunk. A chunk costs about 3 ms of
  script plus 3 to 4 ms of TileMapLayer collision build on this CPU.
* `max_awake_bodies` (60): awake rigid bodies; the rest queue. `water_hz` (10): water ticks per second.

Measure with `demo/stress.tscn` before changing any.
## Demos and tests

* `demo/shape_demo.tscn`: a scripted digger tunnels under boulders and a water pocket in the dark.
  `godot --path . res://addons/openjar/tileworld/demo/shape_demo.tscn -- --shape=disk` (default rect).
* `demo/stress.tscn`: fixed-seed performance run with no input. Args after `--`: `--seconds=60`
  (measured time, after 2 s warm-up), `--seed=1234`, `--shape=rect|disk`, `--bodies=60`,
  `--out=<path>` (default `user://tileworld_stress.json`). Prints and writes a JSON summary (frame
  time percentiles, physics time, awake bodies, tiles dug, chunk loads) and quits. Vsync and the
  fps cap are off. Use `godot --headless` for logic cost, `godot-render` for a real renderer.
* `tests/test_tileworld.gd` (gdUnit4):
  `godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests/test_tileworld.gd`
