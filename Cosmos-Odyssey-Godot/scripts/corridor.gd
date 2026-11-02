extends Node3D
## Hand-flown asteroid corridor (arrow keys / WASD, controller stick, or hold the mouse and drag).
## Ported from src/corridor.js: fixed-step physics, fog that depends on sensor health,
## damage localised to the part of the ship that gets hit.

const Gfx = preload("res://scripts/gfx.gd")
const PAD_DEADZONE := 0.22
const PAD_GAIN := 0.8   # controller steering strength (1.0 = as fast as the keyboard)
const BX := 15.0
const BY := 8.5
const SPAWN_Z := -290.0
const POOL := 130

signal finished(result)

var active := false
var camera: Camera3D
var ship: Node3D
var env: Environment
var rocks: Array = []
var streaks: MeshInstance3D
var streak_mesh: ImmediateMesh
var sx: Array = []
var sy: Array = []
var sz: Array = []
var run: Dictionary = {}
var shake := 0.0
var time := 0.0
var fog_color := Color("0b1024").srgb_to_linear()


func setup(cam: Camera3D, ship_node: Node3D, environment: Environment) -> void:
	camera = cam
	ship = ship_node
	env = environment
	visible = false
	var dl := DirectionalLight3D.new()
	dl.light_color = Color("fff0dd")
	dl.light_energy = 2.2
	dl.rotation_degrees = Vector3(-48, -35, 0)
	add_child(dl)

	var meshes: Array = []
	for k in 3:
		meshes.append(Gfx.rock_mesh(100 + k * 7, 7, 12))
	var mats: Array = []
	for c in ["6e655d", "5d554f", "7b7167"]:
		mats.append(Gfx.std_mat(Color(c), 0.0, 1.0))
	for i in POOL:
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[i % 3]
		mi.material_override = mats[i % 3]
		mi.visible = false
		add_child(mi)
		rocks.append({"m": mi, "active": false, "r": 1.0, "hit": false, "passed": false, "spin": Vector3.ZERO})

	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in 110:
		var a := rng.randf() * TAU
		var r := 6.0 + rng.randf() * 24.0
		sx.append(cos(a) * r)
		sy.append(sin(a) * r * 0.7)
		sz.append(-230.0 + rng.randf() * 250.0)
	streak_mesh = ImmediateMesh.new()
	streaks = MeshInstance3D.new()
	streaks.mesh = streak_mesh
	streaks.material_override = Gfx.unshaded_mat(Color(0.56, 0.64, 0.85, 0.6))
	streaks.extra_cull_margin = 1000.0
	streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(streaks)


func _rand(a: float, b: float) -> float:
	return randf_range(a, b)


func _gauss() -> float:
	return (randf() + randf() + randf() - 1.5) / 1.5


func _spawn(o: Dictionary, ship_x: float, ship_y: float) -> void:
	var slot = null
	for k in rocks:
		if not k.active:
			slot = k
			break
	if slot == null:
		return
	var r: float = (0.7 + pow(randf(), 2.2) * 1.6) * o.size_mul
	var x := 0.0
	var y := 0.0
	if randf() < o.aimed:
		x = ship_x + _gauss() * 4.0
		y = ship_y + _gauss() * 2.5
	else:
		x = _rand(-BX - 3.0, BX + 3.0)
		y = _rand(-BY - 2.0, BY + 2.0)
	slot.active = true
	slot.hit = false
	slot.passed = false
	slot.r = r
	var m: MeshInstance3D = slot.m
	m.position = Vector3(x, y, SPAWN_Z)
	m.scale = Vector3(r * _rand(0.8, 1.4), r * _rand(0.6, 1.0), r * _rand(0.8, 1.4))
	m.rotation = Vector3(_rand(0, TAU), _rand(0, TAU), _rand(0, TAU))
	m.visible = true
	slot.spin = Vector3(_rand(-1, 1), _rand(-1, 1), _rand(-1, 1))
	run.spawned += 1


