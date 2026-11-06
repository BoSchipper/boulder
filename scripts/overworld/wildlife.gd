class_name Wildlife
extends Node3D
## Life in the forest: now and then an animal passes by. A rabbit or a fox comes out of the
## trees and goes a stretch along the edge of the forest, away from the blocks and from
## people, then back in; a bird flies over, or lands on top of a block for a while. They get
## away from you when you come close; while you climb, nothing comes.
## Drawn strips (wild_rabbit.png and so on, four frames each, written by sprites_hd.py)
## are used when the area has them; the stand-ins below, a few pixels each, otherwise.

const TEXEL := 0.055
const NEAR := 2.6  # come this close and it runs or flies off
const GONE := 17.0  # this far from you it is out of sight: it goes
const PAL := {
	"o": Color8(40, 26, 38),
	"b": Color8(146, 120, 96),
	"l": Color8(186, 164, 134),
	"d": Color8(106, 84, 70),
	"w": Color8(236, 230, 216),
	"p": Color8(204, 150, 140),
	"e": Color8(24, 16, 22),
	"r": Color8(210, 106, 46),
	"R": Color8(238, 150, 78),
	"D": Color8(146, 66, 38),
	"k": Color8(44, 32, 36),
	"j": Color8(182, 136, 116),
	"J": Color8(214, 178, 152),
	"u": Color8(76, 128, 206),
	"g": Color8(120, 104, 70),
	"G": Color8(164, 146, 104),
}
const KINDS := {
	"rabbit": {"speed": 2.2, "frames": [
		[
			"...........oo...",
			"..........opo...",
			"..........opoo..",
			"..........oboo..",
			".........obbbbo.",
			"........obbbebbo",
			"...oo..obbbbbbbo",
			"..owwoobbbbbbbo.",
			"..owwbbbbbbbbbo.",
			"...obbbbbbblbbo.",
			"...obblbbbllbo..",
			"....ooooooooo...",
		],
		[
			"................",
			"............oo..",
			"...........opo..",
			"...........opoo.",
			"..........obbbo.",
			".oo.....obbbbebo",
			"owwooooobbbbbbbo",
			"owwbbbbbbbbbbbo.",
			".obbbbbbbbbbbo..",
			"obblboooobblbo..",
			"oloo.....oolo...",
			".o........oo....",
		],
	]},
	"fox": {"speed": 1.7, "frames": [
		[
			"...................o.o..",
			"..................oDoDo.",
			"..................orrrro",
			".................orrrerr",
			"oooo.............orrRRRk",
			"wRRro...........orrrRwo.",
			"orRrro.ooooooooorrrrwo..",
			".orrrrorrrrrrrrrrrrRo...",
			"..oorrrrrrrrrrrrrRRo....",
			"....orrRRRRRRRrrrro.....",
			"....okko.okko.okko.okko.",
			"....okko..oko..oko..oko.",
			"....oooo..ooo..ooo..ooo.",
		],
		[
			"...................o.o..",
			"..................oDoDo.",
			"..................orrrro",
			".................orrrerr",
			"oooo.............orrRRRk",
			"wRRro...........orrrRwo.",
			"orRrro.ooooooooorrrrwo..",
			".orrrrorrrrrrrrrrrrRo...",
			"..oorrrrrrrrrrrrrRRo....",
			"....orrRRRRRRRrrrro.....",
			"...okko..okko.okko..okko",
			"..okko....oko.oko....oko",
			"..ooo.....ooo.ooo....ooo",
		],
	]},
	"bird": {"speed": 4.2, "frames": [
		[
			"................",
			"................",
			"................",
			"..........ooo...",
			".........ojjjo..",
			"........ojjjeoko",
			"..ooo..ojjjjjo..",
			".okkkoojwujjjo..",
			"..ookkkjuwjJJo..",
			"....oookkjJJo...",
			".......oooooo...",
			"........o..o....",
		],
		[
			"......ooo.......",
			".....owwko......",
			"....owukko......",
			"....owukkoooo...",
			".....owkojjjjo..",
			"......okjjjjeoko",
			"..ooo..jjjjjjo..",
			".okkkoojjjjJJo..",
			"..ooooojjjJJo...",
			"......oooooo....",
			"................",
			"................",
		],
		[
			"................",
			"................",
			"................",
			"..........ooo...",
			".........ojjjo..",
			"........ojjjeoko",
			"..ooo..ojjjjjo..",
			".okkkoojjjjJJo..",
			"..ooooowwujJo...",
			".......owukko...",
			"........owkko...",
			".........ooo....",
		],
	]},
}

