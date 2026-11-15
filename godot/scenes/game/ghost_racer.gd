class_name GhostRacer
extends Node2D

## Plays a saved solo replay back as a see-through ball so you can race your
## old self. The level is rebuilt from the replay's seed (see main.gd), so the
## ghost rolls through the same course you are on. Purely visual: the ghost
## never collides with anything.

const FRAME_STRIDE := 7
const GHOST_ALPHA := 0.45
const SPRITE_DIAMETER := 70.0

var _frames: Array = []
var _t := 0.0
var _i := 0
var _started := false
var _finished := false
var _final_distance := 0
var _ghost_distance := 0
var _sprite: Sprite2D
var _tag: Label
var _gap: Label

func setup(replay: Dictionary) -> void:
	_frames = replay.get("frames", [])
	var distances: Array = replay.get("distances", [])
	_final_distance = int(distances[0]) if not distances.is_empty() else 0
	z_index = 4
	var varieties: Array = replay.get("varieties", ["yellow"])
	var tex := UiArt.load_texture(SaveManager.get_variety_texture_path(String(varieties[0]) if not varieties.is_empty() else "yellow"))
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	if tex:
		_sprite.scale = Vector2.ONE * (SPRITE_DIAMETER / maxf(tex.get_width(), 1.0))
	_sprite.modulate = Color(0.75, 0.9, 1.0, GHOST_ALPHA)
	add_child(_sprite)
	_tag = Label.new()
	_tag.text = "GHOST"
	_tag.add_theme_font_size_override("font_size", 18)
	_tag.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 0.85))
	_tag.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02, 0.8))
	_tag.add_theme_constant_override("outline_size", 6)
	_tag.position = Vector2(-30, -66)
	add_child(_tag)
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_gap = Label.new()
	_gap.name = "GhostGap"
	_gap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_gap.offset_left = -330.0
	_gap.offset_right = -24.0
	_gap.offset_top = 116.0
	_gap.offset_bottom = 146.0
	_gap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gap.add_theme_font_size_override("font_size", 18)
	_gap.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	_gap.add_theme_constant_override("outline_size", 6)
	_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_gap)
	if not _frames.is_empty():
		_apply(_frames[0], _frames[0], 0.0)
	_update_gap()

func _physics_process(delta: float) -> void:
	if _frames.is_empty():
		return
	if not _started:
		# Start on the same tick the recorder starts, so both clocks line up.
		if not GameManager.is_playing() or GameManager.input_locked:
			return
		_started = true
	if not GameManager.is_playing():
		return
	_t += delta
	while _i + 1 < _frames.size() and float(_frames[_i + 1][0]) <= _t:
		_i += 1
	if _i + 1 >= _frames.size():
		if not _finished:
			_finished = true
			_apply(_frames[_i], _frames[_i], 0.0)
			_tag.text = "GHOST  ·  %d m" % _final_distance
			create_tween().tween_property(_sprite, "modulate:a", 0.18, 0.6)
	else:
		var a: Array = _frames[_i]
		var b: Array = _frames[_i + 1]
		var span := maxf(float(b[0]) - float(a[0]), 0.0001)
		_apply(a, b, clampf((_t - float(a[0])) / span, 0.0, 1.0))
	_update_gap()

func _apply(a: Array, b: Array, k: float) -> void:
	global_position = Vector2(lerpf(float(a[1]), float(b[1]), k), lerpf(float(a[2]), float(b[2]), k))
	_sprite.rotation = lerpf(float(a[3]), float(b[3]), k)
	_ghost_distance = int(a[5])
	if int(a[4]) == 1:
		_sprite.modulate.a = 0.18

func _update_gap() -> void:
	var gap := GameManager.distance - (_final_distance if _finished else _ghost_distance)
	if _finished and gap > 0:
		_gap.text = "GHOST BEATEN  ·  +%d m" % gap
		_gap.add_theme_color_override("font_color", Color("8EF0A0"))
	elif gap >= 0:
		_gap.text = "AHEAD OF GHOST  ·  +%d m" % gap
		_gap.add_theme_color_override("font_color", Color("8EF0A0"))
	else:
		_gap.text = "BEHIND GHOST  ·  %d m" % gap
		_gap.add_theme_color_override("font_color", Color("FFB27A"))

## Ghost position for tests and tooling.
func ghost_time() -> float:
	return _t
