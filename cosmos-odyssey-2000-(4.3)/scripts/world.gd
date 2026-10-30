extends Node3D
## The Solar System scene: Sun, planets, belt, comet, black hole, route lines and floating labels.

const Data = preload("res://scripts/data.gd")
const Gfx = preload("res://scripts/gfx.gd")
const D2R := PI / 180.0
const ORB_Z := 0.92

const VIEW := {
	"earth": {"cam": 26.0, "park": 14.0, "rad": 5.0, "ang": 0.55, "h": 0.3},
	"mars": {"cam": 22.0, "park": 11.0, "rad": 3.5, "ang": 0.55, "h": 0.3},
	"belt": {"cam": 55.0, "park": 24.0, "rad": 3.0, "ang": 0.6, "h": 0.3},
	"jupiter": {"cam": 70.0, "park": 28.0, "rad": 14.0, "ang": 0.55, "h": 0.28},
	"comet": {"cam": 28.0, "park": 11.0, "rad": 1.6, "ang": 1.25, "h": 0.25},
	"pluto": {"cam": 20.0, "park": 9.0, "rad": 2.2, "ang": 0.55, "h": 0.3},
	"blackhole": {"cam": 90.0, "park": 48.0, "rad": 12.0, "ang": 0.85, "h": 0.45},
	"earth2": {"cam": 26.0, "park": 14.0, "rad": 5.0, "ang": 0.55, "h": 0.3},
}
const PATH_COL := {"fast": Color("ff7a5c"), "normal": Color("6ee7a0"), "ellipse": Color("6aa8ff")}

var root: Node3D
var bodies := {}
var camera: Camera3D
var label_host: Control
var labels: Array = []
var spinners: Array = []
var orbiters: Array = []
var path_nodes: Array = []
var sun_glow1: MeshInstance3D
var halo: MeshInstance3D
var comet_pos: Vector3


static func orbit_pos(r: float, a: float, y: float = 0.0) -> Vector3:
	return Vector3(r * cos(a * D2R), y, r * sin(a * D2R) * ORB_Z)


static func comet_at(nu_deg: float) -> Vector3:
	var c := Data.COMET
	var p: float = c.a * (1.0 - c.e * c.e)
	var nu := nu_deg * D2R
	var r: float = p / (1.0 + c.e * cos(nu))
	var x := r * cos(nu)
	var z := r * sin(nu)
	var w: float = c.omega * D2R
	return Vector3(x * cos(w) - z * sin(w), 0, x * sin(w) + z * cos(w))


static func rot_y(v: Vector3, a: float) -> Vector3:
	var c := cos(a)
	var s := sin(a)
	return Vector3(v.x * c + v.z * s, v.y, -v.x * s + v.z * c)


func setup(cam: Camera3D, labels_host: Control) -> void:
	camera = cam
	label_host = labels_host
	root = Node3D.new()
	add_child(root)
	_build_stars()
	_build_sun()
	_build_planets()
	_build_belt()
	_build_comet()
	_build_blackhole()


func set_world_visible(v: bool) -> void:
	root.visible = v
	label_host.visible = v


func _add_label(text: String, obj: Node3D, yoff: float, major: bool) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18 if major else 16)
	l.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0) if major else Color(0.7, 0.78, 0.9))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_host.add_child(l)
	labels.append({"el": l, "obj": obj, "yoff": yoff, "major": major})


func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := 2600
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for i in n:
		var v := Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5).normalized() * (2600.0 + rng.randf() * 400.0)
		verts.append(v)
		var k := 0.6 + rng.randf() * 0.4
		var warm := rng.randf()
		cols.append(Color(k, k * (0.88 + warm * 0.12), k * (0.8 + (1.0 - warm) * 0.2)))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arr)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.use_point_size = true
	m.point_size = 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.extra_cull_margin = 16384.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _sphere(r: float, seg: int = 48, rings: int = 24) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = rings
	return s