# Which frame shows what: in the drawn strips, and in the stand-ins, which have fewer.
const DRAWN := {"sit": 0, "alert": 1, "crouch": 2, "air": 3, "stand": 0, "sniff": 1, "trot_a": 2, "trot_b": 3,
	"perch": 0, "peck": 1, "up": 2, "down": 3}
const STAND_IN := {
	"rabbit": {"sit": 0, "alert": 0, "crouch": 1, "air": 1},
	"fox": {"stand": 0, "sniff": 0, "trot_a": 0, "trot_b": 1},
	"bird": {"perch": 0, "peck": 0, "up": 1, "down": 2},
}

var area: Node3D  # the walking world (area_3d.gd): ground, player, sprite material
var _ground: Image  # the kind of ground per cell: 1 sand, 4 path, 5 rock, 2 3 6 forest floor
var _people: Array[Vector2] = []  # where people and the dog stand, and the camp: keep clear
var _next := 12.0  # seconds until the next animal may come
var _mesh: MeshInstance3D
var _mat: ShaderMaterial
var _kind := ""
var _frames := 1
var _pos := Vector3.ZERO  # on the ground the height follows the ground; a bird's is its own
var _path: Array[Vector3] = []
var _seg := 0  # the point of the path it is going to
var _perch_i := -1  # a bird: the point of its path where it sits down
var _dir := 1.0  # 1 facing right, as drawn; -1 mirrored
var _state := ""  # rabbit: hop/sit; fox: trot/stop; bird: fly/perch/leave
var _t := 0.0
var _wait := 0.0
var _fleeing := false
var _lift := 0.0  # a hop or a peck, in metres
var _drawn := false  # drawn frames, or the stand-ins
var _rest_pose := ""  # what it does while it waits: sit or sit up, stand or sniff


func _ready() -> void:
	var path: String = area.area_dir + "ground.png"
	if ResourceLoader.exists(path):
		_ground = (load(path) as Texture2D).get_image()
	for n in area.meta.npcs:
		_people.append(Vector2(n.x, n.z))
	var camp: Dictionary = area.meta.get("camp", {})
	for key in ["tent", "fire", "blanket"]:
		if camp.has(key):
			_people.append(Vector2(camp[key][0], camp[key][1]))
	for p in area.meta.get("pads", []):
		_people.append(Vector2(p[0], p[1]))


func _process(delta: float) -> void:
	if area.get("_climb") != null:
		if _mesh:
			_leave()
		return
	if _mesh == null:
		_next -= delta
		if _next <= 0.0:
			_next = randf_range(4.0, 8.0)  # try again soon if there was no good place
			_spawn()
		return
	_t += delta
	var player: Vector3 = area.player.position
	var flat := Vector2(_pos.x - player.x, _pos.z - player.z)
	if not _fleeing and flat.length() < NEAR:
		_flee(player)
	match _kind:
		"rabbit":
			_rabbit(delta)
		"fox":
			_fox(delta)
		"bird":
			_bird(delta)
	_place()
	if _seg >= _path.size() or flat.length() > GONE:
		_leave()


## Which animal is about, for a test or a look: "" when none.
func current() -> String:
	return _kind


# ---------------------------------------------------------------- coming and going
func _spawn(kind := "") -> void:
	if kind == "":
		var night: bool = area.hour < 7.0 or area.hour > 20.0
		var r := randf()
		kind = ("fox" if r < 0.5 else ("rabbit" if r < 0.9 else "bird")) if night \
			else ("rabbit" if r < 0.4 else ("bird" if r < 0.8 else "fox"))
	if not (_bird_route() if kind == "bird" else _edge_route()):
		return
	_kind = kind
	var look: String = kind if kind != "bird" else ("jay" if randf() < 0.5 else "robin")
	var path: String = area.area_dir + "wild_%s.png" % look
	var tex: Texture2D
	_drawn = ResourceLoader.exists(path)
	if _drawn:
		tex = load(path)
		_frames = 4
		_mat = area.call("_sprite_material", tex, load(path.replace(".png", "_n.png")))
	else:
		var frames: Array = KINDS[kind].frames
		_frames = frames.size()
		tex = _strip(frames)
		_mat = area.call("_sprite_material", tex, _flat_normals(tex.get_image()))
	var q := QuadMesh.new()
	q.size = Vector2(tex.get_width() / float(_frames), tex.get_height()) * TEXEL
	q.center_offset = Vector3(0, q.size.y / 2.0, 0)
	q.material = _mat
	_mesh = MeshInstance3D.new()
	_mesh.mesh = q
	add_child(_mesh)
	_t = 0.0
	_wait = 0.0
	_lift = 0.0
	_fleeing = false
	_state = {"rabbit": "hop", "fox": "trot", "bird": "fly"}[kind]
	_rest_pose = "sit" if kind == "rabbit" else "stand"
	_frame(0)
	_place()


