extends Microgame
## PINCH: squeeze a tufa between both hands. Holding left / right squeezes that hand.
## The hold tips over towards the weaker hand, and your body keeps shoving it
## sideways, so keep both hands in balance.

const BLOCK_POS := Vector2(66, 14)
const BLOCK := Vector2i(18, 50)
const SQUEEZE_RATE := 1.4
const RELAX_RATE := 0.9  # slow, so letting go of a key does not tip it over at once
const ZONE := 0.45

var left := 0.0
var right := 0.0
var tilt := 0.0
var push := 0.0
var push_timer := 0.8
var off_balance := 0.0
var block: Sprite2D
var hand_l: Sprite2D
var hand_r: Sprite2D
var needle: ColorRect
var rng := RandomNumberGenerator.new()


func setup() -> void:
	word = "PINCH!"
	keys = ["KeyLeft", "KeyRight"]
	duration = 4.5
	survive_wins = true
	rng.seed = seed_value
	add_rock_background()
	block = PixelArt.sprite(_tufa(), BLOCK_POS, stage)
	var hand := make_hand(false).get_image()
	var img_l := hand.duplicate()
	img_l.rotate_90(CLOCKWISE)  # fingers point right, arm goes off to the left
	var img_r := hand.duplicate()
	img_r.rotate_90(COUNTERCLOCKWISE)
	hand_l = PixelArt.sprite(ImageTexture.create_from_image(img_l), Vector2.ZERO, stage)
	hand_r = PixelArt.sprite(ImageTexture.create_from_image(img_r), Vector2.ZERO, stage)

	# Balance gauge across the top: keep the needle in the green.
	var back := ColorRect.new()
	back.color = PixelArt.OUTLINE
	back.position = Vector2(90, 6)
	back.size = Vector2(120, 8)
	ui.add_child(back)
	var green := ColorRect.new()
	green.color = Color("7fbf5a")
	green.position = Vector2(2 + 58 * (1.0 - ZONE), 2)
	green.size = Vector2(116 * ZONE, 4)
	back.add_child(green)
	needle = ColorRect.new()
	needle.color = Color("fff6e4")
	needle.size = Vector2(2, 12)
	ui.add_child(needle)
	hint("houd links en rechts allebei vast  -  in balans", "KeyLeft")
	_place()


func tick(delta: float) -> void:
	left = _squeeze(left, Input.is_action_pressed("move_left"), delta)
	right = _squeeze(right, Input.is_action_pressed("move_right"), delta)
	push_timer -= delta
	if push_timer <= 0.0:
		push = rng.randf_range(-1.0, 1.0) * 0.6 * speed
		push_timer = rng.randf_range(0.6, 1.1) / speed
	# The tufa tips towards the weaker hand; letting go of both makes it slip.
	tilt += ((left - right) * 0.9 + push * (1.2 - (left + right) * 0.4)) * delta
	tilt = clampf(tilt, -1.2, 1.2)
	if absf(tilt) > ZONE or left + right < 0.5:
		off_balance += delta if _elapsed > 0.8 else 0.0
	else:
		off_balance = maxf(0.0, off_balance - delta * 0.5)
	_place()
	if absf(tilt) >= 1.0 or off_balance > 0.7:
		lose("Gekanteld!")


func _squeeze(value: float, held: bool, delta: float) -> float:
	return minf(1.0, value + SQUEEZE_RATE * delta) if held else maxf(0.0, value - RELAX_RATE * delta)


func _place() -> void:
	var shift := roundf(tilt * 6.0)
	block.position = BLOCK_POS + Vector2(shift, 0)
	# A squeezing hand presses into the tufa; a relaxed one hangs loose.
	hand_l.position = Vector2(BLOCK_POS.x + shift - 70 + roundf(left * 3.0), 30)
	hand_r.position = Vector2(BLOCK_POS.x + BLOCK.x + shift - 1 - roundf(right * 3.0), 30)
	needle.position = Vector2(150 + tilt / 1.2 * 58 - 1, 4)


## A rounded vertical tufa, lit from the left.
func _tufa() -> ImageTexture:
	return PixelArt.shape(BLOCK, shades, func(x: int, y: int) -> int:
		var nx := (x - BLOCK.x / 2.0) / (BLOCK.x / 2.0)
		var edge := 0.75 + 0.25 * sin(y * 0.35)  # wavy outline
		if absf(nx) > edge: return -1
		if absf(nx) > edge - 0.12 or y == 0 or y == BLOCK.y - 1: return 9
		var light := -nx * 0.9 + (PixelArt.bayer(x, y) - 0.5) * 0.5
		return clampi(int((light + 1.0) * 1.8), 0, 3))
