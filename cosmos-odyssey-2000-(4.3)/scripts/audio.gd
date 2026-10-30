extends Node
## Tiny procedural sound: an ambient drone plus beeps, generated as 16-bit PCM in code.

var on := false
var _drone: AudioStreamPlayer
var _sfx := {}
const RATE := 22050


func _ready() -> void:
	_drone = AudioStreamPlayer.new()
	_drone.stream = _make_drone()
	_drone.volume_db = -200.0
	add_child(_drone)
	_sfx["warn"] = _make_tones([[300.0, 0.18, 0.0], [220.0, 0.25, 0.2]], "square", 0.12)
	_sfx["alarm"] = _make_tones([[760.0, 0.16, 0.0], [520.0, 0.16, 0.2], [760.0, 0.16, 0.4], [520.0, 0.16, 0.6]], "square", 0.1)
	_sfx["ok"] = _make_tones([[660.0, 0.1, 0.0], [880.0, 0.16, 0.1]], "sine", 0.18)
	_sfx["thud"] = _make_tones([[70.0, 0.35, 0.0]], "saw", 0.3)
	for k in _sfx:
		var p := AudioStreamPlayer.new()
		p.stream = _sfx[k]
		p.name = "sfx_" + k
		add_child(p)


func toggle() -> bool:
	on = not on
	if on:
		_drone.volume_db = -14.0
		if not _drone.playing:
			_drone.play()
	else:
		_drone.volume_db = -200.0
	return on


func play(sfx_name: String) -> void:
	if not on:
		return
	var p := get_node_or_null("sfx_" + sfx_name) as AudioStreamPlayer
	if p:
		p.play()


func warn() -> void: play("warn")
func alarm() -> void: play("alarm")
func ok() -> void: play("ok")
func thud() -> void: play("thud")


func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _make_tones(tones: Array, shape: String, vol: float) -> AudioStreamWAV:
	var total := 0.0
	for t in tones:
		total = maxf(total, t[2] + t[1])
	var n := int((total + 0.05) * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for t in tones:
		var f: float = t[0]
		var dur: float = t[1]
		var start := int(t[2] * RATE)
		for i in int(dur * RATE):
			var ph := fmod(f * float(i) / RATE, 1.0)
			var v := 0.0
			match shape:
				"square": v = 1.0 if ph < 0.5 else -1.0
				"saw": v = ph * 2.0 - 1.0
				_: v = sin(ph * TAU)
			var env := exp(-5.0 * float(i) / (dur * RATE))
			if start + i < n:
				s[start + i] += v * vol * env
	return _wav(s, false)


func _make_drone() -> AudioStreamWAV:
	# 8 seconds, frequencies chosen to loop cleanly (integer cycles per loop)
	var secs := 8.0
	var n := int(secs * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var freqs := [55.0, 82.5, 110.0, 165.0]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for k in freqs.size():
			v += sin(TAU * freqs[k] * t) * (0.12 / (k + 1)) * (1.0 + 0.4 * sin(TAU * (k + 1) * t / secs))
		s[i] = v
	return _wav(s, true)
