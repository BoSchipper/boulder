class_name BeanieArt
## Hand-drawn 13x11 beanie sprite. Our own art, so every beanie can get its own colour.

const PIXELS := [
	"....ooooo....",
	"...owwwwwo...",
	"...owwwwwo...",
	"..oorrrrroo..",
	".orlrrrrrrro.",
	".orlrrrrrrro.",
	"orrrrrrrrrrdo",
	"occccccccccco",
	"ocdcdcdcdcdco",
	"ocdcdcdcdcdco",
	".ooooooooooo.",
]


static func texture(color: Color) -> ImageTexture:
	var palette := {
		"o": Color("2b1d2e"),
		"w": Color("f4ead6"),
		"r": color,
		"l": color.lightened(0.35),
		"d": color.darkened(0.3),
		"c": color.darkened(0.18),
	}
	var img := Image.create(PIXELS[0].length(), PIXELS.size(), false, Image.FORMAT_RGBA8)
	for y in PIXELS.size():
		var row: String = PIXELS[y]
		for x in row.length():
			if palette.has(row[x]):
				img.set_pixel(x, y, palette[row[x]])
	return ImageTexture.create_from_image(img)
