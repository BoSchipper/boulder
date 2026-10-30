extends FontArea
## First area: Les Sables d'Or, a small sector with the yellow circuit, your tent,
## Margot's stall and Sanne's lost crashpad. The forester guards the path to
## Cul de Chien. Layout is set in _init(); shared building is in FontArea.

# Camp sprites in tileset_camp.png.
const CAMP := "Backgrounds/Tilesets/tileset_camp.png"
const TENT := Rect2(64, 0, 48, 48)
const FIRE_PIT := Rect2(160, 48, 32, 32)
const BLANKET := Rect2(128, 80, 32, 32)


func _init() -> void:
	area_id = "sables"
	area_name = "Les Sables d'Or\nFontainebleau"
	W = 60
	H = 36
	# Sand clearings and 2-wide paths, in tiles.
	sand_rects = [
		Rect2i(3, 23, 10, 7),   # start
		Rect2i(4, 29, 10, 4),   # camp
		Rect2i(21, 21, 11, 8),
		Rect2i(14, 5, 11, 8),
		Rect2i(33, 4, 13, 8),
		Rect2i(43, 19, 11, 9),
		Rect2i(13, 25, 8, 2),   # paths
		Rect2i(22, 13, 2, 8),
		Rect2i(25, 7, 8, 2),
		Rect2i(44, 12, 2, 7),
		Rect2i(32, 23, 11, 2),
		Rect2i(54, 22, 6, 2),   # to Cul de Chien
		Rect2i(26, 29, 2, 2),   # hidden nook behind La Dalle aux Fourmis
		Rect2i(24, 31, 6, 2),
	]
	boulder_list = [
		{"id": "geel1", "n": 1, "title": "La Premiere", "grade": "2", "rock": ROCK_MED, "grey": false, "at": Vector2i(9, 26)},
		{"id": "geel2", "n": 2, "title": "Le Toboggan", "grade": "2+", "rock": ROCK_TALL, "grey": true, "at": Vector2i(23, 25)},
		{"id": "geel3", "n": 3, "title": "La Dalle aux Fourmis", "grade": "3", "rock": ROCK_BIG, "grey": false, "at": Vector2i(29, 27)},
		{"id": "geel4", "n": 4, "title": "Le Pot de Chalk", "grade": "3+", "rock": ROCK_BIG, "grey": true, "at": Vector2i(19, 10)},
		{"id": "geel5", "n": 5, "title": "La Fissure du Lapin", "grade": "4a", "rock": ROCK_TALL, "grey": false, "at": Vector2i(37, 9), "height": "hoog"},
		{"id": "geel6", "n": 6, "title": "L'Ange Dechu", "grade": "4b", "rock": ROCK_MED_B, "grey": true, "at": Vector2i(49, 24)},
		{"id": "grandsaut", "n": 0, "title": "Le Grand Saut", "grade": "4c", "rock": ROCK_TALL, "grey": true, "at": Vector2i(42, 9), "height": "highball"},
	]
	pebbles = [Vector2i(5, 28), Vector2i(30, 22), Vector2i(17, 6), Vector2i(41, 5), Vector2i(52, 26), Vector2i(34, 10)]
	spawns = {"tent": Vector2i(7, 30), "sign": Vector2i(11, 25), "path": Vector2i(55, 22)}
	open_right = [[21 * TILE, 25 * TILE]]  # the path to Cul de Chien
	spot_everyone = true


