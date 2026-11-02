extends RefCounted
## Static game data, ported 1:1 from the web version (src/data.js).

const MAX_DAYS := 300

const SUBS := [
	{"id": "hull", "name": "Hull", "effect": "A weak hull leaks air into life support and risks breaking up."},
	{"id": "arrays", "name": "Solar arrays", "effect": "Damaged arrays recharge less power and leave less power during a blackout."},
	{"id": "thrusters", "name": "Thrusters", "effect": "Weak thrusters steer slowly and make every route cost more power."},
	{"id": "sensors", "name": "Sensors", "effect": "Poor sensors shorten your warning range and reduce science from scans."},
	{"id": "shield", "name": "Heat shield", "effect": "The heat shield decides how re-entry ends."},
	{"id": "comms", "name": "Comms", "effect": "Weak comms hurt guidance during the final landing."},
	{"id": "life", "name": "Life support", "effect": "If life support reaches zero the crew is lost."},
]

const SHIPS := [
	{"id": "orbiter", "name": "Orbiter", "desc": "White spaceplane with delta wings and twin engines. Balanced and easy to read."},
	{"id": "capsule", "name": "Capsule", "desc": "Crew capsule with a gold service module and long solar wings. Classic deep-space look."},
	{"id": "probe", "name": "Sun Probe", "desc": "Small bus hiding behind a huge flat heat shield, like the real Parker Solar Probe."},
	{"id": "custom", "name": "Design your own", "desc": "Choose the body, wings, tail fin, engines, nozzles and colours yourself."},
]

const SHIP_DEFAULT := {"body": "classic", "wings": "delta", "wing_size": "medium", "fin": "single", "engines": "2",
	"nozzle": "medium", "panels": "wing", "hull_col": "pearl", "accent": "blue"}

const SHIP_OPTS := [
	{"key": "body", "label": "Body", "choices": [["slim", "Slim"], ["classic", "Classic"], ["stout", "Stout"]]},
	{"key": "wings", "label": "Wings", "choices": [["none", "None"], ["delta", "Delta"], ["straight", "Straight"], ["swept", "Swept"]]},
	{"key": "wing_size", "label": "Wing size", "choices": [["small", "Small"], ["medium", "Medium"], ["large", "Large"]]},
	{"key": "fin", "label": "Tail fin", "choices": [["none", "None"], ["single", "Single"], ["twin", "Twin"], ["tall", "Tall"]]},
	{"key": "engines", "label": "Engines", "choices": [["1", "1"], ["2", "2"], ["3", "3"]]},
	{"key": "nozzle", "label": "Thruster nozzle", "choices": [["small", "Small"], ["medium", "Medium"], ["large", "Large"]]},
	{"key": "panels", "label": "Solar panels", "choices": [["wing", "On wings"], ["boom", "Side booms"]]},
	{"key": "hull_col", "label": "Hull colour", "choices": [["pearl", "Pearl", "eef1f6"], ["red", "Red", "d8484e"], ["orange", "Orange", "f0903a"], ["steel", "Steel", "9aa6b8"], ["navy", "Navy", "3a4f8a"], ["green", "Green", "5fae7a"]]},
	{"key": "accent", "label": "Accent / flame", "choices": [["blue", "Blue", "4f9bff"], ["orange", "Orange", "ff9a4a"], ["green", "Green", "5dff9e"], ["pink", "Pink", "ff7ad0"], ["red", "Red", "ff6a5a"]]},
]

const CREW := [
	{"id": "pilot", "name": "Pilot", "desc": "Steers 25% better through asteroid fields."},
	{"id": "engineer", "name": "Engineer", "desc": "Repairs cost less and fix more."},
	{"id": "medic", "name": "Medic", "desc": "Halves radiation and life-support damage."},
	{"id": "scientist", "name": "Scientist", "desc": "Scans give 50% more science."},
]

const PATHS := {
	"fast": {"label": "Fast burn", "power": 10, "days": 15, "speed": 76.0, "note": "faster asteroids"},
	"normal": {"label": "Normal route", "power": 7, "days": 25, "speed": 56.0, "note": ""},
	"ellipse": {"label": "Elliptical orbit", "power": 3, "days": 45, "speed": 42.0, "note": "gravity assist, slow"},
}

# Power recharged on arrival (before the solar array factor).
const SOLAR := {"mars": 12, "belt": 9, "jupiter": 5, "comet": 5, "pluto": 1, "blackhole": 0}

const STOPS := [
	{"id": "earth", "name": "Earth", "type": "start", "orbit": [90.0, 0.0, 0.0],
		"fact": "Earth orbits the Sun, a star about 150 million km away, on a slightly elliptical path. The Sun makes its own light by fusing hydrogen."},
	{"id": "mars", "name": "Mars", "type": "planet", "orbit": [135.0, 35.0, 3.0],
		"fact": "Mars has two small moons, Phobos and Deimos. A Mars day is about 24.6 hours long.",
		"scan": {"base": 12, "text": "The scan found dry river valleys and signs of ancient water."}},
	{"id": "belt", "name": "Asteroid Belt", "type": "belt", "orbit": [180.0, 75.0, 0.0],
		"fact": "Millions of rocky bodies orbit between Mars and Jupiter. Ceres, the largest object here, is a dwarf planet.",
		"scan": {"base": 10, "text": "The scan measured rock types and mapped the dwarf planet Ceres."}},
	{"id": "jupiter", "name": "Jupiter", "type": "planet", "orbit": [235.0, 115.0, -4.0],
		"fact": "Jupiter has more than 90 known moons. The four largest are Io, Europa, Ganymede and Callisto.",
		"scan": {"base": 12, "text": "The scan mapped Jupiter's storms and its four biggest moons."}},
	{"id": "comet", "name": "Comet", "type": "comet", "orbit": [],
		"fact": "Comets follow long elliptical orbits. They speed up near the Sun and grow a glowing tail of gas and dust that always points away from it."},
	{"id": "pluto", "name": "Pluto", "type": "dwarf", "orbit": [430.0, 215.0, -8.0],
		"fact": "Pluto is a dwarf planet. It has not cleared other objects from its orbit. Its moon Charon is huge compared with Pluto.",
		"scan": {"base": 14, "text": "The scan found a heart-shaped plain of nitrogen ice."}},
	{"id": "blackhole", "name": "Black Hole (simulation)", "type": "blackhole", "orbit": [560.0, 265.0, 6.0],
		"fact": "No black hole is known anywhere near our solar system. The closest known ones are over a thousand light-years away. This region is a \"what if\" simulation of how a black hole bends light and slows time."},
	{"id": "earth2", "name": "Earth (Return)", "type": "end", "orbit": [90.0, 0.0, 0.0],
		"fact": "Home orbit. Re-entry is about to put the heat shield to the test."},
]

# Comet orbit: semi-major axis, eccentricity, true anomaly (deg), argument of periapsis (deg)
const COMET := {"a": 420.0, "e": 0.8, "nu": 130.0, "omega": 40.0}

const CUE := {
	"suspense": "House M.D. theme: suspense, important decision",
	"intermission": "Doctor Who theme: intermission break",
	"ending": "Cornfield Chase (Interstellar): return to Earth",
	"start": "Mission start",
}
