# Report: hill-rules-audit-1 (standing feel rules, 2026-11-13)

Branch `fix/hill-rules-audit-1`, based on `origin/dev` at `7f7c3af` (`git merge origin/dev`: already up to
date). Not pushed. PLAN-STATUS: new source S10 and rows FR-1 to FR-8 ("Standing feel rules" section), K-14's
proof extended, totals recounted (226 rows).

## Rules table

| # | Rule | Before (dev `7f7c3af`) | Now | Where |
| --- | --- | --- | --- | --- |
| 1 | D-pad everywhere | Already passing. gap-close-8 put the D-pad on every `p*_move_*` action at boot (`Players.add_dpad()`), so play (`HillPlayer.intent()` → `Players.move_vector`), vehicles, the build book, and every menu (`MenuInput.read()`: pause, settings, lobby, New Hill / Restore question) read it. What was missing was a test that the body really moves | **built**. New `tests/test_dpad_moves.gd`: pad 1's D-pad walks P1 both ways; pad 2's walks P2 and never P1; the D-pad drives the Front Loader; the D-pad moves the pause cursor. No end card exists (no round ever ends: `Game.end_round` has no caller) | `scripts/autoload/Players.gd` (`DPAD`, `add_dpad`), `tests/test_dpad_moves.gd`, `tests/test_dpad.gd` |
| 2 | Start fresh | Already passing (PT12-1). Save: `user://saves/<profile>.json` (town, progress, inventory, time of day). With a save the menu shows Continue / New Hill; New Hill asks with a 1 s hold-A, renames the save to a backup (newest 3 kept, never deleted); Settings shows Restore while a backup exists; pause → Back to menu / Settings reaches both | **built** (no change) | `tests/test_new_game.gd` (9 cases) |
| 3 | Pause and back out | Quit path clean: window close (`Game._notification` WM_CLOSE, `auto_accept_quit = false`) and the door both run `Game.quit()`: save, then `get_tree().quit()`. **But** the door is a text bar ("BACK TO OPEN JAR") with no icon | **partial**. Added `test_window_close_saves_and_quits`. The icon is template kit code (see Template gaps) | `scripts/autoload/Game.gd:25-31,93-97`; `tests/test_feel_rules.gd`; `tests/test_lobby.gd::test_pause_door_asks_then_quits`; frame `handoff/frames/rule3_pause_door_is_text_only_no_icon.png` |
| 4 | Solo mode | `--solo`, Select + Start held 2 s (real time), the two-heads icon top-left, off by default, a saved solo never restored at boot, tests on their own settings file: all passing. **But** in play the one pad could never reach P2: only the lobby's Select tap moves the focus, and HillGame keeps P2 asleep until the focus moves | **built**. In play, Select (R on the keys) in solo moves the pad to the other player (the lobby's sound, a bump; P2 tips out of the bucket on the first switch). Select with Start held is left to the solo hold | `scenes/game/hill_game.gd` (`_unhandled_input`, `solo_switch`); `tests/test_feel_rules.gd::test_select_in_solo_play_moves_the_pad_to_the_other_player`, `::test_select_with_start_held_is_the_solo_hold_not_a_switch`, `::test_solo_shows_its_icon_only_while_on`; `tests/test_lobby.gd` (flag, hold, boot); frame `handoff/frames/rule4_solo_icon_top_left_rule7_hint_panel_glyphs.png` |
| 5 | Every action beeps | In play: A (dig / swing / bonk / scoop / ride), B (jump, hop in / out, cancel), Y (horn) always sound. **Silent:** X underground (the book is up top only), LB / RB / LT / RT / stick clicks. **Wrong:** Select in play ran `Game.restart()`: the confirm and round-start sounds, `round_started`, and nothing else (HillGame ignores it once a game exists). Menus: X, Y, the shoulders and left / right on the pause list are silent | **partial**. In play every press now answers: the no-op ones give `HillPlayer.refuse()` (the existing `honk` cue, "can't afford it", and a wobble). Select out of solo refuses instead of the fanfare. Menus unchanged (template kit) | `scenes/players/hill_player.gd` (`refuse`, `refused`, X underground); `scenes/game/hill_game.gd` (`UNUSED_BUTTONS`, triggers, Select); `tests/test_feel_rules.gd` (3 cases) |
| 6 | No forced movement | Passing. The elevator rides on A (`walk_in` is false outside scripted runners), ladders do not snap x, the dig marker never moves the body, hop-in snaps to the vehicle only on B. Cutscenes move locked players (scripted, not in walkable play) | **built** (no change). One question for Kaden below | `scenes/game/elevator.gd:48`; `scenes/players/hill_player.gd` |
| 7 | Show the buttons that matter | Passing: `HillHintLayer` per player, bottom outer corner, A / B / X glyph rows that change with context the same frame (on foot, beside a vehicle, driving, in the cage, book open, a bonk's "needs") | **built** (no change) | `scripts/gameplay/hill_hint_layer.gd`; `tests/test_controls.gd::test_hints_follow_the_context_the_same_frame`; same frame as rule 4 |
| 8 | Every cause shown | Passing. Effects that change play: the Mole's shovel theft (cutscene, then you can't dig), closed bands (bonk + picture of what opens them), boulder bonk, cave-in trap, a bonked scrub (picture of the Loader), the workshop's tool level (shovel pops over each player). Merged since 2026-11-12 (new game, turn jump, balance bottom, launch-ready): nothing new that changes play without a cause | **built** (no change) | `tests/test_story_cutscenes.gd`, `tests/test_dig_progression.gd`, `tests/test_hazards_residents.gd`, `tests/test_gap_close.gd` |

