extends Node3D
## Game flow, ported from src/main.js. Everything runs as awaited coroutines, one step after another.
##
## Test options (after `--`):  --bot=smart|lazy|random|dumb   --speed=N   --skill=0..1   --shot=<name>

const Data = preload("res://scripts/data.gd")
const State = preload("res://scripts/state.gd")
const Events = preload("res://scripts/events.gd")
const Gfx = preload("res://scripts/gfx.gd")
const WorldScript = preload("res://scripts/world.gd")
const Landing = preload("res://scripts/landing.gd")
const SurfaceScript = preload("res://scripts/surface.gd")
const ShipScript = preload("res://scripts/ship.gd")
const CorridorScript = preload("res://scripts/corridor.gd")
const UIScript = preload("res://scripts/ui.gd")
const AudioScript = preload("res://scripts/audio.gd")

var cam: Camera3D
var env: Environment
var world
var ship
var surface
var corridor
var ui
var audio
var s            # mission State
var speed := 1.0
var bot := ""
var bot_skill := 0.75
var shot := ""
var uitest := false
var preview_ship := false
var engine_view := "rear"
var engine_level := 1.0
var _last_leg_field := false
var _last_leg_flare := false
var _flares_used := 0
var _fields_used := 0
var preview_dy := 0.6
var preview_light: DirectionalLight3D
var ship_arg := ""
var snap_every := 0.0
var _ui_clock := 0.0
var _ui_step := 0
var _snap_clock := 0.0
var _snap_n := 0
var t_abs := 0.0

# camera
var cam_mode := "free"     # free | chase
var orbit_on := false
var cam_target := Vector3.ZERO
var cam_yaw := 0.0
var cam_pitch := 0.3
var cam_dist := 100.0
var chase_tan := Vector3(0, 0, -1)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bot="):
			bot = a.substr(6)
		elif a.begins_with("--speed="):
			speed = float(a.substr(8))
		elif a.begins_with("--skill="):
			bot_skill = float(a.substr(8))
		elif a.begins_with("--shot="):
			shot = a.substr(7)
		elif a.begins_with("--eview="):
			engine_view = a.substr(8)
		elif a.begins_with("--elevel="):
			engine_level = float(a.substr(9))
		elif a.begins_with("--ship="):
			ship_arg = a.substr(7)
		elif a == "--uitest":
			uitest = true
		elif a.begins_with("--snap="):
			snap_every = float(a.substr(7))
	get_window().title = "Cosmos: Odyssey '2000"

	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0b1024").srgb_to_linear()   # slightly lifted so it reads on a projector
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.48, 0.66)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = false
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	cam = Camera3D.new()
	cam.fov = 55.0
	cam.near = 0.1
	cam.far = 8000.0
	cam.position = Vector3(140, 60, 90)
	add_child(cam)
	cam.current = true

	ui = UIScript.new()
	ui.speed = speed
	add_child(ui)
	world = WorldScript.new()
	add_child(world)
	world.setup(cam, ui.labels_host)
	preview_light = DirectionalLight3D.new()
	preview_light.rotation_degrees = Vector3(-28, 35, 0)
	preview_light.light_energy = 1.6
	preview_light.visible = false
	add_child(preview_light)
	ship = ShipScript.new()
	if ship_arg != "":
		ship.model = ship_arg
	add_child(ship)
	surface = SurfaceScript.new()
	add_child(surface)
	surface.setup(cam, env, ship, ui)
	surface.speed = speed
	corridor = CorridorScript.new()
	add_child(corridor)
	corridor.setup(cam, ship, env)
	audio = AudioScript.new()
	add_child(audio)
	ui.sound_toggled.connect(func():
		ui.sound_btn.text = "Sound: " + ("on" if audio.toggle() else "off"))

	var fresh := State.new([])
	ui.update_hud(fresh)
	ui.update_subs(fresh)
	if bot != "":
		ui.auto = Callable(self, "_bot_ai")
	if shot != "":
		_debug_shot(shot)
	else:
		game()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var w := get_window()
		w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
	if not orbit_on or corridor.active:
		return
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		cam_yaw -= event.relative.x * 0.006
		cam_pitch = clampf(cam_pitch + event.relative.y * 0.006, -1.4, 1.4)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist * 0.9, 6.0, 400.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist * 1.1, 6.0, 400.0)


func _load_ship() -> String:
	if ship_arg != "":
		return ship_arg
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		return str(cf.get_value("game", "ship", "orbiter"))
	return "orbiter"


func _load_cfg() -> Dictionary:
	var out: Dictionary = Data.SHIP_DEFAULT.duplicate()
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		var saved = cf.get_value("game", "ship_cfg", {})
		if saved is Dictionary:
			for k in saved:
				out[k] = saved[k]
	return out


func _save_cfg(c: Dictionary) -> void:
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	cf.set_value("game", "ship_cfg", c)
	cf.save("user://settings.cfg")


func _save_ship(id: String) -> void:
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	cf.set_value("game", "ship", id)
	cf.save("user://settings.cfg")


func _process(delta: float) -> void:
	var dt := minf(0.05, delta)
	t_abs += dt
	preview_light.visible = preview_ship or shot == "shipclean" or shot == "engine"
	if preview_ship:
		ship.position = Vector3(0, 1.6, 0)
		ship.rotation = Vector3(0.18, ship.rotation.y + dt * 0.6, 0)
		cam.position = Vector3(0, 3.0, 11.5)
		cam.look_at(Vector3(0, preview_dy, 0), Vector3.UP)
	if uitest:
		_ui_clock += delta
		if _ui_clock > 0.7 / speed:
			_ui_clock = 0.0
			var keys := [KEY_1, KEY_2, KEY_3, KEY_8, KEY_ENTER]
			var ev := InputEventKey.new()
			ev.keycode = keys[_ui_step % keys.size()]
			ev.physical_keycode = ev.keycode
			ev.pressed = true
			_ui_step += 1
			Input.parse_input_event(ev)
	if snap_every > 0.0:
		_snap_clock += delta
		if _snap_clock > snap_every:
			_snap_clock = 0.0
			_snap_n += 1
			get_viewport().get_texture().get_image().save_png("/tmp/ui_%02d.png" % _snap_n)
	if corridor.active:
		corridor.update(dt * speed)
	else:
		world.update(dt, t_abs)
		if cam_mode == "chase":
			var want: Vector3 = ship.position + chase_tan * -13.0 + Vector3(0, 4.5, 0)
			cam.position = cam.position.lerp(want, 1.0 - exp(-3.0 * dt * minf(speed, 6.0)))
			cam.look_at(ship.position + chase_tan * 14.0, Vector3.UP)
		elif orbit_on:
			_apply_orbit()
	if s != null:
		ship.update_look(s.h, s.known_shield, t_abs)
	else:
		ship.update_look({"hull": 100, "arrays": 100, "thrusters": 100, "sensors": 100, "comms": 100, "life": 100, "shield": 100}, 100, t_abs)


