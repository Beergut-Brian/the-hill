# Plan status: The Hill

True on `dev` at `67a461d` (2026-11-10). Lanes: update your rows in the same commit as the work
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

There are no "Playtest ... changes" sections yet (`playtests/` holds only the template).

**How proof was checked (2026-11-10, plan-status lane):** `tests/<file>.gd::<test>` names a gdUnit
test. The full suite ran once on this commit: **238/238 pass**. Frames are real Forward+ renders
from `scripts/tools/shots.sh`, saved in this worktree under `.scratch/shots/` (git-ignored). Each
one was looked at. To remake one, run
`scripts/tools/shots.sh "" 4,8 $PWD/.scratch/shots/<beat> --demo --demo-beat=<beat>`; for `demo`, use
`--demo` with times 6,12,18; for `lobby`, use `--ui=lobby-ready`.

**Branch work that is not on `dev`:** `feature/resident-arcs` (`b6ac092`, Gameplay lane, reported done with 261/261 tests) builds the
residents' arcs: shovel thefts, the walled crew, arrivals, restore cards, the Museum, Lost & Found, the Gnome Village and the Dragon Perch.
`feature/art-direction-options-2` has the round-2 art styles D and E. Rows that only exist there
say "on branch" and stay `missing` / `partial` until they merge.

ID prefixes: C core loop, W underground world, T Hillville, B buildings, R residents,
H vehicles, P players, S systems/camera/tech, M menus, V visuals, A audio, K kid-design,
X out of scope, Q open questions, F build phases.

## Core loop and Kaden's north-star notes