func _place_area() -> void:
	_prop(SIGN, _feet(11, 24), Vector2(12, 5), [], Boulder.NATURE, _signpost.bind("Les Sables d'Or - Fontainebleau\nCircuit jaune: 6 blokken."))
	var pepe := _npc("Pepe Bleau", "OldMan", "", _feet(16, 11), [
		"Ah, een nieuwe!\nWelkom in Les Sables d'Or.",
		"Zie je die gele pijltjes?\nDat is het gele circuit.",
		"Begin maar bij nummer 1.\nDie ligt vlak bij de parking.",
		"Heb je het hele circuit gedaan?\nDan daag ik je uit. Hein!",
	])
	pepe.on_talk = func(_p: Player) -> void: await _legend_pepe(pepe)
	var sanne := _npc("Sanne", "Woman", "", _feet(5, 24), [])
	sanne.on_talk = func(_p: Player) -> void: await _crashpad_quest(sanne)
	if Game.quests.get("crashpad", "") in ["", "started"]:
		_place_lost_crashpad()
	var dog := _npc("Biscuit", "", "Dog", _feet(6, 25), ["Woef!", "(Biscuit snuffelt aan\nje magnesiumzak.)"])
	dog.sound = "Sounds/Creature/Dog.wav"
	var forester := _npc("Boswachter", "Villager", "", _feet(57, 22), [
		"Hier begint het pad naar\nde volgende sector.",
		"Ik laat alleen ervaren klimmers\ndoor. Verdien eerst 3 beanies!",
	])
	forester.gate_beanies = 3
	forester.open_lines = [
		"Drie beanies! Jij weet wat\nklimmen is.",
		"Ga maar: het pad naar Cul de Chien,\nhet zandstrand van Font!",
	]
	_place_camp()
	# Past the forester the path leads on to Cul de Chien.
	_exit_zone(Rect2(W * TILE - 6, 21 * TILE, 6, 3 * TILE), "culdechien", "path")
	if Game.flags.has("gate_open"):
		forester.gate_beanies = 0
		forester.lines = forester.open_lines.slice(1)
		forester.position = _feet(57, 20)
		return
	# The forester blocks the path; this wall closes the other lane.
	var gate := _wall(Rect2(56 * TILE, 21 * TILE, TILE, 3 * TILE))
	forester.gate_opened.connect(func():
		Game.flags["gate_open"] = true
		forester.lines = forester.open_lines.slice(1)
		gate.queue_free()
		create_tween().tween_property(forester, "position", _feet(57, 20), 0.6))


# --- legend: Pepe Bleau ------------------------------------------------------

func _legend_pepe(pepe: Npc) -> void:
	var info: Dictionary = Game.LEGENDS.pepe
	if Game.legends_beaten.has("pepe"):
		await Dialog.say(["Mijn muts staat je goed!\nZeg tegen niemand dat ik verloor."], info.name, pepe._face)
		return
	if not Game.can_challenge("pepe"):
		var left: int = info.requires.filter(func(b): return not Game.is_topped(b)).size()
		await Dialog.say(pepe.lines + ["Nog %d blok%s van het gele\ncircuit te gaan." % [left, "" if left == 1 else "ken"]], info.name, pepe._face)
		return
	await Dialog.say([
		"Het hele gele circuit? Pas mal.\nMaar ken je Les Sables echt?",
		"Op Le Pot de Chalk haal ik %d\nbewegingen. Doe jij er meer?" % info.score,
		"Je hebt drie levens. Uitdagen?\nZ = ja,  X = nee",
	], info.name, pepe._face)
	if Dialog.last_button != "a":
		await Dialog.say(["Kom maar terug als je durft."], info.name, pepe._face)
		return
	var target: Boulder
	for n in objects.get_children():
		if n is Boulder and n.boulder_id == info.boulder:
			target = n
	var result: Array = await ClimbSession.climb(target, get_tree().root, info)
	Game.spend_attempt(info.boulder, 0, true)
	if result[0]:
		Game.beat_legend("pepe")
		Game.sfx("Jingles/LevelUp3.wav", -4.0)
		await Dialog.say([
			"%d bewegingen! Ik ben verslagen.\nDat is me lang niet gebeurd." % result[3],
			"Hier, mijn wollen muts. Die\ndraag ik al sinds 1974.",
			"Je krijgt %s!\nKlimniveau +%d." % [info.beanie, int(Game.LEGEND_BONUS)],
		], info.name, pepe._face)
	else:
		await Dialog.say([
			"%d bewegingen. Niet slecht,\nmaar ik haalde er %d." % [result[3], info.score],
			"Train wat en kom terug.\nIk loop niet weg, hein.",
		], info.name, pepe._face)


# --- quest: Sanne's lost crashpad --------------------------------------

func _crashpad_quest(sanne: Npc) -> void:
	match Game.quests.get("crashpad", ""):
		"":
			Game.quests["crashpad"] = "started"
			await Dialog.say([
				"Hoi! Heb jij toevallig een\nblauwe crashpad gezien?",
				"Mijn vriend is hem kwijt. Hij\nklom bij La Dalle aux Fourmis.",
				"Misschien ligt hij daar ergens\nachter, tussen de bomen?",
			], "Sanne", sanne._face)
		"started":
			await Dialog.say(["Nog geen blauwe pad gezien?\nKijk eens achter de Dalle."], "Sanne", sanne._face)
		"found":
			Game.quests["crashpad"] = "done"
			Game.add_beanies(2)
			Game.sfx("Jingles/Success2.wav", -6.0)
			await Dialog.say([
				"Onze crashpad! Je bent een held.",
				"Hier, neem deze twee beanies.\nMerci!",
			], "Sanne", sanne._face)
		"done":
			await Dialog.say(["Dankzij jou kan mijn vriend\nweer veilig vallen. Merci!"], "Sanne", sanne._face)


