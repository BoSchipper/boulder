class_name ClimberFigure
extends Node2D
## The climber, seen from behind, drawn the way Cairn lights its people: a hard split
## between sun and shade, shade in the cool purple of the rock, a thin lit edge on the
## sunny side. The owner sets the pose every frame. With `silhouette` on, everything is
## drawn in one flat colour: that copy, shifted away from the sun, is the cast shadow.

# Compact, a little heroic: short strong limbs, so it reads as a climber and not a stick figure.
const UPPER_ARM := 18.0
const FOREARM := 16.0
const THIGH := 19.0
const SHIN := 18.0
const SHOULDER_W := 9.0
const HIP_W := 6.0
const TORSO := 28.0
const SHADE := Color8(84, 74, 104)  # the rock's shadow colour
const SKIN := Color8(224, 168, 128)
const SHIRT := Color8(184, 82, 62)
const PANTS := Color8(98, 100, 70)
const SHOE := Color8(110, 70, 120)
const HAT := Color8(232, 178, 70)
const HAIR := Color8(66, 44, 40)
const BAG := Color8(70, 120, 160)

var limbs: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var shoulders := Vector2.ZERO
var lifted := -1
var hand_state: Array[String] = ["grip", "grip"]  # grip, flat or reach
var sun := Vector2(-0.45, -0.9).normalized()  # where the light comes from, on screen
var silhouette := false
var leg_scale := 1.0  # legs swinging out towards you look shorter
var flat_color := Color.BLACK


func anchor(i: int) -> Vector2:
	var side := -1.0 if i == 0 or i == 2 else 1.0
	return shoulders + (Vector2(side * SHOULDER_W, 0) if i < 2 else Vector2(side * HIP_W, TORSO))


func _lit(c: Color) -> Color:
	return flat_color if silhouette else Color(minf(c.r * 1.1 + 0.07, 1), minf(c.g * 1.1 + 0.05, 1), minf(c.b * 1.1, 1))


func _shade(c: Color) -> Color:
	return flat_color if silhouette else Color(c.r * 0.3 + SHADE.r * 0.42, c.g * 0.3 + SHADE.g * 0.42, c.b * 0.3 + SHADE.b * 0.42)


func _plain(c: Color) -> Color:
	return flat_color if silhouette else c


## Two bones from root towards target; the joint bends out to the side, and `down` says
## whether it prefers to hang (an elbow, > 0) or to point up (a knee on a high foot, < 0).
static func ik(root: Vector2, target: Vector2, a: float, b: float, outward: float, down := 0.3) -> Array[Vector2]:
	var d := target - root
	var dist := minf(d.length(), a + b - 0.01)
	var end := root + d.normalized() * dist
	var ang := acos(clampf((a * a + dist * dist - b * b) / (2.0 * a * maxf(dist, 0.01)), -1.0, 1.0))
	var base := d.angle()
	var j1 := root + Vector2.from_angle(base + ang) * a
	var j2 := root + Vector2.from_angle(base - ang) * a
	var score := func(j: Vector2) -> float: return (j.x - root.x) * outward + down * (j.y - root.y)
	return [j1 if score.call(j1) >= score.call(j2) else j2, end]


func _draw() -> void:
	var hips := shoulders + Vector2(0, TORSO)
	for i in [2, 3]:
		var side := -1.0 if i == 2 else 1.0
		var bones := ik(anchor(i), limbs[i], THIGH * leg_scale, SHIN * leg_scale, side, -0.8)
		_limb(anchor(i), bones[0], 9.0, 8.0, PANTS)
		_limb(bones[0], bones[1], 8.0, 6.5, PANTS)
		_shoe(bones[1], side)
	for i in [0, 1]:
		var side := -1.0 if i == 0 else 1.0
		var bones := ik(anchor(i), limbs[i], UPPER_ARM, FOREARM, side)
		var mid := anchor(i).lerp(bones[0], 0.45)
		_limb(anchor(i), mid, 7.0, 6.5, SHIRT)  # a short sleeve
		_limb(mid, bones[0], 6.0, 5.5, SKIN)
		_limb(bones[0], bones[1], 5.5, 4.5, SKIN)
		_hand(bones[1], bones[1] - bones[0], hand_state[i], side)
	_torso(hips)
	_head(shoulders + Vector2(0, -10))


