class_name Player
extends CharacterBody2D
## The climber. Walks around and talks to/inspects whatever is in front of them.

const SPEED := 70.0
const REACH := 18.0

var can_move := true
var sprite: ActorSprite


func _ready() -> void:
	sprite = ActorSprite.new()
	sprite.setup("Boy")
	add_child(sprite)
	add_child(_shadow())
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 6)
	shape.shape = rect
	shape.position = Vector2(0, -3)
	add_child(shape)


func _physics_process(_delta: float) -> void:
	var input := Vector2.ZERO
	if can_move:
		input = Game.steer_vector()
	velocity = input * SPEED
	move_and_slide()
	sprite.show_motion(velocity)


func _unhandled_input(event: InputEvent) -> void:
	if can_move and event.is_action_pressed("action_b"):
		get_viewport().set_input_as_handled()
		can_move = false
		await Backpack.open(get_tree().root)
		can_move = true
		return
	if can_move and event.is_action_pressed("action_a"):
		var target := find_interactable()
		if target:
			get_viewport().set_input_as_handled()
			target.interact(self)


## The nearest interactable in front of the climber, or null.
func find_interactable() -> Node2D:
	var probe := global_position + sprite.facing_vector() * 10.0 + Vector2(0, -4)
	var best: Node2D = null
	var best_dist := REACH
	for node in get_tree().get_nodes_in_group("interactable"):
		var rect: Rect2 = node.interact_rect()
		var dist := probe.distance_to(probe.clamp(rect.position, rect.end))
		if dist < best_dist:
			best = node
			best_dist = dist
	return best


func _shadow() -> Sprite2D:
	var shadow := Sprite2D.new()
	shadow.texture = load(Game.ASSETS + "Actor/Character/Shadow.png")
	shadow.position = Vector2(0, -1)
	shadow.z_index = -1
	return shadow
