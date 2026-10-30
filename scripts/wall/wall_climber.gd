class_name WallClimber
extends Node2D
## The climber on the test wall. Z = left hand, X = right hand (controller:
## LB/LT and RB/RT): holding the button grips, letting go releases. The arrows
## or the stick move your body and reach with the free hand. The body hangs from the hands like a pendulum, so you can
## swing, let go and catch a far hold. Feet follow by themselves. All in world
## coordinates: y = 0 is the floor, up is negative.

signal grabbed(hold: WallHold)
signal fell
signal topped

const ARM := 36.0  # hand to shoulder at full stretch
const MIN_ARM := 9.0  # fully locked off
const LEG := 28.0
const GRAVITY := 520.0
const PULL_UP := 760.0
const PUSH_DOWN := 200.0
const SWING_ONE_HAND := 520.0
const SWING_TWO_HANDS := 300.0
const MAX_SPEED := 430.0
const HAND_SPEED := 300.0
const WALK_SPEED := 90.0
const SHOULDER_HEIGHT := 40.0  # shoulders above the floor when standing
const JUMP_WITH_FEET := 290.0  # push-off when your last hand lets go while aiming
const JUMP_NO_FEET := 190.0
const JUMP_COST := 0.06
const AIM_CONE := 0.65  # how far off your aim (radians) a hold can be and still be picked
const SLOPER_ANGLE := 0.87  # about 50 degrees off straight below the hand
const SLOPER_ANGLE_SUPPORTED := 1.2  # about 70 degrees when the other hand holds too
const SLOPER_SPEED := 170.0
const SLOPER_SLIP_TIME := 0.35

const SKIN := Color("f2c29a")
const SKIN_DARK := Color("d08f68")
const PANTS := Color("3d4a7a")
const SHOE := Color("c8463d")
const OUTLINE := Color("2b1d2e")

const TORSO := [
	".......oooooo.......",
	".....oorrrrrroo.....",
	"....orrrRRrrrrro....",
	"...orrRRrrrrrrrro...",
	"...orrrrrrrrrrrro...",
	"...orrrrrrrrrrrro...",
	"....orrrrrrrrrro....",
	".....oorrrrrroo.....",
	"...ooooossssooooo...",
	"..ottttttttttttttto.",
	".otllttttttttttllto.",
	".otlttttttttttttlto.",
	".otttttttttttttttto.",
	".ootttttttttttttoo..",
	"...otttttttttttto...",
	"...otttcccccttto....",
	"...ottcwwwwwctto....",
	"...ottccccccctto....",
	"...oppppppppppppo...",
	"...oppppppppppppo...",
	"...oppppPPpppppo....",
	"....oooooooooooo....",
]

## One hand: where it is and what it holds.
class Hand:
	var action := ""
	var side := -1.0
	var pos := Vector2.ZERO
	var hold: WallHold = null
	var left_hold: WallHold = null  # just let go of: no regrabbing until away from it
	var slip := 0.0
	var cooldown := 0.0

var holds: Array[WallHold] = []
var foot_chips: Array[Vector2] = []
var body := Vector2(240, -SHOULDER_HEIGHT)
var vel := Vector2.ZERO
var stamina := 1.0
var hands: Array[Hand] = []
var feet: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var feet_on := true
var frozen := false
var waiting := false  # placed on holds: wait until both buttons are pressed
var left_ground := false
var aimed: WallHold = null  # the hold your aim points at; the free hand goes there

var _torso: ImageTexture


func _ready() -> void:
	for i in 2:
		var hand := Hand.new()
		hand.action = "grip_left" if i == 0 else "grip_right"
		hand.side = -1.0 if i == 0 else 1.0
		hands.append(hand)
	_torso = PixelArt.from_rows(TORSO, {
		"o": OUTLINE, "r": Color("b5482e"), "R": Color("d9663f"), "s": SKIN_DARK,
		"t": Color("2f9c95"), "l": Color("54bfb5"), "c": Color("7a2a2a"), "w": PixelArt.CHALK, "p": PANTS, "P": PANTS.lightened(0.2),
	})
	reset(Vector2(240, -SHOULDER_HEIGHT))


