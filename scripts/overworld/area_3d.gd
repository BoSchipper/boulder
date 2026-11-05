extends Node3D
## The walking world in HD-2D: a clearing in Font built from the files that
## tools/overworld/export_area.py writes. Smooth ground and blocks with pixel textures, trees
## you walk around, tufts of grass as sprites, sun and sky that change with the time of day,
## and depth of field around you. At a block with a name you can start to climb.

const TERRAIN := preload("res://shaders/overworld/terrain.gdshader")
const SPRITE := preload("res://shaders/overworld/sprite.gdshader")
const GRADE := preload("res://shaders/climb/grade.gdshader")
const CLIMB := preload("res://scripts/movetest/test_cairn.gd")
const TOPO := preload("res://scripts/overworld/topo.gd")
const TEXEL := 0.055  # metres per pixel of every sprite: people, plants and props, as the ground
const GODRAYS := preload("res://shaders/overworld/godrays.gdshader")
const UI_DIR := "res://assets/ui/"
const TITLE_SCENE := "res://scenes/title.tscn"
const CAM_FOV := 30.0  # narrow and far away: a miniature, the diorama look
const CAM_OFFSET := Vector3(0, 11.75, 19.1)
const CAM_LOOK := Vector3(0, 1.3, -5.5)
# Sun direction (towards the sun), sun colour, sky fill and the grade per time of day.
# The day: per time the sun direction (towards it; at night the moon), its colour, the sky
# fill, haze and grade, and the hour it is at its fullest. In between they blend.
const LOOKS := {
	"ochtend": {"hour": 8.0, "sun": Vector3(0.8, 0.42, 0.3), "sun_c": Color(1.25, 1.08, 0.88), "amb": Color(0.32, 0.38, 0.5),
		"haze": Color(0.82, 0.84, 0.88), "sky": Color(0.6, 0.72, 0.9), "ground": Color(0.15, 0.2, 0.22),
		"sat": 1.15, "glow": 0.6, "fog": 0.0045, "vol": 0.0012, "rays": 0.2, "label": "Morning"},
	"middag": {"hour": 13.0, "sun": Vector3(-0.35, 0.86, 0.38), "sun_c": Color(1.2, 1.12, 0.96), "amb": Color(0.34, 0.44, 0.58),
		"haze": Color(0.66, 0.8, 0.86), "sky": Color(0.55, 0.72, 0.92), "ground": Color(0.16, 0.26, 0.24),
		"sat": 1.25, "glow": 0.5, "fog": 0.003, "vol": 0.0, "rays": 0.07, "label": "Midday"},
	"avond": {"hour": 19.0, "sun": Vector3(-0.86, 0.26, 0.2), "sun_c": Color(1.7, 1.0, 0.55), "amb": Color(0.24, 0.22, 0.36),
		"haze": Color(0.95, 0.64, 0.46), "sky": Color(0.62, 0.5, 0.62), "ground": Color(0.14, 0.1, 0.14),
		"sat": 1.1, "glow": 1.0, "fog": 0.0025, "vol": 0.0015, "rays": 0.17, "label": "Evening"},
	"nacht": {"hour": 23.0, "sun": Vector3(0.45, 0.8, 0.4), "sun_c": Color(0.22, 0.28, 0.52), "amb": Color(0.06, 0.07, 0.15),
		"haze": Color(0.1, 0.12, 0.22), "sky": Color(0.04, 0.05, 0.12), "ground": Color(0.02, 0.02, 0.05),
		"sat": 0.9, "glow": 1.3, "fog": 0.005, "vol": 0.0, "rays": 0.0, "label": "Night"},
}
const DAY_ORDER := ["ochtend", "middag", "avond", "nacht"]
const HOURS_PER_SECOND := 1.0 / 40.0  # a game hour in 40 seconds: a day in a quarter of an hour

@export var area_dir := "res://assets/overworld/bas_cuvier/"  # what export_area.py or export_sables.py wrote

var meta: Dictionary
var heights: PackedFloat32Array
var grid := Vector2i.ZERO
var cell := 0.065
var time := "middag"  # the time of day closest to the clock
var hour := 13.0
var player := CharacterBody3D.new()
var camera := Camera3D.new()
var sun := DirectionalLight3D.new()
var env := Environment.new()
var _sky := ProceduralSkyMaterial.new()
var _player_mat: ShaderMaterial
var _player_blob: MeshInstance3D
var _blob_mat: StandardMaterial3D
var _flies := GPUParticles3D.new()
var _ui := CanvasLayer.new()
var _title := Label.new()
var _subtitle := Label.new()
var _prompt := PanelContainer.new()
var _prompt_name := Label.new()
var _prompt_hint := Label.new()
var _fade := ColorRect.new()
var _near: Dictionary = {}  # what you stand next to: a block, a person, the sign
var _topo_data := {}  # the area's topo (topo.json), if it has one
var _topo: CanvasLayer
var _menu: MenuLayer
var _notice := Label.new()  # a short line at the top: something new in your topo
var _news := ""
var _talkers: Array = []
var _talk: Dictionary = {}
var _talk_line := 0
var _speech := PanelContainer.new()
var _speech_name := Label.new()
var _speech_text := Label.new()
var _fire_light: OmniLight3D
var _flames: Sprite3D
var _fire_base: MeshInstance3D
var _sparks: GPUParticles3D
var _trees: TreeBuilder
var _npc_anims: Array = []  # [material, frames, phase] of everyone who breathes, blinks or wags
var _motes := GPUParticles3D.new()
var _needles := GPUParticles3D.new()
var _smoke: GPUParticles3D
var _rays_mat: ShaderMaterial
var _speech_plate := PanelContainer.new()
var _title_marks: Array[TextureRect] = []
var _typing: Tween
var _walk := 0.0
var _view := 0
var _flip := false
var _climb: MoveTest
var _climb_layer := CanvasLayer.new()
var _busy := false


func _ready() -> void:
	# The world is drawn at full window size; the pixel art is in the textures. The UI keeps
	# its 480 x 270 layout.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	meta = JSON.parse_string(FileAccess.get_file_as_string(area_dir + "area.json"))
	grid = Vector2i(meta.grid[0], meta.grid[1])
	cell = meta.cell
	heights = FileAccess.get_file_as_bytes(area_dir + "height.bin").to_float32_array()
	if FileAccess.file_exists(area_dir + "topo.json"):
		_topo_data = JSON.parse_string(FileAccess.get_file_as_string(area_dir + "topo.json"))
	_build_ground()
	_build_trees()
	_build_edges()
	_build_plants()
	_build_details()
	_build_props()
	_build_camp()
	_build_player()
	_build_light()
	_build_air()
	_build_ui()
	_set_time(time)
	_apply_graphics()
	Game.settings_changed.connect(_apply_graphics)
	_show_title()


