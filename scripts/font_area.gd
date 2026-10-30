class_name FontArea
extends Node2D
## Shared base for the outdoor areas in Font: sandy ground with grass, a forest
## around it, boulders, people, projecting climbers, HUD, rain and music.
## An area sets its layout in _init() and adds its own things in _place_area().

const TILE := 16

# Rock sprites in TilesetNature.png (orange and grey sandstone).
const ROCK_MED := Rect2(240, 160, 32, 32)
const ROCK_MED_B := Rect2(240, 192, 32, 32)
const ROCK_BIG := Rect2(272, 160, 64, 48)
const ROCK_TALL := Rect2(336, 160, 32, 48)
const GREY := Vector2(0, 64)  # grey version sits 64 px below the orange one
const PEBBLES := [Rect2(272, 208, 16, 16), Rect2(288, 208, 16, 16), Rect2(304, 208, 16, 16)]

const PINE := Rect2(32, 0, 32, 32)
const ROUND_TREE := Rect2(0, 0, 32, 32)
const BIG_TREE := Rect2(48, 288, 48, 48)
const CLUSTER_DARK := Rect2(0, 32, 64, 48)
const CLUSTER_LIGHT := Rect2(64, 32, 64, 48)
const SIGN := Rect2(80, 128, 16, 16)

# Ground tiles in assets/tiles/ (grass with a sand recolour).
const G_GRASS := Vector2i(0, 5)
const G_GRASS_TUFTS := [Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5)]
const G_SAND_EXTRA := [Vector2i(0, 4), Vector2i(1, 4)]

const MOVE_NAMES := {"crimp": "een crimp", "sloper": "een sloper", "dyno": "een dyno", "footwork": "een klein voetje",
	"pinch": "een pinch", "beta": "een lange beta", "heelhook": "een heelhook", "mantle": "de mantle"}

# --- layout, set by each area in _init() --------------------------------
var area_id := ""
var area_name := ""
var W := 60  # map size in tiles
var H := 36
var sand_rects: Array = []  # sandy areas; overlapping rects merge
var grass_rects: Array = []  # grass islands cut out of the sand
var boulder_list: Array = []  # dicts: id, n, title, grade, rock, grey, at, [height, circuit, color, level]
var pebbles: Array = []  # tile positions
var ground_texture := "res://assets/tiles/ground_font.png"
var music := "Audio/Musics/27 - Chill.ogg"
var layout_seed := 1958
var spawns := {}  # spawn name -> tile
var tree_kinds := [PINE, PINE, PINE, ROUND_TREE, BIG_TREE, CLUSTER_DARK, CLUSTER_LIGHT]
var tree_count := 260
var open_left := []  # pixel y ranges [from, to] on the left edge kept free of trees (exits)
var open_right := []  # same for the right edge
var spot_everyone := true  # do all projecting climbers here want a spotter?

var rng := RandomNumberGenerator.new()
var sand := {}  # Vector2i -> true
var blocked: Array[Rect2] = []  # pixel rects where no random tree may go
var objects := Node2D.new()
var player := Player.new()
var daylight := CanvasModulate.new()


func _ready() -> void:
	rng.seed = layout_seed  # fixed, so the forest looks the same every run
	for r in sand_rects:
		_fill(r, true)
	for r in grass_rects:
		_fill(r, false)

	_build_ground()
	objects.y_sort_enabled = true
	add_child(objects)
	_place_boulders()
	_place_area()
	_place_projectors()
	_place_forest()
	_build_walls()

	var at: Vector2i = spawns.get(Game.spawn, spawns.values()[0])
	player.position = _feet(at.x, at.y)
	objects.add_child(player)
	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = W * TILE
	cam.limit_bottom = H * TILE
	player.add_child(cam)

	_build_hud()
	_build_rain()
	_play_music()


## Area-specific people, props and quests.
func _place_area() -> void:
	pass


func _fill(r: Rect2i, is_sand: bool) -> void:
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			if is_sand:
				sand[Vector2i(x, y)] = true
			else:
				sand.erase(Vector2i(x, y))


func _feet(tx: int, ty: int) -> Vector2:
	return Vector2(tx * TILE + 8, ty * TILE + 12)


# --- ground -------------------------------------------------------------

