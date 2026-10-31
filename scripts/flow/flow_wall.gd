extends Node2D
## Test wall for the flow variant: throw yourself up the route and catch every hold
## with its colour button. Falling puts you back at the start right away.
## Sits next to the swing wall (scripts/wall/) so both can be tried.

const WIDTH := 480
const WALL_HEIGHT := 620
const RESPAWN_TIME := 0.7

# The route, bottom to top: x, height above the floor, type.
const ROUTE := [
	[240, 58, "jug"],
	[270, 98, "crimp"],
	[238, 140, "sloper"],
	[272, 180, "pinch"],
	[236, 222, "jug"],     # rest
	[268, 262, "crimp"],
	[236, 302, "crimp"],
	[270, 344, "sloper"],
	[238, 388, "jug"],     # rest
	[272, 430, "pinch"],
	[238, 470, "crimp"],
	[270, 512, "sloper"],
	[244, 556, "top"],
]
const RATING_TEXT := {"perfect": "PERFECT", "goed": "goed", "net": "net aan"}

var climber := FlowClimber.new()
var cam := Camera2D.new()
var holds: Array[FlowHold] = []
var checkpoint := -1
var practising := false
var falls := 0
var perfects := 0
var time := 0.0
var timing := false
var best_time := 0.0
var _respawn := 0.0
var _using_pad := false

var _bar: ColorRect
var _flow_pips: Array[ColorRect] = []
var _stats: Label
var _message: Label
var _info: Label
var _popup: Label
var _labels: Array[Label] = []
var _message_tween: Tween
var _popup_tween: Tween


func _ready() -> void:
	_draw_scene()
	for h in ROUTE:
		var hold := FlowHold.new(Vector2(h[0], -h[1]), h[2])
		holds.append(hold)
		_place_hold(hold)
	climber.holds = holds
	climber.z_index = 2
	add_child(climber)
	climber.thrown.connect(_on_thrown)
	climber.caught.connect(_on_caught)
	climber.note.connect(_show_popup)
	climber.fell.connect(_on_fell)
	climber.topped.connect(_on_topped)
	cam.limit_left = 0
	cam.limit_right = WIDTH
	cam.limit_bottom = 40
	cam.limit_top = -WALL_HEIGHT - 60
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	add_child(cam)
	_build_hud()
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool) -> void: _show_controls())
	_restart()
	cam.position = climber.body
	_show_controls()


func _process(delta: float) -> void:
	cam.position = climber.body + Vector2(0, -30)
	if timing and climber.state != FlowClimber.State.DONE:
		time += delta
	_bar.size.x = roundf(116 * climber.stamina)
	_bar.color = Color("7fbf5a").lerp(Color("d9453c"), 1.0 - climber.stamina)
	_bar.visible = climber.stamina >= 0.2 or Engine.get_frames_drawn() % 10 < 6
	for i in _flow_pips.size():
		_flow_pips[i].color = Color("f2cf3a") if i < climber.flow else Color("4a3a4a")
	var mode := "oefenen" if practising else "%.1f s" % time
	_stats.text = "Vallen: %d    %s%s" % [falls, mode, "    beste: %.1f s" % best_time if best_time > 0.0 else ""]
	if _respawn > 0.0:
		_respawn -= delta
		if _respawn <= 0.0:
			_practise() if practising else _restart()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("flow_restart"):
		_restart()
	elif event.is_action_pressed("flow_practise"):
		_practise()
	elif event.is_action_pressed("to_menu"):
		get_tree().change_scene_to_file("res://scenes/climb_select.tscn")


## Names the buttons of whatever you are playing with.
func _show_controls() -> void:
	_using_pad = not Input.get_connected_joypads().is_empty()
	for i in holds.size():
		_labels[i].text = holds[i].data.pad if _using_pad else holds[i].data.key
	if _using_pad:
		_info.text = "stick = zwaaien (omhoog = overslaan),  RB = gooien,  knop op de top van je sprong"
	else:
		_info.text = "pijltjes = zwaaien (omhoog = overslaan),  spatie = gooien,  knop op de top van je sprong"


func _restart() -> void:
	practising = false
	timing = false
	time = 0.0
	perfects = 0
	_respawn = 0.0
	climber.start_on(0)


## Project a section: start again from the highest jug you have reached.
func _practise() -> void:
	if checkpoint < 0:
		_say("Pak eerst een bak hogerop", 1.5)
		return
	practising = true
	timing = false
	_respawn = 0.0
	climber.start_on(checkpoint)


func _on_thrown() -> void:
	timing = true


func _on_caught(hold: FlowHold, rating: String) -> void:
	_show_popup(RATING_TEXT[rating])
	if rating == "perfect":
		perfects += 1
	if hold.type == "jug" and climber.index > 0 and climber.index > checkpoint:
		checkpoint = climber.index


func _on_fell() -> void:
	falls += 1
	timing = false
	Game.sfx("Sounds/Hit & Impact/Impact.wav", -8.0)
	_respawn = RESPAWN_TIME


func _on_topped() -> void:
	Game.sfx("Jingles/Success1.wav", -6.0)
	timing = false
	if practising:
		_say("Top! Nu nog van de grond", 3.0)
		return
	if best_time == 0.0 or time < best_time:
		best_time = time
	_say("TOP!  %.1f s,  %d perfect" % [time, perfects], 5.0)


