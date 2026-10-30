extends Node3D
## The spacecraft, built from primitives. Forward is -Z (Godot convention), exhaust at +Z.
## Visuals react to subsystem health: scorching, glowing when critical, bent arrays, etc.

const Gfx = preload("res://scripts/gfx.gd")
const SCORCH := Color("2a120c")

var parts := {}
var _mats := {}   # id -> Array of {m: StandardMaterial3D, base: Color, emissive_base: Color}
var wings: Array = []
var boom: Node3D
var dish_g: Node3D
var hull_node: Node3D
var flame_pivot: Node3D
var flame_mat: StandardMaterial3D
var flame_glow: MeshInstance3D
var plasma: MeshInstance3D
var flame_level := 1.0
var plasma_level := 0.0


func _ready() -> void:
	_build()


func _reg(id: String) -> Node3D:
	var n := Node3D.new()
	n.name = id
	parts[id] = n
	_mats[id] = []
	add_child(n)
	return n


func _std(id: String, color: Color, metal: float = 0.55, rough: float = 0.45, emissive: Color = Color.BLACK) -> StandardMaterial3D:
	var m := Gfx.std_mat(color, metal, rough)
	m.emission_enabled = true
	m.emission = emissive
	_mats[id].append({"m": m, "base": color, "ebase": emissive})
	return m


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _cyl(top: float, bottom: float, h: float, seg: int = 20, caps: bool = true) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	c.cap_top = caps
	c.cap_bottom = caps
	return c


func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


func _build() -> void:
	var rx := Vector3(90, 0, 0)   # lay a Y-axis cylinder along Z (top radius ends up at +Z, the rear)

	hull_node = _reg("hull")
	_mesh(hull_node, _cyl(0.8, 0.66, 3.0), _std("hull", Color("d2d9e3")), Vector3.ZERO, rx)
	_mesh(hull_node, _cyl(0.82, 0.82, 0.25), _std("hull", Color("3a4a66")), Vector3(0, 0, 0.3), rx)

	var shield := _reg("shield")
	_mesh(shield, _cyl(1.5, 1.2, 0.2, 28), _std("shield", Color("2e2e32"), 0.2, 0.8), Vector3(0, 0, -1.65), rx)
	var torus := TorusMesh.new()
	torus.inner_radius = 1.4
	torus.outer_radius = 1.5
	torus.rings = 40
	torus.ring_segments = 8
	_mesh(shield, torus, _std("shield", Color("8a8a92"), 0.8, 0.3), Vector3(0, 0, -1.62), rx)

	var arrays := _reg("arrays")
	for side in [-1, 1]:
		var w := Node3D.new()
		w.position = Vector3(0, 0, 0.2)
		_mesh(w, _box(1.0, 0.07, 0.07), _std("arrays", Color("9aa3b0")), Vector3(side * 0.9, 0, 0))
		_mesh(w, _box(2.4, 0.04, 1.15), _std("arrays", Color("2a4fa6"), 0.35, 0.35, Color("0a1a40")), Vector3(side * 2.3, 0, 0))
		arrays.add_child(w)
		wings.append(w)

	var sensors := _reg("sensors")
	boom = Node3D.new()
	boom.position = Vector3(0, 0.7, -0.4)
	_mesh(boom, _cyl(0.04, 0.04, 0.9, 8), _std("sensors", Color("b8bec8")), Vector3(0, 0.45, 0))
	_mesh(boom, _box(0.3, 0.22, 0.34), _std("sensors", Color("e0e4ea")), Vector3(0, 0.95, 0))
	var lens := SphereMesh.new()
	lens.radius = 0.07
	lens.height = 0.14
	lens.radial_segments = 8
	lens.rings = 4
	var lens_mat := Gfx.unshaded_mat(Color("66ccff"))
	_mesh(boom, lens, lens_mat, Vector3(0, 0.95, -0.18))
	sensors.add_child(boom)

	var comms := _reg("comms")
	dish_g = Node3D.new()
	dish_g.position = Vector3(0, 0.9, 1.0)
	var dish := SphereMesh.new()
	dish.radius = 0.55
	dish.height = 0.55
	dish.is_hemisphere = true
	var dish_mat := _std("comms", Color("eeeeee"), 0.3, 0.4)
	dish_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(dish_g, dish, dish_mat, Vector3.ZERO, Vector3(rad_to_deg(PI / 2.0 + 0.5), 0, 0))
	_mesh(dish_g, _cyl(0.025, 0.025, 0.5, 6), _std("comms", Color("aaaaaa")), Vector3(0, 0.25, 0.15))
	comms.add_child(dish_g)

	var thr := _reg("thrusters")
	var bell_mat := _std("thrusters", Color("707782"), 0.8, 0.35)
	bell_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(thr, _cyl(0.58, 0.32, 0.8, 18, false), bell_mat, Vector3(0, 0, 1.9), rx)
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			_mesh(thr, _box(0.16, 0.16, 0.26), _std("thrusters", Color("9aa0aa")), Vector3(sx * 0.74, sy * 0.5, 1.1))

	# Exhaust flame: cone apex pointing rearwards (+Z)
	flame_pivot = Node3D.new()
	add_child(flame_pivot)
	var cone := _cyl(0.0, 0.38, 2.4, 14)
	flame_mat = StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_mat.albedo_color = Color(0.35, 0.6, 1.0, 0.7)
	var flame_mesh := _mesh(flame_pivot, cone, flame_mat, Vector3.ZERO, rx)
	flame_mesh.position = Vector3(0, 0, 1.2)  # base at pivot origin, apex at +2.4
	flame_pivot.position = Vector3(0, 0, 2.3)

	flame_glow = Gfx.glow(Color("78beff"), 3.4, 0.9)
	flame_glow.position = Vector3(0, 0, 2.5)
	add_child(flame_glow)
	plasma = Gfx.glow(Color("ff8c3c"), 7.0, 0.0)
	plasma.position = Vector3(0, 0, -2.2)
	add_child(plasma)


