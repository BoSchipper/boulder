class_name Backpack
extends CanvasLayer
## Your backpack (X while walking): what gear you own, and fingertape to use.
## Usage: await Backpack.open(get_tree().root)

signal closed

var _text := Label.new()


static func open(parent: Node) -> void:
	var bag := Backpack.new()
	parent.add_child(bag)
	await bag.closed
	bag.queue_free()


func _ready() -> void:
	layer = 8
	var box := NinePatchRect.new()
	box.texture = load(Game.ASSETS + "Ui/Dialog/DialogueBoxSimple.png")
	for side in ["left", "right", "top", "bottom"]:
		box.set("patch_margin_" + side, 8)
	box.position = Vector2(120, 50)
	box.size = Vector2(240, 152)
	add_child(box)
	var title := Label.new()
	title.text = "Rugzak"
	title.position = Vector2(14, 10)
	title.add_theme_font_override("font", Game.font(Game.FONT_TITLE))
	title.add_theme_font_size_override("font_size", 8)
	title.add_theme_color_override("font_color", Dialog.TEXT_COLOR)
	box.add_child(title)
	_text.position = Vector2(14, 24)
	_text.add_theme_font_override("font", Game.font(Game.FONT_TEXT))
	_text.add_theme_font_size_override("font_size", 16)
	_text.add_theme_color_override("font_color", Dialog.TEXT_COLOR)
	_text.add_theme_constant_override("line_spacing", -2)
	box.add_child(_text)
	_refresh()


func _refresh() -> void:
	var gear := []
	for id in Game.GEAR:
		if Game.has_gear(id):
			gear.append(Game.GEAR[id].name)
	var lines := [
		"Fingertape: %d" % Game.tape,
		"Vel: %d/%d    Klimniveau: %.1f" % [Game.skin, Game.max_skin(), Game.climber_level()],
		"Circuits af: %d    Legendes: %d" % [Game.circuits_done(), Game.legends_beaten.size()],
		"Spullen: " + (", ".join(PackedStringArray(gear)) if not gear.is_empty() else "nog niks"),
		"Legendes: " + (", ".join(PackedStringArray(Game.legends_beaten.keys().map(func(id): return Game.LEGENDS[id].beanie))) if not Game.legends_beaten.is_empty() else "nog geen"),
		"",
		"Z = tapen (+1 vel, 1 uur)" if Game.tape > 0 else "",
		"X = dicht",
	]
	_text.text = "\n".join(PackedStringArray(lines))


func _unhandled_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("action_a"):
		if Game.use_tape():
			Game.sfx("Sounds/Menu/Accept3.wav", -8.0)
		else:
			Game.sfx("Sounds/Menu/Cancel.wav", -10.0)
		_refresh()
	elif event.is_action_pressed("action_b"):
		closed.emit()
