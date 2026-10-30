class_name ClimbSession
extends CanvasLayer
## Plays a boulder as a chain of microgames, WarioWare style.
## Usage: var result: Array = await ClimbSession.climb(boulder, get_tree().root)
## result = [topped, name of the move you fell on ("" when topped),
##           practice (you fell on a move you had never tried before: no skin lost),
##           reached (how many moves you did before falling)]

signal done(success: bool, failed_move: String, practice: bool, reached: int)

const PANEL := Rect2(90, 48, 300, 170)
const GAMES := {
	"crimp": preload("res://scripts/climb/crimp.gd"),
	"sloper": preload("res://scripts/climb/sloper.gd"),
	"dyno": preload("res://scripts/climb/dyno.gd"),
	"mantle": preload("res://scripts/climb/mantle.gd"),
	"footwork": preload("res://scripts/climb/footwork.gd"),
	"pinch": preload("res://scripts/climb/pinch.gd"),
	"beta": preload("res://scripts/climb/beta.gd"),
	"heelhook": preload("res://scripts/climb/heelhook.gd"),
	"swing": preload("res://scripts/climb/swing.gd"),
	"campus": preload("res://scripts/climb/campus.gd"),
	"spot": preload("res://scripts/climb/spot.gd"),
	"hang": preload("res://scripts/climb/hangboard.gd"),
}
const GRADES := ["2", "2+", "3", "3+", "4a", "4b", "4c", "5a"]

var boulder: Boulder
var shades: Array
var chain: Array = []
var speed := 1.0
var level := 0
var drill := false  # training/spotting: no level gap
var legend := {}  # set for a legend challenge: name, score, pool (endless mode)
var lives := 3
var reached := 0
var _score_label: Label
var _hearts: Array[TextureRect] = []

var _clip := Control.new()
var _stage := Node2D.new()
var _ui := Control.new()
var _dots: Array[ColorRect] = []
var _fuse := ColorRect.new()
var _spark := ColorRect.new()
var _word := Label.new()
var _keys := HBoxContainer.new()
var _current: Microgame


static func climb(b: Boulder, parent: Node, legend_info := {}) -> Array:
	var session := ClimbSession.new()
	session.legend = legend_info
	session.boulder = b
	parent.add_child(session)
	var result: Array = await session.done
	session.queue_free()
	return result


static func level_of(b: Boulder) -> int:
	return b.level if b.level >= 0 else maxi(0, GRADES.find(b.grade))


## The moves of a boulder: always the same for the same boulder (so you can learn
## the beta), longer and faster on harder grades, and always ending with a mantle.
static func chain_for(b: Boulder) -> Array:
	if not b.moves.is_empty():
		return b.moves
	var level := maxi(0, GRADES.find(b.grade))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(b.boulder_id)
	var moves := []
	var pool := ["crimp", "sloper", "dyno", "footwork", "pinch", "beta", "heelhook"]
	for i in 2 + level / 2:
		var options := pool.filter(func(m): return moves.is_empty() or m != moves[-1])
		moves.append(options[rng.randi() % options.size()])
	moves.append("mantle")
	return moves


