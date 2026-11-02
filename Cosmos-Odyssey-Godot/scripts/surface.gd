extends Node3D
## Planet surface scene: terrain, sky, landing, an astronaut and a short animation for each surface task.

const Gfx = preload("res://scripts/gfx.gd")

const THEMES := {
	"mars": {"ga": "b8683f", "gb": "8c4a2d", "rock": "7a4630", "sky_top": "7d6a60", "sky_hor": "e0b184", "fog": 0.0042, "fog_col": "d9a37a",
		"amb": "c79a78", "amb_e": 0.7, "sun_e": 1.5, "sun_col": "fff1dd", "relief": 1.0, "stars": false, "dust": "c48a62", "sun_glow": 0.0},
	"belt": {"ga": "86837f", "gb": "5c5a58", "rock": "6b6865", "sky_top": "", "fog": 0.0, "amb": "5f6473", "amb_e": 0.55, "sun_e": 2.4,
		"sun_col": "fff6ea", "relief": 1.5, "stars": true, "dust": "9a9792", "sun_glow": 70.0},
	"jupiter": {"ga": "dde8f2", "gb": "a8bdd2", "rock": "c7d6e6", "sky_top": "", "fog": 0.0, "amb": "6a7ea3", "amb_e": 0.75, "sun_e": 1.9,
		"sun_col": "fff6ea", "relief": 0.5, "stars": true, "dust": "e8f1fa", "sun_glow": 45.0, "sky_obj": "jupiter"},
	"comet": {"ga": "3a3631", "gb": "1f1c19", "rock": "2e2a26", "sky_top": "", "fog": 0.0, "amb": "4a4d5a", "amb_e": 0.5, "sun_e": 2.2,
		"sun_col": "fff2e0", "relief": 1.8, "stars": true, "dust": "5a544c", "sun_glow": 50.0},
	"pluto": {"ga": "dcc4b2", "gb": "b39690", "rock": "a38878", "sky_top": "", "fog": 0.0, "amb": "6e6478", "amb_e": 0.6, "sun_e": 1.3,
		"sun_col": "fff6ee", "relief": 0.8, "stars": true, "dust": "e6d3c5", "sun_glow": 14.0, "sky_obj": "charon"},
}

var cam: Camera3D
var env: Environment
var ship
var ui
var speed := 1.0
var theme: Dictionary = {}
var body_id := ""
var noise := FastNoiseLite.new()
var noise2 := FastNoiseLite.new()
var sun: DirectionalLight3D
var sun_glow: MeshInstance3D
var astro: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var props: Array = []
var spin_nodes: Array = []
var nodes: Array = []
var pad_h := 1.05
var idle := false
var idle_ang := 0.6
var shake := 0.0
var _saved := {}
var _cam_target := Vector3.ZERO
var _fog_boost := 0.0
var _spot_n := 0


func setup(cam_: Camera3D, env_: Environment, ship_, ui_) -> void:
	cam = cam_
	env = env_
	ship = ship_
	ui = ui_
	visible = false


# ------------------------------------------------------------ helpers

func _tw(dur: float, fn: Callable) -> void:
	var t := create_tween()
	t.tween_method(fn, 0.0, 1.0, maxf(0.01, dur / maxf(0.1, speed)))
	await t.finished


static func _ease(u: float) -> float:
	return 2.0 * u * u if u < 0.5 else 1.0 - pow(-2.0 * u + 2.0, 2.0) / 2.0


func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _ball(parent: Node3D, r: float, mat: Material, pos: Vector3, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	mi.mesh = s
	mi.material_override = mat
	mi.position = pos
	mi.scale = sc
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, r_top: float, r_bot: float, h: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = 12
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func height_at(x: float, z: float) -> float:
	var d := Vector2(x, z).length()
	var flat := smoothstep(16.0, 75.0, d)
	var rel: float = theme.relief
	var h := noise.get_noise_2d(x, z) * rel * 5.0
	h += (1.0 - absf(noise2.get_noise_2d(x, z))) * rel * 4.0
	h *= flat
	var far := maxf(0.0, d - 190.0) / 190.0
	h += pow(far, 1.5) * rel * 55.0 * (0.5 + absf(noise2.get_noise_2d(x * 2.0, z * 2.0)))
	return h


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, height_at(x, z), z)


