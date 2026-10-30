extends Node2D
## Karma bouldergym in the town of Fontainebleau: indoor problems on a plywood
## wall (also on rainy days), a campus board for the 1-5-9 and the exit to the map.
## Every Saturday the wall is reset with a new set and there is a comp: sign up
## at the desk by the entrance, then one try per problem for comp points. The
## new set stays up all week and can be climbed normally after the comp.

const WALL_TOP := 26
const WALL_BOTTOM := 112  # the foot of the wall, where the mats begin
const MATS_BOTTOM := 206

# The first set of problems (until the first Saturday), a wall section each.
const BASE_PROBLEMS := [
	{"id": "k_groen", "title": "Groene Vlinder", "grade": "4", "color": "5fbf4a", "level": 0, "moves": ["crimp", "pinch", "mantle"]},
	{"id": "k_blauw", "title": "Blauwe Maandag", "grade": "5a", "color": "3f7fd8", "level": 1, "moves": ["pinch", "footwork", "crimp", "mantle"]},
	{"id": "k_comp", "title": "De Lanceerbaan", "grade": "5b", "color": "e88a2f", "level": 2, "moves": ["footwork", "swing", "pinch", "mantle"]},
	{"id": "k_rood", "title": "Rode Draad", "grade": "5c", "color": "d8453f", "level": 3, "moves": ["sloper", "pinch", "heelhook", "dyno", "mantle"]},
	{"id": "k_zwart", "title": "Zwarte Zwaan", "grade": "6a", "color": "3a3540", "level": 4, "moves": ["beta", "pinch", "crimp", "heelhook", "swing", "mantle"]},
]
# New sets: one problem per colour, easy (green) to hard (black).
const SET_COLORS := ["5fbf4a", "3f7fd8", "e88a2f", "d8453f", "3a3540"]
const SET_GRADES := ["4", "5a", "5b", "5c", "6a"]
const SET_NAMES := ["Vlinder", "Maandag", "Lanceerbaan", "Draad", "Zwaan", "Kantelaar", "Druppel", "Wokkel",
	"Spaghetti", "Molentje", "Zandloper", "Kraai", "Pannenkoek", "Sprinkhaan", "Ruggengraat", "Bliksem"]
const SET_COLOR_WORDS := ["groen", "blauw", "oranje", "rood", "zwart"]
const MOVE_POOL := ["crimp", "sloper", "dyno", "footwork", "pinch", "beta", "heelhook", "swing"]
const COMP_RIVALS := ["Lin", "Mehdi", "Yara", "Bas"]
const SECTION_W := 72
const CAMPUS_X := 384  # campus board on the right of the wall

var objects := Node2D.new()
var player := Player.new()
var rng := RandomNumberGenerator.new()
var problems: Array = []
var joris: Npc


func _ready() -> void:
	problems = _week_problems()
	rng.seed = 2024 + Game.wall_set()  # holds move around with every new set
	_draw_room()
	objects.y_sort_enabled = true
	add_child(objects)
	for i in problems.size():
		_problem(i)
	_campus()
	_hangboard_rack()
	_people()
	_exit_door()
	_walls()
	_check_in_line()
	player.position = Vector2(240, 248)
	objects.add_child(player)
	player.sprite.facing = "up"
	var hud := Hud.new()
	hud.area_name = "Karma bouldergym\nFontainebleau"
	add_child(hud)
	var music := AudioStreamPlayer.new()
	var stream: AudioStreamOggVorbis = load(Game.ASSETS + "Audio/Musics/20 - Good Time.ogg")
	stream.loop = true
	music.stream = stream
	music.volume_db = -14.0
	add_child(music)
	music.play()


# --- the room -----------------------------------------------------------