## Back on the mat, hands free, full strength.
func reset(at: Vector2) -> void:
	body = at
	vel = Vector2.ZERO
	stamina = 1.0
	frozen = false
	waiting = false
	left_ground = false
	for hand in hands:
		hand.hold = null
		hand.left_hold = null
		hand.slip = 0.0
		hand.cooldown = 0.0
		hand.pos = body + Vector2(hand.side * 10, 12)
	feet[0] = body + Vector2(-7, SHOULDER_HEIGHT)
	feet[1] = body + Vector2(7, SHOULDER_HEIGHT)
	queue_redraw()


## Start from a hold (practising a section): both hands on it, waits for the buttons.
func place_on(hold: WallHold) -> void:
	reset(hold.pos + Vector2(0, ARM))
	for hand in hands:
		hand.hold = hold
		hand.pos = hold.pos
	left_ground = true
	waiting = true


func gripping() -> Array[Hand]:
	var list: Array[Hand] = []
	for hand in hands:
		if hand.hold:
			list.append(hand)
	return list


func on_floor() -> bool:
	return body.y >= -SHOULDER_HEIGHT - 0.5


func _physics_process(delta: float) -> void:
	if frozen:
		return
	if waiting:
		if Input.is_action_pressed("grip_left") and Input.is_action_pressed("grip_right"):
			waiting = false
		queue_redraw()
		return
	var aim := Game.steer_vector()
	_update_grips(delta)
	_move_body(delta, aim)
	_move_hands(delta, aim)
	_try_grabs()
	_move_feet(delta)
	_update_stamina(delta, aim)
	queue_redraw()


func _update_grips(delta: float) -> void:
	for hand in hands:
		hand.cooldown = maxf(0.0, hand.cooldown - delta)
		if not hand.hold:
			continue
		if not Input.is_action_pressed(hand.action) or stamina <= 0.0:
			_release(hand)
		elif hand.hold.type == "sloper" and _sloper_slipping(hand):
			hand.slip += delta
			if hand.slip >= SLOPER_SLIP_TIME:
				_release(hand)
				Game.sfx("Sounds/Hit & Impact/Hit2.wav", -12.0)
		else:
			hand.slip = 0.0


func _sloper_slipping(hand: Hand) -> bool:
	var offset := body - hand.pos
	if offset.length() < 12.0:
		return false
	var limit := SLOPER_ANGLE_SUPPORTED if gripping().size() == 2 else SLOPER_ANGLE
	return absf(atan2(offset.x, offset.y)) > limit or vel.length() > SLOPER_SPEED


func _release(hand: Hand) -> void:
	hand.left_hold = hand.hold
	hand.hold = null
	hand.slip = 0.0
	if stamina <= 0.0:
		hand.cooldown = 0.6  # pumped out: you can't just grab again
		return
	# Letting go with your last hand while aiming is a jump: the legs push off.
	var aim := Game.steer_vector()
	if gripping().is_empty() and aim != Vector2.ZERO:
		vel += aim.normalized() * (JUMP_WITH_FEET if feet_on else JUMP_NO_FEET)
		stamina = maxf(0.0, stamina - JUMP_COST)


func _move_body(delta: float, aim: Vector2) -> void:
	var grips := gripping()
	var accel := Vector2(0, GRAVITY)
	var damping := 0.15
	if not grips.is_empty():
		left_ground = left_ground or body.y < -SHOULDER_HEIGHT - 20.0
		accel.y += aim.y * (PULL_UP if aim.y < 0.0 else PUSH_DOWN)
		accel.x += aim.x * (SWING_ONE_HAND if grips.size() == 1 else SWING_TWO_HANDS)
		if feet_on:
			damping = 1.8
		if grips.size() == 2:
			damping += 1.0
		if grips.any(func(h): return h.hold.type == "pinch"):
			damping += 3.0  # a pinch stops a swing
	vel += accel * delta
	vel *= exp(-damping * delta)
	vel = vel.limit_length(MAX_SPEED)
	body += vel * delta
	for i in 3:
		for hand in grips:
			_keep_within_arm(hand)
	if body.y >= -SHOULDER_HEIGHT:
		body.y = -SHOULDER_HEIGHT
		vel.y = minf(vel.y, 0.0)
		if grips.is_empty():
			vel.x = aim.x * WALK_SPEED
			if left_ground:
				left_ground = false
				fell.emit()
	body.x = clampf(body.x, 20.0, 460.0)


