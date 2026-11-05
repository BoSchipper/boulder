class_name TopoScreen
extends CanvasLayer
## The topo of an area: a painted map with a badge for every block you know, the circuit and
## the blocks outside it in a list, and the logbook of the block you pick. A block you topped
## you can climb again from here. The map is a painting without markers (topo.png, with
## topo.json saying where each badge goes); this draws the badges and the text over it, so
## they follow what you do. Blocks outside the circuit show up once someone tells you.

signal closed
signal climb(block_id: String)

const SERIF := "res://assets/fonts/imfell/IMFeENrm28P.ttf"  # IM FELL English Roman (OFL, see THIRD_PARTY_NOTICES.md)
const SERIF_ITALIC := "res://assets/fonts/imfell/IMFeENit28P.ttf"  # IM FELL English Italic
const INK := Color8(66, 50, 38)
const INK_LIGHT := Color8(128, 100, 70)
const DARK := Color8(34, 27, 31)
const GOLD := Color8(222, 186, 110)
const GOLD_LIGHT := Color8(250, 228, 168)
const YELLOW := Color8(238, 196, 52)
const WHITE := Color8(250, 247, 238)
const STONE := Color8(236, 226, 204)
const STONE_SHADE := Color8(178, 166, 148)
const STONE_LINE := Color8(120, 108, 96)
const OK := Color8(72, 120, 62)
const OK_LIGHT := Color8(150, 210, 120)
const PICKED := Color(0.96, 0.86, 0.56, 0.7)
const YOU := Color8(84, 150, 214)

var data := {}
var meta := {}
var player_xz := Vector2.ZERO
var _map: Texture2D
var _k := 1.0  # canvas units per pixel of the map image
var _rows: Array[Dictionary] = []  # the blocks in the list, top to bottom
var _unknown: Array[Vector2] = []  # where blocks wait that nobody told you about yet
var _sel := 0
var _steer_held := true  # a stick still pushed when the topo opens does not move the choice
var _board := Control.new()
var _font: Font
var _italic: Font
var _digits: Font  # plain figures for the circuit numbers, like the numbers painted on the rock


## Read the area's topo: the map, the badge points, and which blocks you already know.
func setup(area_dir: String, area_meta: Dictionary, topo: Dictionary, player_at: Vector2) -> void:
	meta = area_meta
	data = topo
	player_xz = player_at
	_map = load(area_dir + str(data.image))
	_k = 480.0 / float(data.size[0])
	var badges: Dictionary = data.badges
	var circuit: Array = []
	for b in meta.boulders:
		if badges.has(b.get("id", "")) and str(b.id).begins_with("geel"):
			circuit.append(b)
	circuit.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.n) < int(b.n))
	for b in circuit:
		_rows.append({"id": b.id, "route": b.route, "tab": str(int(b.n)), "tab_color": YELLOW, "name": b.name,
			"grade": b.grade, "at": _point(badges[b.id]), "in_world": true, "outside": false})
	for o in data.get("outside", []):
		var at := _point(badges[o.id] if badges.has(o.id) else o.at)
		if not (o.get("known", false) or Game.known.has(o.id)):
			_unknown.append(at)
			continue
		var in_world := false
		var route := str(o.id)
		for b in meta.boulders:
			if b.get("id", "") == o.id:
				in_world = true
				route = b.route
		_rows.append({"id": o.id, "route": route, "tab": o.letter, "tab_color": WHITE, "name": o.name,
			"grade": o.grade, "at": at, "in_world": in_world, "outside": true})


func _point(p: Array) -> Vector2:
	return Vector2(float(p[0]), float(p[1])) * _k


func _ready() -> void:
	layer = 15  # over the walking world and its text, under the fades
	_font = load(SERIF) if ResourceLoader.exists(SERIF) else ThemeDB.fallback_font
	_italic = load(SERIF_ITALIC) if ResourceLoader.exists(SERIF_ITALIC) else _font
	_digits = ThemeDB.fallback_font
	_board.size = Vector2(480, 270)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # a painting, not pixel art
	_board.draw.connect(_draw_board)
	_board.modulate.a = 0.0
	add_child(_board)
	create_tween().tween_property(_board, "modulate:a", 1.0, 0.2)


