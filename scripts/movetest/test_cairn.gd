extends MoveTest
## Test 4: climbing a Font boulder, the rock free to grab anywhere. Every hand and foot has
## its own button: hold it, move that limb with the stick, let go to put it down. With no
## button held the stick moves your body: stand up out of your legs, shift your weight.
## Reach with a hand past your arm while your feet carry you and you stand up by yourself.
## How well a spot holds comes from the shape of the rock, read from a grip map. You feel it
## when you put a hand down: a dry tick or a rub, a curled or a flat hand, a wobble. Marks
## that show it beforehand (green good, yellow so-so, red poor) are an aid, off by default.
## On a block with a direction map a hold also has to be pulled the right way: a flake
## sideways, an undercling up, a sloper straight down. Your body position decides that.
## There is no bar: a hand that carries too much for its grip trembles, and spending is
## slow, so take your time to find a good position. Shake out a hand where you stand well.
##
## The rock and the grip maps come from tools/rots/export.py, one folder per block.

signal topped

const SCENE := preload("res://shaders/climb/climb_scene.gdshader")
const SHADOW := preload("res://shaders/climb/shadow_on_rock.gdshader")
const GRADE := preload("res://shaders/climb/grade.gdshader")
# Per time of day: the haze over the far forest, how strong the shaft of sunlight is, and
# whether motes float in the light and fireflies come out.
const AIR := {
	"middag": {"haze": Color(0.86, 0.9, 0.88), "shaft": 0.14, "motes": true, "flies": false},
	"ochtend": {"haze": Color(0.84, 0.9, 0.96), "shaft": 0.16, "motes": true, "flies": false},
	"avond": {"haze": Color(1.0, 0.78, 0.58), "shaft": 0.22, "motes": true, "flies": true},
	"schemering": {"haze": Color(0.5, 0.52, 0.72), "shaft": 0.0, "motes": false, "flies": true},
}

const LH := 0
const RH := 1
const LF := 2
const RF := 3
const BUTTONS := ["hand_left", "hand_right", "foot_left", "foot_right"]
const ARM := 32.0  # from the shoulder, a little less than upper arm and forearm
const LEG := 35.0
const STRETCH := 8.0  # how far you lean when you push a hand past its reach, hanging
const CURSOR_SPEED := 65.0
const BODY_SPEED := 60.0
const PUSH_SPEED := 34.0
const STAND_SPEED := 30.0  # standing up out of your legs while you reach
const SETTLE_SPEED := 14.0  # your weight drifts over your feet by itself
const WIDE := 16.0  # your shoulders may be this far beside your feet
const HAND_CARRY := 1.2  # how much of your weight a perfect hold takes comfortably
const FOOT_CARRY := 0.9  # good feet under you take most of your weight
const COMFORT := 0.5  # a hand below this strain costs nothing
const DRAIN := 0.03  # slow: you have time to look for a better position
const REST_GAIN := 0.15
const SHAKE_FROM := 1.1  # a hand trembles only when it really carries too much
const SLIP_FROM := 1.25  # past this a hand or foot starts to slip...
const SLIP_TIME := 0.5  # ...and is off once it has slipped this long (faster the worse it is)
const PALM := 0.08  # a hand flat on bare rock
const STRICT := 1.5  # how hard the edge of a hold falls off: only its heart really holds
const GOOD_GRIP := 0.5
const FAIR_GRIP := 0.3
const SETTLE := 3  # a placed hand or foot finds the best spot this close: aim well
const GROUND_Y := 257.0  # the sand at the foot of the block
const DYNO_REACH := 104.0  # how far your hand flies on a full jump
const LOAD_TIME := 0.9  # to sink all the way
const LOAD_HOLD := 0.7  # stay down longer than this and your arms tire: the jump shrinks
const SINK := 14.0
const RISE_TIME := 0.38
const DEAD_TIME := 0.3  # the moment at the top where you hang still
const EARLY := 0.07  # you may press this long before the top
const CATCH_RADIUS := 7  # a catching hand finds the hold this close
const SWING_PULL := 20.0  # gravity over the length of the swing
const STEEP := 0.14  # radians: rock leaning out more than this needs body tension
const LOOSE_TIME := 0.3  # on steep rock, moving a hand without tension, your feet cut loose after this
const BENT_DRAIN := 1.0  # on steep rock a bent arm works much harder than a straight one
const TENSION_DRAIN := 0.02
const PRESS := 0.5  # a hand below its shoulder can still press down on a hold that faces up
const SLOPER_PRESS := 0.75  # a palm pressing down on a sloper, standing up past it
const WOBBLE_TIME := 0.35  # a hand put on a poor spot wobbles for a moment: you feel it
const LOG_PATH := "user://klimlog.csv"  # one line per attempt, to tune the climbing on real play
# Topping out, as in Font: a hand over the top edge is not the top yet. With both hands on
# the rim you press yourself up, put a foot up beside your hands and stand up over it.
const PRESS_SPEED := 16.0  # how fast you press up on the rim
const MANTLE_SINK := 8.0  # with nothing under your feet, a half press sinks back
const PALM_PRESS := 0.6  # how much a palm pressing down on top of the block holds
const TOP_FOOT := 0.85  # a foot up on top of the block
const STAND_TIME := 0.9  # standing up on top, once your hips are over your foot
const STAND_OVER := 30.0  # your shoulders this close beside that foot are over it
const ROCK_OVER := 22.0  # how fast pushing up moves your hips over a foot on top
const NOTE_Y := 24.0  # where notes show; the top note goes lower, under you on the rock
const START_FEET := [Vector2(224, GROUND_Y), Vector2(246, GROUND_Y)]
# Time of day: the picture, where the sun stands (x, y on screen, z towards you) and the
# colour of its light. Must match TIMES in tools/rots/export.py.
const TIMES := [
	["avond", Vector3(-0.8, -0.32, 0.42), Color(1.1, 0.95, 0.82)],
	["schemering", Vector3(-0.25, -0.5, 0.85), Color(0.74, 0.76, 0.92)],
	["ochtend", Vector3(0.5, -0.55, 0.6), Color(0.95, 0.98, 1.05)],
	["middag", Vector3(-0.35, -0.7, 0.62), Color(1, 1, 1)],
]

var pos: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var on: Array[bool] = [true, true, true, true]
var prev: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var body := Vector2.ZERO  # your shoulders
var stretch := Vector2.ZERO
var held := -1  # the limb whose button you hold
var stamina := 1.0
var resting := false
var rest_hand := -1
var breath := 0.0
var time := -1
var time_name := ""  # set by whoever starts the climb; stays the same for every try
var route_id := "marierose"  # which block: its folder in assets/climb
var route := {}
var feet_max := 0.6  # how much your feet can carry: more on a slab, less on a steep face
var top_y := 36.0  # a hand over the top edge: you are up
var _named := false
var _was_on := false
var _slip: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _lean := Vector2.ZERO  # the part of the stretch already in `body`
var _rocks: Array[Texture2D] = []
var _hand_map: Image
var _foot_map: Image
var _mask: Image
var _dir_map: Image  # which way each hold wants to be pulled; only on blocks that have one
var _wobble: Array[float] = [0.0, 0.0]
# For the logbook: this attempt so far.
var _attempt_time := 0.0  # only for the tuning log, never shown
var _moves := 0
var _slips := 0
var _logged := false
var _min_stamina := 1.0
var _breath_n := 0
var _rumble_t := 0.0
var _idle_ground := 0.0  # seconds on the sand without starting: then the controls show again
var _told_rest := false
var _figure := ClimberFigure.new()
var _shadow := ClimberFigure.new()
var _shadow_group := CanvasGroup.new()
var _shadow_base := Vector2.ZERO
var lean := 0.0  # radians: how far the block leans out over you (a slab leans back, < 0)
var _away := 0.0  # 0: your feet hold you in to the rock, 1: you hang straight down
var backdrop: Texture2D  # the forest behind the block, from the walking world (already blurred)
var _scene := ColorRect.new()
var _grade := ColorRect.new()
var _front := TextureRect.new()
var _motes := CPUParticles2D.new()
var _flies := CPUParticles2D.new()
var _marks := Node2D.new()
var _loose := 0.0  # how long you have moved a hand without tension on steep rock
var _intro := 0.0  # the block seen from the side, before you start
var _intro_layer := CanvasLayer.new()
# Falling: you drop, land on the pad, sit a moment, hear why, and start again.
var _fall := -1.0  # seconds since you came off, -1 while you climb
var _fall_vel := Vector2.ZERO
var _land_at := -1.0
var _fall_reason := ""
var _last_slip := ""
var _told := false
var _cover := ColorRect.new()
var _dust := CPUParticles2D.new()
var _pad_squash := 0.0
# The dyno: hold the jump button to sink into your legs and aim, let go to spring up,
# press a hand button at the dead point to catch, then stop the swing with the stick.
var _dyno := ""  # "", "load", "fly" or "swing"
var _charge := 0.0
var _load_t := 0.0
var _load_body := Vector2.ZERO
var _aim := Vector2.UP
var _origin := Vector2.ZERO  # between your hands when you jump
var _reach_point := Vector2.ZERO  # where your hand will be at the top
var _jump_from := Vector2.ZERO
var _apex := Vector2.ZERO
var _fly_t := 0.0
var _jump_hand := RH
var _missed := ""
var _theta := 0.0  # the swing on one hand: your body's angle from straight down
var _omega := 0.0
var _swing_grip := 0.0
var _calm := 0.0
# Topping out.
var _top := PackedInt32Array()  # per column, where the rock begins: the top edge of the block
var _cam_y := 0.0  # the view moves up with you as you climb out, so you see yourself on top
var _cam_max := 0.0
var _stand_t := -1.0  # seconds into standing up on top; -1 before
var _stand_from: Array[Vector2] = []  # body, left and right foot when you began to stand up
var _stand_to: Array[Vector2] = []
var _mantle_said := 0  # hints this attempt: 1 press up, 2 a foot up
var _shadow_mat := ShaderMaterial.new()
var _menu: MenuLayer
var _tip := 0.0  # seconds the tip about this block's holds stays up


