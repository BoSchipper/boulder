extends Node2D
## Map of the Forêt de Fontainebleau. Pick a place with the arrows, Z = go, X = back.
## Places outside Font stay locked until you are sponsored and get the van.

const PLACES := [
	{"id": "karma", "name": "Karma bouldergym", "pos": Vector2(96, 92), "flag": "Blue",
		"info": "In de stad. Binnen klimmen en\ntrainen, ook als het regent."},
	{"id": "sables", "name": "Les Sables d'Or", "pos": Vector2(270, 176), "flag": "Yellow",
		"info": "Het gele circuit.\n%d van de 7 blokken getopt."},
	{"id": "culdechien", "name": "Cul de Chien", "pos": Vector2(372, 168), "flag": "Red",
		"info": "Zandvlakte met dennen. Open\nna de boswachter (3 beanies)."},
	{"id": "cuvier", "name": "Bas Cuvier", "pos": Vector2(358, 86), "flag": "Gray",
		"info": "Het beroemde Bas Cuvier.\nKomt later."},
	{"id": "apremont", "name": "Apremont", "pos": Vector2(262, 232), "flag": "Gray",
		"info": "Woeste blokken tussen de heide.\nKomt later."},
	{"id": "beyond", "name": "Buiten Font", "pos": Vector2(446, 236), "flag": "Gray",
		"info": "Daarvoor heb je een sponsor\nen een eigen van nodig."},
]
const W := 480
const H := 270

var _index := 0
var _cursor := TextureRect.new()
var _title := Label.new()
var _info := Label.new()
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 42
	_draw_ground()
	_draw_roads()
	_draw_town(Vector2(96, 92))
	_scatter_trees()
	for p in PLACES:
		_flag(p)
	_build_ui()
	for i in PLACES.size():
		if PLACES[i].id == Game.area:
			_index = i
	_refresh()
	var music := AudioStreamPlayer.new()
	var stream: AudioStreamOggVorbis = load(Game.ASSETS + "Audio/Musics/23 - Road.ogg")
	stream.loop = true
	music.stream = stream
	music.volume_db = -14.0
	add_child(music)
	music.play()


func _is_open(id: String) -> bool:
	if id == "culdechien":
		return Game.flags.has("gate_open")
	return id in ["karma", "sables"]


# --- drawing ------------------------------------------------------------

## Forest floor in a few greens, dithered, with pale sandy heath patches.
func _draw_ground() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.012
	var sand := FastNoiseLite.new()
	sand.seed = 11
	sand.frequency = 0.02
	var greens := [Color("3f6b3a"), Color("4f7f41"), Color("5f924a"), Color("74a85a")]
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var v := noise.get_noise_2d(x, y) * 0.5 + 0.5 + (PixelArt.bayer(x, y) - 0.5) * 0.12
			var c: Color = greens[clampi(int(v * 4.0), 0, 3)]
			var s := sand.get_noise_2d(x, y)
			if s > 0.32:
				c = Color("e6d3a3") if s > 0.38 or PixelArt.bayer(x, y) < 0.5 else c
			# darker frame around the edge of the map
			var edge := minf(minf(x, W - 1 - x), minf(y, H - 1 - y))
			if edge < 6 and PixelArt.bayer(x, y) < (6 - edge) / 6.0:
				c = c.darkened(0.35)
			img.set_pixel(x, y, c)
	PixelArt.sprite(ImageTexture.create_from_image(img), Vector2.ZERO, self)


