extends RefCounted
## Mission state and rules, ported from src/state.js.

const Data = preload("res://scripts/data.gd")

var power: int = 100
var budget: int = 120
var days: int = 0
var science: int = 0
var crew: Array = []
var h: Dictionary = {}
var known_shield: int = 100
var shield_checked_day: int = -1
var history: Array = []
var failed: String = ""


func _init(crew_in: Array = []) -> void:
	crew = crew_in
	for x in Data.SUBS:
		h[x.id] = 100


static func sub_name(id: String) -> String:
	for x in Data.SUBS:
		if x.id == id:
			return x.name
	return id


func has(role: String) -> bool:
	return crew.has(role)


func thruster_factor() -> float:
	return 0.5 + 0.5 * float(h.thrusters) / 100.0

func sensor_factor() -> float:
	return 0.4 + 0.6 * float(h.sensors) / 100.0

func solar_factor() -> float:
	return 0.3 + 0.7 * float(h.arrays) / 100.0

func power_units() -> int:
	return roundi(18.0 + 12.0 * float(h.arrays) / 100.0)


func path_cost(p: Dictionary) -> Dictionary:
	var mult := 1.0 + float(100 - h.thrusters) / 150.0
	return {"power": ceili(float(p.power) * mult), "budget": p.budget, "days": p.days}


func scan_gain(base: int) -> int:
	return roundi(float(base) * sensor_factor() * (1.5 if has("scientist") else 1.0))


## Applies damage to a subsystem. Returns the damage actually dealt.
func damage(id: String, amount: float, source: String) -> int:
	var a := amount
	if id == "life" and has("medic"):
		a = ceil(a / 2.0)
	var ai: int = maxi(0, roundi(a))
	if ai == 0:
		return 0
	var before: int = h[id]
	h[id] = maxi(0, before - ai)
	var real: int = before - h[id]
	history.append({"day": days, "sub": id, "amount": real, "source": source, "hidden": id == "shield"})
	return real


func repair_info() -> Dictionary:
	if has("engineer"):
		return {"cost": 7, "amount": 25}
	return {"cost": 10, "amount": 20}


func repair(id: String) -> int:
	var info := repair_info()
	var accurate: bool = id == "shield" and known_shield == h.shield
	budget -= info.cost
	h[id] = mini(100, h[id] + info.amount)
	if accurate:
		known_shield = h.shield
	return info.amount


func inspect_shield() -> int:
	budget -= 4
	days += 2
	known_shield = h.shield
	shield_checked_day = days
	return h.shield


func leak_check() -> int:
	if h.hull < 40:
		return damage("life", 4, "Slow air leak from the damaged hull")
	return 0


func check_fail() -> String:
	if failed != "":
		return failed
	if h.life <= 0:
		failed = "Life support failed. The crew could not survive."
	elif h.hull <= 0:
		failed = "The hull broke apart."
	elif power <= 0:
		failed = "Out of power. Life support shut down."
	elif budget < 0:
		failed = "Budget exhausted. Mission control cancelled the flight."
	elif days > Data.MAX_DAYS:
		failed = "Mission deadline passed. Supplies ran out."
	return failed


func reentry(mod: float = 0.0) -> Dictionary:
	var integrity: float = 0.7 * h.shield + 0.1 * h.hull + 0.1 * h.thrusters + 0.1 * h.comms
	var roll: float = integrity + mod + (randf() * 20.0 - 10.0)
	var tier := "lost"
	if roll >= 85.0:
		tier = "perfect"
	elif roll >= 68.0:
		tier = "hard"
	elif roll >= 45.0:
		tier = "ballistic"
	if h.shield <= 15:
		tier = "lost"
	elif h.shield < 30 and (tier == "perfect" or tier == "hard"):
		tier = "ballistic"
	return {"tier": tier, "integrity": roundi(integrity), "roll": roundi(roll)}


func score(tier: String) -> int:
	var total := 0.0
	for x in Data.SUBS:
		total += h[x.id]
	var avg: float = total / Data.SUBS.size()
	var base: float = science * 5.0 + power + budget + roundf(avg) + maxf(0.0, Data.MAX_DAYS - days) / 5.0
	var mult := 0.0
	match tier:
		"perfect": mult = 1.0
		"hard": mult = 0.8
		"ballistic": mult = 0.5
	return roundi(base * mult)


func damage_chain() -> Array:
	var rows: Array = []
	for l in history:
		if l.amount > 0:
			rows.append(l)
	rows.sort_custom(func(a, b): return a.amount > b.amount)
	var out: Array = []
	for l in rows.slice(0, 6):
		var unchecked: bool = l.hidden and shield_checked_day < l.day
		var note := ", never checked" if unchecked else ""
		out.append("Day %d: %s (%s −%d%%%s)" % [l.day, l.source, sub_name(l.sub), l.amount, note])
	return out


func effect_lines() -> Array:
	var out: Array = []
	for x in Data.SUBS:
		if h[x.id] < 70:
			out.append("%s ended at %d%%. %s" % [x.name, h[x.id], x.effect])
	return out