# ------------------------------------------------------------ build

func _build_terrain() -> void:
	noise.seed = 11
	noise.frequency = 0.04
	noise2.seed = 23
	noise2.frequency = 0.011
	var n := 120
	var size := 720.0
	var ca := Color(theme.ga)
	var cb := Color(theme.gb)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in n + 1:
		for ix in n + 1:
			var x := (float(ix) / n - 0.5) * size
			var z := (float(iz) / n - 0.5) * size
			var t := clampf(noise2.get_noise_2d(x * 3.0, z * 3.0) * 0.5 + 0.5 + noise.get_noise_2d(x * 9.0, z * 9.0) * 0.18, 0.0, 1.0)
			st.set_color(ca.lerp(cb, t))
			st.add_vertex(Vector3(x, height_at(x, z), z))
	for iz in n:
		for ix in n:
			var a := iz * (n + 1) + ix
			var b := a + 1
			var c := a + n + 1
			var d := c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	mi.material_override = m
	add_child(mi)
	nodes.append(mi)


func _build_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Gfx.rock_mesh(40, 6, 10)
	var count := 220
	mm.instance_count = count
	for i in count:
		var a := rng.randf() * TAU
		var r := 7.0 + pow(rng.randf(), 0.7) * 170.0
		var p := _ground(cos(a) * r, sin(a) * r)
		var s := 0.2 + pow(rng.randf(), 3.0) * 2.4
		var b := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		b = b.scaled(Vector3(s * rng.randf_range(0.8, 1.4), s * rng.randf_range(0.5, 0.9), s * rng.randf_range(0.8, 1.3)))
		mm.set_instance_transform(i, Transform3D(b, p + Vector3(0, s * 0.2, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Gfx.std_mat(Color(theme.rock), 0.0, 1.0)
	add_child(mmi)
	nodes.append(mmi)


func _build_sky_objects() -> void:
	var kind: String = theme.get("sky_obj", "")
	if kind == "jupiter":
		var j := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 520.0
		sm.height = 1040.0
		sm.radial_segments = 48
		sm.rings = 24
		j.mesh = sm
		j.material_override = Gfx.planet_mat(3, 6.0, Color("d9b38c"), Color("a8714a"), Color("efe0c8"), 1.0, 26.0, 1.0)
		j.position = Vector3(-900, 750, -1500)
		add_child(j)
		nodes.append(j)
	elif kind == "charon":
		var c := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 230.0
		sm.height = 460.0
		sm.radial_segments = 32
		sm.rings = 16
		c.mesh = sm
		c.material_override = Gfx.planet_mat(0, 3.0, Color("8d8884"), Color("6f6a68"))
		c.position = Vector3(700, 520, -1200)
		add_child(c)
		nodes.append(c)


func _build_astronaut() -> void:
	astro = Node3D.new()
	var white := Gfx.std_mat(Color("f3f5f9"), 0.05, 0.6)
	var grey := Gfx.std_mat(Color("aab1bd"), 0.2, 0.6)
	var gold := Gfx.std_mat(Color("e0a73a"), 0.9, 0.1)
	var orange := Gfx.std_mat(Color("e8742a"), 0.1, 0.7)
	_box(astro, Vector3(0.62, 0.78, 0.4), white, Vector3(0, 1.25, 0))
	_box(astro, Vector3(0.5, 0.62, 0.28), grey, Vector3(0, 1.3, 0.32))
	_box(astro, Vector3(0.3, 0.22, 0.04), orange, Vector3(0, 1.3, -0.21))
	_ball(astro, 0.3, white, Vector3(0, 1.88, 0))
	_ball(astro, 0.26, gold, Vector3(0, 1.9, -0.1), Vector3(0.95, 0.72, 0.6))
	arm_l = Node3D.new()
	arm_l.position = Vector3(-0.42, 1.55, 0)
	_box(arm_l, Vector3(0.18, 0.62, 0.18), white, Vector3(0, -0.28, 0))
	_ball(arm_l, 0.11, grey, Vector3(0, -0.62, 0))
	astro.add_child(arm_l)
	arm_r = Node3D.new()
	arm_r.position = Vector3(0.42, 1.55, 0)
	_box(arm_r, Vector3(0.18, 0.62, 0.18), white, Vector3(0, -0.28, 0))
	_ball(arm_r, 0.11, grey, Vector3(0, -0.62, 0))
	astro.add_child(arm_r)
	leg_l = Node3D.new()
	leg_l.position = Vector3(-0.17, 0.85, 0)
	_box(leg_l, Vector3(0.23, 0.8, 0.25), white, Vector3(0, -0.4, 0))
	_box(leg_l, Vector3(0.27, 0.16, 0.38), grey, Vector3(0, -0.84, -0.05))
	astro.add_child(leg_l)
	leg_r = Node3D.new()
	leg_r.position = Vector3(0.17, 0.85, 0)
	_box(leg_r, Vector3(0.23, 0.8, 0.25), white, Vector3(0, -0.4, 0))
	_box(leg_r, Vector3(0.27, 0.16, 0.38), grey, Vector3(0, -0.84, -0.05))
	astro.add_child(leg_r)
	astro.scale = Vector3.ONE * 0.8
	astro.visible = false
	add_child(astro)
	nodes.append(astro)


# ------------------------------------------------------------ enter / leave

func _make_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for i in 2200:
		var v := Vector3(rng.randf() - 0.5, rng.randf() - 0.2, rng.randf() - 0.5).normalized() * 2600.0
		verts.append(v)
		var k := 0.55 + rng.randf() * 0.45
		cols.append(Color(k, k, k * 0.95))
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
	nodes.append(mi)


func enter(id: String) -> void:
	body_id = id
	theme = THEMES.get(id, THEMES["mars"])
	_saved = {"bg": env.background_mode, "col": env.background_color, "asrc": env.ambient_light_source, "acol": env.ambient_light_color,
		"aen": env.ambient_light_energy, "fog": env.fog_enabled, "fogd": env.fog_density, "fogc": env.fog_light_color, "sky": env.sky}
	_build_terrain()
	_build_rocks()
	_build_sky_objects()
	_build_astronaut()
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-22, -40, 0)
	sun.light_energy = theme.sun_e
	sun.light_color = Color(theme.sun_col)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)
	nodes.append(sun)
	if theme.sun_glow > 0.0:
		sun_glow = Gfx.glow(Color(theme.sun_col), theme.sun_glow * 14.0, 1.0)
		add_child(sun_glow)
		nodes.append(sun_glow)
	# environment
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(theme.amb)
	env.ambient_light_energy = theme.amb_e
	if theme.sky_top != "":
		var sky := Sky.new()
		var pm := ProceduralSkyMaterial.new()
		pm.sky_top_color = Color(theme.sky_top)
		pm.sky_horizon_color = Color(theme.sky_hor)
		pm.ground_horizon_color = Color(theme.sky_hor)
		pm.ground_bottom_color = Color(theme.gb)
		pm.sky_curve = 0.18
		sky.sky_material = pm
		env.sky = sky
		env.background_mode = Environment.BG_SKY
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color("02030a").srgb_to_linear()
	env.fog_enabled = theme.fog > 0.0
	env.fog_density = theme.fog
	env.fog_light_color = Color(theme.fog_col) if theme.fog > 0.0 else Color.BLACK
	if theme.stars:
		_make_stars()
	# ship on the pad
	var gi: Dictionary = ship.gear_info()
	pad_h = gi.h
	ship.visible = true
	ship.position = Vector3(0, 240.0, 0)
	ship.rotation = Vector3(0, 0.6, 0)
	ship.set_flame(0.0)
	ship.set_legs(0.0)
	ship.set_jets(0.0)
	visible = true
	idle = false
	_spot_n = 0
	cam.position = Vector3(60, 250, 90)
	_cam_target = Vector3(0, 240, 0)
	cam.look_at(_cam_target, Vector3.UP)


func leave() -> void:
	idle = false
	shake = 0.0
	cam.h_offset = 0.0
	cam.v_offset = 0.0
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()
	for p in props:
		if is_instance_valid(p):
			p.queue_free()
	nodes.clear()
	props.clear()
	spin_nodes.clear()
	sun = null
	sun_glow = null
	if not _saved.is_empty():
		env.background_mode = _saved.bg
		env.background_color = _saved.col
		env.ambient_light_source = _saved.asrc
		env.ambient_light_color = _saved.acol
		env.ambient_light_energy = _saved.aen
		env.fog_enabled = _saved.fog
		env.fog_density = _saved.fogd
		env.fog_light_color = _saved.fogc
		env.sky = _saved.sky
	ship.set_legs(0.0)
	ship.set_jets(0.0)
	visible = false


func _process(dt: float) -> void:
	if not visible:
		return
	for s in spin_nodes:
		if is_instance_valid(s.n):
			(s.n as Node3D).rotate_y(s.v * dt)
	if sun_glow != null and sun != null:
		sun_glow.global_position = cam.global_position + sun.global_transform.basis.z * 1400.0
	if _fog_boost > 0.0:
		env.fog_density = theme.fog + _fog_boost
	if idle:
		idle_ang += dt * 0.12 * minf(speed, 4.0)
		var c := Vector3(0, pad_h * 0.5, 0)
		cam.position = c + Vector3(sin(idle_ang) * 17.0, 3.2, cos(idle_ang) * 17.0)
		_cam_target = Vector3(0, pad_h + 0.2, 0)
		cam.look_at(_cam_target - Vector3(0, 1.6, 0), Vector3.UP)
	if shake > 0.0:
		shake = maxf(0.0, shake - dt * 1.4)
		cam.h_offset = randf_range(-1.0, 1.0) * shake
		cam.v_offset = randf_range(-1.0, 1.0) * shake
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


func _dust(at: Vector3, count: int = 40, power: float = 10.0) -> void:
	Gfx.burst(self, at, count, Color(theme.dust), power)


# ------------------------------------------------------------ landing and liftoff

func descent(rough: bool) -> void:
	idle = false
	ship.set_legs(0.0)
	await _tw(1.4, func(u: float):
		var e := _ease(u)
		ship.position = Vector3(0, lerpf(240.0, 150.0, e), 0)
		cam.position = Vector3(60, 250, 90).lerp(ship.position + Vector3(46, 16, 62), e)
		_cam_target = ship.position
		cam.look_at(_cam_target, Vector3.UP))
	ship.set_jets(0.0)
	var start := Vector3(ship.position)
	await _tw(5.2, func(u: float):
		var e := 1.0 - pow(1.0 - u, 2.4)
		var y := lerpf(start.y, pad_h, e)
		ship.position = Vector3(sin(u * 3.0) * (1.0 - u) * 4.0, y, 0)
		ship.rotation = Vector3(0.1 * (1.0 - u), 0.6, 0)
		ship.set_jets(clampf(u * 4.0, 0.0, 1.0) * (1.0 if u < 0.92 else (1.0 - (u - 0.92) / 0.08 * 0.2)))
		ship.set_legs(clampf((u - 0.55) / 0.3, 0.0, 1.0))
		var off := Vector3(46, 16, 62).lerp(Vector3(15, 3.0, 17), e)
		cam.position = ship.position + off
		_cam_target = ship.position + Vector3(0, -1.0, 0)
		cam.look_at(_cam_target, Vector3.UP))
	ship.position = Vector3(0, pad_h, 0)
	ship.rotation = Vector3(0, 0.6, 0)
	ship.set_legs(1.0)
	_dust(Vector3(0, 0.3, 0), 80, 18.0)
	_dust(Vector3(0, 0.4, 0), 50, 9.0)
	shake = 0.9 if rough else 0.35
	await _tw(0.9, func(u: float): ship.set_jets(1.0 - u))
	ship.set_jets(0.0)
	idle_ang = 0.5
	idle = true


func liftoff() -> void:
	idle = false
	var c0 := cam.position
	await _tw(0.8, func(u: float):
		ship.set_jets(u))
	_dust(Vector3(0, 0.3, 0), 90, 20.0)
	shake = 0.5
	await _tw(5.0, func(u: float):
		var e := u * u
		ship.position = Vector3(0, lerpf(pad_h, 260.0, e), 0)
		ship.set_legs(1.0 - clampf((u - 0.15) / 0.2, 0.0, 1.0))
		ship.set_jets(1.0 - clampf((u - 0.7) / 0.3, 0.0, 1.0))
		var off := Vector3(15, 3.0, 17).lerp(Vector3(40, 25, 55), u)
		cam.position = Vector3(c0.x, 0, c0.z).lerp(Vector3(off.x, 0, off.z), u) + Vector3(0, lerpf(c0.y, ship.position.y * 0.6 + off.y, u), 0)
		_cam_target = ship.position
		cam.look_at(_cam_target, Vector3.UP))
	ship.set_jets(0.0)
	ship.set_flame(0.2)


# ------------------------------------------------------------ astronaut and tasks

func _next_spot() -> Vector3:
	var angs := [0.9, 2.3, 3.9, 5.2, 1.6]
	var a: float = angs[_spot_n % angs.size()]
	_spot_n += 1
	var r := 10.5 + float(_spot_n % 3) * 2.0
	return _ground(sin(a) * r, cos(a) * r)


func _frame_cam(focus: Vector3, offset: Vector3, dur: float) -> void:
	var p0 := cam.position
	var t0 := _cam_target
	await _tw(dur, func(u: float):
		var e := _ease(u)
		cam.position = p0.lerp(focus + offset, e)
		_cam_target = t0.lerp(focus + Vector3(0, 1.2, 0), e)
		cam.look_at(_cam_target, Vector3.UP))


func _walk_to(target: Vector3, dur_per_unit: float = 0.22) -> void:
	var from := astro.position
	var flat := Vector3(target.x - from.x, 0, target.z - from.z)
	if flat.length() < 0.2:
		return
	astro.look_at(Vector3(target.x, astro.position.y, target.z), Vector3.UP)
	var dur := flat.length() * dur_per_unit
	await _tw(dur, func(u: float):
		var p := from.lerp(target, u)
		p.y = height_at(p.x, p.z)
		astro.position = p
		var ph := u * dur * 7.0 * speed
		leg_l.rotation.x = sin(ph) * 0.55
		leg_r.rotation.x = -sin(ph) * 0.55
		arm_l.rotation.x = -sin(ph) * 0.45
		arm_r.rotation.x = sin(ph) * 0.45)
	leg_l.rotation.x = 0.0
	leg_r.rotation.x = 0.0
	arm_l.rotation.x = 0.0
	arm_r.rotation.x = 0.0


func _ring_pulse(at: Vector3, col: Color, count: int = 3) -> void:
	for k in count:
		var mi := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 1.0
		c.bottom_radius = 1.0
		c.height = 0.03
		c.radial_segments = 32
		mi.mesh = c
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = col
		mi.material_override = m
		mi.position = at + Vector3(0, 0.1, 0)
		add_child(mi)
		props.append(mi)
		var tw := create_tween()
		tw.tween_method(func(u: float):
			mi.scale = Vector3(0.4 + u * 7.0, 1, 0.4 + u * 7.0)
			m.albedo_color = Color(col.r, col.g, col.b, (1.0 - u) * 0.8), 0.0, 1.0, 1.1 / maxf(0.1, speed))
		await get_tree().create_timer(0.55 / maxf(0.1, speed)).timeout


func _tripod(at: Vector3, top_h: float = 1.4) -> Node3D:
	var g := Node3D.new()
	g.position = at
	var metal := Gfx.std_mat(Color("b9bfca"), 0.6, 0.4)
	for k in 3:
		var a := TAU * k / 3.0
		var leg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.025
		cm.bottom_radius = 0.035
		cm.height = top_h * 1.1
		leg.mesh = cm
		leg.material_override = metal
		leg.position = Vector3(cos(a) * 0.32, top_h * 0.5, sin(a) * 0.32)
		leg.rotation = Vector3(-sin(a) * 0.25, 0, cos(a) * 0.25)
		g.add_child(leg)
	add_child(g)
	props.append(g)
	return g


## vis: sample, drill, mast, photo, lab, scan. found: whether a life search finds something.
func do_task(vis: String, found: bool) -> void:
	idle = false
	var spot := _next_spot()
	var door := Vector3(2.0, height_at(2.0, 1.0), 1.0)
	if not astro.visible:
		astro.position = door
		astro.visible = true
	await _walk_to(spot)
	await _frame_cam(spot, Vector3(5.2, 2.2, 6.2), 0.8)
	astro.look_at(Vector3(spot.x + 1.0, astro.position.y, spot.z), Vector3.UP)
	match vis:
		"drill":
			await _anim_drill(spot)
		"mast":
			await _anim_mast(spot)
		"photo":
			await _anim_photo(spot)
		"lab":
			await _anim_lab(spot, found)
		"scan":
			await _anim_scan(spot)
		_:
			await _anim_sample(spot)
	await _frame_cam(astro.position, Vector3(8.0, 2.8, 9.0), 0.6)
	await _walk_to(door)
	astro.visible = false
	idle = true


func _anim_sample(spot: Vector3) -> void:
	await _tw(0.6, func(u: float):
		astro.rotation.x = u * 0.7
		arm_r.rotation.x = -u * 1.1)
	for k in 3:
		await _tw(0.45, func(u: float): arm_r.rotation.x = -1.1 + sin(u * PI) * 0.7)
		_dust(spot + Vector3(0.8, 0.2, 0), 12, 3.0)
	var case_m := Gfx.std_mat(Color("e8b23a"), 0.4, 0.5)
	var c := _box(self, Vector3(0.4, 0.22, 0.3), case_m, spot + Vector3(0.9, 0.12, 0.2))
	props.append(c)
	await _tw(0.5, func(u: float):
		astro.rotation.x = 0.7 * (1.0 - u)
		arm_r.rotation.x = -1.1 * (1.0 - u))
	astro.rotation.x = 0.0


func _anim_drill(spot: Vector3) -> void:
	var rig := _tripod(spot + Vector3(1.4, 0, 0), 2.6)
	var metal := Gfx.std_mat(Color("d0d4dc"), 0.7, 0.35)
	var bit := Node3D.new()
	bit.position = Vector3(0, 2.8, 0)
	rig.add_child(bit)
	_cyl(bit, 0.1, 0.1, 2.4, metal, Vector3(0, 0, 0))
	_cyl(bit, 0.0, 0.14, 0.4, Gfx.std_mat(Color("6f7480"), 0.8, 0.3), Vector3(0, -1.3, 0))
	_box(rig, Vector3(0.5, 0.4, 0.5), Gfx.std_mat(Color("e8742a"), 0.2, 0.6), Vector3(0, 3.1, 0))
	await _tw(0.5, func(u: float): arm_r.rotation.x = -u * 0.9)
	var base := spot + Vector3(1.4, 0.1, 0)
	await _tw(3.2, func(u: float):
		bit.position.y = lerpf(2.8, 0.9, _ease(u))
		bit.rotation.y += 0.7
		if int(u * 40.0) % 8 == 0:
			_dust(base, 4, 2.5))
	_dust(base, 30, 6.0)
	await _tw(0.5, func(u: float): arm_r.rotation.x = -0.9 * (1.0 - u))
	arm_r.rotation.x = 0.0


func _anim_mast(spot: Vector3) -> void:
	var pole_root := Node3D.new()
	pole_root.position = spot + Vector3(1.3, 0, 0)
	add_child(pole_root)
	props.append(pole_root)
	var metal := Gfx.std_mat(Color("e6e9ef"), 0.6, 0.4)
	var pole := _cyl(pole_root, 0.05, 0.06, 3.6, metal, Vector3(0, 1.8, 0))
	pole_root.scale = Vector3(1, 0.05, 1)
	var cups := Node3D.new()
	cups.position = Vector3(0, 3.65, 0)
	pole_root.add_child(cups)
	_box(cups, Vector3(0.9, 0.04, 0.04), metal, Vector3.ZERO)
	_box(cups, Vector3(0.04, 0.04, 0.9), metal, Vector3.ZERO)
	for k in 4:
		var a := TAU * k / 4.0
		_ball(cups, 0.1, Gfx.std_mat(Color("e8742a"), 0.1, 0.6), Vector3(cos(a) * 0.45, 0.0, sin(a) * 0.45))
	spin_nodes.append({"n": cups, "v": 4.0})
	await _tw(0.5, func(u: float): arm_r.rotation.x = -u * 1.4)
	await _tw(1.8, func(u: float): pole_root.scale = Vector3(1, lerpf(0.05, 1.0, _ease(u)), 1))
	_ring_pulse(spot + Vector3(1.3, 0, 0), Color("9fd0ff"), 2)
	await get_tree().create_timer(0.9 / maxf(0.1, speed)).timeout
	await _tw(0.4, func(u: float): arm_r.rotation.x = -1.4 * (1.0 - u))
	arm_r.rotation.x = 0.0


func _anim_photo(spot: Vector3) -> void:
	await _tw(0.5, func(u: float):
		arm_r.rotation.x = -1.5 * u
		arm_l.rotation.x = -1.2 * u)
	for k in 3:
		await get_tree().create_timer(0.55 / maxf(0.1, speed)).timeout
		var g := Gfx.glow(Color("ffffff"), 3.0, 1.0)
		g.position = astro.position + Vector3(0, 1.6, -0.6).rotated(Vector3.UP, astro.rotation.y)
		add_child(g)
		props.append(g)
		if ui != null:
			ui.flash(Color(1, 1, 1, 0.45))
		var tw := create_tween()
		tw.tween_method(func(u: float): Gfx.set_glow_opacity(g, 1.0 - u), 0.0, 1.0, 0.4 / maxf(0.1, speed))
	await get_tree().create_timer(0.5 / maxf(0.1, speed)).timeout
	await _tw(0.4, func(u: float):
		arm_r.rotation.x = -1.5 * (1.0 - u)
		arm_l.rotation.x = -1.2 * (1.0 - u))


func _anim_lab(spot: Vector3, found: bool) -> void:
	var lab := Node3D.new()
	lab.position = spot + Vector3(1.3, 0, 0)
	add_child(lab)
	props.append(lab)
	_box(lab, Vector3(1.3, 0.6, 0.9), Gfx.std_mat(Color("c4cad6"), 0.4, 0.5), Vector3(0, 0.3, 0))
	_box(lab, Vector3(1.0, 0.04, 0.6), Gfx.std_mat(Color("22262e"), 0.2, 0.6), Vector3(0, 0.62, 0))
	var scr_m := StandardMaterial3D.new()
	scr_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	scr_m.albedo_color = Color("2a5a3a")
	_box(lab, Vector3(0.8, 0.02, 0.4), scr_m, Vector3(0, 0.66, 0))
	_cyl(lab, 0.03, 0.03, 0.9, Gfx.std_mat(Color("e6e9ef"), 0.6, 0.4), Vector3(0.55, 1.0, 0))
	await _tw(0.5, func(u: float):
		astro.rotation.x = u * 0.5
		arm_r.rotation.x = -u * 0.9)
	await _tw(2.8, func(u: float):
		var pulse := 0.5 + 0.5 * sin(u * 30.0)
		scr_m.albedo_color = Color("2a7a4a").lerp(Color("9fffc0"), pulse * 0.6)
		if u > 0.7:
			scr_m.albedo_color = Color("3dff8a") if found else Color("c87a2a"))
	if found:
		_ring_pulse(spot + Vector3(1.3, 0, 0), Color("5dff9e"), 3)
		var g := Gfx.glow(Color("5dff9e"), 5.0, 0.9)
		g.position = spot + Vector3(1.3, 1.0, 0)
		add_child(g)
		props.append(g)
		await get_tree().create_timer(1.2 / maxf(0.1, speed)).timeout
	await _tw(0.4, func(u: float):
		astro.rotation.x = 0.5 * (1.0 - u)
		arm_r.rotation.x = -0.9 * (1.0 - u))
	astro.rotation.x = 0.0
	arm_r.rotation.x = 0.0


func _anim_scan(spot: Vector3) -> void:
	var tri := _tripod(spot + Vector3(1.4, 0, 0), 1.5)
	_ball(tri, 0.22, Gfx.std_mat(Color("e8742a"), 0.3, 0.5), Vector3(0, 1.62, 0))
	_cyl(tri, 0.02, 0.02, 0.6, Gfx.std_mat(Color("e6e9ef"), 0.6, 0.4), Vector3(0, 2.0, 0))
	await _tw(0.5, func(u: float): arm_r.rotation.x = -u * 0.8)
	_ring_pulse(spot + Vector3(1.4, 0, 0), Color("ffb36a"), 4)
	await get_tree().create_timer(2.6 / maxf(0.1, speed)).timeout
	await _tw(0.4, func(u: float): arm_r.rotation.x = -0.8 * (1.0 - u))
	arm_r.rotation.x = 0.0


# ------------------------------------------------------------ hazards

func hazard_fx(kind: String) -> void:
	match kind:
		"dust":
			_dust(astro.position + Vector3(0, 1, 0) if astro.visible else Vector3(0, 1, 0), 70, 14.0)
			var tw := create_tween()
			tw.tween_method(func(u: float): _fog_boost = sin(u * PI) * 0.02, 0.0, 1.0, 2.2 / maxf(0.1, speed))
			tw.finished.connect(func(): _fog_boost = 0.0)
			shake = 0.25
		"quake":
			shake = 0.9
		"radiation":
			if ui != null:
				ui.flash(Color(0.4, 1.0, 0.4, 0.35))
		"equip":
			if ui != null:
				ui.flash(Color(1.0, 0.6, 0.2, 0.35))
			_dust(astro.position + Vector3(0, 1.4, 0) if astro.visible else Vector3(0, 1, 0), 24, 8.0)
		"cold":
			if ui != null:
				ui.flash(Color(0.5, 0.8, 1.0, 0.3))
		"thermal":
			_dust(astro.position + Vector3(0, 0.3, 0) if astro.visible else Vector3(0, 1, 0), 50, 12.0)
			shake = 0.6
			if ui != null:
				ui.flash(Color(1.0, 0.5, 0.2, 0.3))