func _exit_tree() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT


## The height of the ground (or the top of a block) at x, z, in metres.
func ground_at(x: float, z: float) -> float:
	var gx := clampf(x / cell, 0.0, grid.x - 1.001)
	var gz := clampf(z / cell, 0.0, grid.y - 1.001)
	var ix := int(gx)
	var iz := int(gz)
	var fx := gx - ix
	var fz := gz - iz
	var a := heights[iz * grid.x + ix]
	var b := heights[iz * grid.x + ix + 1]
	var c := heights[(iz + 1) * grid.x + ix]
	var d := heights[(iz + 1) * grid.x + ix + 1]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


func _build_ground() -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.resize(grid.x * grid.y)
	normals.resize(grid.x * grid.y)
	for z in grid.y:
		for x in grid.x:
			var i := z * grid.x + x
			verts[i] = Vector3(x * cell, heights[i], z * cell)
			var hl := heights[z * grid.x + maxi(x - 1, 0)]
			var hr := heights[z * grid.x + mini(x + 1, grid.x - 1)]
			var hd := heights[maxi(z - 1, 0) * grid.x + x]
			var hu := heights[mini(z + 1, grid.y - 1) * grid.x + x]
			normals[i] = Vector3(hl - hr, 2.0 * cell, hd - hu).normalized()
	var idx := PackedInt32Array()
	idx.resize((grid.x - 1) * (grid.y - 1) * 6)
	var k := 0
	for z in grid.y - 1:
		for x in grid.x - 1:
			var i := z * grid.x + x
			idx[k] = i; idx[k + 1] = i + 1; idx[k + 2] = i + grid.x
			idx[k + 3] = i + 1; idx[k + 4] = i + grid.x + 1; idx[k + 5] = i + grid.x
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN
	mat.set_shader_parameter("ground_map", load(area_dir + "ground.png"))
	mat.set_shader_parameter("atlas", load(area_dir + "ground_atlas.png"))
	# The foot of each block (Les Sables d'Or knows them), where the sandstone is damp and dark.
	var bases := PackedFloat32Array()
	bases.resize(8)
	var known := false
	for b in meta.boulders:
		if b.has("idx") and int(b.idx) < 8:
			bases[int(b.idx)] = float(b.base_y)
			known = true
	mat.set_shader_parameter("block_base", bases)
	mat.set_shader_parameter("has_blocks", known)
	var clumps := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.frequency = 0.08
	clumps.noise = fn
	clumps.seamless = true
	mat.set_shader_parameter("clumps", clumps)
	mat.set_shader_parameter("world_size", Vector2(meta.size[0], meta.size[1]))
	mat.set_shader_parameter("texel", meta.texel)
	mat.set_shader_parameter("tile_px", float(meta.get("tile", 32)))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	# The forest floor goes on past the edge of the map, under the trees around it: a skirt
	# at the height of the edge, outside the map only. (A flat floor under everything stood
	# higher than the low sand in places, and hid the feet of whoever stood there.)
	var outer := MeshInstance3D.new()
	outer.mesh = _skirt()
	outer.material_override = mat
	add_child(outer)
	# Collision: the same heights. The blocks are too steep to walk up.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = grid.x
	hm.map_depth = grid.y
	var scaled := PackedFloat32Array()
	scaled.resize(heights.size())
	for i in heights.size():
		scaled[i] = heights[i] / cell
	hm.map_data = scaled
	shape.shape = hm
	shape.scale = Vector3.ONE * cell
	shape.position = Vector3((grid.x - 1) * cell / 2.0, 0, (grid.y - 1) * cell / 2.0)
	body.add_child(shape)
	add_child(body)


## The ground's edge pulled straight out, FAR metres on every side, each point at the height
## of the edge where it starts; the corners at the height of the corner.
func _skirt() -> ArrayMesh:
	const FAR := 80.0
	var verts := PackedVector3Array()
	var w := grid.x - 1
	var d := grid.y - 1
	var tri := func(a: Vector3, b: Vector3, c: Vector3) -> void:
		# always facing up, whichever side of the map: the back of a face is not drawn
		verts.append_array([a, c, b] if (b - a).cross(c - a).y > 0.0 else [a, b, c])
	var quad := func(a: Vector3, b: Vector3, c: Vector3, e: Vector3) -> void:
		tri.call(a, b, c)
		tri.call(b, e, c)
	for x in w:
		for side in [[0, -FAR], [d, FAR]]:
			var z0: float = side[0] * cell
			var a := Vector3(x * cell, heights[side[0] * grid.x + x], z0)
			var b := Vector3((x + 1) * cell, heights[side[0] * grid.x + x + 1], z0)
			quad.call(a, b, Vector3(a.x, a.y, z0 + side[1]), Vector3(b.x, b.y, z0 + side[1]))
	for z in d:
		for side in [[0, -FAR], [w, FAR]]:
			var x0: float = side[0] * cell
			var a := Vector3(x0, heights[z * grid.x + side[0]], z * cell)
			var b := Vector3(x0, heights[(z + 1) * grid.x + side[0]], (z + 1) * cell)
			quad.call(a, b, Vector3(x0 + side[1], a.y, a.z), Vector3(x0 + side[1], b.y, b.z))
	for corner in [[0, 0, -FAR, -FAR], [w, 0, FAR, -FAR], [0, d, -FAR, FAR], [w, d, FAR, FAR]]:
		var c := Vector3(corner[0] * cell, heights[corner[1] * grid.x + corner[0]], corner[1] * cell)
		quad.call(c, c + Vector3(corner[2], 0, 0), c + Vector3(0, 0, corner[3]), c + Vector3(corner[2], 0, corner[3]))
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A ring of invisible walls just inside the tree line: the edge of the clearing.
func _build_edges() -> void:
	var w: float = meta.size[0]
	var d: float = meta.size[1]
	for wall in [[Vector3(-0.2, 2, d / 2), Vector3(0.4, 6, d)], [Vector3(w + 0.2, 2, d / 2), Vector3(0.4, 6, d)],
			[Vector3(w / 2, 2, -0.2), Vector3(w, 6, 0.4)], [Vector3(w / 2, 2, d - 0.3), Vector3(w, 6, 0.4)]]:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wall[1]
		shape.shape = box
		body.position = wall[0]
		body.add_child(shape)
		add_child(body)


func _build_trees() -> void:
	_trees = TreeBuilder.new()
	var builder := _trees
	for t in meta.trees:
		var x: float = t[1]
		var z: float = t[2]
		var inside: bool = x > 0 and z > 0 and x < meta.size[0] and z < meta.size[1]
		var g := ground_at(x, z) if inside else 0.7
		add_child(builder.build(t[0], Vector3(x, g - 0.1, z), t[3], int(t[4]), inside))