# --- the scene ------------------------------------------------------------

func _draw_scene() -> void:
	var dark := [Color("6e4436"), Color("754a3a"), Color("7d503e"), Color("855642")]
	var rock := PixelArt.sprite(PixelArt.rock(Vector2i(WIDTH, WALL_HEIGHT), dark, 8), Vector2(0, -WALL_HEIGHT), self)
	rock.z_index = -10
	_rect(Color("a9dcef"), Vector2(0, -WALL_HEIGHT - 140), Vector2(WIDTH, 140), -11)
	_rect(PixelArt.ROCK_ORANGE[3], Vector2(0, -WALL_HEIGHT), Vector2(WIDTH, 3), -9)
	_rect(Color("e6d3a3"), Vector2(0, -2), Vector2(WIDTH, 50), -8)
	_rect(Color("3d6fc8"), Vector2(180, -1), Vector2(120, 8), -7)
	_rect(Color("2a4f94"), Vector2(180, 7), Vector2(120, 3), -7)


func _rect(color: Color, pos: Vector2, size: Vector2, layer: int) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.position = pos
	rect.size = size
	rect.z_index = layer
	add_child(rect)


func _place_hold(hold: FlowHold) -> void:
	var tex := _hold_art(hold)
	var sprite := PixelArt.sprite(tex, (hold.pos - tex.get_size() / 2.0).round(), self)
	sprite.z_index = 1
	var label := _hud_label("", Game.FONT_TITLE, 8, self)
	label.position = hold.pos + Vector2(tex.get_width() / 2.0 + 3.0, -6.0)
	label.z_index = 1
	_labels.append(label)


## Bright colour for the button, and every type keeps its own shape.
func _hold_art(hold: FlowHold) -> ImageTexture:
	var base := Color(hold.data.color)
	var shades := [base.darkened(0.45), base.darkened(0.2), base, base.lightened(0.35)]
	match hold.type:
		"jug":
			return PixelArt.shape(Vector2i(18, 10), shades, func(x: int, y: int) -> int:
				var d: float = pow((x - 8.5) / 9.0, 2) + pow((y - 4.5) / 5.0, 2)
				if d > 1.0: return -1
				if d > 0.72: return 9
				if y >= 5 and absf(x - 8.5) < 6.0: return 9 if y == 5 else 0
				return 3 if y <= 1 else 2)
		"crimp":
			return PixelArt.shape(Vector2i(14, 5), shades, func(x: int, y: int) -> int:
				if (x == 0 or x == 13) and y < 2: return -1
				if y == 0 or y == 4: return 9
				if x == 0 or x == 13: return 9
				return 3 if y == 1 else 2)
		"sloper":
			return PixelArt.shape(Vector2i(20, 11), shades, func(x: int, y: int) -> int:
				var d: float = pow((x - 9.5) / 10.0, 2) + pow((y - 10.0) / 10.0, 2)
				if d > 1.0: return -1
				if d > 0.78: return 9
				return 3 if y < 4 else (2 if y < 8 else 1))
		"pinch":
			return PixelArt.shape(Vector2i(8, 16), shades, func(x: int, y: int) -> int:
				if (x == 0 or x == 7) and (y < 2 or y > 13): return -1
				if x == 0 or x == 7 or y == 0 or y == 15: return 9
				if (x == 1 or x == 6) and (y < 2 or y > 13): return 9
				return 3 if x < 3 else (2 if x < 5 else 1))
		_:  # top
			return PixelArt.shape(Vector2i(28, 10), shades, func(x: int, y: int) -> int:
				var d: float = pow((x - 13.5) / 14.0, 2) + pow((y - 4.5) / 5.0, 2)
				if d > 1.0: return -1
				if d > 0.75: return 9
				if y >= 5 and absf(x - 13.5) < 10.0: return 9 if y == 5 else 0
				return 3 if y <= 1 else 2)


# --- HUD ------------------------------------------------------------------

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	var title := _hud_label("KRACHT", Game.FONT_TITLE, 8, hud)
	title.position = Vector2(10, 6)
	var back := ColorRect.new()
	back.color = PixelArt.OUTLINE
	back.position = Vector2(10, 18)
	back.size = Vector2(120, 8)
	hud.add_child(back)
	_bar = ColorRect.new()
	_bar.position = Vector2(2, 2)
	_bar.size = Vector2(116, 4)
	back.add_child(_bar)
	var flow_title := _hud_label("FLOW", Game.FONT_TITLE, 8, hud)
	flow_title.position = Vector2(10, 30)
	for i in FlowClimber.MAX_FLOW:
		var pip := ColorRect.new()
		pip.position = Vector2(44 + i * 10, 32)
		pip.size = Vector2(8, 6)
		hud.add_child(pip)
		_flow_pips.append(pip)
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
	_popup = _hud_label("", Game.FONT_TITLE, 8, hud)
	_popup.position = Vector2(0, 70)
	_popup.size = Vector2(WIDTH, 12)
	_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


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


func _show_popup(text: String) -> void:
	_popup.text = text
	_popup.modulate.a = 1.0
	if _popup_tween:
		_popup_tween.kill()
	_popup_tween = create_tween()
	_popup_tween.tween_interval(0.5)
	_popup_tween.tween_property(_popup, "modulate:a", 0.0, 0.2)
