class_name Prop
extends StaticBody2D
## A static object from TilesetNature (tree, rock, sign...). Origin = bottom center.
## Give it `lines` to make it readable with A.

var sheet := Boulder.NATURE  # sprite sheet inside the asset pack
var texture: Texture2D  # or our own drawing instead of sheet + region
var region := Rect2()
var footprint := Vector2(12, 6)
var lines: Array = []
var on_use := Callable()  # instead of lines: called with the player when used


func _ready() -> void:
	var sprite := Sprite2D.new()
	if texture:
		region = Rect2(Vector2.ZERO, texture.get_size())
		sprite.texture = texture
	else:
		sprite.texture = ActorSprite._cut(load(Game.ASSETS + sheet), region)
	sprite.centered = false
	sprite.position = Vector2(-region.size.x / 2.0, -region.size.y)
	add_child(sprite)
	if footprint != Vector2.ZERO:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = footprint
		shape.shape = rect
		shape.position = Vector2(0, -footprint.y / 2.0)
		add_child(shape)
	if not lines.is_empty() or on_use.is_valid():
		add_to_group("interactable")


func interact_rect() -> Rect2:
	return Rect2(global_position + Vector2(-region.size.x / 2.0, -region.size.y), region.size + Vector2(0, 4))


func interact(player: Player) -> void:
	player.can_move = false
	if on_use.is_valid():
		await on_use.call(player)
	else:
		await Dialog.say(lines)
	player.can_move = true