func _build_sun() -> void:
	var sun := MeshInstance3D.new()
	sun.mesh = _sphere(22.0, 64, 32)
	sun.material_override = Gfx.planet_mat(5, 3.0, Color("ffc14a"), Color("fff0a0"), Color.WHITE, 3.0)
	root.add_child(sun)
	bodies["sun"] = sun
	sun_glow1 = Gfx.glow(Color("ffc86e"), 150.0, 0.95)
	root.add_child(sun_glow1)
	root.add_child(Gfx.glow(Color("ff8c32"), 340.0, 0.4))
	var light := OmniLight3D.new()
	light.light_color = Color("fff0d8")
	light.light_energy = 1.5
	light.omni_range = 6000.0
	light.omni_attenuation = 0.0
	root.add_child(light)
	_add_label("Sun", sun, 30.0, false)


func _orbit_line(r: float, color: Color = Color("2a3b66"), alpha: float = 0.7) -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 257:
		im.surface_add_vertex(orbit_pos(r, float(i) / 256.0 * 360.0))
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = Gfx.unshaded_mat(Color(color.r * 1.8, color.g * 1.8, color.b * 1.8, alpha))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


func _planet(pname: String, r: float, mat: Material, pos: Vector3, spin: float = 0.06, tilt: float = 0.25, atmos: Color = Color(0, 0, 0, 0), rings: bool = false, label: bool = true, major: bool = false) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	var mesh := MeshInstance3D.new()
	mesh.mesh = _sphere(r)
	mesh.material_override = mat
	mesh.rotation.z = tilt
	g.add_child(mesh)
	if atmos.a > 0.0:
		var a := MeshInstance3D.new()
		a.mesh = _sphere(r * 1.07)
		var am := StandardMaterial3D.new()
		am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		am.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		am.cull_mode = BaseMaterial3D.CULL_FRONT
		am.albedo_color = Color(atmos.r, atmos.g, atmos.b, 0.12)
		am.no_depth_test = false
		a.material_override = am
		g.add_child(a)
	if rings:
		var rm := MeshInstance3D.new()
		rm.mesh = Gfx.annulus(r * 1.5, r * 2.4, 128, 1.0)
		var sm := ShaderMaterial.new()
		sm.shader = preload("res://shaders/ring.gdshader")
		rm.material_override = sm
		rm.rotation.x = 0.45
		g.add_child(rm)
	root.add_child(g)
	spinners.append({"mesh": mesh, "speed": spin})
	if label:
		_add_label(pname, g, r + 2.5, major)
	return g


func _moon(parent: Node3D, r: float, dist: float, speed: float, phase: float, mat: Material, incl: float = 0.25) -> void:
	var m := MeshInstance3D.new()
	m.mesh = _sphere(r, 20, 10)
	m.material_override = mat
	root.add_child(m)
	orbiters.append({"m": m, "parent": parent, "dist": dist, "speed": speed, "phase": phase, "incl": incl})


func _stop_orbit(id: String) -> Vector3:
	for s in Data.STOPS:
		if s.id == id:
			var o: Array = s.orbit
			return orbit_pos(o[0], o[1], o[2])
	return Vector3.ZERO


