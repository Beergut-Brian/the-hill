# Report: hill-launch-ready-3 (launch-readiness, pass 3, 2026-11-14)

Branch `feature/hill-launch-ready-3`, based on `origin/dev` at **`bd30d47`** (PR 71; `git fetch`: origin/dev
unchanged at the end). Not pushed. Checked against everything merged since pass 1 (`40b9157`): PR 66 (D-pad),
PR 67 (launch-ready-1), PR 68 (spend log), PR 69 (feel-rules audit), PR 70 (pause door), PR 71 (press answers).

**The Hill is launch-ready except the TV-box checks** (S-13 frame rate on the GTX 1060, S-07 zoom, W-27
darkness, the 8BitDo pads on the TV). Every standing rule is now **yes** (pass 1 had "no stick-only
requirement" as **no**; PR 66 fixed it). One bug found and fixed (solo Select in the menu after `--solo`).

## What changed

- **Fix: Select after `--solo` did nothing in the menu** (`scenes/ui/lobby.gd` `_solo_select`). `--solo` and
  Settings' solo switch turn solo on with no single pad (`Players.VIRTUAL`, -2); the lobby read Select only
  from a real device, so the one pad could never reach P2's podium in the menu (in play it could, through the
  `restart` action). Now any pad's Select switches when solo has no single pad; Select + Start stays the solo
  hold. Test: `tests/test_press_answers.gd::test_lobby_select_after_the_solo_flag_switches` (fails on the old
  code, passes now). Frame: `handoff/frames/solo_04_solo_select_p2_podium.png`.
- **Session-flow fixture** (`tests/fixtures/session_flow.gd`): frames the pause door focused before A
  (`*_pause_door_focused`); the solo flow now stops the auto-countdown with B, switches podium with Select
  and starts by holding A. Before, `--solo` readied both and the countdown started the game before Select
  was pressed, so the old `solo_select_p2_podium` frame showed "GO!" and the bug above stayed hidden.
- **Roster test on fixtures only** (`tests/test_roster.gd::test_real_roster_is_jeff_and_chuck`): the one test
  on the real `data/roster.json` no longer asserts its order (`roster()[0] == "jeff"`); it keeps only the
  CLAUDE.md contract (Jeff and Chuck are the defaults, files exist, residents never playable). Every other
  roster / chooser test already runs on `tests/fixtures/roster_*.json`.
- **`docs/launch-checklist.md` rewritten** against `bd30d47`: 12 standing rules with yes / no and proof (every
  cited test name checked by script), session-flow table, the TV-box checks for Kaden (now including the
  8BitDo pad checks and the pause blur), the load steps.
- **PLAN-STATUS.md**: notes and proofs updated on FR-4, LR-01, LR-02, LR-06; totals line.

## Rows

- **Moved:** none. Every open row is a TV check, an art pick or Gary's ear (below). Totals recounted by
  script: 210 built, 7 partial, 0 missing, 1 superseded, 4 dropped, 4 later, 226 rows.
- **Updated (still built):** FR-4 (the lobby solo Select fix), LR-01 (flows re-run, new frames), LR-02 (soak
  re-run), LR-06 (checklist rewritten; all rules yes).

## Skipped rows and why

| Row | Status | Why skipped |
| --- | --- | --- |
| S-13 | partial | TV: 60 fps on the GTX 1060 (the producer box renders in software). Checklist 2.1 |
| S-07 | partial | TV: camera zoom from the sofa. Checklist 2.2 |
| W-27 | partial | TV: layer darkness in the living room. Checklist 2.3 |
| A-18 | partial | Gary's ear: listen to `handoff/audio3_preview.ogg` (from audio-3), then one data line in `data/blocks/sand.tres` |
| V-03 | partial | Art, waiting on Kaden's style pick (D or E; `feature/art-direction-options-2` unmerged) |
| F-3 | partial | Roll-up: closes when A-18 and V-03 do |
| F-6 | partial | Roll-up (art): closes with V-03 |
| V-01, V-02, V-04 to V-10, M-01, M-02, Q-01 | built | Art, palette, logo and store-art rows: Art Director process, not re-audited here |
| store art / jar (V-08, `store/`) | built | Art: skipped per the brief |

## Placeholder text, debug prints, dev switches