| ID | Source | Item (short, Kaden's words where possible) | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| C-01 | S1 Notes | "Dig & build sandbox: two players dig down, find treasure, build up" | built | tests/test_hill_demo.gd::test_demo_finds_the_car_builds_and_unlocks_the_excavator; .scratch/shots/demo/t018.0s.png | |
| C-02 | S1 Notes | "Chunked world" | built | tests/test_tileworld.gd::test_chunks_load_and_free | |
| C-03 | S1 Notes | "Soft goal: the hill has a bottom, and something is down there" | partial | tests/test_hazards_residents.gd::test_the_dragon_reveal_plays_once_and_it_saves; .scratch/shots/reveal/t005.0s.png | The Dragon sleeps at the bottom and her first meeting plays. Waking her, bringing her up and the Perch are only on a branch (W-25, B-12) |
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
| C-16 | S1 Loop | Treasures unlock one specific thing each (car → Garage, Gnome Room → Gnome Village) | partial | tests/test_vehicles_treasures.gd::test_each_garage_gives_the_next_vehicle_and_the_drill_garage_waits_for_the_tooth | The car and the tooth unlock things. The Gnome Room → Village link is only on a branch |
| C-17 | S1 Loop | Blocks by depth: dirt, clay, stone, sand, ice, crystal | partial | data/blocks/*.tres | There is **no sand block**. The minor kinds have no tiles of their own: roots, pebbles, pipes, ore, geodes, snow, frozen fish |
| C-18 | S1 Loop | Deeper blocks are worth more; some buildings need a specific kind | built | data/buildings/garage.tres (clay+stone), data/buildings/lighthouse.tres (stone+crystal) | |
| C-19 | S1 Loop | No fail state: nothing underground hurts; town can't be damaged | built | tests/test_hazards_residents.gd::test_a_falling_boulder_bonks_briefly_and_takes_nothing, ::test_a_breached_pocket_floats_the_player_and_takes_nothing | |
| C-20 | S1 Loop | Session 10–20 min, saves at every trip up | built | scenes/game/elevator.gd (every ride autosaves); tests/test_hill_game.gd::test_save_round_trip | Session length is unmeasured until the first playtest |
| C-21 | S1 Two depths | Logistics: backpack, Dump Truck and gnome crew are real hauling limits | partial | tests/test_hill_game.gd::test_backpack_fills_and_capacity_follows_barns; tests/test_vehicles_treasures.gd::test_dump_truck_carries_five_backpacks_and_tips_the_whole_load_onto_the_pile | The gnome crew does not haul (C-13) |
| C-22 | S1 Two depths | Underground engineering: drain or redirect water, drop a boulder to break a wall, route around blocks that need a vehicle | partial | tests/test_tileworld.gd::test_water_pile_levels_out_then_goes_still; tests/test_proto.gd::test_boulder_sleeps_then_falls_when_undercut | Water and falling boulders work. There are no walls a boulder breaks and no blocks that need a vehicle, so no puzzle is placed yet |
| C-23 | S1 Two depths | Town adjacency: hearts float between buildings that like each other (`data/adjacency.tres`) | missing | none (no data/adjacency.tres; no hearts code) | Barns+Village, Tower+pond, Lighthouse on peak, Museum+shaft |
| C-24 | S1 Two depths | Collection: the Museum shows treasures left per layer; the Mole's glow finds them; Strangestone is a curious wall | partial | tests/test_vehicles_treasures.gd::test_a_pickup_pops_up_flies_into_the_bag_and_lands_on_the_shelf; .scratch/shots/shelf/t008.0s.png | The Treasure Shelf (S7) shows silhouettes per layer. The Museum and the Mole's glow are only on a branch |
| C-25 | S1 Guardrails | No text, numbers or tooltips for the adult layer | built | scenes/game/hud.gd ("no numbers and no text"); .scratch/shots/book/t008.0s.png | |
| C-26 | S1 Guardrails | Tuning lives in data: adjacency, `BuildingData.needs_blocks`, `LayerData.hazards` | partial | data/hazards/*.tres; data/buildings/*.tres `cost` | Hazards became a `HazardData` row type (S6). Block needs are the `cost` dictionary. Adjacency is missing |
| C-27 | S1 Data | `data/BALANCE.md`: Buried Car in 5 min, Excavator by 15 min, bottom in 3–4 h | missing | none (no data/BALANCE.md) | The demo reaches the Excavator, but nobody has timed real play |

## Underground

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| W-01 | S1 Underground | ~200 x 300 tiles at 16 px, every tile diggable | built | tests/test_data.gd::test_layers_tile_0_to_300; tests/test_tileworld.gd::test_save_is_edit_only_and_round_trips | |
| W-02 | S1 Underground | Six layers with a dominant hue each (Topsoil, Clay, Stone, Ice, Crystal, Bottom) | built | data/layers/*.tres; .scratch/shots/rescue/t005.0s.png, crystal/t005.0s.png, reveal/t005.0s.png | |
| W-03 | S1 Topsoil | Dirt, roots, worms that wave | partial | data/blocks/dirt.tres | No roots and no waving worms |
| W-04 | S1 Topsoil | Treasures: bottle caps, a boot, a bike | built | data/treasures/{bottle_caps,boot,bike}.tres; tests/test_vehicles_treasures.gd::test_every_layer_but_the_bottom_has_treasures_placed_in_it | |
| W-05 | S1 Clay | Treasures: buried car, bathtub, fossils | built | data/treasures/{buried_car,bathtub,fossil}.tres; tests/test_hill_game.gd::test_buried_car_in_clay_found_by_digging_next_to_it | |
| W-06 | S1 Clay | Water pockets flood and float you up | built | tests/test_hazards_residents.gd::test_a_breached_pocket_floats_the_player_and_takes_nothing | |
| W-07 | S1 Clay | Dim; headlamp | built | tests/test_hazards_residents.gd::test_darkness_values_load_from_data; .scratch/shots/rescue/t005.0s.png | |
| W-08 | S1 Stone | Gnome Room, giant tooth, dinosaur skeleton | built | data/treasures/{gnome_room,giant_tooth,dino_skeleton}.tres | |
| W-09 | S1 Stone | Rolling boulders: bonk, stars, fine | built | tests/test_hazards_residents.gd::test_a_falling_boulder_bonks_briefly_and_takes_nothing | |
| W-10 | S1 Stone | Dark; needs the Lighthouse | built | tests/test_polish.gd::test_a_lighthouse_lights_stone_and_each_more_lights_the_next_layer_down; handoff/frames/lighthouse_before_dark_stone.png, lighthouse_lit_stone.png | Dark until the first Lighthouse (B-07) |
| W-11 | S1 Ice | Ice (slippery), snow, frozen fish | partial | data/blocks/ice.tres (`slippery = true`) | No code reads `slippery`. There is no snow and no frozen fish |
| W-12 | S1 Ice | A frozen caveman who wakes and waves; a pirate chest | built | tests/test_hazards_residents.gd::test_the_caveman_thaws_once_and_it_saves; data/treasures/pirate_chest.tres | |
| W-13 | S1 Ice | Hazard: slide into holes | missing | none | Needs slippery ice first (W-11) |
| W-14 | S1 Crystal | Crystal is worth the most; lava pockets bounce you, no damage | partial | data/blocks/crystal.tres | There are no lava pockets (only the data fields) |
| W-15 | S1 Crystal | The Dragon Egg; self-lit | built | data/treasures/dragon_egg.tres; .scratch/shots/crystal/t005.0s.png | |
| W-16 | S1 Bottom | Huge cavern; the Dragon asleep around the last treasure; warm | built | .scratch/shots/reveal/t005.0s.png | |
| W-17 | S1 Bottom / Audio | Her snore shakes the screen; louder by depth | partial | tests/test_polish.gd::test_the_dragon_snore_sways_the_cavern_and_not_topsoil; handoff/frames/dragon_snore_puff.png | Polish-2: while she sleeps, every 5 s a smoke puff and a gentle sway (2 px in the cavern, fainter up through Crystal, none above); signal `dragon_snored(loudness)`. The periodic snore **sound** waits on audio: `dragon_snore` is not in CUES.md on dev, and feature/audio-pass has its own `_shake` in hill_audio.gd: on merge it should play on `dragon_snored` and drop its shake |
| W-18 | S1 Underground | Directional digging: 1 tile shovel, 3-wide Excavator, 5-wide Drill Rig | built | data/vehicles/*.tres `dig_shape`; tests/test_hill_game.gd::test_vehicle_dig_fits_its_body | |
| W-19 | S1 Underground | Loose things fall: boulders, treasures, bathtub, the Mole | partial | tests/test_tileworld.gd::test_falling_body_wake_rules | Only boulders fall. Treasures are pickups or stay put (S7), and the Mole doesn't fall |
| W-20 | S1 Underground | Props break into chunks when dug under (car, gnome-room walls) | partial | tests/test_tileworld.gd::test_breakable_prop_breaks_when_undercut | The engine can do it, but the car stays where it lies (S7) and no gnome-room walls break |
| W-21 | S1 Underground | Tunnels persist; only edits are saved | built | tests/test_tileworld.gd::test_save_is_edit_only_and_round_trips | |
| W-22 | S1 Underground | Light is a soft gate: you can dig in the dark but can't see the sparkle | built | tests/test_polish.gd::test_a_lighthouse_lights_stone_and_each_more_lights_the_next_layer_down; handoff/frames/lighthouse_lit_stone.png | Lighthouses lift the darkness one layer each from Stone down; Topsoil and Clay stay headlamp layers |
| W-23 | S1 Underground | Bottom reveal: Dragon yawns, hill shakes, asks to come up, elevator carries her up in pieces, she coils on the peak | partial | tests/test_hazards_residents.gd::test_the_dragon_reveal_plays_once_and_it_saves | Only the first meeting is on dev (stir, yawn, smoke rings, back to sleep; S6). The wake, the climb and the peak are on a branch |
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
| T-08 | S7 | Treasure Shelf right of the Caveman's fire: one board per layer, silhouettes for what's left | built | .scratch/shots/shelf/t008.0s.png | When the Museum lands, the shelf should move inside it (on branch) |

## Buildings

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| B-01 | S1 | Barn, 10 dirt: +1 backpack per barn, no cap | built | tests/test_hill_game.gd::test_backpack_fills_and_capacity_follows_barns | |
| B-02 | S1 | Barn: cows wander out; more barns, more cows | built | tests/test_polish.gd::test_every_barn_has_a_cow_in_its_yard_and_a_new_one_trots_out, ::test_a_hundred_barns_is_a_hundred_cows, ::test_walking_into_a_cow_makes_her_hop; handoff/frames/cows_*.png | Polish-2: scripts/gameplay/barn_cows.gd. **Placeholder cow drawn in code**: the library cow is only a proposal (openjar-characters `feature/quadruped-cow`, name open as D53), not approved for play. TODO(audio): `cow_moo` is not in CUES.md |
| B-03 | S1 | House, 15 dirt + 5 clay: lights at dusk; Jeff and Chuck sleep here | partial | data/buildings/house.tres; assets/sprites/buildings/house_lit.png | building.gd swaps in the lit sprite at night (not checked in a frame with a House). Nobody sleeps there |
| B-04 | S1 | Garage, 20 clay + 10 stone, needs the Buried Car; each opens the next vehicle | built | tests/test_hill_build.gd::test_garage_unlocks_excavator_then_still_allowed; tests/test_vehicles_treasures.gd::test_each_garage_gives_the_next_vehicle_and_the_drill_garage_waits_for_the_tooth | |
| B-05 | S1 / S7 | Vehicles park at their Garage; a Garage built early waits with its door shut | built | tests/test_vehicles_treasures.gd::test_vehicles_treasures_buildings_survive_a_reload | |
| B-06 | S1 | **Workshop**, 15 stone: bigger shovel, faster vehicles; hammering and sparks | missing | none (no data row; not in the book: .scratch/shots/book/t008.0s.png) | Dropped without a recorded decision; see REPORT |
| B-07 | S1 | Lighthouse, 20 stone + 5 crystal: lights the next layer down per one built; sweeping beam at night | built | tests/test_polish.gd::test_a_lighthouse_lights_stone_and_each_more_lights_the_next_layer_down, ::test_a_saved_lighthouse_lights_stone_after_a_reload, ::test_building_a_lighthouse_flares_its_lamp; handoff/frames/lighthouse_*.png (polish-2) | Polish-2: the first Lighthouse lights Stone, each more lights the next layer down (UndergroundLook "lit layers": darkness x0.22, warm tint, 1.2 s fade, a lantern and sweeping beam at the lit landing). Up top the lamp flares and shines down when placed, and sweeps the sky at night (scenes/buildings/lighthouse_beam.gd). TODO(audio): a `lighthouse_on` cue for the light-up moment is not in CUES.md |
| B-08 | S1 | Museum: restore the Flooded Cabin; shows every treasure and how many are left per layer | missing | data/buildings/flooded_cabin.tres (ruin row only) | On branch. The Treasure Shelf (T-08) stands in |
| B-09 | S1 | Gnome Village: restore the Crooked Watchtower; the crew digs 20–50 blocks while the game is closed, up to a cap | built | tests/test_resident_arcs.gd::test_gnome_village_crew_leaves_a_capped_pile_after_time_away; handoff/frames/crew_overnight_march.png | Merged with resident-arcs (b9966b0); checked by polish-2 |
| B-10 | S1 | Water Tower, 15 stone + 10 ice: drains floods faster; generic look | built | tests/test_vehicles_treasures.gd::test_water_tower_drains_flooded_tunnels_near_a_player; .scratch/shots/shelf/t008.0s.png | S7 gates it behind the Crane |
| B-11 | S1 | Dragon Perch: restore the Ruined Keep; she warms the Ice layer so it's not slippery | missing | data/buildings/ruined_keep.tres (ruin row only) | On branch. Ice isn't slippery yet anyway (W-11) |
| B-12 | S1 | Gnome crew comeback clip: pile at the shaft, gnomes march out with a whistle | built | tests/test_resident_arcs.gd::test_the_crew_award_runs_on_load_from_the_saved_stamp; handoff/frames/crew_overnight_march.png | Five gnomes march out of the shaft to the pile with a block each (scripts/gameplay/ruin_sites.gd `_draw_clip`); cues `whistle`, `crew_march` |
| B-13 | S1 Art | Buildings are multi-tile sprites with a 3-frame unfold | built | tests/test_art_sprites.gd::test_building_art_and_garage_door_frames | |

## Residents: the ruins

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| R-01 | S1 | Four ruins (Old Shed, Crooked Watchtower, Flooded Cabin, Ruined Keep): can't be cleared or built on | built | tests/test_hill_build.gd::test_ruins_cannot_be_picked_up, ::test_ruins_shaft_and_yard_have_no_scrub | |
| R-02 | S1 | Three beats (Encounter, Arrival hat-in-hands at the shaft, Fix-up via a restore card), all in picture bubbles | missing | tests/test_data.gd::test_can_restore_truth_table (rule only) | On branch `feature/resident-arcs` |
| R-03 | S1 | The Mole steals your shovel, pops up elsewhere, apologises; 3 times, then he comes up | missing | tests/test_data.gd::test_mole_arrives_on_third_encounter (rule only) | On branch |
| R-04 | S1 | Lost & Found: tiles near treasure glow when he's near; "found" items at the shed door; he brings things underground | missing | data/buildings/old_shed.tres | On branch |
| R-05 | S1 | Foreman's crew found walled into the Gnome Room | superseded | S6: the crew stands up top from the start; the Foreman whistles at the Gnome Room | The walled-crew arc is on a branch |
| R-06 | S1 / S6 | Caveman thaws (headlamp, 3 s), waves, follows you up and waits by a campfire | built | tests/test_hazards_residents.gd::test_the_caveman_thaws_once_and_it_saves | S6: thaw by headlamp only; digging the block out and carrying it up comes later |
| R-07 | S1 | Ruins show the future resident's silhouette on the door once met | partial | scenes/levels/hillville.gd `show_silhouette()` | Nothing on dev calls it |
| R-08 | S1 | Restoring is optional, never times out; the resident waits at the shaft | partial | tests/test_hazards_residents.gd::test_the_caveman_thaws_once_and_it_saves | The Caveman waits. Restoring is on a branch |
| R-09 | S1 | Residents wander, react to buildings, idle gags (Mole falls in pond, Caveman baffled by the Dump Truck, Foreman inspects barns) | partial | tests/test_hazards_residents.gd::test_the_crew_cheers_at_a_delivery_and_marches_past_a_new_building | Crew marches and cheers; the Caveman hoots. The named gags are missing |
| R-10 | S1 | Each resident bible gets a "redemption arc" section | built | ~/openjar/openjar-characters/characters/{mole,gnome_foreman,caveman,dragon}/bible.md | |
| R-11 | S1 | The Mole occasionally sits in an empty vehicle and honks | missing | none | |
| R-12 | S6 | Mole rescues trapped players (dives, pops up, digs, hearts) | built | tests/test_hazards_residents.gd::test_digging_into_a_cave_in_traps_then_the_mole_frees_in_time; .scratch/shots/rescue/t005.0s.png | |
| R-13 | S6 | Crew cheers a delivery of 3+ blocks; Foreman holds up the build book | built | tests/test_hazards_residents.gd::test_the_crew_cheers_at_a_delivery_and_marches_past_a_new_building | The crew uses the Foreman's sprite, tinted, until a crew sheet exists |
| R-14 | S6 | Dragon's first meeting: stir, yawn, 3 smoke rings, purr, back to sleep; once per save, never fire | built | tests/test_hazards_residents.gd::test_the_dragon_reveal_plays_once_and_it_saves; .scratch/shots/reveal/t005.0s.png | |
| R-15 | S6 | Residents have no collision and keep to their rooms | built | tests/test_hazards_residents.gd::test_residents_have_no_collision_and_keep_to_their_rooms | |

## Vehicles

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| H-01 | S1 | Five vehicles, unlocked one per Garage | built | tests/test_vehicles_treasures.gd::test_ladder_is_five_vehicles_with_their_own_abilities_and_faceless_art; .scratch/shots/lineup/t008.0s.png | |
| H-02 | S1 | Front Loader: clears 1-tile scrub, carries a ghost, scoops 1 tile; horn, bucket tilt | built | tests/test_hill_game.gd::test_up_top_a_scoops_scrub_x_opens_the_book_y_honks | |
| H-03 | S1 | Excavator: clears 3x2, digs ponds; digs 3-wide; arm waves, cab spins all the way round | partial | data/vehicles/excavator.tres; tests/test_hill_game.gd::test_garage_rolls_out_a_parked_excavator | Dig and clear work. No pond digging and no full cab spin |
| H-04 | S1 / S7 | Dump Truck: hauls the pile, best tip animation, 5x backpack, tips into the elevator, reverse beep | built | tests/test_vehicles_treasures.gd::test_dump_truck_carries_five_backpacks_and_tips_the_whole_load_onto_the_pile, ::test_dump_truck_reverses_with_a_beep_before_it_turns_round | |
| H-05 | S1 / S7 | Crane: places tall buildings, lifts/moves placed buildings, lowers you down the shaft fast, hauls boulders, wrecking ball for stumps | partial | tests/test_vehicles_treasures.gd::test_crane_hooks_a_boulder_out_for_good_and_it_stays_gone_after_a_reload | Tall-building gate and boulder haul work. The fast shaft ride is "not done" (S7). No lifting buildings and no wrecking ball |
| H-06 | S1 / S7 | Drill Rig: 5-wide straight down on its own; parks by the shaft; shakes the screen | built | tests/test_vehicles_treasures.gd::test_drill_rig_drills_five_wide_straight_down_on_its_own_until_told_to_stop | Gentle rumble only when Settings allows shake |
| H-07 | S1 | Vehicles are `.tres` data (dig shape, speed, carry, clear area, sounds, unlock) | built | data/vehicles/*.tres; tests/test_data.gd::test_every_row_loads_with_class_and_id | |
| H-08 | S1 | Hop in/out with one button; on foot is always an option | built | tests/test_hill_game.gd::test_hop_in_drive_and_hop_out | |
| H-09 | S1 | Both players can drive different vehicles at once | partial | none found | Nothing in the code stops it, but no test or frame shows it |
| H-10 | S1 Art / S2 | Vehicles big, round, friendly; **no eyes or faces** (D45 supersedes "faces in the headlights") | built | tests/test_vehicles_treasures.gd::test_ladder_is_five_vehicles_with_their_own_abilities_and_faceless_art; .scratch/shots/lineup/t008.0s.png | |
| H-11 | S1 Art | Two-frame idle wobble, exhaust puffs, player's stripe when driven | partial | .scratch/shots/demo/t018.0s.png (green stripe on the Loader) | The frames show the stripe and the bob. Exhaust puffs aren't confirmed |
| H-12 | S1 | v1.1 vehicle pack: Bulldozer, Cement Mixer, Steamroller, Paver, Tunneler (+ roads) | later | GAME.md Vehicles, "v1.1 vehicle pack" | Garages 5–9 |

## Players

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| P-01 | S1 | Jeff P1 green, Chuck P2 red, in hard hats | built | tests/test_hill_chooser.gd::test_defaults_are_jeff_and_chuck_on_their_own_sheets; .scratch/shots/lobby/t003.0s.png | |
| P-02 | S1 | Jeff and Chuck are "player-locked" | superseded | S5: any roster character can be picked; Jeff and Chuck are the defaults | The GAME.md cast table still says "player-locked" |
| P-03 | S5 | Plays whoever was picked; other characters get a sheet built at runtime | built | tests/test_hill_chooser.gd::test_a_pixel_form_only_character_gets_a_built_sheet, ::test_swapped_picks_swap_the_bodies | |
| P-04 | S1 | Drop-in: P2 asleep in the Loader's bucket; a button press tips him out | built | tests/test_hill_game.gd::test_p2_sleeps_in_the_bucket_then_drops_in_and_plays | |
| P-05 | S2 | The library gains a 2D pixel format for Jeff, Chuck and the four residents | built | assets/sprites/characters/{jeff,chuck,mole,foreman,caveman,dragon}.png | |
| P-06 | S1 | Personalities: Jeff names every rock; Chuck narrates his driving | missing | none | No voice barks (S5). On branch `feature/audio-pass` (6141537), **not on dev** at 76db260 (checked 2026-11-10, polish-2): hill_audio.gd `_on_tile_dug` (placeholder voices) → would be partial |

## Systems, camera, tech

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| S-01 | S1 Camera | Dynamic split table (both close = one camera … one up/one down = split … solo = full screen) | built | tests/test_split.gd::test_table_* (6 tests) | |
| S-02 | S1 Camera | Split slides in and out with a soft whoosh; player-coloured divider | built | tests/test_split.gd::test_far_splits_slides_and_joins; .scratch/shots/demo/t018.0s.png | |
| S-03 | S1 / S3 | Shaft: cage closes, half-second drop with a rattle; the door waits ~1 s so both can ride (S3) | built | tests/test_hill_game.gd::test_door_waits_then_closes, ::test_everyone_in_the_cage_rides_together, ::test_a_skips_the_wait | |
| S-04 | S1 Camera | Land at your deepest layer, or pick a layer on the way down (up/down, pictures) | partial | tests/test_hill_game.gd::test_down_lands_at_the_deepest_rider_layer_up_goes_to_hillville | You can't pick a layer |
| S-05 | S1 Controls | A dig, B jump/hop, X build book, Y horn, Start pause | built | tests/test_hill_game.gd::test_up_top_a_scoops_scrub_x_opens_the_book_y_honks | |
| S-06 | S1 Controls | Underground camera leads in the dig direction; zooms out a little in bigger vehicles | missing | none (no lead or zoom-out in addons/openjar/split_screen/screen_director.gd) | |
| S-07 | S3 | Camera zoom 2.0; check on the TV, likely 3.0 | partial | scenes/game/hill_game.gd (`director.zoom = 2.0`) | Waiting for the TV check |
| S-08 | S3 | Water conserved; breached pockets gush ~2 s | built | tests/test_hill_game.gd::test_breached_pocket_gushes_for_about_two_seconds | |
| S-09 | S1 Tech | Save: edits, treasures, inventory, buildings, vehicles, deepest layer, last scene, crew timestamp, `ResidentState`; autosave every ride and every 60 s | built | tests/test_hill_game.gd::test_save_round_trip; tests/test_data.gd::test_resident_save_round_trip_through_json; scenes/game/hill_save.gd (`AUTOSAVE_EVERY := 60.0`) tests/test_polish.gd::test_every_save_stamps_the_time_and_a_clock_set_back_gives_nothing | `gnome_stamp` is written on every save (scenes/game/hill_save.gd, resident-arcs merge) |
| S-10 | S1 Tech | Game contracts (signals, `Inventory.can_afford`, `World.dig`) in docs/contracts.md | built | docs/contracts.md; tests/test_inventory.gd::test_can_afford | Nothing on dev emits `ruin_restored` or `dragon_woken` yet |
| S-11 | S1 / S2 | Tile world and split director are game-agnostic; Worm's polar disk is a swap | built | tests/test_tileworld.gd::test_polar_body_falls_toward_core, ::test_chunk_manager_knows_no_concrete_shape | |
| S-12 | S1 Tech | Awake `RigidBody2D` cap 60; 9 chunks per player | built | tests/test_tileworld.gd::test_awake_cap_queues_wakes, ::test_chunk_budget_limits_new_chunks_per_call | |
| S-13 | CLAUDE.md / S1 | 60 fps at 1080p on a GTX 1060 | partial | addons/openjar/tileworld/demo (stress run) | The sim cost has been measured. Frame rate on a real GPU hasn't (the producer box renders in software) |
| S-14 | S1 Tech / F-5 | Move tile world + split screen into `openjar-addons`, tagged | missing | ~/openjar/openjar-addons/addons/openjar has no tileworld or split_screen | Both still live in this repo's `addons/openjar/` |
| S-15 | S1 Tech | `PictoBubble` scene for arcs, costs and prompts, then moved to `openjar-addons/ui/` | missing | none (no PictoBubble class; bubbles drawn in build_book.gd / town_residents.gd) | |
| S-16 | S2 | Template features: grown-up menus, solo, `--demo`, `--shots=`, release smoke-boot, `store/jar.glb` | partial | tests/test_lobby.gd::test_saved_solo_stays_off_at_boot; tests/test_hill_demo.gd; .scratch/shots/lobby/t003.0s.png | There is no `store/` folder, so no `jar.glb`. The lobby version label reads v0.0.1, not the tag (template-wide bug) |
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

## Visuals

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| V-01 | S1 / S2 D45 | Palette A "Sandbox" is the baseline | built | art/direction/palettes.md; .scratch/shots/lineup/t008.0s.png | |
| V-02 | S1 / S2 D45 | Day/night cycle as a palette shift (day, dusk, night); lights come on | built | tests/test_time_of_day.gd::test_phases; .scratch/shots/night/t008.0s.png | |
| V-03 | S2 D45 | Round-2 art direction: two distinct styles, one Terraria-leaning, before final art | partial | art/prompts/styles-d-e.md | D (Terraria) and E (picture book) are mocked on `feature/art-direction-options-2`, waiting for Kaden's pick |
| V-04 | S1 Art | 16 px tiles, 32 px characters, nearest-neighbour, whole-pixel zoom | built | art/direction/pixel-rules.md; tests/test_art_sprites.gd::test_sheet_frames_come_from_the_manifest | |
| V-05 | S1 Art | Distinct block colours: dirt brown, clay orange, stone grey-blue, ice pale blue, crystal purple | built | .scratch/shots/crystal/t005.0s.png, rescue/t005.0s.png | |
| V-06 | S1 Art | Treasures sparkle through the dirt from two tiles away | built | .scratch/shots/rescue/t005.0s.png (car and chest sparkle) | |
| V-07 | S1 Art | Juice: dig particles in block colour, shake on big scoops/falls, dust when a building lands, sparkle burst and ding | built | tests/test_polish.gd::test_a_big_scoop_kicks_and_a_loader_scoop_does_not, ::test_a_boulder_landing_near_kicks_and_far_does_not, ::test_kicks_are_small_short_and_off_with_screen_shake_off; handoff/frames/excavator_big_scoop.png | Polish-2: scripts/gameplay/screen_kick.gd. A scoop of 3+ tiles (Excavator, Crane, Drill) kicks 2-3 px for 0.22 s; a boulder landing within 14 tiles kicks up to 3.5 px for 0.25 s. Capped at 4 px / 0.9 s; Settings screen shake off = none. A still frame cannot show a shake |
| V-08 | S1 Art / F-6 | Store art: grid (Excavator mid-scoop, fossil flying, Chuck drives, Jeff cheers), hero (Hillville at dusk, Dragon on the peak) | missing | none (no store/ folder) | |
| V-09 | S1 / F-6 | Final pixel art for everything | partial | assets/sprites/manifest.json | Sandbox art covers everything on dev. Missing: a gnome crew sheet, final cows (polish-2 draws a placeholder cow in code), the Workshop, restored ruins (on branch) |
| V-10 | S2 / Q-3 | No real places: generic landmarks only | built | .scratch/shots/shelf/t008.0s.png (generic water tower) | |

## Audio

All cues below fire in code. With `assets/audio/sfx/` and `assets/audio/music/` empty, every
one plays the **synth placeholder beep** (tests/test_proto.gd::test_audio_synth_beep_for_missing_cues).

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| A-01 | CLAUDE.md | Sound on every action | partial | tests/test_proto.gd::test_audio_synth_beep_for_missing_cues | Every action makes a sound, but they are all placeholder beeps. On branch `feature/audio-pass` (6141537), **not on dev** at 76db260 (checked 2026-11-10, polish-2): tests/test_audio.gd::test_every_cue_resolves_to_a_file |
| A-02 | S1 Audio | `dig_<block>`: crumble, squelch, crack, crunch, chime | partial | scenes/levels/underground.gd (`Audio.play(cue)` per block) | synth only. On branch `feature/audio-pass` (6141537), **not on dev** at 76db260 (checked 2026-11-10, polish-2): assets/audio/sfx/dig_*.ogg; ::test_variants_rotate_without_repeats |
| A-03 | S1 Audio | `scoop`, `tip`: hydraulic whine, rattle | partial | cues `scoop`, `bucket_tip` | synth only. On branch `feature/audio-pass` (6141537), **not on dev** at 76db260 (checked 2026-11-10, polish-2): sfx/scoop_1-2, bucket_tip, dump_truck_tip |
| A-04 | S1 Audio | `engine_<vehicle>`: looped, pitched by speed, one per vehicle | missing | none (no engine cue in code) | On branch `feature/audio-pass` (6141537), **not on dev** at 76db260 (checked 2026-11-10, polish-2): sfx/*_engine.wav; ::test_engine_pitch_follows_speed |
| A-05 | S1 Audio | `horn_<vehicle>`: one per vehicle; Dump Truck reverse beep | partial | cue `horn`; tests/test_vehicles_treasures.gd::test_dump_truck_reverses_with_a_beep_before_it_turns_round | One horn for all vehicles; synth only. On branch `feature/audio-pass` (6141537), **not on dev** at 76db260 (checked 2026-11-10, polish-2): sfx/*_horn.ogg, dump_truck_reverse.ogg; ::test_every_vehicle_has_its_own_engine_and_horn |
| A-06 | S1 Audio | `treasure`: sparkle and ding, bigger for rarer | partial | cues `treasure`, `treasure_reveal`, `treasure_pickup` | synth only; not by rarity. On branch `feature/audio-pass` (6141537), **not on dev** at 76db260 (checked 2026-11-10, polish-2): HillAudio.treasure_cue; ::test_treasures_get_bigger_with_depth |
| A-07 | S1 Audio | `fall`, `bonk` | partial | cues `fall`, `bonk` | synth only. On branch `feature/audio-pass` (6141537), **not on dev** at 76db260 (checked 2026-11-10, polish-2): sfx/fall_1-3, bonk_1-2 |
| A-08 | S1 Audio | `flood`: gurgle, giggle | partial | cues `flood`, `splash`, `float_up` | synth only. On branch `feature/audio-pass` (6141537), **not on dev** at 76db260 (checked 2026-11-10, polish-2): sfx/flood, float_up, splash_1-2 |
| A-09 | S1 Audio | `elevator`: clang, rattle, ding | partial | cues `elevator`, `cage_door` | synth only. On branch `feature/audio-pass` (6141537), **not on dev** at 76db260 (checked 2026-11-10, polish-2): sfx/elevator, cage_door, elevator_clank, elevator_ding |
| A-10 | S1 Audio | `build_place`, `build_move` | partial | cues `build_place`, `build_unfold`, `build_pickup` | synth only. On branch `feature/audio-pass` (6141537), **not on dev** at 76db260 (checked 2026-11-10, polish-2): sfx/build_place, build_pickup, build_unfold |
| A-11 | S1 Audio | `tree_fall`, `rock_crack` | partial | cues `tree_fall`, `rock_crack`, `stump_pop` | synth only. On branch `feature/audio-pass` (6141537), **not on dev** at 76db260 (checked 2026-11-10, polish-2): sfx/tree_fall, rock_crack_1-2, stump_pop |
| A-12 | S1 Audio | `gnome_whistle`: whistle, marching feet | partial | cues `whistle`, `crew_march` | synth only. On branch `feature/audio-pass` (6141537), **not on dev** at 76db260 (checked 2026-11-10, polish-2): sfx/whistle_1-3, crew_march, march_step |
| A-13 | S1 Audio | `dragon_snore` louder by depth | partial | cue `dragon_snore` | synth only; no volume by depth (W-17). On branch `feature/audio-pass` (6141537), **not on dev** at 76db260 (checked 2026-11-10, polish-2): hill_audio.gd `_snore`; ::test_snore_gets_louder_with_depth |
| A-14 | S1 Audio | Music: sunny up-top theme; the same theme slowed underground with a layer per zone; cavern choir | missing | assets/audio/music/ is empty | On branch `feature/audio-pass` (6141537), **not on dev** at 76db260 (checked 2026-11-10, polish-2): assets/audio/music/*; ::test_music_crossfades_up_down_and_cavern |
| A-15 | S1 Audio | Barks: Mole "oh dear", Foreman mutters, Dragon rumbles, Jeff names rocks, Chuck narrates | missing | none | On branch `feature/audio-pass` (6141537), **not on dev** at 76db260 (checked 2026-11-10, polish-2): bark hooks + rate caps (placeholder voices) → would be partial |

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
| K-12 | S1 | A resident's arrival is funny-sad, never sad | missing | none on dev | The arrivals are on a branch |
| K-13 | S1 | Residents never block anything; restoring is optional | partial | tests/test_hazards_residents.gd::test_residents_have_no_collision_and_keep_to_their_rooms | Restoring is on a branch |

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
| F-3 | S1 | Parallel build (layers, treasures, hazards, book, vehicles, crew, dragon; art; content; audio; HUD) | partial | rows above | Audio and the crew/arcs are the biggest gaps |
| F-4 | S1 | First playable `v0.1.0`: dig to Clay, find the car, Barn + Garage, Excavator, split, saves, sound + visual; **Kaden and his son play it** | partial | tests/test_hill_demo.gd::test_demo_finds_the_car_builds_and_unlocks_the_excavator; .scratch/shots/demo/t018.0s.png | The content passes in the scripted demo. There is no `v0.1.0` tag and no playtest report yet |
| F-5 | S1 | Extract the engine into `openjar-addons` (addons `v0.2.0`) | missing | S-14 | |
| F-6 | S1 | Polish: final art, all vehicles, all buildings, Dragon, music, store art, tuning | partial | V-09, A-14, V-08 | |
| F-7 | S1 | Release `v1.0.0` on the TV main tile | later | | |

## Next up

These are the missing and partial rows, ranked by how much Kaden and his son will notice them in
play. Size: S = under a lane-hour, M = one lane session, L = several sessions or a new system.

1. **Merge `feature/resident-arcs`** (R-02, R-03, R-04, R-07, R-08, B-08, B-09, B-11, K-12, K-13, W-23, C-16): the four ruins are on screen but do nothing on dev. Review it and merge it after `vehicles-treasures`. **S** (review and merge) — the work is done
2. **Real sound and music** (A-01 to A-15): every sound is a placeholder beep and there is no music. This is what you hear in every second of play. **L**
3. **Lighthouse lights a layer** (B-07, W-10, W-22): Stone is dark and the building the plan uses to fix that does nothing. **S** **Done on `feature/hill-polish-2`**.
4. **Engine loops and one horn per vehicle** (A-04, A-05): his favourite part is the vehicles. **M** (part of 2)
5. **Cows from barns** (B-02): "more barns, more cows" is the payoff for a hundred barns. **S** **Done on `feature/hill-polish-2`**.
6. **Gnome crew overnight pile and march clip** (C-13, B-12, K-11, S-09 timestamp): the come-back-tomorrow hook. The rule exists and only needs wiring. **M** **Done on `feature/hill-polish-2`** (wired by resident-arcs, checked and framed).
7. **Workshop** (B-06): a whole building is missing, with no recorded decision. Decide: build it (bigger shovel, faster vehicles) or record it as dropped. **M** (S to drop)
8. **Juice: screen shake on big scoops and falls, Strangestone ? bubble, snore shake** (V-07, W-24, W-17). **S** **Done on `feature/hill-polish-2`** (the snore sound waits on audio, W-17).