## Tufts of grass, bracken and heather: one multimesh per variant, billboards that face you.
func _build_plants() -> void:
	var tex: Texture2D = load(area_dir + "tufts.png")
	var nrm: Texture2D = load(area_dir + "tufts_n.png")
	var count := 18
	var w: float = tex.get_width() / float(count) * meta.texel
	var h: float = tex.get_height() * meta.texel
	var per := []
	for i in count:
		per.append([])
	for p in meta.plants:
		per[int(p[2])].append(Vector3(p[0], 0, p[1]))
	for i in count:
		var quad := QuadMesh.new()
		quad.size = Vector2(w, h)
		quad.center_offset = Vector3(0, h / 2.0, 0)
		var mat := _sprite_material(tex, nrm)
		mat.set_shader_parameter("uv_scale", Vector2(1.0 / count, 1))
		mat.set_shader_parameter("uv_offset", Vector2(float(i) / count, 0))
		mat.set_shader_parameter("sway", 0.05)  # grass and bracken move in the wind
		quad.material = mat
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = quad
		mm.instance_count = per[i].size()
		for k in per[i].size():
			var at: Vector3 = per[i][k]
			at.y = ground_at(at.x, at.z) - 0.02
			mm.set_instance_transform(k, Transform3D(Basis(), at))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


func _sprite_material(tex: Texture2D, nrm: Texture2D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SPRITE
	mat.set_shader_parameter("albedo_tex", tex)
	mat.set_shader_parameter("normal_tex", nrm)
	var to_cam := CAM_OFFSET - CAM_LOOK
	mat.set_shader_parameter("cam_back", Vector3(to_cam.x, 0.0, to_cam.z).normalized())
	return mat


## A soft dark patch on the ground under someone's feet: they stand on the ground, not above it.
func _blob(at: Vector3, width: float) -> MeshInstance3D:
	if _blob_mat == null:
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(0.5, 0.0)
		g.width = 32
		g.height = 32
		var grad := Gradient.new()
		grad.colors = PackedColorArray([Color(0.08, 0.05, 0.1, 0.55), Color(0.08, 0.05, 0.1, 0.0)])
		g.gradient = grad
		_blob_mat = StandardMaterial3D.new()
		_blob_mat.albedo_texture = g
		_blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blob_mat.render_priority = -1
	var plane := PlaneMesh.new()
	plane.size = Vector2(width, width * 0.55)
	plane.material = _blob_mat
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at + Vector3(0, 0.03, 0)
	add_child(mi)
	return mi


## Other climbers, and crash pads in front of the blocks.
func _build_props() -> void:
	for n in meta.npcs:
		var tex: Texture2D = load(area_dir + n.sprite + ".png")
		var frames: int = n.get("frames", 1)
		var q := QuadMesh.new()
		q.size = Vector2(tex.get_width() / float(frames), tex.get_height()) * n.get("texel", TEXEL)
		q.center_offset = Vector3(0, q.size.y / 2.0, 0)
		var mat := _sprite_material(tex, load(area_dir + n.sprite + "_n.png"))
		if frames > 1:
			mat.set_shader_parameter("uv_scale", Vector2(1.0 / frames, 1))
			_npc_anims.append([mat, frames, randf() * 10.0])
		q.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.position = Vector3(n.x, ground_at(n.x, n.z) + n.lift, n.z)
		add_child(mi)
		if n.lift == 0:
			_blob(Vector3(n.x, ground_at(n.x, n.z), n.z), q.size.x * 0.55)
		if n.has("lines"):
			_talkers.append(n)
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.3
			cyl.height = 1.6
			shape.shape = cyl
			shape.position.y = 0.8
			body.add_child(shape)
			mi.add_child(body)
	var colours := [Color("b85a46"), Color("40608c")]
	for p in meta.pads:
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 0.12, 1.3)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colours[int(p[2])]
		mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		box.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.position = Vector3(p[0] + 0.6, ground_at(p[0] + 0.6, p[1]) + 0.06, p[1])
		add_child(mi)


## Your tent, the camp fire with its light, a blanket; the sign; the closed path.
func _build_camp() -> void:
	if meta.has("camp"):
		var c: Dictionary = meta.camp
		var tent_at := Vector3(c.tent[0], ground_at(c.tent[0], c.tent[1]), c.tent[1])
		_prop("tent", tent_at, Vector3(1.9, 1.3, 1.4))
		_fire(Vector3(c.fire[0], ground_at(c.fire[0], c.fire[1]), c.fire[1]))
		_prop("blanket", Vector3(c.blanket[0], ground_at(c.blanket[0], c.blanket[1]) + 0.02, c.blanket[1]), Vector3.ZERO, true)
	if meta.has("sign"):
		var sg: Dictionary = meta.sign
		var at := Vector3(sg.x, ground_at(sg.x, sg.z), sg.z)
		_prop("sign", at, Vector3(0.3, 1.0, 0.3))
		_talkers.append({"name": "Sign", "x": sg.x, "z": sg.z, "lines": [sg.text.replace("\n", "  ·  ") + "\nYour topo shows every block of the circuit." + _topo_key()], "verb": "Read"})
	if meta.has("gate"):
		var gt: Dictionary = meta.gate
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(gt.w, 3.0, gt.d)
		shape.shape = bs
		body.position = Vector3(gt.x, ground_at(gt.x, gt.z) + 1.5, gt.z)
		body.add_child(shape)
		add_child(body)
		for dz in [-gt.d / 2.0, gt.d / 2.0]:
			var post := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.12, 1.1, 0.12)
			pm.material = _flat(Color("6a4a30"))
			post.mesh = pm
			post.position = Vector3(gt.x, ground_at(gt.x, gt.z + dz) + 0.55, gt.z + dz)
			add_child(post)
		var bar := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(0.08, 0.1, gt.d)
		bb.material = _flat(Color("d8c6a0"))
		bar.mesh = bb
		bar.position = Vector3(gt.x, ground_at(gt.x, gt.z) + 0.9, gt.z)
		add_child(bar)


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	return m


## A drawn prop standing in the world (or lying flat), with a box you bump into.
func _prop(name: String, at: Vector3, solid: Vector3, flat := false) -> MeshInstance3D:
	var tex: Texture2D = load(area_dir + name + ".png")
	var q := QuadMesh.new()
	q.size = Vector2(tex.get_width(), tex.get_height()) * TEXEL
	var mat := _sprite_material(tex, load(area_dir + name + "_n.png"))
	mat.set_shader_parameter("billboard", false)
	q.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = q
	if flat:
		mi.rotation.x = -PI / 2
		mi.position = at
	else:
		q.center_offset = Vector3(0, q.size.y / 2.0, 0)
		mi.position = at
	add_child(mi)
	if solid != Vector3.ZERO:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = solid
		shape.shape = bs
		body.position = at + Vector3(0, solid.y / 2.0, -solid.z / 2.0)
		body.add_child(shape)
		add_child(body)
	return mi


