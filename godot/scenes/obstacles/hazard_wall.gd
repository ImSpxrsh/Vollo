extends StaticBody2D

const W := 56.0
const H := 256.0
const OUTLINE := 6.0
const C_BODY := Color("E2364B")
const C_DARK := Color("A3192E")
const C_WARN := Color("FFD02A")
const HC_FRAME := 12.0
const HC_STRIPE := 16.0

var _time := 0.0
var _high_contrast := false
var _reduce_motion := false
var _hc_rects: Array[Rect2] = []
var _hc_stripes: Array[PackedVector2Array] = []

func _ready() -> void:
	add_to_group("hazard")
	add_to_group("hazard_wall")
	SaveManager.settings_changed.connect(_apply_settings)
	_apply_settings()

func _apply_settings() -> void:
	_high_contrast = SaveManager.high_contrast_hazards
	_reduce_motion = SaveManager.reduce_motion
	set_process(not _reduce_motion)
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var pulse := 0.12 if _reduce_motion else 0.12 + 0.07 * sin(_time * 3.4)
	var hw := W * 0.5
	draw_rect(Rect2(-hw - 14.0, -H - 14.0, W + 28.0, H + 14.0), Color(1.0, 0.15, 0.25, pulse), true)
	draw_rect(Rect2(-hw - OUTLINE, -H - OUTLINE, W + OUTLINE * 2.0, H + OUTLINE), Color.BLACK, true)
	draw_rect(Rect2(-hw, -H, W, H), C_BODY, true)
	var y := -H + 70.0
	while y < 30.0:
		var a := Vector2(-hw, y)
		var b := Vector2(hw, y - W * 0.7)
		_fill(_clip_band(a, b, 14.0, hw), C_DARK)
		y += 46.0
	draw_rect(Rect2(-hw, -H, W, 36.0), Color("1B1B22"), true)
	var x := -hw - 30.0
	while x < hw:
		var band := PackedVector2Array([Vector2(x, -H + 36.0), Vector2(x + 14.0, -H + 36.0), Vector2(x + 30.0, -H), Vector2(x + 16.0, -H)])
		_fill(_clip_poly(band, hw), C_WARN)
		x += 28.0
	draw_line(Vector2(-hw, -H + 37.0), Vector2(hw, -H + 37.0), Color.BLACK, 4.0)
	draw_line(Vector2(-hw + 7.0, -H + 46.0), Vector2(-hw + 7.0, -10.0), Color(1.0, 0.75, 0.78, 0.55), 4.0)
	if _high_contrast:
		_draw_hazard_frame(hw)

func _draw_hazard_frame(hw: float) -> void:
	if _hc_rects.is_empty():
		_build_hazard_frame(hw)
	for r: Rect2 in _hc_rects:
		draw_rect(r, C_WARN, true)
	for part: PackedVector2Array in _hc_stripes:
		_fill(part, Color.BLACK)
	for r: Rect2 in _hc_rects:
		draw_rect(r, Color.BLACK, false, 2.0)

func _build_hazard_frame(hw: float) -> void:
	var o := hw + OUTLINE
	var top := -H - OUTLINE - HC_FRAME
	_hc_rects = [
		Rect2(-o - HC_FRAME, top, HC_FRAME, H + OUTLINE + HC_FRAME),
		Rect2(o, top, HC_FRAME, H + OUTLINE + HC_FRAME),
		Rect2(-o, top, o * 2.0, HC_FRAME),
	]
	var span := H + OUTLINE + HC_FRAME
	for r: Rect2 in _hc_rects:
		var rect_poly := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		var x := -o - HC_FRAME - span
		while x < o + HC_FRAME:
			var stripe := PackedVector2Array([Vector2(x, top), Vector2(x + HC_STRIPE, top),
				Vector2(x + HC_STRIPE + span, top + span), Vector2(x + span, top + span)])
			for part: PackedVector2Array in Geometry2D.intersect_polygons(stripe, rect_poly):
				_hc_stripes.append(part)
			x += HC_STRIPE * 2.0

func _fill(poly: PackedVector2Array, color: Color) -> void:
	if poly.size() >= 3:
		draw_colored_polygon(poly, color)

func _clip_band(a: Vector2, b: Vector2, thickness: float, hw: float) -> PackedVector2Array:
	var band := PackedVector2Array([a, b, b + Vector2(0, thickness), a + Vector2(0, thickness)])
	return _clip_poly(band, hw)

func _clip_poly(poly: PackedVector2Array, hw: float) -> PackedVector2Array:
	var body := PackedVector2Array([Vector2(-hw, -H), Vector2(hw, -H), Vector2(hw, 0), Vector2(-hw, 0)])
	var parts := Geometry2D.intersect_polygons(poly, body)
	return parts[0] if not parts.is_empty() else PackedVector2Array()
