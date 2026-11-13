# Report: hill-pause-door-1 (pause door icon back to Open Jar, 2026-11-13)

Branch `feature/hill-pause-door-1`, based on `origin/dev` at `216670f` (`git merge origin/dev`: already up to
date). Not pushed. PLAN-STATUS: FR-3 partial → **built**; totals recounted by script (209 built, 8 partial,
226 rows).

## Where the template change came from

The local template clone's `origin/dev` ref (`e57d4ec`) is stale: it does not have the door yet. The
remote could not be fetched (no GitHub credentials here). I did not run a fetch in the template clone
because it is read only. The door change is on the clone's local branch `feature/template-pause-door-1`
(`30b4cbd` door icon, `17c04c5` tests, `69ab14a` PLAN-STATUS). I read it from there. **Gary: please check
that this branch is what was merged to template `dev`.**

**No door art file exists.** The template's door is drawn in code by `IconButton._draw()` (`Icon.DOOR`).
The template has no `art/ui/` on any branch. So there was no file to copy and nothing to add to
`assets/CREDITS.md`. I did not invent an art file.

## What changed

- `scenes/ui/icon_button.gd`: replaced with the template's version. Before this it matched the template's
  pre-door version byte for byte. Adds `class_name IconButton`, `focus_scale`, `disabled` and `slam_in()`
  (so the icon can sit in a `MenuItem` focus list), and a bigger drawn door.
- `scenes/ui/pause_menu.tscn`: this is the game's own scene, not an instance of the template's. The
  "Back to Open Jar" `MenuItem` bar is gone. In its place is `Card/Door`: `Icon` (`IconButton`, `icon = DOOR`,
  128 px, `focus_scale` 140/128) with `Label` "Back to Open Jar" (uppercase) centred beneath it. The node
  layout is the template's. The Hill keeps its fifth bar (Story), so the bar list was tightened to fit
  (top 380, gap 12) and the door sits at y 856. The label's bottom is at y 1054.
- `scenes/ui/pause_menu.gd`: the focus list is Resume, Back to menu, Settings, Story, then the door, which
  is the last stop. The game's look is set in code. `apply_skin()` sets `_door.tint = UiStyle.accent` (The
  Hill's accent). `_style_door_label()` draws the label cream and 46 px when the door is focused, and 38 px
  at 75 % when it is not. The label slams in with the door. Resume, Back to menu, Settings, Story, B
  resumes or backs out, the d-pad through `MenuInput`, and the door's path are all unchanged: A opens the
  `ConfirmDialog`, and "leave" runs `Game.quit()`, which saves and then quits.
- `scenes/ui/kit/ui_preview.gd`: adds the `--ui=pause-door` state (four focus moves down), as the template
  does. I needed it to take the frame.
- `docs/ui.md`: updated the pause line.
- The solo icon, the PAUSED title, the pauser colour and the wedge are not touched. Neither is
  `project.godot`.

## Tests

New `tests/test_pause_door.gd` (6 cases). It runs in its own sandbox (`SuiteSandbox.enter("pause_door")`), so
it never touches the real profile, settings or picks file. Inputs are synthetic presses on pads 5 and 6.

- `test_door_icon_is_in_the_pause_scene`: an `IconButton` with `Icon.DOOR`, 128 px, 140 px focused. The
  label reads "Back to Open Jar", sits beneath the icon, is centred under it and is on screen. The old
  `Card/Buttons/Door` bar is gone.
- `test_door_icon_takes_the_focus_and_is_the_last_stop`
- `test_dpad_reaches_the_door`: the d-pad on either pad walks Resume → … → Story → Door, and Up comes back.
- `test_a_on_the_door_asks_first_then_quits_saved`: A asks first and does not quit. B in the question
  stays. A then "leave" quits once, and the save is flushed.
- `test_b_resumes`: B on the door resumes play.
- `test_door_wears_the_hill_accent`

The existing `tests/test_lobby.gd::test_pause_door_asks_then_quits` still passes unchanged.

Clean import (`rm -rf .godot && godot --headless --import --path .`), then the full suite:

```
Overall Summary: 539 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Exit code: 0
```

## Frame

`handoff/frames/pause_door_focused.png` (`scripts/tools/shots.sh "" 3,4.5 … --ui=pause-door`, the 4.5 s
frame). I looked at it. It shows PAUSED in cream with a red drop and the "PLAYER 2 PAUSED" tag. The four
bars (Resume, Back to menu, Settings, Story) are all unfocused. Under them is the round yellow door icon
(The Hill's accent) with a brown door, which is the focused colour. Beneath it, "BACK TO OPEN JAR" is in
large cream letters and reads clearly. The icon and the text are not clipped. The text ends about 25 px
above the bottom of the screen and is left of the wedge edge. The hint strip "Move / Select / Resume"
is bottom right and does not overlap. The game shows blurred behind.

## Notes for Gary

- `handoff/` is git-excluded, so the frame lives in this worktree only.
- Upstream: nothing new. This lane only adopted the template's change.
