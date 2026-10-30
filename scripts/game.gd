extends Node
## Global game state (autoload "Game"): beanies, skin, time of day, gear and the controls.

signal changed  # anything in the HUD changed

const ASSETS := "res://assets/ninja_adventure/"
const FONTS := "res://assets/fonts/kenney_kenney-fonts/Fonts/"
const FONT_TEXT := "Kenney Pixel"  # crisp at size 16
const FONT_TITLE := "Kenney Mini"  # bolder, for names and banners

const WEEKDAYS := ["ma", "di", "wo", "do", "vr", "za", "zo"]
const COMP_DAY := "za"
const BASE_SKIN := 6
const DAY_START := 9
const DARK := 20  # no climbing from this hour

const GEAR := {
	"fan": {"name": "Ventilator", "price": 2, "info": "Koele vingers: +3 vel per dag."},
	"big_pad": {"name": "Dikke crashpad", "price": 3, "info": "Nodig voor hoge blokken."},
	"second_pad": {"name": "Tweede crashpad", "price": 3, "info": "Met de dikke pad: highballs."},
	"shoes": {"name": "Scherpe schoenen", "price": 3, "info": "Meer marge op voetjes en hakken."},
	"tape": {"name": "Fingertape", "price": 1, "info": "+1 vel als je tapet (kost een uur).", "consumable": true},
}

var beanies := 0  # in your pocket, to spend
var beanies_total := 0  # ever earned; the forester's gates look at this
var topped := {}  # boulder id -> true
var attempts := {}  # boulder id -> number of tries (for flashes)
var gear := {}  # gear id -> true
var tape := 0  # rolls of fingertape in your backpack
var projectors := {}  # "area_day" -> list of today's projecting climbers there
var spotting := {}  # the climber you are spotting right now (for the spot move)
var comp_day := 0  # the last day you signed up for the comp
var comp_asked_day := 0  # the last day Joris asked you at the entrance
var comp_score := {}  # this Saturday: {"tops": n, "zones": n, "tried": [problem ids], "done": bool}
var comp_wins := 0  # first places, for a future sponsor
var beta_day := {}  # boulder id -> day you got its beta from someone (easier that day)
var seen_moves := {}  # microgame name -> true once you have tried it
var quests := {}  # quest id -> "started", "found" or "done"
var flags := {}  # one-off world changes, e.g. "gate_open"
var weather := "droog"  # "droog" or "regen" (wet Font sandstone must not be climbed)
var hang_best := 0  # gym record: most hangboard reps in one go
var hang_last := 0  # reps in the latest hangboard session
var campus_best: Array = [1, 1, 1]  # gym record on the campus board, e.g. [1, 4, 7]
var campus_last: Array = []  # rungs reached in the latest attempt
var spawn := "tent"  # where you appear when an area loads
var area := "sables"  # the area you are in (or came from, while on the map)
var day := 1
var hour := DAY_START
var skin := BASE_SKIN


func _ready() -> void:
	_setup_input()


# --- beanies & gear -----------------------------------------------------

func add_beanies(amount: int) -> void:
	beanies += amount
	beanies_total += amount
	changed.emit()


func has_gear(id: String) -> bool:
	return gear.has(id)


func buy(id: String) -> bool:
	var price: int = GEAR[id].price
	var consumable: bool = GEAR[id].get("consumable", false)
	var needs: String = GEAR[id].get("needs", "")
	if (has_gear(id) and not consumable) or beanies < price or (needs != "" and not has_gear(needs)):
		return false
	beanies -= price
	if consumable:
		tape += 1
		changed.emit()
		return true
	gear[id] = true
	if id == "fan":
		skin += 3
	changed.emit()
	return true


func is_topped(boulder_id: String) -> bool:
	return topped.has(boulder_id)


func mark_topped(boulder_id: String) -> void:
	topped[boulder_id] = true


# --- skin, time & conditions ------------------------------------------

func max_skin() -> int:
	return BASE_SKIN + (3 if has_gear("fan") else 0)


## One try on a boulder: costs skin and an hour. Falls on slopers cost extra skin.
# --- legends ---------------------------------------------------------------

## Each area's legend: beat them on their boulder after doing all circuits there.
## Their beanie is worth +2 climber level.
const LEGENDS := {
	"pepe": {"name": "Pepe Bleau", "area": "sables", "boulder": "geel4", "score": 18,
		"requires": ["geel1", "geel2", "geel3", "geel4", "geel5", "geel6"],
		"pool": ["sloper", "sloper", "mantle", "crimp", "footwork", "beta"],
		"beanie": "Pepe's wollen muts", "color": "8a5fd0"},
}
const LEGEND_BONUS := 2.0

var legends_beaten := {}  # legend id -> true


func can_challenge(id: String) -> bool:
	return LEGENDS[id].requires.all(func(b): return is_topped(b))


func beat_legend(id: String) -> void:
	legends_beaten[id] = true
	changed.emit()


# --- climber level ---------------------------------------------------------

## The circuits and their boulders. Your climber level only goes up when you
## finish a whole circuit (+1) or beat a legend (+2), so it grows slowly.
const CIRCUITS := {
	"Geel": ["geel1", "geel2", "geel3", "geel4", "geel5", "geel6"],
	"Oranje": ["or1", "or2", "or3", "or4", "or5", "or6", "or7", "or8"],
	"Blauw": ["bl1", "bl2", "bl3"],
}


func circuit_done(circuit_name: String) -> bool:
	return CIRCUITS[circuit_name].all(func(b): return is_topped(b))


func circuits_done() -> int:
	return CIRCUITS.keys().filter(func(c): return circuit_done(c)).size()