## A limb part in two tones, split hard down its length: sun on one side, shade on the
## other. How much is in shade depends on how the limb faces the sun.
func _limb(p: Vector2, q: Vector2, w1: float, w2: float, base: Color) -> void:
	var n := (q - p).orthogonal().normalized()
	if n.dot(sun) < 0.0:
		n = -n
	draw_colored_polygon(PackedVector2Array([p + n * w1 / 2, q + n * w2 / 2, q - n * w2 / 2, p - n * w1 / 2]), _lit(base))
	draw_circle(p, w1 / 2 - 0.5, _lit(base))
	draw_circle(q, w2 / 2 - 0.5, _lit(base))
	var k := 0.15 + 0.35 * absf(n.dot(sun))
	draw_colored_polygon(PackedVector2Array([p - n * (w1 / 2 - w1 * (1 - k)), q - n * (w2 / 2 - w2 * (1 - k)),
		q - n * w2 / 2, p - n * w1 / 2]), _shade(base))
	if not silhouette:
		draw_line(p + n * (w1 / 2 - 0.5), q + n * (w2 / 2 - 0.5), _lit(_lit(base)))
		draw_line(p - n * (w1 / 2 - 0.5), q - n * (w2 / 2 - 0.5), _shade(base).darkened(0.35))


func _torso(hips: Vector2) -> void:
	var s := shoulders
	var w := 10.0
	var toward := 1.0 if sun.x < 0.0 else -1.0  # which side of the back is in the sun
	draw_colored_polygon(PackedVector2Array([s + Vector2(-w, -2), s + Vector2(w, -2), s + Vector2(w * 0.8, 14),
		hips + Vector2(w * 0.62, 3), hips + Vector2(-w * 0.62, 3), s + Vector2(-w * 0.8, 14)]), _lit(SHIRT))
	draw_circle(s + Vector2(-toward * (w - 2), 0), 4.0, _lit(SHIRT))
	draw_circle(s + Vector2(toward * (w - 2), 0), 4.0, _shade(SHIRT))
	var t := toward
	draw_colored_polygon(PackedVector2Array([s + Vector2(t * w * 0.25, -2), s + Vector2(t * w, -2), s + Vector2(t * w * 0.8, 14),
		hips + Vector2(t * w * 0.62, 3), hips + Vector2(t * w * 0.2, 3)]), _shade(SHIRT))
	if not silhouette:
		draw_line(s + Vector2(-t * (w * 0.8 - 1), 6), hips + Vector2(-t * (w * 0.62 - 1), 2), _lit(_lit(SHIRT)))
		draw_line(s + Vector2(0, 3), hips + Vector2(0, -2), _shade(SHIRT).darkened(0.1))
		draw_arc(s + Vector2(-t * 5, 6), 4.0, PI * 1.1, PI * 1.9, 6, _lit(_lit(SHIRT)))
	draw_rect(Rect2(hips.x - w * 0.62, hips.y + 1, w * 1.24, 2), _plain(PANTS.darkened(0.3)))
	# The chalk bag hangs at the side, on the shady hip, with a little chalk on top.
	var bag := hips + Vector2(t * (w * 0.62 + 4), -3)
	draw_rect(Rect2(bag.x - 3, bag.y - 1, 6, 8), _plain(BAG))
	if not silhouette:
		draw_line(bag + Vector2(-3, 1), bag + Vector2(-3, 6), BAG.lightened(0.3))
		draw_line(bag + Vector2(-2, -1), bag + Vector2(2, -1), Color8(244, 240, 232))
		draw_line(bag + Vector2(1, 7), bag + Vector2(1, 10), Color8(120, 90, 60))