func _ready() -> void:
	layer = 5
	level = level_of(boulder)
	# Harder grades go faster; warm, sweaty afternoons make everything slippier.
	speed = (1.0 + level * 0.13) * Game.condition().friction
	# Someone showed you the beta today (circuit boulders only): a bit slower.
	if boulder.number > 0 and Game.beta_day.get(boulder.boulder_id, 0) == Game.day:
		speed *= 0.85
	if boulder.indoor:
		shades = PixelArt.hold_shades(boulder.hold_color)
	else:
		shades = PixelArt.ROCK_GREY if boulder.region.position.y >= 224 else PixelArt.ROCK_ORANGE
	if chain.is_empty():  # tests can set a chain
		chain = chain_for(boulder)
	drill = chain.any(func(m): return m in ["campus", "spot", "hang"])
	if not legend.is_empty():
		chain = []
	_build()
	_run()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.05, 0.1, 0.6)
	dim.size = Vector2(480, 270)
	add_child(dim)
	# Frame in the same colours as the dialog box.
	for ring in [[4, PixelArt.OUTLINE], [3, Color("e89b5a")], [1, PixelArt.OUTLINE]]:
		var r := ColorRect.new()
		r.color = ring[1]
		r.position = PANEL.position - Vector2.ONE * ring[0]
		r.size = PANEL.size + Vector2.ONE * ring[0] * 2
		add_child(r)
	_clip.position = PANEL.position
	_clip.size = PANEL.size
	_clip.clip_contents = true
	add_child(_clip)
	_stage.scale = Vector2(2, 2)
	_clip.add_child(_stage)
	_ui.position = PANEL.position
	_ui.size = PANEL.size
	add_child(_ui)

	var title := _label("%s   %s" % [boulder.title, boulder.grade], Game.FONT_TITLE, 8)
	title.position = Vector2(PANEL.position.x, PANEL.position.y - 18)
	if not legend.is_empty():
		title.text = "%s  vs  jij   -   %s" % [legend.name, boulder.title]
		_score_label = _label("", Game.FONT_TITLE, 8)
		_score_label.position = Vector2(PANEL.position.x, PANEL.end.y + 16)
		var heart := PixelArt.from_rows([".rr.rr.", "rrrrrrr", "rrrrrrr", ".rrrrr.", "..rrr..", "...r..."], {"r": Color("d9453c")})
		for i in lives:
			var icon := TextureRect.new()
			icon.texture = heart
			icon.position = Vector2(PANEL.end.x - 40 + i * 12, PANEL.position.y - 16)
			add_child(icon)
			_hearts.append(icon)
	for i in chain.size():
		var dot := ColorRect.new()
		dot.size = Vector2(8, 8)
		dot.position = Vector2(PANEL.end.x - (chain.size() - i) * 12 + 4, PANEL.position.y - 16)
		dot.color = Color("4a3a4a")
		add_child(dot)
		_dots.append(dot)

	# The fuse under the panel burns down like WarioWare's bomb.
	_fuse.color = Color("e9d6a8")
	_fuse.position = Vector2(PANEL.position.x, PANEL.end.y + 9)
	_fuse.size = Vector2(PANEL.size.x, 3)
	add_child(_fuse)
	_spark.size = Vector2(5, 5)
	add_child(_spark)

	_word.add_theme_font_override("font", Game.font(Game.FONT_TITLE))
	_word.add_theme_font_size_override("font_size", 32)
	_word.add_theme_color_override("font_color", Color("fff6e4"))
	_word.add_theme_color_override("font_outline_color", PixelArt.OUTLINE)
	_word.add_theme_constant_override("outline_size", 8)
	_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_word.size = Vector2(480, 60)
	_word.position = Vector2(0, 103)
	_word.pivot_offset = _word.size / 2
	_word.visible = false
	add_child(_word)
	_keys.alignment = BoxContainer.ALIGNMENT_CENTER
	_keys.add_theme_constant_override("separation", 6)
	_keys.size = Vector2(480, 26)
	_keys.position = Vector2(0, 150)
	add_child(_keys)


