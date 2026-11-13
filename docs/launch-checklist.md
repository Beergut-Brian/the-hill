# Launch checklist: The Hill

Written by the launch-readiness lane (`feature/hill-launch-ready-1`, 2026-11-13, on `dev` at
`40b9157`). Everything here was checked on the producer box except section 2, which needs the TV box
(Bazzite, GTX 1060, two 8BitDo pads). Proof paths are in this repo unless they start with
`handoff/` (the producer's hand-off folder in the lane's worktree, not committed) or `.scratch/`
(git-ignored scratch in the same worktree).

## 1. Standing rules

| Rule | Yes / no | Proof |
| --- | --- | --- |
| No stick-only requirement | **No, on `dev` today.** Fixed by PR 66, not merged yet | In play, the move actions in `project.godot` (`p1_move_*`, `p2_move_*`) hold only the left stick axes and keys. The D-pad reaches only the lobby's character chooser (`scenes/ui/lobby.gd` `_left_right`). The fix is on `feature/hill-gap-close-8` (PR 66): K-14, `Players.add_dpad()`, `tests/test_dpad.gd`. This lane did not touch it because PR 66 owns `Players.gd`. It becomes **yes** when PR 66 merges. |
| No auto-steering the player | Yes | Only the `--demo` runner and the `--demo-beat` runners move a player without a pad. Those flags are never passed by the launcher. On ice, the glide keeps going the way the player last pushed (`scripts/gameplay/hazards.gd`, glide comment). Tests: `tests/test_controls.gd::test_p2_alone_rides_and_p1_in_the_other_scene_is_never_pulled`; `tests/test_turn_jump.gd` (10 cases: turning in place moves nothing on screen); `tests/test_controls.gd::test_turning_on_foot_never_swings_the_view`. One by-design exception: a partner standing next to the cage rides the elevator along with the player who pressed A (`tests/test_hill_game.gd::test_a_partner_within_the_radius_is_pulled_along`). |
| Gear is worn | Yes | The hard hats and tools are drawn on the characters' sheets, not shown as HUD gear, and there are no stats (X-02 dropped). Tests: `tests/test_hill_chooser.gd::test_the_stand_in_walks_digs_and_drives_with_its_gear`, `::test_defaults_are_jeff_and_chuck_on_their_own_sheets` (P-01). Frame: `handoff/frames/two_05_playing.png`. |
| Progress is earned behind visible barriers | Yes | Gate bands of hard rock span the hill. Bonking one shows what opens it. Tests: `tests/test_dig_progression.gd::test_a_band_of_gate_rock_spans_the_hill_over_every_layer_but_the_first`, `::test_a_closed_band_bonks_and_shows_what_opens_it_then_opens`, `::test_what_opens_each_band`. Floors: `tests/test_balance.gd` (C-27). |
| Each vehicle or tool has a job only it can do | Yes | Tests: `tests/test_puzzles.gd::test_the_block_is_not_cleared_by_hand_the_mole_or_another_vehicle`, `::test_the_front_loader_clears_the_block_with_its_own_dig`; `tests/test_underground_engineering.gd::test_every_gate_band_has_a_route_on_foot_or_with_the_vehicle_already_needed`, `::test_walking_up_to_hard_rock_on_foot_pops_the_vehicle_that_breaks_it`. |
| Anything that changes play shows its cause | Yes | Tests: `tests/test_dig_progression.gd::test_a_closed_band_bonks_and_shows_what_opens_it_then_opens`, `::test_a_dig_at_open_air_is_heard_as_a_swing`; `tests/test_underground_engineering.gd::test_walking_up_to_hard_rock_on_foot_pops_the_vehicle_that_breaks_it`; `tests/test_polish.gd::test_bumping_a_cow_is_heard_with_her_hop`, `::test_the_lighthouse_flare_is_heard_as_it_lights`. GAME.md: "The break shows its cause every time". |
| No real places or personal details anywhere | Yes, from this branch | Real places: V-10 and Q-03 (generic landmarks only). Personal details: the export used to pack `GAME.md` (producer notes, family details) through `export_presets.cfg` `include_filter`. This branch drops it. `data/story/lines.json` no longer names the producer. Tests: `tests/test_launch_ready.gd::test_no_design_notes_ship_in_the_export`, `::test_shipped_data_names_no_real_people` (the second fails on `dev`'s `lines.json`). Checked in the exported binary: `Kaden` 0 hits, `Premium model budget` 0 hits. |
| Solo mode is session-only | Yes | Tests: `tests/test_lobby.gd::test_saved_solo_stays_off_at_boot`, `::test_select_start_hold_toggles_solo`, `::test_solo_flag_parsing`. Frames: `handoff/frames/two_11_solo_on_select_start.png`, `two_12_solo_off.png`, `solo_02_solo_menu.png`. |
| Saved toggles never restore at boot | Yes | Solo is the only toggle that changes how the game plays, and it is never restored (`tests/test_lobby.gd::test_saved_solo_stays_off_at_boot`, M-06). Music, sound and screen shake are preferences, and they do persist on purpose (`tests/test_lobby.gd::test_settings_persist`). |

### Session flow (checked 2026-11-13, frames in `handoff/frames/`)

`tests/fixtures/session_flow.tscn` drives the real boot scene with synthetic pad events and saves a frame
at each step. All three runs quit by themselves with exit code 0 (no force-close).

| Step | Frame |
| --- | --- |
| Main menu, nobody joined | `two_01_main_menu.png` |
| Ready-up: P1 presses A, then P2 presses A, and the countdown starts | `two_02_p1_ready.png`, `two_03_both_ready_countdown.png` |
| Ready-up alone: hold A on Play | `alone_02_holding_a_alone.png` (also from the export: `export_lobby-hold_t002.5s.png`) |
| Playing (after the intro) | `two_04_playing_first_frame.png`, `two_05_playing.png`, `alone_04_playing.png` |
| Pause by P2, then "Back to Open Jar" asks first | `two_06_pause_by_p2.png`, `two_07_pause_leave_question.png` |
| Stay, resume | `two_08_resumed.png` |
| Drop-out (P2's pad disconnects; Chuck goes back to sleep in the bucket) | `two_09_p2_dropped_out.png` |
| Drop-in (A on that pad; Chuck wakes, no menu) | `two_10_p2_dropped_in.png` |
| Select + Start held 2 s: solo on, then held again: solo off | `two_11_solo_on_select_start.png`, `two_12_solo_off.png` |
| `--solo` boot | `solo_02_solo_menu.png` to `solo_07_solo_pause.png` |
| Back to menu (Continue / New Hill) | `two_13_back_to_menu_continue.png` |
| Quit from the menu: Back to Open Jar, then Leave | `two_14_menu_leave_question.png`, `two_15_menu_leave_focused.png` (exit 0) |
| Quit from pause: Back to Open Jar, then Leave | `alone_06/07`, `solo_08/09` (exit 0) |

The way back to the launcher is the "Back to Open Jar" bar in both menus. It is a bar with text, not
an icon. GAME.md's Showtime decision (2026-11-10) kept it that way, and no icon was added.

### Soak

`tests/fixtures/soak.tscn`: `--demo` looped for 30 real minutes. Each cycle plays the demo, pauses and
resumes, goes Back to menu, sometimes starts a New Hill, and plays again. The error count and the
cycle count are in `handoff/REPORT.md`.

## 2. Still open: the TV box (Kaden, this weekend)

Plug a USB keyboard into the TV box for F3 (the FPS overlay: `fps`, `state`, `round`, `players`).
Each check below names the PLAN-STATUS row it closes. Tell Gary the numbers. Do not edit data on the
box.

1. **S-13: 60 fps at 1080p on the GTX 1060.** Launch *The Hill (dev)*, press F3, and hold each scene
   for 60 s. Write down the lowest `fps` you see:
   a. the main menu;
   b. both players up top in Hillville next to the shaft, with the Barn and Garage built;
   c. one player up top and one underground (the split screen), with the underground player digging;
   d. the Excavator digging a pond up top while the water fills;
   e. the Stone layer with a Lighthouse built (the lit layer).
   Pass: never below 58 in any of them. Below 58: note which scene, then press F12 there (the
   screenshot goes to `~/.local/share/godot/app_userdata/The Hill/screenshots/`) and send it.
2. **S-07: camera zoom (now 2.0; vehicles 1.7).** Sit where your son sits. Up top and underground,
   can he point at his own character and at the block he is about to dig, without leaning in? Try
   it on foot and in the Front Loader. If both look small, Gary changes `data/camera.tres` `zoom` to
   3.0 (the guess from S3) and you check again.
3. **W-27: layer darkness (Topsoil 0.3, Clay 0.6, Stone 0.8, Ice 0.5, Crystal 0.15, Bottom 0.3).**
   With the living room lit as usual, visit each layer. For each one, answer: can you see your
   character, the block edges and a treasure without a lamp? Stone (0.8) is the one most likely to be
   too dark. To jump straight to deep layers without touching his save, set the Steam launch options
   of *The Hill (dev)* to `%command% -- --demo --demo-beat=float` (Clay), `--demo-beat=sand` (Stone),
   `--demo-beat=ice_slide` (Ice), `--demo-beat=crystal` (Crystal) or `--demo-beat=reveal` (Bottom).
   The demo plays in its own "demo" profile. Clear the launch options afterwards.
4. **Kid-design checks that only the TV shows** (`docs/kid-design.md`, K rows):
   a. menu text is readable from the sofa (title, Play / Continue, "Leave the game?");
   b. green P1 and red P2 are easy to tell apart on this TV (podiums, HUD corners, the pause stripe);
   c. the shaft ride (K-06) feels instant: A in the cage until standing below in under a second, and a
      second A skips the wait;
   d. cold start: from pressing the tile to the main menu in under 10 s (time it);
   e. the sound level next to other games: barks, digging and music are not too loud and not too quiet.
5. **F3 readouts for the record:** for 1a to 1e, write down `fps` and `players`, and send a photo
   of the screen.

## 3. Loading the build

From a merge on `dev`:

1. Gary merges the PR into `dev` and pushes a tag `vX.Y.Z-dev.N`. `.github/workflows/release.yml`
   runs the tests (`--continue`), stamps `data/build.json` (the menu's version label), exports
   Linux, smoke-boots the export, writes `openjar.json` and attaches `the-hill-vX.Y.Z-dev.N-linux.zip`
   to the pre-release.
2. On the TV box, the `openjar-update.timer` pulls it within the hour into
   `~/Games/openjar/the-hill-dev/`. To get it now: `systemctl --user start openjar-update.service`
   (or `~/openjar-tv/update.sh`).
3. Restart Steam (or Game Mode) so `shortcuts.py`'s refreshed *The Hill (dev)* tile shows.
4. Launch *The Hill (dev)*. The menu's top-right label must read the new tag (`dev` means a local
   build that CI did not stamp).

On the producer box (a local check):

```
godot --headless --path . --import
godot --headless --path . --export-release "Linux" build/the-hill.x86_64   # re-run once if it exits 134
run-export build/the-hill.x86_64 -- --ui=lobby --shots=2.5 --shot-dir=$PWD/.scratch/shots
```

Game flags go after `--` (`--solo`, `--demo`, `--shots=`). Only `--profile=` is read from either
side.

### Re-running this lane's checks

```
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests --ignoreHeadlessMode --continue
godot-render --path . --resolution 1920x1080 res://tests/fixtures/session_flow.tscn -- --flow=two --shot-dir=$PWD/.scratch/flow --profile=flowtwo
#   also --flow=alone, and --flow=solo --solo (each must end with exit 0)
godot --headless --path . res://tests/fixtures/soak.tscn -- --demo --soak-secs=1800   # grep the log for ERROR
```
