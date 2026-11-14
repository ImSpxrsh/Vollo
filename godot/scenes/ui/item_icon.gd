extends Control

@export var item := 0:
	set(v):
		item = v
		queue_redraw()
@export var flipped := false:
	set(v):
		flipped = v
		queue_redraw()
@export var small_slope := false:
	set(v):
		small_slope = v
		queue_redraw()
@export var tint := Color.WHITE:
	set(v):
		tint = v
		queue_redraw()

func _draw() -> void:
	var s := size
	var c := s * 0.5
	if small_slope:
		var pts := PackedVector2Array([Vector2(3, s.y - 3), Vector2(s.x - 3, 3), Vector2(s.x - 3, s.y - 3)])
		if flipped:
			pts = PackedVector2Array([Vector2(3, 3), Vector2(s.x - 3, s.y - 3), Vector2(3, s.y - 3)])
		draw_colored_polygon(pts, Color(WorldConst.C_RAMP, 0.9) * tint)
		return
	match item:
		0:
			var w := s.x * 0.8
			var top := c.y + s.y * 0.12
			draw_line(Vector2(c.x - w * 0.38, top), Vector2(c.x - w * 0.45, s.y * 0.92), Color(WorldConst.C_ACCENT, 0.6) * tint, 3.0, true)
			draw_line(Vector2(c.x + w * 0.38, top), Vector2(c.x + w * 0.45, s.y * 0.92), Color(WorldConst.C_ACCENT, 0.6) * tint, 3.0, true)
			draw_rect(Rect2(c.x - w * 0.5, top - 4.0, w, 8.0), WorldConst.C_ACCENT * tint)
			draw_circle(Vector2(c.x, s.y * 0.26), s.y * 0.13, WorldConst.C_TEXT * tint)
		1:
			var pts := PackedVector2Array([Vector2(s.x * 0.1, s.y * 0.82), Vector2(s.x * 0.9, s.y * 0.82), Vector2(s.x * 0.9, s.y * 0.3)])
			if flipped:
				pts = PackedVector2Array([Vector2(s.x * 0.1, s.y * 0.82), Vector2(s.x * 0.9, s.y * 0.82), Vector2(s.x * 0.1, s.y * 0.3)])
			draw_colored_polygon(pts, WorldConst.C_RAMP * tint)
		_:
			var w := s.x * 0.82
			var y := s.y * 0.57
			draw_rect(Rect2(c.x - w * 0.5 - 3.0, y - 6.0, w + 6.0, 18.0), Color(WorldConst.C_WALL, 0.18) * tint)
			draw_rect(Rect2(c.x - w * 0.5, y - 3.0, w, 10.0), Color("9EA39A") * tint)
			draw_line(Vector2(c.x - w * 0.5, y - 3.0), Vector2(c.x + w * 0.5, y - 3.0), Color("E3DFC8") * tint, 2.0)