func _ready() -> void:
	var dir := "res://assets/climb/%s/" % route_id
	route = JSON.parse_string(FileAccess.get_file_as_string(dir + "route.json"))
	feet_max = route.feet_max
	top_y = route.top_y
	_hand_map = load(dir + "hand_map.png").get_image()
	_foot_map = load(dir + "foot_map.png").get_image()
	_mask = load(dir + "rock_mask.png").get_image()
	if route.get("directional", false):
		_dir_map = load(dir + "dir_map.png").get_image()
	lean = deg_to_rad(float(route.get("lean", 0.0)))
	for t in TIMES:
		_rocks.append(load(dir + "rock_%s.png" % t[0]))
	_top.resize(_mask.get_width())
	for x in _mask.get_width():
		_top[x] = 9999
		for y in _mask.get_height():
			if _mask.get_pixel(x, y).r > 0.5:
				_top[x] = y
				break
	# Standing on top you are some 80 px above the rim: on a high block the view has to follow.
	_cam_max = clampf(104.0 - float(route.get("high", top_y - 10.0)), 0.0, 90.0)
	_build_scene(dir)
	_shadow.silhouette = true
	_shadow.flat_color = ClimberFigure.SHADE.darkened(0.2)
	_shadow_group.self_modulate.a = 0.5
	_shadow_mat.shader = SHADOW
	_shadow_mat.set_shader_parameter("rock_mask", load(dir + "rock_mask.png"))
	_shadow_group.material = _shadow_mat
	_shadow_group.add_child(_shadow)
	add_child(_shadow_group)
	add_child(_figure)
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	_dust.emitting = false
	_dust.one_shot = true
	_dust.explosiveness = 0.95
	_dust.amount = 22
	_dust.lifetime = 0.9
	_dust.direction = Vector2(0, -1)
	_dust.spread = 80.0
	_dust.initial_velocity_min = 18.0
	_dust.initial_velocity_max = 46.0
	_dust.gravity = Vector2(0, 40)
	_dust.damping_min = 30.0
	_dust.damping_max = 50.0
	_dust.scale_amount_min = 1.0
	_dust.scale_amount_max = 2.0
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(14, 1)
	_dust.color = Color(0.93, 0.86, 0.7, 0.8)
	add_child(_dust)
	_build_front()
	var layer := CanvasLayer.new()
	layer.layer = layer_above(5)
	_cover.color = Color(0.08, 0.06, 0.08, 0.0)
	_cover.size = Vector2(480, 270)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_cover)
	add_child(layer)
	_build_intro(dir)
	Game.count_climb()
	super._ready()


func hint_text() -> String:
	if Game.using_pad:
		return "%s %s hands,  LT RT feet,  stick = body,  %s shake out,  %s jump,  %s holds" % [
			Game.button_name(JOY_BUTTON_LEFT_SHOULDER), Game.button_name(JOY_BUTTON_RIGHT_SHOULDER), Game.button_name(JOY_BUTTON_Y),
			Game.button_name(JOY_BUTTON_A), Game.button_name(JOY_BUTTON_BACK)] + ("  ·  %s tension" % Game.button_name(JOY_BUTTON_B) if steep() else "")
	return "Z X hands,  C V feet  (hold),  arrows = body,  R shake out,  space jump,  G holds" + ("  ·  F tension" if steep() else "")


## You start on the sand at the foot of the block and put your hands and feet on it
## yourself. The time of day stays what it was when you came.
func reset() -> void:
	if time < 0:
		time = 0
		for k in TIMES.size():
			if TIMES[k][0] == time_name:
				time = k
	_set_light()
	on = [false, false, true, true]
	pos[LF] = START_FEET[0]
	pos[RF] = START_FEET[1]
	body = Vector2(235, GROUND_Y - LEG + 3 - ClimberFigure.TORSO)
	pos[LH] = _hanging(LH)
	pos[RH] = _hanging(RH)
	for i in 4:
		prev[i] = pos[i]
	stamina = 1.0
	stretch = Vector2.ZERO
	_lean = Vector2.ZERO
	resting = false
	held = -1
	_slip = [0.0, 0.0, 0.0, 0.0]
	_loose = 0.0
	_fall = -1.0
	_land_at = -1.0
	_last_slip = ""
	_told = false
	_pad_squash = 0.0
	_dyno = ""
	_cam_y = 0.0
	_place_view(Vector2.ZERO)
	_stand_t = -1.0
	_mantle_said = 0
	_note.position.y = NOTE_Y
	_away = 0.0
	_wobble = [0.0, 0.0]
	_attempt_time = 0.0
	_moves = 0
	_slips = 0
	_logged = false
	_min_stamina = 1.0
	_idle_ground = 0.0
	_pose_figure()
	if not _named:
		_named = true
		_show_intro()


## A hand that is not on the rock hangs at your side.
func _hanging(i: int) -> Vector2:
	return anchor(i) + Vector2(-3.0 if i == LH else 3.0, ClimberFigure.UPPER_ARM + ClimberFigure.FOREARM - 1.5)


func on_ground(i: int) -> bool:
	return i >= LF and holding(i) and pos[i].y >= GROUND_Y - 3.0


func _set_light() -> void:
	var sun: Vector3 = TIMES[time][1].normalized()
	var flat := Vector2(sun.x, sun.y)
	for f in [_figure, _shadow]:
		f.sun = flat.normalized()
	_figure.modulate = TIMES[time][2]
	# The shadow falls away from the sun, further when the sun is low.
	_shadow_base = -flat.normalized() * (6.0 + 10.0 * (1.0 - sun.z))
	_shadow_group.position = _shadow_base
	var air: Dictionary = AIR.get(TIMES[time][0], AIR.middag)
	var sm: ShaderMaterial = _scene.material
	sm.set_shader_parameter("rock", _rocks[time])
	sm.set_shader_parameter("haze", air.haze)
	sm.set_shader_parameter("shaft", air.shaft)
	sm.set_shader_parameter("shaft_color", (TIMES[time][2] as Color) * Color(1.0, 0.93, 0.8))
	_motes.emitting = air.motes
	_motes.visible = air.motes
	_flies.emitting = air.flies
	_flies.visible = air.flies
	_front.modulate = (TIMES[time][2] as Color).darkened(0.35 if TIMES[time][0] == "schemering" else 0.0)

func anchor(i: int) -> Vector2:
	var side := -1.0 if i == LH or i == LF else 1.0
	return body + (Vector2(side * ClimberFigure.SHOULDER_W, 0) if i < 2 else Vector2(side * ClimberFigure.HIP_W, ClimberFigure.TORSO))


func reach(i: int) -> float:
	return ARM if i < 2 else LEG


func _map(map: Image, p: Vector2) -> float:
	var x := clampi(int(p.x), 0, map.get_width() - 1)
	var y := clampi(int(p.y), 0, map.get_height() - 1)
	return map.get_pixel(x, y).r


## Is there rock here at all? Beside the block there is only air.
func on_rock(p: Vector2) -> bool:
	return _map(_mask, p) > 0.5


func hand_grip(p: Vector2) -> float:
	if not on_rock(p):
		return 0.0
	return maxf(PALM, pow(_map(_hand_map, p), STRICT))


func foot_grip(p: Vector2) -> float:
	if p.y >= GROUND_Y - 3.0:
		return 1.0  # the ground holds you fine
	if _on_top(p) and _mantling():
		return TOP_FOOT  # up on top of the block, beside your hands
	if not on_rock(p):
		return 0.0
	return maxf(0.08, pow(_map(_foot_map, p), STRICT))  # a smear on bare rock carries little


func grip(i: int, p: Vector2) -> float:
	return hand_grip(p) if i < 2 else foot_grip(p)


## A hand or foot you put down slides into the best spot right next to it.
func _settle(i: int, p: Vector2) -> Vector2:
	if i >= LF and p.y >= GROUND_Y - 3.0:
		return Vector2(p.x, GROUND_Y)  # back on the ground
	if i >= LF and _on_top(p) and _mantling():
		return Vector2(roundf(p.x), _top_at(p.x))  # a foot on top stands on the top edge
	var map := _hand_map if i < 2 else _foot_map
	var best := p.round()
	var best_q := _map(map, best)
	for dy in range(-SETTLE, SETTLE + 1):
		for dx in range(-SETTLE, SETTLE + 1):
			var q := p.round() + Vector2(dx, dy)
			var v := _map(map, q) - Vector2(dx, dy).length() * 0.01
			if v > best_q:
				best_q = v
				best = q
	return best