func _process(_delta: float) -> void:
	var steer := Game.steer_vector()
	if absf(steer.y) < 0.5:
		_steer_held = false
	elif not _steer_held and not _rows.is_empty():
		_steer_held = true
		_sel = wrapi(_sel + int(signf(steer.y)), 0, _rows.size())
		Game.sfx("Sounds/Menu/Move2.wav", -14.0)
		_board.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("action_b") or event.is_action_pressed("to_menu") or event.is_action_pressed("topo"):
		get_viewport().set_input_as_handled()
		Game.sfx("Sounds/Menu/Cancel.wav", -12.0)
		closed.emit()
	elif event.is_action_pressed("action_a") and not _rows.is_empty():
		get_viewport().set_input_as_handled()
		var row: Dictionary = _rows[_sel]
		if row.in_world and Game.is_topped(row.id):
			climb.emit(row.id)


# ---------------------------------------------------------------- drawing
func _draw_board() -> void:
	_board.draw_texture_rect(_map, Rect2(Vector2.ZERO, _board.size), false)
	for at in _unknown:
		_badge(at, "", WHITE, "", 1.25, true, false)
	for i in _rows.size():
		if i != _sel:
			_draw_row_badge(_rows[i], false)
	if not _rows.is_empty():
		_draw_row_badge(_rows[_sel], true)  # the chosen one on top of the others
	_draw_you()
	_draw_lists()
	_draw_detail()


func _draw_row_badge(row: Dictionary, picked: bool) -> void:
	_badge(row.at, row.tab, row.tab_color, _status(row), 1.55 if picked else 1.25, false, picked)


## Flash, top, or nothing yet: a send counts, not how fast.
func _status(row: Dictionary) -> String:
	var entry: Dictionary = Game.logbook.get(row.route, {})
	if entry.get("flash", false):
		return "flash"
	if Game.is_topped(row.id) or entry.get("sends", 0) > 0:
		return "top"
	return ""


## A map marker over the spot `tip`: a dark medallion with a gold rim and a boulder drawn in
## it, a tab with the circuit number, a seal for a send (a bolt for a flash).
func _badge(tip: Vector2, tab: String, tab_color: Color, status: String, s: float, faded: bool, glow: bool) -> void:
	var a := 0.7 if faded else 1.0
	var r := 6.2 * s
	var c := tip - Vector2(0, 12.8 * s)
	if glow:
		_board.draw_circle(c, r + 4.0, Color(1.0, 0.93, 0.62, 0.2), true, -1.0, true)
		_board.draw_circle(c, r + 2.4, Color(1.0, 0.93, 0.62, 0.35), true, -1.0, true)
	_board.draw_colored_polygon(PackedVector2Array([tip, c + Vector2(-2.6 * s, r - 1.6), c + Vector2(2.6 * s, r - 1.6)]), _fade(DARK, a))
	_board.draw_circle(c, r + 0.9, _fade(DARK, a), true, -1.0, true)
	_board.draw_circle(c, r, _fade(GOLD, a), true, -1.0, true)
	_board.draw_circle(c, r - 0.5, _fade(GOLD_LIGHT, a), true, -1.0, true)
	_board.draw_circle(c, r - 1.2, _fade(DARK, a), true, -1.0, true)
	if faded:
		_text_centered(c + Vector2(0, 2.6 * s), "?", int(round(9 * s)), _fade(WHITE, a), _italic)
		return
	_stone(c + Vector2(0, 0.3 * s), r / 18.0 * 0.95)
	if tab != "":
		var tc := c + Vector2(r * 0.8, r * 0.72)
		var half := 3.3 * s
		var box := Rect2(tc - Vector2(half, half), Vector2(half, half) * 2.0)
		_board.draw_rect(box, tab_color)
		_board.draw_rect(box, DARK, false, 0.7)
		_text_centered(tc + Vector2(0, 2.2 * s), tab, int(round(6 * s)), DARK, _digits)
	if status != "":
		var sc := c + Vector2(r * 0.74, -r * 0.74)
		_board.draw_circle(sc, 2.9 * s, DARK, true, -1.0, true)
		_board.draw_circle(sc, 2.9 * s, GOLD, false, 0.5, true)
		if status == "flash":
			var bolt := PackedVector2Array()
			for p in [Vector2(0.4, -2.1), Vector2(-1.4, 0.3), Vector2(0, 0.3), Vector2(-0.7, 2.3), Vector2(1.4, -0.4), Vector2(0, -0.4), Vector2(1.1, -2.1)]:
				bolt.append(sc + p * s)
			_board.draw_colored_polygon(bolt, YELLOW)
		else:
			_board.draw_polyline(PackedVector2Array([sc + Vector2(-1.4, 0) * s, sc + Vector2(-0.3, 1.2) * s, sc + Vector2(1.5, -1.2) * s]), OK_LIGHT, 0.8 * s, true)