func _place_lost_crashpad() -> void:
	var pad := Prop.new()
	pad.texture = _crashpad_art()
	pad.footprint = Vector2(20, 8)
	pad.position = _feet(27, 32)
	pad.on_use = func(_p: Player) -> void:
		Game.quests["crashpad"] = "found"
		Game.sfx("Sounds/Bonus/Bonus.wav", -6.0)
		pad.visible = false
		pad.remove_from_group("interactable")
		await Dialog.say(["Een blauwe crashpad! Dit moet\ndie van Sanne zijn.", "(Je neemt hem mee.)"])
		# Freed only after the dialog, so the pad's own interact() can finish.
		pad.queue_free()
	objects.add_child(pad)


## A folded blue crashpad seen from above, with two straps.
func _crashpad_art() -> ImageTexture:
	var blues := [Color("2a4f94"), Color("3d6fc8"), Color("6c9ce4"), Color("4a3a4a")]
	return PixelArt.shape(Vector2i(22, 14), blues, func(x: int, y: int) -> int:
		if (x == 0 or x == 21) and (y == 0 or y == 13): return -1
		if x == 0 or x == 21 or y == 0 or y == 13: return 9
		if x == 6 or x == 15: return 3
		if y == 1: return 2
		if y >= 11: return 0
		return 1)


## Your tent (sleep = next day, fresh skin), a campfire and Margot's gear stall.
func _place_camp() -> void:
	# Tent and fire pit block their whole area, so you can't walk behind or through them.
	_prop(TENT, _feet(5, 31), Vector2(44, 38), [], CAMP, _sleep)
	var fire := _prop(FIRE_PIT, _feet(9, 31), Vector2(28, 26), ["Het kampvuur knispert.\nLekker na een dag klimmen."], CAMP)
	fire.add_child(_flame())
	var blanket := Sprite2D.new()
	blanket.texture = ActorSprite._cut(load(Game.ASSETS + CAMP), BLANKET)
	blanket.position = _feet(12, 31) + Vector2(0, -6)
	blanket.z_index = -8
	add_child(blanket)
	var margot := _npc("Margot", "Villager2", "", _feet(13, 30), [])
	margot.on_talk = func(_p: Player) -> void:
		await Dialog.say(["Bonjour! Pads, schoenen, een\nventilator... alles voor beanies."], "Margot", margot._face)
		await Shop.open(get_tree().root)


func _sleep(_player: Player) -> void:
	await Dialog.say(["Je tent. Slapen tot morgen?\nZ = ja,  X = nee"])
	if Dialog.last_button != "a":
		return
	var fade := ColorRect.new()
	fade.color = Color(0.05, 0.03, 0.08, 0.0)
	fade.size = Vector2(480, 270)
	var layer := CanvasLayer.new()
	layer.layer = 9
	layer.add_child(fade)
	add_child(layer)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.6)
	await tween.finished
	Game.sleep()
	daylight.color = Game.daylight()
	Game.sfx("Jingles/Secret1.wav", -10.0)
	tween = create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(fade, "color:a", 0.0, 0.8)
	await tween.finished
	layer.queue_free()
	await Dialog.say(["Dag %d. Uitgerust, vel weer heel.\nHet is %s." % [Game.day, Game.condition().name]])


## A small flickering flame on top of the fire pit.
func _flame() -> AnimatedSprite2D:
	var flame := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	var pal := {"r": Color("e8562f"), "y": Color("ffd23f"), "w": Color("fff6c8")}
	for rows in [["..r..", ".ryr.", ".ryr.", "rywyr", ".rrr."], [".r...", "..rr.", ".ryr.", "ryyyr", ".rrr."], ["...r.", ".rr..", ".ryr.", "rywyr", ".rrr."]]:
		frames.add_frame("default", PixelArt.from_rows(rows, pal))
	frames.set_animation_speed("default", 8.0)
	flame.sprite_frames = frames
	flame.position = Vector2(0, -18)
	flame.play()
	return flame


