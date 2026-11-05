class_name MenuLayer
extends CanvasLayer
## The game's menus, in its own frames and pixel fonts: a list you move through with the
## stick, arrows or d-pad, A to choose, B to go back, Start to close. Pages stack, so settings
## and controls open over the pause or title menu and B brings you back to it. Whoever opens
## a menu pauses the game; the menu keeps running. Settings and controls are built in; any
## other item is handed to the owner through `chose`.

signal chose(id: String)  # an item the owner handles: resume, topo, leave, ...
signal closed  # the menu closed, with B or Start or because the owner closed it

const UI_DIR := "res://assets/ui/"
const CREAM := Color("faeed6")
const GOLD := Color("f2cf3a")
const SAND := Color("deba6e")
const GREY := Color("968c8c")
const INK := Color("1c1620")
const STEP := 15  # pixels from one line of a list to the next
const REPEAT_FIRST := 0.4  # hold the stick: the selection moves on after this...
const REPEAT := 0.12  # ...and then this often

var closable := true  # false for the title menu: B on its first page does nothing
var _pages: Array[Dictionary] = []
var _sel := 0
var _tab := 0  # on the controls page: 0 walking, 1 climbing
var _root := Control.new()
var _held := 0
var _held_x := 0
var _repeat := 0.0
var _armed := false  # input waits a frame, so the press that opened the menu does not also choose


func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.size = Vector2(480, 270)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	visible = false


func _ready() -> void:
	Game.device_changed.connect(func() -> void:
		if is_open():
			_build())


func open(page: Dictionary) -> void:
	if not _pages.is_empty():
		_pages[-1]["_sel"] = _sel  # back here, the same line is chosen again
	_pages.append(page)
	_sel = _first(page)
	_tab = int(page.get("tab", 0))
	_armed = false
	visible = true
	_build()


func back() -> void:
	_pages.pop_back()
	if _pages.is_empty():
		visible = false
		closed.emit()
		return
	_sel = int(_pages[-1].get("_sel", _first(_pages[-1])))
	_build()


func close() -> void:
	_pages.clear()
	visible = false
	closed.emit()


func is_open() -> bool:
	return not _pages.is_empty()


static func settings_page() -> Dictionary:
	return {"title": "SETTINGS", "at": Vector2(110, 50), "width": 260, "dim": true,
		"items": [{"label": "Show holds", "setting": "show_grips"}, {"label": "Rumble", "setting": "rumble"},
			{"label": "Sound", "setting": "volume"}, {"label": "Graphics", "setting": "graphics"},
			{"label": "Window", "setting": "window"}, {"label": "Language", "value": "English", "dim": true}],
		"notes": {
			"show_grips": "Marks that show how well a spot holds.\nAn aid: reading the rock is the game.",
			"rumble": "The controller buzzes when a hand\ncarries too much, slips or catches.",
			"graphics": "Low: fewer shadows, no fog or ambient\nocclusion. For laptops and handhelds.",
		}}


static func controls_page(climbing: bool) -> Dictionary:
	return {"title": "CONTROLS", "controls": true, "tab": 1 if climbing else 0, "dim": true, "items": []}


## What to press, per action, for the device you are using: [what, keys, how].
static func controls_rows(climbing: bool) -> Array:
	var pad := Game.using_pad
	var b := func(button: JoyButton, key: String) -> String: return Game.button_name(button) if pad else key
	if not climbing:
		return [["Walk", "stick" if pad else "arrows", "or the d-pad" if pad else "or WASD"],
			["Talk, climb", b.call(JOY_BUTTON_A, "Z"), "when a name shows"],
			["Run", b.call(JOY_BUTTON_B, "X"), "hold"],
			["Topo", b.call(JOY_BUTTON_BACK, "Tab"), "the map of the area"],
			["Time of day", b.call(JOY_BUTTON_Y, "T"), "on to the next, for testing"],
			["Pause", b.call(JOY_BUTTON_START, "Esc"), ""]]
	var hands := "%s %s" % [Game.button_name(JOY_BUTTON_LEFT_SHOULDER), Game.button_name(JOY_BUTTON_RIGHT_SHOULDER)]
	return [["Hands", hands if pad else "Z X", "hold, move with the " + ("stick" if pad else "arrows")],
		["Feet", "LT RT" if pad else "C V", "hold, move with the " + ("stick" if pad else "arrows")],
		["Body", "stick" if pad else "arrows", "nothing held: shift, stand up"],
		["Jump", b.call(JOY_BUTTON_A, "space"), "sink, aim, let go, grab"],
		["Shake out", b.call(JOY_BUTTON_Y, "R"), "where you stand well"],
		["Tension", b.call(JOY_BUTTON_B, "F"), "as you move, on steep rock"],
		["Show holds", b.call(JOY_BUTTON_BACK, "G"), "an aid, off by default"],
		["Top out", "", "both hands on the rim, push up"]]


