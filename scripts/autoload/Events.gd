## The Hill's signal bus. Emitters call Events.<signal>.emit(...); anyone may connect.
extends Node

## A tile was dug out. player is Players.P1/P2, or -1 for nobody.
signal tile_dug(cell: Vector2i, block: StringName, player: int)
## A treasure was found.
signal treasure_found(id: StringName, player: int)
## The shared pile of one block type changed to this count.
signal inventory_changed(block: StringName, count: int)
## A building was placed on the ground grid.
signal building_placed(id: StringName, cell: Vector2i)
## A placed building was moved by the Crane.
signal building_moved(id: StringName, from: Vector2i, to: Vector2i)
## A vehicle was unlocked by a Garage.
signal vehicle_unlocked(id: StringName)
## A player changed scene: &"hillville" or &"underground".
signal entered_scene(player: int, scene: StringName)
## The screen split or merged.
signal split_changed(is_split: bool)
## A resident was met underground; count is the encounters so far.
signal resident_encountered(id: StringName, count: int)
## A resident reached the surface and waits at their ruin.
signal resident_arrived(id: StringName)
## A ruin was restored into its building.
signal ruin_restored(id: StringName, resident: StringName)
## The Dragon woke up.
signal dragon_woken()
