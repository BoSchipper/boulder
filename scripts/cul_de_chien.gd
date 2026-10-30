extends FontArea
## Cul de Chien (Trois Pignons): a wide plain of pale quartz sand, ringed by
## pines, with low boulders that land in soft sand. The orange circuit runs
## around the plain, a short blue one is harder, and the two roofs are long
## projects. Le Bilboquet, the mushroom rock in the middle, may not be climbed.

const ORANGE := "e88a2f"
const BLUE := "3f7fd8"


func _init() -> void:
	area_id = "culdechien"
	area_name = "Cul de Chien\nTrois Pignons"
	W = 64
	H = 40
	ground_texture = "res://assets/tiles/ground_cul_de_chien.png"
	music = "Audio/Musics/31 - Sunny.ogg"
	layout_seed = 1977
	sand_rects = [
		Rect2i(8, 6, 48, 28),   # the big plain
		Rect2i(5, 10, 3, 20),
		Rect2i(56, 9, 3, 20),
		Rect2i(12, 4, 38, 2),
		Rect2i(12, 34, 40, 2),
		Rect2i(0, 18, 5, 2),    # path in from Les Sables d'Or
	]
	# Little islands of heather and pines in the sand.
	grass_rects = [
		Rect2i(16, 10, 4, 3),
		Rect2i(44, 8, 5, 3),
		Rect2i(38, 28, 6, 3),
		Rect2i(10, 27, 3, 4),
		Rect2i(50, 21, 3, 4),
	]
	boulder_list = [
		{"id": "or1", "n": 1, "title": "Le Chien Couche", "grade": "3", "rock": ROCK_MED, "grey": false, "at": Vector2i(12, 15), "circuit": "Oranje", "color": ORANGE, "level": 2},
		{"id": "or2", "n": 2, "title": "La Plage", "grade": "3", "rock": ROCK_MED_B, "grey": true, "at": Vector2i(20, 21), "circuit": "Oranje", "color": ORANGE, "level": 2},
		{"id": "or3", "n": 3, "title": "Le Coquillage", "grade": "3+", "rock": ROCK_TALL, "grey": false, "at": Vector2i(18, 31), "circuit": "Oranje", "color": ORANGE, "level": 3},
		{"id": "or4", "n": 4, "title": "La Dune", "grade": "4a", "rock": ROCK_BIG, "grey": false, "at": Vector2i(28, 31), "circuit": "Oranje", "color": ORANGE, "level": 4},
		{"id": "or5", "n": 5, "title": "Le Sablier", "grade": "4a", "rock": ROCK_TALL, "grey": true, "at": Vector2i(36, 10), "circuit": "Oranje", "color": ORANGE, "level": 4, "height": "hoog"},
		{"id": "or6", "n": 6, "title": "La Queue du Chien", "grade": "4b", "rock": ROCK_MED, "grey": false, "at": Vector2i(42, 20), "circuit": "Oranje", "color": ORANGE, "level": 5},
		{"id": "or7", "n": 7, "title": "Le Pied Nu", "grade": "4b", "rock": ROCK_BIG, "grey": true, "at": Vector2i(50, 31), "circuit": "Oranje", "color": ORANGE, "level": 5},
		{"id": "or8", "n": 8, "title": "Le Grain de Sable", "grade": "4c", "rock": ROCK_TALL, "grey": false, "at": Vector2i(53, 14), "circuit": "Oranje", "color": ORANGE, "level": 6},
		{"id": "bl1", "n": 1, "title": "Le Bleu du Ciel", "grade": "5a", "rock": ROCK_BIG, "grey": true, "at": Vector2i(11, 24), "circuit": "Blauw", "color": BLUE, "level": 6},
		{"id": "bl2", "n": 2, "title": "La Mer de Sable", "grade": "5b", "rock": ROCK_TALL, "grey": true, "at": Vector2i(29, 25), "circuit": "Blauw", "color": BLUE, "level": 7, "height": "hoog"},
		{"id": "bl3", "n": 3, "title": "Le Desert", "grade": "5c", "rock": ROCK_MED_B, "grey": false, "at": Vector2i(46, 26), "circuit": "Blauw", "color": BLUE, "level": 7},
		# The two famous roofs: long, hard projects for later.
		{"id": "toit", "n": 0, "title": "Le Toit du Cul de Chien", "grade": "7a", "rock": ROCK_BIG, "grey": true, "at": Vector2i(24, 13), "level": 8},
		{"id": "autretoit", "n": 0, "title": "L'Autre Toit", "grade": "8a", "rock": ROCK_BIG, "grey": false, "at": Vector2i(46, 14), "level": 10},
	]
	pebbles = [Vector2i(15, 18), Vector2i(26, 8), Vector2i(40, 33), Vector2i(54, 24), Vector2i(33, 28)]
	spawns = {"path": Vector2i(6, 18)}
	open_left = [[18 * TILE, 20 * TILE]]  # the path back to Les Sables d'Or
	tree_kinds = [PINE, PINE, PINE, PINE, CLUSTER_DARK]  # mostly Scots pines here
	tree_count = 320
	spot_everyone = false