func _build_planets() -> void:
	var rock := Gfx.planet_mat(0, 11.0, Color("8c8379"), Color("5f574f"), Color("b3a99d"), 1.0)
	var dark := Gfx.planet_mat(0, 12.0, Color("6b6258"), Color("4a443d"), Color("7d7468"), 1.0)

	bodies["earth"] = _planet("Earth", 5.0, Gfx.planet_mat(1, 2.0, Color("1b4f9e"), Color("2e8d49"), Color("8bb86b"), 1.0), _stop_orbit("earth"), 0.08, 0.25, Color("4da6ff"), false, true, true)
	_moon(bodies["earth"], 1.3, 11.0, 0.5, 1.0, rock)
	bodies["mars"] = _planet("Mars", 3.5, Gfx.planet_mat(2, 4.0, Color("b4532c"), Color("7a3418"), Color("dc9163"), 1.0), _stop_orbit("mars"), 0.07, 0.25, Color("ff9966"), false, true, true)
	_moon(bodies["mars"], 0.35, 6.5, 1.4, 0.0, dark)
	_moon(bodies["mars"], 0.28, 9.5, 0.8, 2.0, dark)
	bodies["jupiter"] = _planet("Jupiter", 14.0, Gfx.planet_mat(3, 6.0, Color("d9b38c"), Color("a8714a"), Color("efe0c8"), 1.0, 26.0, 1.0), _stop_orbit("jupiter"), 0.12, 0.05, Color(0, 0, 0, 0), false, true, true)
	var jm := [[1.1, 22.0, 1.2, 0.0], [1.0, 28.0, 0.8, 1.7], [1.7, 36.0, 0.5, 3.3], [1.5, 45.0, 0.3, 4.4]]
	for i in jm.size():
		_moon(bodies["jupiter"], jm[i][0], jm[i][1], jm[i][2], jm[i][3], dark if i % 2 == 1 else rock, 0.08)
	bodies["pluto"] = _planet("Pluto", 2.2, Gfx.planet_mat(4, 8.0, Color("b79f89"), Color("8a6f5c"), Color("f1e8de"), 1.0), _stop_orbit("pluto"), 0.03, 0.25, Color(0, 0, 0, 0), false, true, true)
	_moon(bodies["pluto"], 1.1, 5.2, 0.35, 0.0, dark, 0.05)
	bodies["belt"] = _planet("Ceres (Asteroid Belt)", 3.0, rock, _stop_orbit("belt"), 0.1, 0.25, Color(0, 0, 0, 0), false, true, true)

	_planet("Mercury", 1.6, Gfx.planet_mat(0, 20.0, Color("9a928a"), Color("6f6861"), Color("bdb6ae")), orbit_pos(46.0, 200.0))
	_planet("Venus", 4.4, Gfx.planet_mat(3, 21.0, Color("e6c88a"), Color("d0a864"), Color("f1dcae"), 1.0, 9.0), orbit_pos(68.0, 300.0), 0.06, 0.25, Color("ffd699"))
	_planet("Saturn", 11.0, Gfx.planet_mat(3, 22.0, Color("e6d29c"), Color("c8ae72"), Color("f0e2b8"), 1.0, 22.0), orbit_pos(310.0, 120.0, 3.0), 0.06, 0.3, Color(0, 0, 0, 0), true)
	_planet("Uranus", 6.0, Gfx.planet_mat(3, 23.0, Color("9fe0e6"), Color("86cdd6"), Color("c4f0f2"), 1.0, 6.0), orbit_pos(365.0, 325.0), 0.06, 0.25, Color("9fe0e6"))
	_planet("Neptune", 5.8, Gfx.planet_mat(3, 24.0, Color("3b5fd0"), Color("2a46a8"), Color("5a7be6"), 1.0, 12.0), orbit_pos(400.0, 250.0), 0.06, 0.25, Color("4466ff"))
	for r in [46.0, 68.0, 90.0, 135.0, 235.0, 310.0, 365.0, 400.0, 430.0]:
		_orbit_line(r)
	_orbit_line(180.0, Color("4a3c30"), 0.35)


func _build_belt() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var n := 2200
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Gfx.rock_mesh(5, 3, 5)
	mm.instance_count = n
	for i in n:
		var r := 158.0 + (rng.randf() + rng.randf()) * 0.5 * 50.0
		var a := rng.randf() * 360.0
		var p := orbit_pos(r, a, (rng.randf() - 0.5) * 9.0)
		var basis := Basis.from_euler(Vector3(rng.randf() * 6.0, rng.randf() * 6.0, rng.randf() * 6.0))
		var sc := 0.25 + pow(rng.randf(), 3.0) * 1.5
		basis = basis.scaled(Vector3(sc, sc * (0.6 + rng.randf() * 0.4), sc))
		mm.set_instance_transform(i, Transform3D(basis, p))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Gfx.std_mat(Color("8f8579"), 0.0, 1.0)
	root.add_child(mmi)


