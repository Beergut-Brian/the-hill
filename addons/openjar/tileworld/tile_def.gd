## One kind of tile in a TileWorld palette. Index in the palette = tile id; id 0 is air.
class_name TileDef
extends Resource

@export var id: StringName
@export var color: Color = Color.WHITE
@export var solid: bool = true
@export var breakable: bool = true
