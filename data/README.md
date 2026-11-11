# data/

Content rows for The Hill, as `.tres` resources. The content lane owns this folder.
The id of every row equals its file stem (`dirt.tres` has `id = &"dirt"`).

- `blocks/`     BlockData: dirt .. crystal, plus edgestone and strangestone (unbreakable until 2.0.0).
- `layers/`     LayerData: depth bands 0..300 with block mix, hazards, darkness, snore volume.
- `treasures/`  TreasureData: one-of-a-kind finds and what they unlock. No sprites yet.
- `buildings/`  BuildingData: buildable buildings and the ruins to restore. No scenes yet.
- `vehicles/`   VehicleData: Front Loader .. Drill Rig, ordered 0..4.
- `hazards/`    HazardData: how many boulders, water pockets and cave-ins each layer gets, and how
                many of them sit near the layer's landing (Gameplay lane added the first rows, 2026-11-10).

- `camera.tres` CameraTuning (`scripts/gameplay/camera_tuning.gd`): the base zoom (S-07), the
                underground lead and the per-vehicle zoom-out (Camera lane, 2026-11-10).

Schemas live in `scripts/data/`; the rules are in `docs/contracts.md`.
Costs name block ids, never code. A ruin may only cost blocks from layers at or above the
layer where its resident is met (`Rules.restore_cost_is_fair`).
Numbers here are first guesses; BALANCE.md wins when it exists.
Add a row by copying a neighbour and changing the id and the file name together.
tests/test_data.gd loads every row and checks the folder's class and the id.

`menu_skin.tres` (MenuSkin, the Showtime menus' look: logo, colours, Jeff and Chuck, the Hillville
backdrop) is the UI lane's, at the path the menu kit reads (`docs/ui.md`).