# ---------------------------------------------------------------- drawing helpers
## A frame (or a plate) from the game's UI art; children go inside, relative to it.
func box(parent: Control, rect: Rect2, art := "frame", margin := 6) -> Panel:
	var sb := StyleBoxTexture.new()
	sb.texture = load(UI_DIR + art + ".png")
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", sb)
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func label(parent: Control, text: String, pos: Vector2, color := CREAM, font_name := Game.FONT_TEXT,
		width := 0.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Game.font(font_name))
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", -2)
	l.horizontal_alignment = align
	l.position = pos
	if width > 0.0:
		l.size.x = width
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func text_width(text: String, font_name := Game.FONT_TEXT) -> float:
	return Game.font(font_name).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x


## A circuit number in a small square: filled once you topped that block.
func badge(parent: Control, pos: Vector2, n: int, done: bool) -> void:
	var edge := ColorRect.new()
	edge.color = INK
	edge.position = pos
	edge.size = Vector2(11, 11)
	parent.add_child(edge)
	var fill := ColorRect.new()
	fill.color = GOLD if done else Color("3c3228")
	fill.position = pos + Vector2(1, 1)
	fill.size = Vector2(9, 9)
	parent.add_child(fill)
	label(parent, str(n), pos + Vector2(0, -3), INK if done else GOLD, Game.FONT_TEXT, 11, HORIZONTAL_ALIGNMENT_CENTER)


## Rows of [what, keys, how], the keys on small plates.
func key_rows(parent: Control, origin: Vector2, rows: Array, step := 17.0) -> void:
	for k in rows.size():
		var row: Array = rows[k]
		var y := origin.y + k * step
		label(parent, row[0], Vector2(origin.x, y), CREAM)
		var x := origin.x + 68.0
		if row[1] != "":
			var w := text_width(row[1]) + 10.0
			box(parent, Rect2(x, y + 2, w, 14), "plate", 4)
			label(parent, row[1], Vector2(x + 5, y), GOLD)
			x += w + 6.0
		label(parent, row[2], Vector2(x, y), SAND)


func _marker(parent: Control, pos: Vector2) -> void:
	var m := Polygon2D.new()
	m.polygon = PackedVector2Array([Vector2(0, 0), Vector2(3, 3), Vector2(0, 6)])
	m.color = GOLD
	m.position = pos
	parent.add_child(m)


# ---------------------------------------------------------------- building a page
func _build() -> void:
	for c in _root.get_children():
		_root.remove_child(c)
		c.queue_free()
	var page: Dictionary = _pages[-1]
	if page.get("dim", false):
		var dim := ColorRect.new()
		dim.color = Color(INK, 0.55)
		dim.size = Vector2(480, 270)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(dim)
	if page.get("controls", false):
		_build_controls(page)
	else:
		_build_list(page)
	if page.has("card"):
		(page.card as Callable).call(self, box(_root, page.card_rect))
	var a := Game.button_name(JOY_BUTTON_A) if Game.using_pad else "Z"
	var b := Game.button_name(JOY_BUTTON_B) if Game.using_pad else "X"
	var hint := "%s  select     %s  back" % [a, b]
	if page.get("controls", false):
		hint = "left, right  walking or climbing     %s  back" % b
	elif not closable and _pages.size() == 1:
		hint = "%s  select" % a
	label(_root, hint, Vector2(0, 248), GREY, Game.FONT_TEXT, 480, HORIZONTAL_ALIGNMENT_CENTER)


func _title_plate(at: Vector2, width: float, title: String) -> void:
	var pw := text_width(title, Game.FONT_TITLE) + 20.0
	box(_root, Rect2(at.x + (width - pw) / 2.0, at.y - 9, pw, 18), "plate", 4)
	label(_root, title, Vector2(at.x, at.y - 10), GOLD, Game.FONT_TITLE, width, HORIZONTAL_ALIGNMENT_CENTER)