# ---------------- camera helpers ----------------

func _apply_orbit() -> void:
	var off := Vector3(cos(cam_pitch) * sin(cam_yaw), sin(cam_pitch), cos(cam_pitch) * cos(cam_yaw)) * cam_dist
	cam.position = cam_target + off
	cam.look_at(cam_target, Vector3.UP)


func _sync_orbit() -> void:
	var off := cam.position - cam_target
	cam_dist = clampf(off.length(), 6.0, 400.0)
	if off.length() < 0.001:
		return
	cam_yaw = atan2(off.x, off.z)
	cam_pitch = asin(clampf(off.y / off.length(), -1.0, 1.0))


static func ease_f(u: float) -> float:
	return 2.0 * u * u if u < 0.5 else 1.0 - pow(-2.0 * u + 2.0, 2.0) / 2.0


func _tw(dur: float, fn: Callable) -> void:
	var t := create_tween()
	t.tween_method(fn, 0.0, 1.0, maxf(0.01, dur / speed))
	await t.finished


func cam_to(pos: Vector3, target: Vector3, dur: float = 2.2) -> void:
	cam_mode = "free"
	orbit_on = false
	var p0 := cam.position
	var t0 := cam_target
	await _tw(dur, func(u: float):
		var e := ease_f(u)
		cam.position = p0.lerp(pos, e)
		cam_target = t0.lerp(target, e)
		cam.look_at(cam_target, Vector3.UP))
	_sync_orbit()
	orbit_on = true


func place_ship(p: Vector3, tan_v: Vector3) -> void:
	ship.position = p
	ship.look_at(p + tan_v, Vector3.UP)
	chase_tan = tan_v


# ---------------- small helpers ----------------

func refresh() -> void:
	if s != null:
		ui.update_hud(s)
		ui.update_subs(s)


## Returns true if the mission has just failed.
func guard() -> bool:
	s.power = mini(100, s.power)
	refresh()
	s.check_fail()
	return s.failed != ""


func with_diff(fn: Callable) -> Variant:
	var before: Dictionary = s.h.duplicate()
	var r = fn.call()
	var lines: Array = []
	for x in Data.SUBS:
		if x.id != "shield" and before[x.id] > s.h[x.id]:
			lines.append("%s −%d%%" % [x.name, before[x.id] - s.h[x.id]])
	if lines.size() > 0:
		ui.toast(" · ".join(PackedStringArray(lines)), "bad")
		ui.flash()
		audio.warn()
	refresh()
	return r


func pick_random(a: Array) -> Variant:
	return a[randi() % a.size()]


# ---------------- legs of the journey ----------------

func pick_path(i: int) -> String:
	ui.cue(Data.CUE.suspense)
	var from := i - 1
	world.show_paths(from, i)
	var ov: Dictionary = world.overview(from, i)
	await cam_to(ov.pos, ov.target, 2.0)
	var cols := {"fast": "#ff7a5c", "normal": "#6ee7a0", "ellipse": "#6aa8ff"}
	var opts: Array = []
	for pid in Data.PATHS:
		var p: Dictionary = Data.PATHS[pid]
		var c: Dictionary = s.path_cost(p)
		var sub := "power −%d · %d days" % [c.power, c.days]
		if p.note != "":
			sub += " · " + p.note
		opts.append({"id": pid, "dot": cols[pid], "label": p.label, "sub": sub,
			"disabled": c.power >= s.power})
	var all_off := true
	for o in opts:
		if not o.disabled:
			all_off = false
	if all_off:
		for o in opts:
			o.disabled = false
	var pid: String = await ui.choose("path", "Next stop: " + Data.STOPS[i].name,
		"Choose your route (shown on the map). Faster burns cost more power and meet faster asteroids. Weak thrusters make every route cost more.", opts)
	world.show_paths(from, i, pid)
	return pid


func sail(cp: Array, u0: float, u1: float, dur: float) -> void:
	cam_mode = "chase"
	orbit_on = false
	ship.set_flame(1.0)
	await _tw(dur, func(u: float):
		var k := u0 + (u1 - u0) * ease_f(u)
		place_ship(WorldScript.bez(cp[0], cp[1], cp[2], k), WorldScript.bez_tan(cp[0], cp[1], cp[2], k)))


func leg_events(i: int) -> Array:
	# Fewer events per leg, and each kind is limited so nothing repeats too often.
	var n := 1 if i == 1 else (2 if randf() < 0.35 else 1)
	var list: Array = []
	if i == 2:
		list.append("belt")
	if i == 3:
		list.append("powerdrop")
	var had_field := list.has("belt")
	var had_flare := false
	while list.size() < n:
		var cand: Array = ["malfunction", "malfunction"]
		if _flares_used < 2 and not _last_leg_flare and not had_flare:
			cand.append("flare")
		if _fields_used < 2 and not _last_leg_field and not had_field:
			cand.append("corridor")
		var pick: String = cand[randi() % cand.size()]
		if list.has(pick):
			break
		list.append(pick)
		if pick == "flare":
			had_flare = true
		if pick == "corridor":
			had_field = true
	if list.is_empty():
		list.append("malfunction")
	if had_flare:
		_flares_used += 1
	if list.has("corridor"):
		_fields_used += 1
	_last_leg_flare = had_flare
	_last_leg_field = had_field
	list.shuffle()
	return list