func _build_ground() -> void:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	var source := TileSetAtlasSource.new()
	source.texture = load(ground_texture)
	source.texture_region_size = Vector2i(TILE, TILE)
	for x in 11:
		for y in 7:
			if source.has_room_for_tile(Vector2i(x, y), Vector2i.ONE, 1, Vector2i.ZERO, 1):
				source.create_tile(Vector2i(x, y))
	tileset.add_source(source, 0)

	var layer := TileMapLayer.new()
	layer.tile_set = tileset
	layer.z_index = -10
	add_child(layer)
	for x in W:
		for y in H:
			var cell := Vector2i(x, y)
			layer.set_cell(cell, 0, _sand_tile(cell) if sand.has(cell) else _grass_tile())

	# Small tufts and leaves on the grass.
	var detail: Texture2D = load(Game.ASSETS + "Backgrounds/Tilesets/TilesetFloorDetail.png")
	for i in W * H / 15:
		var cell := Vector2i(rng.randi_range(0, W - 1), rng.randi_range(0, H - 1))
		if _near_sand(cell, 0):
			continue
		var deco := Sprite2D.new()
		var col := rng.randi_range(0, 7)
		deco.texture = ActorSprite._cut(detail, Rect2(col * 16, 32, 16, 16))
		deco.position = Vector2(cell * TILE) + Vector2(8, 8)
		deco.z_index = -9
		add_child(deco)


func _grass_tile() -> Vector2i:
	if rng.randf() < 0.12:
		return G_GRASS_TUFTS[rng.randi() % G_GRASS_TUFTS.size()]
	return G_GRASS


# Picks the sand tile with the right grass edges, based on its neighbours.
func _sand_tile(c: Vector2i) -> Vector2i:
	var n := sand.has(c + Vector2i.UP)
	var s := sand.has(c + Vector2i.DOWN)
	var w := sand.has(c + Vector2i.LEFT)
	var e := sand.has(c + Vector2i.RIGHT)
	if not w and not e:
		if n and s: return Vector2i(3, 1)
		if s: return Vector2i(3, 0)
		if n: return Vector2i(3, 2)
		return Vector2i(3, 3)
	if not n and not s:
		if w and e: return Vector2i(1, 3)
		if e: return Vector2i(0, 3)
		return Vector2i(2, 3)
	var x := 1 if (w and e) else (0 if e else 2)
	var y := 1 if (n and s) else (0 if s else 2)
	if x == 1 and y == 1:
		# Inner corners where a diagonal neighbour is grass.
		if not sand.has(c + Vector2i(1, 1)): return Vector2i(5, 1)
		if not sand.has(c + Vector2i(-1, 1)): return Vector2i(6, 1)
		if not sand.has(c + Vector2i(1, -1)): return Vector2i(5, 2)
		if not sand.has(c + Vector2i(-1, -1)): return Vector2i(6, 2)
		if rng.randf() < 0.04:
			return G_SAND_EXTRA[rng.randi() % G_SAND_EXTRA.size()]
	return Vector2i(x, y)


func _near_sand(cell: Vector2i, radius: int) -> bool:
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if sand.has(cell + Vector2i(dx, dy)):
				return true
	return false


# --- objects ------------------------------------------------------------

func _place_boulders() -> void:
	for b in boulder_list:
		var boulder := Boulder.new()
		boulder.boulder_id = b.id
		boulder.number = b.n
		boulder.title = b.title
		boulder.grade = b.grade
		boulder.region = b.rock
		boulder.height = b.get("height", "laag")
		boulder.circuit = b.get("circuit", "Geel")
		boulder.circuit_color = Color(b.get("color", "f2cf3a"))
		boulder.level = b.get("level", -1)
		if b.grey:
			boulder.region.position += GREY
		boulder.position = _feet(b.at.x, b.at.y)
		objects.add_child(boulder)
	for at in pebbles:
		_prop(PEBBLES[rng.randi() % PEBBLES.size()], _feet(at.x, at.y), Vector2(10, 5))


## A signpost that shows where you are and leads to the map.
func _signpost(_player: Player, info: String) -> void:
	await Dialog.say([info, "Wegwijzer naar de rest van Font.\nKaart bekijken?  Z = ja,  X = nee"])
	if Dialog.last_button == "a":
		Game.travel("map")