func _build_comet() -> void:
	var g := Node3D.new()
	comet_pos = comet_at(Data.COMET.nu)
	g.position = comet_pos
	var rock := MeshInstance3D.new()
	rock.mesh = Gfx.rock_mesh(31, 6, 10)
	rock.scale = Vector3(1.9, 1.45, 1.6)
	rock.material_override = Gfx.std_mat(Color("5b5650"), 0.0, 1.0)
	g.add_child(rock)
	g.add_child(Gfx.glow(Color("aad7ff"), 16.0, 0.8))
	root.add_child(g)
	bodies["comet"] = g
	spinners.append({"mesh": rock, "speed": 0.4})
	_add_label("Comet", g, 5.0, true)
	# orbit path
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(0, 362, 2):
		im.surface_add_vertex(comet_at(float(i)))
	im.surface_end()
	var line := MeshInstance3D.new()
	line.mesh = im
	line.material_override = Gfx.unshaded_mat(Color(0.3, 0.52, 0.66, 0.6))
	root.add_child(line)
	# tail: particles streaming away from the Sun
	var tail_dir := Vector3(comet_pos.x, 0, comet_pos.z).normalized()
	var p := CPUParticles3D.new()
	p.amount = 900
	p.lifetime = 10.0
	p.local_coords = true
	p.direction = tail_dir
	p.spread = 7.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 12.0
	p.gravity = Vector3.ZERO
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.4
	p.scale_amount_min = 0.8
	p.scale_amount_max = 2.2
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.6))
	sc.add_point(Vector2(1, 2.4))
	p.scale_amount_curve = sc
	var gr := Gradient.new()
	gr.set_color(0, Color(0.5, 0.72, 1.0, 0.22))
	gr.set_color(1, Color(0.5, 0.72, 1.0, 0.0))
	p.color_ramp = gr
	var q := QuadMesh.new()
	q.size = Vector2(3.0, 3.0)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	var grad_tex := GradientTexture2D.new()
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.5, 0.0)
	var gg := Gradient.new()
	gg.set_color(0, Color(1, 1, 1, 1))
	gg.set_color(1, Color(1, 1, 1, 0))
	grad_tex.gradient = gg
	grad_tex.width = 64
	grad_tex.height = 64
	qm.albedo_texture = grad_tex
	q.material = qm
	p.mesh = q
	g.add_child(p)
	p.preprocess = 10.0


func _build_blackhole() -> void:
	var o: Array = []
	for s in Data.STOPS:
		if s.id == "blackhole":
			o = s.orbit
	var bh := Node3D.new()
	bh.position = orbit_pos(o[0], o[1], o[2])
	bodies["blackhole"] = bh
	var disk := MeshInstance3D.new()
	disk.mesh = Gfx.annulus(15.0, 44.0, 160, 1.0)
	var dm := ShaderMaterial.new()
	dm.shader = preload("res://shaders/disk.gdshader")
	disk.material_override = dm
	disk.rotation.x = 0.32
	bh.add_child(disk)
	var core := MeshInstance3D.new()
	core.mesh = _sphere(12.0, 40, 20)
	core.material_override = Gfx.unshaded_mat(Color.BLACK)
	bh.add_child(core)
	halo = MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(38, 38)
	halo.mesh = hq
	var hm := ShaderMaterial.new()
	hm.shader = preload("res://shaders/halo.gdshader")
	halo.material_override = hm
	bh.add_child(halo)
	bh.add_child(Gfx.glow(Color("ff963c"), 130.0, 0.35))
	root.add_child(bh)
	_add_label("Black hole (simulation)", bh, 24.0, true)


# ---------- geometry queries used by the game flow ----------

func body_pos(i: int) -> Vector3:
	var id: String = Data.STOPS[i].id
	var key := "earth" if id == "earth2" else id
	return (bodies[key] as Node3D).position


func _sun_dir(b: Vector3) -> Vector3:
	var u := Vector3(-b.x, 0, -b.z)
	if u.length_squared() < 1.0:
		u = Vector3(1, 0, 0)
	return u.normalized()


func park_pos(i: int) -> Vector3:
	var v: Dictionary = VIEW[Data.STOPS[i].id]
	var b := body_pos(i)
	return b + rot_y(_sun_dir(b), -0.25) * float(v.park) + Vector3(0, float(v.park) * 0.05, 0)


func body_radius(i: int) -> float:
	return VIEW[Data.STOPS[i].id].rad


