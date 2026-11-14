extends Node

const MIX_RATE := 22050
const VOICES := 8
const BACKGROUND_MUSIC := "res://assets/audio/voll_background.mp3"
const MUSIC_VOLUME_DB := -13.0 + 5.1
const LOWPASS_HZ := 6500.0
const EDGE_FADE := 0.003
const BUILD_BUDGET_USEC := 3000
enum { SQUARE, PULSE, TRI, BELL }

var _streams := {}
var _recipes := {}
var _pending: Array[String] = []
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX" if AudioServer.get_bus_index("SFX") >= 0 else &"Master"
		add_child(p)
		_players.append(p)
	_define_sounds()
	_start_background_music()

func _process(_delta: float) -> void:
	var start := Time.get_ticks_usec()
	while not _pending.is_empty() and Time.get_ticks_usec() - start < BUILD_BUDGET_USEC:
		_get_stream(_pending.pop_front())
	if _pending.is_empty():
		set_process(false)

func _start_background_music() -> void:
	if not ResourceLoader.exists(BACKGROUND_MUSIC):
		return
	var music := load(BACKGROUND_MUSIC)
	if music is AudioStreamMP3:
		(music as AudioStreamMP3).loop = true
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "VollBackgroundMusic"
	_music_player.stream = music
	_music_player.volume_db = MUSIC_VOLUME_DB
	_music_player.bus = &"Music" if AudioServer.get_bus_index("Music") >= 0 else &"Master"
	add_child(_music_player)
	_music_player.play()

func play(sfx_name: String, pitch_jitter := 0.06, volume_db := 0.0, pitch := 1.0) -> void:
	var stream := _get_stream(sfx_name)
	if stream == null:
		push_warning("AudioManager: unknown sound '%s'" % sfx_name)
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.pitch_scale = maxf(0.05, pitch + randf_range(-pitch_jitter, pitch_jitter))
	p.volume_db = volume_db
	p.play()

func has_sound(sfx_name: String) -> bool:
	return _streams.has(sfx_name) or _recipes.has(sfx_name)

func _get_stream(sfx_name: String) -> AudioStream:
	if _streams.has(sfx_name):
		return _streams[sfx_name]
	if not _recipes.has(sfx_name):
		return null
	var stream: AudioStream
	var path := "res://assets/sfx/%s.wav" % sfx_name
	if ResourceLoader.exists(path):
		stream = load(path)
	else:
		var r: Array = _recipes[sfx_name]
		stream = _synth(float(r[0]), r[1], r[2])
	_streams[sfx_name] = stream
	return stream

func _define(sfx_name: String, duration: float, wave: Callable, notes: Array = []) -> void:
	_recipes[sfx_name] = [duration, wave, notes]
	_pending.append(sfx_name)

