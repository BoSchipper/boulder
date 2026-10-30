extends Microgame
## CRIMP: holding A squeezes harder (open hand -> half crimp -> full crimp).
## The hold asks for a changing amount of grip (body swings, feet cut): stay
## above the white line or you slip, but squeezing hard pumps you out fast.

const LEDGE_POS := Vector2(43, 30)
const SQUEEZE_RATE := 1.15
const RELAX_RATE := 1.5
const MAX_SLIP := 0.5
const GRACE := 1.2  # seconds at the start to grab the hold before it starts asking for grip

var grip := 0.0
var demand := 0.0
var demand_target := 0.25
var demand_timer := GRACE
var pump := 0.0
var slip := 0.0
var hands: Array[Sprite2D] = []
var grip_meter: ColorRect
var demand_line: ColorRect
var pump_meter: ColorRect
var rng := RandomNumberGenerator.new()


func setup() -> void:
	word = "KNIJP!"
	duration = 5.0
	survive_wins = true
	rng.seed = seed_value
	add_rock_background()
	PixelArt.sprite(_ledge(), LEDGE_POS, stage)
	for rows in [HAND_OPEN, HAND_HALF, HAND_FULL]:
		hands.append(PixelArt.sprite(make_hand_rows(rows), Vector2(67, LEDGE_POS.y - 1), stage))
	hands[0].position.y += 2
	label_at("GRIP", Vector2(236, 4), Game.FONT_TITLE, 8)
	grip_meter = make_meter(Vector2(242, 16), 120)
	demand_line = ColorRect.new()
	demand_line.color = Color("fff6e4")
	demand_line.size = Vector2(16, 2)
	ui.add_child(demand_line)
	label_at("POMP", Vector2(266, 4), Game.FONT_TITLE, 8)
	pump_meter = make_meter(Vector2(272, 16), 120)
	hint("vasthouden = harder knijpen  -  blijf boven de streep")
	_draw_ui()


func tick(delta: float) -> void:
	if Input.is_action_pressed("action_a"):
		grip = minf(1.0, grip + SQUEEZE_RATE * delta)
	else:
		grip = maxf(0.0, grip - RELAX_RATE * delta)
	demand_timer -= delta
	if demand_timer <= 0.0:
		demand_target = clampf(rng.randf_range(0.15, 0.85) * (0.9 + 0.1 * speed), 0.1, 0.9)
		demand_timer = rng.randf_range(0.9, 1.4) / speed
	# Never faster than you can squeeze (SQUEEZE_RATE), or it would be unfair.
	if _elapsed > GRACE * 0.5:
		demand = move_toward(demand, demand_target, delta * minf(0.4 * speed, 0.7))
	# Squeezing hard pumps you out much faster than a relaxed grip.
	pump += (grip * grip * 0.28 * sqrt(speed) - maxf(0.0, 0.5 - grip) * 0.5) * delta
	pump = maxf(pump, 0.0)
	if grip < demand and _elapsed > GRACE:
		slip += delta
	else:
		slip = maxf(0.0, slip - delta)
	_draw_ui()
	if pump >= 1.0:
		lose("Verzuurd!")
	elif slip >= MAX_SLIP:
		lose("Weggegleden!")


func _draw_ui() -> void:
	var stage_idx := 0 if grip < 0.34 else (1 if grip < 0.67 else 2)
	for i in hands.size():
		hands[i].visible = i == stage_idx
	# A slipping hand slides down a pixel; a pumped hand shakes.
	var shake := 1.0 if pump > 0.65 and Engine.get_frames_drawn() % 4 < 2 else 0.0
	hands[stage_idx].position.x = 67 + shake
	var low := grip < demand
	set_meter(grip_meter, grip, Color("d9453c") if low else Color("f2cf3a"))
	demand_line.position = Vector2(239, 16 + 2 + roundf(116 * (1.0 - demand)) - 1)
	demand_line.visible = not low or Engine.get_frames_drawn() % 8 < 5
	set_meter(pump_meter, pump, Color("7fbf5a").lerp(Color("d9453c"), pump))


## A thin horizontal edge: lit top, shadow underneath.
func _ledge() -> ImageTexture:
	return PixelArt.shape(Vector2i(64, 10), shades, func(x: int, y: int) -> int:
		if (x == 0 or x == 63) and y < 2: return -1
		if y == 0: return 9
		if y <= 2: return 3
		if y <= 4: return 2
		if y == 5: return 9
		# soft dithered shadow under the edge
		return 0 if PixelArt.bayer(x, y) < 1.0 - (y - 5) / 5.0 else -1)


const HAND_HALF := [
	".ooo.ooo.ooo.ooo.",
	"owwwowwwowwwowwwo",
	"olssolssolssolsso",
	"osssosssosssososo",
	"odssodssodssodsdo",
	"odddddddddddddddo",
	"olsssssssssssssdo",
	"olsssssssssssssdo",
	"osssssssssssssddo",
	".osssssssssssddo.",
	".osssssssssssddo.",
	"..osssssssssddo..",
]

# Full crimp: fingers stacked high and the thumb locked over the index finger.
const HAND_FULL := [
	".ooo.ooo.ooo.ooo.",
	"owwwowwwowwwowwwo",
	"oddoodddodddoddoo",
	"ooooooooooooooooo",
	"osslssoolsssssdo.",
	"osslsoolssssssdo.",
	"ossssoossssssddo.",
	".oossssssssssddo.",
	"..osssssssssddo..",
	"..osssssssssddo..",
	"..osssssssssddo..",
]
