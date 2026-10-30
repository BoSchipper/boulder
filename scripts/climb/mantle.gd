extends Microgame
## MANTLE: the final push onto the top. Mash A and B in turns to press yourself up.

const BOY := "Actor/Character/Boy/SeparateAnim/"
const LIP_Y := 46
const LOW_Y := 40.0  # climber sprite top at the start (only the head shows)
const HIGH_Y := 30.0  # standing on top

var progress := 0.0
var next_key := "action_a"
var climber: Sprite2D
var walk_up: Array = []
var bar: ColorRect
var key_a: TextureRect
var key_b: TextureRect
var step := 0


func setup() -> void:
	word = "DRUK!"
	keys = ["KeyZ", "KeyX"]
	duration = 4.5
	survive_wins = false
	if indoor:
		_ceiling()
	else:
		_sky()
	var walk: Texture2D = load(Game.ASSETS + BOY + "Walk.png")
	for row in 4:
		walk_up.append(ActorSprite._cut(walk, Rect2(16, row * 16, 16, 16)))
	climber = PixelArt.sprite(walk_up[0], Vector2(67, LOW_Y), stage)
	# The top of the boulder sits in front of the climber.
	var lip_tex := PixelArt.plywood(Vector2i(150, 85 - LIP_Y), seed_value) if indoor else PixelArt.rock(Vector2i(150, 85 - LIP_Y), shades, seed_value)
	var lip := PixelArt.sprite(lip_tex, Vector2(0, LIP_Y), stage)
	var edge := ColorRect.new()
	edge.color = PixelArt.OUTLINE
	edge.size = Vector2(150, 1)
	lip.add_child(edge)
	var lit := ColorRect.new()
	lit.color = Color("d8ccb4") if indoor else shades[3]
	lit.position = Vector2(0, 1)
	lit.size = Vector2(150, 2)
	lip.add_child(lit)
	for x in [62, 81]:  # hands on the lip
		PixelArt.sprite(PixelArt.from_rows([".ooooo.", "owwwwwo", "ossssso", ".ooooo."], PixelArt.SKIN), Vector2(x, LIP_Y - 2), stage)

	key_a = TextureRect.new()
	key_a.texture = load(Game.ASSETS + "Ui/Input/Keyboard/KeyZ.png")
	key_a.position = Vector2(124, 120)
	ui.add_child(key_a)
	key_b = TextureRect.new()
	key_b.texture = load(Game.ASSETS + "Ui/Input/Keyboard/KeyX.png")
	key_b.position = Vector2(162, 120)
	ui.add_child(key_b)
	var back := ColorRect.new()
	back.color = PixelArt.OUTLINE
	back.position = Vector2(70, 138)
	back.size = Vector2(160, 8)
	ui.add_child(back)
	bar = ColorRect.new()
	bar.color = Color("f2cf3a")
	bar.position = Vector2(2, 2)
	bar.size = Vector2(0, 4)
	back.add_child(bar)
	hint("Z en X om de beurt rammen!")


## Every press counts (read from input events, so no fast tap is missed);
## switching between Z and X counts double.
func _input(event: InputEvent) -> void:
	if not running:
		return
	for action in ["action_a", "action_b"]:
		if event.is_action_pressed(action):
			progress += 0.1 if action == next_key else 0.07
			next_key = "action_b" if action == "action_a" else "action_a"
			step += 1
			climber.texture = walk_up[step % 4]


func tick(delta: float) -> void:
	progress = maxf(0.0, progress - 0.18 * speed * delta)
	climber.position.y = roundf(lerpf(LOW_Y, HIGH_Y, minf(progress, 1.0)))
	bar.size.x = roundf(156 * minf(progress, 1.0))
	# Blink the key to press next.
	var blink := Engine.get_frames_drawn() % 16 < 10
	key_a.modulate.a = 1.0 if next_key == "action_a" and blink else 0.45
	key_b.modulate.a = 1.0 if next_key == "action_b" and blink else 0.45
	if progress >= 1.0:
		running = false
		climber.texture = ActorSprite._cut(load(Game.ASSETS + BOY + "Item.png"), Rect2(0, 0, 16, 16))
		climber.position.y = HIGH_Y - 1
		var tween := create_tween()
		tween.tween_interval(0.35)
		tween.tween_callback(win.bind("Top!"))


## Indoors: a dark gym roof with strip lights instead of sky.
func _ceiling() -> void:
	var img := Image.create(150, LIP_Y, false, Image.FORMAT_RGBA8)
	for y in LIP_Y:
		for x in 150:
			var c := Color("3a3944") if (x / 6 + y / 6) % 2 == 0 else Color("34333d")
			if y >= 8 and y <= 10 and (x % 50) > 10 and (x % 50) < 40:
				c = Color("f4f6e8")  # strip light
			elif y > 10 and y < 14 and (x % 50) > 10 and (x % 50) < 40 and PixelArt.bayer(x, y) < 0.3:
				c = Color("6a6a70")
			img.set_pixel(x, y, c)
	PixelArt.sprite(ImageTexture.create_from_image(img), Vector2.ZERO, stage)


func _sky() -> void:
	var sky := Image.create(150, LIP_Y, false, Image.FORMAT_RGBA8)
	var blues := [Color("8fd0ec"), Color("a9dcef"), Color("c6e8f2")]
	for y in LIP_Y:
		for x in 150:
			var t := float(y) / LIP_Y * 2.99 + (PixelArt.bayer(x, y) - 0.5) * 0.6
			sky.set_pixel(x, y, blues[clampi(int(t), 0, 2)])
	# a couple of clouds
	for c in [Vector3(28, 10, 9), Vector3(40, 12, 7), Vector3(112, 18, 8), Vector3(122, 16, 6)]:
		for y in range(int(c.y - c.z), int(c.y + c.z)):
			for x in range(int(c.x - c.z * 1.6), int(c.x + c.z * 1.6)):
				var d := pow((x - c.x) / (c.z * 1.6), 2) + pow((y - c.y) / c.z, 2)
				if d < 1.0 and y < c.y + 2 and x >= 0 and x < 150 and y >= 0:
					sky.set_pixel(x, y, Color("f7fbfb") if d < 0.75 else Color("e4f1f5"))
	# distant treetops
	for x in 150:
		var top := LIP_Y - 5 - int(2.5 + 2.5 * sin(x * 0.35) + 1.5 * sin(x * 0.11))
		for y in range(maxi(top, 0), LIP_Y):
			sky.set_pixel(x, y, Color("5d8f4a") if y > top else Color("3f6b3a"))
	PixelArt.sprite(ImageTexture.create_from_image(sky), Vector2.ZERO, stage)