func holding(i: int) -> bool:
	return on[i] and not (resting and i == rest_hand)


## A foot under your hips carries you fully; a high foot, up by your waist, only a little
## until you stand up onto it.
## Steep rock: it leans out over you. Your feet stay on while you stand still, but carry
## little without body tension, and cut loose if you move a hand without it.
func steep() -> bool:
	return lean > STEEP


func tensed() -> bool:
	return steep() and Input.is_action_pressed("tension") and _fall < 0.0 and _dyno == ""


## A heel hooked over a rim at your chest or higher: it holds without tension.
func heel_hook(f: int) -> bool:
	return steep() and holding(f) and not on_ground(f) and pos[f].y < body.y + 10.0 and foot_grip(pos[f]) >= 0.3


func hooked() -> bool:
	return heel_hook(LF) or heel_hook(RF)


## How much of your weight your feet can take. On steep rock that is little, unless you
## hold tension (it doubles) or hook a heel.
func feet_carry() -> float:
	if not steep():
		return feet_max
	if hooked():
		return maxf(feet_max * 2.0, 0.55)
	return feet_max * 2.0 if tensed() else feet_max


func _below(f: int) -> float:
	return clampf((pos[f].y - anchor(f).y + 26.0) / 30.0, 0.15, 1.0)


## A hand pulls best from above you.
func _pull(h: int) -> float:
	return clampf((body.y + 10.0 - pos[h].y) / 16.0, 0.25, 1.0)


## How well a hand's pull suits its hold, 0 to 1. Your arm pulls from the hand towards the
## shoulder, and a hold only works pulled the way it faces: a rim forgives a lot, a flake
## wants a pull towards its crack, an undercling a pull up, a sloper a pull straight down.
## A hand below its shoulder can still press down on a hold that wants a pull down.
## Blocks without a direction map keep the old rule: a hand pulls best from above you.
func _direction(h: int) -> float:
	return _direction_at(h, pos[h])


func _direction_at(h: int, p: Vector2) -> float:
	if _dir_map == null:
		return _pull(h)
	var d := _hold_dir(p)
	var want := Vector2(d.x, d.y)
	var arm := anchor(h) - p
	if want.length() < 0.2 or arm.length() < 1.0:
		return 1.0
	want = want.normalized()
	arm = arm.normalized()
	var tol := deg_to_rad(lerpf(90.0, 25.0, d.z))
	var fit := _fit(arm.dot(want), tol)
	if want.y > 0.7:
		fit = maxf(fit, PRESS * _fit(-arm.dot(want), tol))
	if d.z > 0.95:
		# A sloper: pulled straight down with your weight under it, never sideways, and not
		# with the arm bent in close (the hand rolls off the bulge). Stand up past it and you
		# press down on it with your palm, like on the top of a block: that is how you move
		# on from one sloper to the next.
		var pull := _fit(arm.dot(want), deg_to_rad(35.0)) * clampf((anchor(h).distance_to(p) - ARM * 0.2) / (ARM * 0.3), 0.0, 1.0)
		fit = maxf(pull, SLOPER_PRESS * _fit(-arm.dot(want), deg_to_rad(50.0)))
	var least := lerpf(0.35, 0.05, d.z)
	return least + (1.0 - least) * fit


## 1 within `tol` of the right direction, fading to 0 over 45 degrees more.
func _fit(cos_angle: float, tol: float) -> float:
	return smoothstep(cos(tol + deg_to_rad(45.0)), cos(tol), cos_angle)


## The way the hold at p wants to be pulled (x, y), and how strict it is about that (z).
func _hold_dir(p: Vector2) -> Vector3:
	var c := _dir_map.get_pixel(clampi(int(p.x), 0, _dir_map.get_width() - 1), clampi(int(p.y), 0, _dir_map.get_height() - 1))
	return Vector3(c.r * 2.0 - 1.0, c.g * 2.0 - 1.0, c.b)


## How well a hand at p would hold: the grip of the spot and, on a block with directions,
## how well your pull suits it. This is what the hand shows, sounds like and the marks say.
func _hand_quality(h: int, p: Vector2) -> float:
	return hand_grip(p) * (_direction_at(h, p) if _dir_map else 1.0)


## Which way the fingers point on the hold at p: over a rim up, into a flake's crack
## sideways, and under an undercling up as well. Zero: along the forearm, as before.
func _fingers(p: Vector2) -> Vector2:
	if _dir_map == null:
		return Vector2.ZERO
	var d := _hold_dir(p)
	var want := Vector2(d.x, d.y)
	if want.length() < 0.2:
		return Vector2.ZERO
	want = want.normalized()
	return Vector2.UP if want.y < -0.5 else -want


## 1 when your body is over your feet; less the further you lean out beside them.
func balance() -> float:
	var low := INF
	var high := -INF
	for f in [LF, RF]:
		if holding(f):
			low = minf(low, pos[f].x)
			high = maxf(high, pos[f].x)
	if low == INF:
		return 1.0
	var out := maxf(low - WIDE - body.x, body.x - high - WIDE)
	return clampf(1.0 - maxf(out, 0.0) / 30.0, 0.4, 1.0)


## The share of your weight each limb carries: feet first, as much as they can, the
## hands the rest, the better grip taking more.
func loads() -> Array[float]:
	var share: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var cap: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var feet := 0.0
	for f in [LF, RF]:
		if holding(f):
			cap[f] = FOOT_CARRY * foot_grip(pos[f]) * (1.0 if heel_hook(f) else _below(f))
			feet += cap[f]
	var carry := minf(feet * (1.0 if hooked() else balance()), feet_carry())
	var hands := 0.0
	for h in [LH, RH]:
		if holding(h):
			cap[h] = lerpf(hand_grip(pos[h]) * _direction(h), _press_cap(h), _press(h))
			hands += cap[h]
	for i in 4:
		if i >= LF and feet > 0.0:
			share[i] = carry * cap[i] / feet
		elif i < LF and hands > 0.0:
			share[i] = (1.0 - carry) * cap[i] / hands
	return share


func strain(i: int, share: Array[float]) -> float:
	if not holding(i):
		return 0.0
	# On a block with directions a hand pulled the wrong way holds less, so it strains more.
	var holds := FOOT_CARRY * foot_grip(pos[i])
	if i < 2:
		# Pressing down on top of the block your palm holds in its own way (see _press_cap).
		holds = HAND_CARRY * lerpf(hand_grip(pos[i]) * (_direction(i) if _dir_map else 1.0), _press_cap(i), _press(i))
	var s := share[i] / maxf(holds, 0.01)
	if pos[i].distance_to(anchor(i)) > reach(i) * 0.92 and _press(i) < 0.5:
		s += 0.25  # at full stretch; pressing on locked arms is no stretch
	return s


func drain_now() -> float:
	var share := loads()
	var d := 0.0
	for h in [LH, RH]:
		var st := strain(h, share)
		d += maxf(0.0, st - COMFORT) + 3.0 * pow(maxf(0.0, st - 1.0), 2.0)
		if steep() and holding(h):
			# Hanging under steep rock, a bent arm tires fast: hang low on straight arms.
			var bent := clampf((ARM * 0.85 - anchor(h).distance_to(pos[h])) / (ARM * 0.45), 0.0, 1.0)
			d += BENT_DRAIN * bent * share[h]
	return d * DRAIN


func step(delta: float) -> void:
	if _intro > 0.0:
		_intro -= delta
		if _intro <= 0.0:
			_show_tip()
		return
	_update_tip(delta)
	if Input.is_action_just_pressed("toggle_grips"):
		Game.show_grips = not Game.show_grips
		say("Show holds: on" if Game.show_grips else "Show holds: off")
	for i in 2:
		_wobble[i] = maxf(0.0, _wobble[i] - delta)
	if _fall < 0.0 and not _logged:
		_attempt_time += delta
	_update_view(delta)
	if _fall >= 0.0:
		_update_fall(delta)
		return
	if _stand_t >= 0.0:
		_update_stand(delta)
		return
	if _dyno != "":
		_update_dyno(delta)
		return
	if Input.is_action_just_pressed("hop") and held < 0:
		_begin_load()
		return
	var steer := Game.steer_vector()
	_update_held()
	if held >= 0:
		_move_limb(steer, delta)
	else:
		stretch = stretch.move_toward(Vector2.ZERO, 30.0 * delta)
	_update_rest()
	_update_body(delta, steer if held < 0 else Vector2.ZERO)
	_update_strength(delta)
	if _fall < 0.0:
		_update_mantle()
	breath += delta * (2.0 + (1.0 - stamina) * 8.0)
	_breathe()
	_feel(delta)
	_update_hint(delta)
	_pose_figure()


## Start or Esc: the climb stops, with the block and the controls beside the menu. Leaving
## the block now goes through here.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("to_menu"):
		get_viewport().set_input_as_handled()
		_open_pause()


