# Report: hill-press-answers-adopt-1 (every menu press answers, 2026-11-13)

Branch `feature/press-answers-adopt-1`, based on `origin/dev` at `0f70ea7` (`git merge origin/dev`: already up
to date). Not pushed. PLAN-STATUS: **FR-5 partial → built** (moved row IDs: `FR-5`); totals recounted by
script: 210 built, 7 partial, 226 rows.

Source: openjar-template `dev` at `7301e2b` (PR #17, commit `9d99f29` "template: every menu press answers").
The template clone's `origin/dev` already holds it (checked at the start and again before writing this).

## What changed

Taken from the template as is (the Hill's copies were identical to the template's pre-fix `f737145`):
`scenes/ui/confirm_dialog.gd`, `scenes/ui/icon_button.gd` (`wobble()`, `pose_wobble()`, `is_wobbling()`),
`scenes/ui/kit/menu_item.gd` (same), `scenes/ui/kit/ui_sound.gd` (the `honk` stand-in cue; the Hill's own
`honk` through `Audio` wins).

Merged by hand / by patch (the Hill's versions differ from the template's):
- `scenes/ui/kit/menu_input.gd`: the Hill's `read()` kept (it has no d-pad reader: the d-pad comes through the
  move actions, `Players.add_dpad`); added the template's `other` / `button` fields, `OTHER` / `TRIGGERS`,
  `refuse()`, `owned_elsewhere()`, `_other()`, `_solo_hold()`, `refusals` / `last_refused`.
- `scenes/ui/lobby.gd`, `scenes/ui/pause_menu.gd`, `scenes/ui/settings_panel.gd`: template hunks applied
  cleanly at offsets (the pause list's left / right step works across the Hill's 5 rows incl. Story).
- `scenes/ui/kit/ui_preview.gd`: `--ui=pause-refuse` (4 steps to the door in the Hill, not 3) and
  `--ui=lobby-refuse`. `scripts/tools/shots.sh`: help line lists them.
- **The Hill's own screen** `scenes/ui/hold_confirm.gd` (New Hill? in the lobby, Restore last hill? in
  settings): unused buttons now refuse the same way (honk + wobble on the focused bar); a refusal never
  starts or feeds the hold. Start while paused is left to Game.
- Docs: `docs/press-answers.md` (the template's audit + a Hill section), `docs/ui.md` (`honk` cue row,
  "Every press answers", the two new screenshot states).

All customisation is in code; no `.tscn` changed. No gameplay code, art, audio or save format touched.

## Screen by screen

| Screen | Before | After | Test |
| --- | --- | --- | --- |
| Lobby / start menu | X, Y, LB, RB, LT, RT, L3, R3, Start, Select (not solo), B on Play not ready, left / right on a locked podium: silent | honk + focused bar wobbles; nothing else changes. Join press, solo Select, Select + Start hold unchanged | `test_lobby_unused_buttons_refuse_and_change_nothing`, `_b_with_nothing_to_back_out_of_refuses`, `_join_press_is_not_a_refusal`, `_left_right_on_a_locked_podium_refuses`, `_select_in_solo_still_switches` |
| Pause list | X, Y, shoulders, triggers, clicks, Select, left / right: silent | refuse; left / right step the list (right = down), refuse past the ends; Start still resumes | `test_pause_unused_buttons_refuse_and_change_nothing`, `_left_right_cycle_then_refuse_at_the_end`, `_start_still_resumes` |
| Settings (lobby or pause) | unused buttons silent | refuse, the row wobbles, no value changes; Start in pause resumes | `test_settings_unused_button_refuses_and_changes_nothing` (asserts the scratch settings file) |
| Leave the game? (ConfirmDialog) | silent | refuse, stays open on Stay | `test_confirm_unused_button_refuses_and_stays_open` |
| New Hill? (HoldConfirm, Hill only) | silent | refuse; no hold, no backup, save untouched | `test_new_hill_question_refuses_unused_buttons` |
| Restore last hill? (HoldConfirm, Hill only) | silent | refuse; no restore, backups unchanged | `test_restore_question_refuses_unused_buttons` |
| Build book (X in play) | not a menu screen: gameplay-owned (BuildController), already covered by FR-5 in play | unchanged | existing `test_feel_rules.gd` |

## Tests

New: `tests/test_press_answers.gd`, 12 cases, all pass (template's 10 adapted to the Hill + 2 Hill-only).
Real synthetic pad events on devices 5 and 6, `SuiteSandbox.enter("press_answers")` (own profile, own
settings file `user://test_settings_press_answers.json`, own picks) and a scratch saves folder
(`user://test_press_answers_saves`), never the real files.

Full suite on a clean import (`rm -rf .godot`, `--import`, then
`godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests`): **551 test cases, 0 errors, 0 failures, 0 flaky, 0 orphans** (exit 0).
The log has 9 engine `ERROR` lines ("Cannot convert argument 1 from Object to Object", which gdUnit does not count), in
`test_build_info`, `test_chooser`, `test_isolation` and `test_hill_barks_freed`: the lobby's deferred
`UiPreview.run` / `NewHillPreview.run` (`lobby.gd:115-116`, untouched here) firing after those suites free
the lobby in the same frame. This lane didn't cause them; none come from `test_press_answers.gd`. Worth a
`is_instance_valid` guard in a later systems lane.

## Frames (real, `scripts/tools/shots.sh`, Forward+ on llvmpipe, 4 s)

- `handoff/frames/pause_refuse_right_on_door.png`: `--ui=pause-refuse`, right pressed on the door, the door
  mid-rock. `handoff/frames/pause_door_still.png` is the same state without the refusal;
  `pause_door_wobble_vs_still.png` crops both side by side (left: tilted door).
- `handoff/frames/start_menu_refuse_x.png`: `--ui=lobby-refuse`, X refused, Play mid-shake.
  `start_menu_still.png` (`--ui=lobby-joined`) is the still; `start_menu_play_wobble_vs_still.png` crops the
  Play bar (top: shifted about 15 px right).

Looked at all of them: the wobble shows; nothing else differs. The honk is audio only (tests count it via
`UiSound.plays`).

## Notes

- Template parity: Start pressed first and then Select (to begin the solo hold) honks once for the Start in
  the lobby; Select pressed second never does. Same as the template.
- In the pause shots the door does not look larger when focused (128 vs 140 px) in either frame; that is the
  pause-door lane's state, not changed here.
- `handoff/` is git-excluded in this repo, so the frames and `handoff.json` live in the worktree only.