## Returns true if the mission failed during this leg.
func travel_leg(from: int, i: int, pid: String) -> bool:
	var c: Dictionary = s.path_cost(Data.PATHS[pid])
	s.power -= c.power
	s.days += c.days
	if guard():
		return true
	var cp: Array = world.curve(from, i, pid)
	var plan := leg_events(i)
	var segs := plan.size() + 1
	place_ship(cp[0], WorldScript.bez_tan(cp[0], cp[1], cp[2], 0.0))
	for k in segs:
		await sail(cp, float(k) / segs, float(k + 1) / segs, 3.4)
		if k < plan.size():
			await run_event(plan[k], pid)
			if guard():
				return true
	ship.set_flame(0.15)
	return false


func run_event(type: String, pid: String) -> void:
	ui.cue(Data.CUE.suspense)
	match type:
		"corridor": await corridor_event(pid, false)
		"belt": await corridor_event(pid, true)
		"flare": await flare_event()
		"malfunction": await malfunction_event()
		"powerdrop": await power_drop_event()


func choice_event(ev: Dictionary) -> void:
	var pick: String = await ui.choose(ev.id, ev.title, ev.text, ev.options)
	var valid := false
	for o in ev.options:
		if o.id == pick:
			valid = true
	if not valid:
		pick = ev.options[0].id
	var text: String = with_diff(func(): return Events.run_option(ev.id, pick, s))
	ui.toast(text, "good")
	guard()


func flare_event() -> void:
	ui.flash(Color(1, 0.82, 0.35, 0.5))
	await choice_event(Events.FLARE)


func malfunction_event() -> void:
	await choice_event(pick_random(Events.MALFUNCTIONS))


func power_drop_event() -> void:
	var units: int = s.power_units()
	audio.alarm()
	ui.flash(Color(1, 0.24, 0.16, 0.3))
	var extra := " (array damage cut this from 30)" if s.h.arrays < 100 else ""
	var r: Dictionary = await ui.power_panel(units, Events.POWER_SYSTEMS, 14.0,
		"The arrays can only supply [b]%d[/b] power units right now%s. Choose which systems stay on before time runs out. Going over the limit trips the breakers." % [units, extra])
	var res: Dictionary = with_diff(func(): return Events.resolve_power_drop(s, r.chosen, r.timed_out))
	if guard():
		return
	await ui.say("Power stabilised" if res.tone == "good" else "Power drop result", "\n".join(PackedStringArray(res.notes)))


func corridor_event(pid: String, belt: bool) -> void:
	var sensors: int = s.h.sensors
	var thr: int = s.h.thrusters
	var notes: Array = []
	if sensors < 85:
		notes.append("Sensors at %d%%: you will see rocks later (thicker fog)." % sensors)
	if thr < 85:
		notes.append("Thrusters at %d%%: steering is slower." % thr)
	if notes.is_empty():
		notes.append("Your ship is in good shape, so sensors and steering are at full strength.")
	var posture: String = await ui.choose("posture", "Asteroid Belt ahead" if belt else "Asteroid field ahead",
		"Fly through by hand. [b]Arrow keys / WASD[/b], or hold the mouse button and drag. Hits damage the part that gets hit, and that damage stays with you.\n[color=#a9b9dd]%s[/color]" % " ".join(PackedStringArray(notes)),
		[
			{"id": "shield", "label": "Raise debris shields", "sub": "power −4 · hits do 40% less damage"},
			{"id": "thrust", "label": "Thrusters ready", "sub": "power −4 · steering 30% stronger"},
			{"id": "hold", "label": "Hold course", "sub": "free · no changes"},
		])
	if posture != "hold":
		s.power -= 4
		if guard():
			return
	var sp: float = Data.PATHS[pid].speed
	var save_xf: Transform3D = ship.transform
	world.set_world_visible(false)
	orbit_on = false
	cam_mode = "free"
	ui.mini_text("Steer: arrow keys / WASD / controller stick · or hold mouse and drag")
	var bot_mode := ""
	if bot != "":
		bot_mode = "dumb" if bot == "dumb" else "smart"
	var res: Dictionary = await corridor.run_field({
		"speed": sp * (0.9 if belt else 1.0),
		"count": 96 if belt else 60,
		"size_mul": 1.15 if belt else 1.0,
		"spawn_time": 24.0 if belt else 18.0,
		"aimed": 0.4 if belt else 0.33,
		"bot_skill": bot_skill,
		"pilot": s.has("pilot"),
		"thrust_boost": posture == "thrust",
		"shield_posture": posture == "shield",
		"bot": bot_mode,
		"get_params": func(): return {"thr": s.thruster_factor(), "sens": s.sensor_factor()},
		"should_abort": func(): return s.check_fail() != "",
		"on_hit": func(loc: String, amount: int, _size: float):
			audio.thud()
			with_diff(func():
				if loc == "centre":
					s.damage("hull", roundi(amount * 0.6), "Asteroid hit the nose")
					if randf() < 0.7:
						s.damage("shield", roundi(amount * 1.3), "Asteroid struck the heat shield")
				elif loc == "arrays":
					s.damage("arrays", amount, "Asteroid hit the solar arrays")
				elif loc == "sensors":
					s.damage("sensors", amount, "Asteroid hit the sensor boom")
				else:
					s.damage("thrusters", amount, "Asteroid hit the thrusters")
				return null),
		"on_tick": func(t: Dictionary):
			var n := roundi(t.progress * 10.0)
			ui.mini_text("Hits: %d · Warning range: %d m · %s%s" % [t.hits, t.vis, "▮".repeat(n), "▯".repeat(10 - n)]),
	})
	ui.mini_text("")
	world.set_world_visible(true)
	ship.transform = save_xf
	corridor.visible = false
	ui.toast("Asteroid field cleared: %d hit%s, %d dodged" % [res.hits, "" if res.hits == 1 else "s", res.dodged], "bad" if res.hits > 0 else "good")
	guard()


