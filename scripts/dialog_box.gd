extends CanvasLayer
## Text box at the bottom of the screen (autoload "Dialog").
## Usage: await Dialog.say(["Line one", "Line two"], "Name", faceset_texture)
## Afterwards Dialog.last_button tells whether A or B closed it (for yes/no questions).

signal closed

const CHARS_PER_SEC := 45.0
const TEXT_COLOR := Color("3d2b2b")

var _box := TextureRect.new()
var _face := TextureRect.new()
var _name := Label.new()
var _text := Label.new()
var _arrow := TextureRect.new()
var _lines: Array = []
var _shown := 0.0
var _blip_count := 0

var is_open := false
var last_button := ""  # "a" or "b": the button that closed the last box


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	add_child(_box)
	_box.add_child(_face)
	_box.add_child(_name)
	_box.add_child(_text)
	_box.add_child(_arrow)
	_text.add_theme_font_override("font", Game.font(Game.FONT_TEXT))
	_text.add_theme_color_override("font_color", TEXT_COLOR)
	_text.add_theme_font_size_override("font_size", 16)
	_text.add_theme_constant_override("line_spacing", -2)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.add_theme_font_override("font", Game.font(Game.FONT_TITLE))
	_name.add_theme_font_size_override("font_size", 8)
	_name.add_theme_color_override("font_color", Color("f4e4d4"))
	_name.position = Vector2(8, 1)
	_arrow.texture = load(Game.ASSETS + "Ui/Arrow.png")
	_box.visible = false


func say(lines: Array, speaker := "", face: Texture2D = null) -> void:
	_lines = lines.duplicate()
	if face:
		_box.texture = load(Game.ASSETS + "Ui/Dialog/DialogBoxFaceset.png")
		_face.texture = face
		_face.position = Vector2(6, 14)
		_text.position = Vector2(54, 15)
		_text.size = Vector2(236, 40)
	else:
		_box.texture = load(Game.ASSETS + "Ui/Dialog/DialogueBoxSimple.png")
		_face.texture = null
		_text.position = Vector2(12, 11)
		_text.size = Vector2(290, 44)
	_name.text = speaker
	_name.visible = face != null and speaker != ""
	_box.position = Vector2((480 - _box.texture.get_width()) / 2.0, 270 - _box.texture.get_height() - 6)
	_arrow.position = _box.texture.get_size() - Vector2(18, 14)
	is_open = true
	_box.visible = true
	_next_line()
	await closed


func _next_line() -> void:
	if _lines.is_empty():
		is_open = false
		_box.visible = false
		closed.emit()
		return
	_text.text = _lines.pop_front()
	_text.visible_characters = 0
	_shown = 0.0


func _process(delta: float) -> void:
	if not is_open:
		return
	var total := _text.get_total_character_count()
	if _text.visible_characters < total:
		_shown += delta * CHARS_PER_SEC
		var before := _text.visible_characters
		_text.visible_characters = mini(int(_shown), total)
		if _text.visible_characters != before:
			_blip_count += 1
			if _blip_count % 3 == 0:
				Game.sfx("Sounds/Menu/Move1.wav", -18.0)
	_arrow.visible = _text.visible_characters >= total and int(Time.get_ticks_msec() / 350) % 2 == 0


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not (event.is_action_pressed("action_a") or event.is_action_pressed("action_b")):
		return
	get_viewport().set_input_as_handled()
	if _text.visible_characters < _text.get_total_character_count():
		_text.visible_characters = -1
		_shown = 9999.0
	else:
		last_button = "a" if event.is_action_pressed("action_a") else "b"
		Game.sfx("Sounds/Menu/Accept.wav", -14.0)
		_next_line()