## The camp fire: a ring of stones and logs, drawn flames that flicker, sparks and light.
func _fire(at: Vector3) -> void:
	_fire_base = _prop("fire_base", at + Vector3(0, 0, 0.05), Vector3(0.9, 0.3, 0.6))
	_flames = Sprite3D.new()
	_flames.texture = load(area_dir + "flames.png")
	_flames.hframes = 6
	_flames.pixel_size = TEXEL
	_flames.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_flames.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_flames.shaded = false
	_flames.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_flames.modulate = Color(1.6, 1.4, 1.2)  # bright enough to glow
	_flames.position = at + Vector3(0, 1.25, 0.08)  # standing on the crossed logs, not hiding them
	add_child(_flames)
	var sparks := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, 0.3, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.2
	sparks.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.7, 0.3)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.6, 0.2)
	fm.emission_energy_multiplier = 6.0
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = fm
	sparks.draw_pass_1 = q
	sparks.amount = 24
	sparks.lifetime = 1.6
	sparks.position = at + Vector3(0, 0.6, 0)
	add_child(sparks)
	_sparks = sparks
	_smoke = _puffs(at + Vector3(0, 0.9, 0))
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.6, 0.3)
	_fire_light.omni_range = 7.5
	_fire_light.omni_attenuation = 2.2  # fades out before the edge, no hard disc of light
	_fire_light.shadow_enabled = true
	_fire_light.position = at + Vector3(0, 0.8, 0.3)
	add_child(_fire_light)
	_talkers.append({"name": "Campfire", "x": at.x, "z": at.z, "lines": ["The fire crackles.\nTonight you sleep here, by your tent."], "verb": "Look"})


func _build_player() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	shape.shape = cap
	shape.position.y = 0.8
	player.add_child(shape)
	var tex: Texture2D = load(area_dir + "player.png")
	var frame: Array = meta.player.frame
	var q := QuadMesh.new()
	q.size = Vector2(frame[0], frame[1]) * meta.player.get("texel", TEXEL)
	q.center_offset = Vector3(0, q.size.y / 2.0, 0)
	_player_mat = _sprite_material(tex, load(area_dir + "player_n.png"))
	q.material = _player_mat
	var mi := MeshInstance3D.new()
	mi.mesh = q
	player.add_child(mi)
	_player_blob = _blob(Vector3.ZERO, q.size.x * 0.55)
	player.floor_max_angle = deg_to_rad(42)
	player.position = Vector3(meta.player.x, ground_at(meta.player.x, meta.player.z) + 0.1, meta.player.z)
	add_child(player)
	camera.fov = CAM_FOV
	add_child(camera)
	camera.position = player.position + CAM_OFFSET
	camera.look_at(player.position + CAM_LOOK)
	camera.attributes = CameraAttributesPractical.new()
	_set_frame()


func _build_light() -> void:
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_blur = 0.6
	add_child(sun)
	var sky := Sky.new()
	sky.sky_material = _sky
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_sky_affect = 0.4
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.6
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# Fireflies over the grass, at dusk.
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(meta.size[0] / 2.0, 0.8, meta.size[1] / 2.0)
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.2
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	_flies.process_material = pm
	var dot := QuadMesh.new()
	dot.size = Vector2(0.06, 0.06)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.85, 0.35)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.8, 0.3)
	glow.emission_energy_multiplier = 6.0
	glow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dot.material = glow
	_flies.draw_pass_1 = dot
	_flies.amount = 90
	_flies.lifetime = 8.0
	_flies.position = Vector3(meta.size[0] / 2.0, 1.4, meta.size[1] / 2.0)
	_flies.visibility_aabb = AABB(Vector3(-20, -3, -20), Vector3(40, 6, 40))
	add_child(_flies)


## Jump to a time of day; the clock runs on from there.
func _set_time(which: String) -> void:
	hour = LOOKS[which].hour
	_apply_hour()


