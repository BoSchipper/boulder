class_name Hud
extends CanvasLayer
## Top bar shared by all areas: beanies, skin, day/time/conditions, plus the
## area name that fades in when you arrive.

var area_name := ""

var _beanies := Label.new()
var _skin := Label.new()
var _clock := Label.new()


func _ready() -> void:
	var icon := TextureRect.new()
	icon.texture = BeanieArt.texture(Color("c8463d"))
	icon.position = Vector2(8, 7)
	icon.scale = Vector2(2, 2)
	add_child(icon)
	var skin_icon := TextureRect.new()
	skin_icon.texture = PixelArt.from_rows([".ooo.", "osslo", "ossso", "osddo", ".ooo."], PixelArt.SKIN)
	skin_icon.position = Vector2(62, 9)
	skin_icon.scale = Vector2(2, 2)
	add_child(skin_icon)
	for label in [_beanies, _skin, _clock]:
		_shadowed(label, Game.FONT_TEXT)
	_beanies.position = Vector2(38, 7)
	_skin.position = Vector2(78, 7)
	_clock.position = Vector2(330, 4)
	_clock.size = Vector2(142, 30)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock.add_theme_constant_override("line_spacing", -2)
	_refresh()
	Game.changed.connect(_refresh)
	if area_name != "":
		_banner()


func _shadowed(label: Label, font_name: String) -> void:
	label.add_theme_font_override("font", Game.font(font_name))
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_shadow_color", PixelArt.OUTLINE)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)


func _refresh() -> void:
	_beanies.text = str(Game.beanies)
	_skin.text = "%d/%d" % [Game.skin, Game.max_skin()]
	_skin.add_theme_color_override("font_color", Color("ff8a7a") if Game.skin <= 1 else Color.WHITE)
	_clock.text = "Dag %d (%s)   %02d:00\n%s" % [Game.day, Game.weekday(), Game.hour, Game.condition().name]


func _banner() -> void:
	var banner := Label.new()
	banner.text = area_name
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shadowed(banner, Game.FONT_TITLE)
	banner.add_theme_constant_override("line_spacing", -6)
	banner.size = Vector2(480, 40)
	banner.position = Vector2(0, 30)
	banner.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(0.4)
	tween.tween_property(banner, "modulate:a", 1.0, 0.8)
	tween.tween_interval(2.5)
	tween.tween_property(banner, "modulate:a", 0.0, 0.8)