func arrive(i: int) -> void:
	var st: Dictionary = Data.STOPS[i]
	cam_mode = "free"
	var v: Dictionary = world.view(i)
	await cam_to(v.pos, v.target, 2.4)
	ui.cue(Data.CUE.intermission)
	var leak: int = s.leak_check()
	var extra := ""
	if Data.SOLAR.has(st.id):
		var gain := roundi(Data.SOLAR[st.id] * s.solar_factor())
		s.power = mini(100, s.power + gain)
		extra += "\n[color=#a9b9dd]Solar panels recharged power by %d%s.[/color]" % [gain, " (damaged arrays collect less)" if s.h.arrays < 70 else ""]
	if leak > 0:
		extra += "\n[color=#a9b9dd]The damaged hull is leaking air: life support −%d%%.[/color]" % leak
	if guard():
		return
	await ui.say(st.name, st.fact + extra)
	if st.id == "comet":
		await comet_special()
	if st.id == "blackhole":
		await blackhole_special()
	guard()


func comet_special() -> void:
	var pick: String = await ui.choose("comet", "Comet flyby", "The comet is releasing gas and dust. How close do you fly?", [
		{"id": "close", "label": "Close pass", "sub": "power −6 · 2 days · lots of science · dust may hit the ship"},
		{"id": "far", "label": "Safe distance", "sub": "power −2 · less science"},
		{"id": "skip", "label": "Skip", "sub": "free"},
	])
	if pick == "close":
		s.power -= 6
		s.days += 2
		var g: int = s.scan_gain(16)
		s.science += g
		ui.toast("Close pass: science +%d" % g, "good")
		if randf() < 0.5:
			with_diff(func():
				s.damage("sensors", 12, "Comet dust hit the sensors")
				s.damage("shield", 10, "Comet dust pitted the heat shield")
				return null)
	elif pick == "far":
		s.power -= 2
		var g: int = s.scan_gain(8)
		s.science += g
		ui.toast("Distant study: science +%d" % g, "good")
		if randf() < 0.1:
			with_diff(func():
				s.damage("sensors", 6, "Stray comet dust")
				return null)


func blackhole_special() -> void:
	var pick: String = await ui.choose("blackhole", "Black hole decision (simulation)",
		"This is a \"what if\" simulation. Real black holes are far from our Solar System. Close to one, time and light behave strangely, and radiation is intense.", [
			{"id": "study", "label": "Study it", "sub": "10 days · big science · radiation will damage arrays, sensors and comms"},
			{"id": "sling", "label": "Slingshot", "sub": "55%: save 10 days and gain power · 45%: thrusters and hull strained"},
			{"id": "away", "label": "Turn away", "sub": "free · nothing gained, nothing lost"},
		])
	if pick == "study":
		s.days += 10
		var g: int = s.scan_gain(24)
		s.science += g
		ui.toast("Science +%d" % g, "good")
		with_diff(func():
			s.damage("arrays", 15, "Black hole radiation hit the arrays")
			s.damage("sensors", 15, "Black hole radiation hit the sensors")
			s.damage("comms", 10, "Black hole radiation hit the comms")
			return null)
	elif pick == "sling":
		if randf() < 0.55:
			s.days = maxi(0, s.days - 10)
			s.power = mini(100, s.power + 8)
			ui.toast("Perfect slingshot: 10 days saved, power +8", "good")
		else:
			with_diff(func():
				s.damage("thrusters", 20, "Slingshot strained the thrusters")
				s.damage("hull", 10, "Tidal stress on the hull")
				return null)


func hub(i: int) -> void:
	var st: Dictionary = Data.STOPS[i]
	var scanned := false
	var landed := false
	while true:
		cam_mode = "free"
		orbit_on = true
		var rep: Dictionary = s.repair_info()
		var opts: Array = []
		if st.has("scan") and not scanned:
			opts.append({"id": "scan", "label": "Scan the area", "sub": "power −8 · gives science"})
		if Landing.has_landing(st.id) and not landed:
			opts.append({"id": "land", "label": "Land on %s" % Landing.BODIES[st.id].body, "sub": "power −6 · 1 day · surface tasks, search for life", "disabled": s.power < 30})
		opts.append({"id": "repair", "label": "Repair a system", "sub": "power −%d · restores %d%%" % [rep.cost, rep.amount]})
		opts.append({"id": "inspect", "label": "Inspect the heat shield", "sub": "power −2 · 2 days · last inspected: %s" % ("never" if s.shield_checked_day < 0 else "day %d" % s.shield_checked_day)})
		opts.append({"id": "depart", "label": "Depart for the next stop", "sub": ""})
		var pick: String = await ui.choose("hub", st.name, "Parked. You can drag to look around. What now?", opts)
		if pick == "depart":
			return
		if pick == "scan":
			s.power -= 8
			var g: int = s.scan_gain(st.scan.base)
			s.science += g
			scanned = true
			ui.toast("%s Science +%d" % [st.scan.text, g], "good")
		elif pick == "land":
			landed = true
			await land(i)
		elif pick == "inspect":
			var before: int = s.known_shield
			var real: int = s.inspect_shield()
			if real < before - 3:
				ui.toast("Heat shield inspected: %d%%. Hidden damage found!" % real, "bad")
			else:
				ui.toast("Heat shield inspected: %d%%. No new damage." % real, "good")
		elif pick == "repair":
			var ropts: Array = []
			for x in Data.SUBS:
				var shown: int = s.known_shield if x.id == "shield" else s.h[x.id]
				ropts.append({"id": x.id, "label": x.name, "sub": ("last known %d" % shown if x.id == "shield" else "%d" % shown) + "%",
					"disabled": x.id != "shield" and s.h[x.id] >= 100})
			ropts.append({"id": "cancel", "label": "Cancel", "sub": ""})
			var target: String = await ui.choose("repair", "Repair which system?", "Costs %d power." % rep.cost, ropts)
			if target != "cancel":
				if s.power <= rep.cost:
					ui.toast("Not enough power for a repair.", "bad")
				else:
					var blind: bool = target == "shield" and s.known_shield != s.h.shield
					s.repair(target)
					if blind:
						ui.toast("Heat shield repaired, but its true condition is unknown until you inspect it.", "good")
					else:
						ui.toast("%s repaired." % State.sub_name(target), "good")
		if guard():
			return


