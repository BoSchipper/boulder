extends Microgame
## ONTHOUD!: the holds light up in the order of the beta. Then climb it:
## press the arrows in the same order. One wrong hold and you are off.

const BOY := "Actor/Character/Boy/SeparateAnim/"
const DIRS := ["up", "left", "right", "down"]
const ACTIONS := {"up": "move_up", "left": "move_left", "right": "move_right", "down": "move_down"}
const HOLD_POS := {"up": Vector2(66, 6), "left": Vector2(28, 36), "right": Vector2(104, 36), "down": Vector2(66, 64)}

var sequence: Array = []
var holds := {}
var climber: Sprite2D
var showing := true
var step := 0
var label: Label
var interval := 0.5
var started := false
var rng := RandomNumberGenerator.new()


func setup() -> void:
	word = "ONTHOUD!"
	keys = ["KeyUp", "KeyLeft", "KeyRight", "KeyDown"]
	survive_wins = false
	rng.seed = seed_value
	var length := 3 + int((speed - 1.0) / 0.25)
	for i in length:
		var options := DIRS.filter(func(d): return sequence.is_empty() or d != sequence[-1])
		sequence.append(options[rng.randi() % options.size()])
	interval = 0.55 / sqrt(speed)
	# The clock covers the demo plus time to replay every hold.
	duration = length * interval + 1.2 + length * 0.7
	add_rock_background()
	for d in DIRS:
		holds[d] = PixelArt.sprite(_jug(), HOLD_POS[d], stage)
	climber = PixelArt.sprite(ActorSprite._cut(load(Game.ASSETS + BOY + "Idle.png"), Rect2(16, 0, 16, 16)), Vector2(67, 32), stage)
	label = label_at("Kijk goed...", Vector2(118, 4), Game.FONT_TITLE, 8)
	hint("onthoud de volgorde,  speel hem na met de pijltjes", "KeyUp")


func tick(_delta: float) -> void:
	# The demo starts once the instruction word is gone, so you can see it.
	if not started:
		started = true
		_demo()


func _demo() -> void:
	var tween := create_tween()
	tween.tween_interval(0.3)
	for d in sequence:
		tween.tween_callback(_light.bind(d, true))
		tween.tween_callback(Game.sfx.bind("Sounds/Menu/Move3.wav", -12.0))
		tween.tween_interval(interval * 0.7)
		tween.tween_callback(_light.bind(d, false))
		tween.tween_interval(interval * 0.3)
	tween.tween_callback(func():
		showing = false
		label.text = "Jouw beurt!")


func _light(d: String, on: bool) -> void:
	holds[d].modulate = Color(1.9, 1.9, 1.7) if on else Color.WHITE


func _input(event: InputEvent) -> void:
	if not running or showing:
		return
	for d in DIRS:
		if event.is_action_pressed(ACTIONS[d]):
			_light(d, true)
			get_tree().create_timer(0.15).timeout.connect(_light.bind(d, false))
			climber.position = Vector2(67, 32) + (HOLD_POS[d] - Vector2(66, 32)) * 0.25
			if d != sequence[step]:
				lose("Verkeerde greep!")
				return
			step += 1
			Game.sfx("Sounds/Menu/Accept2.wav", -12.0)
			if step >= sequence.size():
				win("Beta klopt!")
			return


## A big jug, same as on the dyno.
func _jug() -> ImageTexture:
	return PixelArt.shape(Vector2i(19, 9), shades, func(x: int, y: int) -> int:
		var nx := (x - 9.0) / 9.5
		var ny := (y - 4.0) / 4.5
		var d := nx * nx + ny * ny
		if d > 1.0: return -1
		if d > 0.75: return 9
		if y >= 4 and absf(nx) < 0.7: return 9 if y == 4 else 0
		return 3 if y <= 1 else 2)
