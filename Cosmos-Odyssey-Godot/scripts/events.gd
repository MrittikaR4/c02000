extends RefCounted
## Random events, ported from src/events.js.
## Each event is {id,title,text,options:[{id,label,sub}]}; run_option() resolves a choice.

const State = preload("res://scripts/state.gd")

const MALFUNCTIONS := [
	{"id": "tracker", "title": "Dust blinds a star tracker",
		"text": "A micro-impact kicked up a dust cloud that blinded one of your star trackers. Without it the ship is unsure which way it is pointing. (Parker Solar Probe has this problem.)",
		"options": [
			{"id": "backup", "label": "Switch to the backup tracker", "sub": "power −6 · small damage"},
			{"id": "recal", "label": "Recalibrate in place", "sub": "power −2 · 3 days · medium damage"},
			{"id": "ignore", "label": "Ignore it", "sub": "free · big damage risk"}]},
	{"id": "patch", "title": "Software patch in progress",
		"text": "A software update is half-loaded when an instrument asks to restart. (This really happened to Parker in 2023.) Do you roll back or push through?",
		"options": [
			{"id": "rollback", "label": "Roll the patch back", "sub": "2 days · safe"},
			{"id": "push", "label": "Push the patch through", "sub": "55% better science, 45% comms fault"}]},
	{"id": "coolant", "title": "Solar array cooling fault",
		"text": "The water cooling loop for the solar arrays is overheating. Left alone, the panels can cook. (Parker uses about one gallon of water to cool its arrays.)",
		"options": [
			{"id": "cut", "label": "Cut array power to cool down", "sub": "power −10 · small damage"},
			{"id": "run", "label": "Keep running at full power", "sub": "50% chance of heavy damage"}]},
	{"id": "upset", "title": "Radiation upsets the computer",
		"text": "A charged particle flipped a bit in the main computer. The ship needs a decision about whether to reboot.",
		"options": [
			{"id": "reboot", "label": "Reboot the computer", "sub": "1 day · small comms damage"},
			{"id": "wait", "label": "Wait and watch", "sub": "35% chance of a bad crash"}]},
	{"id": "valve", "title": "Thruster valve sticks",
		"text": "A valve in one of the steering thrusters is sticking open and wasting fuel.",
		"options": [
			{"id": "routine", "label": "Run the valve repair routine", "sub": "power −4 · small damage"},
			{"id": "work", "label": "Work around it", "sub": "free · bigger damage"}]},
	{"id": "breach", "title": "Micrometeoroid hits the hull",
		"text": "A tiny rock punched a small hole in the hull. Air is leaking slowly.",
		"options": [
			{"id": "patch", "label": "Patch it now", "sub": "power −3 · small damage"},
			{"id": "later", "label": "Deal with it later", "sub": "free · bigger damage"}]},
]

const FLARE := {
	"id": "flare", "title": "Solar flare!",
	"text": "A solar flare is coming. Radiation is rising fast. Radiation can damage electronics and crew.",
	"options": [
		{"id": "shelter", "label": "Shelter in the shielded core", "sub": "power −8, 6 days · small damage"},
		{"id": "carry", "label": "Carry on", "sub": "free · heavy radiation damage"}],
}

const POWER_SYSTEMS := [
	{"id": "life", "name": "Life support", "cost": 15},
	{"id": "shield", "name": "Debris shields", "cost": 10},
	{"id": "thrusters", "name": "Thrusters", "cost": 10},
	{"id": "comms", "name": "Comms", "cost": 5},
	{"id": "lab", "name": "Science lab", "cost": 10},
]


static func _hit(s, id: String, n: float, src: String) -> String:
	var a: int = s.damage(id, n, src)
	return "%s −%d%%" % [State.sub_name(id), a] if a > 0 else ""


static func _join(parts: Array) -> String:
	var out := ""
	for p in parts:
		if p != "":
			out += (", " if out != "" else "") + p
	return out