func land(i: int) -> void:
	var st: Dictionary = Data.STOPS[i]
	var info: Dictionary = Landing.BODIES[st.id]
	var sopts: Array = []
	for k in info.sites.size():
		var si: Dictionary = info.sites[k]
		sopts.append({"id": str(k), "label": si.name, "sub": "%s · %s" % [Landing.risk_label(si.risk), si.note]})
	sopts.append({"id": "cancel", "label": "Stay in orbit", "sub": ""})
	var pick: String = await ui.choose("site", "Land on %s" % info.body, "Choose a landing site. Riskier terrain can need a harder descent. Good thrusters, sensors and comms make a safe landing more likely.", sopts)
	if pick == "cancel":
		return
	var site: Dictionary = info.sites[int(pick)]
	s.power -= 6
	s.days += 1
	var vis_on: bool = bot == "" and shot == ""
	var skill: float = (0.5 * s.h.thrusters + 0.3 * s.h.sensors + 0.2 * s.h.comms) / 100.0 + (0.1 if s.has("pilot") else 0.0)
	var fail: float = clampf(site.risk * (1.6 - skill * 1.2), 0.03, 0.8)
	var hard: bool = randf() < fail
	if vis_on:
		cam_mode = "free"
		orbit_on = false
		world.set_world_visible(false)
		surface.speed = speed
		surface.enter(st.id)
		await surface.descent(hard)
	audio.thud()
	if hard:
		var dh: int = s.damage("hull", float(randi_range(8, 18)), "Hard landing on %s" % info.body)
		var dt: int = s.damage("thrusters", float(randi_range(4, 12)), "Hard landing on %s" % info.body)
		refresh()
		await ui.say("Hard landing", "The ship came down too fast at %s. Hull −%d%%, thrusters −%d%%." % [site.name, dh, dt])
	else:
		refresh()
		await ui.say("Touchdown", "Smooth landing at %s on %s." % [site.name, info.body])
	if guard():
		_leave_surface()
		return
	var done := {}
	var life_hits := 0
	while true:
		var topts: Array = []
		for t in site.tasks:
			if done.has(t.id):
				continue
			var gain: int = s.scan_gain(t.sci)
			topts.append({"id": t.id, "label": t.label, "sub": "power %s%d · %d day%s · about +%d science" % ["+" if t.power < 0 else "−", absi(t.power), t.days, "" if t.days == 1 else "s", gain],
				"disabled": s.power < t.power + 14})
		topts.append({"id": "leave", "label": "Return to orbit", "sub": "power −6 · 1 day · needs working thrusters"})
		var tp: String = await ui.choose("surface", "On the surface: %s" % site.name, "Each task can be done once. Keep at least 14 power in reserve to lift off.", topts)
		if tp == "leave":
			break
		var task: Dictionary = {}
		for t in site.tasks:
			if t.id == tp:
				task = t
		done[tp] = true
		var found := false
		if task.has("life") and randf() < float(task.life):
			found = true
		var hz := ""
		if randf() < float(task.hazard[1]):
			hz = task.hazard[0]
		if vis_on:
			await surface.do_task(Landing.VIS.get(task.id, "sample"), found)
		s.power -= task.power
		s.days += task.days
		var g: int = s.scan_gain(task.sci)
		s.science += g
		var msg: String = "%s Science +%d." % [task.text, g]
		if found:
			s.science += 20
			life_hits += 1
			msg += " Possible sign of life found: science +20. This would need confirmation by other teams."
		ui.toast(msg, "good")
		if hz != "":
			if vis_on:
				surface.hazard_fx(hz)
			var hm: String = Landing.hazard(s, hz, info.body)
			if hm != "":
				ui.toast(hm, "bad")
		if guard():
			_leave_surface()
			return
	var tries := 0
	while true:
		tries += 1
		s.power -= 6
		s.days += 1
		var up_fail: float = clampf((100.0 - float(s.h.thrusters)) / 110.0, 0.0, 0.7)
		if randf() >= up_fail:
			break
		var d2: int = s.damage("thrusters", float(randi_range(4, 8)), "Failed liftoff from %s" % info.body)
		ui.toast("Liftoff attempt failed. Thrusters −%d%%." % d2, "bad")
		if tries >= 3 or s.power <= 5:
			s.failed = "The ship could not lift off from %s and the crew was stranded." % info.body
			_leave_surface()
			refresh()
			return
	if vis_on:
		await surface.liftoff()
		surface.leave()
		world.set_world_visible(true)
		var vw: Dictionary = world.view(i)
		cam.position = vw.pos
		cam_target = vw.target
		cam.look_at(cam_target, Vector3.UP)
		_sync_orbit()
		orbit_on = true
		cam_mode = "free"
		place_ship(world.park_pos(i), Vector3(0, 0, -1).rotated(Vector3.UP, 0.6))
		ship.set_flame(0.2)
	refresh()
	await ui.say("Back in orbit", "The ship lifted off from %s.%s" % [info.body, (" Possible life signs found: %d." % life_hits) if life_hits > 0 else ""])
	guard()


func _leave_surface() -> void:
	if surface.visible:
		surface.leave()
		world.set_world_visible(true)


func finale() -> void:
	ui.cue(Data.CUE.ending)
	var known: int = s.known_shield
	var never := " - never inspected!" if s.shield_checked_day < 0 else ""
	var pick: String = await ui.choose("reentry", "Choose your re-entry angle",
		"Last decision. Heat shield (last known): [b]%d%%[/b]%s. Comms: [b]%d%%[/b]. A shallow angle is gentler but needs good guidance from comms." % [known, never, s.h.comms], [
			{"id": "standard", "label": "Standard angle", "sub": "no change"},
			{"id": "shallow", "label": "Shallow and slow", "sub": "less heat, but needs comms of 60% or more"},
			{"id": "steep", "label": "Steep and fast", "sub": "more heat: risky for a weak shield, a little safer for a strong one"},
		])
	var mod := 0.0
	if pick == "shallow":
		mod = 8.0 if s.h.comms >= 60 else -12.0
	elif pick == "steep":
		mod = 4.0 if s.h.shield >= 60 else -10.0
	var out: Dictionary = s.reentry(mod)
	var earth: Vector3 = world.body_pos(7)
	var start_p: Vector3 = ship.position
	var dir := (start_p - earth).normalized()
	var end_p: Vector3 = earth + dir * (world.body_radius(7) + 1.2)
	cam_mode = "chase"
	orbit_on = false
	ship.set_flame(0.3)
	await _tw(6.0, func(u: float):
		var e := ease_f(u)
		place_ship(start_p.lerp(end_p, e), -dir)
		ship.set_plasma(maxf(0.0, (u - 0.45) / 0.5))
		if u > 0.6:
			cam.position += Vector3(randf() - 0.5, randf() - 0.5, 0) * 0.25)
	if out.tier == "lost":
		Gfx.burst(self, ship.position, 140, Color("ffa050"), 16.0)
		ship.visible = false
		ui.flash(Color(1, 1, 1, 0.7))
		audio.thud()
	else:
		ui.flash(Color(1, 1, 1, 0.3))
		audio.ok()
	ship.set_plasma(0.0)
	await end_report(out.tier, "", out)