func _open_pause() -> void:
	if _menu == null:
		_menu = MenuLayer.new()
		add_child(_menu)
		_menu.chose.connect(_on_menu)
		_menu.closed.connect(func() -> void: get_tree().paused = false)
	get_tree().paused = true
	Game.sfx("Sounds/Menu/Accept.wav", -12.0)
	_menu.open({"title": "PAUSED", "at": Vector2(20, 48), "width": 124, "dim": true, "climbing": true,
		"items": [{"label": "Resume", "id": "resume"}, {"label": "Start over", "id": "again"},
			{"label": "Leave block", "id": "leave"}, {"label": "Settings", "id": "settings"}],
		"card": _pause_card, "card_rect": Rect2(156, 32, 304, 200)})


func _on_menu(id: String) -> void:
	_menu.close()
	match id:
		"again":
			_start_over()
		"leave":
			leave.emit()


func _pause_card(menu: MenuLayer, panel: Control) -> void:
	menu.label(panel, "%s  %s" % [route.title, route.grade], Vector2(14, 6), MenuLayer.CREAM, Game.FONT_TITLE)
	var kind := "overhang" if lean > STEEP else ("slab" if lean < -0.1 else "")
	menu.label(panel, ("%s  ·  " % kind if kind != "" else "") + Game.log_line(route_id), Vector2(14, 22), MenuLayer.SAND)
	menu.key_rows(panel, Vector2(14, 44), MenuLayer.controls_rows(true))


## Back to the sand to try again. A try you had begun counts, as if you had come off.
func _start_over() -> void:
	if not _logged and _moves > 0:
		_logged = true
		Game.log_attempt(route_id, false, _moves, _slips)
		_write_log(false, "Started over")
	var tw := create_tween()
	tw.tween_property(_cover, "color:a", 1.0, 0.3)
	tw.tween_callback(reset)
	tw.tween_property(_cover, "color:a", 0.0, 0.3)


## A breath you hear once you start to tire: louder and quicker the more spent you are.
func _breathe() -> void:
	var n := int(breath / TAU)
	if n == _breath_n:
		return
	_breath_n = n
	if stamina < 0.85:
		_sfx("breath", lerpf(-28.0, -12.0, clampf((0.85 - stamina) / 0.85, 0.0, 1.0)))


## On a controller you feel a hand that carries too much: a soft buzz, stronger as it trembles.
func _feel(delta: float) -> void:
	_rumble_t -= delta
	if _rumble_t > 0.0 or not Game.using_pad:
		return
	var share := loads()
	var worst := 0.0
	for h in [LH, RH]:
		worst = maxf(worst, strain(h, share))
	if worst > SHAKE_FROM:
		Game.rumble(minf(0.45, (worst - SHAKE_FROM) * 1.5), 0.0, 0.25)
		_rumble_t = 0.22


## The controls show at the start of your first few climbs, and again when you stand on the
## sand a while without starting; otherwise the rock has the screen to itself.
func _update_hint(delta: float) -> void:
	var waiting := not on[LH] and not on[RH] and _moves == 0
	_idle_ground = _idle_ground + delta if waiting else 0.0
	_hint.visible = (Game.climbs_started <= 3 and _moves == 0) or _idle_ground > 4.0


## Hold a limb's button to lift it, let go to put it down.
func _update_held() -> void:
	if held >= 0 and not Input.is_action_pressed(BUTTONS[held]):
		_place()
	if held >= 0:
		return
	for i in 4:
		if Input.is_action_just_pressed(BUTTONS[i]) and not (resting and i == rest_hand):
			held = i
			_was_on = on[i]
			prev[i] = pos[i]
			on[i] = false
			return


func _move_limb(steer: Vector2, delta: float) -> void:
	var from := anchor(held)
	var p := pos[held] + steer * CURSOR_SPEED * delta
	var off := p - from
	var past := off.length() > reach(held) and steer.dot(off.normalized()) > 0.5
	off = off.limit_length(reach(held))
	if held >= LF:
		# A knee to your waist; on steep rock a heel goes higher, and so does a foot you put
		# up on top while you press yourself up there.
		off.y = maxf(off.y, -30.0 if steep() or _press(LH) + _press(RH) > 1.0 else -12.0)
	pos[held] = from + off
	pos[held].y = minf(pos[held].y, GROUND_Y)  # not into the sand
	if held < 2 and past and _standing():
		# Reaching further than your arm while your feet carry you: you stand up into it,
		# but only as far as your legs reach: standing up never pulls a foot off.
		var before := body
		body += off.normalized() * STAND_SPEED * delta
		for f in [LF, RF]:
			if on[f] and anchor(f).distance_to(pos[f]) > LEG - 1.0:
				body = before
				break
		stretch = stretch.move_toward(Vector2.ZERO, 30.0 * delta)
	else:
		stretch = stretch.move_toward(off.normalized() * STRETCH if past else Vector2.ZERO, 30.0 * delta)


func _place() -> void:
	var i := held
	held = -1
	if not _was_on and i < 2 and pos[i].distance_to(prev[i]) < 3.0:
		pos[i] = prev[i]  # a hanging hand you did not move stays hanging
		return
	pos[i] = _settle(i, pos[i])
	if grip(i, pos[i]) <= 0.0:
		return  # let go in the air: nothing to hold, the limb just hangs
	on[i] = true
	if not on_ground(i):
		_moves += 1
	if i < 2:
		# You hear and feel how the hand landed: a dry tick on a good hold, a rub of skin on a
		# poor one, and there the hand wobbles for a moment as your weight comes onto it.
		var q := _hand_quality(i, pos[i])
		_sfx("grip_good" if q >= FAIR_GRIP else "grip_poor", -8.0 if q >= GOOD_GRIP else -12.0)
		if q < FAIR_GRIP:
			_wobble[i] = WOBBLE_TIME
			Game.rumble(0.25, 0.0, 0.12)
		else:
			Game.rumble(0.12, 0.0, 0.05)
	else:
		_sfx("step_sand" if on_ground(i) else "step_rock", -14.0 if on_ground(i) else -11.0)


## Standing on top: that is the send. It counts, not how fast: bouldering is no speed climbing.
func _send() -> void:
	_logged = true
	var e := Game.log_attempt(route_id, true, _moves, _slips)
	_write_log(true, "")
	_tell("TOP!  Flash!\nFirst try." if e.flash and e.sends == 1
		else ("TOP!\nSent in %d tries." % e.attempts if e.sends == 1 else "TOP!\nSent again."))
	_note.position.y = 196.0  # on the rock under you, not over your head
	_restart = 3.5
	topped.emit()


## One line per attempt, so the climbing can be tuned on how it is really played: when,
## which block, sent or not, seconds, moves, slips, how low your strength went, why you fell.
func _write_log(sent: bool, reason: String) -> void:
	if not Game.keep_records:
		return
	var fresh := not FileAccess.file_exists(LOG_PATH)
	var f := FileAccess.open(LOG_PATH, FileAccess.WRITE if fresh else FileAccess.READ_WRITE)
	if f == null:
		return
	if fresh:
		f.store_line("time,block,top,seconds,moves,slips,lowest_strength,reason")
	f.seek_end()
	f.store_line("%s,%s,%d,%.1f,%d,%d,%.2f,\"%s\"" % [Time.get_datetime_string_from_system(), route_id,
		1 if sent else 0, _attempt_time, _moves, _slips, _min_stamina, reason.replace("\"", "'")])




## Hold shake-out with both hands on: the hand that works hardest lets go and rests.
func _update_rest() -> void:
	var want := Input.is_action_pressed("shake_out") and held < 0 and on[LH] and on[RH]
	if want and not resting:
		var share := loads()
		rest_hand = LH if strain(LH, share) >= strain(RH, share) else RH
	resting = want


## Where you hang on straight arms, below your hands.
func _hang() -> Vector2:
	var hands := Vector2.ZERO
	var nh := 0
	for i in [LH, RH]:
		# The hand you are moving does not pull you along: you stay where you were.
		if holding(i) or (i == held and _was_on):
			hands += pos[i] if holding(i) else prev[i]
			nh += 1
	return body if nh == 0 else hands / nh + Vector2(0, ARM - 4.0)


## Any foot on the rock holds you up, even a high one: you can always stand up onto it,
## like a rock-over.
func _standing() -> bool:
	return holding(LF) or holding(RF)


func _balance_x() -> float:
	var feet := 0.0
	var nf := 0
	var hands := 0.0
	var nh := 0
	for i in 4:
		if holding(i):
			if i >= LF:
				feet += pos[i].x
				nf += 1
			else:
				hands += pos[i].x
				nh += 1
	if nf == 0:
		return body.x
	var x := feet / nf
	return lerpf(x, hands / nh, 0.3) if nh > 0 else x


