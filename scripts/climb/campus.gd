extends Microgame
## 1-5-9 on the campus board, as a record attempt rather than pass/fail.
## For each hand: mash Z and X in turns to charge up (like the mantle). After a
## short "ready" the marker rises; stop it with Z exactly at the top, like the
## power move. Power x timing decides how many rungs you go up (at most 4):
## only a full charge and a spot-on stop gives the 9; a weaker go is 1-3-6 or so.

const RUNG_GAP := 7.4
const CHARGE_TIME := 1.6
const READY_TIME := 0.6  # pause between mashing and the timing press
const AIM_TIME := 0.7  # marker goes up to the top in this time, then back down
const MAX_GAIN := 4

var rungs := [1, 1]  # rung each hand is on
var hand := 0  # 0 = left, 1 = right
var stage_phase := "charge"  # charge, ready, aim, move, done
var next_key := "action_a"
var power := 0.0
var marker := 0.0
var phase_time := 0.0
var hands: Array[Sprite2D] = []
var power_fill: ColorRect
var aim_marker: ColorRect
var score: Label
var call_out: Label


func setup() -> void:
	word = "1 - 5 - 9!"
	keys = ["KeyZ", "KeyX"]
	duration = 11.0  # long enough for both hands; you never run out of time
	survive_wins = true
	shades = [Color("6b4a32"), Color("8a6142"), Color("a87a52"), Color("c79a6a")]
	PixelArt.sprite(PixelArt.plywood(Vector2i(STAGE), seed_value), Vector2.ZERO, stage)
	for i in range(1, 10):
		PixelArt.sprite(_rung(), Vector2(30, _rung_y(i)), stage)
		var n := label_at(str(i), Vector2(40, _rung_y(i) * 2 - 6), Game.FONT_TITLE, 8)
		n.add_theme_color_override("font_color", Color("fff6e4") if i in [5, 9] else Color("cdbfa6"))
	for x in [56, 78]:
		hands.append(PixelArt.sprite(make_hand(false), Vector2(x, 0), stage))

	# Meter on the right: yellow = power you charged, red line = timing marker.
	label_at("KRACHT", Vector2(256, 4), Game.FONT_TITLE, 8)
	var back := ColorRect.new()
	back.color = PixelArt.OUTLINE
	back.position = Vector2(266, 16)
	back.size = Vector2(12, 120)
	ui.add_child(back)
	power_fill = ColorRect.new()
	power_fill.color = Color("f2cf3a")
	power_fill.position = Vector2(2, 118)
	power_fill.size = Vector2(8, 0)
	back.add_child(power_fill)
	var top := ColorRect.new()
	top.color = Color("fff6e4")
	top.position = Vector2(-4, 1)
	top.size = Vector2(20, 2)
	back.add_child(top)
	aim_marker = ColorRect.new()
	aim_marker.color = Color("d9453c")
	aim_marker.size = Vector2(20, 3)
	aim_marker.visible = false
	back.add_child(aim_marker)
	score = label_at("1", Vector2(250, 140), Game.FONT_TITLE, 8)
	call_out = label_at("", Vector2(150, 4), Game.FONT_TITLE, 8)
	hint("Z en X rammen = laden,  dan Z precies bovenaan")
	_call("RAMMEN!")
	_place()


func _rung_y(rung: float) -> float:
	return 66.0 - (rung - 1.0) * RUNG_GAP


func _call(text: String) -> void:
	call_out.text = text


func _input(event: InputEvent) -> void:
	if not running:
		return
	if stage_phase == "charge":
		for action in ["action_a", "action_b"]:
			if event.is_action_pressed(action):
				power = minf(1.0, power + (0.09 if action == next_key else 0.03))
				next_key = "action_b" if action == "action_a" else "action_a"
	elif stage_phase == "aim" and event.is_action_pressed("action_a"):
		var off := absf(1.0 - marker)
		_reach(1.0 if off < 0.03 else clampf(1.0 - off * 2.5, 0.1, 0.9))


func tick(delta: float) -> void:
	phase_time += delta
	match stage_phase:
		"charge":
			if power < 1.0:  # a full meter stays full
				power = maxf(0.0, power - 0.2 * delta)
			if phase_time >= CHARGE_TIME:
				stage_phase = "ready"
				phase_time = 0.0
				_call("KLAAR...")
		"ready":
			if phase_time >= READY_TIME:
				stage_phase = "aim"
				phase_time = 0.0
				marker = 0.0
				aim_marker.visible = true
				_call("STOP BOVENIN!")
		"aim":
			# Up to the top, then back down again; no press at all is a weak slap.
			var t := phase_time * speed / AIM_TIME
			marker = t if t <= 1.0 else 2.0 - t
			if t >= 2.0:
				_reach(0.1)
	power_fill.size.y = roundf(116 * power)
	power_fill.position.y = 2 + 116 - power_fill.size.y
	aim_marker.position = Vector2(-4, 2 + 116 * (1.0 - clampf(marker, 0.0, 1.0)) - 1)


func _reach(quality: float) -> void:
	stage_phase = "move"
	aim_marker.visible = false
	var from: int = rungs[0] if hand == 1 else 1
	# Rounded down: only a full charge with a spot-on stop gives all 4 rungs.
	var gain := clampi(floori(MAX_GAIN * power * quality + 0.02), 0, MAX_GAIN)
	_call("")
	rungs[hand] = from + gain
	Game.sfx("Sounds/Hit & Impact/Hit3.wav", -10.0)
	var tween := create_tween()
	tween.tween_property(hands[hand], "position:y", roundf(_rung_y(rungs[hand])) - 2, 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.3)
	tween.tween_callback(_next_hand)
	var reached := ["1"]
	for i in hand + 1:
		reached.append(str(rungs[i]))
	score.text = " - ".join(PackedStringArray(reached))


func _next_hand() -> void:
	if hand == 0:
		hand = 1
		stage_phase = "charge"
		phase_time = 0.0
		power = 0.0
		next_key = "action_a"
		_call("RAMMEN!")
		return
	stage_phase = "done"
	Game.campus_last = [1, rungs[0], rungs[1]]
	win("%d - %d - %d" % Game.campus_last)


func _place() -> void:
	for i in hands.size():
		hands[i].position.y = roundf(_rung_y(rungs[i])) - 2


## A wooden campus rung: thin slat with a rounded lip.
func _rung() -> ImageTexture:
	return PixelArt.shape(Vector2i(90, 4), shades, func(x: int, y: int) -> int:
		if y == 0 or y == 3: return 9
		return 3 if y == 1 else 1)
