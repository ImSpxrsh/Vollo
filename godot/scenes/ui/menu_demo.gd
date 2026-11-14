extends Node2D

const GRAVITY := 1500.0
const BOUNCE_V := -780.0
const BALL_R := 18.0
const PIT_DEPTH := 56.0
const SPIKE_W := 34.0
const SPIKE_H := 30.0
const TRAIL_LEN := 22

const C_GROUND := Color(0.0862745, 0.105882, 0.141176, 0.95)
const C_ACCENT := Color("7EA899")
const C_HAZARD := Color("B85D57")
const C_TEXT := Color("E8ECF4")

@export var speed := 330.0
@export var ground_offset := 84.0
@export var ball_screen_x := 0.2
@export var seed_value := 7

var scroll := 0.0
var _rng := RandomNumberGenerator.new()
var _pits: Array[Vector2] = []
var _spikes: Array[float] = []
var _next_x := 0.0
var _ball_y := 0.0
var _vy := 0.0
var _angle := 0.0
var _squash := 0.0
var _trail: Array[Vector2] = []
var _bounce_flash := {}
var _ball_tex: Texture2D

func _ready() -> void:
	refresh_variety()
	_rng.seed = seed_value
	_next_x = 0.0
	_ball_y = _ground_y() - BALL_R
	_extend_course()

func _screen() -> Vector2:
	return get_viewport_rect().size

func _ground_y() -> float:
	return _screen().y - ground_offset

func _ball_world_x() -> float:
	return scroll + _screen().x * ball_screen_x

func _extend_course() -> void:
	var horizon := scroll + _screen().x + 600.0
	while _next_x < horizon:
		var ground_len := _rng.randf_range(360.0, 620.0)
		var pit_w := _rng.randf_range(190.0, 240.0)
		var x0 := _next_x + ground_len
		_pits.append(Vector2(x0, x0 + pit_w))
		if _rng.randf() < 0.65:
			var first := x0 + pit_w + _rng.randf_range(50.0, 70.0)
			_spikes.append(first)
			if _rng.randf() < 0.5:
				_spikes.append(first + SPIKE_W + 2.0)
		_next_x = x0 + pit_w
	while not _pits.is_empty() and _pits[0].y < scroll - 400.0:
		_pits.pop_front()
		_bounce_flash.clear()
	while not _spikes.is_empty() and _spikes[0] < scroll - 400.0:
		_spikes.pop_front()

func _pit_at(x: float) -> int:
	for i in _pits.size():
		if x > _pits[i].x and x < _pits[i].y:
			return i
	return -1

func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 20.0)
	scroll += speed * delta
	_extend_course()
	var bx := _ball_world_x()
	var gy := _ground_y()
	_vy += GRAVITY * delta
	_ball_y += _vy * delta
	var pit := _pit_at(bx)
	var surface := gy + PIT_DEPTH if pit >= 0 else gy
	if _ball_y + BALL_R >= surface and _vy > 0.0:
		_ball_y = surface - BALL_R
		if pit >= 0:
			_vy = BOUNCE_V
			_squash = 1.0
			_bounce_flash[_pits[pit].x] = 0.0
		elif _vy > 260.0:
			_squash = clampf(_vy / 900.0, 0.0, 0.6)
			_vy = -_vy * 0.22
		else:
			_vy = 0.0
	_squash = move_toward(_squash, 0.0, delta * 4.0)
	_angle += speed * delta / BALL_R
	for k in _bounce_flash.keys():
		_bounce_flash[k] += delta
	_trail.push_front(Vector2(bx, _ball_y))
	if _trail.size() > TRAIL_LEN:
		_trail.pop_back()
	queue_redraw()

func _to_screen(p: Vector2) -> Vector2:
	return Vector2(p.x - scroll, p.y)

func _trampoline_alpha(pit: Vector2) -> float:
	var bx := _ball_world_x()
	var appear := clampf((bx - (pit.x - 320.0)) / 90.0, 0.0, 1.0)
	var vanish := 1.0 - clampf((bx - (pit.y + 260.0)) / 140.0, 0.0, 1.0)
	return appear * vanish