## The light of the hour on the clock: between two times of day, blended.
func _apply_hour() -> void:
	var keys: Array = []
	for name in DAY_ORDER:
		keys.append([LOOKS[name].hour, name])
	keys.append([LOOKS.ochtend.hour + 24.0, "ochtend"])
	var h := hour if hour >= LOOKS.ochtend.hour else hour + 24.0
	var a: Array = keys[0]
	var b: Array = keys[1]
	for k in keys.size() - 1:
		if h >= keys[k][0] and h <= keys[k + 1][0]:
			a = keys[k]
			b = keys[k + 1]
	var t: float = (h - a[0]) / (b[0] - a[0])
	t = t * t * (3.0 - 2.0 * t)
	var la: Dictionary = LOOKS[a[1]]
	var lb: Dictionary = LOOKS[b[1]]
	time = a[1] if t < 0.5 else b[1]
	var dir := (la.sun as Vector3).lerp(lb.sun, t).normalized()
	sun.look_at_from_position(Vector3.ZERO, -dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	var c := (la.sun_c as Color).lerp(lb.sun_c, t)
	var energy := maxf(c.r, maxf(c.g, c.b))
	sun.light_color = Color(c.r / energy, c.g / energy, c.b / energy)
	sun.light_energy = energy
	sun.light_volumetric_fog_energy = 2.0
	env.ambient_light_color = (la.amb as Color).lerp(lb.amb, t)
	env.ambient_light_energy = 1.0
	var haze := (la.haze as Color).lerp(lb.haze, t)
	_sky.sky_top_color = (la.sky as Color).lerp(lb.sky, t)
	_sky.sky_horizon_color = haze
	_sky.ground_horizon_color = haze
	_sky.ground_bottom_color = (la.ground as Color).lerp(lb.ground, t)
	env.fog_light_color = haze
	env.fog_density = lerpf(la.fog, lb.fog, t)
	env.glow_intensity = lerpf(la.glow, lb.glow, t)
	env.adjustment_saturation = lerpf(la.sat, lb.sat, t)
	var vol := lerpf(la.vol, lb.vol, t)
	env.volumetric_fog_enabled = vol > 0.0002 and not Game.graphics_low
	env.volumetric_fog_density = vol
	env.volumetric_fog_albedo = haze * 0.7
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 40.0
	# Fireflies and the camp fire come with the dark.
	var dark := hour >= 18.5 or hour < 5.5
	_flies.emitting = dark
	_flies.visible = dark
	_motes.emitting = not dark
	_needles.emitting = not dark
	if _rays_mat:
		_rays_mat.set_shader_parameter("sun_dir", dir)
		_rays_mat.set_shader_parameter("color", sun.light_color)
		_rays_mat.set_shader_parameter("intensity", lerpf(la.get("rays", 0.0), lb.get("rays", 0.0), t))
	_subtitle.text = "%s  ·  %s" % [meta.get("subtitle", "Fontainebleau"), LOOKS[time].label]
	if _fire_light and _fire_light.visible != dark:
		_fire_light.visible = dark
		_flames.visible = dark
		_sparks.emitting = dark
		_sparks.visible = dark
		_smoke.emitting = dark
		var mat: ShaderMaterial = (_fire_base.mesh as QuadMesh).material
		mat.set_shader_parameter("albedo_tex", load(area_dir + ("fire_lit.png" if dark else "fire_base.png")))


## Small things lying on the ground: pebbles and twigs on the sand, pine cones and needles
## under the pines. One flat multimesh per kind.
func _build_details() -> void:
	if not FileAccess.file_exists(area_dir + "details.png"):
		return
	var tex: Texture2D = load(area_dir + "details.png")
	var nrm: Texture2D = load(area_dir + "details_n.png")
	var kinds := 6
	var ground: Image = load(area_dir + "ground.png").get_image()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var per: Array = []
	for k in kinds:
		per.append([])
	var w: float = meta.size[0]
	var d: float = meta.size[1]
	# which kinds go where: sand (1) and path (4): pebbles, twig, flat stone; needles (2): cone, needles, twig
	var on := {1: [0, 2, 4, 3], 4: [0, 4], 2: [1, 5, 2]}
	for i in 1400:
		var x := rng.randf_range(0.5, w - 0.5)
		var z := rng.randf_range(0.5, d - 0.5)
		var id := int(round(ground.get_pixel(int(x / w * ground.get_width()), int(z / d * ground.get_height())).r * 255.0))
		if not on.has(id) or rng.randf() > 0.35:
			continue
		var choice: Array = on[id]
		per[choice[rng.randi() % choice.size()]].append(Vector3(x, 0, z))
	var size := Vector2(tex.get_width() / float(kinds), tex.get_height()) * TEXEL
	for k in kinds:
		var quad := QuadMesh.new()
		quad.size = size
		quad.orientation = PlaneMesh.FACE_Y  # lying on the ground
		var mat := _sprite_material(tex, nrm)
		mat.set_shader_parameter("billboard", false)
		mat.set_shader_parameter("uv_scale", Vector2(1.0 / kinds, 1))
		mat.set_shader_parameter("uv_offset", Vector2(float(k) / kinds, 0))
		quad.material = mat
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = quad
		mm.instance_count = per[k].size()
		for j in per[k].size():
			var at: Vector3 = per[k][j]
			at.y = ground_at(at.x, at.z) + 0.02
			mm.set_instance_transform(j, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


## The air: motes glinting in the sun around you, needles drifting down, and shafts of light
## falling through the trees (strongest in the morning and the evening).
func _build_air() -> void:
	var glint := StandardMaterial3D.new()
	glint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glint.vertex_color_use_as_albedo = true
	glint.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glint.albedo_color = Color(1.0, 0.92, 0.75)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(8.0, 1.6, 6.0)
	pm.gravity = Vector3(0, 0.02, 0)
	pm.initial_velocity_min = 0.03
	pm.initial_velocity_max = 0.12
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.3
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	_motes.process_material = pm
	var dot := QuadMesh.new()
	dot.size = Vector2(0.035, 0.035)
	dot.material = glint
	_motes.draw_pass_1 = dot
	_motes.amount = 70
	_motes.lifetime = 7.0
	_motes.preprocess = 7.0
	_motes.local_coords = false
	_motes.visibility_aabb = AABB(Vector3(-10, -3, -8), Vector3(20, 6, 16))
	add_child(_motes)
	# needles and the odd leaf, drifting and turning on their way down
	var npm := ParticleProcessMaterial.new()
	npm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	npm.emission_box_extents = Vector3(9.0, 0.5, 7.0)
	npm.gravity = Vector3(0.15, -0.35, 0)
	npm.initial_velocity_min = 0.0
	npm.initial_velocity_max = 0.1
	npm.angle_min = 0.0
	npm.angle_max = 360.0
	npm.angular_velocity_min = -90.0
	npm.angular_velocity_max = 90.0
	npm.turbulence_enabled = true
	npm.turbulence_noise_strength = 0.5
	npm.color = Color(0.62, 0.44, 0.26)
	_needles.process_material = npm
	var needle := QuadMesh.new()
	needle.size = Vector2(0.11, 0.035)
	var nmat := StandardMaterial3D.new()
	nmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nmat.vertex_color_use_as_albedo = true
	nmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	needle.material = nmat
	_needles.draw_pass_1 = needle
	_needles.amount = 16
	_needles.lifetime = 14.0
	_needles.preprocess = 14.0
	_needles.local_coords = false
	_needles.visibility_aabb = AABB(Vector3(-10, -8, -8), Vector3(20, 10, 16))
	add_child(_needles)
	# shafts of light, scattered over the area
	_rays_mat = ShaderMaterial.new()
	_rays_mat.shader = GODRAYS
	var streaks := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	streaks.noise = fn
	streaks.seamless = true
	streaks.width = 128
	streaks.height = 32
	_rays_mat.set_shader_parameter("streaks", streaks)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 9:
		var x := rng.randf_range(2.0, meta.size[0] - 2.0)
		var z := rng.randf_range(2.0, meta.size[1] - 2.0)
		var q := QuadMesh.new()
		q.material = _rays_mat
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 12.0  # the shader stretches the quad far beyond its own size
		var length := rng.randf_range(8.0, 12.0)
		mi.position = Vector3(x, ground_at(x, z) + length * 0.45, z)
		mi.set_instance_shader_parameter("size", Vector2(rng.randf_range(1.4, 2.6), length))
		mi.set_instance_shader_parameter("phase", rng.randf() * 10.0)
		add_child(mi)


## Soft grey puffs rising from the fire and spreading as they go.
func _puffs(at: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.35
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0.08, 0.05, 0)
	pm.scale_min = 0.6
	pm.scale_max = 0.9
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.6))
	var gt := CurveTexture.new()
	gt.curve = grow
	pm.scale_curve = gt
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var puff := QuadMesh.new()
	puff.size = Vector2(0.5, 0.5)
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.62, 0.6, 0.62, 1), Color(0.62, 0.6, 0.62, 0)])
	soft.gradient = g
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = soft
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = mat
	p.draw_pass_1 = puff
	p.amount = 12
	p.lifetime = 4.5
	p.local_coords = false
	p.position = at
	add_child(p)
	return p