static func run_option(ev_id: String, opt_id: String, s) -> String:
	match ev_id:
		"tracker":
			match opt_id:
				"backup":
					s.power -= 6
					return _join(["Backup tracker online", _hit(s, "sensors", 5, "Dust blinded a star tracker")])
				"recal":
					s.days += 3
					s.power -= 2
					return _join(["Slow recalibration worked", _hit(s, "sensors", 8, "Dust blinded a star tracker")])
				_:
					return _join(["The ship drifted and the tracker overheated", _hit(s, "sensors", randi_range(15, 25), "Dust blinded a star tracker (ignored)")])
		"patch":
			if opt_id == "rollback":
				s.days += 2
				return "Patch rolled back. No harm done."
			if randf() < 0.55:
				s.science += 6
				return "The patch worked. Sharper instruments: science +6"
			s.science = maxi(0, s.science - 6)
			return _join(["The patch failed and the computer rebooted", _hit(s, "comms", 20, "Failed software patch"), "science −6"])
		"coolant":
			if opt_id == "cut":
				s.power -= 10
				return _join(["Arrays cooled", _hit(s, "arrays", 5, "Cooling loop fault")])
			if randf() < 0.5:
				return _join(["The panels cooked", _hit(s, "arrays", 25, "Cooling loop fault (ignored)")])
			return "Lucky: the panels survived."
		"upset":
			if opt_id == "reboot":
				s.days += 1
				return _join(["Rebooted safely", _hit(s, "comms", 5, "Radiation upset (rebooted)")])
			if randf() < 0.35:
				return _join(["The computer crashed", _hit(s, "comms", 25, "Radiation upset (ignored)")])
			return "The glitch cleared by itself."
		"valve":
			if opt_id == "routine":
				s.power -= 4
				return _join(["Valve freed", _hit(s, "thrusters", 5, "Sticking thruster valve")])
			return _join(["The ship limped on", _hit(s, "thrusters", 15, "Sticking thruster valve (worked around)")])
		"breach":
			if opt_id == "patch":
				s.power -= 3
				return _join(["Hole patched", _hit(s, "hull", 6, "Micrometeoroid hit the hull")])
			return _join(["The crack spread", _hit(s, "hull", 18, "Micrometeoroid hit the hull (ignored)")])
		"flare":
			if opt_id == "shelter":
				s.power -= 8
				s.days += 6
				return _join(["The crew sheltered safely", _hit(s, "arrays", 5, "Solar flare (sheltered)")])
			return _join([_hit(s, "comms", 20, "Solar flare radiation"), _hit(s, "arrays", 10, "Solar flare radiation"), _hit(s, "life", 10, "Solar flare radiation")])
	return ""


static func launch_debris(s) -> int:
	var a := randi_range(20, 42)
	s.damage("shield", a, "Foam debris hit the heat shield at launch")
	return a


static func resolve_power_drop(s, chosen: Array, timed_out: bool) -> Dictionary:
	var notes: Array = []
	var units: int = s.power_units()
	var keep: Array = chosen.duplicate()
	if timed_out:
		var ids: Array = []
		for x in POWER_SYSTEMS:
			ids.append(x.id)
		ids.shuffle()
		keep = ids.slice(0, 2)
		notes.append("Too slow! The computer cut systems at random.")
	var used := 0
	for id in keep:
		for x in POWER_SYSTEMS:
			if x.id == id:
				used += x.cost
	if used > units:
		notes.append("Overload! You tried to use %d of %d units. Breakers tripped." % [used, units])
		var t := _hit(s, "hull", 15, "Power overload during blackout")
		if t != "":
			notes.append(t)
		s.power -= 10
		keep = ["life"]
	var names: Array = []
	for id in keep:
		for x in POWER_SYSTEMS:
			if x.id == id:
				names.append(x.name)
	notes.append("Systems running: " + (", ".join(PackedStringArray(names)) if names.size() > 0 else "none"))
	var tone := "neutral"
	if not keep.has("life"):
		s.failed = "Life support was switched off during the power drop."
		notes.append("Life support was off!")
		return {"notes": notes, "tone": "bad"}
	if not keep.has("shield"):
		notes.append("Debris shields were off. " + _hit(s, "hull", 20, "Debris shields off during blackout"))
	if not keep.has("thrusters"):
		s.days += 15
		notes.append("Thrusters were off. You drifted: +15 days. " + _hit(s, "thrusters", 10, "Thrusters off during blackout"))
	if not keep.has("comms"):
		s.days += 3
		notes.append("No comms, guidance lost: +3 days. " + _hit(s, "comms", 10, "Comms off during blackout"))
	if not keep.has("lab"):
		s.science = maxi(0, s.science - 5)
		notes.append("Science lab was off: science −5.")
	if keep.has("shield"):
		tone = "good"
		notes.append("Good priorities: crew and ship protected.")
	return {"notes": notes, "tone": tone}
