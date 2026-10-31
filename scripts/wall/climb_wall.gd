extends Node2D
## Test wall for the new climbing game: one route with all hold types, to get
## the feel right before it goes into the world. R (controller: Y) = from the ground,
## T (controller: X) = practise from the last jug you reached (a top only counts
## from the ground).

const WIDTH := 480
const WALL_HEIGHT := 620  # rock above the floor

# The route, bottom to top. Heights are pixels above the floor.
const ROUTE := [
	[215, 62, "jug"], [265, 62, "jug"],   # start
	[232, 105, "crimp"],
	[282, 132, "sloper"],
	[240, 166, "pinch"],
	[286, 200, "jug"],                    # rest
	[232, 234, "pocket"],
	[272, 270, "pinch"],
	[230, 302, "crimp"],
	[286, 376, "jug"],                    # the dyno
	[246, 416, "sloper"],
	[282, 456, "top"],
]
const FOOT_CHIPS := [
	[205, 20], [270, 26], [235, 58], [292, 70], [215, 96], [272, 110], [230, 140], [288, 158],
	[218, 186], [268, 200], [240, 232], [282, 248], [222, 268], [262, 290],
	[276, 346], [240, 384], [290, 400],
]
const HOLD_INFO := {
	"jug": "Bak: makkelijk, laadt je kracht weer op",
	"crimp": "Crimp: klein en kost veel kracht",
	"sloper": "Sloper: je glijdt weg als je er niet onder hangt of te snel gaat",
	"pinch": "Pinch: kost kracht, maar stopt je zwaai",
	"pocket": "Pocket: piepklein, er past maar een hand in",
	"top": "Top: pak hem met allebei je handen!",
}

var climber := WallClimber.new()
var cam := Camera2D.new()
var holds: Array[WallHold] = []
var checkpoint: WallHold = null
var practising := false
var falls := 0
var time := 0.0
var timing := false
var best_time := 0.0
var seen_types := {}
var keys := {}

var _bar: ColorRect
var _bar_back: ColorRect
var _stats := Label.new()
var _message := Label.new()
var _info := Label.new()
var _message_tween: Tween


func _ready() -> void:
	_draw_scene()
	for h in ROUTE:
		var hold := WallHold.new(Vector2(h[0], -h[1]), h[2])
		holds.append(hold)
		_place_hold(hold)
	climber.holds = holds
	for c in FOOT_CHIPS:
		var chip := Vector2(c[0], -c[1])
		climber.foot_chips.append(chip)
		var sprite := PixelArt.sprite(_foot_chip(), chip - Vector2(4, 1), self)
		sprite.z_index = 1
	climber.z_index = 2
	add_child(climber)
	climber.grabbed.connect(_on_grabbed)
	climber.fell.connect(_on_fell)
	climber.topped.connect(_on_topped)
	cam.limit_left = 0
	cam.limit_right = WIDTH
	cam.limit_bottom = 40
	cam.limit_top = -WALL_HEIGHT - 60
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	add_child(cam)
	cam.position = climber.body
	_build_hud()
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool) -> void: _show_controls())
	_show_controls()


## Names the buttons of whatever you are playing with.
func _show_controls() -> void:
	if Input.get_connected_joypads().is_empty():
		keys = {"left": "Z", "right": "X", "move": "pijltjes", "restart": "R", "practise": "T"}
	else:
		keys = {"left": "LB", "right": "RB", "move": "stick", "restart": "Y", "practise": "X"}
	if climber.left_ground:
		return
	_say("%s = linkerhand,  %s = rechterhand" % [keys.left, keys.right], 4.0)
	_info.text = "Vasthouden = grijpen,  loslaten = loslaten,  %s = bewegen en reiken" % keys.move


func _retry_hint() -> String:
	return "%s = van de grond,  %s = oefen vanaf de laatste bak" % [keys.restart, keys.practise]