# ---------------------------------------------------------------- UI
## A pixel frame from assets/ui as a stretchable panel.
func _frame_box(name: String, margin: int, inner: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(UI_DIR + name + ".png")
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.set_content_margin_all(inner)
	return sb


func _build_ui() -> void:
	var grade_layer := CanvasLayer.new()
	grade_layer.layer = 0  # over the 3D world, under the text
	var grade := ColorRect.new()
	grade.size = Vector2(480, 270)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = GRADE
	gm.set_shader_parameter("saturation", 1.0)  # the world has its own saturation per time of day
	gm.set_shader_parameter("contrast", 1.05)
	gm.set_shader_parameter("grain", 0.012)
	grade.material = gm
	grade_layer.add_child(grade)
	add_child(grade_layer)
	add_child(_ui)
	for label in [_title, _subtitle, _prompt_name, _prompt_hint]:
		label.add_theme_font_override("font", Game.font(Game.FONT_TEXT))
		label.add_theme_color_override("font_color", Color("faeed6"))
		label.add_theme_color_override("font_outline_color", Color("1c1620"))
		label.add_theme_constant_override("outline_size", 3)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", Game.font(Game.FONT_TITLE))
	_title.add_theme_font_size_override("font_size", 16)
	_title.text = meta.get("title", "BAS CUVIER")
	_title.position = Vector2(0, 22)
	_title.size = Vector2(480, 20)
	_subtitle.add_theme_font_size_override("font_size", 16)
	_subtitle.add_theme_color_override("font_color", Color("deba6e"))
	_subtitle.position = Vector2(0, 40)
	_subtitle.size = Vector2(480, 18)
	_ui.add_child(_title)
	_ui.add_child(_subtitle)
	_notice.add_theme_font_override("font", Game.font(Game.FONT_TEXT))
	_notice.add_theme_font_size_override("font_size", 16)
	_notice.add_theme_color_override("font_color", Color("faeed6"))
	_notice.add_theme_color_override("font_outline_color", Color("2b2329"))
	_notice.add_theme_constant_override("outline_size", 4)
	_notice.position = Vector2(0, 8)
	_notice.size = Vector2(480, 18)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.modulate.a = 0.0
	_ui.add_child(_notice)
	# a gold line with a diamond on either side of the area's name
	var w := Game.font(Game.FONT_TITLE).get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	for k in 2:
		var mark := TextureRect.new()
		mark.texture = load(UI_DIR + "ornament.png")
		mark.flip_h = k == 1
		mark.position = Vector2(240.0 - w / 2.0 - 46.0 if k == 0 else 240.0 + w / 2.0 + 6.0, 28)
		_ui.add_child(mark)
		_title_marks.append(mark)
	_prompt.add_theme_stylebox_override("panel", _frame_box("frame", 6, 6))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	_prompt_name.add_theme_font_size_override("font_size", 16)
	_prompt_hint.add_theme_font_size_override("font_size", 16)
	_prompt_hint.add_theme_color_override("font_color", Color("deba6e"))
	col.add_child(_prompt_name)
	col.add_child(_prompt_hint)
	_prompt.add_child(col)
	_prompt.visible = false
	_ui.add_child(_prompt)
	_fade.color = Color("f4efe6")
	_fade.size = Vector2(480, 270)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_ui.add_child(_fade)
	var sbox := _frame_box("frame", 6, 8)
	sbox.content_margin_top = 11  # room for the name plate on the edge
	_speech.add_theme_stylebox_override("panel", sbox)
	for label in [_speech_name, _speech_text]:
		label.add_theme_font_override("font", Game.font(Game.FONT_TEXT))
		label.add_theme_font_size_override("font_size", 16)
	_speech_name.add_theme_color_override("font_color", Color("f2cf3a"))
	_speech_text.add_theme_color_override("font_color", Color("faeed6"))
	_speech.add_child(_speech_text)
	_speech.position = Vector2(40, 192)
	_speech.custom_minimum_size = Vector2(400, 0)
	_speech.visible = false
	_ui.add_child(_speech)
	# who speaks: a small plate on the top edge of the box
	_speech_plate.add_theme_stylebox_override("panel", _frame_box("plate", 4, 3))
	_speech_plate.add_child(_speech_name)
	_speech_plate.position = Vector2(50, 183)
	_speech_plate.visible = false
	_ui.add_child(_speech_plate)
	add_child(_climb_layer)
	_climb_layer.layer = 10
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 20  # the fades go over the climbing screen too
	add_child(fade_layer)
	_fade.reparent(fade_layer, false)


func _show_title() -> void:
	for label in [_title, _subtitle] + _title_marks:
		label.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(label, "modulate:a", 1.0, 0.8)
		tw.tween_interval(3.0)
		tw.tween_property(label, "modulate:a", 0.0, 1.2)


# ---------------------------------------------------------------- walking
func _process(delta: float) -> void:
	if not _climb:
		hour = fmod(hour + delta * HOURS_PER_SECOND, 24.0)
		_apply_hour()
	if _fire_light and _fire_light.visible:
		_fire_light.light_energy = (2.0 if time == "avond" else 2.4) + randf() * 0.5
	if _flames:
		_flames.frame = int(Time.get_ticks_msec() / 90.0) % 6
	var t := Time.get_ticks_msec() / 1000.0
	for a in _npc_anims:
		var frames: int = a[1]
		var f := 0
		if frames == 2:  # the dog wags its tail
			f = int((t + a[2]) * 4.0) % 2
		else:  # breathing, and now and then a blink
			f = 1 if fmod(t + a[2], 2.4) > 1.2 else 0
			if frames > 2 and fmod(t * 0.9 + a[2] * 3.1, 4.3) < 0.14:
				f = 2
		(a[0] as ShaderMaterial).set_shader_parameter("uv_offset", Vector2(float(f) / frames, 0))


func _physics_process(delta: float) -> void:
	if _climb or _busy or not _talk.is_empty():
		return
	var steer := Game.steer_vector()
	var speed := 4.2 if Input.is_action_pressed("action_b") else 2.4
	var move := Vector3(steer.x, 0, steer.y) * speed
	player.velocity.x = move.x
	player.velocity.z = move.z
	player.velocity.y = 0.0 if player.is_on_floor() else player.velocity.y - 18.0 * delta
	player.move_and_slide()
	if steer.length() > 0.2:
		_walk += delta * speed * 2.2
		if absf(steer.x) > absf(steer.y):
			_view = 2
			_flip = steer.x < 0  # the side frames face right
		else:
			_view = 0 if steer.y < 0 else 1
	else:
		_walk = 0.0
	_set_frame()
	_player_blob.position = Vector3(player.position.x, ground_at(player.position.x, player.position.z) + 0.03, player.position.z)
	_motes.position = player.position + Vector3(0, 1.3, -1.5)
	_needles.position = player.position + Vector3(0, 6.0, -2.5)
	for m in _trees.materials():
		m.set_shader_parameter("player_pos", player.position + Vector3(0, 0.9, 0))
	var target := player.position + CAM_OFFSET
	camera.position = camera.position.lerp(target, 1.0 - exp(-delta * 4.0))
	camera.look_at(camera.position - CAM_OFFSET + CAM_LOOK)
	_focus()
	_check_boulders()


func _set_frame() -> void:
	var per: int = meta.player.frames_per_view
	var step: int = [0, 1, 0, 2][int(_walk) % 4]
	if _walk <= 0.0:  # standing still: breathing in and out
		step = 3 if per > 3 and fmod(Time.get_ticks_msec() / 1000.0, 2.2) > 1.1 else 0
	var frame: int = _view * per + step
	var n := 3 * per
	if _flip:
		_player_mat.set_shader_parameter("uv_scale", Vector2(-1.0 / n, 1))
		_player_mat.set_shader_parameter("uv_offset", Vector2(float(frame + 1) / n, 0))
	else:
		_player_mat.set_shader_parameter("uv_scale", Vector2(1.0 / n, 1))
		_player_mat.set_shader_parameter("uv_offset", Vector2(float(frame) / n, 0))


## Sharp where you stand, soft in front and behind: the diorama look.
func _focus() -> void:
	var attr: CameraAttributesPractical = camera.attributes
	var d := camera.position.distance_to(player.position + Vector3(0, 0.9, 0))
	attr.dof_blur_far_enabled = not Game.graphics_low
	attr.dof_blur_far_distance = d + 3.5
	attr.dof_blur_far_transition = 9.0
	attr.dof_blur_near_enabled = not Game.graphics_low
	attr.dof_blur_near_distance = d - 4.0
	attr.dof_blur_near_transition = 3.0
	attr.dof_blur_amount = 0.1


func _check_boulders() -> void:
	var found: Dictionary = {}
	var best := INF
	for t in _talkers:
		var d := Vector2(player.position.x - t.x, player.position.z - t.z).length()
		if d < 1.7 and d < best:
			best = d
			found = {"talk": t}
	if found.is_empty():
		var nearest := 1.0  # with two blocks close together, the one you stand closest to
		for b in meta.boulders:
			if b.name == "":
				continue
			var dx: float = (player.position.x - b.x) / (b.rx + 2.2)
			var dz: float = (player.position.z - b.z) / (b.rz + 2.2)
			if dx * dx + dz * dz < nearest:
				nearest = dx * dx + dz * dz
				found = b
	_near = found
	_prompt.visible = not found.is_empty()
	if _prompt.visible:
		var key := Game.button_name(JOY_BUTTON_A) if Game.using_pad else "Z"
		if found.has("talk"):
			_prompt_name.text = found.talk.name
			_prompt_hint.text = "%s  %s" % [key, found.talk.get("verb", "Talk")]
		else:
			var done := Game.is_topped(found.get("id", "marierose"))
			var entry: Dictionary = Game.logbook.get(found.get("route", "marierose"), {})
			var note := ""
			if entry.get("flash", false):
				note = "  (flash)"
			elif done:
				note = "  (top)"
			elif entry.get("attempts", 0) > 0:
				note = "  (%d %s)" % [entry.attempts, "try" if entry.attempts == 1 else "tries"]
			_prompt_name.text = found.name + note
			_prompt_hint.text = "%s  Climb     %s" % [key, found.grade]
		var screen := camera.unproject_position(player.position + Vector3(0, 2.4, 0))
		var scale := get_viewport().get_visible_rect().size / Vector2(480, 270)
		_prompt.position = screen / scale + Vector2(14, -30)


func _unhandled_input(event: InputEvent) -> void:
	if _climb or _busy:
		return
	if not _talk.is_empty():
		if event.is_action_pressed("action_a") and _speech_text.visible_ratio < 1.0:
			_typing.kill()  # still typing: show the whole line first
			_speech_text.visible_ratio = 1.0
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("action_a") or event.is_action_pressed("action_b"):
			_talk_line += 1
			if _talk_line >= _talk.lines.size() or event.is_action_pressed("action_b"):
				_talk = {}
				_speech.visible = false
				_speech_plate.visible = false
				if _news != "":
					_tell_news(_news)
					_news = ""
			else:
				_say_line(_talk.lines[_talk_line])
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("to_menu"):
		get_viewport().set_input_as_handled()
		_open_pause()
	elif event.is_action_pressed("action_c"):
		_set_time(DAY_ORDER[(DAY_ORDER.find(time) + 1) % DAY_ORDER.size()])
		_show_title()
	elif event.is_action_pressed("topo") and not _topo_data.is_empty():
		_open_topo()
	elif event.is_action_pressed("action_a") and _near.has("talk"):
		_talk = _near.talk
		_talk_line = 0
		_learn_from(_talk.name)
		_speech_name.text = _talk.name
		_speech.visible = true
		_speech_plate.visible = true
		_say_line(_talk.lines[0])
		_prompt.visible = false
		Game.sfx("Sounds/Menu/Move1.wav", -12.0)
	elif event.is_action_pressed("action_a") and not _near.is_empty():
		_start_climb()


# ---------------------------------------------------------------- the topo
## The map of the area with every block you know (see topo.gd). From it you can climb again
## any block you topped, without walking there.
func _open_topo() -> void:
	_busy = true
	_prompt.visible = false
	Game.sfx("Sounds/Menu/Accept.wav", -12.0)
	_topo = TOPO.new()
	_topo.setup(area_dir, meta, _topo_data, Vector2(player.position.x, player.position.z))
	_topo.closed.connect(_close_topo)
	_topo.climb.connect(_climb_from_topo)
	add_child(_topo)


func _close_topo() -> void:
	if _topo:
		_topo.queue_free()
		_topo = null
	_busy = false


func _climb_from_topo(block_id: String) -> void:
	_close_topo()
	for b in meta.boulders:
		if b.get("id", "") == block_id:
			_start_climb(b)
			return


## Someone tells you about a block outside the circuit: from now on it is in your topo.
func _learn_from(who: String) -> void:
	for o in _topo_data.get("outside", []):
		if o.get("told_by", "") == who and not Game.known.has(o.id):
			Game.known[o.id] = true
			_news = "New in your topo: %s  %s" % [o.name, o.grade]


func _tell_news(text: String) -> void:
	_notice.text = text
	var tw := create_tween()
	tw.tween_property(_notice, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.6)
	tw.tween_property(_notice, "modulate:a", 0.0, 0.5)


func _topo_key() -> String:
	if _topo_data.is_empty():
		return ""
	return " Open it with %s." % (Game.button_name(JOY_BUTTON_BACK) if Game.using_pad else "Tab")


## A line of speech appears letter by letter.
func _say_line(line: String) -> void:
	_speech_text.text = line
	_speech_text.visible_ratio = 0.0
	if _typing:
		_typing.kill()
	_typing = create_tween()
	_typing.tween_property(_speech_text, "visible_ratio", 1.0, line.length() * 0.028)


# ---------------------------------------------------------------- pause menu
## Start or Esc: the game stops, with where you are and how the circuit goes beside the menu.
func _open_pause() -> void:
	if _menu == null:
		_menu = MenuLayer.new()
		add_child(_menu)
		_menu.chose.connect(_on_menu)
		_menu.closed.connect(func() -> void: get_tree().paused = false)
	get_tree().paused = true
	Game.sfx("Sounds/Menu/Accept.wav", -12.0)
	_menu.open({"title": "PAUSED", "at": Vector2(28, 48), "width": 124, "dim": true,
		"items": [{"label": "Resume", "id": "resume"}, {"label": "Topo", "id": "topo", "dim": _topo_data.is_empty()},
			{"label": "Settings", "id": "settings"}, {"label": "Controls", "id": "controls"},
			{"label": "Title screen", "id": "title"}],
		"card": _pause_card, "card_rect": Rect2(168, 40, 284, 132)})


func _on_menu(id: String) -> void:
	match id:
		"resume":
			_menu.close()
		"topo":
			_menu.close()
			_open_topo()
		"title":
			get_tree().paused = false
			get_tree().change_scene_to_file(TITLE_SCENE)


func _pause_card(menu: MenuLayer, panel: Control) -> void:
	var right := panel.size.x - 14.0
	menu.label(panel, str(meta.get("title", "")), Vector2(14, 6), MenuLayer.CREAM, Game.FONT_TITLE)
	menu.label(panel, "%s  ·  %s" % [meta.get("subtitle", "Fontainebleau"), LOOKS[time].label], Vector2(14, 22), MenuLayer.SAND)
	var y := 44.0
	var circuit: Array = []
	for b in meta.boulders:
		if str(b.get("id", "")).begins_with("geel"):
			circuit.append(b)
	circuit.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.n < b.n)
	if not circuit.is_empty():
		var done := 0
		for b in circuit:
			done += 1 if Game.is_topped(b.id) else 0
		menu.label(panel, str(_topo_data.get("circuit", "Circuit")), Vector2(14, y))
		menu.label(panel, "%d / %d topped" % [done, circuit.size()], Vector2(0, y), MenuLayer.SAND, Game.FONT_TEXT, right, HORIZONTAL_ALIGNMENT_RIGHT)
		for k in circuit.size():
			menu.badge(panel, Vector2(14 + k * 15, y + 18), int(circuit[k].n), Game.is_topped(circuit[k].id))
		y += 38.0
	var outside: Array = _topo_data.get("outside", [])
	if not outside.is_empty():
		var found := 0
		for o in outside:
			found += 1 if o.get("known", false) or Game.known.has(o.id) else 0
		menu.label(panel, "Off the circuit", Vector2(14, y))
		menu.label(panel, "%d of %d found" % [found, outside.size()], Vector2(0, y), MenuLayer.SAND, Game.FONT_TEXT, right, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 20.0
	var tries := 0
	var sends := 0
	var flashes := 0
	for e in Game.logbook.values():
		tries += e.attempts
		sends += e.sends
		flashes += 1 if e.flash else 0
	menu.label(panel, "This session  %d %s  ·  %d %s  ·  %d %s" % [tries, "try" if tries == 1 else "tries",
		sends, "send" if sends == 1 else "sends", flashes, "flash" if flashes == 1 else "flashes"], Vector2(14, y + 4), MenuLayer.SAND)


## Graphics High or Low (a setting): Low drops what costs most and shows least, for laptops
## and handhelds. One pass of sun shadow instead of four, no ambient occlusion, no volumetric
## fog, no depth of field, no anti-aliasing.
func _apply_graphics() -> void:
	var low := Game.graphics_low
	env.ssao_enabled = not low
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if low else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 30.0 if low else 45.0
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X
	_apply_hour()


# ---------------------------------------------------------------- climbing
## A burst of chalk, then the climbing screen. Leaving it brings you back where you stood.
func _start_climb(target: Dictionary = {}) -> void:
	_busy = true
	_prompt.visible = false
	Game.sfx("Sounds/Menu/Accept.wav", -10.0)
	var tw := create_tween()
	tw.tween_property(camera, "fov", CAM_FOV * 0.68, 0.45).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_fade, "modulate:a", 1.0, 0.45)
	await tw.finished
	var block := target if not target.is_empty() else _near
	var forest := await _forest_behind(block)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_climb = CLIMB.new()
	_climb.backdrop = forest
	_climb.time_name = "schemering" if time == "nacht" else time  # the rock has no night picture yet
	_climb.route_id = block.get("route", "marierose")
	_climb.leave.connect(_end_climb)
	_climb.topped.connect(func() -> void:
		Game.mark_topped(block.get("id", "marierose"))
		await get_tree().create_timer(2.6).timeout  # time to read the logbook line
		if _climb and not _busy:
			_end_climb())
	_climb_layer.add_child(_climb)
	# The climbing screen covers the whole world and has its own picture of the forest: drawing
	# the world underneath would cost nearly as much as walking in it, for nothing.
	get_viewport().disable_3d = true
	var tw2 := create_tween()
	tw2.tween_property(_fade, "modulate:a", 0.0, 0.35)
	await tw2.finished
	_busy = false


