extends Microgame
## HANG!: hangboard repeaters. Hold A while it says HANG, let go while it says
## RUST. Letting go during a hang fails that rep; hanging on through a rest
## pumps you out. A gym record to beat, never a fail: you get your number of reps.

const REPS := 10  # nobody makes all ten: the pump decides your record
const HANG_TIME := 2.0
const REST_TIME := 1.2
const MAX_OFF := 0.3

var rep := 0
var done_reps := 0
var hanging_phase := true
var phase_time := 0.0
var off_time := 0.0
var rep_failed := false
var pump := 0.0
var hands: Array[Sprite2D] = []
var call_out: Label
var phase_bar: ColorRect
var pump_meter: ColorRect
var rep_dots: Array[ColorRect] = []


func setup() -> void:
	word = "HANG!"
	duration = REPS * (HANG_TIME + REST_TIME) + 1.0
	survive_wins = true
	var wood := [Color("6b4a32"), Color("8a6142"), Color("a87a52"), Color("c79a6a")]
	shades = wood
	PixelArt.sprite(PixelArt.plywood(Vector2i(STAGE), seed_value), Vector2.ZERO, stage)
	PixelArt.sprite(_board(), Vector2(25, 18), stage)
	for x in [52, 82]:
		hands.append(PixelArt.sprite(make_hand(false), Vector2(x, 24), stage))
	call_out = label_at("HANG!", Vector2(120, 6), Game.FONT_TITLE, 16)
	var back := ColorRect.new()
	back.color = PixelArt.OUTLINE
	back.position = Vector2(70, 128)
	back.size = Vector2(160, 8)
	ui.add_child(back)
	phase_bar = ColorRect.new()
	phase_bar.position = Vector2(2, 2)
	phase_bar.size = Vector2(156, 4)
	back.add_child(phase_bar)
	label_at("POMP", Vector2(262, 4), Game.FONT_TITLE, 8)
	pump_meter = make_meter(Vector2(270, 16), 100)
	for i in REPS:
		var dot := ColorRect.new()
		dot.size = Vector2(8, 8)
		dot.position = Vector2(14 + i * 12, 8)
		dot.color = Color("4a3a4a")
		ui.add_child(dot)
		rep_dots.append(dot)
	hint("Z vasthouden bij HANG,  loslaten bij RUST")


func tick(delta: float) -> void:
	if rep >= REPS:
		return
	phase_time += delta
	var holding := Input.is_action_pressed("action_a")
	if hanging_phase:
		if holding:
			off_time = 0.0
			pump += 0.12 * delta
		else:
			off_time += delta
			if off_time > MAX_OFF:
				rep_failed = true
		if phase_time >= HANG_TIME:
			_end_hang()
	else:
		pump += (0.2 if holding else -0.22) * delta  # no rest if you keep hanging
		if phase_time >= REST_TIME:
			hanging_phase = true
			phase_time = 0.0
			off_time = 0.0
			rep_failed = false
			call_out.text = "HANG!"
	pump = clampf(pump, 0.0, 1.0)
	# Hands slide down a little when you let go.
	for h in hands:
		h.position.y = 24 if holding else 30
	var limit := HANG_TIME if hanging_phase else REST_TIME
	phase_bar.size.x = roundf(156 * (1.0 - phase_time / limit))
	phase_bar.color = Color("f2cf3a") if hanging_phase else Color("7fbf5a")
	set_meter(pump_meter, pump, Color("7fbf5a").lerp(Color("d9453c"), pump))
	if pump >= 1.0:
		_finish("Verzuurd!")


func _end_hang() -> void:
	if not rep_failed:
		done_reps += 1
		rep_dots[rep].color = Color("f2cf3a")
		Game.sfx("Sounds/Menu/Accept2.wav", -12.0)
	else:
		rep_dots[rep].color = Color("d9453c")
	rep += 1
	if rep >= REPS:
		_finish("%d van de %d" % [done_reps, REPS])
		return
	hanging_phase = false
	phase_time = 0.0
	call_out.text = "RUST"


func win(_reason := "") -> void:
	_finish("%d van de %d" % [done_reps, REPS])


func _finish(text: String) -> void:
	if _done:
		return
	Game.hang_last = done_reps
	_done = true
	running = false
	finished.emit(true, text)


## A wooden hangboard with two edges and two pockets.
func _board() -> ImageTexture:
	return PixelArt.shape(Vector2i(100, 16), shades, func(x: int, y: int) -> int:
		if y == 0 or y == 15 or x == 0 or x == 99: return 9
		if y == 6 and x > 6 and x < 93: return 9  # the edge you hang on
		if y > 6 and y < 9 and x > 6 and x < 93: return 0  # shadow under the edge
		if y < 6: return 3 if y < 3 else 2
		return 1)