func _bot_input(o: Dictionary, s: Dictionary) -> Array:
	if o.bot == "dumb":
		return [0.0, 0.0]
	if time < run.bot_until:
		return run.bot_target
	if randf() > o.bot_skill:
		run.bot_until = time + 0.5
		run.bot_target = [randf() * 2.0 - 1.0, randf() * 2.0 - 1.0]
		return run.bot_target
	var vis: float = 1.52 / run.dens
	var best_cost := INF
	var bgx := 0.0
	var bgy := 0.0
	var gx := -BX
	while gx <= BX:
		var gy := -BY
		while gy <= BY:
			var cost := Vector2(gx - s.x, gy - s.y).length() * 0.25
			for k in rocks:
				if not k.active or k.hit:
					continue
				var p: Vector3 = k.m.position
				if p.z < -vis or p.z > 4.0:
					continue
				var dx: float = (p.x - gx) / (k.r * 0.8 + 2.9)
				var dy: float = (p.y - gy) / (k.r * 0.8 + 1.5)
				var d2 := dx * dx + dy * dy
				if d2 < 1.6:
					cost += (1.6 - d2) * 40.0 / (1.0 + absf(p.z) / 40.0)
			if cost < best_cost:
				best_cost = cost
				bgx = gx
				bgy = gy
			gy += 3.0
		gx += 3.0
	return [clampf((bgx - s.x) / 3.0, -1.0, 1.0), clampf((bgy - s.y) / 3.0, -1.0, 1.0)]


func _step(h: float) -> void:
	var o: Dictionary = run.o
	var par: Dictionary = o.get_params.call()
	var thr: float = par.thr
	var sens: float = par.sens
	run.dens = 0.005 + (1.0 - sens) * 0.02
	env.fog_density = run.dens
	var s: Dictionary = run.ship
	time += h

	var ix := 0.0
	var iy := 0.0
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		ix += 1.0
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		ix -= 1.0
	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
		iy += 1.0
	if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
		iy -= 1.0
	var pad_active := false
	for pad in Input.get_connected_joypads():
		var stick := Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), -Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
		var mag := stick.length()
		if mag > PAD_DEADZONE:
			# remap deadzone..1 to 0..1, then a curve so small tilts give fine control
			var t := clampf((mag - PAD_DEADZONE) / (1.0 - PAD_DEADZONE), 0.0, 1.0)
			t = (0.25 * t + 0.75 * t * t * t) * PAD_GAIN
			stick = stick.normalized() * t
			pad_active = true
		else:
			stick = Vector2.ZERO
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_RIGHT):
			stick.x += 0.6
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_LEFT):
			stick.x -= 0.6
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_UP):
			stick.y += 0.6
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_DOWN):
			stick.y -= 0.6
		ix = clampf(ix + stick.x, -1.0, 1.0)
		iy = clampf(iy + stick.y, -1.0, 1.0)
	if ix == 0.0 and iy == 0.0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var vp := get_viewport()
		var mp := vp.get_mouse_position()
		var size := vp.get_visible_rect().size
		var px := (mp.x / size.x) * 2.0 - 1.0
		var py := -((mp.y / size.y) * 2.0 - 1.0)
		ix = clampf((px * BX - s.x) / 4.0, -1.0, 1.0)
		iy = clampf((py * BY - s.y) / 3.0, -1.0, 1.0)
	if o.bot != "":
		var bi := _bot_input(o, s)
		ix = bi[0]
		iy = bi[1]

	var max_v: float = 21.0 * thr * (1.25 if o.pilot else 1.0) * (1.3 if o.thrust_boost else 1.0)
	var resp := minf(1.0, (3.0 if pad_active else 5.0) * thr * h)
	s.vx += (ix * max_v - s.vx) * resp
	s.vy += (iy * max_v * 0.8 - s.vy) * resp
	s.x = clampf(s.x + s.vx * h, -BX, BX)
	s.y = clampf(s.y + s.vy * h, -BY, BY)

	run.spawn_clock += h
	while run.spawned < o.count and run.spawn_clock >= (float(run.spawned) / o.count) * o.spawn_time:
		_spawn(o, s.x, s.y)

	for k in rocks:
		if not k.active:
			continue
		var m: MeshInstance3D = k.m
		var prev := m.position.z
		m.position.z += o.speed * h
		var pz := m.position.z
		m.rotation.x += k.spin.x * h
		m.rotation.y += k.spin.y * h
		if not k.hit:
			var zmin := minf(prev, pz)
			var zmax := maxf(prev, pz)
			if zmax >= -1.8 and zmin <= 2.0:
				var dx: float = m.position.x - s.x
				var dy: float = m.position.y - s.y
				var ex: float = k.r * 0.8 + 2.4
				var ey: float = k.r * 0.8 + 1.0
				if pow(dx / ex, 2.0) + pow(dy / ey, 2.0) < 1.0:
					k.hit = true
					var loc := "centre"
					if absf(dx) > 1.5 and absf(dx) > absf(dy) * 1.2:
						loc = "arrays"
					elif dy > 0.55:
						loc = "sensors"
					elif dy < -0.55:
						loc = "thrusters"
					var amount := roundi((5.0 + k.r * 3.2) * (0.6 if o.shield_posture else 1.0) * (0.85 + randf() * 0.3))
					run.hits += 1
					shake = 1.0
					Gfx.burst(self, Vector3(s.x + dx * 0.4, s.y + dy * 0.4, -1.0), 34, Color("ffb070"), 14.0)
					o.on_hit.call(loc, amount, k.r)
					k.active = false
					m.visible = false
					if o.should_abort.call():
						run.abort = true
					continue
		if not k.passed and pz > 3.0 and not k.hit:
			k.passed = true
			run.dodged += 1
		if pz > 22.0:
			k.active = false
			m.visible = false

	var any_active := false
	for k in rocks:
		if k.active:
			any_active = true
			break
	if run.spawned >= o.count and not any_active:
		run.end_timer += h
	if run.abort or run.end_timer > 1.0:
		_finish()


