class_name ActorSprite
extends AnimatedSprite2D
## Four-direction character sprite built from a Ninja Adventure character folder
## (SeparateAnim/Walk.png = 4 columns down/up/left/right x 4 frames, Idle.png = 1 frame).
## Characters without SeparateAnim use SpriteSheet.png (same columns, walk in rows 0-3).

const DIRS := ["down", "up", "left", "right"]

var facing := "down"


func setup(character: String) -> void:
	var base := Game.ASSETS + "Actor/Character/" + character + "/SeparateAnim/"
	var walk: Texture2D
	var idle: Texture2D
	if ResourceLoader.exists(base + "Walk.png"):
		walk = load(base + "Walk.png")
		idle = load(base + "Idle.png")
	else:
		walk = load(Game.ASSETS + "Actor/Character/" + character + "/SpriteSheet.png")
		idle = walk
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for col in DIRS.size():
		var dir: String = DIRS[col]
		frames.add_animation("walk_" + dir)
		frames.set_animation_speed("walk_" + dir, 8.0)
		for row in 4:
			frames.add_frame("walk_" + dir, _cut(walk, Rect2(col * 16, row * 16, 16, 16)))
		frames.add_animation("idle_" + dir)
		frames.add_frame("idle_" + dir, _cut(idle, Rect2(col * 16, 0, 16, 16)))
	sprite_frames = frames
	offset = Vector2(0, -8)
	play("idle_down")


func show_motion(velocity: Vector2) -> void:
	if velocity.length() > 0.1:
		if abs(velocity.x) > abs(velocity.y):
			facing = "right" if velocity.x > 0 else "left"
		else:
			facing = "down" if velocity.y > 0 else "up"
		play("walk_" + facing)
	else:
		play("idle_" + facing)


func face_towards(point: Vector2) -> void:
	var d := point - global_position
	if abs(d.x) > abs(d.y):
		facing = "right" if d.x > 0 else "left"
	else:
		facing = "down" if d.y > 0 else "up"
	play("idle_" + facing)


func facing_vector() -> Vector2:
	match facing:
		"up": return Vector2.UP
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
	return Vector2.DOWN


static func _cut(tex: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = region
	return atlas
