extends Node
## Global game state (autoload "Game"): which blocks you topped, the controls, fonts, sounds.

signal device_changed  # you switched between keyboard and controller
signal settings_changed

const ASSETS := "res://assets/ninja_adventure/"  # only four of its menu sounds are left (CC0, see LICENSE.txt)
const FONTS := "res://assets/fonts/kenney_kenney-fonts/Fonts/"
const FONT_TEXT := "Kenney Pixel"  # crisp at size 16
const FONT_TITLE := "Kenney Mini"  # bolder, for names and banners

const SETTINGS_PATH := "user://settings.cfg"
const SAVE_PATH := "user://save.cfg"  # your progress, kept as you go (see save_progress)
const SAVE_KEYS := ["topped", "logbook", "known", "tips_seen", "climbs_started", "mantle_hints", "area"]
const VOLUME_STEPS := 5
const STICK_DEADZONE := 0.25
const ALL_DEVICES := -1  # a binding made in code otherwise only listens to controller 0
const XBOX_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_START: "Start",
	JOY_BUTTON_BACK: "View",
}
const BUTTON_NAMES := {
	["nintendo", "pro controller", "joy-con", "switch"]: {
		JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X",
		JOY_BUTTON_LEFT_SHOULDER: "L", JOY_BUTTON_RIGHT_SHOULDER: "R", JOY_BUTTON_START: "+",
		JOY_BUTTON_BACK: "-",
	},
	["dualsense", "dualshock", "playstation", "ps4", "ps5"]: {
		JOY_BUTTON_A: "Cross", JOY_BUTTON_B: "Circle", JOY_BUTTON_X: "Square", JOY_BUTTON_Y: "Triangle",
		JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_START: "Options",
		JOY_BUTTON_BACK: "Create",
	},
}

var topped := {}  # boulder id -> true
# Per block (its route): attempts, sends, whether it was a flash, the fewest moves, and how
# often a hand or foot slipped. No times: bouldering is about the send, not speed.
var logbook := {}
var show_grips := false  # the marks that show how well a spot holds: an aid, off by default
var climbs_started := 0  # the controls show on the rock only during your first few climbs
var mantle_hints := 0  # how to climb out at the top: told on your first few tries
var known := {}  # blocks outside the circuit someone told you about: they are in your topo
var tips_seen := {}  # blocks whose tip about their kind of hold you have been told
var area := ""  # the scene of the area you were last in: Continue takes you back there
var keep_records := true  # off while a test bot plays: it must not fill your save or climb log
var using_pad := false  # the last thing you touched was a controller
# Settings, kept in SETTINGS_PATH.
var rumble_on := true
var volume := 4  # of VOLUME_STEPS
var graphics_low := false  # fewer shadows, no fog or ambient occlusion: for laptops and handhelds
var fullscreen := false

var _last_pad := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # its sounds play in menus too, while the game is paused
	_setup_input()
	_load_settings()
	_load_progress()
	var pads := Input.get_connected_joypads()
	using_pad = not pads.is_empty()
	if using_pad:
		_last_pad = pads[0]
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func is_topped(boulder_id: String) -> bool:
	return topped.has(boulder_id)


func mark_topped(boulder_id: String) -> void:
	topped[boulder_id] = true
	save_progress()


# ---------------------------------------------------------------- progress
## Your progress is kept as you go: after every attempt, every block you top, everything you
## are told. There is no save button; closing the game loses nothing.
func save_progress() -> void:
	if not keep_records:
		return
	var cfg := ConfigFile.new()
	for key in SAVE_KEYS:
		cfg.set_value("progress", key, get(key))
	cfg.save(SAVE_PATH)


func has_progress() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for key in SAVE_KEYS:
		set(key, cfg.get_value("progress", key, get(key)))


## Start over: an empty logbook and topo, the first-time tips again.
func new_game() -> void:
	topped = {}
	logbook = {}
	known = {}
	tips_seen = {}
	climbs_started = 0
	mantle_hints = 0
	area = ""
	if has_progress():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## Someone told you about a block outside the circuit: it is in your topo from now on.
func tell_block(id: String) -> void:
	known[id] = true
	save_progress()


func saw_tip(route: String) -> void:
	tips_seen[route] = true
	save_progress()


func count_climb() -> void:
	climbs_started += 1
	save_progress()


func count_mantle_hint() -> void:
	mantle_hints += 1
	save_progress()


func enter_area(scene: String) -> void:
	area = scene
	save_progress()


## How your logbook reads for one block, in a line.
func log_line(route: String) -> String:
	var e: Dictionary = logbook.get(route, {})
	if e.get("flash", false):
		return "Flash: first try"
	if e.get("sends", 0) == 1:
		return "Sent in %d %s" % [e.attempts, "try" if e.attempts == 1 else "tries"]
	if e.get("sends", 0) > 1:
		return "Climbed %d times" % e.sends
	if e.get("attempts", 0) > 0:
		return "%d %s, no send yet" % [e.attempts, "try" if e.attempts == 1 else "tries"]
	return "Not tried yet"


# ---------------------------------------------------------------- settings
func setting_text(id: String) -> String:
	match id:
		"show_grips":
			return "On" if show_grips else "Off"
		"rumble":
			return "On" if rumble_on else "Off"
		"volume":
			return str(volume)
		"graphics":
			return "Low" if graphics_low else "High"
		"window":
			return "Fullscreen" if fullscreen else "Windowed"
	return ""