## A rabbit or a fox: out of the trees, a stretch along the edge of the forest somewhere in
## view (on the sand right in front of the trees), back into the trees. Never by a block or
## by people.
func _edge_route() -> bool:
	var player: Vector3 = area.player.position
	for attempt in 60:
		var p := Vector2(player.x + randf_range(-9.0, 9.0), player.z + randf_range(-9.0, 2.0))
		if not _good(p) or not _in_view(p) or p.distance_to(Vector2(player.x, player.z)) < 5.0:
			continue
		var n := _to_forest(p)
		var along := Vector2(-n.y, n.x) * (1.0 if randf() < 0.5 else -1.0)
		var back := _walk(p, -along, randf_range(2.5, 5.0))
		var on := _walk(p, along, randf_range(4.0, 8.0))
		back.reverse()
		var line: Array[Vector2] = []
		line.append_array(back)
		line.append(p)
		line.append_array(on)
		var length := 0.0
		for k in range(1, line.size()):
			length += line[k].distance_to(line[k - 1])
		if length < 4.5:
			continue
		var first := line[0]
		var last := line[-1]
		var in0 := _to_forest(first) * 3.0
		var in1 := _to_forest(last) * 3.0
		_path.clear()
		_path.append(Vector3(first.x + in0.x, 0.0, first.y + in0.y))
		for q in line:
			_path.append(Vector3(q.x, 0.0, q.y))
		_path.append(Vector3(last.x + in1.x, 0.0, last.y + in1.y))
		_pos = _path[0]
		_seg = 1
		_perch_i = -1
		_dir = 1.0 if _path[-1].x >= _path[0].x else -1.0
		return true
	return false