func view(i: int) -> Dictionary:
	var v: Dictionary = VIEW[Data.STOPS[i].id]
	var b := body_pos(i)
	var u := _sun_dir(b)
	var pos: Vector3 = b + rot_y(u, v.ang) * v.cam + Vector3(0, v.cam * v.h, 0)
	var target: Vector3 = b.lerp(park_pos(i), 0.45)
	return {"pos": pos, "target": target}


func overview(i0: int, i1: int) -> Dictionary:
	var a := park_pos(i0)
	var b := park_pos(i1)
	var target := (a + b) * 0.5
	var dist := a.distance_to(b) * 0.95 + 70.0
	return {"pos": target + Vector3(0.25, 0.85, 0.55).normalized() * dist, "target": target}


## Control points of the quadratic Bezier for a leg: [A, C, B]
func curve(i0: int, i1: int, pid: String) -> Array:
	var a := park_pos(i0)
	var b := park_pos(i1)
	var mid := (a + b) * 0.5
	var ab := b - a
	var length := ab.length()
	var side := Vector3(-ab.z, 0, ab.x).normalized()
	if side.dot(mid) < 0.0:
		side = -side
	var bow: float = {"fast": 0.0, "normal": 0.2, "ellipse": 0.5}.get(pid, 0.2)
	var c := mid + side * (length * bow * 2.0)
	var m := bez(a, c, b, 0.5)
	var d := Vector2(m.x, m.z).length()
	if d < 75.0:
		c += side * ((75.0 - d) * 2.2)
	return [a, c, b]


static func bez(a: Vector3, c: Vector3, b: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return a * (u * u) + c * (2.0 * u * t) + b * (t * t)


static func bez_tan(a: Vector3, c: Vector3, b: Vector3, t: float) -> Vector3:
	return ((c - a) * (2.0 * (1.0 - t)) + (b - c) * (2.0 * t)).normalized()


func clear_paths() -> void:
	for n in path_nodes:
		n.queue_free()
	path_nodes.clear()


func show_paths(i0: int, i1: int, only: String = "") -> void:
	clear_paths()
	for pid in PATH_COL:
		if only != "" and only != pid:
			continue
		var cp := curve(i0, i1, pid)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var s := SphereMesh.new()
		s.radius = 0.9
		s.height = 1.8
		s.radial_segments = 8
		s.rings = 4
		mm.mesh = s
		var pts: Array = []
		for k in 91:
			if k % 3 != 2:
				pts.append(bez(cp[0], cp[1], cp[2], float(k) / 90.0))
		mm.instance_count = pts.size()
		for k in pts.size():
			mm.set_instance_transform(k, Transform3D(Basis(), pts[k]))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = Gfx.unshaded_mat(PATH_COL[pid])
		root.add_child(mmi)
		path_nodes.append(mmi)


func update(dt: float, t: float) -> void:
	if not root.visible:
		return
	for s in spinners:
		(s.mesh as Node3D).rotation.y += s.speed * dt
	for o in orbiters:
		var a: float = o.phase + o.speed * t
		var pp: Vector3 = (o.parent as Node3D).position
		(o.m as Node3D).position = Vector3(pp.x + cos(a) * o.dist, pp.y + sin(a) * o.dist * o.incl, pp.z + sin(a) * o.dist)
	halo.look_at(camera.global_position, Vector3.UP)
	Gfx.set_glow_opacity(sun_glow1, 0.95 * (1.0 + sin(t * 0.8) * 0.02))
	var vp := label_host.get_viewport_rect().size
	for l in labels:
		var wp: Vector3 = (l.obj as Node3D).global_position + Vector3(0, l.yoff, 0)
		var dist := camera.global_position.distance_to(wp)
		var behind := camera.is_position_behind(wp)
		var sp := camera.unproject_position(wp)
		var ok: bool = (not behind) and dist < (1400.0 if l.major else 700.0) and dist > 6.0 and sp.x > -50 and sp.x < vp.x + 50 and sp.y > -50 and sp.y < vp.y + 50
		var el: Label = l.el
		el.visible = ok
		if ok:
			el.position = sp - Vector2(el.size.x * 0.5, el.size.y)
			el.modulate.a = clampf(1.6 - dist / 900.0, 0.25, 1.0)
