class_name FlowClimber
extends Node2D
## The climber on the flow wall: hang and swing, throw yourself at the next hold,
## catch it with its colour button at the dead point (the top of your jump). A
## perfect catch keeps your speed, so the next throw flows out of it. The route is
## fixed; holding up while you throw skips a hold if you have the speed for it.
## All in world coordinates: y = 0 is the floor, up is negative.

signal thrown
signal caught(hold: FlowHold, rating: String)
signal note(text: String)
signal fell
signal topped

enum State { HANG, FLY, DROP, DONE }

const GRAVITY := 520.0
const SWING_K := 32.0  # how fast the pendulum wants to return: a swing of about 1.1 s
const SWING_DAMP := 0.5
const SWING_PUMP := 14.0
const SWING_MAX := 1.2
const OMEGA_FULL := 5.0  # swing speed that counts as full power
const MAX_REACH := 100.0  # the distance you can throw at full power
const CATCH_GAP := 8.0  # how far under the hold your jump may end and still reach it
const CARRY := 3.0  # swing speed you keep from a perfect catch
const CARRY_PER_FLOW := 0.4
const MAX_FLOW := 4
const FLOW_PATIENCE := 1.6  # hang longer than this and your flow is gone
const SETTLE_TIME := 0.3  # how long you must keep pressing on a sloper
const WRONG_LOCK := 0.25
const EARLY_LOCK := 0.12
const THROW_COST := 0.02
const NET_COST := 0.1
const WRONG_COST := 0.05
const FLOOR := -11.0
const HIT_STOP := 0.05
const POWER_FADE := 1.5  # your swing's power lingers a moment, so a slightly late throw still counts

const HANG := [
	"...oo......oo...",
	"..osso....osso..",
	"...oso....oso...",
	"...oso.oo.oso...",
	"...osoorrooso...",
	"...oooRRrrooo...",
	"....orRRrrro....",
	"....orrrrrro....",
	"....osssssso....",
	"....osossoso....",
	"....osssssdo....",
	".....oddddo.....",
	"....otltttto....",
	"....otltttto....",
	"....otttttto....",
	".....opPppo.....",
	".....opppPo.....",
	".....oppopo.....",
	"....opo..opo....",
	"....opo..opo....",
	"....occo.occo...",
	".....oo...oo....",
]
const FLY := [
	".............oo.",
	"............osso",
	"...........osdo.",
	"......oo..oso...",
	"....oorroosso...",
	"...orRRrrroo....",
	"...orRRrrro.....",
	"...orrrrrro.....",
	"...osssssso.....",
	"...ososssoo.....",
	"...osssssdo.....",
	"....oddddo......",
	"...otltttoo.....",
	"..ootltttto.....",
	".osootttttoo....",
	".oso.opPppo.....",
	"..o..opppoooo...",
	".....opooopppo..",
	"....opo...occo..",
	"....occo...oo...",
	".....oo.........",
]
const FALL := [
	"..oo........oo..",
	".osso......osso.",
	"..oso..oo..oso..",
	"...osooRRooso...",
	"....oorRRroo....",
	"....orrrrrro....",
	"....osssssso....",
	"....osossoso....",
	"....osssssdo....",
	".....oddddo.....",
	"....otltttto....",
	"....otttttto....",
	".....opPppo.....",
	"....oppoppo.....",
	"...opo...opo....",
	"..occo....occo..",
	"...oo......oo...",
]
const COLORS := {
	"o": PixelArt.OUTLINE, "s": Color("f2c29a"), "d": Color("d08f68"),
	"r": Color("b5482e"), "R": Color("d9663f"), "t": Color("2f9c95"), "l": Color("54bfb5"),
	"p": Color("3e4a66"), "P": Color("56648a"), "c": Color("7a2a2a"),
}
const LEAN_PAD := 8
const LEAN_SHEARS := [0.0, 0.17, 0.34]

var holds: Array[FlowHold] = []
var state := State.DONE
var index := 0  # the hold you are on
var target_index := 0  # the hold you are going for
var body := Vector2.ZERO
var vel := Vector2.ZERO
var theta := 0.0
var omega := 0.0
var stamina := 1.0
var flow := 0
var power := 0.0
var flight_time := 0.0
var apex_time := 0.0
var can_reach := true

var _hang_time := 0.0
var _settle := 0.0
var _lock := 0.0
var _stop := 0.0
var _facing := 1.0
var _puffs: Array[Dictionary] = []
var _lean_frames := {}
var _fly_right: ImageTexture
var _fly_left: ImageTexture
var _fall: ImageTexture


func _ready() -> void:
	_fly_right = PixelArt.from_rows(FLY, COLORS)
	_fly_left = PixelArt.from_rows(_mirrored(FLY), COLORS)
	_fall = PixelArt.from_rows(FALL, COLORS)
	for i in LEAN_SHEARS.size():
		_lean_frames[i] = PixelArt.from_rows(_sheared(HANG, LEAN_SHEARS[i]), COLORS)
		_lean_frames[-i] = PixelArt.from_rows(_sheared(HANG, -LEAN_SHEARS[i]), COLORS)