func _visuals(dt: float) -> void:
	var s: Dictionary = run.ship
	ship.position = Vector3(s.x, s.y, 0)
	ship.rotation = Vector3(s.vy * 0.025, 0, -s.vx * 0.04)
	shake = maxf(0.0, shake - dt * 2.2)
	var sh := shake * shake * 0.5
	camera.position = Vector3(s.x * 0.55 + (randf() - 0.5) * sh, s.y * 0.55 + 3.4 + (randf() - 0.5) * sh, 13.5)
	camera.look_at(Vector3(s.x * 0.35, s.y * 0.35 + 0.4, -26.0), Vector3.UP)
	var spd: float = run.o.speed
	var length := 0.9 + spd * 0.05
	streak_mesh.clear_surfaces()
	streak_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in sx.size():
		sz[i] += spd * 1.15 * dt
		if sz[i] > 18.0:
			sz[i] = -230.0
		streak_mesh.surface_add_vertex(Vector3(sx[i], sy[i], sz[i]))
		streak_mesh.surface_add_vertex(Vector3(sx[i], sy[i], sz[i] - length * 3.0))
	streak_mesh.surface_end()
	run.o.on_tick.call({
		"hits": run.hits,
		"progress": minf(1.0, float(run.spawned) / run.o.count),
		"vis": roundi(1.52 / run.dens),
	})


func _finish() -> void:
	if not active:
		return
	active = false
	visible = false
	env.fog_enabled = false
	var res := {"hits": run.hits, "dodged": run.dodged, "aborted": run.abort}
	run = {}
	finished.emit(res)


## Coroutine: returns {hits, dodged, aborted} once the field has been flown.
func run_field(opts: Dictionary) -> Dictionary:
	var o := {"size_mul": 1.0, "aimed": 0.35, "spawn_time": 18.0, "bot": ""}
	o.merge(opts, true)
	for k in rocks:
		k.active = false
		(k.m as Node3D).visible = false
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	visible = true
	run = {"o": o, "bot_until": 0.0, "bot_target": [0.0, 0.0], "ship": {"x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0},
		"hits": 0, "dodged": 0, "spawned": 0, "spawn_clock": 0.0, "end_timer": 0.0, "dens": 0.006, "abort": false}
	time = 0.0
	shake = 0.0
	active = true
	ship.position = Vector3.ZERO
	ship.rotation = Vector3.ZERO
	_visuals(0.0)
	var res = await finished
	return res


func update(dt: float) -> void:
	if not active or run.is_empty():
		return
	var rem := dt
	while rem > 0.000001 and active:
		var h := minf(0.03, rem)
		_step(h)
		rem -= h
	if active:
		_visuals(dt)