## Walking off the map here takes you to another area.
func _exit_zone(rect: Rect2, to: String, at: String) -> void:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(body: Node2D) -> void:
		if body == player:
			Game.travel(to, at))


func _place_forest() -> void:
	# Dense edges so the area feels enclosed.
	for x in range(-8, W * TILE + 40, 44):
		_tree(CLUSTER_DARK, Vector2(x + rng.randi_range(-6, 6), 30 + rng.randi_range(-4, 4)), true)
		_tree(CLUSTER_DARK, Vector2(x + 22 + rng.randi_range(-6, 6), H * TILE + 14), true)
		_tree(PINE, Vector2(x + 20 + rng.randi_range(-6, 6), H * TILE - 12), true)
	for y in range(40, H * TILE, 30):
		if not _in_ranges(y, open_left):
			_tree(CLUSTER_DARK, Vector2(14 + rng.randi_range(-4, 4), y), true)
		if not _in_ranges(y, open_right):
			_tree(CLUSTER_DARK, Vector2(W * TILE - 14 + rng.randi_range(-4, 4), y), true)
	# Scattered trees in between, never on the sand.
	for i in tree_count:
		var cell := Vector2i(rng.randi_range(2, W - 3), rng.randi_range(3, H - 2))
		if _near_sand(cell, 1):
			continue
		_tree(tree_kinds[rng.randi() % tree_kinds.size()], _feet(cell.x, cell.y) + Vector2(rng.randi_range(-5, 5), 0), false)


func _in_ranges(y: int, ranges: Array) -> bool:
	return ranges.any(func(r): return y > r[0] and y < r[1])


func _tree(region: Rect2, feet: Vector2, force: bool) -> void:
	var trunk := Rect2(feet - Vector2(region.size.x * 0.4, 10), Vector2(region.size.x * 0.8, 12))
	if not force:
		for r in blocked:
			if r.intersects(trunk):
				return
	blocked.append(trunk)
	_prop(region, feet, Vector2(region.size.x * 0.6, 8))


func _prop(region: Rect2, feet: Vector2, footprint: Vector2, lines: Array = [], sheet := Boulder.NATURE, on_use := Callable()) -> Prop:
	var prop := Prop.new()
	prop.sheet = sheet
	prop.on_use = on_use
	prop.region = region
	prop.footprint = footprint
	prop.lines = lines
	prop.position = feet
	objects.add_child(prop)
	blocked.append(Rect2(feet - Vector2(region.size.x / 2.0, region.size.y * 0.5), Vector2(region.size.x, region.size.y * 0.5)))
	return prop


func _npc(display_name: String, character: String, animal: String, feet: Vector2, lines: Array) -> Npc:
	var npc := Npc.new()
	npc.display_name = display_name
	npc.character = character
	npc.animal = animal
	npc.lines = lines
	npc.position = feet
	objects.add_child(npc)
	blocked.append(Rect2(feet - Vector2(16, 24), Vector2(32, 32)))
	return npc


func _build_walls() -> void:
	_wall(Rect2(-TILE, -TILE, (W + 2) * TILE, TILE))
	_wall(Rect2(-TILE, H * TILE, (W + 2) * TILE, TILE))
	_wall(Rect2(-TILE, 0, TILE, H * TILE))
	_wall(Rect2(W * TILE, 0, TILE, H * TILE))


func _wall(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)
	add_child(body)
	return body


# --- projecting climbers ----------------------------------------------------

## Today's climbers projecting boulders here: more boulders, more people. The
## ones that want a spotter carry a bobbing "!".
func _place_projectors() -> void:
	var ids := []
	for b in boulder_list:
		if b.get("height", "laag") == "laag" and b.n > 0:  # circuit boulders only
			ids.append(b.id)
	for info in Game.todays_projectors(area_id, ids, spot_everyone):
		if info.state == "gone":
			continue
		var target: Boulder
		for n in objects.get_children():
			if n is Boulder and n.boulder_id == info.boulder:
				target = n
		var npc := _npc(info.name, info.character, "", target.position + Vector2(-target.region.size.x / 2.0 - 10, 2), [])
		npc.on_talk = func(_p: Player) -> void: await _talk_projector(npc, target, info)
		if info.state == "projecting" and info.wants_spot:
			var bubble := PixelArt.sprite(PixelArt.from_rows([
				".ooooo.", "owwrwwo", "owwrwwo", "owwrwwo", "owwwwwo", "owwrwwo", ".ooooo.", "...o...",
			], {"o": PixelArt.OUTLINE, "w": Color("fff6e4"), "r": Color("d9453c")}), Vector2(-3, -30), npc)
			var tween := create_tween().set_loops()
			tween.tween_property(bubble, "position:y", -32.0, 0.4)
			tween.tween_property(bubble, "position:y", -30.0, 0.4)
			npc.set_meta("bubble", bubble)


