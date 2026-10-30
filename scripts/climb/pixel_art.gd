class_name PixelArt
## Small helpers for our own pixel art: sprites from text grids and generated rock.

const OUTLINE := Color("2b1d2e")
const CHALK := Color("f3eee2")
const SKIN := {"o": OUTLINE, "s": Color("f2c29a"), "d": Color("d08f68"), "l": Color("ffe2c4"), "w": Color("f6f1e8")}

const ROCK_ORANGE := [Color("7c4136"), Color("a65e45"), Color("c98158"), Color("e3a874")]
const ROCK_GREY := [Color("46524b"), Color("61705f"), Color("7f8f78"), Color("a2b294")]

const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


## Builds a texture from rows of characters; each character is a key in `palette`
## ('.' or any unknown character is transparent).
static func from_rows(rows: Array, palette: Dictionary) -> ImageTexture:
	var width := 0
	for row in rows:
		width = maxi(width, row.length())
	var img := Image.create(width, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if palette.has(row[x]):
				img.set_pixel(x, y, palette[row[x]])
	return ImageTexture.create_from_image(img)


## Dithered sandstone texture in 4 shades, with a few dark cracks.
static func rock(size: Vector2i, shades: Array, seed_value: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.028
	noise.fractal_octaves = 3
	var cracks := FastNoiseLite.new()
	cracks.seed = seed_value + 7
	cracks.noise_type = FastNoiseLite.TYPE_CELLULAR
	cracks.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
	cracks.frequency = 0.03
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var v := noise.get_noise_2d(x, y) * 0.5 + 0.5  # 0..1
			v += (BAYER[y % 4][x % 4] / 16.0 - 0.5) * 0.08
			var c: Color = shades[clampi(int(v * 4.0), 0, 3)]
			if cracks.get_noise_2d(x, y) > 0.93:
				c = shades[0].darkened(0.25)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## Shades for plastic gym holds of one colour (dark to light).
static func hold_shades(color: Color) -> Array:
	return [color.darkened(0.45), color.darkened(0.2), color, color.lightened(0.35)]


## A gym wall: flat plywood panels with seams and a grid of bolt holes.
static func plywood(size: Vector2i, seed_value: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.08
	var base := Color("b8a88c")
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var grain := noise.get_noise_2d(x * 0.3, y * 2.0)
			var c := base.darkened(0.06) if grain > 0.25 else base
			if x % 50 == 0 or y % 40 == 0:
				c = base.darkened(0.3)  # panel seams
			elif x % 8 == 4 and y % 8 == 4:
				c = Color("5a5048")  # bolt holes
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## A filled shape from a function (x, y) -> shade index 0-3 (8 = chalk, 9 = outline, -1 = transparent).
static func shape(size: Vector2i, shades: Array, fn: Callable) -> ImageTexture:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var i: int = fn.call(x, y)
			if i >= 0:
				img.set_pixel(x, y, OUTLINE if i == 9 else (CHALK if i == 8 else shades[i]))
	return ImageTexture.create_from_image(img)


static func bayer(x: int, y: int) -> float:
	return BAYER[y % 4][x % 4] / 16.0


static func sprite(tex: Texture2D, pos: Vector2, parent: Node) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = pos
	parent.add_child(s)
	return s
