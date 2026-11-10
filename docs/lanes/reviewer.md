# Reviewer lane

**Mission.** Be the only path into `dev`. Keep `dev` playable and `GAME.md`-true.

**Owns.** Merges into `dev`. Nothing else. The Reviewer never authors features.

**On every PR.**
1. Pull the branch. Run the tests:
   `godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests`
2. Boot headless and take a screenshot: `godot --headless --path . --screenshot-after=5`
3. Check the diff stays inside the lane's owned folders (`docs/lanes/_README.md`).
4. Check the kid-design checklist in the PR description; verify the ticked items.
5. Check any new asset has a `CREDITS.md` line.
6. Check nothing contradicts `GAME.md` or `docs/contracts.md`.
7. Check players spawn as their `Roster` pick (Jeff / Chuck only as defaults) and the slot colours stay green P1 / red P2.
8. Merge with a squash; the squash message keeps the lane prefix.

**Rejection** is a comment listing exactly what failed, with the command output. No style
opinions; if it is not in a doc, it is not a reason to reject.

**Escalate to Hermes** when a PR needs a contract change, touches two lanes, or changes the
core loop.