## A picture of the forest behind the block, from where you stand in front of it, blurred:
## the backdrop of the climbing screen, in the same light as here.
func _forest_behind(block: Dictionary) -> Texture2D:
	if not block.has("x"):
		return null
	var view := SubViewport.new()
	view.size = Vector2i(480, 270)
	view.world_3d = get_world_3d()
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cam := Camera3D.new()
	cam.fov = 52.0
	view.add_child(cam)
	add_child(view)
	# From the block itself, looking on into the forest: the block is behind you (its walls face
	# outwards, so from inside it you see through), and the camp or props in front stay out.
	var g := ground_at(block.x, block.z - 6.0)
	cam.position = Vector3(block.x, g + 1.9, block.z)
	cam.look_at(Vector3(block.x, g + 2.4, block.z - 12.0))
	cam.current = true
	player.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := view.get_texture().get_image()
	player.visible = true
	view.queue_free()
	img.resize(96, 54, Image.INTERPOLATE_BILINEAR)  # out of focus: the rock is what you look at
	img.resize(480, 270, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(img)


func _end_climb() -> void:
	_busy = true
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.3)
	await tw.finished
	_climb.queue_free()
	_climb = null
	get_viewport().disable_3d = false
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	camera.fov = CAM_FOV
	var tw2 := create_tween()
	tw2.tween_property(_fade, "modulate:a", 0.0, 0.4)
	await tw2.finished
	_busy = false