func _label(text: String, font_name: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", Game.font(font_name))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("fff6e4"))
	add_child(label)
	return label


## One microgame from setup to result: [success, reason].
func _play(kind: String, seed_offset: int) -> Array:
	var game: Microgame = GAMES[kind].new()
	game.stage = _stage
	game.ui = _ui
	game.shades = shades
	game.indoor = boulder.indoor
	# The first time you meet a move the word stays up a little longer (and a
	# fall there costs no skin), but it is not easier.
	var first_time := not Game.seen_moves.has(kind)
	Game.seen_moves[kind] = true
	# Above your climber level everything goes faster.
	var gap := 1.0 if drill else Game.gap_factor(level)
	game.speed = speed * gap
	game.seed_value = hash(boulder.boulder_id) + seed_offset
	add_child(game)
	game.setup()
	_current = game
	await _flash_word(game.word, 1.0 if first_time else 0.75, game.keys)
	game.running = true
	var result: Array = await game.finished
	_current = null
	return [result[0], result[1], game, first_time]


func _run() -> void:
	if not legend.is_empty():
		await _run_legend()
		return
	for i in chain.size():
		_dots[i].color = Color("fff6e4")
		var result: Array = await _play(chain[i], i)
		var game: Microgame = result[2]
		var first_time: bool = result[3]
		if result[0]:
			_dots[i].color = Boulder.CIRCUIT_YELLOW
			Game.sfx("Sounds/Bonus/Coin.wav" if i < chain.size() - 1 else "Jingles/Success1.wav", -8.0)
			await _flash_word(result[1] if result[1] != "" else "JA!", 0.45)
		else:
			_dots[i].color = Color("d9453c")
			Game.sfx("Sounds/Hit & Impact/Impact.wav", -6.0)
			await _flash_word(result[1] if result[1] != "" else "MIS!", 0.8)
		_clear_stage(game)
		if not result[0]:
			done.emit(false, chain[i], first_time, i)
			return
	done.emit(true, "", false, chain.size())


## Legend challenge: the legend climbs first and falls at their score. Then you
## get an endless chain from their favourite moves that speeds up every 4 moves.
## A fall costs a life and you retry that move; with no lives left it is over.
## You win by doing more moves than the legend.
func _run_legend() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(legend.name) + Game.day
	var base := speed
	await _rival_turn()
	_update_score()
	var kind := ""
	var tier := 0
	while lives > 0:
		if kind == "":
			kind = legend.pool[rng.randi() % legend.pool.size()]
		if reached / 4 > tier:
			tier = reached / 4
			await _flash_word("SNELLER!", 0.5)
		speed = base * (1.0 + 0.15 * tier)
		var result: Array = await _play(kind, reached)
		_clear_stage(result[2])
		if result[0]:
			reached += 1
			kind = ""
			Game.sfx("Sounds/Bonus/Coin.wav", -10.0)
			_update_score()
			if reached == legend.score + 1:
				Game.sfx("Jingles/Success1.wav", -6.0)
				await _flash_word("RECORD!", 0.8)
		else:
			lives -= 1
			_hearts[lives].modulate = Color(0.3, 0.3, 0.3)
			Game.sfx("Sounds/Hit & Impact/Impact.wav", -6.0)
			await _flash_word(result[1] if result[1] != "" else "MIS!", 0.6)
			if lives > 0:
				await _flash_word("NOG %d" % lives, 0.5)
	done.emit(reached > legend.score, "", false, reached)


func _rival_turn() -> void:
	await _flash_word("%s klimt..." % legend.name, 0.4)
	for i in legend.score:
		_score_label.text = "%s:  %d bewegingen" % [legend.name, i + 1]
		Game.sfx("Sounds/Menu/Move2.wav", -16.0)
		await get_tree().create_timer(0.12).timeout
	await _flash_word("Valt bij %d!" % legend.score, 0.7)
	await _flash_word("JOUW BEURT!", 0.5)


func _update_score() -> void:
	_score_label.text = "Jij: %d   -   %s: %d" % [reached, legend.name, legend.score]


func _process(_delta: float) -> void:
	var ratio := _current.time_left() if _current and _current.running else (1.0 if _current else 0.0)
	_fuse.size.x = roundf(PANEL.size.x * ratio)
	_spark.visible = _current != null and _current.running
	_spark.position = _fuse.position + Vector2(_fuse.size.x - 2, -1)
	_spark.color = Color("ffd23f") if Engine.get_frames_drawn() % 6 < 3 else Color("ff7b2f")


## Big instruction word, WarioWare style, with the keys to use underneath.
func _flash_word(text: String, hold: float, keys: Array = []) -> void:
	for child in _keys.get_children():
		child.queue_free()
	for key in keys:
		var icon := TextureRect.new()
		icon.texture = load(Game.ASSETS + "Ui/Input/Keyboard/%s.png" % key)
		icon.custom_minimum_size = Vector2(26, 26)
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		_keys.add_child(icon)
	_word.text = text
	_word.visible = true
	_word.scale = Vector2(2, 2)
	var tween := create_tween()
	tween.tween_property(_word, "scale", Vector2.ONE, 0.12)
	tween.tween_interval(hold)
	await tween.finished
	_word.visible = false
	for child in _keys.get_children():
		child.queue_free()


func _clear_stage(game: Microgame) -> void:
	for child in _stage.get_children():
		child.queue_free()
	for child in _ui.get_children():
		child.queue_free()
	game.queue_free()