func _draw_room() -> void:
	var img := Image.create(480, 270, false, Image.FORMAT_RGBA8)
	for y in 270:
		for x in 480:
			img.set_pixel(x, y, _room_pixel(x, y))
	PixelArt.sprite(ImageTexture.create_from_image(img), Vector2.ZERO, self).z_index = -10
	# Holds on the wall, in each problem's colour, plus tape at the start hold.
	for i in problems.size():
		var color := Color(problems[i].color)
		var x0 := 12 + i * SECTION_W
		for n in 9:
			var hold := _hold(color, rng.randi_range(6, 11), rng.randi_range(4, 7))
			var pos := Vector2(x0 + rng.randi_range(6, SECTION_W - 18), WALL_TOP + 4 + n * 8.5 + rng.randi_range(-2, 2))
			PixelArt.sprite(hold, pos, self).z_index = -9
		var tape := ColorRect.new()
		tape.color = color
		tape.size = Vector2(10, 3)
		tape.position = Vector2(x0 + SECTION_W / 2 - 5, WALL_BOTTOM - 10)
		tape.z_index = -9
		add_child(tape)


func _room_pixel(x: int, y: int) -> Color:
	if y < WALL_TOP - 6:
		# dark roof with strip lights
		if y > 6 and y < 10 and x % 80 > 12 and x % 80 < 60:
			return Color("f4f6e8")
		return Color("2f2e38") if (x / 8 + y / 8) % 2 == 0 else Color("2a2933")
	if y < WALL_TOP:
		return Color("4a4a56") if y < WALL_TOP - 1 else PixelArt.OUTLINE
	if y < WALL_BOTTOM:
		# plywood wall, a section per problem, campus board on the right
		var base := Color("b8a88c") if x < CAMPUS_X else Color("9a7a58")
		if (x - 12) % SECTION_W == 0 and x < CAMPUS_X:
			return base.darkened(0.35)
		if x >= CAMPUS_X and x < CAMPUS_X + 70 and (y - WALL_TOP) % 9 == 3:
			return Color("6b4a32")  # campus rungs
		if x % 8 == 4 and y % 8 == 4:
			return Color("5a5048")
		return base.darkened(0.06) if (y + x / 3) % 7 == 0 else base
	if y < WALL_BOTTOM + 2:
		return PixelArt.OUTLINE
	if y < MATS_BOTTOM:
		# thick blue mats with seams
		var mat := Color("3d63b8")
		if (x % 60 == 0) or (y - WALL_BOTTOM) % 46 == 0:
			return mat.darkened(0.3)
		if (y - WALL_BOTTOM) % 46 < 3:
			return mat.lightened(0.15)
		return mat if PixelArt.bayer(x, y) > 0.1 else mat.darkened(0.08)
	if y < MATS_BOTTOM + 2:
		return Color("2a3f7a")
	# wooden floor near the entrance
	var wood := Color("c79a6a") if (y / 8) % 2 == 0 else Color("bb8f60")
	if (x + (y / 8) * 37) % 64 == 0:
		return wood.darkened(0.25)
	return wood


## The reception desk: a wooden counter with a light top.
func _counter() -> ImageTexture:
	var wood := [Color("6b4a32"), Color("8a6142"), Color("c79a6a"), Color("e8c89a")]
	return PixelArt.shape(Vector2i(52, 26), wood, func(x: int, y: int) -> int:
		if x == 0 or x == 51 or y == 0 or y == 25 or y == 7: return 9
		if y < 7: return 3 if y < 3 else 2
		if x % 13 == 6: return 0
		return 1)


func _hold(color: Color, w: int, h: int) -> ImageTexture:
	var shades := PixelArt.hold_shades(color)
	return PixelArt.shape(Vector2i(w, h), shades, func(x: int, y: int) -> int:
		var nx := (x - (w - 1) / 2.0) / (w / 2.0)
		var ny := (y - (h - 1) / 2.0) / (h / 2.0)
		var d := nx * nx + ny * ny
		if d > 1.0: return -1
		if d > 0.6: return 9
		return 3 if ny < -0.2 else 2)


# --- things to do -----------------------------------------------------------

