## PT10-4: one unlock zone between two layers (data/gates/<n>_<layer>.tres). A band of Gate Rock
## (`rows` rows ending on the first row of layer `opens`) runs the whole width of the hill, so
## nobody digs to the bottom from the start. What breaks it: the Workshop's shovel on foot
## (`shovel_level`), a vehicle with dig_tier >= `vehicle_tier`, or, for everyone, a found
## `treasure` or an ARRIVED `resident`. The band's signs and the bonk bubble show `picture`.
class_name DepthGate
extends Resource

@export var id: StringName
## The layer under the band (LayerData.id).
@export var opens: StringName
## Rows of Gate Rock; the band ends on the first row of `opens`.
@export var rows: int = 3
## 0 = the shovel never breaks it; else the Workshop level (Progress.tool_level()) that does.
@export var shovel_level: int = 0
## 0 = no vehicle breaks it; else a vehicle with VehicleData.dig_tier >= this does.
@export var vehicle_tier: int = 0
## Found (Progress) = open for everyone, on foot too.
@export var treasure: StringName = &""
## Story.arrived(resident) = open for everyone, on foot too.
@export var resident: StringName = &""
## PictoBubble picture of what opens it: &"vehicle:<id>", &"treasure:<id>", &"shovel_gold",
## &"hardhat" ...
@export var picture: StringName
## First-session target (minutes of play) for this layer opening; BALANCE.md, never shown.
@export var target_minute: int = 0
