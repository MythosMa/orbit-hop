class_name Sfx
extends RefCounted

## Tiny runtime synth — builds short PCM tones on the fly so the game ships with
## zero external audio assets (important for a small web build).

const SAMPLE_RATE := 44100

enum Wave { SINE, TRIANGLE, SAW }

static var _host: Node = null
static var _enabled := true


static func init(host: Node) -> void:
	_host = host


static func set_enabled(on: bool) -> void:
	_enabled = on


static func enabled() -> bool:
	return _enabled


static func launch() -> void:
	_play(_blip(520.0, 0.07, 0.18, Wave.SINE, 900.0))


static func capture(combo: int, perfect: bool) -> void:
	var semis := mini(combo, 16)
	var f := 440.0 * pow(2.0, semis / 12.0)
	if perfect:
		f *= 1.5
	_play(_blip(f, 0.22 if perfect else 0.16, 0.26, Wave.TRIANGLE, f * 1.01))
	if perfect:
		_play(_blip(f * 2.0, 0.18, 0.14, Wave.SINE, f * 2.0), 0.03)


static func fail() -> void:
	_play(_blip(220.0, 0.45, 0.30, Wave.SAW, 70.0))
	_play(_blip(110.0, 0.55, 0.22, Wave.SINE, 55.0), 0.04)


static func ui() -> void:
	_play(_blip(660.0, 0.05, 0.14, Wave.SINE, 880.0))


static func _blip(freq: float, dur: float, vol: float, wave: int, end_freq: float) -> AudioStreamWAV:
	var n := maxi(1, int(SAMPLE_RATE * dur))
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f := lerpf(freq, end_freq, t)
		phase += TAU * f / float(SAMPLE_RATE)
		var s := 0.0
		match wave:
			Wave.SINE:
				s = sin(phase)
			Wave.TRIANGLE:
				s = asin(sin(phase)) * (2.0 / PI)
			Wave.SAW:
				s = 2.0 * (phase / TAU - floorf(phase / TAU + 0.5))
		# Percussive envelope: fast attack, exponential decay.
		var env := exp(-5.0 * t) * minf(1.0, t * 220.0)
		var v := clampi(int(s * env * vol * 32767.0), -32768, 32767)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav


static func _play(stream: AudioStreamWAV, delay: float = 0.0) -> void:
	if not _enabled or _host == null or not is_instance_valid(_host):
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	_host.add_child(p)
	p.finished.connect(p.queue_free)
	if delay > 0.0:
		var timer := _host.get_tree().create_timer(delay)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(p):
				p.play())
	else:
		p.play()