func _place_area() -> void:
	_prop(SIGN, _feet(7, 16), Vector2(12, 5), [], Boulder.NATURE,
		_signpost.bind("Cul de Chien - Trois Pignons\nOranje: 8 blokken. Blauw: 3."))
	_exit_zone(Rect2(0, 18 * TILE, 6, 2 * TILE), "sables", "path")
	_bilboquet()
	# Pines on the heather islands and a few lone ones in the sand.
	for at in [Vector2i(17, 12), Vector2i(19, 11), Vector2i(46, 10), Vector2i(40, 30), Vector2i(42, 29),
			Vector2i(11, 29), Vector2i(51, 24), Vector2i(34, 6), Vector2i(22, 34), Vector2i(57, 18)]:
		_tree(PINE, _feet(at.x, at.y), true)
	_npc("Luc", "Villager", "", _feet(26, 19), [
		"Wij noemen dit het strand van\nParijs. Alleen de zee ontbreekt.",
		"En zacht landen in het zand!\nPerfect voor de kinderen.",
	])
	_npc("Lotte", "Child", "", _feet(27, 20), [
		"Mag ik op de paddenstoel?\nPapa zegt nee...",
	])
	_npc("Garde Forestier", "OldMan2", "", _feet(35, 22), [
		"Dat is Le Bilboquet. Hier klim je\nniet op: hij is te kwetsbaar.",
		"De daken daar zijn beroemd.\nLe Toit is een echte 7A!",
	])


## The mushroom rock in the middle of the plain. Off limits.
func _bilboquet() -> void:
	# Pale, weathered grey-beige sandstone.
	var shades := [Color("6b675a"), Color("918b76"), Color("b6ae94"), Color("d6ceb2")]
	var size := Vector2i(54, 64)
	var tex := PixelArt.shape(size, shades, func(x: int, y: int) -> int:
		var cx := 26.5
		# cap: a wide, flattened dome on top
		var nx := (x - cx) / 26.0
		var ny := (y - 17.0) / 16.0
		var d := nx * nx + ny * ny
		var in_cap := d <= 1.0 and y <= 27
		# stem: narrow neck, flaring out at the foot
		var half := 7.0 + maxf(0.0, y - 50.0) * 0.7
		var in_stem := y > 25 and y < size.y and absf(x - cx) <= half
		if not in_cap and not in_stem:
			return -1
		if in_cap:
			if d > 0.9 or y == 27:
				return 9
			var light := -nx * 0.5 - ny * 0.9 + (PixelArt.bayer(x, y) - 0.5) * 0.4
			return clampi(int((light + 0.9) * 2.0), 0, 3)
		if absf(absf(x - cx) - half) < 1.0 or y == size.y - 1:
			return 9
		if y < 33:
			return 0  # shadow under the cap
		return 1 if x > cx + 1 else 2)
	var rock := Prop.new()
	rock.texture = tex
	rock.footprint = Vector2(20, 10)
	rock.lines = [
		"Le Bilboquet. Een bord zegt:\n\"Escalade interdite\".",
		"Hier mag je niet op klimmen.\nHij kan afbreken.",
	]
	rock.position = _feet(32, 19)
	objects.add_child(rock)
	blocked.append(Rect2(rock.position - Vector2(27, 64), Vector2(54, 64)))