## The little boulder in a badge: round, lit from the top left, a layer line, on the ground.
func _stone(c: Vector2, k: float) -> void:
	var pts: Array[Vector2] = [Vector2(-11, 6), Vector2(-12, 0), Vector2(-8, -6), Vector2(-1, -9), Vector2(7, -8), Vector2(12, -2), Vector2(11, 6)]
	var outline := PackedVector2Array()
	for p in pts:
		outline.append(c + p * k)
	_board.draw_colored_polygon(outline, STONE)
	_board.draw_colored_polygon(PackedVector2Array([c + pts[3] * k, c + pts[4] * k, c + pts[5] * k, c + pts[6] * k, c + Vector2(-2, 6) * k]), STONE_SHADE)
	_board.draw_polyline(PackedVector2Array([c + Vector2(-9, -1) * k, c + Vector2(-2, 0.5) * k, c + Vector2(8, -1.5) * k]), STONE_LINE, 0.5, true)
	_board.draw_line(c + Vector2(-14, 7) * k, c + Vector2(14, 7) * k, GOLD, 0.6, true)


## Where you stand: a small blue dot on the map.
func _draw_you() -> void:
	var m: Array = data.get("world_to_map", [])
	if m.size() < 2:
		return
	var px := float(m[0][0]) * player_xz.x + float(m[0][1]) * player_xz.y + float(m[0][2])
	var py := float(m[1][0]) * player_xz.x + float(m[1][1]) * player_xz.y + float(m[1][2])
	var at := Vector2(px, py) * _k
	_board.draw_circle(at, 2.6, DARK, true, -1.0, true)
	_board.draw_circle(at, 1.9, YOU, true, -1.0, true)
	_board.draw_circle(at + Vector2(-0.5, -0.5), 0.6, Color(1, 1, 1, 0.8), true, -1.0, true)


func _draw_lists() -> void:
	var box := _rect(data.legend)
	var x := box.position.x + 1.0
	var w := box.size.x - 2.0
	var y := box.position.y + 9.0
	_board.draw_string(_font, Vector2(x, y), str(data.get("circuit", "Circuit")), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, INK)
	_board.draw_line(Vector2(x, y + 3.0), Vector2(x + 44.0, y + 3.0), YELLOW, 1.2)
	y += 13.0
	var outside_started := false
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		if row.outside and not outside_started:
			outside_started = true
			var ob := _rect(data.outside_box)
			y = ob.position.y + 9.0
			_board.draw_string(_font, Vector2(x, y), "Off the circuit", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, INK)
			y += 11.0
		_draw_row(row, i == _sel, x, y, w)
		y += 12.0 if not row.outside else 10.5
	if not _unknown.is_empty():
		if not outside_started:
			var ob := _rect(data.outside_box)
			y = ob.position.y + 9.0
			_board.draw_string(_font, Vector2(x, y), "Off the circuit", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, INK)
			y += 11.0
		var n := _unknown.size()
		_board.draw_string(_italic, Vector2(x, y), "?  %d more %s to find" % [n, "block" if n == 1 else "blocks"], HORIZONTAL_ALIGNMENT_LEFT, w, 7, INK_LIGHT)


