extends Microgame
## VOETJE!: steer your shoe onto the tiny foothold with the chalk tick and press A.
## The other chips are decoys. Good shoes give you more room for error.

const SHOE := [
	"..ossso........",
	"..ossso........",
	"..orrrro.......",
	"..orwwwoooo....",
	"..orrrrrrrroo..",
	".orrrrrrrrrrroo",
	".okkkkkkkkkkkko",
	"..oooooooooooo.",
]
const TOE := Vector2(14, 6)  # toe tip inside the shoe sprite
const MOVE_SPEED := 36.0

var shoe: Sprite2D
var target := Vector2.ZERO
var decoys: Array[Vector2] = []
var tolerance := Vector2(5, 4)  # how far the toe may be off, sideways / up-down
var placed := false
var rng := RandomNumberGenerator.new()


func setup() -> void:
	word = "VOETJE!"
	keys = ["KeyLeft", "KeyRight", "KeyZ"]
	duration = 4.5
	survive_wins = false
	rng.seed = seed_value
	if Game.has_gear("shoes"):
		tolerance = Vector2(8, 6)
	add_rock_background()
	var spots := [Vector2(28, 58), Vector2(62, 66), Vector2(96, 56), Vector2(122, 68), Vector2(80, 44), Vector2(44, 40)]
	for i in spots.size():
		var j := rng.randi_range(i, spots.size() - 1)
		var tmp: Vector2 = spots[i]
		spots[i] = spots[j]
		spots[j] = tmp
	target = spots[0]
	decoys = [spots[1], spots[2]]
	for spot in [target] + decoys:
		PixelArt.sprite(_chip(), spot - Vector2(3, 0), stage)
	# The chalk tick that marks the right foothold.
	PixelArt.sprite(PixelArt.from_rows(["w...", ".w.w", "..w."], {"w": PixelArt.CHALK}), target + Vector2(-2, -6), stage)
	var palette := PixelArt.SKIN.duplicate()
	palette["r"] = Color("c8463d")
	palette["k"] = Color("3a3040")
	shoe = PixelArt.sprite(PixelArt.from_rows(SHOE, palette), Vector2(rng.randi_range(10, 120), 10) - TOE, stage)
	hint("pijltjes = sturen,  Z = neerzetten op het streepje")


func tick(delta: float) -> void:
	if placed:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# A slightly shaky leg: small wobble that grows on harder grades.
	var wobble := Vector2(sin(_elapsed * 9.0), cos(_elapsed * 7.0)) * 3.0 * maxf(0.0, speed - 1.0)
	shoe.position += (dir * MOVE_SPEED * speed + wobble) * delta
	shoe.position = shoe.position.clamp(-TOE + Vector2(2, 4), STAGE - TOE - Vector2(2, 4))
	if Input.is_action_just_pressed("action_a"):
		placed = true
		var toe := shoe.position + TOE
		shoe.position = shoe.position.round()
		if _on(toe, target):
			Game.sfx("Sounds/Jump & Bounce/Bounce.wav", -10.0)
			var tween := create_tween()
			tween.tween_property(shoe, "position", target - TOE, 0.08)
			tween.tween_interval(0.25)
			tween.tween_callback(win.bind("Staat!"))
		else:
			var on_decoy := decoys.any(func(d: Vector2) -> bool: return _on(toe, d))
			var tween := create_tween()
			tween.tween_property(shoe, "position", shoe.position + Vector2(0, 40), 0.3).set_ease(Tween.EASE_IN)
			tween.tween_callback(lose.bind("Verkeerd voetje!" if on_decoy else "Weggeschoven!"))


func _on(toe: Vector2, hold: Vector2) -> bool:
	return absf(toe.x - hold.x) <= tolerance.x and absf(toe.y - hold.y) <= tolerance.y


func _chip() -> ImageTexture:
	return PixelArt.shape(Vector2i(7, 3), shades, func(x: int, y: int) -> int:
		if y == 0: return 9 if x > 0 and x < 6 else -1
		if y == 1: return 3 if x > 0 and x < 6 else 9
		return 0 if PixelArt.bayer(x, y) < 0.6 else -1)
