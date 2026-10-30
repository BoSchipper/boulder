extends Microgame
## POWER!: a comp-style jump, timed like a golf swing. Three presses of A:
## 1) start the swing, 2) stop the power in the orange zone,
## 3) on the way back, hit the white line for a straight jump.

const BOY := "Actor/Character/Boy/SeparateAnim/"
const START := Vector2(28, 58)
const JUG := Vector2(108, 10)
const BAR := Rect2(50, 8, 200, 10)  # in ui coordinates, along the top
const ACCURACY_AT := 0.08  # where the white line sits on the bar
const ACCURACY_TOL := 0.06

var phase := 0  # 0 waiting, 1 power going up, 2 coming back, 3 jumping
var marker := 0.0
var power := 0.0
var zone := Vector2(0.68, 0.86)
var climber: Sprite2D
var marker_rect: ColorRect
var power_fill: ColorRect


func setup() -> void:
	word = "POWER!"
	duration = 5.0
	survive_wins = false
	var narrow := clampf((speed - 1.0) * 0.08, 0.0, 0.06)
	zone = Vector2(0.68 + narrow, 0.86 - narrow)
	add_rock_background()
	PixelArt.sprite(_volume(), Vector2(56, 30), stage)
	PixelArt.sprite(_jug(), JUG, stage)
	climber = PixelArt.sprite(ActorSprite._cut(load(Game.ASSETS + BOY + "Idle.png"), Rect2(16, 0, 16, 16)), START, stage)

	var back := ColorRect.new()
	back.color = PixelArt.OUTLINE
	back.position = BAR.position
	back.size = BAR.size
	ui.add_child(back)
	power_fill = ColorRect.new()
	power_fill.color = Color("f2cf3a")
	power_fill.position = Vector2(2, 2)
	power_fill.size = Vector2(0, BAR.size.y - 4)
	back.add_child(power_fill)
	var target := ColorRect.new()
	target.color = Color(0.95, 0.55, 0.2, 0.85)
	target.position = Vector2(2 + (BAR.size.x - 4) * zone.x, 2)
	target.size = Vector2((BAR.size.x - 4) * (zone.y - zone.x), BAR.size.y - 4)
	back.add_child(target)
	var line := ColorRect.new()
	line.color = Color("fff6e4")
	line.position = Vector2(2 + (BAR.size.x - 4) * ACCURACY_AT - 1, -2)
	line.size = Vector2(2, BAR.size.y + 4)
	back.add_child(line)
	marker_rect = ColorRect.new()
	marker_rect.color = Color("d9453c")
	marker_rect.size = Vector2(3, BAR.size.y + 6)
	ui.add_child(marker_rect)
	hint("Z: start  -  Z: kracht in het oranje  -  Z: op de streep")
	_draw_bar()


func tick(delta: float) -> void:
	var pressed := Input.is_action_just_pressed("action_a")
	match phase:
		0:
			if pressed:
				phase = 1
		1:
			marker += delta * 0.75 * speed
			if pressed or marker >= 1.0:
				power = minf(marker, 1.0)
				phase = 2
		2:
			marker -= delta * 0.85 * speed
			if pressed:
				_jump(absf(marker - ACCURACY_AT) <= ACCURACY_TOL)
			elif marker < -0.02:
				_jump(false)
	_draw_bar()


func _draw_bar() -> void:
	var w := BAR.size.x - 4
	marker_rect.position = BAR.position + Vector2(2 + w * clampf(marker, 0.0, 1.0) - 1, -3)
	power_fill.size.x = roundf(w * (power if phase >= 2 else clampf(marker, 0.0, 1.0)))
	# Swinging back to load up as the power rises.
	if phase == 1:
		climber.position = START + Vector2(-roundf(marker * 4.0), roundf(marker * 3.0))


func _jump(straight: bool) -> void:
	phase = 3
	climber.texture = ActorSprite._cut(load(Game.ASSETS + BOY + "Jump.png"), Rect2(16, 0, 16, 16))
	Game.sfx("Sounds/Jump & Bounce/Jump.wav", -8.0)
	var reason := ""
	if power < zone.x:
		reason = "Te kort!"
	elif power > zone.y:
		reason = "Te ver!"
	elif not straight:
		reason = "Scheef!"
	var land := JUG + Vector2(1, 4)
	if reason == "Te kort!":
		land = START.lerp(JUG, 0.6)
	elif reason == "Te ver!":
		land = JUG + Vector2(16, -8)
	elif reason == "Scheef!":
		land = JUG + Vector2(-18, 6)
	var tween := create_tween()
	var mid := (climber.position + land) / 2.0 + Vector2(0, -14)
	tween.tween_property(climber, "position", mid, 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(climber, "position", land, 0.16).set_ease(Tween.EASE_IN)
	if reason == "":
		tween.tween_interval(0.25)
		tween.tween_callback(win.bind("Gelanceerd!"))
	else:
		tween.tween_property(climber, "position", land + Vector2(0, 80), 0.4).set_ease(Tween.EASE_IN)
		tween.tween_callback(lose.bind(reason))


## A big triangular volume bolted to the wall, in the colour of the holds.
func _volume() -> ImageTexture:
	return PixelArt.shape(Vector2i(40, 34), shades, func(x: int, y: int) -> int:
		if y < 34 - x * 0.85 or x > 39: return -1
		if y == 33 or absf(y - (34 - x * 0.85)) < 1.0 or x == 39: return 9
		return 2 if y < 20 else 1)


func _jug() -> ImageTexture:
	return PixelArt.shape(Vector2i(19, 9), shades, func(x: int, y: int) -> int:
		var nx := (x - 9.0) / 9.5
		var ny := (y - 4.0) / 4.5
		var d := nx * nx + ny * ny
		if d > 1.0: return -1
		if d > 0.75: return 9
		if y >= 4 and absf(nx) < 0.7: return 9 if y == 4 else 0
		return 3 if y <= 1 else 2)
