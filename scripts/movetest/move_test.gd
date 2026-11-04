class_name MoveTest
extends Node2D
## Shared by the movement tests: one screen of grey rock, no art, no score. Only how a
## move feels counts. Falling puts you straight back at the start. In screen coordinates.

signal leave

const FLOOR := 258.0
const ROCK := Color("4a4247")
const ROCK_EDGE := Color("5c5358")
const HOLD := Color("d8cfc0")
const GOOD := Color("7fbf5a")
const BAD := Color("e0705a")
const TARGET := Color("f2cf3a")
const LEFT_HAND := Color("6cc4ff")
const RIGHT_HAND := Color("ffb04a")
const BODY := Color("54bfb5")
const RESTART_TIME := 0.6

var _note := Label.new()
var _hint := Label.new()
var _note_tween: Tween
var _restart := 0.0


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = layer_above(1)
	add_child(layer)
	for label in [_note, _hint]:
		label.add_theme_font_override("font", Game.font(Game.FONT_TEXT))
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color("fff6e4"))
		label.add_theme_color_override("font_outline_color", Color("2b2329"))
		label.add_theme_constant_override("outline_size", 3)
		label.size = Vector2(480, 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		layer.add_child(label)
	_note.position = Vector2(0, 24)
	_hint.position = Vector2(0, 2)
	_hint.text = hint_text()
	reset()


func _physics_process(delta: float) -> void:
	if _restart > 0.0:
		_restart -= delta
		if _restart <= 0.0:
			reset()
	else:
		step(delta)
	queue_redraw()


## A layer for text and overlays, above whatever layer the test itself is drawn in: on its
## own that is the screen, from the walking world it is the climbing layer there.
func layer_above(n: int) -> int:
	var cl := get_canvas_layer_node()
	return (cl.layer if cl else 0) + n


## Each test fills these in.
func hint_text() -> String:
	return ""


func reset() -> void:
	pass


func step(_delta: float) -> void:
	pass


func again_soon(text: String) -> void:
	say(text)
	_restart = RESTART_TIME


func say(text: String) -> void:
	_note.text = text
	_note.modulate.a = 1.0
	if _note_tween:
		_note_tween.kill()
	_note_tween = create_tween()
	_note_tween.tween_interval(1.0)
	_note_tween.tween_property(_note, "modulate:a", 0.0, 0.3)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("to_menu"):
		get_viewport().set_input_as_handled()
		leave.emit()


func button(pad_button: JoyButton, key: String) -> String:
	return Game.button_name(pad_button) if Game.using_pad else key


func draw_rock() -> void:
	draw_rect(Rect2(0, 0, 480, 270), ROCK)
	draw_rect(Rect2(0, FLOOR, 480, 12), Color("2b2329"))


func draw_hold(at: Vector2, radius: float, color := HOLD) -> void:
	draw_circle(at, radius, Color("2b2329"))
	draw_circle(at, radius - 1.0, color)


func draw_corners(at: Vector2, radius: float, color: Color) -> void:
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var p: Vector2 = at + corner * radius
		draw_line(p, p - Vector2(corner.x * 4, 0), color)
		draw_line(p, p - Vector2(0, corner.y * 4), color)


func draw_limb(from: Vector2, to: Vector2, color: Color) -> void:
	draw_line(from, to, Color("2b2329"), 4.0)
	draw_line(from, to, color, 2.0)