func set_flame(v: float) -> void:
	flame_level = v


func set_plasma(v: float) -> void:
	plasma_level = v
	Gfx.set_glow_opacity(plasma, minf(1.0, v))
	var sc := 5.0 + v * 8.0
	plasma.scale = Vector3(sc / 7.0, sc / 7.0, sc / 7.0)


func update_look(h: Dictionary, known_shield: float, t: float) -> void:
	_look("hull", h.hull, t)
	_look("shield", known_shield, t)
	_look("arrays", h.arrays, t)
	_look("sensors", h.sensors, t)
	_look("comms", h.comms, t)
	_look("thrusters", h.thrusters, t)
	var da := 1.0 - float(h.arrays) / 100.0
	var ds := 1.0 - float(h.sensors) / 100.0
	var dc := 1.0 - float(h.comms) / 100.0
	var dh := 1.0 - float(h.hull) / 100.0
	wings[0].rotation.z = da * 0.55
	wings[1].rotation.z = -da * 0.8
	boom.rotation.z = ds * 0.9
	dish_g.rotation.y = sin(t * 3.1) * dc * 0.8 if dc > 0.4 else 0.0
	hull_node.scale = Vector3(1.0 - dh * 0.05, 1.0 - dh * 0.05, 1.0)

	var base := flame_level * (0.45 + 0.55 * float(h.thrusters) / 100.0)
	var stutter := 1.0
	if h.thrusters < 55:
		stutter = 0.6 + 0.4 * sin(t * 31.0) * sin(t * 17.0)
	var k := maxf(0.02, base * stutter) * (0.92 + 0.08 * sin(t * 40.0))
	flame_pivot.scale = Vector3(1, 1, k)
	flame_mat.albedo_color.a = 0.12 + 0.5 * minf(1.0, k)
	Gfx.set_glow_opacity(flame_glow, 0.1 + 0.5 * minf(1.0, k))
	if plasma_level > 0.0:
		Gfx.set_glow_opacity(plasma, minf(1.0, plasma_level * (0.85 + 0.15 * sin(t * 50.0))))


func _look(id: String, v: float, t: float) -> void:
	var d := 1.0 - v / 100.0
	for e in _mats[id]:
		var m: StandardMaterial3D = e.m
		m.albedo_color = (e.base as Color).lerp(SCORCH, minf(0.85, d * 0.95))
		if v < 45.0:
			var pulse := 0.5 + 0.5 * sin(t * 6.0 + id.length())
			m.emission = Color(1, 0.25, 0.05)
			m.emission_energy_multiplier = (1.0 - v / 45.0) * (0.25 + 0.5 * pulse)
		else:
			m.emission = e.ebase
			m.emission_energy_multiplier = 1.0
