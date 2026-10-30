extends Microgame
## HAK!: your leg swings up and down next to a ledge. Press A when the heel is
## level with the ledge to hook it, then keep holding A to pull yourself in.
## Good shoes make the hooking window bigger. Close-up: only the lower leg shows,
## coming in from the side like the arms in the other moves.

const BOY := "Actor/Character/Boy/SeparateAnim/"
const LEDGE := Vector2(92, 42)  # top-left of the ledge
const SHIN_LEN := 90
const HEEL_SPOT := Vector2(SHIN_LEN + 6, 14)  # bottom of the heel inside the leg sprite

var phase := 0.0
var heel_y := 50.0
var window := 4.0
var hooked := false
var pull := 0.0
var off_time := 0.0
var leg: Sprite2D
var bar: ColorRect


func setup() -> void:
	word = "HAK!"
	duration = 4.5
	survive_wins = false
	window = 10.0 if Game.has_gear("shoes") else 7.0
	add_rock_background()
	PixelArt.sprite(_ledge(), LEDGE, stage)
	# A chalk mark shows where the heel should go.
	PixelArt.sprite(PixelArt.from_rows(["w.w.w"], {"w": PixelArt.CHALK}), LEDGE + Vector2(4, -2), stage)
	leg = PixelArt.sprite(_leg(), Vector2.ZERO, stage)

	var back := ColorRect.new()
	back.color = PixelArt.OUTLINE
	back.position = Vector2(70, 128)
	back.size = Vector2(160, 8)
	ui.add_child(back)
	bar = ColorRect.new()
	bar.color = Color("f2cf3a")
	bar.position = Vector2(2, 2)
	bar.size = Vector2(0, 4)
	back.add_child(bar)
	hint("Z als je hiel bij de richel is,  dan vasthouden")
	_place()


func tick(delta: float) -> void:
	if not hooked:
		phase += delta * 2.5 * speed
		heel_y = 40.0 + sin(phase) * 28.0
		_place()
		if Input.is_action_just_pressed("action_a"):
			if absf(heel_y - LEDGE.y) <= window:
				hooked = true
				heel_y = LEDGE.y
				Game.sfx("Sounds/Jump & Bounce/Bounce.wav", -10.0)
				_place()
			else:
				lose("Mis!")
		return
	# Hooked: pull in by holding A. Letting go too long unhooks the heel.
	if Input.is_action_pressed("action_a"):
		pull += delta / 1.1
		off_time = 0.0
	else:
		off_time += delta
		pull = maxf(0.0, pull - delta * 0.4)
	bar.size.x = roundf(156 * minf(pull, 1.0))
	if off_time > 0.4:
		lose("Hak geschoten!")
	elif pull >= 1.0:
		win("Hak erin!")


func _place() -> void:
	leg.position = Vector2(LEDGE.x + 4, roundf(heel_y)) - HEEL_SPOT


## The climbing shoe from the footwork move, turned so the heel points down and
## the toe up, with the shin running off to the left edge of the panel.
func _leg() -> ImageTexture:
	var palette := PixelArt.SKIN.duplicate()
	palette["r"] = Color("c8463d")
	palette["k"] = Color("3a3040")
	var shoe := PixelArt.from_rows(preload("res://scripts/climb/footwork.gd").SHOE, palette).get_image()
	shoe.rotate_90(COUNTERCLOCKWISE)
	var img := Image.create(SHIN_LEN + shoe.get_width(), shoe.get_height(), false, Image.FORMAT_RGBA8)
	var pants := Color("3d4a7a")
	for x in SHIN_LEN + 2:
		for y in range(7, 14):
			img.set_pixel(x, y, PixelArt.OUTLINE if y == 7 or y == 13 else (pants.lightened(0.15) if y == 8 else pants))
	img.blend_rect(shoe, Rect2i(Vector2i.ZERO, shoe.get_size()), Vector2i(SHIN_LEN, 0))
	return ImageTexture.create_from_image(img)


func _ledge() -> ImageTexture:
	return PixelArt.shape(Vector2i(30, 8), shades, func(x: int, y: int) -> int:
		if x == 29 and y < 2: return -1
		if y == 0: return 9
		if y <= 2: return 3
		if y <= 3: return 2
		if y == 4: return 9
		return 0 if PixelArt.bayer(x, y) < 1.0 - (y - 4) / 4.0 else -1)
