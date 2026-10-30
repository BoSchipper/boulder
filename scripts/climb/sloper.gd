extends Microgame
## SLOPER: keep your palm on the chalked sweet spot of a round hold.
## The hold keeps pushing you off-centre; steer with left/right.

const CENTER := Vector2(75, 64)
const RADIUS := Vector2(52, 30)
const ZONE := 0.32
const MAX_SLIP := 0.6

var pos := 0.0
var vel := 0.0
var drift := 0.0
var drift_timer := 0.0
var slip := 0.0
var hand: Sprite2D
var sweat: Sprite2D
var meter: ColorRect
var rng := RandomNumberGenerator.new()


func setup() -> void:
	word = "BALANS!"
	keys = ["KeyLeft", "KeyRight"]
	duration = 4.2
	survive_wins = true
	rng.seed = seed_value
	pos = rng.randf_range(-0.1, 0.1)
	add_rock_background()
	PixelArt.sprite(_sloper(), CENTER - RADIUS, stage)
	hand = PixelArt.sprite(make_hand(true), Vector2.ZERO, stage)
	sweat = PixelArt.sprite(PixelArt.from_rows([".b.", "bbb", "bwb", ".b."], {"b": Color("5fa8e0"), "w": Color("dff1ff")}), Vector2.ZERO, stage)
	label_at("GRIP", Vector2(262, 4), Game.FONT_TITLE, 8)
	meter = make_meter(Vector2(270, 16), 120)
	hint("links / rechts  -  blijf op het magnesium", "KeyLeft")
	set_meter(meter, 1.0, Color("7fbf5a"))
	sweat.visible = false
	_place_hand()


func tick(delta: float) -> void:
	drift_timer -= delta
	if drift_timer <= 0.0:
		drift = rng.randf_range(-1.0, 1.0) * 1.8 * speed
		drift_timer = rng.randf_range(0.35, 0.7) / speed
	var steer := Input.get_axis("move_left", "move_right")
	# Off-centre the sloper pushes you further away: an unstable balance.
	vel += (drift + pos * 2.2 * speed + steer * 4.2) * delta
	vel *= 1.0 - 2.5 * delta
	pos += vel * delta
	if absf(pos) > ZONE and _elapsed > 0.6:  # a moment to find your balance first
		slip += delta
	else:
		slip = maxf(0.0, slip - delta * 0.5)
	_place_hand()
	sweat.visible = absf(pos) > ZONE and Engine.get_frames_drawn() % 10 < 6
	var grip := 1.0 - slip / MAX_SLIP
	set_meter(meter, grip, Color("d9453c").lerp(Color("7fbf5a"), grip))
	if absf(pos) >= 1.0 or slip >= MAX_SLIP:
		lose("Weggegleden!")


func _place_hand() -> void:
	var x := CENTER.x + pos * (RADIUS.x - 10)
	var nx := (x - CENTER.x) / RADIUS.x
	var surface := CENTER.y - RADIUS.y * sqrt(maxf(0.0, 1.0 - nx * nx))
	hand.position = Vector2(roundf(x) - 8, roundf(surface) - 3)
	sweat.position = hand.position + Vector2(18, -4)


## A big rounded dome, lit from the top left, with a chalked sweet spot on top.
func _sloper() -> ImageTexture:
	var size := Vector2i(RADIUS * 2) + Vector2i(1, 1)
	return PixelArt.shape(size, shades, func(x: int, y: int) -> int:
		var nx := (x - RADIUS.x) / RADIUS.x
		var ny := (y - RADIUS.y) / RADIUS.y
		var d := nx * nx + ny * ny
		if ny > 0.0:
			# dithered shadow under the dome
			return 0 if d < 1.0 and ny < 0.45 and PixelArt.bayer(x, y) < 0.8 - ny * 1.8 else -1
		if d > 1.0: return -1
		if d > 0.9: return 9
		var light := -nx * 0.45 - ny * 0.9
		var idx := clampi(int((light + 0.35) * 2.6 + PixelArt.bayer(x, y) * 0.8), 0, 3)
		# the chalked sweet spot
		if absf(nx) < ZONE * 0.75 and ny < -0.55 and PixelArt.bayer(x, y) < 0.5:
			return 8
		return idx)