## This week's problems: the starting set, or a new set generated per Saturday.
func _week_problems() -> Array:
	var set_no := Game.wall_set()
	if set_no == 0:
		return BASE_PROBLEMS
	var r := RandomNumberGenerator.new()
	r.seed = set_no * 7907
	var list := []
	for i in 5:
		var moves := []
		for m in 3 + i / 2:
			var options := MOVE_POOL.filter(func(x): return moves.is_empty() or x != moves[-1])
			moves.append(options[r.randi() % options.size()])
		moves.append("mantle")
		list.append({"id": "k%d_%d" % [set_no, i], "title": "%s (%s)" % [SET_NAMES[r.randi() % SET_NAMES.size()], SET_COLOR_WORDS[i]],
			"grade": SET_GRADES[i], "color": SET_COLORS[i], "level": i, "moves": moves})
	return list


func _problem(i: int) -> void:
	var p: Dictionary = problems[i]
	var b := IndoorProblem.new()
	b.boulder_id = p.id
	b.title = p.title
	b.grade = p.grade
	b.level = p.level
	b.moves = p.moves
	b.hold_color = Color(p.color)
	b.section = Rect2(12 + i * SECTION_W, WALL_TOP, SECTION_W, WALL_BOTTOM - WALL_TOP)
	if Game.is_comp_day() and Game.wall_set() > 0:
		b.one_try = true
		b.on_result = _comp_result.bind(b)
	objects.add_child(b)


func _campus() -> void:
	var board := Prop.new()
	board.texture = ImageTexture.create_from_image(Image.create(70, 8, false, Image.FORMAT_RGBA8))
	board.footprint = Vector2.ZERO
	board.position = Vector2(CAMPUS_X + 35, WALL_BOTTOM + 4)
	board.on_use = _train
	objects.add_child(board)


## A freestanding hangboard rack near the entrance.
func _hangboard_rack() -> void:
	var wood := [Color("4a3424"), Color("6b4a32"), Color("a87a52"), Color("c79a6a")]
	var rack := Prop.new()
	rack.texture = PixelArt.shape(Vector2i(40, 36), wood, func(x: int, y: int) -> int:
		if y < 10:  # the board on top
			if y == 0 or y == 9 or x == 0 or x == 39: return 9
			if y == 4: return 9
			return 3 if y < 4 else 2
		if (x >= 3 and x <= 6) or (x >= 33 and x <= 36):  # two legs
			return 9 if x == 3 or x == 6 or x == 33 or x == 36 else 1
		return -1)
	rack.footprint = Vector2(40, 8)
	rack.position = Vector2(70, 250)
	rack.on_use = _hang
	objects.add_child(rack)


## Hangboard repeaters: a gym record to beat (most reps before the pump wins).
func _hang(_player: Player) -> void:
	if Game.skin <= 0:
		await Dialog.say(["Je vel is op. Eerst uitrusten."])
		return
	await Dialog.say(["Hangboard: repeaters.\nGymrecord: %d reps." % Game.hang_best, "Een poging? Kost 1 vel.\nZ = ja,  X = nee"])
	if Dialog.last_button != "a":
		return
	var drill := IndoorProblem.new()
	drill.boulder_id = "hangboard"
	drill.title = "Hangboard"
	drill.grade = "record"
	drill.level = 1
	drill.moves = ["hang"]
	drill.hold_color = Color("a87a52")
	drill.visible = false
	objects.add_child(drill)
	await ClimbSession.climb(drill, get_tree().root)
	drill.queue_free()
	Game.spend_attempt("hangboard", 0)
	var lines := ["%d reps gedaan." % Game.hang_last]
	if Game.hang_last > Game.hang_best:
		Game.hang_best = Game.hang_last
		Game.sfx("Jingles/LevelUp2.wav", -6.0)
		lines[0] += "\nNieuw gymrecord!"
	Game.changed.emit()
	await Dialog.say(lines)