func _keep_within_arm(hand: Hand) -> void:
	var offset := body - hand.pos
	var length := offset.length()
	if length < 0.01:
		return
	var dir := offset / length
	if length > ARM:
		body = hand.pos + dir * ARM
		var outward := vel.dot(dir)
		if outward > 0.0:
			vel -= dir * outward
	elif length < MIN_ARM:
		body = hand.pos + dir * MIN_ARM
		var inward := vel.dot(dir)
		if inward < 0.0:
			vel -= dir * inward


## The hold closest to where you are aiming, within reach of your free hand.
func _find_aimed(aim: Vector2) -> WallHold:
	if aim == Vector2.ZERO or gripping().size() == 2:
		return null
	var best: WallHold = null
	var best_score := INF
	for hold in holds:
		var to_hold := hold.pos - body
		if to_hold.length() > ARM + 4.0 or to_hold.length() < 1.0:
			continue
		if hands.any(func(h): return h.hold == hold) and hold.type != "top":
			continue
		var off_aim := absf(aim.angle_to(to_hold))
		if off_aim < AIM_CONE and off_aim < best_score:
			best_score = off_aim
			best = hold
	return best


func _move_hands(delta: float, aim: Vector2) -> void:
	aimed = _find_aimed(aim)
	for hand in hands:
		if hand.hold:
			hand.pos = hand.hold.pos
			continue
		var target := body + Vector2(hand.side * 10, 12)  # relaxed
		if aimed and aimed != hand.left_hold:
			target = aimed.pos  # you aim in a direction, the hand finds the hold
		elif aim != Vector2.ZERO:
			target = body + aim.normalized() * ARM + Vector2(hand.side * 2, 0)
		elif Input.is_action_pressed(hand.action):
			target = body + Vector2(hand.side * 6, -ARM * 0.85)  # ready to catch
		hand.pos = hand.pos.move_toward(target, HAND_SPEED * delta)
		var reach := hand.pos - body
		if reach.length() > ARM:
			hand.pos = body + reach.normalized() * ARM


func _try_grabs() -> void:
	for hand in hands:
		if hand.hold:
			continue
		if hand.left_hold and hand.pos.distance_to(hand.left_hold.pos) > hand.left_hold.radius() + 6.0:
			hand.left_hold = null
		if hand.cooldown > 0.0 or not Input.is_action_pressed(hand.action):
			continue
		for hold in holds:
			if hold == hand.left_hold or hand.pos.distance_to(hold.pos) > hold.radius():
				continue
			if body.distance_to(hold.pos) > ARM + 4.0:
				continue
			if hold.type == "pocket" and hands.any(func(h): return h.hold == hold):
				continue  # a pocket only fits one hand
			hand.hold = hold
			hand.pos = hold.pos
			vel *= 0.85
			Game.sfx("Sounds/Hit & Impact/Hit3.wav", -14.0)
			grabbed.emit(hold)
			if hands[0].hold == hands[1].hold and hold.type == "top":
				frozen = true
				topped.emit()
			break


func _move_feet(delta: float) -> void:
	var hip := body + Vector2(0, 12)
	feet_on = on_floor()
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var target := hip + Vector2(side * 5, 22) - vel * 0.02
		if on_floor():
			target = Vector2(body.x + side * 7, 0)
		else:
			var best := LEG
			for chip in foot_chips:
				# each foot prefers chips on its own side of the body
				var dist := hip.distance_to(chip) + (0.0 if (chip.x - body.x) * side >= -4.0 else 12.0)
				if dist < best and chip.y > hip.y - 6.0:
					best = dist
					target = chip
					feet_on = true
		feet[i] = feet[i].move_toward(target, 240.0 * delta)
		var leg := feet[i] - hip
		if leg.length() > LEG:
			feet[i] = hip + leg.normalized() * LEG