func _talk_projector(npc: Npc, target: Boulder, info: Dictionary) -> void:
	if info.state == "spotted":
		await Dialog.say(["Dankzij jouw spot durf ik\nhet nog een keer. Allez!"], info.name, npc._face)
		return
	if not info.wants_spot:
		await Dialog.say([
			"Ik werk vandaag aan %s.\nNog niet gelukt, maar bijna!" % target.title,
			"Ik val steeds bij %s." % MOVE_NAMES.get(ClimbSession.chain_for(target)[0], "de start"),
		], info.name, npc._face)
		return
	await Dialog.say([
		"Ik project %s vandaag.\nWil je me spotten?" % target.title,
		"Z = ja,  X = nee",
	], info.name, npc._face)
	if Dialog.last_button != "a":
		return
	var drill := Boulder.new()
	drill.boulder_id = "spot_" + target.boulder_id
	drill.title = "%s spotten" % info.name
	drill.grade = target.grade
	drill.region = target.region
	drill.level = 1
	drill.moves = ["spot"]
	drill.visible = false
	drill.position = Vector2(-500, -500)
	objects.add_child(drill)
	Game.spotting = info
	var result: Array = await ClimbSession.climb(drill, get_tree().root)
	drill.queue_free()
	Game.hour = mini(Game.DARK, Game.hour + 1)
	if npc.has_meta("bubble"):
		npc.get_meta("bubble").queue_free()
		npc.remove_meta("bubble")
	if result[0]:
		info.state = "spotted"
		Game.beta_day[target.boulder_id] = Game.day
		Game.add_beanies(1)
		var first: String = ClimbSession.chain_for(target)[0]
		await Dialog.say([
			"Merci! Zonder jou lag ik ernaast.\nHier, een beanie.",
			"Tip: het begint met %s.\nVandaag gaat hij je makkelijker af." % MOVE_NAMES.get(first, first),
		], info.name, npc._face)
	else:
		info.state = "gone"
		Game.changed.emit()
		await Dialog.say(["Au, mijn enkel... Ik stop voor\nvandaag. Volgende keer beter."], info.name, npc._face)
		npc.queue_free()


# --- HUD, weather & audio ---------------------------------------------------

func _build_hud() -> void:
	var hud := Hud.new()
	hud.area_name = area_name
	add_child(hud)
	add_child(daylight)
	daylight.color = Game.daylight()
	Game.changed.connect(func(): create_tween().tween_property(daylight, "color", Game.daylight(), 1.0))


## Grey light, falling streaks and the sound of rain on rainy days.
func _build_rain() -> void:
	if not Game.is_raining():
		return
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var rain := CPUParticles2D.new()
	rain.position = Vector2(240, -10)
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(300, 2)
	rain.amount = 160
	rain.lifetime = 0.9
	rain.direction = Vector2(-0.25, 1)
	rain.spread = 2.0
	rain.gravity = Vector2.ZERO
	rain.initial_velocity_min = 300.0
	rain.initial_velocity_max = 360.0
	var drop := Image.create(1, 5, false, Image.FORMAT_RGBA8)
	drop.fill(Color(0.75, 0.85, 1.0, 0.55))
	rain.texture = ImageTexture.create_from_image(drop)
	layer.add_child(rain)
	var sound := AudioStreamPlayer.new()
	sound.stream = load(Game.ASSETS + "Audio/Sounds/Ambient/Rain.wav")
	sound.volume_db = -14.0
	sound.finished.connect(sound.play)  # keep raining
	add_child(sound)
	sound.play()


func _play_music() -> void:
	var player_node := AudioStreamPlayer.new()
	var stream: AudioStreamOggVorbis = load(Game.ASSETS + music)
	stream.loop = true
	player_node.stream = stream
	player_node.volume_db = -12.0
	add_child(player_node)
	player_node.play()