## Like on real rock, you move with your legs: on your feet you stay where you are until
## you push yourself up, down or aside. Without a foot under you, you sink onto your arms.
## Never out of reach of a hand or foot.
func _update_body(delta: float, push: Vector2) -> void:
	var mantle := _mantling()
	var pressing := mantle and (push.y < -0.3 or _press(LH) + _press(RH) > 0.5)
	var top_f := _top_foot() if mantle else -1
	if mantle and push.y < -0.3:
		# Both hands on the rim: push up and you press yourself up on your arms, slower than
		# you stand up on your legs. Your feet help as long as they reach. With a foot up on
		# top, pushing up rocks you over onto it: your hips go over that foot by themselves.
		body.y -= PRESS_SPEED * -push.y * delta
		body.x += push.x * PUSH_SPEED * 0.5 * delta
		if top_f >= 0:
			body.x = move_toward(body.x, pos[top_f].x, ROCK_OVER * -push.y * delta)
	elif not _standing():
		# Hanging, you sink onto your arms; a half press on the rim sinks back more slowly,
		# and on straight arms, up over the rim, you hold yourself there while you bring a
		# foot up.
		if not (mantle and _locked()):
			body = body.move_toward(_hang(), (MANTLE_SINK if mantle else BODY_SPEED) * delta)
	elif push != Vector2.ZERO:
		body += push * PUSH_SPEED * delta
	elif held < 0 or held >= LF:
		# Standing still, your weight settles over your feet, leaning a little to your hands:
		# feet under you, not hanging out to one side.
		body.x = move_toward(body.x, _balance_x(), SETTLE_SPEED * delta)
	body += stretch - _lean
	_lean = stretch
	# With a foot up on top you rock over onto it: your hands follow, they do not hold you back.
	var rocking := top_f >= 0
	for _pass in 3:
		for i in [LF, RF, LH, RH]:
			# Pressing up on the rim your feet on the face do not hold you down: too far below,
			# they come off. A foot up on top does keep you near it.
			var free: bool = (pressing and i >= LF and not _on_top(pos[i])) or (rocking and i < 2)
			if on[i] and not free:
				var a := anchor(i)
				var d := a.distance_to(pos[i])
				if d > reach(i):
					body += a.direction_to(pos[i]) * (d - reach(i))
	if rocking:
		for h in [LH, RH]:
			if on[h] and anchor(h).distance_to(pos[h]) > ARM + 4.0:
				on[h] = false  # a hand you have moved away from lets go of the rim
	body.y = minf(body.y, GROUND_Y - ClimberFigure.TORSO - 8.0)  # you can crouch, not sit in the sand
	for h in [LH, RH]:
		if not on[h] and h != held:
			pos[h] = _hanging(h)
	for f in [LF, RF]:
		if not on[f] and f != held:
			pos[f] = anchor(f) + Vector2(-3.0 if f == LF else 3.0, LEG - 2.0)  # a foot in the air dangles
	for f in [LF, RF]:
		if on[f] and pos[f].distance_to(anchor(f)) > LEG + 5.0:
			on[f] = false
			prev[f] = pos[f]
			if not mantle:
				say("Foot off")


## A hand or foot that carries more than its grip can take trembles harder and harder,
## and then slips off. On a good hold that never happens; on bare rock it happens fast.
func _update_slips(delta: float) -> void:
	var share := loads()
	for i in 4:
		if not holding(i) or on_ground(i):
			_slip[i] = 0.0
			continue
		var st := strain(i, share)
		if st > SLIP_FROM:
			_slip[i] += delta * (st - SLIP_FROM + 0.6)
		else:
			_slip[i] = maxf(0.0, _slip[i] - delta * 2.0)
		if _slip[i] >= SLIP_TIME and i < 2 and _press(i) > 0.5:
			# Pressing up on the rim, your arms give out: you sink back until you hang from it.
			# Try again while you have the strength.
			_slip = [0.0, 0.0, 0.0, 0.0]
			_slips += 1
			body = _hang()
			Game.rumble(0.25, 0.4, 0.2)
			_sfx("scrape", -12.0)
			say("Sank back down")
			return
		if _slip[i] >= SLIP_TIME:
			_slip[i] = 0.0
			_slips += 1
			Game.rumble(0.3, 0.6, 0.25)
			on[i] = false
			prev[i] = pos[i]
			_sfx("scrape", -8.0 if i < 2 else -12.0)
			var side := "left" if i % 2 == 0 else "right"
			_last_slip = "Your %s %s slipped off: the rock held too little there." % [side, "hand" if i < 2 else "foot"]
			say("Hand slipping!" if i < 2 else "Foot slipping!")
			return


func _update_strength(delta: float) -> void:
	_update_slips(delta)
	_update_tension(delta)
	var d := drain_now()
	_min_stamina = minf(_min_stamina, stamina)
	if stamina < 0.35 and not _told_rest:
		_told_rest = true
		say("Tired? Hold %s to shake out where you stand well" % button(JOY_BUTTON_Y, "R"))
	if resting and d == 0.0:
		stamina = minf(stamina + REST_GAIN * delta, 1.0)
	stamina -= d * delta
	# A foot up on top of the block holds you too: from there you stand up, you do not fall.
	var grounded := on_ground(LF) or on_ground(RF) or _top_foot() >= 0
	if not holding(LH) and not holding(RH) and not resting and not grounded:
		_start_fall(_last_slip if _last_slip != "" else "No hand left on the rock.")
		return
	if stamina > 0.0:
		return
	# Out of strength: the hand that works hardest slips. A bit of fright keeps you going.
	var share := loads()
	var worst := LH if strain(LH, share) >= strain(RH, share) else RH
	if not on[1 - worst] and not grounded:
		_start_fall("Your strength ran out. Shake out where you stand well.")
		return
	on[worst] = false
	prev[worst] = pos[worst]
	_slips += 1
	Game.rumble(0.3, 0.6, 0.25)
	stamina = 0.15
	_sfx("scrape", -8.0)
	_last_slip = "Your strength ran out. Shake out where you stand well."
	say("Hand slipping!")


## On steep rock your feet stay on while you stand still, but carry little unless you hold
## tension (or hook a heel), and holding it costs strength. Move a hand without tension and
## your feet cut loose: you swing from the other hand.
func _update_tension(delta: float) -> void:
	if not steep():
		return
	var feet_on := false
	for f in [LF, RF]:
		if holding(f) and not on_ground(f) and not heel_hook(f):
			feet_on = true
	if tensed() and (holding(LF) or holding(RF)):
		stamina -= TENSION_DRAIN * delta
	elif not (holding(LF) or holding(RF)) and _fall < 0.0 and _dyno == "":
		stamina -= TENSION_DRAIN * 2.0 * delta  # on your arms alone: that tires you fast
	var moving := held == LH or held == RH
	if feet_on and moving and not tensed():
		_loose += delta
		if _loose >= LOOSE_TIME:
			_cut_loose()
	else:
		_loose = 0.0


## Your feet swing off the rock. A hooked heel keeps you in; otherwise the hand you were
## moving comes away too and you swing from the other one. Push the stick against the
## swing to calm it, then put your feet back on.
func _cut_loose() -> void:
	_loose = 0.0
	for f in [LF, RF]:
		if holding(f) and not on_ground(f) and not heel_hook(f):
			on[f] = false
			prev[f] = pos[f]
	_sfx("scrape", -10.0)
	Game.rumble(0.3, 0.5, 0.2)
	var key := "B" if Game.using_pad else "F"
	if holding(LF) or holding(RF) or held < 0:
		say("Feet off: hold %s as you move a hand" % key)
		return
	var mv := held
	var hand := RH if mv == LH else LH
	if not holding(hand):
		return
	held = -1
	on[mv] = false
	prev[mv] = pos[mv]
	pos[mv] = _hanging(mv)
	_jump_hand = hand
	var d := body - pos[hand]
	_theta = clampf(atan2(d.x, maxf(d.y, 1.0)), -0.6, 0.6)
	var side := signf(_theta) if absf(_theta) > 0.05 else (1.0 if randf() < 0.5 else -1.0)
	_omega = side * 1.0  # your legs swing off the rock and take you with them
	_swing_grip = 2.4 * maxf(hand_grip(pos[hand]), 0.5)
	_calm = 0.0
	_dyno = "swing"
	say("Feet cut loose! Push against the swing")


## A hand that carries too much trembles; when you are nearly spent, everything does. A
## soft, quick tremble, not noise, and the feet only at the very end.
func _shake(i: int, share: Array[float]) -> Vector2:
	if not holding(i) or on_ground(i):
		return Vector2.ZERO
	var amount := maxf(0.0, 0.2 - stamina) * 5.0 + _slip[i] / SLIP_TIME * 2.0
	if i < 2:
		amount += maxf(0.0, strain(i, share) - SHAKE_FROM) * 1.5 + _wobble[i] / WOBBLE_TIME * 1.4
	if amount <= 0.0:
		return Vector2.ZERO
	var t := Time.get_ticks_msec() / 1000.0
	return Vector2(sin(t * 41.0 + i * 1.7), sin(t * 37.0 + i * 2.3)) * minf(amount, 2.5)