## Follows the edge of the forest from p, turning with it, for about `length` metres.
func _walk(p: Vector2, heading: Vector2, length: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var q := p
	var dir := heading.normalized()
	var gone := 0.0
	var since := 0.0
	while gone < length:
		var moved := false
		for turn in [0.0, 0.3, -0.3, 0.6, -0.6, 0.9, -0.9]:
			var hd := dir.rotated(turn)
			var nq := q + hd * 0.4
			if _good(nq) and _in_view(nq):
				q = nq
				dir = hd
				moved = true
				break
		if not moved:
			break
		gone += 0.4
		since += 0.4
		if since >= 1.0:
			out.append(q)
			since = 0.0
	if since > 0.0:
		out.append(q)
	return out


## A bird: over the view, and mostly down onto the top of a block in view for a while.
func _bird_route() -> bool:
	var player: Vector3 = area.player.position
	var w: float = area.meta.size[0]
	var dir := 1.0 if randf() < 0.5 else -1.0
	var x0 := clampf(player.x - dir * 14.0, 0.3, w - 0.3)
	var x1 := clampf(player.x + dir * 14.0, 0.3, w - 0.3)
	var blocks: Array = []
	for b in area.meta.boulders:
		if absf(float(b.x) - player.x) < 9.0 and float(b.z) > player.z - 10.0 and float(b.z) < player.z + 3.0:
			blocks.append(b)
	_path.clear()
	if not blocks.is_empty() and randf() < 0.75:
		var top := _top_of(blocks.pick_random())
		var cruise := top.y + 2.2
		_path.append(Vector3(x0, cruise, top.z))
		_path.append(Vector3(top.x - dir * 2.0, top.y + 0.8, top.z))
		_path.append(top)
		_path.append(Vector3(top.x + dir * 2.5, top.y + 1.4, top.z))
		_path.append(Vector3(x1, cruise + 1.0, top.z))
		_perch_i = 2
	else:
		var z := player.z + randf_range(-8.0, 2.0)
		var high: float = area.call("ground_at", player.x, player.z) + 4.5  # over everything
		_path.append(Vector3(x0, high, z))
		_path.append(Vector3(x1, high + 0.5, z))
		_perch_i = -1
	_pos = _path[0]
	_seg = 1
	_dir = dir
	return true


## The highest point of a block, where a bird sits.
func _top_of(b: Dictionary) -> Vector3:
	var best := Vector3(b.x, area.call("ground_at", b.x, b.z), b.z)
	for i in range(-3, 4):
		for j in range(-3, 4):
			var x: float = b.x + i / 3.0 * float(b.rx) * 0.7
			var z: float = b.z + j / 3.0 * float(b.rz) * 0.7
			if not _rock(x, z):
				continue
			var h: float = area.call("ground_at", x, z)
			if h > best.y:
				best = Vector3(x, h, z)
	return best


## Too close: it turns away from you and goes, fast: back into the trees, or up and away.
func _flee(player: Vector3) -> void:
	_fleeing = true
	var away := Vector2(_pos.x - player.x, _pos.z - player.z).normalized()
	_path.clear()
	if _kind == "bird":
		_dir = 1.0 if away.x >= 0.0 else -1.0
		_path.append(_pos + Vector3(_dir * 3.0, 1.5, 0.0))
		_path.append(_pos + Vector3(_dir * 14.0, 4.0, 0.0))
		_state = "leave"
		_perch_i = -1
	else:
		var into := (away + _to_forest(Vector2(_pos.x, _pos.z))).normalized()
		_path.append(_pos + Vector3(into.x, 0.0, into.y) * 7.0)
		if _kind == "fox":
			_state = "trot"
	_seg = 0


func _leave() -> void:
	if _mesh:
		_mesh.queue_free()
	_mesh = null
	_kind = ""
	_next = randf_range(20.0, 55.0)


# ---------------------------------------------------------------- how each one moves
## Along the path by `dist` metres; a bird's height goes along with it.
func _advance(dist: float) -> void:
	while dist > 0.0 and _seg < _path.size():
		var to := _path[_seg]
		var d := to - _pos
		if _kind != "bird":
			d.y = 0.0
		if absf(d.x) > 0.05:
			_dir = signf(d.x)
		var length := d.length()
		if length <= dist:
			_pos = Vector3(to.x, to.y if _kind == "bird" else _pos.y, to.z)
			dist -= length
			_seg += 1
		else:
			_pos += d * (dist / length)
			dist = 0.0


func _rabbit(delta: float) -> void:
	var fast := 2.6 if _fleeing else 1.0
	match _state:
		"sit":
			_pose(_rest_pose)
			_lift = 0.0
			_wait -= delta * fast
			if _wait <= 0.0:
				_state = "hop"
				_t = 0.0
		"hop":
			var hop_t := 0.3 / fast
			var k := minf(_t / hop_t, 1.0)
			_advance(0.55 / hop_t * delta)
			_lift = sin(k * PI) * 0.12
			_pose("crouch" if k < 0.25 or k > 0.85 else "air")  # push off, fly, land
			if k >= 1.0:
				_state = "sit"
				# mostly a short pause, sometimes a long sit up, looking around
				var long := randf() < 0.15 and not _fleeing
				_wait = 0.05 if _fleeing else (randf_range(1.5, 3.5) if long else randf_range(0.2, 0.8))
				_rest_pose = "alert" if long else "sit"


func _fox(delta: float) -> void:
	match _state:
		"trot":
			_advance(float(KINDS.fox.speed) * (2.2 if _fleeing else 1.0) * delta)
			_pose("trot_a" if int(_t / (0.07 if _fleeing else 0.14)) % 2 == 0 else "trot_b")
			if not _fleeing and randf() < delta * 0.12:
				_state = "stop"  # stops to sniff or look around, then goes on
				_wait = randf_range(0.8, 1.6)
				_rest_pose = "sniff" if randf() < 0.7 else "stand"
		"stop":
			_pose(_rest_pose)
			_wait -= delta
			if _wait <= 0.0:
				_state = "trot"


func _bird(delta: float) -> void:
	var speed: float = KINDS.bird.speed
	match _state:
		"fly":
			_advance(speed * delta)
			_pose("up" if int(_t / 0.09) % 2 == 0 else "down")
			if _perch_i >= 0 and _seg > _perch_i:
				_state = "perch"
				_wait = randf_range(3.0, 6.0)
		"perch":
			var pecking := fmod(_t, 0.9) < 0.18  # a little peck now and then
			_pose("peck" if pecking else "perch")
			_lift = 0.0
			_wait -= delta
			if _wait <= 0.0:
				_state = "leave"
				_lift = 0.0
		"leave":
			_advance(speed * (1.4 if _fleeing else 1.0) * delta)
			_pose("up" if int(_t / 0.07) % 2 == 0 else "down")


# ---------------------------------------------------------------- drawing
func _place() -> void:
	if _kind != "bird":
		_pos.y = area.call("ground_at", _pos.x, _pos.z)
	_mesh.position = _pos + Vector3(0, _lift, 0)


func _pose(name: String) -> void:
	_frame(DRAWN[name] if _drawn else STAND_IN[_kind][name])


func _frame(k: int) -> void:
	if _dir > 0.0:
		_mat.set_shader_parameter("uv_scale", Vector2(1.0 / _frames, 1))
		_mat.set_shader_parameter("uv_offset", Vector2(float(k) / _frames, 0))
	else:
		_mat.set_shader_parameter("uv_scale", Vector2(-1.0 / _frames, 1))
		_mat.set_shader_parameter("uv_offset", Vector2(float(k + 1) / _frames, 0))


func _strip(frames: Array) -> ImageTexture:
	var w: int = str(frames[0][0]).length()
	var h: int = frames[0].size()
	var img := Image.create(w * frames.size(), h, false, Image.FORMAT_RGBA8)
	for f in frames.size():
		for y in h:
			var row: String = frames[f][y]
			for x in w:
				var ch := row[x]
				if ch != ".":
					img.set_pixel(f * w + x, y, PAL[ch])
	return ImageTexture.create_from_image(img)


func _flat_normals(img: Image) -> ImageTexture:
	var n := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			n.set_pixel(x, y, Color(0.5, 0.5, 1.0, img.get_pixel(x, y).a))
	return ImageTexture.create_from_image(n)


func _cell(x: float, z: float) -> int:
	if _ground == null:
		return 1
	# the map covers the whole area, at whatever resolution it was written
	var ix := clampi(int(x / float(area.meta.size[0]) * _ground.get_width()), 0, _ground.get_width() - 1)
	var iz := clampi(int(z / float(area.meta.size[1]) * _ground.get_height()), 0, _ground.get_height() - 1)
	return _ground.get_pixel(ix, iz).r8


func _rock(x: float, z: float) -> bool:
	return _cell(x, z) == 5


func _sand(x: float, z: float) -> bool:
	var c := _cell(x, z)
	return c == 1 or c == 4


func _forest(x: float, z: float) -> bool:
	var c := _cell(x, z)
	return c == 2 or c == 3 or c == 6


## The edge of the forest: the sand right in front of the trees. In among them the plants
## would hide the animal; here you see it against the forest.
func _edge(p: Vector2) -> bool:
	if not _sand(p.x, p.y):
		return false
	for k in 12:
		var d := Vector2.from_angle(TAU * k / 12.0)
		if _forest(p.x + d.x * 0.3, p.y + d.y * 0.3) or _forest(p.x + d.x * 0.6, p.y + d.y * 0.6):
			return true
	return false


## The way into the forest from a spot on its edge.
func _to_forest(p: Vector2) -> Vector2:
	var sum := Vector2.ZERO
	for k in 12:
		var d := Vector2.from_angle(TAU * k / 12.0)
		for r in [0.3, 0.6, 1.2]:
			if _forest(p.x + d.x * r, p.y + d.y * r):
				sum += d / r
				break
	return sum.normalized() if sum.length() > 0.01 else Vector2(0, -1)


## Somewhere an animal may go: on the edge of the forest, inside the map, in sight of the
## camera, not by a block or in front of one, not by people or the camp.
func _good(p: Vector2) -> bool:
	var w: float = area.meta.size[0]
	var d: float = area.meta.size[1]
	if p.x < 1.0 or p.y < 1.0 or p.x > w - 1.0 or p.y > d - 1.0 or not _edge(p):
		return false
	if _to_forest(p).y > 0.6:
		return false  # the trees would stand between it and the camera
	for k in 12:
		var dir := Vector2.from_angle(TAU * k / 12.0)
		for r in [0.75, 1.5]:
			if _rock(p.x + dir.x * r, p.y + dir.y * r):
				return false
	# not in front of a block (the camera looks from the south): no rock in the 4 m north
	for k in range(1, 9):
		for ox in [-0.8, 0.0, 0.8]:
			if _rock(p.x + ox, p.y - k * 0.5):
				return false
	for q in _people:
		if p.distance_to(q) < 3.0:
			return false
	return not _hidden(p.x, p.y)


## In view: beside you, behind you up to where the picture gets too blurred, or just in front.
func _in_view(p: Vector2) -> bool:
	var player: Vector3 = area.player.position
	return absf(p.x - player.x) < 10.0 and p.y > player.z - 9.0 and p.y < player.z + 2.5


## A block between this spot and the camera (which looks from the south, from +z).
func _hidden(x: float, z: float) -> bool:
	for k in 8:
		if _rock(x, z + 0.5 + k * 0.5):
			return true
	return false
