class_name Npc
extends StaticBody2D
## Someone (or something) to talk to. Set the fields before adding it to the tree.

var display_name := ""
var character := ""  # folder in Actor/Character, or empty for an animal
var animal := ""  # folder in Actor/Animal (2-frame idle sheet)
var lines: Array = []
var sound := ""  # optional sfx when talked to
var gate_beanies := 0  # > 0: blocks a path until you have earned this many beanies in total
var open_lines: Array = []  # said once you have enough
var on_talk := Callable()  # replaces the normal lines, called with the player

signal gate_opened

var _sprite: Node2D
var _face: Texture2D


func _ready() -> void:
	if character != "":
		var actor := ActorSprite.new()
		actor.setup(character)
		_sprite = actor
		_face = load(Game.ASSETS + "Actor/Character/" + character + "/Faceset.png")
	else:
		var anim := AnimatedSprite2D.new()
		var frames := SpriteFrames.new()
		var sheet: Texture2D = load(Game.ASSETS + "Actor/Animal/" + animal + "/SpriteSheet.png")
		frames.set_animation_speed("default", 3.0)
		for i in 2:
			frames.add_frame("default", ActorSprite._cut(sheet, Rect2(i * 16, 0, 16, 16)))
		anim.sprite_frames = frames
		anim.offset = Vector2(0, -8)
		anim.play()
		_sprite = anim
		_face = load(Game.ASSETS + "Actor/Animal/" + animal + "/Faceset.png")
	add_child(_sprite)

	var shadow := Sprite2D.new()
	shadow.texture = load(Game.ASSETS + "Actor/Character/Shadow.png")
	shadow.position = Vector2(0, -1)
	shadow.z_index = -1
	add_child(shadow)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 6)
	shape.shape = rect
	shape.position = Vector2(0, -3)
	add_child(shape)
	add_to_group("interactable")


func interact_rect() -> Rect2:
	return Rect2(global_position + Vector2(-8, -16), Vector2(16, 18))


func interact(player: Player) -> void:
	player.can_move = false
	player.sprite.face_towards(global_position)
	if _sprite is ActorSprite:
		_sprite.face_towards(player.global_position)
	if sound != "":
		Game.sfx(sound)
	if on_talk.is_valid():
		await on_talk.call(player)
	elif gate_beanies > 0 and Game.beanies_total >= gate_beanies:
		await Dialog.say(open_lines, display_name, _face)
		gate_beanies = 0
		gate_opened.emit()
	else:
		await Dialog.say(lines, display_name, _face)
	player.can_move = true
