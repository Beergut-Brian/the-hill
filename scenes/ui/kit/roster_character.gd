## A Roster character for a lobby podium, built from data/roster.json (CharacterSlot uses it when
## the MenuSkin leaves p1_character / p2_character empty). make() returns:
##   3D (default): a Node3D holding the character's .glb, playing idle, cheer on wave()/cheer()
##   pixel (MenuSkin.pixel_art): a Node2D with the pixel form, feet at the origin
## Either one swaps who it is with set_character(id). A form the character lacks falls back to the
## other one; neither: null (the slot shows the placeholder).
class_name RosterCharacter
extends RefCounted

const Jarling3D := preload("res://scenes/ui/kit/roster_jarling.gd")
const Sprite := preload("res://scenes/ui/kit/roster_sprite.gd")


static func make(id: String, pixel: bool) -> Node:
	var who := Roster.info(id)
	if who.is_empty():
		return null
	var has_3d: bool = who.glb != "" and ResourceLoader.exists(who.glb)
	var has_px: bool = who.pixel != "" and ResourceLoader.exists(who.pixel)
	var node: Node
	if has_3d and (not pixel or not has_px):
		node = Jarling3D.new()
	elif has_px:
		node = Sprite.new()
	else:
		return null
	node.name = "Roster_%s" % id
	node.set_character(id)
	return node