## The hand shows how it would hold where it is: curled on a hold, flat on bare rock,
## open while it is in the air.
func _pose_figure() -> void:
	var delta := get_physics_process_delta_time()
	var share := loads()
	# On rock that leans out, with nothing holding your feet in, your legs swing out
	# towards you: they look shorter, and your shadow drifts off the rock.
	var feet_hold := (holding(LF) or holding(RF)) and _fall < 0.0
	var swing_out := 0.0 if feet_hold or not steep() else 1.0
	_away = move_toward(_away, swing_out, delta * (2.5 if swing_out == 0.0 else 1.6))
	var hang := _away * clampf(sin(lean) * 2.2, 0.0, 1.0)
	_shadow_group.position = _shadow_base + Vector2(3.0, 9.0) * hang
	_shadow_group.self_modulate.a = 0.5 - 0.22 * hang
	for f in [_figure, _shadow]:
		f.leg_scale = 1.0 - 0.38 * hang
		f.shoulders = body + Vector2(0, sin(breath) * 0.6)
		for i in 4:
			var p := pos[i] + _shake(i, share)
			if i >= LF and not holding(i):
				var hip := anchor(i)
				var hanging := hip + Vector2(-2.0 if i == LF else 2.0, (ClimberFigure.THIGH + ClimberFigure.SHIN) * (1.0 - 0.38 * hang) * 0.97)
				p = p.lerp(hanging, hang)  # straight, foreshortened: swinging out at you
			f.limbs[i] = p
			if i < 2:
				var state := "grip" if _hand_quality(i, pos[i]) >= FAIR_GRIP else "flat"
				if not on[i] or (resting and i == rest_hand):
					state = "reach"
				var press := _press(i) if state != "reach" else 0.0
				if press > 0.3:
					state = "flat"  # pressing: the palm flat on top, fingers forward over the rim
				f.hand_state[i] = state
				f.hand_dir[i] = Vector2.UP if press > 0.3 else (_fingers(pos[i]) if state != "reach" else Vector2.ZERO)
				f.arm_down[i] = lerpf(0.3, -1.0, press)  # elbows out and up as you press
		f.queue_redraw()
	_marks.queue_redraw()

func _draw() -> void:
	_draw_pad()  # the rock and the forest are drawn by _scene, just below this


## The crash pad at the foot of the block; it gives a little when you land on it.
func _draw_pad() -> void:
	var h := 7.0 - _pad_squash * 3.0
	var r := Rect2(192, GROUND_Y + 1 - h, 88 + _pad_squash * 4.0, h)
	r.position.x -= _pad_squash * 2.0
	draw_rect(r.grow(1.0), Color("2b2329"))
	draw_rect(r, Color("3f6f9a"))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color("5d93bf"))
	draw_rect(Rect2(r.position + Vector2(r.size.x / 2.0 - 0.5, 0), Vector2(1, r.size.y)), Color("2c5578"))
	draw_rect(Rect2(r.position + Vector2(6, h - 2), Vector2(r.size.x - 12, 1)), Color("2c5578"))


func _sfx(name: String, volume_db: float) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = load("res://assets/climb/sfx/%s.wav" % name)
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.92, 1.08)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


## You come off: everything lets go and you drop, arms up, onto the pad.
func _start_fall(reason: String) -> void:
	if not _logged:
		_logged = true
		Game.log_attempt(route_id, false, _moves, _slips)
		_write_log(false, reason)
	_fall = 0.0
	_dyno = ""
	_fall_reason = reason
	held = -1
	resting = false
	for i in 4:
		on[i] = false
	_fall_vel = Vector2(clampf((body.x - _balance_x()) * 0.8, -25.0, 25.0), -15.0)
	if body.y + ClimberFigure.TORSO + LEG < GROUND_Y - 24.0:
		_sfx("whoosh", -6.0)


func _update_fall(delta: float) -> void:
	_fall += delta
	var hips := body + Vector2(0, ClimberFigure.TORSO)
	if _land_at < 0.0:
		_fall_vel.y += 760.0 * delta
		body += _fall_vel * delta
		hips = body + Vector2(0, ClimberFigure.TORSO)
		var w := _fall * 16.0
		pos[LH] = body + Vector2(-13.0 + sin(w) * 3.0, -20.0 + cos(w * 1.3) * 4.0)
		pos[RH] = body + Vector2(13.0 + sin(w + 1.0) * 3.0, -22.0 + cos(w * 1.1) * 4.0)
		pos[LF] = hips + Vector2(-8.0, LEG - 7.0)
		pos[RF] = hips + Vector2(9.0, LEG - 11.0)
		if maxf(pos[LF].y, pos[RF].y) >= GROUND_Y - 5.0:
			_land_at = _fall
			var hard := clampf(_fall_vel.y / 260.0, 0.3, 1.0)
			_sfx("thud", lerpf(-12.0, -3.0, hard))
			_dust.position = Vector2(body.x, GROUND_Y - 4.0)
			_dust.amount = int(lerpf(8.0, 24.0, hard))
			_dust.restart()
			_dust.emitting = true
			_pad_squash = hard
			Game.rumble(0.4 * hard, 0.8 * hard, 0.3)
	else:
		# On the pad: knees give, you sink into a crouch, sit back a little, and breathe.
		var k := _fall - _land_at
		var crouch := GROUND_Y - 5.0 - LEG * 0.55 - ClimberFigure.TORSO
		body.y = lerpf(body.y, crouch + sin(minf(k, 1.0) * PI) * -2.0, minf(1.0, delta * 14.0))
		body.x = lerpf(body.x, body.x + _fall_vel.x * 0.1, delta)
		hips = body + Vector2(0, ClimberFigure.TORSO)
		pos[LF] = Vector2(hips.x - 12.0, GROUND_Y - 5.0)
		pos[RF] = Vector2(hips.x + 12.0, GROUND_Y - 5.0)
		pos[LH] = pos[LH].lerp(hips + Vector2(-10.0, 8.0), minf(1.0, delta * 10.0))
		pos[RH] = pos[RH].lerp(hips + Vector2(10.0, 8.0), minf(1.0, delta * 10.0))
		_pad_squash = maxf(0.0, _pad_squash - delta * 3.0)
		var shake := maxf(0.0, 0.25 - k) * 10.0 * _pad_squash
		_place_view(Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake)
		if k > 0.45 and not _told:
			_told = true
			_tell("You fell   (%s = try again)\n%s" % [button(JOY_BUTTON_LEFT_SHOULDER, "Z"), _fall_reason])
		var again := Input.is_action_just_pressed("hand_left") or Input.is_action_just_pressed("hand_right") or Input.is_action_just_pressed("hop")
		if _cover.color.a == 0.0 and (k > 2.6 or (_told and again)):
			var tw := create_tween()
			tw.tween_property(_cover, "color:a", 1.0, 0.45)
			tw.tween_callback(reset)
			tw.tween_interval(0.15)
			tw.tween_property(_cover, "color:a", 0.0, 0.45)
	breath += delta * 6.0
	_pose_figure()


## A longer note than say(): why you came off, so the next try can be better.
func _tell(text: String) -> void:
	_note.text = text
	_note.modulate.a = 1.0
	_note.size.y = 40.0
	if _note_tween:
		_note_tween.kill()
	_note_tween = create_tween()
	_note_tween.tween_interval(2.4)
	_note_tween.tween_property(_note, "modulate:a", 0.0, 0.4)


## Small marks over the climber: where the limb you move would hold, and how good that is;
## and how a rest is going.
func _draw_marks() -> void:
	_draw_dyno_marks()
	if held >= 0 and Game.show_grips:  # an aid, off by default: feel the rock instead
		var spot := _settle(held, pos[held])
		var q := _hand_quality(held, spot) if held < 2 else grip(held, spot)
		var color := GOOD if q >= GOOD_GRIP else (TARGET if q >= FAIR_GRIP else BAD)
		_corners(spot, 6.0, color)
	if resting:
		var color := GOOD if drain_now() == 0.0 else TARGET
		_marks.draw_arc(body + Vector2(0, -10), 10.0, -PI / 2.0, -PI / 2.0 + TAU * stamina, 24, color, 1.0)


func _corners(at: Vector2, radius: float, color: Color) -> void:
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var p: Vector2 = at + corner * radius
		_marks.draw_line(p, p - Vector2(corner.x * 3, 0), color)
		_marks.draw_line(p, p - Vector2(0, corner.y * 3), color)


# ---------------------------------------------------------------- topping out
## Where the rock begins in column x: the top edge of the block there.
func _top_at(x: float) -> float:
	return float(_top[clampi(int(x), 0, _top.size() - 1)])


## On the top edge of the block, give or take a few pixels: where a foot can stand on top.
## Generous, because a foot put next to your hand on the rim looks like it is on top.
func _on_top(p: Vector2) -> bool:
	var t := _top_at(p.x)
	return t < 9000.0 and p.y >= t - 10.0 and p.y <= t + 7.0


func _on_rim(h: int) -> bool:
	return holding(h) and pos[h].y <= top_y


## Both hands on the rim, over the top edge: from here you climb out. Once a foot is up on
## top you are still climbing out, even with a hand off the rim.
func _mantling() -> bool:
	if _fall >= 0.0 or _dyno != "":
		return false
	return (_on_rim(LH) and _on_rim(RH)) or _top_foot() >= 0


## How much a hand on the rim presses instead of pulls: 0 while you hang below it, 1 once
## your shoulders are up by it.
func _press(h: int) -> float:
	if not _mantling():
		return 0.0
	return clampf((pos[h].y - body.y + 16.0) / 12.0, 0.0, 1.0)


## What a palm pressing on top holds: least with your shoulders at the rim, elbows out (the
## hard part of a mantle), much more on straight arms. Your feet decide how much it must.
func _press_cap(h: int) -> float:
	var up := pos[h].y - body.y  # how far your shoulders are above your hand
	return PALM_PRESS * (0.5 + 0.8 * clampf((up - 6.0) / 14.0, 0.0, 1.0))


## Up on straight arms over the rim: your shoulders well above your hands.
func _locked() -> bool:
	return (pos[LH].y + pos[RH].y) / 2.0 - body.y >= 10.0