func _draw() -> void:
	var size := _screen()
	var gy := _ground_y()
	var left := scroll - 40.0
	var right := scroll + size.x + 40.0
	var x := left
	for pit in _pits:
		if pit.y < left:
			continue
		if pit.x > right:
			break
		_draw_ground(x, pit.x, gy, size.y)
		_draw_pit(pit, gy, size.y)
		x = pit.y
	_draw_ground(x, right, gy, size.y)
	for sx in _spikes:
		if sx < left or sx > right:
			continue
		var c := _to_screen(Vector2(sx, gy))
		var tri := PackedVector2Array([c + Vector2(-SPIKE_W * 0.5, 0), c + Vector2(0, -SPIKE_H), c + Vector2(SPIKE_W * 0.5, 0)])
		var glow := PackedVector2Array([c + Vector2(-SPIKE_W * 0.7, 2), c + Vector2(0, -SPIKE_H - 7), c + Vector2(SPIKE_W * 0.7, 2)])
		draw_colored_polygon(glow, Color(C_HAZARD, 0.18))
		draw_colored_polygon(tri, C_HAZARD)
	if _trail.size() > 1:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i in _trail.size():
			pts.append(_to_screen(_trail[i]))
			cols.append(Color(C_ACCENT, 0.45 * (1.0 - float(i) / _trail.size())))
		draw_polyline_colors(pts, cols, BALL_R * 0.9, true)
	var bp := _to_screen(Vector2(_ball_world_x(), _ball_y))
	var stretch := clampf(absf(_vy) / 1400.0, 0.0, 0.25)
	var sx := 1.0 + _squash * 0.35 - stretch * 0.5
	var sy := 1.0 - _squash * 0.3 + stretch
	draw_circle(bp, BALL_R + 8.0, Color(C_ACCENT, 0.10))
	if _ball_tex:
		draw_set_transform_matrix(Transform2D(0.0, Vector2(sx, sy), 0.0, bp + Vector2(0, BALL_R * (1.0 - sy)))
			* Transform2D(_angle, Vector2.ZERO))
		var r := BALL_R * 1.08
		draw_texture_rect(_ball_tex, Rect2(-r, -r, r * 2.0, r * 2.0), false)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_set_transform(bp + Vector2(0, BALL_R * (1.0 - sy)), 0.0, Vector2(sx, sy))
		draw_circle(Vector2.ZERO, BALL_R, C_TEXT)
		draw_arc(Vector2.ZERO, BALL_R - 1.0, 0.0, TAU, 32, C_ACCENT, 2.0, true)
		var d := Vector2.from_angle(_angle) * (BALL_R - 6.0)
		draw_line(-d, d, Color(C_ACCENT, 0.55), 3.0, true)
		draw_set_transform(Vector2.ZERO)

func _draw_ground(x0: float, x1: float, gy: float, bottom: float) -> void:
	if x1 <= x0:
		return
	var a := _to_screen(Vector2(x0, gy))
	draw_rect(Rect2(a, Vector2(x1 - x0, bottom - gy)), C_GROUND)
	draw_line(a, a + Vector2(x1 - x0, 0), Color(C_ACCENT, 0.85), 2.0)
	draw_line(a + Vector2(0, 3), a + Vector2(x1 - x0, 3), Color(C_ACCENT, 0.15), 6.0)

func _draw_pit(pit: Vector2, gy: float, bottom: float) -> void:
	var a := _to_screen(Vector2(pit.x, gy))
	var w := pit.y - pit.x
	draw_line(a, a + Vector2(0, bottom - gy), Color(C_ACCENT, 0.25), 1.0)
	draw_line(a + Vector2(w, 0), a + Vector2(w, bottom - gy), Color(C_ACCENT, 0.25), 1.0)
	var alpha := _trampoline_alpha(pit)
	if alpha <= 0.0:
		return
	var t: float = _bounce_flash.get(pit.x, 99.0)
	var dip := 10.0 * maxf(0.0, 1.0 - t * 6.0)
	var pop := 1.0 + 0.25 * (1.0 - clampf(alpha * 1.4, 0.0, 1.0))
	var inset := 10.0
	var top := gy + PIT_DEPTH + dip
	var tw := (w - inset * 2.0) / pop
	var cx := a.x + w * 0.5
	var col := Color(C_ACCENT, alpha)
	draw_line(Vector2(cx - tw * 0.4, top), Vector2(cx - tw * 0.45, gy + PIT_DEPTH + 26.0), Color(C_ACCENT, alpha * 0.5), 3.0)
	draw_line(Vector2(cx + tw * 0.4, top), Vector2(cx + tw * 0.45, gy + PIT_DEPTH + 26.0), Color(C_ACCENT, alpha * 0.5), 3.0)
	draw_rect(Rect2(cx - tw * 0.5 - 4.0, top - 4.0, tw + 8.0, 16.0), Color(C_ACCENT, alpha * 0.15))
	draw_rect(Rect2(cx - tw * 0.5, top, tw, 8.0), col)
	if t < 0.4:
		var r := 20.0 + t * 260.0
		draw_arc(Vector2(cx, top), r, PI, TAU, 32, Color(C_ACCENT, (0.4 - t) * 1.5), 2.0, true)

func refresh_variety() -> void:
	_ball_tex = UiArt.load_texture(SaveManager.get_variety_texture_path())
