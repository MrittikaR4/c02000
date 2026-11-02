extends RefCounted
const State = preload("res://scripts/state.gd")
## Landing sites and surface tasks. Safest site first. Every task can be done once per landing.
## hazard kinds: dust, radiation, equip, cold, quake, thermal

const BODIES := {
	"mars": {"body": "Mars", "sites": [
		{"name": "Ancient river delta", "risk": 0.15, "note": "flat, good for rocks and past water", "tasks": [
			{"id": "rock", "label": "Collect rock cores", "power": 4, "days": 1, "sci": 10, "hazard": ["equip", 0.15], "text": "Cores from old river sediments were stored."},
			{"id": "life", "label": "Search for signs of past life", "power": 6, "days": 2, "sci": 6, "life": 0.25, "hazard": ["dust", 0.25], "text": "Samples were checked for organic molecules."},
			{"id": "wx", "label": "Set up a weather mast", "power": 3, "days": 1, "sci": 6, "hazard": ["dust", 0.2], "text": "The mast began recording wind, dust and pressure."}]},
		{"name": "Polar ice cap", "risk": 0.3, "note": "cold, ice cores, high power use", "tasks": [
			{"id": "ice", "label": "Drill an ice core", "power": 7, "days": 2, "sci": 13, "hazard": ["cold", 0.4], "text": "The core shows layers of dust and ice from many past climates."},
			{"id": "co2", "label": "Measure carbon dioxide frost", "power": 4, "days": 1, "sci": 7, "hazard": ["cold", 0.3], "text": "Seasonal carbon dioxide frost was measured."}]},
		{"name": "Canyon floor (Valles Marineris)", "risk": 0.5, "note": "tight landing, layered cliffs", "tasks": [
			{"id": "cliff", "label": "Photograph the layered cliffs", "power": 3, "days": 1, "sci": 9, "hazard": ["quake", 0.2], "text": "Cliff layers record billions of years of change."},
			{"id": "sub", "label": "Drill for underground ice", "power": 8, "days": 2, "sci": 16, "hazard": ["equip", 0.35], "text": "The drill reached ice below the surface."}]}]},
	"belt": {"body": "Ceres", "sites": [
		{"name": "Occator crater bright spots", "risk": 0.2, "note": "very low gravity, bright salt deposits", "tasks": [
			{"id": "salt", "label": "Sample the bright salts", "power": 4, "days": 1, "sci": 11, "hazard": ["equip", 0.15], "text": "The salts point to briny water that reached the surface."},
			{"id": "life", "label": "Search for organic compounds", "power": 6, "days": 2, "sci": 7, "life": 0.2, "hazard": ["equip", 0.2], "text": "Samples were tested for carbon-based molecules."},
			{"id": "ice", "label": "Mine water ice (restores power)", "power": -8, "days": 1, "sci": 6, "hazard": ["equip", 0.2], "text": "Water ice was split into fuel, which gave back some power."}]},
		{"name": "Rough highlands", "risk": 0.4, "note": "steep slopes, many boulders", "tasks": [
			{"id": "rock", "label": "Core a boulder", "power": 4, "days": 1, "sci": 9, "hazard": ["quake", 0.2], "text": "The rock type was identified and logged."}]}]},
	"jupiter": {"body": "Europa (moon of Jupiter)", "sites": [
		{"name": "Smooth ice plains", "risk": 0.3, "note": "radiation is strong, ice crust over an ocean", "tasks": [
			{"id": "drill", "label": "Drill into the ice crust", "power": 8, "days": 2, "sci": 14, "hazard": ["radiation", 0.45], "text": "The ice crust is thick, and there is salty water underneath."},
			{"id": "life", "label": "Search for life in brine pockets", "power": 7, "days": 2, "sci": 8, "life": 0.18, "hazard": ["radiation", 0.45], "text": "Brine samples were checked for signs of living cells."},
			{"id": "mag", "label": "Magnetometer survey", "power": 3, "days": 1, "sci": 8, "hazard": ["radiation", 0.3], "text": "Magnetic readings support a salty ocean below the ice."}]},
		{"name": "Cracked ridges", "risk": 0.5, "note": "uneven ground, fresh material from below", "tasks": [
			{"id": "ridge", "label": "Sample ridge material", "power": 5, "days": 1, "sci": 12, "hazard": ["radiation", 0.4], "text": "Ridge material may have come up from the ocean."}]}]},
	"comet": {"body": "the comet nucleus", "sites": [
		{"name": "Dusty plain", "risk": 0.45, "note": "almost no gravity, ship must anchor", "tasks": [
			{"id": "anchor", "label": "Fire anchor harpoons and drill", "power": 6, "days": 1, "sci": 14, "hazard": ["equip", 0.3], "text": "The sample holds ice and dust older than the planets."},
			{"id": "gas", "label": "Analyse escaping gas", "power": 4, "days": 1, "sci": 9, "hazard": ["thermal", 0.25], "text": "Water vapour and carbon compounds were measured."}]}]},
	"pluto": {"body": "Pluto", "sites": [
		{"name": "Heart-shaped nitrogen plain", "risk": 0.25, "note": "extreme cold, smooth ice", "tasks": [
			{"id": "ice", "label": "Core the nitrogen ice", "power": 7, "days": 2, "sci": 14, "hazard": ["cold", 0.45], "text": "The ice slowly churns like a very cold pot of soup."},
			{"id": "charon", "label": "Photograph Charon", "power": 3, "days": 1, "sci": 7, "hazard": ["cold", 0.25], "text": "Charon hangs fixed in the sky because both worlds face each other."},
			{"id": "life", "label": "Search for chemistry of life", "power": 6, "days": 2, "sci": 6, "life": 0.08, "hazard": ["cold", 0.4], "text": "Only simple carbon compounds were found. It is far too cold for life as we know it."}]},
		{"name": "Water-ice mountains", "risk": 0.45, "note": "rough and steep", "tasks": [
			{"id": "mtn", "label": "Sample the mountain rock", "power": 5, "days": 1, "sci": 11, "hazard": ["quake", 0.2], "text": "The mountains are made of water ice as hard as rock."}]}]},
}

const VIS := {"rock": "sample", "life": "lab", "wx": "mast", "ice": "drill", "co2": "scan", "cliff": "photo", "sub": "drill", "salt": "sample", "drill": "drill", "mag": "scan", "ridge": "sample", "anchor": "drill", "gas": "scan", "charon": "photo", "mtn": "sample"}


static func has_landing(id: String) -> bool:
	return BODIES.has(id)


static func risk_label(r: float) -> String:
	return "low risk" if r < 0.25 else ("medium risk" if r < 0.42 else "high risk")


## Applies a hazard. Returns a short message, or "" if nothing happened.
static func hazard(s, kind: String, body: String) -> String:
	var src := "Hazard on %s" % body
	match kind:
		"dust":
			return "Dust storm: solar arrays −%d%%." % s.damage("arrays", float(randi_range(8, 16)), src)
		"radiation":
			return "Radiation burst: life support −%d%%." % s.damage("life", float(randi_range(8, 14)), src)
		"equip":
			var id: String = ["sensors", "comms"][randi() % 2]
			return "Instrument failure: %s −%d%%." % [State.sub_name(id), s.damage(id, float(randi_range(6, 12)), src)]
		"cold":
			s.power -= 5
			return "Extreme cold: heaters used extra power (−5)."
		"quake":
			return "Ground shock: hull −%d%%." % s.damage("hull", float(randi_range(5, 10)), src)
		"thermal":
			return "Hot gas jet: thrusters −%d%%." % s.damage("thrusters", float(randi_range(6, 12)), src)
	return ""