const TIER_TEXT := {
	"perfect": ["Perfect landing!", "The heat shield held and you landed softly. Mission control erupts."],
	"hard": ["Hard landing", "The shield held, but the landing was rough. Everyone walked away."],
	"ballistic": ["Ballistic re-entry", "The crew survived a brutal, steep entry, but the ship was lost."],
	"lost": ["Heat shield failed", "The shield could not protect the ship. The mission is lost."],
}


func end_report(tier: String, fail_reason: String, out) -> void:
	var won := fail_reason == "" and tier != "lost"
	var score: int = 0 if fail_reason != "" else s.score(tier)
	var result := {"won": won, "tier": tier, "fail_reason": fail_reason, "score": score, "h": s.h.duplicate(),
		"power": s.power, "days": s.days, "science": s.science, "hits_logged": s.history.size()}
	if out != null:
		result["integrity"] = out.integrity
	print("RESULT ", JSON.stringify(result))
	ui.hide_all()
	var head: Array = ["Mission failed", fail_reason] if fail_reason != "" else TIER_TEXT[tier]
	var tcol := "#ff6b5a" if (fail_reason != "" or tier == "lost") else ("#5fd68a" if tier == "perfect" else "#f0c24b")
	var chain_rows: Array = s.damage_chain()
	var chain := ""
	for x in chain_rows:
		chain += "• " + x + "\n"
	if chain == "":
		chain = "• No major damage. A clean flight!\n"
	var eff := ""
	for x in s.effect_lines():
		eff += "• " + x + "\n"
	var table := ""
	for x in Data.SUBS:
		var note := ""
		if x.id == "shield" and s.known_shield != s.h[x.id]:
			note = " (you believed %d%%)" % s.known_shield
		table += "• %s: [b]%d%%[/b]%s\n" % [x.name, s.h[x.id], note]
	var bb := "[font_size=40][color=%s][b]%s[/b][/color][/font_size]\n%s\n\n" % [tcol, head[0], head[1]]
	bb += "[font_size=26][b]%d[/b] score    [b]%d[/b] days    [b]%d[/b] science    [b]%d[/b] power left[/font_size]\n\n" % [score, s.days, s.science, s.power]
	bb += "[b]How your damage carried over[/b]\n%s\n" % chain
	if eff != "":
		bb += "[b]What that cost you[/b]\n%s\n" % eff
	bb += "[b]Final ship condition (true values)[/b]\n%s\n" % table
	bb += "[b]What this teaches[/b]\nEarly damage does not go away. A hit in the first asteroid field can shorten your warning in the next one, and a heat shield nobody inspected can end the mission on the last day. Real spacecraft face the same problem: Parker Solar Probe has no temperature sensor on the front of its heat shield, so engineers must rely on models and careful checks."
	if bot != "":
		get_tree().quit()
		return
	if uitest:
		get_tree().create_timer(2.0).timeout.connect(func(): get_tree().quit())
	ui.report(bb, "Play again", func(): get_tree().reload_current_scene())


# ---------------- main loop ----------------

func game() -> void:
	await ui.title_screen("COSMOS: ODYSSEY '2000",
		"Fly a spacecraft from Earth to the edge of the Solar System and bring it home. Every hit you take stays with the ship and changes what happens next.\n\n• Fly through asteroid fields by hand (arrow keys / WASD, or hold the mouse and drag).\n• Make quick choices when systems fail or power drops.\n• The heat shield cannot be seen from inside. Inspect it, or gamble.\n\n[color=#a9b9dd]Tip: number keys pick options, Enter continues, F11 toggles fullscreen.\nController: D-pad or left stick to move, A to select, Start to continue. In asteroid fields the left stick or D-pad steers.[/color]", "Begin")
	if Input.get_connected_joypads().size() > 0:
		ui.toast("Controller connected: %s" % Input.get_joy_name(Input.get_connected_joypads()[0]), "good")
	ship.visible = true
	world.set_world_visible(false)
	preview_ship = true
	var chosen: String = await ui.ship_select(Data.SHIPS, _load_ship(), func(id: String):
		if id == "custom":
			ship.set_custom(_load_cfg())
		else:
			ship.set_model(id))
	if chosen == "custom":
		preview_dy = -1.5
		var c: Dictionary = await ui.ship_builder(_load_cfg(), Data.SHIP_OPTS, func(c2: Dictionary): ship.set_custom(c2))
		preview_dy = 0.6
		_save_cfg(c)
		ship.set_custom(c)
	preview_ship = false
	if chosen != "custom" and chosen != ship.model:
		ship.set_model(chosen)
	_save_ship(chosen)
	ship.rotation = Vector3.ZERO
	var crew: Array = await ui.crew_select(Data.CREW)
	s = State.new(crew)
	_flares_used = 0
	_fields_used = 0
	_last_leg_field = false
	_last_leg_flare = false
	refresh()
	ship.visible = true
	world.set_world_visible(true)
	ui.cue(Data.CUE.start)
	var v0: Dictionary = world.view(0)
	cam.position = v0.pos + Vector3(30, 14, 30)
	cam_target = v0.target
	cam.look_at(cam_target, Vector3.UP)
	var park: Vector3 = world.park_pos(0)
	place_ship(park, Vector3(0, 0, -1).rotated(Vector3.UP, 0.6))
	ship.set_flame(0.2)
	await cam_to(v0.pos, v0.target, 3.0)
	Events.launch_debris(s)
	refresh()
	await ui.say("Launch complete", "You are in orbit around Earth. During launch, cameras saw foam debris fly past the nose. Engineers cannot tell whether it struck the heat shield. (This is how the Columbia accident started in 2003.)")
	await hub(0)
	if s.failed == "":
		for i in range(1, Data.STOPS.size()):
			var pid: String = await pick_path(i)
			world.clear_paths()
			if await travel_leg(i - 1, i, pid):
				break
			await arrive(i)
			if s.failed != "":
				break
			if i < Data.STOPS.size() - 1:
				await hub(i)
				if s.failed != "":
					break
	if s.failed != "":
		audio.thud()
		await end_report("lost", s.failed, null)
	else:
		await finale()