func _define_sounds() -> void:
	_define("click", 0.05, func(t: float, d: float) -> float:
		return _square(t, 1200.0, 0.5) * _env(t, d, 0.001) * 0.4)
	_define("place", 0.09, func(t: float, d: float) -> float:
		return _square(t, 520.0 + 900.0 * t / d, 0.5) * _env(t, d, 0.003) * 0.55)
	_define("boing", 0.32, func(t: float, d: float) -> float:
		var f := 180.0 + 520.0 * pow(1.0 - t / d, 3.0) + 30.0 * sin(t * 60.0)
		return _square(t, f, 0.35) * _env(t, d, 0.005) * 0.9)
	_define("expire", 0.22, func(t: float, d: float) -> float:
		return _triangle(t, 600.0 - 1600.0 * t) * _env(t, d, 0.01) * 0.5)
	_define("deny", 0.12, func(t: float, d: float) -> float:
		return _square(t, 140.0, 0.5) * _env(t, d, 0.004) * 0.4)
	_define("pickup", 0.25, Callable(), [[0.0, 0.11, 660.0, PULSE, 0.5], [0.09, 0.16, 990.0, PULSE, 0.5]])
	_define("countdown", 0.13, func(t: float, d: float) -> float:
		return (sin(TAU * 660.0 * t) * 0.7 + _square(t, 660.0, 0.5) * 0.15) * _env(t, d, 0.004) * 0.6)
	_define("go", 0.38, func(t: float, d: float) -> float:
		var body := sin(TAU * 1320.0 * t) * 0.6 + _square(t, 1320.0, 0.5) * 0.12 + sin(TAU * 660.0 * t) * 0.2
		return body * _env(t, d, 0.004) * 0.6)
	_define("coin", 0.32, Callable(), [[0.0, 0.075, 988.0, SQUARE, 0.45], [0.07, 0.25, 1319.0, SQUARE, 0.45]])
	_define("clutch", 0.42, func(t: float, _d: float) -> float:
		if t >= 0.14:
			return 0.0
		return _triangle(t, 1200.0 + 9000.0 * t) * 0.06 * (1.0 - t / 0.14),
		[[0.0, 0.30, 1047.0, BELL, 0.4], [0.05, 0.30, 1568.0, BELL, 0.4], [0.10, 0.32, 2093.0, BELL, 0.4]])
	_define("stomp", 0.24, func(t: float, _d: float) -> float:
		var s := 0.0
		if t < 0.07:
			s += sin(TAU * (900.0 * t - 2800.0 * t * t)) * _env(t, 0.07, 0.002) * 0.6
			s += randf_range(-1.0, 1.0) * 0.18 * (1.0 - t / 0.07)
		s += sin(TAU * (95.0 * t - 90.0 * t * t)) * _env(t, 0.24, 0.004) * 0.9
		return s * 0.75)
	_define("hurt", 0.3, func(t: float, d: float) -> float:
		var f := 520.0 - 340.0 * t / d + 25.0 * sin(t * 140.0)
		var s := _square(t, f, 0.3) * 0.6 + _square(t, f * 0.5, 0.5) * 0.25
		return s * _env(t, d, 0.004) * 0.55)
	_define("level_up", 0.5, Callable(), [
		[0.0, 0.11, 784.0, PULSE, 0.45], [0.09, 0.11, 988.0, PULSE, 0.45],
		[0.18, 0.32, 1175.0, PULSE, 0.45], [0.18, 0.32, 587.0, TRI, 0.27]])
	_define("buy", 0.45, func(t: float, _d: float) -> float:
		if t >= 0.03:
			return 0.0
		return randf_range(-1.0, 1.0) * _env(t, 0.03, 0.001) * 0.22,
		[[0.0, 0.08, 1568.0, SQUARE, 0.16], [0.05, 0.20, 2093.0, BELL, 0.36], [0.09, 0.20, 2637.0, BELL, 0.36],
		[0.13, 0.22, 3136.0, BELL, 0.36], [0.17, 0.28, 4186.0, BELL, 0.32]])
	_define("win", 1.35, Callable(), [
		[0.00, 0.12, 523.0, PULSE, 0.4], [0.11, 0.12, 659.0, PULSE, 0.4], [0.22, 0.12, 784.0, PULSE, 0.4],
		[0.33, 0.20, 1047.0, PULSE, 0.4], [0.52, 0.12, 784.0, PULSE, 0.4], [0.63, 0.70, 1047.0, PULSE, 0.4],
		[0.63, 0.70, 1319.0, SQUARE, 0.2],
		[0.00, 0.33, 262.0, TRI, 0.28], [0.33, 0.30, 196.0, TRI, 0.28], [0.63, 0.70, 262.0, TRI, 0.28]])
	_define("death", 0.7, func(t: float, d: float) -> float:
		var noise := randf_range(-1.0, 1.0)
		var tone := _square(t, 110.0 - 70.0 * t / d, 0.5)
		var attack := minf(1.0, t / 0.006)
		return (noise * 0.6 + tone * 0.35) * pow(1.0 - t / d, 2.0) * attack * 0.75)

func _synth(duration: float, wave: Callable, notes: Array = []) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	if wave.is_valid():
		for i in n:
			buf[i] = float(wave.call(float(i) / MIX_RATE, duration))
	for note: Array in notes:
		_render_note(buf, float(note[0]), float(note[1]), float(note[2]), int(note[3]), float(note[4]))
	var data := PackedByteArray()
	data.resize(n * 2)
	var a := 1.0 - exp(-TAU * LOWPASS_HZ / MIX_RATE)
	var y := 0.0
	var fade_n := int(EDGE_FADE * MIX_RATE)
	for i in n:
		y += a * (buf[i] - y)
		var s := y
		if i < fade_n:
			s *= float(i) / fade_n
		elif i > n - fade_n:
			s *= float(n - i) / fade_n
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	return w

static func _render_note(buf: PackedFloat32Array, start: float, dur: float, f: float, kind: int, vol: float) -> void:
	var i0 := int(start * MIX_RATE)
	var count := mini(int(dur * MIX_RATE), buf.size() - i0)
	var attack := 0.003 if kind == BELL else 0.004
	var inv_rel := 1.0 / (dur - attack)
	for j in count:
		var lt := float(j) / MIX_RATE
		var e := lt / attack if lt < attack else pow(maxf(0.0, 1.0 - (lt - attack) * inv_rel), 1.5)
		var ph := fmod(lt * f, 1.0)
		var w: float
		match kind:
			SQUARE:
				w = 1.0 if ph < 0.5 else -1.0
			PULSE:
				w = 1.0 if ph < 0.25 else -1.0
			TRI:
				w = 4.0 * absf(ph - 0.5) - 1.0
			_:
				w = sin(TAU * ph) + 0.35 * sin(TAU * f * 2.76 * lt) * exp(-lt * 18.0)
		buf[i0 + j] += w * e * vol

static func _env(t: float, d: float, attack: float) -> float:
	if t < attack:
		return t / attack
	return pow(maxf(0.0, 1.0 - (t - attack) / (d - attack)), 1.5)

static func _square(t: float, f: float, duty: float) -> float:
	return 1.0 if fmod(t * f, 1.0) < duty else -1.0

static func _triangle(t: float, f: float) -> float:
	var ph := fmod(t * absf(f), 1.0)
	return 4.0 * absf(ph - 0.5) - 1.0
