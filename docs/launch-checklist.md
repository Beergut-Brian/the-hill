# Launch checklist: The Hill

Rewritten by the launch-readiness lane, pass 3 (`feature/hill-launch-ready-3`, 2026-11-14), checked
against **`dev` at `bd30d47`** (PR 71, press answers). Since pass 1 (`40b9157`) these merged: PR 66
(D-pad, K-14), PR 67 (launch-ready-1), PR 68 (spend log), PR 69 (feel-rules audit, FR-1..FR-8),
PR 70 (pause door, FR-3), PR 71 (every menu press answers, FR-5).

Everything in section 1 was checked on the producer box. Section 2 needs the TV box (Bazzite,
GTX 1060, two 8BitDo pads) and stays open. Proof paths are in this repo unless they start with
`handoff/` (the producer's hand-off folder in the lane's worktree, not committed) or `.scratch/`
(git-ignored scratch in the same worktree).

## 1. Standing rules

| Rule | Yes / no | Proof |
| --- | --- | --- |
| No stick-only requirement | **Yes** (was no in pass 1; PR 66 merged) | `Players.add_dpad()` puts the D-pad on every player's move actions at boot. Tests: `tests/test_dpad.gd` (4: `::test_every_players_move_actions_have_the_dpad`, `::test_the_dpad_walks_its_own_player_like_the_stick`, `::test_the_dpad_moves_menu_focus`, `::test_solo_hands_the_dpad_to_the_focused_player`); `tests/test_dpad_moves.gd` (4: walks P1, walks P2 and never P1, drives the Front Loader, moves the pause cursor); `tests/test_pause_door.gd::test_dpad_reaches_the_door`. Rows K-14, FR-1. |
| No auto-steering the player | Yes | Only `--demo` and `--demo-beat=` move a player without a pad; the launcher never passes them. The elevator rides on A, never by walking in (`scenes/game/elevator.gd` `walk_in` false). Tests: `tests/test_controls.gd::test_p2_alone_rides_and_p1_in_the_other_scene_is_never_pulled`, `::test_turning_on_foot_never_swings_the_view`; `tests/test_turn_jump.gd` (10 cases). By design: a partner standing next to the cage rides along with the player who pressed A (`tests/test_hill_game.gd::test_a_partner_within_the_radius_is_pulled_along`, GAME.md playtest 2026-11-10 item 9). Open question for Kaden (FR-6): a vehicle pushed into a one-tile step hops up onto it. Row FR-6. |
| Gear is worn | Yes | Hard hats and tools are drawn on the characters' sheets; no HUD gear, no stats (X-02 dropped). Tests: `tests/test_hill_chooser.gd::test_the_stand_in_walks_digs_and_drives_with_its_gear`, `::test_defaults_are_jeff_and_chuck_on_their_own_sheets`. Frame: `handoff/frames/two_05_playing.png`. |
| Progress is earned behind visible barriers | Yes | Gate bands of hard rock span the hill; bonking one shows what opens it. Tests: `tests/test_dig_progression.gd::test_a_band_of_gate_rock_spans_the_hill_over_every_layer_but_the_first`, `::test_a_closed_band_bonks_and_shows_what_opens_it_then_opens`, `::test_what_opens_each_band`; floors in `tests/test_balance.gd` (C-27). |
| Each vehicle or tool has a job only it can do | Yes | `tests/test_puzzles.gd::test_the_block_is_not_cleared_by_hand_the_mole_or_another_vehicle`, `::test_the_front_loader_clears_the_block_with_its_own_dig`; `tests/test_underground_engineering.gd::test_every_gate_band_has_a_route_on_foot_or_with_the_vehicle_already_needed`, `::test_walking_up_to_hard_rock_on_foot_pops_the_vehicle_that_breaks_it`. |
| Anything that changes play shows its cause | Yes | `tests/test_dig_progression.gd::test_a_closed_band_bonks_and_shows_what_opens_it_then_opens`; `tests/test_story_cutscenes.gd::test_the_theft_takes_the_shovel_you_cannot_dig_then_you_wake_up_top_with_it`; `tests/test_hazards_residents.gd::test_a_falling_boulder_bonks_briefly_and_takes_nothing`. Every press answers too (FR-5): a press that does nothing honks and wobbles, `tests/test_press_answers.gd` (13), `tests/test_feel_rules.gd::test_unused_buttons_and_triggers_refuse`. Row FR-8. |
| No real places or personal details | Yes | Generic landmarks only (V-10, Q-03). `export_presets.cfg` does not pack `GAME.md`; no real names in shipped data. Tests: `tests/test_launch_ready.gd::test_no_design_notes_ship_in_the_export`, `::test_shipped_data_names_no_real_people`. `export_presets.cfg` and `data/` unchanged since pass 1 (`git diff 89c8ac5 bd30d47`). Row LR-03. |
| Solo mode is session-only, never restored at boot | Yes | `tests/test_lobby.gd::test_saved_solo_stays_off_at_boot`, `::test_select_start_hold_toggles_solo`, `::test_solo_flag_parsing`; `tests/test_feel_rules.gd::test_solo_shows_its_icon_only_while_on`. Frames: `two_12_solo_on_select_start.png`, `two_13_solo_off.png`, `solo_02..11`. **Fixed in this pass:** after `--solo`, Select on the pad never moved to the other podium in the menu (`tests/test_press_answers.gd::test_lobby_select_after_the_solo_flag_switches`, frame `solo_04_solo_select_p2_podium.png`). Row FR-4. |
| Saved toggles never restore at boot | Yes | Solo is the only toggle that changes how the game plays, and it is never restored (above, M-06). Music, sound and screen shake are preferences and persist on purpose (`tests/test_lobby.gd::test_settings_persist`). |
| A save offers Continue and New; New asks first and keeps a backup | Yes | `tests/test_new_game.gd` (11: `::test_first_run_shows_only_play`, `::test_menu_shows_continue_and_new_hill_with_a_save`, `::test_new_hill_without_the_hold_does_nothing`, `::test_hold_backs_up_and_the_next_game_has_no_edits`, `::test_restore_swaps_the_last_hill_back`, `::test_backups_capped_at_three_newest_kept`, ...). Frame: `two_14_back_to_menu_continue.png` (Continue focused, New Hill under it). Rows PT12-1, FR-2. |
| The pause menu has a big icon back to the launcher | **Yes** (was a text bar in pass 1; PR 70 merged) | The 128 px door `IconButton` with "BACK TO OPEN JAR" under it, the last stop after Story; A asks first, then saves and quits. Tests: `tests/test_pause_door.gd` (6: `::test_door_icon_is_in_the_pause_scene`, `::test_door_icon_takes_the_focus_and_is_the_last_stop`, `::test_dpad_reaches_the_door`, `::test_a_on_the_door_asks_first_then_quits_saved`, `::test_b_resumes`, `::test_door_wears_the_hill_accent`). Frames: `two_07_pause_door_focused.png`, `alone_06_pause_door_focused.png`, `solo_09_pause_door_focused.png`. Row FR-3. |
| Quitting never needs a force-close | Yes | All three session flows end by themselves with exit 0 (below); `tests/test_feel_rules.gd::test_window_close_saves_and_quits`. |