## Sandy paths between the places, as dotted lines.
func _draw_roads() -> void:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var order := ["karma", "sables", "sables", "culdechien", "culdechien", "cuvier", "sables", "apremont", "culdechien", "beyond"]
	for i in range(0, order.size() - 1, 2):
		var a: Vector2 = _place(order[i]).pos
		var b: Vector2 = _place(order[i + 1]).pos
		var steps := int(a.distance_to(b))
		for t in steps:
			if t % 6 < 4:
				var p := a.lerp(b, float(t) / steps) + Vector2(0, sin(t * 0.05) * 6.0)
				for o in [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
					var q := Vector2i(p + o)
					if q.x >= 0 and q.y >= 0 and q.x < W and q.y < H:
						img.set_pixel(q.x, q.y, Color("f3e8cc"))
	PixelArt.sprite(ImageTexture.create_from_image(img), Vector2.ZERO, self)


## A few roofs for the town of Fontainebleau around the gym.
func _draw_town(center: Vector2) -> void:
	var roof := PixelArt.from_rows([
		"..oooooo..",
		".orrrrrro.",
		"orrrrrrrro",
		"oddddddddo",
		"owwwwwwwwo",
		"owwkwwkwwo",
		"oooooooooo",
	], {"o": PixelArt.OUTLINE, "r": Color("c8563d"), "d": Color("8f3a2d"), "w": Color("efe2c8"), "k": Color("4a5a7a")})
	for offset in [Vector2(-34, -14), Vector2(-20, -22), Vector2(16, -18), Vector2(28, -6), Vector2(-30, 6), Vector2(22, 10), Vector2(-12, 16)]:
		PixelArt.sprite(roof, center + offset, self)


func _scatter_trees() -> void:
	var nature: Texture2D = load(Game.ASSETS + Boulder.NATURE)
	var bushes := [Rect2(0, 160, 16, 16), Rect2(16, 160, 16, 16), Rect2(48, 160, 16, 16)]
	for i in 260:
		var p := Vector2(rng.randi_range(4, W - 20), rng.randi_range(4, H - 20))
		var near := false
		for place in PLACES:
			if p.distance_to(place.pos) < 30.0:
				near = true
		if near:
			continue
		var tree := PixelArt.sprite(ActorSprite._cut(nature, bushes[rng.randi() % bushes.size()]), p, self)
		tree.modulate = Color(0.8, 0.9, 0.8)


func _flag(place: Dictionary) -> void:
	var sheet: Texture2D = load(Game.ASSETS + "Backgrounds/Animated/Flag/Flag%s16x16.png" % place.flag)
	var frames := SpriteFrames.new()
	for i in 4:
		frames.add_frame("default", ActorSprite._cut(sheet, Rect2(i * 16, 0, 16, 16)))
	frames.set_animation_speed("default", 6.0)
	var flag := AnimatedSprite2D.new()
	flag.sprite_frames = frames
	flag.position = place.pos + Vector2(0, -8)
	flag.play()
	if not _is_open(place.id):
		flag.modulate = Color(0.6, 0.6, 0.65)
	add_child(flag)
	var label := _label(place.name, Game.FONT_TITLE, 8)
	label.position = place.pos + Vector2(-60, 2)
	label.size = Vector2(120, 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not _is_open(place.id):
		label.modulate = Color(0.75, 0.75, 0.8)


# --- UI -----------------------------------------------------------------

func _build_ui() -> void:
	var title := _label("Foret de Fontainebleau", Game.FONT_TITLE, 16)
	title.position = Vector2(12, 8)
	var box := NinePatchRect.new()
	box.texture = load(Game.ASSETS + "Ui/Dialog/DialogueBoxSimple.png")
	for side in ["left", "right", "top", "bottom"]:
		box.set("patch_margin_" + side, 8)
	box.position = Vector2(12, 206)
	box.size = Vector2(200, 56)
	add_child(box)
	_title.position = Vector2(10, 6)
	_style(_title, Game.FONT_TITLE, 8, Dialog.TEXT_COLOR)
	box.add_child(_title)
	_info.position = Vector2(10, 16)
	_info.add_theme_constant_override("line_spacing", -2)
	_style(_info, Game.FONT_TEXT, 16, Dialog.TEXT_COLOR)
	box.add_child(_info)
	_cursor.texture = load(Game.ASSETS + "Ui/Arrow.png")
	add_child(_cursor)
	var help := _label("pijltjes = kiezen,  Z = reizen,  X = terug", Game.FONT_TEXT, 16)
	help.position = Vector2(220, 6)
	help.size = Vector2(250, 20)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _label(text: String, font_name: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	_style(label, font_name, size, Color("fff6e4"))
	label.add_theme_color_override("font_shadow_color", PixelArt.OUTLINE)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	return label


func _style(label: Label, font_name: String, size: int, color: Color) -> void:
	label.add_theme_font_override("font", Game.font(font_name))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


func _refresh() -> void:
	var place: Dictionary = PLACES[_index]
	_title.text = place.name + ("" if _is_open(place.id) else "  (dicht)")
	var info: String = place.info
	if place.id == "karma" and Game.is_comp_day():
		info = "Vandaag is het zaterdag:\ncomp in Karma!"
	elif place.id == "sables":
		info = info % Game.topped.keys().filter(func(k): return k.begins_with("geel") or k == "grandsaut").size()
	elif place.id == "culdechien" and Game.flags.has("gate_open"):
		var done := Game.topped.keys().filter(func(k): return k.begins_with("or") or k.begins_with("bl")).size()
		info = "Het zandstrand van Font.\n%d van de 11 circuitblokken getopt." % done
	_info.text = info


func _process(_delta: float) -> void:
	var bob := 2.0 if Time.get_ticks_msec() / 300 % 2 == 0 else 0.0
	_cursor.position = PLACES[_index].pos + Vector2(-6, -32 + bob)


func _unhandled_input(event: InputEvent) -> void:
	var step := 0
	if event.is_action_pressed("move_right") or event.is_action_pressed("move_down"):
		step = 1
	elif event.is_action_pressed("move_left") or event.is_action_pressed("move_up"):
		step = -1
	if step != 0:
		_index = (_index + step + PLACES.size()) % PLACES.size()
		Game.sfx("Sounds/Menu/Move1.wav", -12.0)
		_refresh()
	elif event.is_action_pressed("action_a"):
		var id: String = PLACES[_index].id
		if _is_open(id):
			Game.sfx("Sounds/Menu/Accept.wav", -10.0)
			Game.travel(id, {"sables": "sign", "culdechien": "path"}.get(id, "door"))
		else:
			Game.sfx("Sounds/Menu/Cancel.wav", -10.0)
	elif event.is_action_pressed("action_b"):
		Game.travel(Game.area, {"sables": "sign", "culdechien": "path"}.get(Game.area, "door"))


func _place(id: String) -> Dictionary:
	for p in PLACES:
		if p.id == id:
			return p
	return {}