## Hang from a hold, ready to go, with full strength.
func start_on(hold_index: int) -> void:
	index = hold_index
	state = State.HANG
	theta = 0.0
	omega = 0.0
	stamina = 1.0
	flow = 0
	_settle = 0.0
	_lock = 0.0
	_hang_time = 0.0
	_puffs.clear()
	body = _hang_position()
	target_index = mini(index + 1, holds.size() - 1)
	queue_redraw()


func current_hold() -> FlowHold:
	return holds[index]


func target_hold() -> FlowHold:
	return holds[target_index]


## How much of your swing goes towards the target, 0 to 1.
func throw_power(target: FlowHold) -> float:
	var dx := target.pos.x - current_hold().pos.x
	var speed := absf(omega) if absf(dx) < 10.0 else maxf(0.0, omega * signf(dx))
	return clampf(speed / OMEGA_FULL, 0.0, 1.0)


func power_needed(target: FlowHold) -> float:
	return clampf(current_hold().pos.distance_to(target.pos) / MAX_REACH, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	_update_puffs(delta)
	if _stop > 0.0:
		_stop -= delta
		queue_redraw()
		return
	match state:
		State.HANG:
			_hang(delta)
		State.FLY:
			_fly(delta)
		State.DROP:
			_drop(delta)
	queue_redraw()


func _hang(delta: float) -> void:
	var hold := current_hold()
	var steer := Game.steer_vector()
	theta += omega * delta
	omega += (-SWING_K * sin(theta) - SWING_DAMP * omega + SWING_PUMP * steer.x) * delta
	if absf(theta) > SWING_MAX:
		theta = signf(theta) * SWING_MAX
		omega = 0.0
	body = _hang_position()
	_hang_time += delta
	if _hang_time > FLOW_PATIENCE:
		flow = 0
	stamina = clampf(stamina - hold.data.drain * delta, 0.0, 1.0)
	if stamina <= 0.0:
		note.emit("Verzuurd!")
		_start_drop()
		return
	if _settle > 0.0:
		_settle -= delta
		if not Input.is_action_pressed(hold.data.action):
			note.emit("Weggegleden!")
			_start_drop()
		return
	# Hold up to go for the hold after the next one.
	var ahead := 2 if steer.y < -0.5 else 1
	target_index = mini(index + ahead, holds.size() - 1)
	power = maxf(throw_power(target_hold()), power - POWER_FADE * delta)
	if Input.is_action_just_pressed("flow_throw") and target_index != index:
		_throw()


func _throw() -> void:
	var target := target_hold()
	_facing = 1.0 if target.pos.x >= body.x else -1.0
	var goal := target.pos + Vector2(-7.0 * _facing, 12.0)
	var rise := body.y - goal.y
	var strength := clampf(power / maxf(power_needed(target), 0.01), 0.25, 1.0)
	var actual_rise := rise * strength * strength
	can_reach = rise - actual_rise <= CATCH_GAP
	vel.y = -sqrt(2.0 * GRAVITY * actual_rise)
	apex_time = -vel.y / GRAVITY
	vel.x = (goal.x - body.x) / apex_time
	flight_time = 0.0
	_lock = 0.0
	stamina = maxf(0.0, stamina - THROW_COST)
	state = State.FLY
	Game.sfx("Sounds/Menu/Move1.wav", -14.0)
	thrown.emit()


func _fly(delta: float) -> void:
	body += vel * delta
	vel.y += GRAVITY * delta
	flight_time += delta
	_lock -= delta
	var target := target_hold()
	if flight_time > apex_time + target.data.net:
		note.emit("Gemist!" if can_reach else "Te kort!")
		_start_drop()
		return
	if _lock > 0.0:
		return
	for type in FlowHold.TYPES:
		var action: String = FlowHold.TYPES[type].action
		if Input.is_action_just_pressed(action):
			_try_catch(action)
			return


func _try_catch(action: String) -> void:
	var target := target_hold()
	if action != target.data.action:
		_lock = WRONG_LOCK
		stamina = maxf(0.0, stamina - WRONG_COST)
		note.emit("Verkeerde kleur!")
		Game.sfx("Sounds/Menu/Cancel.wav", -12.0)
		return
	var off := absf(flight_time - apex_time)
	if not can_reach or off > target.data.net:
		_lock = EARLY_LOCK
		note.emit("Te vroeg!" if can_reach else "Te kort!")
		return
	var rating := "net"
	if off <= target.data.perfect:
		rating = "perfect"
	elif off <= target.data.good:
		rating = "goed"
	_catch(target, rating)


func _catch(hold: FlowHold, rating: String) -> void:
	index = target_index
	target_index = mini(index + 1, holds.size() - 1)
	state = State.HANG
	_hang_time = 0.0
	theta = 0.0
	omega = 0.0
	power = 0.0
	if rating == "perfect":
		flow = mini(flow + 1, MAX_FLOW)
		_stop = HIT_STOP
		Game.sfx("Sounds/Menu/Accept2.wav", -10.0)
	else:
		flow = maxi(flow - 1, 0) if rating == "goed" else 0
		Game.sfx("Sounds/Menu/Move1.wav", -10.0)
		if rating == "net":
			stamina = maxf(0.0, stamina - NET_COST)
	if hold.type == "sloper":
		_settle = SETTLE_TIME
	for i in 6:
		_puffs.append({"pos": hold.pos, "vel": Vector2.RIGHT.rotated(TAU * i / 6.0) * 26.0, "life": 0.3})
	if hold.type == "top":
		state = State.DONE
		body = _hang_position()
		topped.emit()
		caught.emit(hold, rating)
		return
	_carry_speed(hold, rating)
	body = _hang_position()
	caught.emit(hold, rating)


## Your speed turns into a swing towards the next hold, so the next throw flows.
func _carry_speed(hold: FlowHold, rating: String) -> void:
	if index + 1 >= holds.size():
		return
	var side := signf(holds[index + 1].pos.x - hold.pos.x)
	if rating == "perfect":
		theta = -side * 0.35 * hold.data.carry
		omega = side * (CARRY + CARRY_PER_FLOW * flow) * hold.data.carry
	elif rating == "goed":
		omega = side * 1.2 * hold.data.carry


func _start_drop() -> void:
	state = State.DROP
	vel.x *= 0.3
	vel.y = maxf(vel.y, 0.0)
	flow = 0
	Game.sfx("Sounds/Hit & Impact/Hit2.wav", -12.0)


func _drop(delta: float) -> void:
	body += vel * delta
	vel.y = minf(vel.y + GRAVITY * delta, 420.0)
	if body.y >= FLOOR:
		body.y = FLOOR
		state = State.DONE
		fell.emit()


func _hang_position() -> Vector2:
	return current_hold().pos + Vector2(sin(theta) * 10.0, 12.0)


func _update_puffs(delta: float) -> void:
	for puff in _puffs:
		puff.pos += puff.vel * delta
		puff.life -= delta
	_puffs = _puffs.filter(func(puff: Dictionary) -> bool: return puff.life > 0.0)


# --- drawing --------------------------------------------------------------

func _draw() -> void:
	if state == State.HANG or state == State.FLY:
		_draw_target()
	match state:
		State.HANG:
			_draw_hanging()
		State.FLY:
			var tex := _fly_right if _facing > 0.0 else _fly_left
			draw_texture(tex, (body - Vector2(7, 12)).round() if _facing > 0.0 else (body - Vector2(8, 12)).round())
		State.DROP:
			draw_texture(_fall, (body - Vector2(8, 9)).round())
		State.DONE:
			if index == holds.size() - 1:
				_draw_hanging()
			else:
				draw_texture(_fall, (body - Vector2(8, 9)).round())
	for puff in _puffs:
		draw_rect(Rect2(puff.pos.round(), Vector2(2, 2)), PixelArt.CHALK)
	if stamina < 0.25 and (state == State.HANG) and Engine.get_frames_drawn() % 20 < 10:
		draw_rect(Rect2((body + Vector2(8, -8)).round(), Vector2(2, 2)), Color("a9dcef"))


func _draw_hanging() -> void:
	var step := 0
	if absf(theta) > 0.45:
		step = 2
	elif absf(theta) > 0.15:
		step = 1
	var frame: ImageTexture = _lean_frames[step if theta >= 0.0 else -step]
	var hand := current_hold().pos + Vector2(0, -1)
	draw_texture(frame, (hand - Vector2(LEAN_PAD + 8, 1)).round())


## Corners around the hold you are going for. Hanging: a ring fills up as your
## swing gets strong enough. Flying: a ring shrinks onto the hold at the dead point.
func _draw_target() -> void:
	if index == holds.size() - 1:
		return
	var hold := target_hold()
	var color := Color(hold.data.color)
	if state == State.HANG:
		var enough := minf(power / maxf(power_needed(hold), 0.01), 1.0)
		var ring := Color.WHITE if enough >= 1.0 else color
		draw_arc(hold.pos, 15.0, -PI / 2.0, -PI / 2.0 + TAU * enough, 20, ring, 1.0)
	elif can_reach:
		var left := maxf(apex_time - flight_time, 0.0) / maxf(apex_time, 0.01)
		draw_arc(hold.pos, 11.0 + 26.0 * left, 0.0, TAU, 24, color, 1.0)
	var r := 13.0
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var p: Vector2 = (hold.pos + corner * r).round()
		draw_line(p, p - Vector2(corner.x * 4, 0), PixelArt.CHALK)
		draw_line(p, p - Vector2(0, corner.y * 4), PixelArt.CHALK)


## A leaning frame: every row is shifted a bit further, the hands stay in place.
func _sheared(rows: Array, shear: float) -> Array:
	var result := []
	for y in rows.size():
		var shift := int(roundf(y * shear))
		result.append(".".repeat(LEAN_PAD + shift) + rows[y] + ".".repeat(LEAN_PAD - shift))
	return result


func _mirrored(rows: Array) -> Array:
	var result := []
	for row: String in rows:
		var flipped := ""
		for c in row.reverse():
			flipped += c
		result.append(flipped)
	return result
