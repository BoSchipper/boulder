class_name Microgame
extends Node
## Base for one WarioWare-style move on a boulder.
## A microgame draws into `stage` (a 150x85 area shown at 2x zoom) and puts
## bars/hints in `ui` (300x170, normal pixel size). It ends with finished(success).

signal finished(success: bool, reason: String)

const STAGE := Vector2(150, 85)

var stage: Node2D
var ui: Control
var shades: Array = PixelArt.ROCK_ORANGE
var speed := 1.0  # higher grade = faster
var seed_value := 0
var duration := 4.0
var word := "KLIM!"
var keys: Array = ["KeyZ"]  # key icons shown under the word, so you know what to press
var survive_wins := true  # when time runs out: win (endurance moves) or lose (timing moves)
var running := false
var indoor := false  # gym: plywood wall and plastic holds instead of sandstone

var _elapsed := 0.0
var _done := false


## Build the scene. Called before the instruction word appears.
func setup() -> void:
	pass


## Per-frame logic while running.
func tick(_delta: float) -> void:
	pass


func time_left() -> float:
	return clampf(1.0 - _elapsed / duration, 0.0, 1.0)


func win(reason := "") -> void:
	if not _done:
		_done = true
		running = false
		finished.emit(true, reason)


func lose(reason := "") -> void:
	if not _done:
		_done = true
		running = false
		finished.emit(false, reason)


func _process(delta: float) -> void:
	if not running:
		return
	_elapsed += delta
	tick(delta)
	if running and _elapsed >= duration:
		if survive_wins:
			win()
		else:
			lose("Te laat!")


# --- shared drawing helpers -------------------------------------------

## The wall behind the holds, a bit darker so the holds stand out.
func add_rock_background() -> void:
	if indoor:
		PixelArt.sprite(PixelArt.plywood(Vector2i(STAGE), seed_value), Vector2.ZERO, stage)
		return
	var dark := shades.map(func(c: Color) -> Color: return c.darkened(0.18))
	PixelArt.sprite(PixelArt.rock(Vector2i(STAGE), dark, seed_value), Vector2.ZERO, stage)


## A forearm + hand sprite. `open` = fingers stretched, else curled over a hold.
func make_hand(open: bool) -> ImageTexture:
	return make_hand_rows(HAND_OPEN if open else HAND_CLOSED)


## Any hand drawing from rows, with the forearm added below it.
func make_hand_rows(hand_rows: Array) -> ImageTexture:
	var rows: Array = hand_rows.duplicate()
	for i in 60:
		rows.append(ARM_ROW)
	return PixelArt.from_rows(rows, PixelArt.SKIN)


func hint(text: String, key := "KeyZ") -> void:
	var icon := TextureRect.new()
	icon.texture = load(Game.ASSETS + "Ui/Input/Keyboard/%s.png" % key)
	icon.position = Vector2(8, 150)
	ui.add_child(icon)
	var label := label_at(text, Vector2(25, 146))
	label.add_theme_color_override("font_color", Color("fff6e4"))


func label_at(text: String, pos: Vector2, font_name := Game.FONT_TEXT, size := 16) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_override("font", Game.font(font_name))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_shadow_color", PixelArt.OUTLINE)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	ui.add_child(label)
	return label


## A vertical meter (0..1) drawn at normal pixel size inside `ui`.
func make_meter(pos: Vector2, height: float) -> ColorRect:
	var back := ColorRect.new()
	back.color = PixelArt.OUTLINE
	back.position = pos
	back.size = Vector2(10, height)
	ui.add_child(back)
	var fill := ColorRect.new()
	fill.position = Vector2(2, height - 2)
	fill.size = Vector2(6, 0)
	back.add_child(fill)
	return fill


func set_meter(fill: ColorRect, value: float, color: Color) -> void:
	var full := fill.get_parent_control().size.y - 4
	var h := roundf(full * clampf(value, 0.0, 1.0))
	fill.size.y = h
	fill.position.y = 2 + full - h
	fill.color = color


const HAND_CLOSED := [
	".ooo.ooo.ooo.ooo.",
	"owwwowwwowwwowwwo",
	"olssolssolssolsso",
	"osssosssosssossso",
	"odddddddddddddddo",
	"olsssssssssssssdo",
	"olsssssssssssssdo",
	"osssssssssssssddo",
	".osssssssssssddo.",
	".osssssssssssddo.",
	"..osssssssssddo..",
]

const HAND_OPEN := [
	".ooo.ooo.ooo.ooo.",
	"owwwowwwowwwowwwo",
	"olssolssolssolsso",
	"olssolssolssolsso",
	"olssolssolssolsso",
	"osssosssosssossso",
	"ossssssssssssssso",
	"olsssssssssssssdo",
	"olsssssssssssssdo",
	"osssssssssssssddo",
	".osssssssssssddo.",
	"..osssssssssddo..",
]

const ARM_ROW := "..osssssssssddo.."
