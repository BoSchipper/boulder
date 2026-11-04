extends Node2D
## Temporary start screen: pick an area of Fontainebleau to walk and climb in.

const AREAS := [
	["1  Les Sables d'Or", "het startgebied: het gele circuit", "res://scenes/overworld/sables.tscn"],
	["2  Bas Cuvier", "loop door het bos naar La Marie-Rose", "res://scenes/overworld/bas_cuvier.tscn"],
]

var _row := 0
var _steer_held := false
var _screen := Control.new()
var _rows: Array[Label] = []


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("2b2329"))
	add_child(_screen)
	_line("FONTAINEBLEAU", Game.FONT_TITLE, 70, Color("f2cf3a"))
	for i in AREAS.size():
		_rows.append(_line("", Game.FONT_TEXT, 110 + i * 34, Color("fff6e4")))
		_line(AREAS[i][1], Game.FONT_TEXT, 124 + i * 34, Color("a9a0a0"))
	var button := Game.button_name(JOY_BUTTON_A) if Game.using_pad else "Z"
	_line("stick = kiezen   %s = starten" % button, Game.FONT_TEXT, 250, Color("a9a0a0"))
	_refresh()


func _refresh() -> void:
	for i in _rows.size():
		var text: String = AREAS[i][0]
		_rows[i].text = "> %s <" % text if i == _row else text


func _process(_delta: float) -> void:
	var steer := Game.steer_vector()
	if absf(steer.y) < 0.5:
		_steer_held = false
	elif not _steer_held:
		_steer_held = true
		_row = wrapi(_row + int(signf(steer.y)), 0, _rows.size())
		Game.sfx("Sounds/Menu/Move2.wav", -14.0)
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("action_a"):
		get_tree().change_scene_to_file(AREAS[_row][2])


func _line(text: String, font_name: String, y: float, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", Game.font(font_name))
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.position = Vector2(0, y)
	label.size = Vector2(480, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = text
	_screen.add_child(label)
	return label