## How strong you are, on the same scale as Boulder.level
## (0 = grade 2, 6 = 4c, 8 = 7a, 10 = 8a).
func climber_level() -> float:
	return 2.0 + circuits_done() + legends_beaten.size() * LEGEND_BONUS


## How far a boulder is above you (0 = fine). One level of slack.
func gap_for(boulder_level: int) -> float:
	return maxf(0.0, boulder_level - climber_level() - 1.0)


## Speed multiplier for a boulder above your level. It climbs steeply, so a
## boulder far above you (a 7a or 8a early on) is near impossible.
func gap_factor(boulder_level: int) -> float:
	var gap := gap_for(boulder_level)
	return 1.0 + 0.3 * gap + 0.05 * gap * gap


## A practice attempt (falling on a move you had never seen) costs no skin.
func spend_attempt(boulder_id: String, extra_skin: int, practice := false) -> void:
	attempts[boulder_id] = attempts.get(boulder_id, 0) + 1
	if not practice:
		skin = maxi(0, skin - 1 - extra_skin)
	hour = mini(DARK, hour + 1)
	changed.emit()


## Climbers projecting boulders in an area today (same answer all day). About
## one per 7 boulders, at least an 80% chance of one in a small area. In a
## small area they all want a spotter; in bigger ones only the first does.
func todays_projectors(area_id: String, boulder_ids: Array, spot_everyone: bool) -> Array:
	var key := "%s_%d" % [area_id, day]
	if projectors.has(key):
		return projectors[key]
	var list := []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	if not is_raining() and not boulder_ids.is_empty():
		var count := boulder_ids.size() / 7 + (1 if rng.randf() < 0.8 else 0)
		var names := ["Noor", "Mehdi", "Sophie", "Bas", "Yara", "Tim", "Ines", "Kofi"]
		var looks := ["Villager5", "Villager6", "Hunter", "Inspector", "Woman", "OldWoman", "Princess", "Noble"]
		var pool := boulder_ids.duplicate()
		for i in mini(count, pool.size()):
			var who := rng.randi() % names.size()
			var spot: String = pool.pop_at(rng.randi() % pool.size())
			list.append({"name": names[who], "character": looks[who], "boulder": spot, "state": "projecting",
				"wants_spot": spot_everyone or i == 0})
			names.remove_at(who)
			looks.remove_at(who)
	projectors[key] = list
	return list


## Tape a split tip: one skin back, but taping takes an hour.
func use_tape() -> bool:
	if tape <= 0 or skin >= max_skin():
		return false
	tape -= 1
	skin += 1
	hour = mini(DARK, hour + 1)
	changed.emit()
	return true


func sleep() -> void:
	day += 1
	hour = DAY_START
	skin = max_skin()
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 7919
	weather = "regen" if rng.randf() < 0.1 else "droog"
	changed.emit()


func weekday() -> String:
	return WEEKDAYS[(day - 1) % 7]


func is_comp_day() -> bool:
	return weekday() == COMP_DAY


## Which set of problems is on the gym wall: a new set every Saturday, kept all week.
func wall_set() -> int:
	return (day + 1) / 7


func in_comp_today() -> bool:
	return is_comp_day() and comp_day == day


func is_raining() -> bool:
	return weather == "regen"


# --- travelling -------------------------------------------------------------

const AREAS := {
	"sables": "res://scenes/world.tscn",
	"karma": "res://scenes/gym.tscn",
	"map": "res://scenes/map.tscn",
	"culdechien": "res://scenes/cul_de_chien.tscn",
}


## Load another area. Travelling to a different place on the map takes an hour.
func travel(to: String, at := "door") -> void:
	spawn = at
	if to != "map":
		if to != area:
			hour = mini(DARK, hour + 1)
		area = to
	changed.emit()
	get_tree().change_scene_to_file.call_deferred(AREAS[to])


## How the rock feels right now. friction > 1 makes the microgames faster/harder.
func condition() -> Dictionary:
	if is_raining():
		return {"name": "regen", "friction": 1.0}
	if hour < 12:
		return {"name": "koel en droog", "friction": 0.9}
	if hour < 16:
		return {"name": "warm, zweterig", "friction": 1.15}
	return {"name": "avondfris", "friction": 1.0}


## Light tint for the world at the current hour.
func daylight() -> Color:
	if is_raining():
		return Color("a8b0c4")
	var keys := {9: Color("fff4e0"), 12: Color("ffffff"), 15: Color("fff8ec"), 17: Color("ffdcb0"), 19: Color("c9a6c4"), 20: Color("8a82b8")}
	var prev := DAY_START
	for h in keys:
		if h >= hour:
			if h == hour or h == prev:
				return keys[h]
			return keys[prev].lerp(keys[h], float(hour - prev) / (h - prev))
		prev = h
	return keys[DARK]


# --- controls -----------------------------------------------------------

# Arrows/WASD to walk, Z/Space = A, X = B. A controller works too.
func _setup_input() -> void:
	_bind("move_left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT])
	_bind("move_right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT])
	_bind("move_up", [KEY_UP, KEY_W], [JOY_BUTTON_DPAD_UP])
	_bind("move_down", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN])
	_bind("action_a", [KEY_Z, KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A])
	_bind("action_b", [KEY_X, KEY_SHIFT], [JOY_BUTTON_B])


func _bind(action: String, keys: Array, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
	for button in buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		InputMap.action_add_event(action, ev)


## A pixel font with smoothing turned off, so it stays crisp when scaled up.
func font(font_name: String) -> FontFile:
	var f: FontFile = load(FONTS + font_name + ".ttf")
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f


func sfx(path: String, volume_db := -6.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = load(ASSETS + "Audio/" + path)
	player.volume_db = volume_db
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
