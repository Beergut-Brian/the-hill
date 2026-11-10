## A one-of-a-kind find (data/treasures/<id>.tres).
class_name TreasureData
extends Resource

@export var id: StringName
## Layer id where the seed places it.
@export var layer: StringName
@export var sprite: Texture2D
## Tiles; bigger than 1x1 is a multi-tile prop that breaks into chunks.
@export var footprint: Vector2i = Vector2i.ONE
## Building / vehicle / resident id, or &"".
@export var unlocks: StringName
## How many the seed places in the layer.
@export var count: int = 1
## For Hermes and the grown-up only, never on the kid's screen.
@export var museum_text: String