# ---------------- bot player (for automated testing) ----------------

var _hub_count := 0
var _last_hub := -1

func _bot_ai(kind: String, p: Dictionary) -> Variant:
	if kind == "say":
		return null
	if kind == "crew":
		if bot == "random":
			var ids: Array = []
			for c in Data.CREW:
				ids.append(c.id)
			ids.shuffle()
			return ids.slice(0, 3)
		return ["pilot", "engineer", "medic"]
	if kind == "power":
		if bot == "dumb":
			var all: Array = []
			for x in p.systems:
				all.append(x.id)
			return all
		var prio := ["life", "shield", "thrusters", "comms", "lab"]
		var out: Array = []
		var used := 0
		var units: int = s.power_units()
		for id in prio:
			for x in p.systems:
				if x.id == id and used + x.cost <= units:
					out.append(id)
					used += x.cost
		return out
	# choose
	var opts: Array = p.options
	var ids: Array = []
	for o in opts:
		ids.append(o.id)
	var enabled: Array = opts.filter(func(o): return not o.get("disabled", false))
	if enabled.is_empty():
		enabled = opts
	if bot == "random" or bot == "dumb":
		if p.id == "hub":
			return "depart" if (bot == "dumb" or randf() < 0.5) else pick_random(ids)
		return pick_random(enabled).id
	match p.id:
		"path": return "ellipse" if s.power < 45 else "normal"
		"posture": return "shield" if s.power > 40 else "hold"
		"site": return ids[0]
		"surface":
			for o in enabled:
				if o.id != "leave" and s.power > 70:
					return o.id
			return "leave"
		"hub":
			if bot == "lazy":
				return "depart"
			if _last_hub != s.days:
				_hub_count = 0
				_last_hub = s.days
			_hub_count += 1
			var weak := 0
			for x in Data.SUBS:
				if x.id != "shield" and x.id != "life" and s.h[x.id] < 60:
					weak += 1
			if ids.has("scan") and s.power > 60 and _hub_count < 2:
				return "scan"
			if ids.has("land") and s.power > 92 and s.h.thrusters > 60 and _hub_count < 3:
				return "land"
			var need_inspect: bool = s.shield_checked_day < 0
			for l in s.history:
				if l.sub == "shield" and l.day >= s.shield_checked_day:
					need_inspect = true
			if need_inspect and s.power > 30 and _hub_count < 3:
				return "inspect"
			if (weak > 0 or s.known_shield < 80) and s.power > 35 and _hub_count < 5:
				return "repair"
			return "depart"
		"repair":
			if s.known_shield < 80:
				return "shield"
			var worst = null
			for x in Data.SUBS:
				if x.id != "shield" and s.h[x.id] < 100:
					if worst == null or s.h[x.id] < s.h[worst]:
						worst = x.id
			return worst if worst != null else "cancel"
		"reentry": return "shallow" if (s.h.comms >= 60 and s.known_shield < 90) else "standard"
		"comet": return "close" if s.power > 50 else "far"
		"blackhole": return "sling" if (s.power > 40 and s.h.thrusters > 70) else "away"
	return enabled[0].id


# ---------------- debug screenshots (used during development) ----------------

