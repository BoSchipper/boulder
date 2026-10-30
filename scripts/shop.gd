class_name Shop
extends CanvasLayer
## Gear stall: pick with up/down, buy with A, leave with B.
## Usage: await Shop.open(get_tree().root)

signal closed

const IDS := ["fan", "big_pad", "second_pad", "shoes", "tape"]
const ROW_H := 22

var _index := 0
var _rows: Array[Label] = []
var _prices: Array[Label] = []
var _info := Label.new()
var _wallet := Label.new()
var _cursor := TextureRect.new()


static func open(parent: Node) -> void:
	var shop := Shop.new()
	parent.add_child(shop)
	await shop.closed
	shop.queue_free()


func _ready() -> void:
	layer = 8
	var box := NinePatchRect.new()
	box.texture = load(Game.ASSETS + "Ui/Dialog/DialogueBoxSimple.png")
	box.patch_margin_left = 8
	box.patch_margin_right = 8
	box.patch_margin_top = 8
	box.patch_margin_bottom = 8
	box.position = Vector2(82, 20)
	box.size = Vector2(316, 182)
	add_child(box)
	_label("Le Petit Bleau  -  klimwinkel", Vector2(100, 34), Game.FONT_TITLE, 8)
	for i in IDS.size():
		_rows.append(_label("", Vector2(112, 50 + i * ROW_H), Game.FONT_TEXT, 16))
		_prices.append(_label("", Vector2(290, 50 + i * ROW_H), Game.FONT_TEXT, 16))
	_cursor.texture = load(Game.ASSETS + "Ui/Arrow.png")
	_cursor.rotation_degrees = -90
	add_child(_cursor)
	_info.add_theme_color_override("font_color", Color("6b4e4e"))
	_info.position = Vector2(100, 164)
	add_child(_info)
	_style(_info, Game.FONT_TEXT, 16)
	_wallet.position = Vector2(300, 34)
	_style(_wallet, Game.FONT_TITLE, 8)
	add_child(_wallet)
	_refresh()


func _label(text: String, pos: Vector2, font_name: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	_style(label, font_name, size)
	add_child(label)
	return label


func _style(label: Label, font_name: String, size: int) -> void:
	label.add_theme_font_override("font", Game.font(font_name))
	label.add_theme_font_size_override("font_size", size)
	if not label.has_theme_color_override("font_color"):
		label.add_theme_color_override("font_color", Dialog.TEXT_COLOR)


func _refresh() -> void:
	for i in IDS.size():
		var item: Dictionary = Game.GEAR[IDS[i]]
		var right := "gekocht" if Game.has_gear(IDS[i]) else "%d beanies" % item.price
		if item.get("consumable", false):
			right = "%d beanie  (%d)" % [item.price, Game.tape]
		_rows[i].text = item.name
		_prices[i].text = right
		_rows[i].modulate.a = 0.5 if Game.has_gear(IDS[i]) else 1.0
		_prices[i].modulate.a = _rows[i].modulate.a
	_cursor.position = Vector2(98, 64 + _index * ROW_H)
	_info.text = Game.GEAR[IDS[_index]].info + "\nZ = kopen,  X = terug"
	_wallet.text = "Je hebt %d beanies" % Game.beanies


func _unhandled_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("move_up"):
		_index = (_index + IDS.size() - 1) % IDS.size()
		Game.sfx("Sounds/Menu/Move1.wav", -12.0)
	elif event.is_action_pressed("move_down"):
		_index = (_index + 1) % IDS.size()
		Game.sfx("Sounds/Menu/Move1.wav", -12.0)
	elif event.is_action_pressed("action_a"):
		if Game.buy(IDS[_index]):
			Game.sfx("Sounds/Bonus/Coin.wav", -8.0)
		else:
			Game.sfx("Sounds/Menu/Cancel.wav", -10.0)
	elif event.is_action_pressed("action_b"):
		closed.emit()
		return
	_refresh()