func _process(delta: float) -> void:
	cam.position = climber.body + Vector2(0, -30)
	if timing and not climber.frozen:
		time += delta
	if not timing and climber.left_ground:
		timing = true
	_bar.size.x = roundf(116 * climber.stamina)
	_bar.color = Color("7fbf5a").lerp(Color("d9453c"), 1.0 - climber.stamina)
	if climber.stamina < 0.2:
		_bar.visible = Engine.get_frames_drawn() % 10 < 6
	else:
		_bar.visible = true
	var mode := "oefenen" if practising else "%.1f s" % time
	_stats.text = "Vallen: %d    %s%s" % [falls, mode, "    beste: %.1f s" % best_time if best_time > 0.0 else ""]
	if climber.waiting:
		_info.text = "Houd %s en %s ingedrukt om te beginnen" % [keys.left, keys.right]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("wall_restart"):
		_restart()
	elif event.is_action_pressed("wall_practise"):
		_practise()
	elif event.is_action_pressed("to_menu"):
		get_tree().change_scene_to_file("res://scenes/climb_select.tscn")


func _restart() -> void:
	practising = false
	timing = false
	time = 0.0
	climber.reset(Vector2(240, -WallClimber.SHOULDER_HEIGHT))
	_info.text = _retry_hint()


## Project a section: start again from the highest jug you have reached.
func _practise() -> void:
	if checkpoint == null:
		_say("Pak eerst een bak hogerop", 1.5)
		return
	practising = true
	timing = false
	climber.place_on(checkpoint)
	_say("Oefenen: een top telt pas van de grond", 2.0)


func _on_grabbed(hold: WallHold) -> void:
	if hold.type == "jug" and hold.pos.y < -80.0 and (checkpoint == null or hold.pos.y < checkpoint.pos.y):
		checkpoint = hold
	if not seen_types.has(hold.type):
		seen_types[hold.type] = true
		_info.text = HOLD_INFO[hold.type]
	elif not climber.waiting:
		_info.text = _retry_hint()


func _on_fell() -> void:
	falls += 1
	Game.sfx("Sounds/Hit & Impact/Impact.wav", -6.0)
	_say("Plof!", 1.0)
	practising = false
	timing = false
	time = 0.0


func _on_topped() -> void:
	Game.sfx("Jingles/Success1.wav", -6.0)
	if practising:
		_say("Top! Nu nog van de grond", 3.0)
		return
	if best_time == 0.0 or time < best_time:
		best_time = time
	_say("TOP!  %.1f seconden" % time, 5.0)
	_info.text = "%s = nog een keer" % keys.restart


# --- the scene ----------------------------------------------------------

func _draw_scene() -> void:
	# A calm, dark wall: little contrast in the rock, so the holds stand out.
	var dark := [Color("6e4436"), Color("754a3a"), Color("7d503e"), Color("855642")]
	var rock := PixelArt.sprite(PixelArt.rock(Vector2i(WIDTH, WALL_HEIGHT), dark, 8), Vector2(0, -WALL_HEIGHT), self)
	rock.z_index = -10
	# Sky above the boulder, with a lit edge along the top.
	var sky := ColorRect.new()
	sky.color = Color("a9dcef")
	sky.size = Vector2(WIDTH, 140)
	sky.position = Vector2(0, -WALL_HEIGHT - 140)
	sky.z_index = -11
	add_child(sky)
	var edge := ColorRect.new()
	edge.color = PixelArt.ROCK_ORANGE[3]
	edge.size = Vector2(WIDTH, 3)
	edge.position = Vector2(0, -WALL_HEIGHT)
	edge.z_index = -9
	add_child(edge)
	# Sand and the crashpad at the bottom.
	var sand := ColorRect.new()
	sand.color = Color("e6d3a3")
	sand.size = Vector2(WIDTH, 50)
	sand.position = Vector2(0, -2)
	sand.z_index = -8
	add_child(sand)
	var pad := ColorRect.new()
	pad.color = Color("3d6fc8")
	pad.size = Vector2(160, 8)
	pad.position = Vector2(160, -1)
	pad.z_index = -7
	add_child(pad)
	var pad_edge := ColorRect.new()
	pad_edge.color = Color("2a4f94")
	pad_edge.size = Vector2(160, 3)
	pad_edge.position = Vector2(160, 7)
	pad_edge.z_index = -7
	add_child(pad_edge)


func _place_hold(hold: WallHold) -> void:
	var tex := _hold_art(hold.type)
	var sprite := PixelArt.sprite(tex, hold.pos - tex.get_size() / 2.0, self)
	sprite.z_index = 1