No new print, flag or placeholder since pass 1's LR-04 audit (`git diff 89c8ac5 bd30d47 -- scenes scripts
data`: 14 files, no print / TODO / placeholder added). Every print is behind a flag the launcher never passes
(`--demo`, `--demo-beat=`, `--bark-log`, `--audio-log`, `--proto`, `--shots=`) or `OS.is_debug_build()`.
The new `--ui=pause-refuse` / `lobby-refuse` previews are behind `--ui=`. Text in the frames reads as finished
(title, "WHO'S PLAYING?", pause, "LEAVE THE GAME? Progress is saved.", the door's "BACK TO OPEN JAR"). The
top-right label reads "dev" until CI stamps `data/build.json`. Release export (`.scratch/build/`): "Kaden" 0
hits, "Premium model budget" 0 hits; the only "GAME.md" string is project.godot's description, which no screen
shows.

## Frames (`handoff/frames/`, `godot-render` 1920x1080, all three flows exit 0 by themselves)

Looked at every one:

- `two_01_main_menu`: logo, PLAY, "WHO'S PLAYING? Press A on a controller to join", both podiums dark with
  "A JOIN". `two_02_p1_ready`: Jeff lit, READY!, 1P chip, Settings and Back to Open Jar appear.
  `two_03_both_ready_countdown`: Chuck READY! too, "BOTH PLAYERS READY 2", "Starting in 2, B Cancel".
- `two_04_playing_first_frame`: the intro's letterbox bars, A-skip arrow bottom right. `two_05_playing`:
  Hillville, head-frame, Jeff, Chuck and the Front Loader, both HUD corners (depth bars, bags, B/X hints).
- `two_06_pause_by_p2`: "PAUSED / PLAYER 2 PAUSED" (red stripe), Resume / Back to menu / Settings / Story,
  then the round door icon with "BACK TO OPEN JAR". `two_07_pause_door_focused`: the door enlarged with a
  white ring. `two_08_pause_leave_question`: "LEAVE THE GAME? Progress is saved. You'll go back to Open Jar."
  Stay (focused) / Leave. `two_09_resumed`: play again.
- `two_10_p2_dropped_out`: P2's HUD corner gone. `two_11_p2_dropped_in`: both corners back, no menu.
- `two_12_solo_on_select_start`: the green + red heads icon top left. `two_13_solo_off`: icon gone; P2's corner
  is gone too, by design: solo off keeps the pad on P1 and lets P2 go (`Players.set_solo(false)` emits
  `player_left(P2)`); P2 drops back in with A on their own pad, which the fixture does next.
- `two_14_back_to_menu_continue`: CONTINUE (focused, 2P) / NEW HILL / SETTINGS / BACK TO OPEN JAR, "PRESS A
  ON CONTINUE", both podiums with Pick / Ready up. `two_15/16`: the leave question, then Leave focused; exit 0.
- `alone_01..08`: one pad; holding A on Play fills "STARTING SOLO" on Jeff's plate; play; "PLAYER 1 PAUSED"
  (green stripe); door focused; leave question; Leave; exit 0.
- `solo_01/02` (`--solo`): heads icon top left, both podiums READY!, "BOTH PLAYERS READY 3". `solo_03`: B stops
  it, Jeff's plate gets "Pick / Ready up" and arrows, "WAITING FOR PLAYER 1, or hold A to start solo".
  `solo_04`: Select moved the pad to Chuck (Jeff's arrows gone). `solo_05`: "STARTING SOLO" fills on Chuck's
  plate. `solo_06/07`: play with the solo icon. `solo_08..11`: pause, door, leave question, Leave; exit 0.

One environment note: the first re-run of the solo flow lost its X server mid-run ("X connection to :84
broken", the shared virtual display) and exited 1 after `solo_06`; the re-run exited 0. Not a game fault.

## Soak

`tests/fixtures/soak.tscn -- --demo --soak-secs=1800` on `bd30d47`: **1802 s, 12 cycles, 11 demo runs to the
end, 0 SCRIPT ERROR, 0 ERROR, 0 WARNING**, `Game.quit()` exit 0. Static memory 238 to 254 MB from cycle 2 on;
orphan nodes 0 at the end. Log: `handoff/soak.log`.

## Tests

After a clean import (`rm -rf .godot`, `--import`: 0 errors): `godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests --ignoreHeadlessMode --continue` → **552 test cases, 63 suites, 0 errors, 0 failures, 0 flaky, 0 skipped, 0 orphans**, exit 0, 11 min 22 s (log `.scratch/tests.log`). One new case this pass (551 before). The log also has the 9 known engine `ERROR: ... Cannot convert argument 1 from Object to Object` lines (the lobby's deferred `UiPreview.run` / `NewHillPreview.run` on a lobby a test already freed); they predate this pass, gdUnit does not count them, and they never appear in the soak or the flows.

Hygiene: roster and chooser tests run on `tests/fixtures/roster_*.json` (one deliberate contract test on the
real file, above). Physics outcomes: spot-checked the pile and boulder tests (`test_crane_pond.gd` stages its
own 10 dirt and places the player; hazard tests compare a staged before / after); not every one of the
suite's tests was read.

## Needs Kaden

- **`--solo` boot readies both players and starts a 3 s countdown with no press** (`lobby.open()`, since
  2026-11-09; B stops it). Solo is a playtest switch, so it may be what you want; say if the game should wait
  for A instead.
- **FR-6 (carried over):** a vehicle pushed into a one-tile step hops up onto it. Is that auto-steering?
- **The TV checks** in `docs/launch-checklist.md` section 2 (S-13, S-07, W-27, the pads, the kid-design TV
  items). Nothing here was played on the TV; no playtest result is claimed.