## What changed (code)

- `scenes/players/hill_player.gd`: `refuse(button)` (sound `honk`, a small squash, signal `refused`). X
  underground calls it. B in the air was **not** made a refusal: jump reads *held* B, so B pressed in the air
  jumps on landing; it is not a no-op.
- `scenes/game/hill_game.gd`: `_unhandled_input` in PLAYING. Select / R: in solo `solo_switch()`, else refuse
  (consumed, so `Game.restart()` no longer fires in play). LB, RB, stick clicks and a trigger pull past 0.6
  (one per pull) refuse. `_player_of_device` maps a pad to its player (the focus in solo, P1 for the keys).
- No change to `project.godot`, `scenes/ui/*`, tuning, art, audio or data.

## Tests

- New: `tests/test_dpad_moves.gd` (4), `tests/test_feel_rules.gd` (7). Staging: each player waits (bounded)
  until it stands on the ground; a walk is judged by direction and 24 px, held until reached (cap 240 frames),
  never by a frame count. The Loader case tries right, then left.
- Full suite (clean import first): `Overall Summary: 533 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | (exit code 0; on `528db5b` + this report)`

## Template gaps (openjar-template; not changed here)

1. **Pause door has no icon.** `scenes/ui/pause_menu.tscn` / `kit/menu_item.gd` draw text-only bars; the rule
   wants a big icon back to the launcher (a 5-year-old can't read "BACK TO OPEN JAR"). Same for the lobby's door.
2. **Silent presses in the kit menus.** `MenuInput.read()` reads only up / down / left / right, A and B. In the
   pause list, Settings, the lobby and the confirm questions, X, Y, the shoulders and triggers say nothing,
   and left / right on the pause list say nothing. The kit needs a refusal cue (`UiSound`) for those.
3. **Pause hint strip is clipped.** In the 1920x1080 frame the strip's last glyph ("B Resume") runs off the
   right edge (`handoff/frames/rule3_pause_door_is_text_only_no_icon.png`).
4. **`Game.gd` `restart` on Select** in PLAYING plays a confirm and the round-start sound in any game that has no
   rounds. The Hill now consumes it in play; the template's default may want the same thought.
5. **No D-pad in `project.godot`.** Unchanged: The Hill adds it in code (`Players.add_dpad()`).

## Needs a gameplay decision (not decided here)

1. **Vehicles hop up one-tile steps on the stick** (`HillPlayer._step_up`): pushing a vehicle into a one-tile
   step lifts it onto the step. It moves only the way the stick points, but it is a hop the player didn't press
   for. Keep (vehicles "drive over anything"), or make it a button?
2. **The refusal sound.** No-op presses use the existing `honk` ("can't afford it", soft clown bwah). Keep it,
   or ask the Audio lane for a separate "nope"?
3. **Solo focus marker.** The solo icon shows both heads; it does not say which player the pad drives now
   (the switch bumps that player and plays a high / low tick). Does Kaden want the focused head bigger?
4. **Presses while locked** (cutscene, elevator ride, a boulder's stun) are silent by design (the lock is shown);
   say if those should refuse too.

## Frames

- `handoff/frames/rule3_pause_door_is_text_only_no_icon.png` (`--ui=pause`, before and now: unchanged).
- `handoff/frames/rule4_solo_icon_top_left_rule7_hint_panel_glyphs.png` (`--demo --solo`, t = 8 s: the
  two-heads solo icon top-left, P1's hint panel bottom-left with A dig / B get out).
