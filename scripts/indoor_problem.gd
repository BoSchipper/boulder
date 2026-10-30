class_name IndoorProblem
extends Boulder
## A gym problem: a coloured section of the plywood wall instead of a rock.
## You start it from the mats at the foot of its section.

var section := Rect2()  # its part of the wall, in room coordinates


func _ready() -> void:
	indoor = true
	position = Vector2(section.get_center().x, section.end.y + 2)
	# A chalk tick on the wall once topped, like outside.
	_tick = PixelArt.sprite(PixelArt.from_rows(["o...o", "wo.ow", ".wow.", "..w.."], {"w": PixelArt.CHALK, "o": PixelArt.OUTLINE}), Vector2(section.size.x / 2.0 - 10, -section.size.y + 4), self)
	_tick.visible = Game.is_topped(boulder_id)
	add_to_group("interactable")


func interact_rect() -> Rect2:
	return Rect2(section.position.x + 4, section.end.y - 6, section.size.x - 8, 16)
