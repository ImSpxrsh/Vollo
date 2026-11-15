extends Node2D

const SIZES := [Vector2(128, 42), Vector2(192, 82), Vector2(210, 22)]
const GLOW := Color("FFD166")

var item := 2

func _ready() -> void:
	z_index = 60
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _shape() -> PackedVector2Array:
	var h: Vector2 = SIZES[clampi(item, 0, 2)] * 0.5
	if item == 1:
		return PackedVector2Array([Vector2(-h.x, h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y)])
	return PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])

func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.5 + 0.5 * sin(t * 6.0)
	var poly := _shape()
	draw_colored_polygon(poly, Color(GLOW, 0.4 + 0.25 * pulse))
	var outline := poly.duplicate()
	outline.append(poly[0])
	draw_polyline(outline, Color(Color.WHITE.lerp(GLOW, pulse), 1.0), 5.0, true)
	var h: Vector2 = SIZES[clampi(item, 0, 2)] * 0.5
	var bob := 8.0 * sin(t * 5.0)
	var tip := Vector2(0, -h.y - 18.0 + bob)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-20, -26), tip + Vector2(20, -26)]), GLOW)
	draw_rect(Rect2(tip + Vector2(-7, -58), Vector2(14, 34)), GLOW)
	var font := ThemeDB.fallback_font
	var text := "CLICK HERE"
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	var at := tip + Vector2(-size.x * 0.5, -70)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0.2, 0.08, 0.02))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