### Session flow (re-run 2026-11-14 on `bd30d47`, frames in `handoff/frames/`)

`tests/fixtures/session_flow.tscn` drives the real boot scene with synthetic pad events and saves a frame
at each step (`godot-render`, Forward+ on the software GPU). All three runs quit by themselves with
exit code 0.

| Step | Frame |
| --- | --- |
| Main menu, nobody joined ("WHO'S PLAYING?", A JOIN on both podiums) | `two_01_main_menu.png`, `alone_01_main_menu.png` |
| Ready-up: P1 presses A (READY!, 1P chip), then P2 presses A ("BOTH PLAYERS READY 2", countdown) | `two_02_p1_ready.png`, `two_03_both_ready_countdown.png` |
| Ready-up alone: hold A on Play ("STARTING SOLO" fills on Jeff's plate) | `alone_02_holding_a_alone.png` |
| Playing: the intro's letterbox with the A-skip arrow, then Hillville with both HUD corners | `two_04_playing_first_frame.png`, `two_05_playing.png`, `alone_03/04` |
| Pause by P2 ("PLAYER 2 PAUSED", red stripe), cursor on the door | `two_06_pause_by_p2.png`, `two_07_pause_door_focused.png` |
| The door asks first: "LEAVE THE GAME? Progress is saved." Stay / Leave; B, B resumes | `two_08_pause_leave_question.png`, `two_09_resumed.png` |
| Drop-out (P2's pad disconnects; P2's HUD corner goes) and drop-in (A on that pad, no menu) | `two_10_p2_dropped_out.png`, `two_11_p2_dropped_in.png` |
| Select + Start held 2 s: solo on (green and red heads top left), held again: solo off | `two_12_solo_on_select_start.png`, `two_13_solo_off.png` |
| Back to menu: Continue (focused, 2P) / New Hill / Settings / Back to Open Jar | `two_14_back_to_menu_continue.png` |
| Quit from the menu: Back to Open Jar, Leave the game?, Leave (exit 0) | `two_15_menu_leave_question.png`, `two_16_menu_leave_focused.png` |
| Quit from pause through the door (exit 0) | `alone_05..08`, `solo_08..11` |
| `--solo` boot: both ready and counting down; B stops it; Select moves the pad to Chuck; hold A starts | `solo_01..05`, then `solo_06/07` playing with the solo icon |

### Soak

`tests/fixtures/soak.tscn`: `--demo` looped for 30 real minutes on `bd30d47`. Each cycle plays the demo,
pauses and resumes, goes Back to menu, every third cycle starts a New Hill, and plays again. Result in
`REPORT.md` and row LR-02.

## 2. Still open: the TV box (Kaden, this weekend)

Plug a USB keyboard into the TV box for F3 (the FPS overlay: `fps`, `state`, `round`, `players`).
Each check names the PLAN-STATUS row it closes. Tell Gary the numbers. Do not edit data on the box.

1. **S-13: 60 fps at 1080p on the GTX 1060.** Launch *The Hill (dev)*, press F3, and hold each scene
   for 60 s. Write down the lowest `fps` you see:
   a. the main menu;
   b. both players up top in Hillville next to the shaft, with the Barn and Garage built;
   c. one player up top and one underground (the split screen), with the underground player digging;
   d. the Excavator digging a pond up top while the water fills;
   e. the Stone layer with a Lighthouse built (the lit layer);
   f. the pause menu over play (the blur).
   Pass: never below 58 in any of them. Below 58: note which scene, press F12 there (the screenshot
   goes to `~/.local/share/godot/app_userdata/The Hill/screenshots/`) and send it.
2. **S-07: camera zoom (now 2.0; vehicles 1.7).** Sit where your son sits. Up top and underground,
   can he point at his own character and at the block he is about to dig, without leaning in? Try it
   on foot and in the Front Loader. If both look small, Gary changes `data/camera.tres` `zoom` to 3.0
   and you check again.
3. **W-27: layer darkness (Topsoil 0.3, Clay 0.6, Stone 0.8, Ice 0.5, Crystal 0.15, Bottom 0.3).**
   With the living room lit as usual, visit each layer: can you see your character, the block edges and
   a treasure without a lamp? Stone (0.8) is the likeliest to be too dark. To jump to deep layers
   without touching his save, set the Steam launch options of *The Hill (dev)* to
   `%command% -- --demo --demo-beat=float` (Clay), `--demo-beat=sand` (Stone), `--demo-beat=ice_slide`
   (Ice), `--demo-beat=crystal` (Crystal) or `--demo-beat=reveal` (Bottom). The demo plays in its own
   "demo" profile. Clear the launch options afterwards.
4. **The 8BitDo pads on the TV** (what the producer box can only fake with synthetic events):
   a. first pad to press A is P1 (green), the second P2 (red), whichever pad it is;
   b. the D-pad walks, drives and moves every menu cursor, on both pads;
   c. Select + Start held 2 s turns solo on (two heads top left) and again turns it off; one Select tap
      in solo moves the pad to the other player, in the menu and in play; after solo off, the second
      pad presses A to come back in as P2;
   d. pull P2's pad's USB (or switch it off) mid-game: Chuck goes back to sleep; press A on it again:
      he wakes, no menu;
   e. pause, go down to the door (big icon, "BACK TO OPEN JAR"), A, Leave: the game closes by itself
      and Steam / Game Mode is back within a few seconds (no force-close).
5. **Kid-design checks only the TV shows** (`docs/kid-design.md`):
   a. menu text readable from the sofa (title, Play / Continue, "Leave the game?", the door label);
   b. green P1 and red P2 easy to tell apart (podiums, HUD corners, the pause stripe);
   c. the shaft ride (K-06) feels instant: A in the cage until standing below in under a second;
   d. cold start: from pressing the tile to the main menu in under 10 s (time it);
   e. sound level next to other games: barks, digging, music and the soft honk on a do-nothing press
      are not too loud or too quiet.
6. **F3 readouts for the record:** for 1a to 1f, write down `fps` and `players`, and send a photo.

## 3. Loading the build

From a merge on `dev`:

1. Gary merges the PR into `dev` and pushes a tag `vX.Y.Z-dev.N`. `.github/workflows/release.yml`
   runs the tests (`--continue`), stamps `data/build.json` (the menu's version label), exports Linux,
   smoke-boots the export, writes `openjar.json` and attaches `the-hill-vX.Y.Z-dev.N-linux.zip` to the
   pre-release.
2. On the TV box, the `openjar-update.timer` pulls it within the hour into
   `~/Games/openjar/the-hill-dev/`. To get it now: `systemctl --user start openjar-update.service`
   (or `~/openjar-tv/update.sh`).
3. Restart Steam (or Game Mode) so the refreshed *The Hill (dev)* tile shows.
4. Launch *The Hill (dev)*. The menu's top-right label must read the new tag (`dev` means a local build
   that CI did not stamp).

On the producer box (a local check):

```
godot --headless --path . --import
godot --headless --path . --export-release "Linux" build/the-hill.x86_64   # re-run once if it exits 134
run-export build/the-hill.x86_64 -- --ui=lobby --shots=2.5 --shot-dir=$PWD/.scratch/shots
```

Game flags go after `--` (`--solo`, `--demo`, `--shots=`). Only `--profile=` is read from either side.

### Re-running this lane's checks

```
rm -rf .godot && godot --headless --path . --import
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests --ignoreHeadlessMode --continue
godot-render --path . --resolution 1920x1080 res://tests/fixtures/session_flow.tscn -- --flow=two --shot-dir=$PWD/handoff/frames --profile=flowtwo
#   also --flow=alone, and --flow=solo --solo (each must end with exit 0)
godot --headless --path . res://tests/fixtures/soak.tscn -- --demo --soak-secs=1800   # grep the log for ERROR
```