## The 1-5-9 on the campus board: a gym record to beat, not a pass/fail.
## Each go costs 1 skin.
func _train(_player: Player) -> void:
	if Game.skin <= 0:
		await Dialog.say(["Je vel is op. Eerst uitrusten."])
		return
	var best := "%d - %d - %d" % Game.campus_best
	await Dialog.say(["Campusboard. Gymrecord: %s." % best, "Een poging? Kost 1 vel.\nZ = ja,  X = nee"])
	if Dialog.last_button != "a":
		return
	var drill := IndoorProblem.new()
	drill.boulder_id = "campus"
	drill.title = "Campus 1-5-9"
	drill.grade = "record"
	drill.level = 2
	drill.moves = ["campus"]
	drill.hold_color = Color("a87a52")
	drill.visible = false
	objects.add_child(drill)
	await ClimbSession.climb(drill, get_tree().root)
	drill.queue_free()
	Game.spend_attempt("campus", 0)
	var got: Array = Game.campus_last
	var lines := ["Je haalde %d - %d - %d." % got]
	if got[2] > Game.campus_best[2] or (got[2] == Game.campus_best[2] and got[1] > Game.campus_best[1]):
		Game.campus_best = got
		Game.sfx("Jingles/LevelUp2.wav", -6.0)
		lines[0] += "\nNieuw gymrecord!"
	Game.changed.emit()
	await Dialog.say(lines)


# --- Saturday comp -----------------------------------------------------

## A line across the room where the mats begin. On comp day Joris stops you
## there until you have signed up at the desk.
func _check_in_line() -> void:
	if not Game.is_comp_day() or Game.wall_set() == 0:
		return
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(480, 6)
	shape.shape = box
	shape.position = Vector2(240, MATS_BOTTOM - 2)
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(body: Node2D) -> void:
		if body == player and not Game.in_comp_today():
			_stop_at_desk())


func _stop_at_desk() -> void:
	player.can_move = false
	player.position.y = MATS_BOTTOM + 18
	await _sign_up()
	player.can_move = true


func _sign_up() -> void:
	if Game.comp_score.get("done", false) and Game.comp_day == Game.day:
		await Dialog.say(["De comp zit erop voor jou.\nGoed geklommen!"], "Joris", joris._face)
		return
	Game.comp_asked_day = Game.day
	await Dialog.say([
		"Hé, wacht even! Het is zaterdag:\ncomp-dag met een nieuwe wand!",
		"Vijf problemen, elk maar een\npoging. Inschrijven: 1 beanie.",
		"Doe je mee?  Z = ja,  X = nee",
	], "Joris", joris._face)
	if Dialog.last_button != "a":
		await Dialog.say(["Vandaag is de wand alleen voor\nde comp. Kom maandag terug!"], "Joris", joris._face)
		return
	if Game.beanies < 1:
		await Dialog.say(["Je hebt geen beanie voor het\ninschrijfgeld. Volgende week!"], "Joris", joris._face)
		return
	Game.beanies -= 1
	Game.comp_day = Game.day
	Game.comp_score = {"tops": 0, "zones": 0, "tried": [], "done": false}
	Game.changed.emit()
	await Dialog.say(["Je staat ingeschreven. Succes!\nTops en zones tellen."], "Joris", joris._face)


## After each comp attempt: count a top or zone (half the moves); after the
## fifth problem the results are in.
func _comp_result(result: Array, problem: IndoorProblem) -> void:
	var score: Dictionary = Game.comp_score
	if problem.boulder_id in score.tried:
		return
	score.tried.append(problem.boulder_id)
	if result[0]:
		score.tops += 1
		score.zones += 1
	elif result[3] * 2 >= problem.moves.size():
		score.zones += 1
	var left: int = problems.size() - score.tried.size()
	if left > 0:
		await Dialog.say(["Comp: %d tops, %d zones.\nNog %d probleem%s." % [score.tops, score.zones, left, "" if left == 1 else "en"]])
		return
	score.done = true
	await _comp_ranking(score)