## A foot up on top of the block, while you climb out.
func _top_foot() -> int:
	for f in [LF, RF]:
		if holding(f) and _on_top(pos[f]) and pos[f].y <= top_y:
			return f
	return -1


## Hints the first few times, and the moment you stand up: once your hips come up over the
## foot you put on top, you stand up on it, with the other foot beside it.
func _update_mantle() -> void:
	if not _mantling():
		return
	var hints := Game.mantle_hints < 3
	if _mantle_said == 0 and hints:
		_mantle_said = 1
		Game.count_mantle_hint()
		say("Press up:  stick up")
	var f := _top_foot()
	if f < 0:
		if _mantle_said == 1 and hints and _press(LH) + _press(RH) > 1.6:
			_mantle_said = 2
			say("Put a foot up on the rim:  %s" % ("LT or RT" if Game.using_pad else "C or V"))
		return
	if anchor(f).y > pos[f].y + 6.0 or absf(body.x - pos[f].x) > STAND_OVER:
		return  # not over that foot yet: push up
	_stand_t = 0.0
	held = -1
	var other := RF if f == LF else LF
	var side := 1.0 if other == RF else -1.0
	var x2 := clampf(pos[f].x + side * 24.0, 0.0, 479.0)
	_stand_from = [body, pos[LF], pos[RF]]
	var feet: Array[Vector2] = [pos[f], Vector2(x2, _top_at(x2))]
	if other == LF:
		feet.reverse()
	var mid := (feet[0] + feet[1]) / 2.0
	_stand_to = [Vector2(mid.x, minf(feet[0].y, feet[1].y) - LEG + 3.0 - ClimberFigure.TORSO), feet[0], feet[1]]
	on[LH] = false
	on[RH] = false
	on[other] = true
	_sfx("step_rock", -11.0)


## Up you come, over your foot, the other foot beside it, your hands free: then you stand.
func _update_stand(delta: float) -> void:
	_stand_t += delta
	var k := smoothstep(0.0, 1.0, minf(_stand_t / STAND_TIME, 1.0))
	body = _stand_from[0].lerp(_stand_to[0], k)
	pos[LF] = _stand_from[1].lerp(_stand_to[1], k)
	pos[RF] = _stand_from[2].lerp(_stand_to[2], k)
	pos[LH] = _hanging(LH)
	pos[RH] = _hanging(RH)
	breath += delta * 3.0
	_pose_figure()
	if _stand_t >= STAND_TIME and not _logged:
		_send()


## The view follows you up as you climb out, so you see yourself standing on top, and goes
## back down when you come off.
func _update_view(delta: float) -> void:
	var want := 0.0
	if _stand_t >= 0.0:
		want = _cam_max
	elif _mantling():
		var rim := (pos[LH].y + pos[RH].y) / 2.0
		want = _cam_max * clampf((rim - body.y + 28.0) / 70.0, 0.0, 1.0)
	_cam_y = move_toward(_cam_y, want, (60.0 if want > _cam_y else 120.0) * delta)
	if _fall < 0.0 or _land_at < 0.0:  # on the pad, _update_fall adds the shake of landing
		_place_view(Vector2.ZERO)


## Where the climbing screen is drawn: the view moved up, plus a shake when you land hard.
## The colour grade stays put, and the shadow needs to know where the rock now is.
func _place_view(shake: Vector2) -> void:
	position = Vector2(0, _cam_y) + shake
	_grade.position = -position
	_shadow_mat.set_shader_parameter("offset", position)
	(_scene.material as ShaderMaterial).set_shader_parameter("cam", position.y)


# ---------------------------------------------------------------- the dyno
func _hands_on() -> Array[int]:
	var out: Array[int] = []
	for i in [LH, RH]:
		if holding(i):
			out.append(i)
	return out


## You need a hand to push off from and a foot to spring from.
func _begin_load() -> void:
	var hands := _hands_on()
	if hands.is_empty():
		return
	if not (holding(LF) or holding(RF)):
		say("You cannot jump without your feet on")
		return
	if on_ground(LF) and on_ground(RF):
		return  # from the sand you just reach
	_dyno = "load"
	_load_t = 0.0
	_charge = 0.0
	_load_body = body
	_aim = Vector2.UP
	resting = false
	_origin = Vector2.ZERO
	for i in hands:
		_origin += pos[i]
	_origin /= hands.size()


func _update_dyno(delta: float) -> void:
	match _dyno:
		"load":
			_update_load(delta)
		"fly":
			_update_fly(delta)
		"swing":
			_update_swing(delta)
	breath += delta * 6.0
	_pose_figure()


## Sinking into your legs: the longer you hold, the further you will go, up to a point;
## stay down too long and your arms tire and the jump gets smaller again.
func _update_load(delta: float) -> void:
	var steer := Game.steer_vector()
	_aim = _aim.lerp(Vector2.UP.rotated(clampf(steer.x, -1.0, 1.0) * 0.65), minf(1.0, delta * 8.0)).normalized()
	if Input.is_action_pressed("hop"):
		_load_t += delta
		if _load_t <= LOAD_TIME:
			_charge = _load_t / LOAD_TIME
		elif _load_t > LOAD_TIME + LOAD_HOLD:
			_charge = maxf(0.3, 1.0 - (_load_t - LOAD_TIME - LOAD_HOLD) * 0.8)
		var sink := SINK * minf(_load_t / LOAD_TIME, 1.0)
		var target := _load_body + Vector2(0, sink)
		for i in _hands_on():
			var a := target + Vector2((-1.0 if i == LH else 1.0) * ClimberFigure.SHOULDER_W, 0)
			if a.distance_to(pos[i]) > ARM + 1.0:
				target.y = minf(target.y, pos[i].y + sqrt(maxf(0.0, pow(ARM + 1.0, 2) - pow(a.x - pos[i].x, 2))))
		body = target
		stamina -= DRAIN * 0.5 * delta
		return
	# Let go of the button: jump, or stand back up if you hardly sank.
	if _charge < 0.15:
		body = _load_body
		_dyno = ""
		return
	_launch()


func _launch() -> void:
	_jump_hand = LH if _aim.x < -0.05 else RH
	_reach_point = _origin + _aim * DYNO_REACH * _charge
	var side := -1.0 if _jump_hand == LH else 1.0
	_apex = _reach_point + Vector2(-side * ClimberFigure.SHOULDER_W, ARM - 6.0)
	_jump_from = body
	_fly_t = 0.0
	_missed = ""
	for i in 4:
		prev[i] = pos[i]
		on[i] = false
	_sfx("whoosh", -12.0)
	_sfx("effort", -10.0)
	_dyno = "fly"


func _ring() -> float:
	var close := RISE_TIME + DEAD_TIME * 0.5
	return maxf(0.0, (close - _fly_t) / close) * 22.0 + 4.0


## Up you go, slowing to the top; there you hang still for a moment, the dead point,
## and that is when your hand must close on the hold.
func _update_fly(delta: float) -> void:
	_fly_t += delta
	var side := -1.0 if _jump_hand == LH else 1.0
	if _fly_t < RISE_TIME:
		body = _jump_from.lerp(_apex, sin(_fly_t / RISE_TIME * PI / 2.0))
	elif _fly_t < RISE_TIME + DEAD_TIME:
		body = _apex + Vector2(0, (_fly_t - RISE_TIME) * 8.0)
	else:
		_start_fall(_missed if _missed != "" else "Too late: you were already dropping. Press as the ring closes.")
		_fall_vel = Vector2.ZERO
		return
	var arm := anchor(_jump_hand)
	pos[_jump_hand] = arm + (_reach_point - arm).limit_length(ARM + 2.0) if _missed == "" else arm + Vector2(side * 6.0, -ARM + 6.0)
	var other := RH if _jump_hand == LH else LH
	pos[other] = anchor(other) + Vector2(-side * 6.0, 18.0)
	var hips := body + Vector2(0, ClimberFigure.TORSO)
	var stretch_legs := clampf(_fly_t / RISE_TIME, 0.0, 1.0)
	pos[LF] = hips + Vector2(-6.0, lerpf(LEG - 12.0, LEG - 3.0, stretch_legs))
	pos[RF] = hips + Vector2(7.0, lerpf(LEG - 14.0, LEG - 6.0, stretch_legs))
	if _missed != "":
		return
	var pressed := Input.is_action_just_pressed("hand_left") or Input.is_action_just_pressed("hand_right")
	if not pressed:
		return
	if _fly_t < RISE_TIME - EARLY:
		_missed = "Grabbed too early: your hand closed on air."
		say("Too early!")
		return
	var spot := _best_hold(pos[_jump_hand])
	if hand_grip(spot) < FAIR_GRIP:
		_missed = "Nothing to catch there. Aim the arc at a hold."
		_sfx("scrape", -10.0)
		return
	_catch(spot)


func _best_hold(p: Vector2) -> Vector2:
	var best := p.round()
	var best_q := hand_grip(best)
	for dy in range(-CATCH_RADIUS, CATCH_RADIUS + 1):
		for dx in range(-CATCH_RADIUS, CATCH_RADIUS + 1):
			var q := p.round() + Vector2(dx, dy)
			var v := hand_grip(q) - Vector2(dx, dy).length() * 0.004
			if v > best_q:
				best_q = v
				best = q
	return best


