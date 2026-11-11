# Plan status: The Hill

True on `dev` at `8ee8d2d` (2026-11-10, plan-sync lane). Lanes: update your rows in the same commit as the work
(format: `~/openjar/lanes/plan-status-format.md`). Gary: add rows when a new brief arrives; never
delete rows, supersede them.

Sources (newest last):
- S1 `~/openjar/THEHILL-PLAN-2026-11-09.md` (Kaden's original brief). GAME.md's Pitch through Out of scope is S1 word for word (one wording change: "no real places").
- S2 GAME.md "Producer notes" (2026-11-09/10), including Kaden's art notes D45 (2026-11-10)
- S3 GAME.md "Decisions made without Kaden", 2026-11-10 Gary: water, elevator, camera
- S4 GAME.md decisions, 2026-11-10 Systems lane: Showtime menus (D48 d)
- S5 GAME.md decisions, 2026-11-10 Systems lane: character chooser
- S6 GAME.md decisions, 2026-11-10 Gameplay lane: residents and hazards
- S7 GAME.md decisions, 2026-11-10 Gameplay lane: vehicles and treasures
- S8 Kaden 2026-11-10 (via Gary, chooser-catchphrase brief): "when a character is up on the screen, I'd like it to say it's catchphrase once"

There are no "Playtest ... changes" sections yet (`playtests/` holds only the template).

**How proof was checked (2026-11-10, plan-status lane; re-run by the plan-sync lane):** `tests/<file>.gd::<test>`
names a gdUnit test. The full suite ran on `8ee8d2d`: **288/288 pass**. Frames are real Forward+ renders
from `scripts/tools/shots.sh`, saved in this worktree under `.scratch/shots/` (git-ignored). Each
one was looked at. To remake one, run
`scripts/tools/shots.sh "" 4,8 $PWD/.scratch/shots/<beat> --demo --demo-beat=<beat>`; for `demo`, use
`--demo` with times 6,12,18; for `lobby`, use `--ui=lobby-ready`.

**Branch work that is not on `dev`:** only `feature/art-direction-options-2` (round-2 art styles D and E, V-03).
Resident arcs (PR 9, `b9966b0`), the audio pass (PR 12, `2b1a65c`) and polish 2 (PR 13, `8ee8d2d`) are all
merged; the 2026-11-10 plan-sync moved their rows (see "Plan-sync 2026-11-10" below the Totals).

ID prefixes: C core loop, W underground world, T Hillville, B buildings, R residents,
H vehicles, P players, S systems/camera/tech, M menus, V visuals, A audio, K kid-design,
X out of scope, Q open questions, F build phases.

## Core loop and Kaden's north-star notes

| ID | Source | Item (short, Kaden's words where possible) | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| C-01 | S1 Notes | "Dig & build sandbox: two players dig down, find treasure, build up" | built | tests/test_hill_demo.gd::test_demo_finds_the_car_builds_and_unlocks_the_excavator; .scratch/shots/demo/t018.0s.png | |
| C-02 | S1 Notes | "Chunked world" | built | tests/test_tileworld.gd::test_chunks_load_and_free | |
| C-03 | S1 Notes | "Soft goal: the hill has a bottom, and something is down there" | built | tests/test_hazards_residents.gd::test_the_dragon_reveal_plays_once_and_it_saves; tests/test_resident_arcs_underground.gd::test_the_dragon_second_meeting_brings_her_up_and_not_before_the_first; tests/test_resident_arcs.gd::test_dragon_perch_flies_her_up_and_warms_the_ice | The Dragon sleeps at the bottom; the first meeting, her wake, the ride up and the Perch are all on dev (resident arcs, PR 9) |
| C-04 | S1 Notes | "Prefab building, not individual blocks" | built | tests/test_hill_build.gd::test_place_snaps_to_plot_grid | |
| C-05 | S1 Notes | "He still chooses what buildings go where … If he wants 100 barns, so be it" | built | tests/test_hill_build.gd::test_a_hundred_barns_never_refused | |
| C-06 | S1 Notes | "He has to clear the land above in order to build" | built | tests/test_hill_build.gd::test_scooped_plot_becomes_buildable | |
| C-07 | S1 Notes | "The hill comes with a Front Loader" | built | tests/test_hill_game.gd::test_hop_in_drive_and_hop_out; .scratch/shots/lineup/t008.0s.png | |
| C-08 | S1 Notes | "Going underground is a cutscene, separated from up top" | built | tests/test_hill_game.gd::test_ride_down_to_deepest_and_up_dumps_backpacks | The cutscene is the elevator cage ride (see S-03) |
| C-09 | S1 Notes | "One player up top, the other below: true split screen. If both are visible on one screen, the split disappears" | built | tests/test_split.gd::test_table_one_up_one_down_is_split_even_at_same_coordinates, ::test_close_players_share_one_view; .scratch/shots/demo/t018.0s.png | |
| C-10 | S1 Notes | "Game name: The Hill. Town name: Hillville" | built | assets/ui/the_hill_logo.png; .scratch/shots/lobby/t003.0s.png | The town name "Hillville" never appears on screen |
| C-11 | S1 Players | Both players share one inventory (the shaft pile) and one town | built | tests/test_inventory.gd::test_spend_is_all_or_nothing; tests/test_hill_game.gd::test_ride_down_to_deepest_and_up_dumps_backpacks | |
| C-12 | S1 Loop | Load in: Hillville is as you left it | built | tests/test_hill_build.gd::test_hillville_save_round_trip, ::test_rebuild_from_progress | |
| C-13 | S1 Loop | Session start: the gnome crew has dug overnight and left a pile at the shaft | built | tests/test_resident_arcs.gd::test_the_crew_award_runs_on_load_from_the_saved_stamp; tests/test_polish.gd::test_every_save_stamps_the_time_and_a_clock_set_back_gives_nothing; handoff/frames/crew_overnight_march.png | Wired by the resident-arcs merge (b9966b0): on load with the Gnome Village standing, `ruins.crew_return(save.away_seconds)` piles blocks at the shaft and the crew marches out. Checked and framed by polish-2 |
| C-14 | S1 Loop | Backpack full is never a hard stop; the icon goes round and happy | built | tests/test_hill_game.gd::test_full_backpack_never_stops_digging; scenes/game/hud.gd | |
| C-15 | S1 Loop | Ride up and the backpack dumps at the shaft pile | built | tests/test_hill_game.gd::test_ride_down_to_deepest_and_up_dumps_backpacks | |
| C-16 | S1 Loop | Treasures unlock one specific thing each (car → Garage, Gnome Room → Gnome Village) | built | tests/test_vehicles_treasures.gd::test_each_garage_gives_the_next_vehicle_and_the_drill_garage_waits_for_the_tooth; tests/test_resident_arcs_underground.gd::test_opening_the_gnome_room_frees_the_crew | Car → Garage, tooth → Drill Garage, Gnome Room → crew freed → Gnome Village restore (PR 9) |
| C-17 | S1 Loop | Blocks by depth: dirt, clay, stone, sand, ice, crystal | built | data/blocks/sand.tres; tests/test_depth_life.gd::test_every_block_resolves_to_a_data_row_and_a_tile, ::test_sand_lies_only_in_the_lower_stone_layer, ::test_digging_sand_behaves_like_dirt; handoff/frames/depth_sand_dig.png | Depth life lane: Sand (id 8, pale gold tile, `dig_dirt` cue, dug like dirt, value 5) sits in the lower Stone layer (depth 100 to 130, `stone.tres` mix 0.78 stone / 0.12 sand / 0.1 clay; the generator only puts a block at or below its `depth_from`). On the pile and the elevator picker. Pebbles, pipes, ore and geodes still have no data rows, so they were not added; roots, snow and the frozen fish are drawn (W-03, W-11). The build book (`scenes/ui/build_book.gd`, UI lane) does not list sand yet |
| C-18 | S1 Loop | Deeper blocks are worth more; some buildings need a specific kind | built | data/buildings/garage.tres (clay+stone), data/buildings/lighthouse.tres (stone+crystal) | |
| C-19 | S1 Loop | No fail state: nothing underground hurts; town can't be damaged | built | tests/test_hazards_residents.gd::test_a_falling_boulder_bonks_briefly_and_takes_nothing, ::test_a_breached_pocket_floats_the_player_and_takes_nothing | |
| C-20 | S1 Loop | Session 10–20 min, saves at every trip up | built | scenes/game/elevator.gd (every ride autosaves); tests/test_hill_game.gd::test_save_round_trip | Session length is unmeasured until the first playtest |
| C-21 | S1 Two depths | Logistics: backpack, Dump Truck and gnome crew are real hauling limits | built | tests/test_hill_game.gd::test_backpack_fills_and_capacity_follows_barns; tests/test_vehicles_treasures.gd::test_dump_truck_carries_five_backpacks_and_tips_the_whole_load_onto_the_pile; tests/test_resident_arcs.gd::test_gnome_village_crew_leaves_a_capped_pile_after_time_away | The crew hauls while the game is closed (C-13, capped by Rules.GNOME_CAP) |
| C-22 | S1 Two depths | Underground engineering: drain or redirect water, drop a boulder to break a wall, route around blocks that need a vehicle | partial | tests/test_tileworld.gd::test_water_pile_levels_out_then_goes_still; tests/test_proto.gd::test_boulder_sleeps_then_falls_when_undercut | Water and falling boulders work. There are no walls a boulder breaks and no blocks that need a vehicle, so no puzzle is placed yet |
| C-23 | S1 Two depths | Town adjacency: hearts float between buildings that like each other (`data/adjacency.tres`) | missing | none (no data/adjacency.tres; no hearts code) | Barns+Village, Tower+pond, Lighthouse on peak, Museum+shaft |
| C-24 | S1 Two depths | Collection: the Museum shows treasures left per layer; the Mole's glow finds them; Strangestone is a curious wall | built | tests/test_vehicles_treasures.gd::test_a_pickup_pops_up_flies_into_the_bag_and_lands_on_the_shelf; tests/test_resident_arcs.gd::test_museum_takes_the_treasure_shelf_and_the_caveman_polishes; tests/test_resident_arcs_underground.gd::test_a_lost_and_found_visit_glows_unfound_treasure_and_gives_blocks | Shelf silhouettes per layer move into the Museum; the Mole's visit glows unfound treasure; Strangestone is W-24 |
| C-25 | S1 Guardrails | No text, numbers or tooltips for the adult layer | built | scenes/game/hud.gd ("no numbers and no text"); .scratch/shots/book/t008.0s.png | |
| C-26 | S1 Guardrails | Tuning lives in data: adjacency, `BuildingData.needs_blocks`, `LayerData.hazards` | partial | data/hazards/*.tres; data/buildings/*.tres `cost` | Hazards became a `HazardData` row type (S6). Block needs are the `cost` dictionary. Adjacency is missing |
| C-27 | S1 Data | `data/BALANCE.md`: Buried Car in 5 min, Excavator by 15 min, bottom in 3–4 h | missing | none (no data/BALANCE.md) | The demo reaches the Excavator, but nobody has timed real play |

## Underground

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| W-01 | S1 Underground | ~200 x 300 tiles at 16 px, every tile diggable | built | tests/test_data.gd::test_layers_tile_0_to_300; tests/test_tileworld.gd::test_save_is_edit_only_and_round_trips | |
| W-02 | S1 Underground | Six layers with a dominant hue each (Topsoil, Clay, Stone, Ice, Crystal, Bottom) | built | data/layers/*.tres; .scratch/shots/rescue/t005.0s.png, crystal/t005.0s.png, reveal/t005.0s.png | |
| W-03 | S1 Topsoil | Dirt, roots, worms that wave | built | tests/test_depth_life.gd::test_roots_hang_only_from_topsoil_dirt_ceilings_and_go_when_dug, ::test_a_worm_waves_only_when_the_player_is_close_then_ducks_back, ::test_a_dug_out_worm_cell_takes_its_worm_with_it; handoff/frames/depth_roots_landing.png, depth_worms_wave.png | Depth life lane: roots hang from Topsoil dirt ceilings (seeded per cell, about one ceiling in five, two always in the landing room; they sway; dig the cell and the root goes). Worms live in some dirt cells (and both landing-room walls): stand next to one and it pops out (`pop`), waves, ducks back in when you leave (or after 2.4 s) and rests 5 s. Drawn in `scripts/gameplay/depth_life.gd`, no collision change, no text. `--demo-beat=worms`. No worm sound of its own yet (uses `pop`) |
| W-04 | S1 Topsoil | Treasures: bottle caps, a boot, a bike | built | data/treasures/{bottle_caps,boot,bike}.tres; tests/test_vehicles_treasures.gd::test_every_layer_but_the_bottom_has_treasures_placed_in_it | |
| W-05 | S1 Clay | Treasures: buried car, bathtub, fossils | built | data/treasures/{buried_car,bathtub,fossil}.tres; tests/test_hill_game.gd::test_buried_car_in_clay_found_by_digging_next_to_it | |
| W-06 | S1 Clay | Water pockets flood and float you up | built | tests/test_hazards_residents.gd::test_a_breached_pocket_floats_the_player_and_takes_nothing | |
| W-07 | S1 Clay | Dim; headlamp | built | tests/test_hazards_residents.gd::test_darkness_values_load_from_data; .scratch/shots/rescue/t005.0s.png | |
| W-08 | S1 Stone | Gnome Room, giant tooth, dinosaur skeleton | built | data/treasures/{gnome_room,giant_tooth,dino_skeleton}.tres | |
| W-09 | S1 Stone | Rolling boulders: bonk, stars, fine | built | tests/test_hazards_residents.gd::test_a_falling_boulder_bonks_briefly_and_takes_nothing | |
| W-10 | S1 Stone | Dark; needs the Lighthouse | built | tests/test_polish.gd::test_a_lighthouse_lights_stone_and_each_more_lights_the_next_layer_down; handoff/frames/lighthouse_before_dark_stone.png, lighthouse_lit_stone.png | Dark until the first Lighthouse (B-07) |
| W-11 | S1 Ice | Ice (slippery), snow, frozen fish | built | tests/test_hazards_deep.gd::test_a_slide_on_ice_ends_in_a_hole_and_drifts_gently_a_layer_down, ::test_a_vehicle_skates_into_the_hole_too, ::test_warm_ice_does_not_slide_and_other_ground_never_does; handoff/frames/ice_slide_skate.png, ice_loader_tips_in.png; tests/test_depth_life.gd::test_one_frozen_fish_sits_in_the_ice_floor_of_every_rink, ::test_the_frozen_fish_is_a_treasure_once; handoff/frames/depth_snow_fish.png, depth_fish_reveal.png, depth_fish_free.png | Hazards-3: slippery is built. On ice (`BlockData.slippery`) the stick steers a glide that keeps going after letting go and turns slowly, on foot and in every vehicle, with speed streaks, a spray at the feet and a whoosh (`dragon_whoosh`). Not once `Story.ice_warm()`. Snow: only the snow piles in the ice-hole nests and the flakes in the chutes. Depth life lane: snow drifts on every rink's ice floor (a white cap, piled against the far wall), and one frozen fish (`data/treasures/frozen_fish.tres`, a picture) in one floor block per rink. Dig it out: the first is the treasure (reveal, bag, shelf); later ones wiggle free and swim off (`splash`), never a second treasure. `--demo-beat=fish`. No fish sound of its own yet |
| W-12 | S1 Ice | A frozen caveman who wakes and waves; a pirate chest | built | tests/test_hazards_residents.gd::test_the_caveman_thaws_once_and_it_saves; data/treasures/pirate_chest.tres | |
| W-13 | S1 Ice | Hazard: slide into holes | built | tests/test_hazards_deep.gd::test_a_slide_on_ice_ends_in_a_hole_and_drifts_gently_a_layer_down, ::test_ice_holes_and_lava_pockets_place_from_data_and_move_nothing_else; handoff/frames/ice_hole_drift.png, ice_hole_nest.png | Hazards-3: data/hazards/ice_hole.tres (3 rinks, 1 near the Ice landing). Each rink has an ice floor and a 4-wide hole (fits the Drill Rig) at the end away from the shaft; its chute drops to a nest at the top of Crystal. The drift is capped at `Hazards.HOLE_FALL` (210 px/s) with snowflakes; landing on the snow pile pops. Nothing is taken. `--demo-beat=ice_slide`, `ice_drive` |
| W-14 | S1 Crystal | Crystal is worth the most; lava pockets bounce you, no damage | built | tests/test_hazards_deep.gd::test_lava_bounces_a_bounded_hop_and_never_hurts; data/blocks/crystal.tres; handoff/frames/lava_bounce.png | Hazards-3: data/hazards/crystal_lava_pocket.tres (4 rooms, 1 near the Crystal landing). The pool is drawn (orange, juice dashes, bubbles, a glow), not a tile, so no new tile art. Standing on it launches `Hazards.LAVA_HOP` (hop about 66 px, test bounds 32 to 80) with `dragon_boing` and an orange ring. No damage path. `--demo-beat=lava`. The `BlockData.bouncy` field is still unused |
| W-15 | S1 Crystal | The Dragon Egg; self-lit | built | data/treasures/dragon_egg.tres; .scratch/shots/crystal/t005.0s.png | |
| W-16 | S1 Bottom | Huge cavern; the Dragon asleep around the last treasure; warm | built | .scratch/shots/reveal/t005.0s.png | |
| W-17 | S1 Bottom / Audio | Her snore shakes the screen; louder by depth | partial | tests/test_polish.gd::test_the_dragon_snore_sways_the_cavern_and_not_topsoil; tests/test_audio.gd::test_snore_gets_louder_with_depth | The snore sound (hill_audio.gd, every 5.5 s, louder by depth) and the puff + sway (underground_residents.gd, every 5.0 s) run on two clocks, so sound and puff drift apart, and both sway the camera at the Bottom. Make hill_audio play on `dragon_snored` and drop its `_shake` |
| W-18 | S1 Underground | Directional digging: 1 tile shovel, 3-wide Excavator, 5-wide Drill Rig | built | data/vehicles/*.tres `dig_shape`; tests/test_hill_game.gd::test_vehicle_dig_fits_its_body | |
| W-19 | S1 Underground | Loose things fall: boulders, treasures, bathtub, the Mole | partial | tests/test_tileworld.gd::test_falling_body_wake_rules | Only boulders fall. Treasures are pickups or stay put (S7), and the Mole doesn't fall |
| W-20 | S1 Underground | Props break into chunks when dug under (car, gnome-room walls) | partial | tests/test_tileworld.gd::test_breakable_prop_breaks_when_undercut | The engine can do it, but the car stays where it lies (S7) and no gnome-room walls break |
| W-21 | S1 Underground | Tunnels persist; only edits are saved | built | tests/test_tileworld.gd::test_save_is_edit_only_and_round_trips | |
| W-22 | S1 Underground | Light is a soft gate: you can dig in the dark but can't see the sparkle | built | tests/test_polish.gd::test_a_lighthouse_lights_stone_and_each_more_lights_the_next_layer_down; handoff/frames/lighthouse_lit_stone.png | Lighthouses lift the darkness one layer each from Stone down; Topsoil and Clay stay headlamp layers |
| W-23 | S1 Underground | Bottom reveal: Dragon yawns, hill shakes, asks to come up, elevator carries her up in pieces, she coils on the peak | built | tests/test_hazards_residents.gd::test_the_dragon_reveal_plays_once_and_it_saves; tests/test_resident_arcs_underground.gd::test_the_dragon_second_meeting_brings_her_up_and_not_before_the_first; tests/test_resident_arcs.gd::test_the_dragon_comes_up_in_pieces_and_waits_by_the_keep | First meeting, then the wake; she comes up the shaft in three slices and waits on the peak by the Ruined Keep (PR 9) |
| W-24 | S1 World borders | Strangestone below the cavern: faint runes, slow pulse, shovel bounces with a sparkle and a ? bubble | built | tests/test_polish.gd::test_strangestone_bounces_with_a_question_bubble_and_edgestone_does_not; handoff/frames/strangestone_question.png | Polish-2: scripts/gameplay/strange_bubble.gd: a ? picture bubble over the digger and a ring of sparkles at the tile; `dig_blocked` plays as before |
| W-25 | S1 World borders | Edgestone at left/right edges, hazard stripe, unbreakable | built | tests/test_hill_game.gd::test_edges_and_floor_are_unbreakable | |
| W-26 | S1 World borders | Both are `BlockData` with `breakable = false` + `breakable_from_version` | built | tests/test_data.gd::test_unbreakable_blocks_by_version | |
| W-27 | S6 | Layer darkness values (Topsoil 0.3, Clay 0.6, Stone 0.8, Ice 0.5, Crystal 0.15, Bottom 0.3) | partial | tests/test_hazards_residents.gd::test_darkness_values_load_from_data | Needs a recheck on the TV |
| W-28 | S6 | Hazard counts as data; one of each kind near the first landings | built | tests/test_hazards_residents.gd::test_hazard_rows_place_per_layer_with_a_few_near_the_first_landings | |
| W-29 | S6 | Cave-in: the Mole digs you out ~1.6 s, the game frees you by 4 s | built | tests/test_hazards_residents.gd::test_digging_into_a_cave_in_traps_then_the_mole_frees_in_time, ::test_a_trapped_player_is_free_within_trap_max_even_without_the_mole; .scratch/shots/rescue/t005.0s.png | |
| W-30 | S7 | Treasures per layer are pickups: pop up, fly into the bag | built | tests/test_vehicles_treasures.gd::test_a_pickup_pops_up_flies_into_the_bag_and_lands_on_the_shelf | |

## Up top: Hillville

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| T-01 | S1 Up top | Side-view town ~8 screens wide, starts as scrub (trees, rocks, stumps, fence), shaft + Front Loader | built | tests/test_hill_build.gd::test_scrub_layout_is_deterministic; .scratch/shots/lineup/t008.0s.png | |
| T-02 | S1 Up top | The Loader scoops scrub into blocks and leaves a flat plot | built | tests/test_hill_build.gd::test_scoop_tree_and_stump_give_dirt_rock_gives_stone | |
| T-03 | S1 Up top | Bigger vehicles clear bigger areas | built | data/vehicles/excavator.tres (`clear_area` 3x2), crane.tres | |
| T-04 | S1 Up top | Build book: one button, pictures, cost as stacked block icons, greyed if short | built | tests/test_hill_build.gd::test_book_cards_affordable_greyed_and_garage_gate; .scratch/shots/book/t008.0s.png | |
| T-05 | S1 Up top | A ghost follows you, snaps to the grid, unfolds with a clunk | built | tests/test_hill_build.gd::test_place_snaps_to_plot_grid; tests/test_art_sprites.gd::test_building_art_and_garage_door_frames | |
| T-06 | S1 Controls | Not clear → the ghost goes red and the Loader honks | built | tests/test_hill_build.gd::test_bad_plots_rejected_with_honk_and_no_spend | |
| T-07 | S1 Up top | "The game cheers every time" | built | tests/test_hazards_residents.gd::test_the_crew_cheers_at_a_delivery_and_marches_past_a_new_building | The crew marches past each new building (S6) |
| T-08 | S7 | Treasure Shelf right of the Caveman's fire: one board per layer, silhouettes for what's left | built | .scratch/shots/shelf/t008.0s.png | The shelf moves into the Museum once it is restored (tests/test_resident_arcs.gd::test_museum_takes_the_treasure_shelf_and_the_caveman_polishes) |

## Buildings

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| B-01 | S1 | Barn, 10 dirt: +1 backpack per barn, no cap | built | tests/test_hill_game.gd::test_backpack_fills_and_capacity_follows_barns | |
| B-02 | S1 | Barn: cows wander out; more barns, more cows | built | tests/test_polish.gd::test_every_barn_has_a_cow_in_its_yard_and_a_new_one_trots_out, ::test_a_hundred_barns_is_a_hundred_cows, ::test_walking_into_a_cow_makes_her_hop; handoff/frames/cows_*.png | Polish-2: scripts/gameplay/barn_cows.gd. **Placeholder cow drawn in code**: the library cow is only a proposal (openjar-characters `feature/quadruped-cow`, name open as D53), not approved for play. TODO(audio): `cow_moo` is not in CUES.md |
| B-03 | S1 | House, 15 dirt + 5 clay: lights at dusk; Jeff and Chuck sleep here | built | data/buildings/house.tres; assets/sprites/buildings/house_lit.png; tests/test_gap_close.gd::test_by_night_the_absent_p2_sleeps_in_the_house_and_by_day_in_the_bucket, ::test_waking_at_night_comes_out_of_the_house_door; handoff/frames/house_sleeper_zs_night.png, house_wake_out_of_door.png (gap-close-1) | building.gd swaps in the lit sprite at night (town-life-1 checked it in frames, on its branch). Gap-close-1: by night (lights >= 0.5) the player not yet in the game sleeps in the first House instead of the Loader's bucket: Zs in their slot colour drift out of the attic window; a press wakes them out of the House door with a puff (`hop_out`). By day the bucket, as GAME.md's drop-in says. Beat `--demo-beat=house` |
| B-04 | S1 | Garage, 20 clay + 10 stone, needs the Buried Car; each opens the next vehicle | built | tests/test_hill_build.gd::test_garage_unlocks_excavator_then_still_allowed; tests/test_vehicles_treasures.gd::test_each_garage_gives_the_next_vehicle_and_the_drill_garage_waits_for_the_tooth | |
| B-05 | S1 / S7 | Vehicles park at their Garage; a Garage built early waits with its door shut | built | tests/test_vehicles_treasures.gd::test_vehicles_treasures_buildings_survive_a_reload | |
| B-06 | S1 | **Workshop**, 15 stone: bigger shovel, faster vehicles; hammering and sparks | built | tests/test_gap_close.gd::test_the_workshop_is_a_book_card_for_fifteen_stone, ::test_tool_level_counts_workshops_up_to_the_cap, ::test_the_bigger_shovel_bites_one_cell_deeper_on_foot, ::test_a_workshop_digs_quicker_and_drives_faster_capped, ::test_building_a_workshop_pops_the_shovel_over_every_player_with_one_sound, ::test_the_workshop_hammers_with_sparks_and_clangs_only_near_a_player; data/buildings/workshop.tres; handoff/frames/workshop_*.png, big_shovel_*.png (gap-close-1) | Gap-close-1: a book card for 15 stone (after the Garage). Each Workshop is a `dig_power` level (`Progress.tool_level()`, max 2): on foot the bigger shovel takes one more cell per dig with a gold glint; digging is 35% quicker and vehicles 15% faster per level. Built: a big gold shovel pops over every player with sparks (`tool_upgrade`). The building hammers the anvil with sparks and chimney smoke; the clang (`workshop_hammer`) only near a player. Sounds are stand-in aliases (see A-01). Beats: `--demo-beat=workshop|shovel` |
| B-07 | S1 | Lighthouse, 20 stone + 5 crystal: lights the next layer down per one built; sweeping beam at night | built | tests/test_polish.gd::test_a_lighthouse_lights_stone_and_each_more_lights_the_next_layer_down, ::test_a_saved_lighthouse_lights_stone_after_a_reload, ::test_building_a_lighthouse_flares_its_lamp; handoff/frames/lighthouse_*.png (polish-2) | Polish-2: the first Lighthouse lights Stone, each more lights the next layer down (UndergroundLook "lit layers": darkness x0.22, warm tint, 1.2 s fade, a lantern and sweeping beam at the lit landing). Up top the lamp flares and shines down when placed, and sweeps the sky at night (scenes/buildings/lighthouse_beam.gd). TODO(audio): a `lighthouse_on` cue for the light-up moment is not in CUES.md |
| B-08 | S1 | Museum: restore the Flooded Cabin; shows every treasure and how many are left per layer | built | tests/test_resident_arcs.gd::test_restore_card_only_while_arrived_and_paying_rebuilds_plank_by_plank, ::test_museum_takes_the_treasure_shelf_and_the_caveman_polishes; data/buildings/museum.tres | Restoring the Flooded Cabin makes the Museum; it takes over the Treasure Shelf (PR 9) |
| B-09 | S1 | Gnome Village: restore the Crooked Watchtower; the crew digs 20–50 blocks while the game is closed, up to a cap | built | tests/test_resident_arcs.gd::test_gnome_village_crew_leaves_a_capped_pile_after_time_away; handoff/frames/crew_overnight_march.png | Merged with resident-arcs (b9966b0); checked by polish-2 |
| B-10 | S1 | Water Tower, 15 stone + 10 ice: drains floods faster; generic look | built | tests/test_vehicles_treasures.gd::test_water_tower_drains_flooded_tunnels_near_a_player; .scratch/shots/shelf/t008.0s.png | S7 gates it behind the Crane |
| B-11 | S1 | Dragon Perch: restore the Ruined Keep; she warms the Ice layer so it's not slippery | built | tests/test_resident_arcs.gd::test_dragon_perch_flies_her_up_and_warms_the_ice; tests/test_resident_arcs_underground.gd::test_a_cold_save_keeps_the_ice_layer_cold; tests/test_hazards_deep.gd::test_warm_ice_does_not_slide_and_other_ground_never_does; data/buildings/dragon_perch.tres | The Perch restores and she flies up to it (PR 9). Since hazards-3 (PR 15) ice is slippery, and `Story.ice_warm()` turns the glide off, so the payoff is felt (gap-close-1 sync) |
| B-12 | S1 | Gnome crew comeback clip: pile at the shaft, gnomes march out with a whistle | built | tests/test_resident_arcs.gd::test_the_crew_award_runs_on_load_from_the_saved_stamp; handoff/frames/crew_overnight_march.png | Five gnomes march out of the shaft to the pile with a block each (scripts/gameplay/ruin_sites.gd `_draw_clip`); cues `whistle`, `crew_march` |
| B-13 | S1 Art | Buildings are multi-tile sprites with a 3-frame unfold | built | tests/test_art_sprites.gd::test_building_art_and_garage_door_frames | |

## Residents: the ruins

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| R-01 | S1 | Four ruins (Old Shed, Crooked Watchtower, Flooded Cabin, Ruined Keep): can't be cleared or built on | built | tests/test_hill_build.gd::test_ruins_cannot_be_picked_up, ::test_ruins_shaft_and_yard_have_no_scrub | |
| R-02 | S1 | Three beats (Encounter, Arrival hat-in-hands at the shaft, Fix-up via a restore card), all in picture bubbles | built | tests/test_resident_arcs.gd::test_silhouettes_show_once_met_and_arrival_pleads_in_pictures, ::test_restore_card_only_while_arrived_and_paying_rebuilds_plank_by_plank, ::test_every_arc_state_survives_a_reload | On dev since PR 9 |
| R-03 | S1 | The Mole steals your shovel, pops up elsewhere, apologises; 3 times, then he comes up | built | tests/test_resident_arcs_underground.gd::test_three_thefts_bring_the_mole_up_and_there_is_no_fourth, ::test_digging_on_foot_brings_a_theft_that_never_blocks_digging_or_walking, ::test_driving_never_brings_a_theft | On dev since PR 9. Thefts only on foot |
| R-04 | S1 | Lost & Found: tiles near treasure glow when he's near; "found" items at the shed door; he brings things underground | built | tests/test_resident_arcs.gd::test_lost_and_found_leaves_a_bundle_that_a_player_picks_up; tests/test_resident_arcs_underground.gd::test_a_lost_and_found_visit_glows_unfound_treasure_and_gives_blocks; data/buildings/lost_and_found.tres | On dev since PR 9 |
| R-05 | S1 | Foreman's crew found walled into the Gnome Room | built | tests/test_resident_arcs_underground.gd::test_opening_the_gnome_room_frees_the_crew, ::test_a_gnome_room_found_in_the_save_frees_the_crew_on_load; tests/test_resident_arcs.gd::test_the_crew_appears_up_top_only_once_freed | S6 put the crew up top from the start; the resident-arcs decision (GAME.md: "his crew joins him only once freed from the Gnome Room") restored the S1 walled crew, on dev since PR 9 |
| R-06 | S1 / S6 | Caveman thaws (headlamp, 3 s), waves, follows you up and waits by a campfire | built | tests/test_hazards_residents.gd::test_the_caveman_thaws_once_and_it_saves | S6: thaw by headlamp only; digging the block out and carrying it up comes later |
| R-07 | S1 | Ruins show the future resident's silhouette on the door once met | built | tests/test_resident_arcs.gd::test_silhouettes_show_once_met_and_arrival_pleads_in_pictures | scripts/gameplay/ruin_sites.gd calls `show_silhouette()` once a resident is met |
| R-08 | S1 | Restoring is optional, never times out; the resident waits at the shaft | built | tests/test_resident_arcs.gd::test_restore_card_only_while_arrived_and_paying_rebuilds_plank_by_plank; tests/test_hazards_residents.gd::test_the_caveman_thaws_once_and_it_saves | The restore card is offered only while a resident waits; nothing times out |
| R-09 | S1 | Residents wander, react to buildings, idle gags (Mole falls in pond, Caveman baffled by the Dump Truck, Foreman inspects barns) | built | tests/test_resident_arcs.gd::test_residents_react_to_a_building_placed_near_them, ::test_town_gags_pond_and_dump_truck; tests/test_hazards_residents.gd::test_the_crew_cheers_at_a_delivery_and_marches_past_a_new_building | Mole in the pond, Caveman baffled by the Dump Truck (tested). The Foreman's barn inspection is in scripts/gameplay/town_residents.gd with no test |
| R-10 | S1 | Each resident bible gets a "redemption arc" section | built | ~/openjar/openjar-characters/characters/{mole,gnome_foreman,caveman,dragon}/bible.md | |
| R-11 | S1 | The Mole occasionally sits in an empty vehicle and honks | partial | scripts/gameplay/town_residents.gd (`_empty_vehicle`, mode `honk`) | Code on dev (PR 9): he hops on a parked empty vehicle near a player and honks twice, every 50 s at most. No test or frame |
| R-12 | S6 | Mole rescues trapped players (dives, pops up, digs, hearts) | built | tests/test_hazards_residents.gd::test_digging_into_a_cave_in_traps_then_the_mole_frees_in_time; .scratch/shots/rescue/t005.0s.png | |
| R-13 | S6 | Crew cheers a delivery of 3+ blocks; Foreman holds up the build book | built | tests/test_hazards_residents.gd::test_the_crew_cheers_at_a_delivery_and_marches_past_a_new_building | The crew uses the Foreman's sprite, tinted, until a crew sheet exists |
| R-14 | S6 | Dragon's first meeting: stir, yawn, 3 smoke rings, purr, back to sleep; once per save, never fire | built | tests/test_hazards_residents.gd::test_the_dragon_reveal_plays_once_and_it_saves; .scratch/shots/reveal/t005.0s.png | |
| R-15 | S6 | Residents have no collision and keep to their rooms | built | tests/test_hazards_residents.gd::test_residents_have_no_collision_and_keep_to_their_rooms | |

## Vehicles

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| H-01 | S1 | Five vehicles, unlocked one per Garage | built | tests/test_vehicles_treasures.gd::test_ladder_is_five_vehicles_with_their_own_abilities_and_faceless_art; .scratch/shots/lineup/t008.0s.png | |
| H-02 | S1 | Front Loader: clears 1-tile scrub, carries a ghost, scoops 1 tile; horn, bucket tilt | built | tests/test_hill_game.gd::test_up_top_a_scoops_scrub_x_opens_the_book_y_honks | |
| H-03 | S1 | Excavator: clears 3x2, digs ponds; digs 3-wide; arm waves, cab spins all the way round | built | tests/test_crane_pond.gd::test_excavator_digs_a_pond_that_fills_with_water_and_keeps_it_after_a_reload, ::test_excavator_scoops_scrub_first_and_never_digs_a_pond_in_the_shaft_or_under_a_building; tests/test_polish.gd::test_the_excavator_spins_round_on_the_horn_and_the_loader_does_not; handoff/frames/pond_*.png, handoff/frames/excavator_spin_*.png (`--demo-beat=pond`, `spin`) | Crane-pond lane (2026-11-10, `feature/hill-crane-pond`): up top, A on bare yard ground (no scrub ahead) digs the 3 columns ahead of the bucket a tile deeper (2 at most; the dirt goes to the pile) and water seeps in over about 1 s (`flood`): a pond, saved. A on a full pond splashes. No ponds in the shaft, pile, ruins, the old pond or under a building; nothing is built on a dug pond. The horn spin turns the whole sprite (a cab-only spin needs a cab layer from the Art lane) |
| H-04 | S1 / S7 | Dump Truck: hauls the pile, best tip animation, 5x backpack, tips into the elevator, reverse beep | built | tests/test_vehicles_treasures.gd::test_dump_truck_carries_five_backpacks_and_tips_the_whole_load_onto_the_pile, ::test_dump_truck_reverses_with_a_beep_before_it_turns_round | |
| H-05 | S1 / S7 | Crane: places tall buildings, lifts/moves placed buildings, lowers you down the shaft fast, hauls boulders, wrecking ball for stumps | built | tests/test_vehicles_treasures.gd::test_crane_hooks_a_boulder_out_for_good_and_it_stays_gone_after_a_reload; tests/test_crane_pond.gd::test_crane_wrecking_ball_bonks_a_building_and_the_pile_and_takes_nothing, ::test_crane_ball_knocks_scrub_clear, ::test_crane_lifts_a_building_with_up_a_and_sets_it_down_somewhere_else, ::test_a_ride_down_with_the_crane_is_lowered_down_the_shaft_on_the_cable_in_under_two_seconds; handoff/frames/ball_*.png, lift_*.png, cable_*.png (`--demo-beat=ball`, `lift`, `cable`) | Crane-pond lane (2026-11-10): up top the rope carries a wrecking ball and A swings it: a building in front leans right over and springs back (`bonk`, a small view kick), the pile leans and blocks tumble off (nothing is lost), stumps and scrub are knocked clear 4x2. Up + A by a building lifts it on the hook (the boom telescopes over the roof); drive, then A sets it down (the build book's move rules). A ride down with the Crane aboard: after the cage sinks, the cable lowers the riders from the shaft mouth to the landing (0.6 s + 1.1 s), cable drawn to each rider |
| H-06 | S1 / S7 | Drill Rig: 5-wide straight down on its own; parks by the shaft; shakes the screen | built | tests/test_vehicles_treasures.gd::test_drill_rig_drills_five_wide_straight_down_on_its_own_until_told_to_stop | Gentle rumble only when Settings allows shake |
| H-07 | S1 | Vehicles are `.tres` data (dig shape, speed, carry, clear area, sounds, unlock) | built | data/vehicles/*.tres; tests/test_data.gd::test_every_row_loads_with_class_and_id | |
| H-08 | S1 | Hop in/out with one button; on foot is always an option | built | tests/test_hill_game.gd::test_hop_in_drive_and_hop_out | |
| H-09 | S1 | Both players can drive different vehicles at once | built | tests/test_two_drivers.gd (7 cases: ::test_excavator_and_loader_drive_and_dig_at_the_same_time_on_one_layer, ::test_neither_vehicle_takes_the_other_players_input, ::test_one_player_hopping_out_leaves_the_other_driving, ::test_a_bystander_keeps_their_powers_and_boards_the_free_vehicle_with_b, ::test_two_b_presses_at_one_free_vehicle_give_it_to_one_player, ::test_the_camera_frames_both_drivers_close_and_splits_to_each_driver_far, ::test_each_driven_vehicle_shows_its_drivers_stripe_row); handoff/frames/t003.0s.png, t005.0s.png (`--demo-beat=drivers`) | Two-vehicles lane (2026-11-10, `feature/hill-two-drivers`): P1 in the Excavator and P2 in the Loader on one layer drive, dig and honk in the same frames; the tests passed on the first run, so no game code needed fixing. Boarding is B (GAME.md controls table), not A; there is no boarding prompt to steal a press |
| H-10 | S1 Art / S2 | Vehicles big, round, friendly; **no eyes or faces** (D45 supersedes "faces in the headlights") | built | tests/test_vehicles_treasures.gd::test_ladder_is_five_vehicles_with_their_own_abilities_and_faceless_art; .scratch/shots/lineup/t008.0s.png | |
| H-11 | S1 Art | Two-frame idle wobble, exhaust puffs, player's stripe when driven | built | tests/test_gap_close.gd::test_exhaust_puffs_quicker_while_rolling_from_each_vehicles_stack; .scratch/shots/demo/t018.0s.png (stripe); handoff/frames/exhaust_loader_idle.png, exhaust_loader_zoom.png (gap-close-1) | Stripe and bob were on dev. Gap-close-1: while someone drives, the stack in each sprite puffs round smoke, slow idling and streaming back while rolling (the Dump Truck gets a small drawn stack; the Crane has none). Beat `--demo-beat=exhaust` |
| H-12 | S1 | v1.1 vehicle pack: Bulldozer, Cement Mixer, Steamroller, Paver, Tunneler (+ roads) | later | GAME.md Vehicles, "v1.1 vehicle pack" | Garages 5–9 |

## Players

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| P-01 | S1 | Jeff P1 green, Chuck P2 red, in hard hats | built | tests/test_hill_chooser.gd::test_defaults_are_jeff_and_chuck_on_their_own_sheets; .scratch/shots/lobby/t003.0s.png | |
| P-02 | S1 | Jeff and Chuck are "player-locked" | superseded | S5: any roster character can be picked; Jeff and Chuck are the defaults | The GAME.md cast table still says "player-locked" |
| P-03 | S5 | Plays whoever was picked; other characters get a sheet built at runtime | built | tests/test_hill_chooser.gd::test_a_pixel_form_only_character_gets_a_built_sheet, ::test_swapped_picks_swap_the_bodies | |
| P-04 | S1 | Drop-in: P2 asleep in the Loader's bucket; a button press tips him out | built | tests/test_hill_game.gd::test_p2_sleeps_in_the_bucket_then_drops_in_and_plays | |
| P-05 | S2 | The library gains a 2D pixel format for Jeff, Chuck and the four residents | built | assets/sprites/characters/{jeff,chuck,mole,foreman,caveman,dragon}.png | |
| P-06 | S1 | Personalities: Jeff names every rock; Chuck narrates his driving | partial | scripts/audio/hill_audio.gd (`Audio.bark("jeff", "rock_name")`, `Audio.bark("chuck", "narrate")`); tests/test_audio.gd::test_barks_fall_back_to_placeholders_and_are_rate_capped; tests/test_gap_close.gd::test_a_library_voice_pack_says_its_lines_for_game_cues | Jeff names rocks and Chuck narrates (PR 12). Gap-close-1: `Audio.LIBRARY_CUES` maps `rock_name` -> `cheer` and `narrate` -> `ready`/`wait`, so the moment Jeff's and Chuck's library packs land these lines play in their real voices. openjar-characters v0.5.0 has no voice pack for Jeff or Chuck, so they are still synth placeholders: needs the characters repo |

## Systems, camera, tech

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| S-01 | S1 Camera | Dynamic split table (both close = one camera … one up/one down = split … solo = full screen) | built | tests/test_split.gd::test_table_* (6 tests) | |
| S-02 | S1 Camera | Split slides in and out with a soft whoosh; player-coloured divider | built | tests/test_split.gd::test_far_splits_slides_and_joins; .scratch/shots/demo/t018.0s.png | |
| S-03 | S1 / S3 | Shaft: cage closes, half-second drop with a rattle; the door waits ~1 s so both can ride (S3) | built | tests/test_hill_game.gd::test_door_waits_then_closes, ::test_everyone_in_the_cage_rides_together, ::test_a_skips_the_wait | |
| S-04 | S1 Camera | Land at your deepest layer, or pick a layer on the way down (up/down, pictures) | built | tests/test_camera.gd::test_picked_layer_is_where_the_cage_stops, ::test_pick_stops_at_the_ends_and_up_top_goes_back_to_hillville, ::test_press_keeps_the_cage_going_but_never_long; tests/test_hill_game.gd::test_down_lands_at_the_deepest_rider_layer_up_goes_to_hillville; `--demo --demo-beat=pick` | Camera lane 2026-11-10 (feature/hill-camera-lead): pictures beside the shaft (LayerPick); up past Topsoil picks Hillville and the cage comes back up; each press keeps the cage going 0.7 s (max 4 s) |
| S-05 | S1 Controls | A dig, B jump/hop, X build book, Y horn, Start pause | built | tests/test_hill_game.gd::test_up_top_a_scoops_scrub_x_opens_the_book_y_honks | |
| S-06 | S1 Controls | Underground camera leads in the dig direction; zooms out a little in bigger vehicles | built | tests/test_camera.gd::test_lead_follows_the_move_direction_and_eases_back, ::test_no_lead_up_top_or_while_riding, ::test_shared_camera_has_no_lead, ::test_zoom_per_vehicle_from_data; `--demo --demo-beat=lead` | Camera lane 2026-11-10: scripts/gameplay/camera_lead.gd, values in data/camera.tres (lead 64x40 px, Dump Truck / Crane 0.85x = zoom 1.7, also up top). 1.7 is not a whole-pixel zoom: check on the TV with S-07 |
| S-07 | S3 | Camera zoom 2.0; check on the TV, likely 3.0 | partial | data/camera.tres (`zoom = 2.0`, read by scenes/game/hill_game.gd); tests/test_camera.gd::test_zoom_per_vehicle_from_data | Unchanged at 2.0, now in data. Waiting for the TV check (vehicles 1.7) |
| S-08 | S3 | Water conserved; breached pockets gush ~2 s | built | tests/test_hill_game.gd::test_breached_pocket_gushes_for_about_two_seconds | |
| S-09 | S1 Tech | Save: edits, treasures, inventory, buildings, vehicles, deepest layer, last scene, crew timestamp, `ResidentState`; autosave every ride and every 60 s | built | tests/test_hill_game.gd::test_save_round_trip; tests/test_data.gd::test_resident_save_round_trip_through_json; scenes/game/hill_save.gd (`AUTOSAVE_EVERY := 60.0`) tests/test_polish.gd::test_every_save_stamps_the_time_and_a_clock_set_back_gives_nothing | `gnome_stamp` is written on every save (scenes/game/hill_save.gd, resident-arcs merge) |
| S-10 | S1 Tech | Game contracts (signals, `Inventory.can_afford`, `World.dig`) in docs/contracts.md | built | docs/contracts.md; tests/test_inventory.gd::test_can_afford | `ruin_restored` (scripts/gameplay/story.gd) and `dragon_woken` (scripts/gameplay/underground_residents.gd) are emitted on dev since PR 9 |
| S-11 | S1 / S2 | Tile world and split director are game-agnostic; Worm's polar disk is a swap | built | tests/test_tileworld.gd::test_polar_body_falls_toward_core, ::test_chunk_manager_knows_no_concrete_shape | |
| S-12 | S1 Tech | Awake `RigidBody2D` cap 60; 9 chunks per player | built | tests/test_tileworld.gd::test_awake_cap_queues_wakes, ::test_chunk_budget_limits_new_chunks_per_call | |
| S-13 | CLAUDE.md / S1 | 60 fps at 1080p on a GTX 1060 | partial | addons/openjar/tileworld/demo (stress run) | The sim cost has been measured. Frame rate on a real GPU hasn't (the producer box renders in software) |
| S-14 | S1 Tech / F-5 | Move tile world + split screen into `openjar-addons`, tagged | missing | ~/openjar/openjar-addons/addons/openjar has no tileworld or split_screen | Both still live in this repo's `addons/openjar/` |
| S-15 | S1 Tech | `PictoBubble` scene for arcs, costs and prompts, then moved to `openjar-addons/ui/` | partial | scripts/gameplay/picto_bubble.gd (class PictoBubble; used by town_residents, underground_residents, treasure_shelf, strange_bubble) | PictoBubble exists in this repo as draw helpers (resident arcs). Not yet moved to `openjar-addons/ui/` (gap-close-1 sync) |
| S-16 | S2 | Template features: grown-up menus, solo, `--demo`, `--shots=`, release smoke-boot, `store/jar.glb` | partial | tests/test_lobby.gd::test_saved_solo_stays_off_at_boot; tests/test_hill_demo.gd; .scratch/shots/lobby/t003.0s.png; tests/test_store.gd::test_manifest_names_the_jar; tests/test_store.gd::test_zip_carries_the_jar_and_store_art; tests/test_store.gd::test_jar_fits_the_launcher_budget | `store/jar.glb` built (store-art-1: a cut-away hill slice, `art/tools/make_jar.sh`; the release manifest always names it and the release fails without it; launcher frame in the lane hand-off). Still open: the lobby version label reads v0.0.1, not the tag (template-wide bug) |
| S-17 | S2 | Premium slice spend logged in GAME.md by the producer | missing | none (no spend log in GAME.md) | |
| S-18 | S6 / S7 | `--demo-beat=` showcases (bonk … crystal; garage … lineup) | built | .scratch/shots/{lineup,book,shelf,rescue,reveal,crystal}/ | Polish-2 adds lighthouse, cows, strange, scoop, snore (scripts/gameplay/polish_beats.gd) |

## Menus

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| M-01 | S4 | Showtime kit with The Hill's skin (`data/menu_skin.tres`, palette A colours) | built | tests/test_hill_menu.gd::test_skin_loads_as_pixel_art; .scratch/shots/lobby/t003.0s.png | |
| M-02 | S4 | Pixel logo with the kit's tilt | built | assets/ui/the_hill_logo.png; .scratch/shots/lobby/t003.0s.png | |
| M-03 | S4 | Wipe card says "DIG IN!" | built | data/menu_skin.tres | |
| M-04 | S4 | Jeff and Chuck on the podiums at 8x; the plates name the pick | built | tests/test_hill_menu.gd::test_lobby_shows_both_pixel_characters; tests/test_hill_chooser.gd::test_podiums_show_and_swap_to_the_pick | |
| M-05 | S4 | Backdrop is a live Hillville with saved scrub and saved time of day | built | scenes/ui/hill_menu_backdrop.gd; .scratch/shots/lobby/t003.0s.png | |
| M-06 | S4 | Solo is never restored at boot | built | tests/test_lobby.gd::test_saved_solo_stays_off_at_boot | |
| M-07 | S5 | No character barks; a swap plays the generic `char_swap` | built | tests/test_hill_chooser.gd::test_a_character_without_barks_falls_back_never_to_another_voice | |
| M-08 | S8 | Chooser says the character's catchphrase once (Kaden 2026-11-10) | built | tests/test_chooser_voice.gd::test_three_fast_steps_say_only_the_last_after_the_settle, ::test_standing_still_never_repeats, ::test_joining_says_the_pick_once, ::test_leaving_cancels_a_pending_line, ::test_two_players_each_on_their_own_voice; tests/test_sync_characters.gd::test_vendors_the_catchphrase; .scratch/cycle-run.log | Ported from the template (docs/ui.md "Chooser voice"). Each step still plays `char_swap` at once (M-07); 0.3 s after the last step (or a join) the podium's character says `voice/catchphrase.ogg` on that player's panned voice, falling back to a bark. 17 of 21 v0.5.0 characters have one; Jeff, Chuck, Bloom and Old Reel stay silent after the swap |

## Visuals

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| V-01 | S1 / S2 D45 | Palette A "Sandbox" is the baseline | built | art/direction/palettes.md; .scratch/shots/lineup/t008.0s.png | |
| V-02 | S1 / S2 D45 | Day/night cycle as a palette shift (day, dusk, night); lights come on | built | tests/test_time_of_day.gd::test_phases; .scratch/shots/night/t008.0s.png | |
| V-03 | S2 D45 | Round-2 art direction: two distinct styles, one Terraria-leaning, before final art | partial | art/prompts/styles-d-e.md | D (Terraria) and E (picture book) are mocked on `feature/art-direction-options-2`, still not merged to dev (checked at 8ee8d2d); waiting for Kaden's pick |
| V-04 | S1 Art | 16 px tiles, 32 px characters, nearest-neighbour, whole-pixel zoom | built | art/direction/pixel-rules.md; tests/test_art_sprites.gd::test_sheet_frames_come_from_the_manifest | |
| V-05 | S1 Art | Distinct block colours: dirt brown, clay orange, stone grey-blue, ice pale blue, crystal purple | built | .scratch/shots/crystal/t005.0s.png, rescue/t005.0s.png | |
| V-06 | S1 Art | Treasures sparkle through the dirt from two tiles away | built | .scratch/shots/rescue/t005.0s.png (car and chest sparkle) | |
| V-07 | S1 Art | Juice: dig particles in block colour, shake on big scoops/falls, dust when a building lands, sparkle burst and ding | built | tests/test_polish.gd::test_a_big_scoop_kicks_and_a_loader_scoop_does_not, ::test_a_boulder_landing_near_kicks_and_far_does_not, ::test_kicks_are_small_short_and_off_with_screen_shake_off; handoff/frames/excavator_big_scoop.png | Polish-2: scripts/gameplay/screen_kick.gd. A scoop of 3+ tiles (Excavator, Crane, Drill) kicks 2-3 px for 0.22 s; a boulder landing within 14 tiles kicks up to 3.5 px for 0.25 s. Capped at 4 px / 0.9 s; Settings screen shake off = none. A still frame cannot show a shake |
| V-08 | S1 Art / F-6 | Store art: grid (Excavator mid-scoop, fossil flying, Chuck drives, Jeff cheers), hero (Hillville at dusk, Dragon on the peak) | built | store/grid.png; store/hero.png; tests/test_store.gd::test_store_images_are_the_tv_sizes | Rendered from the game by `art/tools/render_store.sh` (`art/store/store_shot.tscn`: a store camera over a staged real game). Grid: Chuck's Excavator scoops the fossil out of the Clay, Jeff cheers. Hero: Hillville at dusk, the Dragon asleep on her perch |
| V-09 | S1 / F-6 | Final pixel art for everything | partial | assets/sprites/manifest.json | Sandbox art covers everything on dev, including the restored ruins (bcb0571, PR 9) and the Workshop (gap-close-1, `art/tools/make_workshop_art.py`). Missing: a gnome crew sheet, final cows (polish-2 draws a placeholder cow in code) |
| V-10 | S2 / Q-3 | No real places: generic landmarks only | built | .scratch/shots/shelf/t008.0s.png (generic water tower) | |

## Audio

All cues below fire in code and, since the audio pass (PR 12), play real files from `assets/audio/sfx/`
and `assets/audio/music/` (seeded synth SFX from `assets/audio/tools/make_cues.py`, Gary's music; list in
`assets/audio/CUES.md`). A cue with no file still falls back to the synth beep
(tests/test_proto.gd::test_audio_synth_beep_for_missing_cues).

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| A-01 | CLAUDE.md | Sound on every action | built | tests/test_audio.gd::test_every_cue_resolves_to_a_file; tests/test_proto.gd::test_audio_synth_beep_for_missing_cues | On dev since PR 12: every cue in assets/audio/CUES.md has a file (seeded synth from make_cues.py). Still not in CUES.md: `cow_moo` (B-02), `lighthouse_on` (B-07). Gap-close-1 stand-ins (Audio.ALIASES): `workshop_hammer` -> `elevator_clank`, `tool_upgrade` -> `treasure_pickup`; real files wanted |
| A-02 | S1 Audio | `dig_<block>`: crumble, squelch, crack, crunch, chime | built | assets/audio/sfx/dig_*.ogg; tests/test_audio.gd::test_variants_rotate_without_repeats | Three variants per block, rotated (PR 12) |
| A-03 | S1 Audio | `scoop`, `tip`: hydraulic whine, rattle | built | assets/audio/sfx/scoop_1-2, bucket_tip, dump_truck_tip; assets/audio/CUES.md | `tip` is an alias of `dump_truck_tip` (PR 12) |
| A-04 | S1 Audio | `engine_<vehicle>`: looped, pitched by speed, one per vehicle | built | assets/audio/sfx/*_engine.wav; tests/test_audio.gd::test_engine_pitch_follows_speed, ::test_driving_in_the_game_runs_that_vehicles_engine | Looped per vehicle, pitched by speed (PR 12) |
| A-05 | S1 Audio | `horn_<vehicle>`: one per vehicle; Dump Truck reverse beep | built | assets/audio/sfx/*_horn.ogg, dump_truck_reverse.ogg; tests/test_audio.gd::test_every_vehicle_has_its_own_engine_and_horn | One horn per vehicle (PR 12) |
| A-06 | S1 Audio | `treasure`: sparkle and ding, bigger for rarer | built | scripts/audio/hill_audio.gd `treasure_cue`; tests/test_audio.gd::test_treasures_get_bigger_with_depth | Bigger cue (`treasure_big`, `treasure_huge`) for deeper treasures (PR 12) |
| A-07 | S1 Audio | `fall`, `bonk` | built | assets/audio/sfx/fall_1-3, bonk_1-2 | PR 12 |
| A-08 | S1 Audio | `flood`: gurgle, giggle | built | assets/audio/sfx/flood, float_up, splash_1-2 | PR 12 |
| A-09 | S1 Audio | `elevator`: clang, rattle, ding | built | assets/audio/sfx/elevator, cage_door, elevator_clank, elevator_ding | PR 12 |
| A-10 | S1 Audio | `build_place`, `build_move` | built | assets/audio/sfx/build_place, build_pickup, build_unfold | `build_move` is an alias of `build_pickup` (PR 12) |
| A-11 | S1 Audio | `tree_fall`, `rock_crack` | built | assets/audio/sfx/tree_fall, rock_crack_1-2, stump_pop | PR 12 |
| A-12 | S1 Audio | `gnome_whistle`: whistle, marching feet | built | assets/audio/sfx/whistle_1-3, crew_march, march_step | `gnome_whistle` is an alias of `whistle` (PR 12) |
| A-13 | S1 Audio | `dragon_snore` louder by depth | partial | assets/audio/sfx/dragon_snore_1-2.ogg; tests/test_audio.gd::test_snore_gets_louder_with_depth | Plays and gets louder by depth (PR 12). Not synced with the puff and sway (W-17) |
| A-14 | S1 Audio | Music: sunny up-top theme; the same theme slowed underground with a layer per zone; cavern choir | built | assets/audio/music/music_up.ogg, music_down.ogg, music_down_layer_1-4.wav, music_cavern.ogg; tests/test_audio.gd::test_music_crossfades_up_down_and_cavern, ::test_big_moments_duck_the_music | Up-top theme, slowed underground theme with a layer per zone, cavern track (PR 12) |
| A-15 | S1 Audio | Barks: Mole "oh dear", Foreman mutters, Dragon rumbles, Jeff names rocks, Chuck narrates | partial | assets/audio/voice/*.ogg; tests/test_audio.gd::test_barks_fall_back_to_placeholders_and_are_rate_capped; tests/test_gap_close.gd::test_the_finder_cheers_in_their_own_voice_and_a_voiceless_pick_stays_quiet, ::test_a_workshop_gets_a_cheer_from_each_voiced_player | All five bark hooks fire and are rate-capped (PR 12). Gap-close-1: any picked character with a library voice pack (17 of 21 in v0.5.0) now speaks in play (`VoiceLines`): `win` on finding a treasure, `cheer` on a Workshop and now and then on a build, `join` when a resident arrives. Still placeholders: Jeff, Chuck, the Mole, the Foreman, the Dragon (no library packs) |

## Kid-design checks (S1, on top of docs/kid-design.md)

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| K-01 | S1 | Nothing underground can hurt the player | built | tests/test_hazards_residents.gd (bonk, float, cave-in tests) | |
| K-02 | S1 | The game never refuses a building; a hundred barns is celebrated | built | tests/test_hill_build.gd::test_a_hundred_barns_never_refused, ::test_garages_past_the_ladder_are_still_allowed | You can't afford something → honk, the book stays open (test_cant_afford_honks_and_keeps_book) |
| K-03 | S1 | Buildings move for free | built | tests/test_hill_build.gd::test_pick_up_and_move_is_free | |
| K-04 | S1 | The backpack never hard-stops digging | built | tests/test_hill_game.gd::test_full_backpack_never_stops_digging | |
| K-05 | S1 | Split appears and disappears on its own; no button | built | tests/test_split.gd::test_far_splits_slides_and_joins | |
| K-06 | S1 | Shaft transition under one second and skippable | partial | tests/test_hill_game.gd::test_a_skips_the_wait; tests/test_proto.gd::test_elevator_rides_down_under_a_second_and_rearms_only_after_leaving | Skipping works. The S3 door wait (~1 s) comes before the drop, so a full ride takes more than a second unless A is pressed. Check at the playtest |
| K-07 | S1 | Costs shown as block pictures, never numbers | built | .scratch/shots/book/t008.0s.png | |
| K-08 | S1 | On foot is always available | built | tests/test_hill_game.gd::test_hop_in_drive_and_hop_out | |
| K-09 | S1 | Depth shown as a picture strip of layers, not metres | built | scenes/game/hud.gd; .scratch/shots/reveal/t005.0s.png (marker at the bottom band) | |
| K-10 | S1 | The Dragon is sleepy and friendly from the first frame | built | .scratch/shots/reveal/t005.0s.png | |
| K-11 | S1 | The gnome crew rewards coming back, with a cap | built | tests/test_resident_arcs.gd::test_gnome_village_crew_leaves_a_capped_pile_after_time_away | Capped by Rules.GNOME_CAP; nothing under 30 minutes; a clock set back gives nothing (tests/test_polish.gd) |
| K-12 | S1 | A resident's arrival is funny-sad, never sad | built | tests/test_resident_arcs.gd::test_silhouettes_show_once_met_and_arrival_pleads_in_pictures | Arrivals are on dev (PR 9): hat in hands at the shaft, pleading in picture bubbles. Tone to confirm at the first playtest |
| K-13 | S1 | Residents never block anything; restoring is optional | built | tests/test_hazards_residents.gd::test_residents_have_no_collision_and_keep_to_their_rooms; tests/test_resident_arcs.gd::test_restore_card_only_while_arrived_and_paying_rebuilds_plank_by_plank | Restoring is an optional card; residents never collide |

## Out of scope and open questions

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| X-01 | S1 | Shops and buildings you walk inside | dropped | GAME.md Out of scope ("cut, not deferred") | |
| X-02 | S1 | Gear or stats of any kind | dropped | GAME.md Out of scope | |
| X-03 | S1 | Individual block placement | dropped | GAME.md Out of scope | |
| X-04 | S1 | Enemies | dropped | GAME.md Out of scope | |
| X-05 | S1 | A second hill | later | GAME.md Out of scope ("natural later update") | |
| X-06 | S1 | Strange layers below Strangestone; Edgestone removable to expand | later | data/blocks/strangestone.tres, edgestone.tres (`breakable_from_version = "2.0.0"`) | |
| Q-01 | S1 | Palette: pick one of three | built | S2 D45: palette A baseline | Still unticked in GAME.md |
| Q-02 | S1 | Kaden approves or edits the four resident bibles | missing | none (unticked in GAME.md; no recorded approval) | The art was made before approval was recorded |
| Q-03 | S1 | Real places: no | built | V-10 | |

## Build phases

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| F-0 | S1 | Design sprint: GAME.md, palette, bibles, repo from template | partial | GAME.md; art/direction/palettes.md | Bible approval is open (Q-02) |
| F-1 | S1 | Risk prototypes: chunked grid + edit saves + falling boulders; two SubViewports split (`v0.0.1-dev.1`) | built | tests/test_proto.gd; tests/test_tileworld.gd; tests/test_split.gd | |
| F-2 | S1 | Grey-box: capsules, Loader box, dig, elevator, one barn, beeps | built | tests/test_hill_game.gd; tests/test_hill_build.gd | |
| F-3 | S1 | Parallel build (layers, treasures, hazards, book, vehicles, crew, dragon; art; content; audio; HUD) | partial | rows above | Arcs and audio are on dev (PR 9, PR 12). Biggest gaps now: merging the finished lane branches (see "Gap-close 2026-11-10"), Jeff's and Chuck's voice packs |
| F-4 | S1 | First playable `v0.1.0`: dig to Clay, find the car, Barn + Garage, Excavator, split, saves, sound + visual; **Kaden and his son play it** | partial | tests/test_hill_demo.gd::test_demo_finds_the_car_builds_and_unlocks_the_excavator; .scratch/shots/demo/t018.0s.png | The content passes in the scripted demo. There is no `v0.1.0` tag and no playtest report yet |
| F-5 | S1 | Extract the engine into `openjar-addons` (addons `v0.2.0`) | missing | S-14 | |
| F-6 | S1 | Polish: final art, all vehicles, all buildings, Dragon, music, store art, tuning | partial | V-09, A-14, V-08 | |
| F-7 | S1 | Release `v1.0.0` on the TV main tile | later | | |

## Totals

Counted from the Status column, 192 rows, on `dev` at `8ee8d2d` (2026-11-10) plus M-08 (chooser-catchphrase lane):

| built | partial | missing | superseded | dropped | later | total |
| --- | --- | --- | --- | --- | --- | --- |
| 156 | 21 | 6 | 1 | 4 | 4 | 192 |

Before the plan-sync: 112 built, 47 partial, 22 missing, 2 superseded, 4 dropped, 4 later.

## Plan-sync 2026-11-10

Rows that said "on branch" / "not on dev" were checked against `origin/dev` at `8ee8d2d` (git grep for the
cue, file, data row or function; test names confirmed in `tests/`) and moved: C-03, C-16, C-21, C-24, W-23,
B-08, R-02, R-03, R-04, R-05, R-07, R-08, R-09, K-12, K-13 (resident arcs, PR 9); A-01 to A-12, A-14
(audio pass, PR 12) to built. B-11, R-11, P-06, A-13, A-15 to partial. W-17 stays partial with a new reason.
Only V-03 is still branch work.

## Next up

These are the missing and partial rows, ranked by how much Kaden and his son will notice them in
play. Size: S = under a lane-hour, M = one lane session, L = several sessions or a new system.

1. **First playtest: tag `v0.1.0`, Kaden and his son play it** (F-4; check at the TV: S-07 zoom, W-27 darkness, K-06 ride time, S-13 frame rate; time C-27 and write `data/BALANCE.md`): everything below is a guess until they play. **S**
2. **Workshop** (B-06): a building from Kaden's list is not in the book, with no recorded decision. Build it (bigger shovel, faster vehicles, hammering and sparks) or record it as dropped. **M** (S to drop)
3. **Adjacency hearts** (C-23, C-26): hearts float between buildings that like each other, on every build. Needs `data/adjacency.tres`. **M**
4. **Real voices for the barks** (A-15, P-06): Jeff, Chuck and the residents talk in synth gibberish, heard every few minutes. Waits on the voice packs; the hooks are done. **M**
5. **Slippery ice and sliding into holes** (W-11, W-13, B-11): the Ice layer plays like dirt, so the Dragon Perch's warm-ice payoff can't be felt. **M**
6. **Excavator: cab-only spin and digging ponds** (H-03): his favourite vehicle. Cab spin needs a cab layer from Art. **M**
7. **Crane: fast shaft ride, lifting buildings, wrecking ball** (H-05). **L**
8. **Camera leads the dig, zooms out in big vehicles** (S-06). **M**
9. **Topsoil and depth life: roots, waving worms, sand, snow, frozen fish** (W-03, C-17). **M**
10. **Lava pockets that bounce you** (W-14): Crystal has no hazard. **M**
11. **Pick a layer on the way down** (S-04). **M**
12. **Dragon snore in sync** (W-17, A-13): play the sound on `dragon_snored`, drop hill_audio's second sway. **S**
13. **Loose things fall and props break** (W-19, W-20): treasures, bathtub, the Mole, the car, gnome-room walls. **M**
14. **House: lights checked, Jeff and Chuck sleep there** (B-03). **S**
15. ~~**Store art and `store/jar.glb`** (V-08, S-16)~~: done in store-art-1 (2026-11-10). Version label bug is template-wide and still open. **M**
16. **Final art: crew sheet, approved cow, Workshop; Kaden picks style D or E** (V-09, V-03, F-6). **L**
17. **Underground puzzles: walls a boulder breaks, blocks that need a vehicle** (C-22). **L**
18. **Proof gaps: a test or frame for the Mole's honk, two players driving, exhaust puffs** (R-11, H-09, H-11). **S**
19. **Kaden approves the four resident bibles** (Q-02, F-0). **S** (Kaden's time)
20. **Engine extraction to `openjar-addons`, `PictoBubble`, spend log** (S-14, F-5, S-15, S-17): not seen in play. **L** / **M** / **S**

F-3 and F-6 are roll-ups: they close when the items above do.