func _comp_ranking(score: Dictionary) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = Game.wall_set() * 31337
	var scores := [{"name": "Jij", "tops": score.tops, "zones": score.zones}]
	for n in COMP_RIVALS:
		var t := clampi(r.randi_range(1, 4) + (1 if n == "Lin" else 0), 0, 5)
		scores.append({"name": n, "tops": t, "zones": clampi(t + r.randi_range(0, 1), 0, 5)})
	scores.sort_custom(func(a, b): return a.tops > b.tops or (a.tops == b.tops and (a.zones > b.zones or (a.zones == b.zones and a.name == "Jij"))))
	var rank := 0
	for i in scores.size():
		if scores[i].name == "Jij":
			rank = i + 1
	var rows := []
	for i in 3:
		rows.append("%d. %s  %d tops, %d zones" % [i + 1, scores[i].name, scores[i].tops, scores[i].zones])
	var lines := ["Uitslag van de comp!\n" + rows[0], rows[1] + "\n" + rows[2]]
	var prize: int = {1: 3, 2: 2, 3: 1}.get(rank, 0)
	if prize > 0:
		Game.add_beanies(prize)
		if rank == 1:
			Game.comp_wins += 1
		Game.sfx("Jingles/Success3.wav", -6.0)
		lines.append("Je werd %de! Je wint %d beanie%s." % [rank, prize, "s" if prize > 1 else ""])
	else:
		lines.append("Je werd %de. Volgende week beter!" % rank)
	await Dialog.say(lines, "Joris", joris._face)


func _people() -> void:
	# The desk sits by the entrance, so you walk past Joris when you come in.
	var desk := Prop.new()
	desk.texture = _counter()
	desk.footprint = Vector2(46, 18)
	desk.position = Vector2(300, 244)
	objects.add_child(desk)
	joris = Npc.new()
	joris.display_name = "Joris"
	joris.character = "Villager4"
	joris.lines = [
		"Welkom bij Karma! Hier klim je\nook als het buiten regent.",
		"Elke kleur is een probleem.\nGroen is het makkelijkst.",
		"Het campusboard rechts? Probeer\nhet gymrecord op de 1-5-9 te breken.",
		"Ook het hangboard bij de ingang\nheeft een gymrecord. Durf je?",
		"Elke zaterdag een nieuwe wand en\neen comp. Kom je ook?",
	]
	joris.position = Vector2(300, 220)
	objects.add_child(joris)
	joris.on_talk = func(_p: Player) -> void:
		if Game.is_comp_day() and Game.wall_set() > 0 and not Game.in_comp_today():
			await _sign_up()
		elif Game.in_comp_today() and not Game.comp_score.get("done", false):
			await Dialog.say(["Comp: %d tops, %d zones tot nu.\nSucces met de rest!" % [Game.comp_score.tops, Game.comp_score.zones]], "Joris", joris._face)
		else:
			await Dialog.say(joris.lines, "Joris", joris._face)
	var lin := Npc.new()
	lin.display_name = "Lin"
	lin.character = "Villager3"
	lin.lines = [
		"Ik train voor de comp! Het oranje\nprobleem heeft een echte sprong.",
		"Timing is alles: kracht in het\noranje, dan precies op de streep.",
	]
	lin.position = Vector2(196, 150)
	objects.add_child(lin)


func _exit_door() -> void:
	var door := Prop.new()
	var rows := []
	for y in 6:
		rows.append("oooooooooooooooooooooo" if y == 0 else "o" + "w".repeat(20) + "o")
	door.texture = PixelArt.from_rows(rows, {"o": PixelArt.OUTLINE, "w": Color("e8e2d0")})
	door.footprint = Vector2.ZERO
	door.position = Vector2(240, 270)
	door.on_use = func(_p: Player) -> void:
		var unfinished: bool = Game.in_comp_today() and not Game.comp_score.get("done", false)
		var lines := ["Naar buiten, terug naar de kaart?\nZ = ja,  X = nee"]
		if unfinished:
			lines = ["Je comp is nog niet af. Ga je weg,\ndan telt je score zoals hij nu is.", "Naar buiten?\nZ = ja,  X = nee"]
		await Dialog.say(lines)
		if Dialog.last_button == "a":
			if unfinished:
				Game.comp_score.done = true
				await _comp_ranking(Game.comp_score)
			Game.travel("map")
	objects.add_child(door)


func _walls() -> void:
	for r in [Rect2(0, 0, 480, WALL_BOTTOM + 6), Rect2(-16, 0, 16, 270), Rect2(480, 0, 16, 270), Rect2(0, 270, 480, 16)]:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = r.size
		shape.shape = box
		shape.position = r.get_center()
		body.add_child(shape)
		add_child(body)
