class_name SfxPlayer
extends Node

const RATE := 22050

const EVENT_CUES := {
	"card_deployed": "deploy",
	"order_played": "deploy",
	"card_drawn": "draw",
	"unit_moved": "move",
	"attack_started": "attack",
	"damage_dealt": "damage",
	"fatigue_damage": "damage",
	"card_destroyed": "destroy",
	"turn_started": "turn",
	"countermeasure_triggered": "trigger",
}

static var instance: SfxPlayer

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _voice_index := 0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	for _index in 4:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -8.0
		add_child(voice)
		_voices.append(voice)
	_streams = {
		"deploy": _thud(140.0, 0.11),
		"draw": _rustle(0.07),
		"move": _sweep(240.0, 160.0, 0.08),
		"attack": _strike(0.10),
		"damage": _hit(0.08),
		"destroy": _hit(0.13, 0.42),
		"turn": _brass([196.0, 247.0], 0.09),
		"trigger": _tick(1100.0, 0.05),
		"win": _brass([392.0, 494.0, 587.0], 0.10),
		"lose": _brass([349.0, 293.0, 220.0], 0.11),
	}


static func cue_for(event_type: String, payload: Dictionary = {}) -> String:
	if event_type == "match_ended":
		var winner := str(payload.get("winner_id", ""))
		if winner == "player":
			return "win"
		if winner == "opponent":
			return "lose"
		return "turn"
	return str(EVENT_CUES.get(event_type, ""))


static func play_event(event_type: String, payload: Dictionary = {}) -> void:
	if instance == null or not is_instance_valid(instance):
		return
	instance.play_cue(cue_for(event_type, payload))


func play_cue(cue: String) -> void:
	if cue.is_empty() or DisplayServer.get_name() == "headless":
		return
	var stream: Variant = _streams.get(cue)
	if stream == null or _voices.is_empty():
		return
	var voice: AudioStreamPlayer = _voices[_voice_index]
	_voice_index = (_voice_index + 1) % _voices.size()
	voice.stream = stream
	voice.play()


func _thud(hz: float, seconds: float) -> AudioStreamWAV:
	var n := int(RATE * seconds)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 22.0)
		samples[i] = (sin(TAU * hz * t) * 0.55 + _noise() * 0.22) * env
	return _pcm(samples)


func _rustle(seconds: float) -> AudioStreamWAV:
	var n := int(RATE * seconds)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var prev := 0.0
	for i in n:
		var env := 1.0 - float(i) / float(max(n - 1, 1))
		prev = prev * 0.55 + _noise() * 0.45
		samples[i] = prev * env * env * 0.35
	return _pcm(samples)


func _sweep(start_hz: float, end_hz: float, seconds: float) -> AudioStreamWAV:
	var n := int(RATE * seconds)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	for i in n:
		var u := float(i) / float(max(n - 1, 1))
		var hz := lerpf(start_hz, end_hz, u)
		phase += TAU * hz / RATE
		var env := sin(PI * u)
		samples[i] = sin(phase) * env * 0.28
	return _pcm(samples)


func _strike(seconds: float) -> AudioStreamWAV:
	var n := int(RATE * seconds)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	for i in n:
		var u := float(i) / float(max(n - 1, 1))
		phase += TAU * lerpf(420.0, 140.0, u) / RATE
		var env := exp(-u * 8.0)
		samples[i] = (sin(phase) * 0.4 + _noise() * 0.25) * env
	return _pcm(samples)


func _hit(seconds: float, weight := 0.32) -> AudioStreamWAV:
	var n := int(RATE * seconds)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 28.0)
		samples[i] = (sin(TAU * 70.0 * t) * 0.45 + _noise() * weight) * env
	return _pcm(samples)


func _tick(hz: float, seconds: float) -> AudioStreamWAV:
	var n := int(RATE * seconds)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var u := float(i) / float(max(n - 1, 1))
		samples[i] = sin(TAU * hz * float(i) / RATE) * exp(-u * 14.0) * 0.22
	return _pcm(samples)


func _brass(notes: Array, note_seconds: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	for note in notes:
		var hz := float(note)
		var n := int(RATE * note_seconds)
		for i in n:
			var u := float(i) / float(max(n - 1, 1))
			var env := sin(PI * u)
			var t := float(i) / RATE
			samples.append((sin(TAU * hz * t) + 0.35 * sin(TAU * hz * 2.0 * t)) * env * 0.22)
	return _pcm(samples)


func _noise() -> float:
	return randf() * 2.0 - 1.0


func _pcm(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var value := int(round(clampf(samples[i], -1.0, 1.0) * 32767.0))
		data.encode_s16(i * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
