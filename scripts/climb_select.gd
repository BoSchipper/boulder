extends Node2D
## Pick which climbing prototype to try. Temporary, until one of them wins.

const SWING_WALL := "res://scenes/climb_wall.tscn"
const FLOW_WALL := "res://scenes/climb_flow.tscn"


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("2b1d2e"))
	_line("KIES EEN WAND", Game.FONT_TITLE, 16, 56, Color("f2cf3a"))
	_line("Z / A   =   Slingerwand", Game.FONT_TEXT, 16, 112, Color("fff6e4"))
	_line("elke hand een knop, vrij reiken en zwaaien", Game.FONT_TEXT, 16, 128, Color("a9a0a0"))
	_line("X / B   =   Flowwand", Game.FONT_TEXT, 16, 164, Color("fff6e4"))
	_line("gooien en vangen met de kleur van de greep", Game.FONT_TEXT, 16, 180, Color("a9a0a0"))
	_line("Esc / Start  =  terug naar dit menu", Game.FONT_TEXT, 16, 236, Color("a9a0a0"))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("action_a"):
		get_tree().change_scene_to_file(SWING_WALL)
	elif event.is_action_pressed("action_b"):
		get_tree().change_scene_to_file(FLOW_WALL)


func _line(text: String, font_name: String, size: int, y: float, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(0, y)
	label.size = Vector2(480, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", Game.font(font_name))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