func _head(head: Vector2) -> void:
	draw_rect(Rect2(shoulders.x - 2, shoulders.y - 6, 4, 5), _shade(SKIN))
	draw_circle(head, 6.0, _plain(HAIR))
	draw_circle(head + Vector2(-6, 0.5), 1.2, _lit(SKIN))
	draw_circle(head + Vector2(6, 0.5), 1.2, _shade(SKIN))
	if not silhouette:
		for hx in [-3.0, 0.0, 3.0]:
			draw_line(head + Vector2(hx, 2), head + Vector2(hx + 1, 6), HAIR.darkened(0.25))
	# A beanie: a half circle over the head, a rib band, a pompom.
	var top := PackedVector2Array()
	for k in 9:
		top.append(head + Vector2.from_angle(PI + PI * k / 8.0) * 6.5 + Vector2(0, -1))
	draw_colored_polygon(top, _lit(HAT))
	var side := 1.0 if sun.x < 0.0 else -1.0
	var shaded := PackedVector2Array([head + Vector2(0, -1)])
	for k in 5:
		shaded.append(head + Vector2.from_angle(PI * 1.5 + side * PI * 0.5 * k / 4.0) * 6.5 + Vector2(0, -1))
	draw_colored_polygon(shaded, _shade(HAT))
	draw_rect(Rect2(head.x - 6, head.y - 3, 12, 2), _plain(HAT.darkened(0.15)))
	draw_circle(head + Vector2(0, -8), 2.0, _lit(HAT))


func _shoe(p: Vector2, side: float) -> void:
	draw_rect(Rect2(p.x - 4, p.y - 3, 8, 5), _plain(SHOE))
	if not silhouette:
		draw_line(p + Vector2(-4, 1.5), p + Vector2(4, 1.5), Color8(40, 34, 40))  # the rubber rand
		draw_line(p + Vector2(-3, -2.5), p + Vector2(2, -2.5), _lit(SHOE))
		draw_rect(Rect2(p.x - 2 * side - 0.5, p.y - 1.5, 1, 1), Color8(230, 220, 200))


## A hand in a few pixels, turned along the forearm: the back of the hand, knuckles in
## the sun, fingertips white with chalk, a thumb on the inside.
func _hand(p: Vector2, along: Vector2, state: String, side: float) -> void:
	var f := along.normalized()
	var w := f.orthogonal()
	if w.dot(sun) < 0.0:
		w = -w
	var thumb := -1.0 if w.dot(Vector2(-side, 0)) > 0.0 else 1.0
	var skin := _plain(SKIN)
	var lit := _lit(SKIN)
	var shade := _shade(SKIN)
	var chalk := flat_color if silhouette else SKIN.lerp(Color.WHITE, 0.55)
	var gap := _shade(_shade(SKIN))
	var px := func(u: float, k: float, c: Color) -> void:
		var q := (p + f * u + w * k).round()
		draw_rect(Rect2(q, Vector2.ONE), c)
	match state:
		"grip":  # back of the hand, then four fingers curled over the edge
			for u in range(-1, 2):
				for k in range(-3, 4):
					px.call(u, k, lit if k >= 2 else (shade if k <= -2 else skin))
			for k in range(-2, 4):
				px.call(1, k, _lit(lit))
			for u in [2, 3]:
				for k in range(-3, 4):
					var finger := k in [-3, -1, 1, 3]
					px.call(u, k, (chalk if u == 3 else (lit if k > 0 else skin)) if finger else gap)
			px.call(0, 4 * thumb, skin)
			px.call(1, 4 * thumb, skin)
			px.call(2, 4 * thumb, shade)
		"flat":  # palm and fingers flat against the rock: a poor grip
			for u in range(-1, 2):
				for k in range(-3, 4):
					px.call(u, k, shade if k < -1 else skin)
			for n in 4:
				var k: float = [-3.5, -1.2, 1.2, 3.5][n]
				for u in [2, 3]:
					px.call(u, k + (n - 1.5) * 0.3 * (u - 2), skin if u < 3 else chalk)
			px.call(0, 4 * thumb, skin)
		_:  # reaching: short fingers, a little open
			for u in range(-1, 2):
				for k in range(-3, 4):
					px.call(u, k, lit if k >= 2 else (shade if k <= -2 else skin))
			for n in 4:
				var k: float = [-3.0, -1.0, 1.0, 3.0][n]
				var spread := (n - 1.5) * 0.25
				px.call(2, k + spread, lit if k > 0 else skin)
				px.call(3, k + spread * 2.0, chalk)
			px.call(1, 4 * thumb, skin)
			px.call(2, 4.5 * thumb, chalk)