func _draw_row(row: Dictionary, picked: bool, x: float, y: float, w: float) -> void:
	if picked:
		_board.draw_rect(Rect2(x - 2.0, y - 7.0, w + 3.0, 9.6), PICKED)
	var box := Rect2(x, y - 5.6, 6.4, 6.4)
	_board.draw_rect(box, row.tab_color)
	_board.draw_rect(box, INK, false, 0.6)
	_text_centered(box.get_center() + Vector2(0, 2.2), row.tab, 6, INK, _digits)
	var name_w := w - 25.0
	# a long name gets a size smaller before it is shortened
	var name_size := 7 if _font.get_string_size(row.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x <= name_w else 6
	_board.draw_string(_font, Vector2(x + 9.0, y), _fit(row.name, name_w, name_size), HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, INK)
	_board.draw_string(_font, Vector2(x + w - 15.0, y), row.grade, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, INK)
	var sx := x + w - 1.5
	var entry: Dictionary = Game.logbook.get(row.route, {})
	match _status(row):
		"flash":
			var bolt := PackedVector2Array()
			for p in [Vector2(0.6, -3.4), Vector2(-2.0, 0.6), Vector2(0, 0.6), Vector2(-1.0, 3.6), Vector2(2.2, -0.8), Vector2(0.2, -0.8), Vector2(1.8, -3.4)]:
				bolt.append(Vector2(sx, y - 2.4) + p)
			_board.draw_colored_polygon(bolt, YELLOW)
			_board.draw_polyline(bolt + PackedVector2Array([bolt[0]]), INK, 0.4, true)
		"top":
			_board.draw_polyline(PackedVector2Array([Vector2(sx - 2.2, y - 2.4), Vector2(sx - 0.6, y - 0.6), Vector2(sx + 2.4, y - 4.6)]), OK, 1.1, true)
		_:
			if entry.get("attempts", 0) > 0:
				var tries := "%dx" % entry.attempts
				var tw := _italic.get_string_size(tries, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
				_board.draw_string(_italic, Vector2(x + w - tw, y), tries, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, INK_LIGHT)


func _draw_detail() -> void:
	if _rows.is_empty():
		return
	var row: Dictionary = _rows[_sel]
	var box := _rect(data.detail)
	var x := box.position.x + 1.0
	var y := box.position.y + 10.0
	_board.draw_string(_font, Vector2(x, y), "%s  %s" % [row.name, row.grade], HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 2.0, 10, INK)
	var entry: Dictionary = Game.logbook.get(row.route, {})
	var line := "Not tried yet"
	if entry.get("flash", false):
		line = "Flash: first try"
	elif entry.get("sends", 0) > 0:
		line = "Sent in %d %s" % [entry.attempts, "try" if entry.attempts == 1 else "tries"] if entry.sends == 1 else "Climbed %d times" % entry.sends
	elif Game.is_topped(row.id):
		line = "Topped"
	elif entry.get("attempts", 0) > 0:
		line = "%d %s, no send yet" % [entry.attempts, "try" if entry.attempts == 1 else "tries"]
	elif not row.in_world:
		line = "Not found yet"
	_board.draw_string(_italic, Vector2(x, y + 12.0), line, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 2.0, 7, INK)
	var key_y := y + 30.0
	if row.in_world and Game.is_topped(row.id):
		var key := Game.button_name(JOY_BUTTON_A) if Game.using_pad else "Z"
		var kb := Rect2(x, key_y - 7.0, maxf(8.0, _font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 3.0), 8.6)
		_board.draw_rect(kb, DARK)
		_text_centered(kb.get_center() + Vector2(0, 2.4), key, 7, WHITE, _font)
		_board.draw_string(_font, Vector2(kb.end.x + 3.0, key_y), "Climb again", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, INK)
	elif row.in_world:
		_board.draw_string(_italic, Vector2(x, key_y), "Walk there to climb it", HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 2.0, 6, INK_LIGHT)


# ---------------------------------------------------------------- helpers
func _rect(r: Array) -> Rect2:
	var a := _point([r[0], r[1]])
	var b := _point([r[2], r[3]])
	return Rect2(a, b - a)


func _fade(c: Color, a: float) -> Color:
	return Color(c, c.a * a)


func _text_centered(at: Vector2, text: String, size: int, color: Color, font: Font) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_board.draw_string(font, Vector2(at.x - w / 2.0, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## A name that fits: shortened with an ellipsis if it is too long for the list.
func _fit(text: String, width: float, size: int) -> String:
	if _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
		return text
	var t := text
	while t.length() > 3 and _font.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges() + "…"
