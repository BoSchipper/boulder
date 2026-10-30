extends Microgame
## SPOT!: someone else is projecting the boulder. They wobble, then come off.
## Slide the crashpad (left/right) under where they will land.

const GROUND := 68.0  # above the hint line, so the pad stays visible
const PAD_W := 34

var character := "Villager5"
var climber: Sprite2D
var pad: Sprite2D
var shadow: Sprite2D
var pos := Vector2(75, 10)
var vel := Vector2.ZERO
var pad_x := 75.0
var wobble_time := 1.2
var falling := false
var rng := RandomNumberGenerator.new()


func setup() -> void:
	word = "SPOT!"
	keys = ["KeyLeft", "KeyRight"]
	duration = 5.0
	survive_wins = false
	rng.seed = seed_value
	character = Game.spotting.get("character", character)
	pos = Vector2(rng.randf_range(30, 120), 10)
	pad_x = 150 - pos.x  # start on the wrong side, so you have to move
	wobble_time = rng.randf_range(0.8, 1.5)
	add_rock_background()
	var sheet := Game.ASSETS + "Actor/Character/%s/SeparateAnim/" % character
	climber = PixelArt.sprite(ActorSprite._cut(load(sheet + "Idle.png"), Rect2(16, 0, 16, 16)), Vector2.ZERO, stage)
	shadow = PixelArt.sprite(PixelArt.from_rows([".oooooo.", "oooooooo", ".oooooo."], {"o": Color(0, 0, 0, 0.35)}), Vector2.ZERO, stage)
	var blues := [Color("2a4f94"), Color("3d6fc8"), Color("6c9ce4"), Color("4a3a4a")]
	pad = PixelArt.sprite(PixelArt.shape(Vector2i(PAD_W, 7), blues, func(x: int, y: int) -> int:
		if x == 0 or x == PAD_W - 1 or y == 0 or y == 6: return 9
		return 2 if y == 1 else (0 if y >= 5 else 1)), Vector2.ZERO, stage)
	hint("schuif de pad onder je maatje", "KeyLeft")
	_place()


func tick(delta: float) -> void:
	pad_x = clampf(pad_x + Input.get_axis("move_left", "move_right") * 75.0 * speed * delta, PAD_W / 2.0, 150 - PAD_W / 2.0)
	if not falling:
		# Shaking on the wall... then off they come, drifting a bit sideways.
		climber.position.x = pos.x - 8 + (1 if Engine.get_frames_drawn() % 6 < 3 else -1)
		if _elapsed >= wobble_time:
			falling = true
			vel = Vector2(rng.randf_range(-22, 22) * speed, 0)
			climber.texture = ActorSprite._cut(load(Game.ASSETS + "Actor/Character/%s/SeparateAnim/Jump.png" % character), Rect2(0, 0, 16, 16))
	else:
		vel.y += 160.0 * delta
		pos += vel * delta
		pos.x = clampf(pos.x, 8, 142)
		if pos.y >= GROUND - 14:
			var caught := absf(pos.x - pad_x) <= PAD_W / 2.0
			Game.sfx("Sounds/Hit & Impact/Impact2.wav" if caught else "Sounds/Hit & Impact/Hit2.wav", -8.0)
			running = false
			_place()
			if caught:
				win("Gespot!")
			else:
				lose("Au!")
			return
	_place()


func _place() -> void:
	if falling:
		climber.position = (pos - Vector2(8, 0)).round()
	else:
		climber.position.y = pos.y
	pad.position = Vector2(roundf(pad_x - PAD_W / 2.0), GROUND - 2)
	# The shadow shows where they are above, and gets darker as they come down.
	shadow.position = Vector2(roundf(pos.x - 4), GROUND - 4)
	shadow.modulate.a = 0.4 + 0.6 * clampf(pos.y / GROUND, 0.0, 1.0)