## Caught: you hang on one hand and your legs swing on. The further from the dead point
## you caught, and the more sideways you jumped, the wilder the swing.
func _catch(spot: Vector2) -> void:
	pos[_jump_hand] = spot
	on[_jump_hand] = true
	var off_time := absf(_fly_t - (RISE_TIME + DEAD_TIME * 0.5))
	var side := signf(_aim.x) if absf(_aim.x) > 0.05 else (1.0 if randf() < 0.5 else -1.0)
	_theta = clampf((body.x - spot.x) / 30.0, -0.5, 0.5)
	_omega = side * (1.6 + off_time * 10.0 + absf(_aim.x) * 2.5)
	_swing_grip = 2.4 * maxf(hand_grip(spot), 0.5)
	_calm = 0.0
	_sfx("slap", -4.0)
	Game.rumble(0.25, 0.5, 0.15)
	say("Caught!")
	_dyno = "swing"


## A pendulum from your hand. Push the stick against the swing to brake it; a swing that
## goes on too long pulls your hand off.
func _update_swing(delta: float) -> void:
	var steer := Game.steer_vector()
	var h := pos[_jump_hand]
	var push := clampf(steer.x, -1.0, 1.0) * 7.0
	_omega += (-SWING_PULL * sin(_theta) - 0.35 * _omega + push) * delta
	_theta = clampf(_theta + _omega * delta, -1.2, 1.2)
	var down := Vector2(sin(_theta), cos(_theta))
	var side := -1.0 if _jump_hand == LH else 1.0
	body = h + down * (ARM - 4.0) + Vector2(-side * ClimberFigure.SHOULDER_W * cos(_theta), 0)
	var hips := body + down * ClimberFigure.TORSO
	pos[LF] = hips + down.rotated(0.12) * (LEG - 4.0) + Vector2(-4, 0)
	pos[RF] = hips + down.rotated(-0.08) * (LEG - 7.0) + Vector2(4, 0)
	var other := RH if _jump_hand == LH else LH
	pos[other] = anchor(other) + down * 20.0
	_swing_grip -= delta * (0.35 + absf(_omega) * 0.45)
	if _swing_grip <= 0.0:
		_start_fall("The swing pulled your hand off. Push the stick against the swing.")
		return
	_calm = _calm + delta if absf(_theta) < 0.14 and absf(_omega) < 0.55 else 0.0
	if _calm > 0.2:
		# Still: you hang from the jug. Now put your feet back and match.
		_dyno = ""
		prev[other] = pos[other]
		pos[other] = _hanging(other)
		say("Feet back on, second hand on")


func _draw_dyno_marks() -> void:
	match _dyno:
		"load":
			var end := _origin + _aim * DYNO_REACH * _charge
			var q := hand_grip(_best_hold(end))
			var color := GOOD if q >= GOOD_GRIP else (TARGET if q >= FAIR_GRIP else BAD)
			for k in range(1, 15):
				var t := k / 14.0
				var p := _origin.lerp(end, t) + _aim.orthogonal() * sin(t * PI) * 6.0 * _charge
				if k % 2 == 0:
					_marks.draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color("2b2329"))
					_marks.draw_rect(Rect2(p - Vector2(0.5, 0.5), Vector2(1, 1)), color)
			if q >= FAIR_GRIP:
				_corners(_best_hold(end), 6.0, color)
			var bar := Rect2(body.x + 22, body.y - 10, 4, 34)
			_marks.draw_rect(bar.grow(1), Color("2b2329"))
			_marks.draw_rect(bar, Color("4a4247"))
			var hgt := bar.size.y * _charge
			_marks.draw_rect(Rect2(bar.position.x, bar.end.y - hgt, bar.size.x, hgt), GOOD if _load_t >= LOAD_TIME * 0.9 and _load_t <= LOAD_TIME + LOAD_HOLD else TARGET)
		"fly":
			if _missed == "":
				var r := _ring()
				var c := _reach_point
				_marks.draw_arc(c, r + 1.0, 0, TAU, 32, Color("2b2329"), 3.0)
				_marks.draw_arc(c, r, 0, TAU, 32, GOOD if _fly_t >= RISE_TIME - EARLY else Color("fff6e4"), 1.0)
		"swing":
			# Which way to push: against the swing.
			if absf(_omega) > 0.3:
				var dir := -signf(_omega)
				var at := body + Vector2(dir * 16.0, 30.0)
				for w in [[Color("2b2329"), 3.0], [Color("fff6e4"), 1.0]]:
					_marks.draw_line(at, at + Vector2(dir * 10.0, 0), w[0], w[1])
					_marks.draw_line(at + Vector2(dir * 10.0, 0), at + Vector2(dir * 6.0, -3), w[0], w[1])
					_marks.draw_line(at + Vector2(dir * 10.0, 0), at + Vector2(dir * 6.0, 3), w[0], w[1])


# ---------------------------------------------------------------- the block from the side
## Before you climb you see the block from the side for a moment, with its name: whether
## it leans out over you or back, which you cannot see from the front.
func _build_intro(dir: String) -> void:
	_intro_layer.layer = layer_above(4)
	var pic := TextureRect.new()
	pic.texture = load(dir + "side.png")
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_intro_layer.add_child(pic)
	var kind := "overhang" if lean > STEEP else ("slab" if lean < -0.1 else "")
	for k in 2:
		var label := Label.new()
		label.add_theme_font_override("font", Game.font(Game.FONT_TITLE if k == 0 else Game.FONT_TEXT))
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color("fff6e4") if k == 0 else Color("deba6e"))
		label.add_theme_color_override("font_outline_color", Color("2b2329"))
		label.add_theme_constant_override("outline_size", 4)
		label.size = Vector2(480, 20)
		label.position = Vector2(0, 4 + k * 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text = str(route.title) if k == 0 else "%s%s" % [route.grade, ("  ·  " + kind) if kind != "" else ""]
		_intro_layer.add_child(label)
	_intro_layer.visible = false
	add_child(_intro_layer)


## The first time on a block that teaches a kind of hold, one line about it, after the
## block's name. It stays while you start, and goes after a couple of moves.
func _show_tip() -> void:
	var tip := str(route.get("tip", ""))
	if tip == "" or Game.tips_seen.has(route_id):
		return
	Game.saw_tip(route_id)
	if _note_tween:
		_note_tween.kill()
	_note.text = tip
	_note.size.y = 40.0
	_note.modulate.a = 1.0
	_tip = 9.0


func _update_tip(delta: float) -> void:
	if _tip <= 0.0:
		return
	_tip -= delta
	if _tip <= 0.0 or _moves >= 3:
		_tip = 0.0
		_note_tween = create_tween()
		_note_tween.tween_property(_note, "modulate:a", 0.0, 0.5)


func _show_intro() -> void:
	_intro = 1.9
	_intro_layer.visible = true
	for ch in _intro_layer.get_children():
		ch.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_interval(1.5)
		tw.tween_property(ch, "modulate:a", 0.0, 0.4)
	get_tree().create_timer(1.95).timeout.connect(func() -> void: _intro_layer.visible = false)


# ---------------------------------------------------------------- around the rock
## The rock and the forest behind it (see climb_scene.gdshader), with motes and fireflies in
## the air in front of the rock but behind you.
func _build_scene(dir: String) -> void:
	# Taller than the screen by as much as the view moves up when you stand on top.
	_scene.position = Vector2(0, -_cam_max)
	_scene.size = Vector2(480, 270 + _cam_max)
	_scene.z_index = -1  # under the crash pad, which this node draws itself
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = SCENE
	sm.set_shader_parameter("extra", _cam_max)
	sm.set_shader_parameter("rock_mask", load(dir + "rock_mask.png"))
	sm.set_shader_parameter("has_backdrop", backdrop != null)
	if backdrop:
		sm.set_shader_parameter("backdrop", backdrop)
	_scene.material = sm
	add_child(_scene)
	for p in [_motes, _flies]:
		var flies: bool = p == _flies
		p.amount = 14 if flies else 28
		p.lifetime = 5.0 if flies else 7.0
		p.preprocess = p.lifetime
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.position = Vector2(240, 125 if not flies else 170)
		p.emission_rect_extents = Vector2(235, 115 if not flies else 80)
		p.direction = Vector2(0, -1)
		p.spread = 180.0
		p.gravity = Vector2(0, -1.5)
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 6.0 if not flies else 9.0
		p.scale_amount_min = 1.0
		p.scale_amount_max = 1.6 if not flies else 2.0
		p.color = Color(1.0, 0.94, 0.8, 0.75) if not flies else Color(0.92, 1.0, 0.5)
		var ramp := Gradient.new()
		if flies:  # they blink
			ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
			ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.15),
				Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
		else:
			ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
			ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
		p.color_ramp = ramp
		var glow := CanvasItemMaterial.new()
		glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = glow
		add_child(p)


## Blurred grass close to the camera in the corners, then the colour grade over it all.
func _build_front() -> void:
	_front.texture = load("res://assets/climb/front_tufts.png")
	_front.z_index = 5
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_front)
	_grade.size = Vector2(480, 270)
	_grade.z_index = 10
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = GRADE
	_grade.material = gm
	add_child(_grade)
