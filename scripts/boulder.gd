class_name Boulder
extends StaticBody2D
## A climbable boulder. Origin = bottom center of the rock.
## Set the fields below before adding it to the tree.

const NATURE := "Backgrounds/Tilesets/TilesetNature.png"
const CIRCUIT_YELLOW := Color("f2cf3a")

var boulder_id := ""
var title := ""
var grade := ""
var number := 0
var region := Rect2()  # rock sprite inside TilesetNature.png
var circuit := "Geel"  # circuit name shown in the info, and the colour of its arrows
var circuit_color := CIRCUIT_YELLOW
var height := "laag"  # "laag", "hoog" (needs the thick pad) or "highball" (both pads)
var indoor := false  # gym problem: plastic holds on plywood, climbable in the rain
var hold_color := Color()  # indoor: colour of the holds
var moves: Array = []  # fixed list of moves (indoor); empty = picked from the grade
var level := -1  # difficulty step (0 = easiest); -1 = work it out from the grade
var one_try := false  # comp: a single attempt, no "another go?"
var on_result := Callable()  # called with the climb result after each attempt (comp scoring)

var _tick: Sprite2D


func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = ActorSprite._cut(load(Game.ASSETS + NATURE), region)
	sprite.centered = false
	sprite.position = Vector2(-region.size.x / 2.0, -region.size.y)
	add_child(sprite)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(region.size.x - 6, region.size.y * 0.45)
	shape.shape = rect
	shape.position = Vector2(0, -rect.size.y / 2.0)
	add_child(shape)

	if number > 0:
		add_child(_circuit_arrow())
	# A chalk tick appears once you have topped it.
	_tick = PixelArt.sprite(PixelArt.from_rows(["o...o", "wo.ow", ".wow.", "..w.."], {"w": PixelArt.CHALK, "o": PixelArt.OUTLINE}), Vector2(region.size.x * 0.1, -region.size.y * 0.55), self)
	_tick.visible = Game.is_topped(boulder_id)
	add_to_group("interactable")


## A small painted yellow arrow on the rock, like the circuit markings in Font.
func _circuit_arrow() -> Polygon2D:
	var arrow := Polygon2D.new()
	arrow.color = circuit_color
	arrow.polygon = PackedVector2Array([Vector2(-2, 0), Vector2(2, 0), Vector2(2, -3), Vector2(4, -3), Vector2(0, -7), Vector2(-4, -3), Vector2(-2, -3)])
	arrow.position = Vector2(-region.size.x * 0.15, -region.size.y * 0.3)
	return arrow


func interact_rect() -> Rect2:
	return Rect2(global_position + Vector2(-region.size.x / 2.0, -region.size.y * 0.6), Vector2(region.size.x, region.size.y * 0.6 + 4))


func interact(player: Player) -> void:
	player.can_move = false
	player.sprite.face_towards(global_position + Vector2(0, -8))
	await _offer_climb()
	player.can_move = true


func _offer_climb() -> void:
	var where := "%s %d" % [circuit, number] if number > 0 else "Buiten het circuit"
	if indoor:
		where = "Karma bouldergym"
	var info := "%s\n%s  -  grade %s" % [title, where, grade]
	if height != "laag":
		info += "  -  " + height
	var missing := _missing_gear()
	if missing != "":
		await Dialog.say([info, missing])
		return
	if Game.is_raining() and not indoor:
		await Dialog.say([info, "Het zandsteen is nat, dan breekt\nhet. Vandaag naar de gym?"])
		return
	if Game.skin <= 0:
		await Dialog.say([info, "Je vingertoppen zijn op.\nSlaap eerst uit in je tent."])
		return
	if Game.hour >= Game.DARK:
		await Dialog.say([info, "Het is te donker om te klimmen.\nTijd voor het kampvuur."])
		return
	if one_try and boulder_id in Game.comp_score.get("tried", []):
		await Dialog.say([info, "Je comp-poging heb je gehad.\nVanaf morgen mag je weer."])
		return
	var moves := ClimbSession.chain_for(self).size()
	var status := "Al getopt!" if Game.is_topped(boulder_id) else "%d bewegingen." % moves
	await Dialog.say([info, "%s %s\nKlimmen?  Z = ja,  X = nee" % [status, _feel()]])
	if Dialog.last_button != "a":
		return
	while true:
		var first_try: bool = Game.attempts.get(boulder_id, 0) == 0
		var result: Array = await ClimbSession.climb(self, get_tree().root)  # [topped, failed move, practice]
		Game.spend_attempt(boulder_id, 1 if result[1] == "sloper" else 0, result[2])
		if result[0]:
			await _topped(first_try)
		if one_try:
			if not result[0]:
				Game.sfx("Sounds/Hit & Impact/Hit1.wav", -6.0)
				await Dialog.say(["Plof! Dat was je enige poging\nop comp-dag."])
		if on_result.is_valid():
			await on_result.call(result)
		if result[0] or one_try:
			return
		Game.sfx("Sounds/Hit & Impact/Hit1.wav", -6.0)
		if Game.skin <= 0:
			await Dialog.say(["Plof! Op de crashpad.", "Au, je vel is op voor vandaag.\nRust uit in je tent."])
			return
		var note := ""
		if result[2]:
			note = "\nNieuwe beweging: geen vel kwijt."
		elif result[1] == "sloper":
			note = "\nDie sloper kostte extra vel."
		await Dialog.say(["Plof! Op de crashpad." + note, "Nog een poging?\nZ = ja,  X = nee"])
		if Dialog.last_button != "a" or Game.hour >= Game.DARK:
			return


func _topped(first_try: bool) -> void:
	if Game.is_topped(boulder_id):
		await Dialog.say(["Getopt! Nog steeds een mooie lijn."])
		return
	Game.mark_topped(boulder_id)
	_tick.visible = true
	Game.sfx("Jingles/LevelUp1.wav", -6.0)
	if first_try:
		Game.add_beanies(2)
		await Dialog.say(["Geflasht: %s!\nIn een keer! Je krijgt 2 beanies." % title])
	else:
		Game.add_beanies(1)
		await Dialog.say(["Getopt: %s!\nJe krijgt een beanie." % title])
	# Finishing a whole circuit is what makes you stronger.
	if Game.CIRCUITS.has(circuit) and boulder_id in Game.CIRCUITS[circuit] and Game.circuit_done(circuit):
		Game.sfx("Jingles/LevelUp3.wav", -4.0)
		Game.changed.emit()
		await Dialog.say(["Het hele %s circuit is af!\nKlimniveau +1 (nu %d)." % [circuit.to_lower(), int(Game.climber_level())]])


## How hard this boulder feels for your climber level.
func _feel() -> String:
	var gap := Game.gap_for(ClimbSession.level_of(self))
	if gap <= 0.0:
		return "Goed te doen."
	if gap <= 1.5:
		return "Pittig voor jou."
	if gap <= 3.5:
		return "Heel zwaar voor jou."
	return "Veel te zwaar: train eerst!"


func _missing_gear() -> String:
	if height == "hoog" and not Game.has_gear("big_pad"):
		return "Dit blok is hoog. Zonder dikke\ncrashpad waag ik het niet."
	if height == "highball" and not (Game.has_gear("big_pad") and Game.has_gear("second_pad")):
		return "Een echte highball! Hiervoor wil\nik een dikke en een tweede pad."
	return ""
