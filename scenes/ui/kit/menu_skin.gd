## One game's look for the Showtime menus (docs/ui.md): title, colours, the two characters and what
## sits behind the stage. Make one `.tres` per game at res://data/menu_skin.tres (picked up on its
## own), or set it in code: `UiStyle.use_skin(preload("res://data/menu_skin.tres"))` in main.gd _ready().
## Everything has a default, so an empty skin is the template's own look.
class_name MenuSkin
extends Resource

enum Backdrop {
	SUNBURST,   ## the turning sunburst only
	SCENE,      ## backdrop_scene runs live in a small SubViewport, blurred, under the sunburst
	TEXTURE,    ## backdrop_texture, blurred, under the sunburst (the still fallback)
	SCREEN,     ## whatever the game draws behind the menu (its level in main.tscn), blurred
}

@export_group("Title")
## Title art (a logo PNG). Empty: title_text in the display face, slanted, with a hard outline.
@export var title_texture: Texture2D
## Empty: the project name.
@export var title_text := ""

@export_group("Colours")
## Title fill, focused-bar chevron block, READY line, meters. Also becomes UiStyle.accent.
@export var accent := Color("ffc23a")
## The sunburst.
@export var accent2 := Color("8a5cf6")
## Panels, the wedge, the wipe cover. Keep it dark: cream text sits on it.
@export var deep := Color("281a5c")

@export_group("Characters")
## Player 1's character on the left podium (Jeff in Open Jar games). Any scene: a Control or Node2D
## is placed on the podium (feet at its origin for Node2D), a Node3D is shown in its own little
## lit SubViewport. The kit calls set_joined(on: bool), wave() and cheer() on it if it has them.
## Empty: the template's placeholder.
@export var p1_character: PackedScene
@export var p2_character: PackedScene
@export var p1_name := "JEFF"
@export var p2_name := "CHUCK"
## Pixel art: nearest filtering and whole-number scaling for 2D characters and backdrops.
@export var pixel_art := false
## Node2D / Control characters are scaled by this (pixel games: a whole number, e.g. 4).
@export var character_scale := 1.0
## Node3D characters: camera distance, and the height it looks at (about the middle of the
## character, in metres). Feet at y = 0 stand on the podium.
@export var camera_3d_distance := 3.4
@export var camera_3d_height := 0.9

@export_group("Backdrop")
@export var backdrop := Backdrop.SUNBURST
## Backdrop.SCENE: the game's world (a level, a diorama). Instanced into a SubViewport at 1/4
## resolution, so it is cheap and already soft. It brings its own Camera2D/3D.
@export var backdrop_scene: PackedScene
## A 3D backdrop_scene without a Camera3D of its own gets one here (where it stands, what it
## looks at, field of view).
@export var backdrop_camera_position := Vector3(5.6, 2.9, 7.4)
@export var backdrop_camera_target := Vector3(-3.0, 1.2, -1.0)
@export var backdrop_camera_fov := 50.0
## Backdrop.TEXTURE, and the fallback for SCENE when the scene is missing.
@export var backdrop_texture: Texture2D
## 0..1: how strongly the sunburst covers the world behind it (SUNBURST mode ignores this).
@export_range(0.0, 1.0) var sunburst_over_world := 0.55
## Blur strength for SCENE / TEXTURE / SCREEN.
@export_range(0.0, 5.0) var blur := 2.5

@export_group("Round card")
## Show a "ROUND 1" card between the wipe and the game.
@export var round_card := true
## %d is the round number.
@export var round_card_title := "ROUND %d"


func title() -> String:
	if title_text != "":
		return title_text
	return str(ProjectSettings.get_setting("application/config/name", ""))


func player_name(player: int) -> String:
	return p1_name if player == 0 else p2_name


func character(player: int) -> PackedScene:
	return p1_character if player == 0 else p2_character