func _build_list(page: Dictionary) -> void:
	var items: Array = page.items
	var at: Vector2 = page.at
	var w: float = page.width
	var notes: Dictionary = page.get("notes", {})
	var top := 13 if page.get("title", "") != "" else 8  # room under the title plate
	var h := items.size() * STEP + top + 10 + (34 if not notes.is_empty() else 0)
	box(_root, Rect2(at, Vector2(w, h)))
	if page.get("title", "") != "":
		_title_plate(at, w, page.title)
	for k in items.size():
		var it: Dictionary = items[k]
		var y := at.y + top + k * STEP
		var off: bool = it.get("dim", false)
		label(_root, it.label, Vector2(at.x + 20, y), GREY if off else (GOLD if k == _sel else CREAM))
		if k == _sel and not off:
			_marker(_root, Vector2(at.x + 11, y + 6))
		if it.has("setting") and it.setting == "volume":
			for n in Game.VOLUME_STEPS:
				var plate := ColorRect.new()
				plate.color = INK
				plate.position = Vector2(at.x + w - 14 - (Game.VOLUME_STEPS - n) * 11, y + 4)
				plate.size = Vector2(9, 9)
				_root.add_child(plate)
				var fill := ColorRect.new()
				fill.color = (GOLD if k == _sel else SAND) if n < Game.volume else Color("463c32")
				fill.position = plate.position + Vector2(1, 1)
				fill.size = Vector2(7, 7)
				_root.add_child(fill)
		elif it.has("setting") or it.has("value"):
			var v: String = Game.setting_text(it.setting) if it.has("setting") else it.value
			label(_root, v, Vector2(at.x, y), GREY if off else (GOLD if k == _sel else SAND), Game.FONT_TEXT, w - 12, HORIZONTAL_ALIGNMENT_RIGHT)
	var cur: Dictionary = items[_sel] if _sel < items.size() else {}
	var key: String = cur.get("setting", cur.get("id", ""))  # a note per setting, or per item
	if notes.has(key):
		label(_root, notes[key], Vector2(at.x, at.y + h - 38), GREY, Game.FONT_TEXT, w, HORIZONTAL_ALIGNMENT_CENTER)


func _build_controls(page: Dictionary) -> void:
	var r := Rect2(40, 36, 400, 202)
	box(_root, r)
	_title_plate(r.position, r.size.x, page.title)
	var names := ["Walking", "Climbing"]
	var x := r.position.x + 16
	for k in 2:
		if k == _tab:
			_marker(_root, Vector2(x - 8, r.position.y + 18))
		label(_root, names[k], Vector2(x, r.position.y + 12), GOLD if k == _tab else GREY)
		x += text_width(names[k]) + 26
	key_rows(_root, r.position + Vector2(16, 34), controls_rows(_tab == 1), 19.0)


# ---------------------------------------------------------------- input
func _first(page: Dictionary) -> int:
	var items: Array = page.get("items", [])
	for k in items.size():
		if not items[k].get("dim", false):
			return k
	return 0


func _process(delta: float) -> void:
	if not is_open():
		return
	if not _armed:
		_armed = true
		return
	var steer := Game.steer_vector()
	var dy := 0 if absf(steer.y) < 0.5 else int(signf(steer.y))
	var dx := 0 if absf(steer.x) < 0.5 else int(signf(steer.x))
	if dy != _held:
		_held = dy
		_repeat = REPEAT_FIRST
		if dy != 0:
			_move(dy)
	elif dy != 0:
		_repeat -= delta
		if _repeat <= 0.0:
			_repeat = REPEAT
			_move(dy)
	if dx != _held_x:
		_held_x = dx
		if dx != 0:
			_side(dx)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or not _armed:
		return
	var a := event.is_action_pressed("action_a")
	var b := event.is_action_pressed("action_b") or event.is_action_pressed("to_menu")
	if not (a or b):
		return
	get_viewport().set_input_as_handled()  # first: choosing may take this menu out of the tree
	if a:
		_choose()
	elif _pages.size() > 1:
		Game.sfx("Sounds/Menu/Cancel.wav", -12.0)
		back()
	elif closable:
		Game.sfx("Sounds/Menu/Cancel.wav", -12.0)
		close()


func _move(dy: int) -> void:
	var items: Array = _pages[-1].get("items", [])
	if items.is_empty():
		return
	for _n in items.size():
		_sel = wrapi(_sel + dy, 0, items.size())
		if not items[_sel].get("dim", false):
			break
	Game.sfx("Sounds/Menu/Move2.wav", -14.0)
	_build()


func _side(dx: int) -> void:
	var page: Dictionary = _pages[-1]
	if page.get("controls", false):
		_tab = wrapi(_tab + dx, 0, 2)
		Game.sfx("Sounds/Menu/Move2.wav", -14.0)
		_build()
		return
	var items: Array = page.get("items", [])
	if _sel < items.size() and items[_sel].has("setting"):
		Game.change_setting(items[_sel].setting, dx)
		Game.sfx("Sounds/Menu/Move1.wav", -12.0)
		_build()


func _choose() -> void:
	var items: Array = _pages[-1].get("items", [])
	if _sel >= items.size() or items[_sel].get("dim", false):
		return
	var it: Dictionary = items[_sel]
	Game.sfx("Sounds/Menu/Accept.wav", -12.0)
	if it.has("setting"):
		# A steps a value up; the sound level goes round from full back to off.
		var up := 1 if it.setting != "volume" or Game.volume < Game.VOLUME_STEPS else -Game.VOLUME_STEPS
		Game.change_setting(it.setting, up)
		_build()
	elif it.get("id", "") == "settings":
		open(settings_page())
	elif it.get("id", "") == "controls":
		open(controls_page(_pages[-1].get("climbing", false)))
	else:
		chose.emit(it.get("id", ""))