## Change a setting one step (a toggle simply flips), apply it and keep it.
func change_setting(id: String, step: int) -> void:
	match id:
		"show_grips":
			show_grips = not show_grips
		"rumble":
			rumble_on = not rumble_on
			if rumble_on:
				rumble(0.3, 0.0, 0.15)  # so you feel what you switched on
		"volume":
			volume = clampi(volume + step, 0, VOLUME_STEPS)
		"graphics":
			graphics_low = not graphics_low
		"window":
			fullscreen = not fullscreen
	_apply_settings()
	var cfg := ConfigFile.new()
	for key in ["show_grips", "rumble_on", "volume", "graphics_low", "fullscreen"]:
		cfg.set_value("settings", key, get(key))
	cfg.save(SETTINGS_PATH)
	settings_changed.emit()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for key in ["show_grips", "rumble_on", "volume", "graphics_low", "fullscreen"]:
			set(key, cfg.get_value("settings", key, get(key)))
	_apply_settings()


func _apply_settings() -> void:
	AudioServer.set_bus_mute(0, volume == 0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(volume) / VOLUME_STEPS, 0.01)))
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


## One attempt on a block, sent or not. A flash is a send on your very first attempt.
func log_attempt(route: String, sent: bool, moves := 0, slips := 0) -> Dictionary:
	var e: Dictionary = logbook.get(route, {"attempts": 0, "sends": 0, "flash": false, "best_moves": 0, "slips": 0})
	e.attempts += 1
	e.slips += slips
	if sent:
		if e.sends == 0 and e.attempts == 1:
			e.flash = true
		e.sends += 1
		if e.best_moves == 0 or moves < e.best_moves:
			e.best_moves = moves
	logbook[route] = e
	save_progress()
	return e


# Arrows/WASD to walk, Z/Space = A, X = B. A controller works too.
# The stick has its own actions: menus read move_* as single presses, which an
# analog stick would repeat on every tiny movement.
func _setup_input() -> void:
	_bind("move_left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT])
	_bind("move_right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT])
	_bind("move_up", [KEY_UP, KEY_W], [JOY_BUTTON_DPAD_UP])
	_bind("move_down", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN])
	_bind("action_a", [KEY_Z, KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A])
	_bind("action_b", [KEY_X, KEY_SHIFT], [JOY_BUTTON_B])
	_bind_axis("stick_left", JOY_AXIS_LEFT_X, -1.0)
	_bind_axis("stick_right", JOY_AXIS_LEFT_X, 1.0)
	_bind_axis("stick_up", JOY_AXIS_LEFT_Y, -1.0)
	_bind_axis("stick_down", JOY_AXIS_LEFT_Y, 1.0)
	# On the rock: four limbs, four buttons (shoulders for the hands, triggers for the feet).
	_bind("hand_left", [KEY_Z], [JOY_BUTTON_LEFT_SHOULDER])
	_bind("hand_right", [KEY_X], [JOY_BUTTON_RIGHT_SHOULDER])
	_bind("foot_left", [KEY_C], [])
	_bind("foot_right", [KEY_V], [])
	_bind("hop", [KEY_SPACE], [JOY_BUTTON_A])
	_bind("tension", [KEY_F], [JOY_BUTTON_B])  # body tension on steep rock
	_bind_axis("foot_left", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_bind_axis("foot_right", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_bind("shake_out", [KEY_R], [JOY_BUTTON_Y])
	_bind("action_c", [KEY_T], [JOY_BUTTON_Y])  # in the walking world: on to the next time of day
	_bind("toggle_grips", [KEY_G], [JOY_BUTTON_BACK])  # on the rock: show how well a spot holds
	_bind("topo", [KEY_TAB, KEY_M], [JOY_BUTTON_BACK])  # in the walking world: the map of the area
	_bind("to_menu", [KEY_ESCAPE], [JOY_BUTTON_START])


func _bind(action: String, keys: Array, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		ev.device = ALL_DEVICES
		InputMap.action_add_event(action, ev)
	for button in buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		ev.device = ALL_DEVICES
		InputMap.action_add_event(action, ev)


func _bind_axis(action: String, axis: JoyAxis, direction: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, STICK_DEADZONE)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = direction
	ev.device = ALL_DEVICES
	InputMap.action_add_event(action, ev)


## Keeps track of what you are playing with, so hints can name the right buttons.
func _input(event: InputEvent) -> void:
	var pad := event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5)
	if pad:
		_last_pad = event.device
	if (pad and not using_pad) or (event is InputEventKey and using_pad):
		using_pad = pad
		device_changed.emit()


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		_last_pad = device
	using_pad = connected or not Input.get_connected_joypads().is_empty()
	device_changed.emit()


## What a controller button is called on the controller you are holding. The
## button is its position: a Switch controller has its B where an Xbox one has A.
func button_name(button: JoyButton) -> String:
	var pad_name := Input.get_joy_name(_last_pad).to_lower()
	for words in BUTTON_NAMES:
		for word in words:
			if pad_name.contains(word):
				return BUTTON_NAMES[words].get(button, "?")
	return XBOX_NAMES.get(button, "?")


## Where you are steering: the stick (analog) if it is pushed, else arrows or d-pad.
func steer_vector() -> Vector2:
	var stick := Input.get_vector("stick_left", "stick_right", "stick_up", "stick_down")
	if stick != Vector2.ZERO:
		return stick
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## A pixel font with smoothing turned off, so it stays crisp when scaled up.
func font(font_name: String) -> FontFile:
	var f: FontFile = load(FONTS + font_name + ".ttf")
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f


## A short buzz on the controller you are holding; nothing on a keyboard.
func rumble(weak: float, strong: float, seconds: float) -> void:
	if using_pad and rumble_on:
		Input.start_joy_vibration(_last_pad, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), seconds)


func sfx(path: String, volume_db := -6.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = load(ASSETS + "Audio/" + path)
	player.volume_db = volume_db
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
