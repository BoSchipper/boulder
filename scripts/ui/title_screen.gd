extends Control
## The title screen: the camp at dusk drifting slowly behind the name, and where to go. The
## picture is a screenshot of Les Sables d'Or (assets/ui/title_bg.png).

const AREAS := {
	"sables": "res://scenes/overworld/sables.tscn",
	"bas_cuvier": "res://scenes/overworld/bas_cuvier.tscn",
}

var _menu := MenuLayer.new()
var _bg := TextureRect.new()
var _t := 0.0


func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS  # the picture at full size
	get_tree().paused = false
	size = Vector2(480, 270)
	_bg.texture = load("res://assets/ui/title_bg.png")
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.size = Vector2(500, 281)  # a little larger than the screen: it drifts
	add_child(_bg)
	# Darker towards the left, where the name and the menu are.
	var shade := TextureRect.new()
	var g := GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.gradient.colors = PackedColorArray([Color(MenuLayer.INK, 0.62), Color(MenuLayer.INK, 0.0)])
	g.fill_to = Vector2(1, 0)
	g.width = 64
	g.height = 4
	shade.texture = g
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.size = Vector2(250, 270)
	add_child(shade)
	var title := Label.new()
	title.text = "FONTAINEBLEAU"
	title.add_theme_font_override("font", Game.font(Game.FONT_TITLE))
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", MenuLayer.GOLD)
	title.add_theme_color_override("font_outline_color", MenuLayer.INK)
	title.add_theme_constant_override("outline_size", 4)
	title.position = Vector2(34, 44)
	add_child(title)
	var orn := TextureRect.new()
	orn.texture = load("res://assets/ui/ornament.png")
	orn.position = Vector2(36, 86)
	add_child(orn)
	var sub := Label.new()
	sub.text = "a bouldering game"
	sub.add_theme_font_override("font", Game.font(Game.FONT_TEXT))
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", MenuLayer.SAND)
	sub.add_theme_color_override("font_outline_color", MenuLayer.INK)
	sub.add_theme_constant_override("outline_size", 2)
	sub.position = Vector2(82, 79)
	add_child(sub)
	_menu.closable = false
	add_child(_menu)
	_menu.chose.connect(_on_menu)
	# With progress kept from before you continue it; starting over asks first.
	var first: Array = [{"label": "Continue", "id": "continue"}, {"label": "New game", "id": "new"}] \
		if Game.has_progress() else [{"label": "Play", "id": "play"}]
	_menu.open({"at": Vector2(30, 112), "width": 128,
		"items": first + [{"label": "Choose area", "id": "areas"},
			{"label": "Settings", "id": "settings"}, {"label": "Controls", "id": "controls"},
			{"label": "Quit", "id": "quit"}]})


func _process(delta: float) -> void:
	_t += delta
	_bg.position = Vector2(-10.0 + sin(_t * 0.05) * 8.0, -5.5 + cos(_t * 0.04) * 4.0)


func _on_menu(id: String) -> void:
	match id:
		"play":
			get_tree().change_scene_to_file(AREAS.sables)
		"continue":
			var at := Game.area if ResourceLoader.exists(Game.area) else AREAS.sables
			get_tree().change_scene_to_file(at)
		"new":
			_menu.open({"title": "NEW GAME", "at": Vector2(30, 112), "width": 200,
				"items": [{"label": "Keep my progress", "id": "new_no"}, {"label": "Start over", "id": "new_yes"}],
				"notes": {"new_yes": "Your logbook and topo\nstart empty again.",
					"new_no": "Back to the menu."}})
		"new_yes":
			Game.new_game()
			get_tree().change_scene_to_file(AREAS.sables)
		"new_no":
			_menu.back()
		"areas":
			_menu.open({"title": "AREAS", "at": Vector2(30, 112), "width": 200,
				"items": [{"label": "Les Sables d'Or", "id": "sables"}, {"label": "Bas Cuvier", "id": "bas_cuvier"}],
				"notes": {"sables": "The starting area,\nwith the yellow circuit.",
					"bas_cuvier": "Through the forest\nto La Marie-Rose."}})
		"sables", "bas_cuvier":
			get_tree().change_scene_to_file(AREAS[id])
		"quit":
			get_tree().quit()
