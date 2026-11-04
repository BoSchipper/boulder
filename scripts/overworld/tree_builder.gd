class_name TreeBuilder
extends RefCounted
## Builds the trees of the walking world from a few smooth shapes: a spruce of stacked wavy
## tiers, a round broadleaf of bulging clumps, a tall Scots pine with flat pads of needles,
## a birch. Each tree gets a trunk you bump into. Sizes are in metres.

const ATLAS := preload("res://assets/overworld/bas_cuvier/tree_atlas.png")
const SHADER := preload("res://shaders/overworld/foliage.gdshader")
# Tiles in tree_atlas.png, in the order export_area.py writes them.
const TILES := {"spruce": 0, "broadleaf": 1, "pine": 2, "birchleaf": 3, "bark": 4, "pinebark": 5, "birch": 6}
const LEAVES := ["spruce", "broadleaf", "pine", "birchleaf"]

var _materials := {}
var _noise := NoiseTexture2D.new()
var _sphere := SphereMesh.new()


func _init() -> void:
	var fn := FastNoiseLite.new()
	fn.frequency = 0.05
	_noise.noise = fn
	_noise.seamless = true
	_sphere.radius = 1.0
	_sphere.height = 2.0
	_sphere.radial_segments = 16
	_sphere.rings = 10


func material(tile: String) -> ShaderMaterial:
	if not _materials.has(tile):
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("atlas", ATLAS)
		m.set_shader_parameter("noise", _noise)
		m.set_shader_parameter("tile", float(TILES[tile]))
		m.set_shader_parameter("translucency", 0.12 if tile in LEAVES else 0.0)
		_materials[tile] = m
	return _materials[tile]


func materials() -> Array:
	return _materials.values()


## One tree as a node: kind is spruce, broadleaf, pine or birch; g is the ground under it.
func build(kind: String, pos: Vector3, h: float, seed: int, solid: bool) -> Node3D:
	var tree := Node3D.new()
	tree.position = pos
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	match kind:
		"spruce":
			_trunk(tree, 0.0, h * 0.95, 0.14, 0.05, "bark")
			for i in 7:
				_tier(tree, h * (0.12 + 0.118 * i), h * 0.21, h * (0.3 - 0.037 * i), seed + i)
		"broadleaf":
			_trunk(tree, 0.0, h * 0.62, 0.22, 0.13, "bark")
			var c := Vector3(0, h * 0.7, 0)
			_clump(tree, c, Vector3(h * 0.26, h * 0.22, h * 0.26), "broadleaf")
			for k in 7:
				var a := rng.randf() * TAU
				var r := h * rng.randf_range(0.14, 0.2)
				_clump(tree, c + Vector3(cos(a) * h * 0.2, rng.randf_range(-0.08, 0.16) * h, sin(a) * h * 0.2),
					Vector3(r, r * 0.85, r), "broadleaf")
		"pine":
			_trunk(tree, 0.0, h * 0.5, 0.2, 0.14, "bark")
			_trunk(tree, h * 0.5, h * 0.93, 0.14, 0.08, "pinebark")
			for k in 6:
				_clump(tree, Vector3(rng.randf_range(-0.8, 0.8), h * rng.randf_range(0.7, 0.96), rng.randf_range(-0.65, 0.65)),
					Vector3(rng.randf_range(0.8, 1.2), rng.randf_range(0.34, 0.47), rng.randf_range(0.8, 1.2)), "pine")
		_:
			_trunk(tree, 0.0, h * 0.92, 0.1, 0.05, "birch")
			for k in 5:
				var r := rng.randf_range(0.45, 0.65)
				_clump(tree, Vector3(rng.randf_range(-0.45, 0.45), h * rng.randf_range(0.55, 0.95), rng.randf_range(-0.4, 0.4)),
					Vector3(r, r * 1.1, r), "birchleaf")
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.35 if kind != "birch" else 0.25
		cyl.height = 3.0
		shape.shape = cyl
		shape.position.y = 1.5
		body.add_child(shape)
		tree.add_child(body)
	return tree


func _trunk(tree: Node3D, y0: float, y1: float, r0: float, r1: float, tile: String) -> void:
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = r0
	cyl.top_radius = r1
	cyl.height = y1 - y0 + 0.2
	cyl.radial_segments = 8
	cyl.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = material(tile)
	mi.position.y = (y0 + y1) / 2.0 - 0.1
	tree.add_child(mi)


func _clump(tree: Node3D, at: Vector3, radii: Vector3, tile: String) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere
	mi.material_override = material(tile)
	mi.position = at
	mi.scale = radii
	mi.set_instance_shader_parameter("bump", 0.14 / ((radii.x + radii.y + radii.z) / 3.0))
	tree.add_child(mi)


## A spruce tier: a wavy skirt, high in the middle, drooping at the tips, with an underside.
func _tier(tree: Node3D, y0: float, ht: float, radius: float, seed: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 28
	var rings := [[0.0, ht], [0.35, ht * 0.62], [0.7, ht * 0.28], [1.0, -radius * 0.3], [0.55, -radius * 0.12], [0.15, 0.0]]
	var pts: Array = []
	for r in rings:
		var ring: Array[Vector3] = []
		for i in seg + 1:
			var th := TAU * i / seg
			var rw := radius * (1.0 + 0.13 * sin(7.0 * th + seed) + 0.06 * sin(13.0 * th + 2.0 * seed))
			ring.append(Vector3(cos(th) * rw * r[0], r[1], sin(th) * rw * r[0]))
		pts.append(ring)
	for k in pts.size() - 1:
		for i in seg:
			var a: Vector3 = pts[k][i]
			var b: Vector3 = pts[k][i + 1]
			var c: Vector3 = pts[k + 1][i]
			var d: Vector3 = pts[k + 1][i + 1]
			for v in [a, c, b, b, c, d]:
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material("spruce")
	mi.position.y = y0
	mi.set_instance_shader_parameter("bump", 0.09)
	tree.add_child(mi)
