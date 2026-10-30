extends Microgame
## DYNO: the climber swings to load up; press A while the meter is in the
## green zone to jump to the jug. One try.

const BOY := "Actor/Character/Boy/SeparateAnim/"
const HANG_POS := Vector2(67, 44)
const JUG_POS := Vector2(66, 6)

var phase := 0.0
var power := 0.0
var zone := 0.24
var jumped := false
var climber: Sprite2D
var meter: ColorRect
var zone_rect: ColorRect


func setup() -> void:
	word = "SPRING!"
	duration = 3.6
	survive_wins = false
	zone = clampf(0.24 - (speed - 1.0) * 0.14, 0.12, 0.24)
	add_rock_background()
	PixelArt.sprite(_jug(), JUG_POS, stage)
	PixelArt.sprite(_edge(), Vector2(56, 52), stage)
	PixelArt.sprite(_edge(), Vector2(76, 52), stage)
	climber = PixelArt.sprite(ActorSprite._cut(load(Game.ASSETS + BOY + "Idle.png"), Rect2(16, 0, 16, 16)), HANG_POS, stage)
	label_at("KRACHT", Vector2(2, 4), Game.FONT_TITLE, 8)
	meter = make_meter(Vector2(14, 16), 120)
	zone_rect = ColorRect.new()
	zone_rect.color = Color(0.5, 0.85, 0.35, 0.45)
	zone_rect.size = Vector2(10, roundf(116 * zone))
	zone_rect.position = Vector2(14, 18)
	ui.add_child(zone_rect)
	hint("druk als de meter in het groen staat")


func tick(delta: float) -> void:
	if jumped:
		return
	phase += delta * 4.2 * speed
	power = 0.5 - 0.5 * cos(phase)
	set_meter(meter, power, Color("f2cf3a"))
	# Lower body = more loaded.
	climber.position = HANG_POS + Vector2(roundf(sin(phase * 0.5) * 3.0), roundf(power * 5.0))
	if Input.is_action_just_pressed("action_a"):
		_jump(power >= 1.0 - zone)


func _jump(good: bool) -> void:
	jumped = true
	climber.texture = ActorSprite._cut(load(Game.ASSETS + BOY + "Jump.png"), Rect2(16, 0, 16, 16))
	Game.sfx("Sounds/Jump & Bounce/Jump.wav", -8.0)
	var tween := create_tween()
	if good:
		tween.tween_property(climber, "position", JUG_POS + Vector2(1, 4), 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(func(): climber.texture = ActorSprite._cut(load(Game.ASSETS + BOY + "Idle.png"), Rect2(16, 0, 16, 16)))
		tween.tween_interval(0.2)
		tween.tween_callback(win.bind("Raak!"))
	else:
		var peak := climber.position + Vector2(0, -16 if power > 0.5 else -6)
		tween.tween_property(climber, "position", peak, 0.2).set_ease(Tween.EASE_OUT)
		tween.tween_property(climber, "position", peak + Vector2(0, 70), 0.35).set_ease(Tween.EASE_IN)
		tween.tween_callback(lose.bind("Mis!" if power > 0.5 else "Te zwak!"))


## A big incut jug: rounded lip with a dark pocket.
func _jug() -> ImageTexture:
	return PixelArt.shape(Vector2i(19, 9), shades, func(x: int, y: int) -> int:
		var nx := (x - 9.0) / 9.5
		var ny := (y - 4.0) / 4.5
		var d := nx * nx + ny * ny
		if d > 1.0: return -1
		if d > 0.75: return 9
		if y >= 4 and absf(nx) < 0.7: return 9 if y == 4 else 0
		return 3 if y <= 1 else 2)


func _edge() -> ImageTexture:
	return PixelArt.shape(Vector2i(16, 5), shades, func(x: int, y: int) -> int:
		if (x == 0 or x == 15) and y == 0: return -1
		if y == 0 or y == 3: return 9
		if y == 4: return 0 if PixelArt.bayer(x, y) < 0.5 else -1
		return 3 if y == 1 else 2)