func _update_stamina(delta: float, aim: Vector2) -> void:
	var grips := gripping()
	if grips.is_empty():
		if on_floor():
			stamina = minf(1.0, stamina + 0.5 * delta)
		return
	if on_floor():
		return
	var drain := 0.0
	var bend := 0.0
	var all_jugs := true
	for hand in grips:
		drain += hand.hold.drain()
		all_jugs = all_jugs and hand.hold.drain() < 0.0
		bend += 1.0 - clampf((body.distance_to(hand.pos) - MIN_ARM) / (ARM - MIN_ARM), 0.0, 1.0)
	bend /= grips.size()
	if all_jugs:
		drain = -0.14 * grips.size()  # shake out: two hands on a jug recharge fastest
	else:
		drain = maxf(drain / grips.size(), 0.01)
		if grips.size() == 1:
			drain *= 1.7  # one arm carries it all
		drain *= 1.0 + bend * 0.7  # hanging straight-armed is cheaper
		if not feet_on:
			drain *= 1.3
		if aim.y < 0.0:
			drain += 0.015
	stamina = clampf(stamina - drain * delta, 0.0, 1.0)


# --- drawing ------------------------------------------------------------

func _draw() -> void:
	var shake := Vector2.ZERO
	if stamina < 0.2 and not gripping().is_empty():
		shake = Vector2(1 if Engine.get_physics_frames() % 4 < 2 else 0, 0)
	var at := (body + shake).round()
	var hip := at + Vector2(0, 12)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		_limb(hip + Vector2(side * 4, 0), feet[i].round(), 15.0, side, PANTS, 6.0)
		draw_rect(Rect2(feet[i].round() + Vector2(-5 + side * 2, -3), Vector2(10, 6)), OUTLINE)
		draw_rect(Rect2(feet[i].round() + Vector2(-4 + side * 2, -2), Vector2(8, 4)), SHOE)
	draw_texture(_torso, at + Vector2(-10, -10))
	if aimed:
		_draw_marker(aimed)
	for hand in hands:
		var shoulder := at + Vector2(hand.side * 7, 2)
		_limb(shoulder, hand.pos.round(), ARM / 2.0 + 1.0, hand.side, SKIN, 4.0)
		var p := hand.pos.round()
		draw_rect(Rect2(p + Vector2(-4, -4), Vector2(8, 8)), OUTLINE)
		var color: Color = PixelArt.CHALK if hand.hold else SKIN
		if hand.slip > 0.0 and Engine.get_physics_frames() % 6 < 3:
			color = Color("d9453c")  # slipping off a sloper
		draw_rect(Rect2(p + Vector2(-3, -3), Vector2(6, 6)), color)


## Four little corners around the hold you are aiming at.
func _draw_marker(hold: WallHold) -> void:
	var r := hold.radius() + 3.0
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var p: Vector2 = (hold.pos + corner * r).round()
		draw_line(p, p - Vector2(corner.x * 3, 0), Color("fff6e4"), 1.0)
		draw_line(p, p - Vector2(0, corner.y * 3), Color("fff6e4"), 1.0)


## A two-part limb with the joint bending outward.
func _limb(from: Vector2, to: Vector2, segment: float, side: float, color: Color, width: float) -> void:
	var dist := from.distance_to(to)
	var mid := (from + to) / 2.0
	if dist < segment * 2.0 and dist > 0.01:
		var along := (to - from) / dist
		var out := Vector2(along.y, -along.x) * (1.0 if along.y * side >= 0.0 else -1.0)
		mid += out * sqrt(segment * segment - dist * dist / 4.0)
	mid = mid.round()
	for w in [[width + 2.0, OUTLINE], [width, color]]:
		draw_line(from, mid, w[1], w[0])
		draw_line(mid, to, w[1], w[0])