func _debug_shot(name: String) -> void:
	await get_tree().process_frame
	s = State.new(["pilot", "engineer", "medic"])
	refresh()
	ship.visible = true
	world.set_world_visible(true)
	var stop_for := {"earth": 0, "mars": 1, "belt": 2, "jupiter": 3, "comet": 4, "pluto": 5, "blackhole": 6}
	if stop_for.has(name):
		var i: int = stop_for[name]
		var v: Dictionary = world.view(i)
		cam.position = v.pos
		cam_target = v.target
		cam.look_at(cam_target, Vector3.UP)
		place_ship(world.park_pos(i), Vector3(0, 0, -1).rotated(Vector3.UP, 0.6))
		ship.set_flame(0.2)
		await get_tree().create_timer(1.0).timeout
	elif name == "overview":
		cam.position = Vector3(0, 900, 700)
		cam.look_at(Vector3.ZERO, Vector3.UP)
		ship.visible = false
		await get_tree().create_timer(1.0).timeout
	elif name == "shipselect":
		world.set_world_visible(false)
		ship.visible = true
		preview_ship = true
		ship.rotation.y = 2.4
		if ship_arg == "custom":
			preview_dy = -1.5
			ui.ship_builder(Data.SHIP_DEFAULT.duplicate(), Data.SHIP_OPTS, func(c2: Dictionary): ship.set_custom(c2))
		else:
			ui.ship_select(Data.SHIPS, ship_arg if ship_arg != "" else "orbiter", func(id: String): ship.set_model(id))
		await get_tree().create_timer(0.6).timeout
	elif name == "shipclean":
		ui.visible = false
		world.set_world_visible(false)
		preview_light.visible = true
		ship.visible = true
		ship.position = Vector3.ZERO
		ship.rotation = Vector3(0.12, 0.9 if ship_arg == "probe" else 2.5, 0)
		cam.position = Vector3(0, 2.6, 10.5)
		cam.look_at(Vector3.ZERO, Vector3.UP)
		ship.set_flame(1.0)
		await get_tree().create_timer(0.5).timeout
	elif name == "joy":
		ui.crew_select(Data.CREW)
		await get_tree().create_timer(0.3).timeout
		var seq := [[JOY_BUTTON_DPAD_DOWN, 0], [JOY_BUTTON_A, 0], [JOY_BUTTON_DPAD_DOWN, 0], [JOY_BUTTON_DPAD_DOWN, 0], [JOY_BUTTON_A, 0]]
		for st in seq:
			var ev := InputEventJoypadButton.new()
			ev.button_index = st[0]
			ev.pressed = true
			Input.parse_input_event(ev)
			await get_tree().create_timer(0.15).timeout
	elif name == "engine":
		ui.visible = false
		world.set_world_visible(false)
		preview_light.visible = true
		ship.visible = true
		ship.position = Vector3.ZERO
		ship.rotation = Vector3.ZERO
		var side := engine_view == "side"
		cam.position = Vector3(7.5, 1.0, 3.0) if side else Vector3(2.5, 1.6, 8.5)
		cam.look_at(Vector3(0, 0, 3.0), Vector3.UP)
		ship.set_flame(engine_level)
		await get_tree().create_timer(0.6).timeout
	elif name == "shiphealthy":
		ship.position = Vector3.ZERO
		ship.rotation = Vector3(0.1, 2.5, 0)
		cam.position = Vector3(7.0, 3.5, 8.0)
		cam.look_at(Vector3.ZERO, Vector3.UP)
		world.set_world_visible(false)
		ship.set_flame(1.0)
		await get_tree().create_timer(0.5).timeout
	elif name == "ship":
		s.h.hull = 55
		s.h.arrays = 35
		s.h.sensors = 40
		s.h.thrusters = 50
		s.known_shield = 30
		ship.position = Vector3.ZERO
		ship.rotation = Vector3(0.2, 2.4, 0)
		cam.position = Vector3(5.5, 3.0, 6.0)
		cam.look_at(Vector3.ZERO, Vector3.UP)
		world.set_world_visible(false)
		ship.set_flame(1.0)
		await get_tree().create_timer(0.5).timeout
	elif name == "path":
		world.show_paths(0, 1)
		var ov: Dictionary = world.overview(0, 1)
		cam.position = ov.pos
		cam.look_at(ov.target, Vector3.UP)
		await get_tree().create_timer(0.5).timeout
	elif name == "corridor":
		world.set_world_visible(false)
		ship.rotation = Vector3.ZERO
		corridor.run_field({"speed": 56.0, "count": 44, "bot": "smart", "bot_skill": 0.0, "pilot": false, "thrust_boost": false, "shield_posture": false,
			"get_params": func(): return {"thr": 1.0, "sens": 0.5},
			"should_abort": func(): return false, "on_hit": func(_l, _a, _z): pass,
			"on_tick": func(t): ui.mini_text("Hits: %d · Warning range: %d m" % [t.hits, t.vis])})
		await get_tree().create_timer(14.0 / maxf(1.0, speed)).timeout
	elif name == "dialog":
		world.set_world_visible(true)
		var v: Dictionary = world.view(3)
		cam.position = v.pos
		cam_target = v.target
		cam.look_at(cam_target, Vector3.UP)
		place_ship(world.park_pos(3), Vector3(0, 0, -1))
		ui.cue(Data.CUE.suspense)
		ui.toast("Mission start. Science +12", "good")
		ui.choose("path", "Next stop: Mars", "Choose your route (shown on the map).", [
			{"id": "fast", "dot": "#ff7a5c", "label": "Fast burn", "sub": "power −10 · 15 days · faster asteroids"},
			{"id": "normal", "dot": "#6ee7a0", "label": "Normal route", "sub": "power −7 · 25 days"}])
		await get_tree().create_timer(1.0).timeout
	elif name.begins_with("landing"):
		var bid := "mars"
		var tasks_seq: Array = []
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--body="):
				bid = a.substr(7)
			if a.begins_with("--seq="):
				tasks_seq = a.substr(6).split(",")
		world.set_world_visible(false)
		cam_mode = "free"
		orbit_on = false
		surface.speed = speed
		surface.enter(bid)
		var which := name.substr(7)
		if which == "":
			await get_tree().create_timer(0.4).timeout
			await surface.descent(false)
			await get_tree().create_timer(0.6).timeout
		elif which == "mid":
			surface.speed = 1.0
			surface.descent(false)
			await get_tree().create_timer(5.2).timeout
		else:
			surface.speed = 6.0
			await surface.descent(false)
			surface.speed = 1.0
			var vis: String = which
			surface.do_task(vis, true)
			await get_tree().create_timer(float(OS.get_environment("SHOTWAIT") if OS.get_environment("SHOTWAIT") != "" else "6.0")).timeout
	elif name == "routecheck":
		for i in range(1, Data.STOPS.size()):
			for pid in Data.PATHS:
				var cp: Array = world.curve(i - 1, i, pid)
				var mn := 1e9
				for k in range(0, 101):
					var p: Vector3 = WorldScript.bez(cp[0], cp[1], cp[2], float(k) / 100.0)
					for o in world.obstacles:
						mn = minf(mn, p.distance_to(o.pos) - o.r)
				print("ROUTE ", i, " ", pid, " min clearance ", snappedf(mn, 0.1))
		get_tree().quit()
		return
	elif name == "report":
		s.days = 212
		s.science = 41
		s.power = 18
		s.damage("shield", 34, "Foam debris hit the heat shield at launch")
		s.damage("sensors", 18, "Asteroid hit the sensor boom")
		s.damage("arrays", 40, "Black hole radiation hit the arrays")
		s.damage("hull", 22, "Asteroid hit the nose")
		s.known_shield = 100
		end_report("hard", "", {"integrity": 71})
		await get_tree().create_timer(0.5).timeout
	elif name == "powerdrop":
		ui.power_panel(24, Events.POWER_SYSTEMS, 14.0, "The arrays can only supply [b]24[/b] power units right now. Choose which systems stay on before time runs out.")
		await get_tree().create_timer(0.5).timeout
	elif name == "crew":
		ui.crew_select(Data.CREW)
		await get_tree().create_timer(0.5).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var path := "/tmp/shot_%s.png" % name
	img.save_png(path)
	print("SHOT saved ", path, " ", img.get_size())
	get_tree().quit()