## Every type has its own recognisable shape.
func _hold_art(type: String) -> ImageTexture:
	var light: Array = PixelArt.ROCK_ORANGE
	match type:
		"jug":
			return PixelArt.shape(Vector2i(26, 13), light, func(x: int, y: int) -> int:
				var d: float = pow((x - 12.5) / 13.0, 2) + pow((y - 6.0) / 6.5, 2)
				if d > 1.0: return -1
				if d > 0.78: return 9
				if y >= 6 and absf(x - 12.5) < 9.0: return 9 if y == 6 else 0  # the dark pocket you hook into
				return 3 if y <= 2 else 2)
		"crimp":
			return PixelArt.shape(Vector2i(18, 6), light, func(x: int, y: int) -> int:
				if (x == 0 or x == 17) and y < 2: return -1
				if y == 0 or y == 4: return 9
				if y == 5: return 0 if PixelArt.bayer(x, y) < 0.6 else -1
				return 8 if y == 1 and x > 2 and x < 15 else 3)
		"sloper":
			return PixelArt.shape(Vector2i(30, 17), light, func(x: int, y: int) -> int:
				var d: float = pow((x - 14.5) / 15.0, 2) + pow((y - 16.0) / 16.0, 2)
				if d > 1.0: return -1
				if d > 0.84: return 9
				if d < 0.3 and y < 13 and PixelArt.bayer(x, y) < 0.3: return 8
				return 3 if y < 8 else (2 if y < 13 else 1))
		"pinch":
			return PixelArt.shape(Vector2i(10, 24), light, func(x: int, y: int) -> int:
				var half := 4.5 - absf(y - 11.5) * 0.1
				if absf(x - 4.5) > half: return -1
				if absf(absf(x - 4.5) - half) < 1.0 or y == 0 or y == 23: return 9
				return 3 if x < 4 else 1)
		"pocket":
			return PixelArt.shape(Vector2i(13, 11), light, func(x: int, y: int) -> int:
				var d: float = pow((x - 6.0) / 6.5, 2) + pow((y - 5.0) / 5.5, 2)
				if d > 1.0: return -1
				if d > 0.72: return 3 if y < 5 else 1
				if d > 0.46: return 9
				return 9)
		_:  # top
			return PixelArt.shape(Vector2i(40, 12), [Color("7a5a2a"), Color("b58a3a"), Color("e0b64e"), Color("ffe08a")], func(x: int, y: int) -> int:
				var d: float = pow((x - 19.5) / 20.0, 2) + pow((y - 5.5) / 6.0, 2)
				if d > 1.0: return -1
				if d > 0.8: return 9
				if y >= 6 and absf(x - 19.5) < 15.0: return 9 if y == 6 else 0
				return 3 if y <= 2 else 2)


func _foot_chip() -> ImageTexture:
	return PixelArt.shape(Vector2i(9, 3), PixelArt.ROCK_ORANGE, func(x: int, y: int) -> int:
		if y == 0: return 3 if x > 0 and x < 8 else -1
		if y == 1: return 9
		return 0 if PixelArt.bayer(x, y) < 0.5 else -1)


# --- HUD ------------------------------------------------------------------

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	var title := _hud_label("KRACHT", Game.FONT_TITLE, 8, hud)
	title.position = Vector2(10, 6)
	_bar_back = ColorRect.new()
	_bar_back.color = PixelArt.OUTLINE
	_bar_back.position = Vector2(10, 18)
	_bar_back.size = Vector2(120, 8)
	hud.add_child(_bar_back)
	_bar = ColorRect.new()
	_bar.position = Vector2(2, 2)
	_bar.size = Vector2(116, 4)
	_bar_back.add_child(_bar)
	_stats = _hud_label("", Game.FONT_TEXT, 16, hud)
	_stats.position = Vector2(142, 8)
	_info = _hud_label("", Game.FONT_TEXT, 16, hud)
	_info.position = Vector2(0, 250)
	_info.size = Vector2(WIDTH, 18)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message = _hud_label("", Game.FONT_TITLE, 16, hud)
	_message.position = Vector2(0, 40)
	_message.size = Vector2(WIDTH, 24)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _hud_label(text: String, font_name: String, size: int, parent: Node) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", Game.font(font_name))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("fff6e4"))
	label.add_theme_color_override("font_shadow_color", PixelArt.OUTLINE)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	return label


func _say(text: String, seconds: float) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(seconds)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.4)
