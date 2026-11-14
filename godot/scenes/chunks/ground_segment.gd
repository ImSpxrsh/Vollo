@tool
class_name GroundSegment
extends StaticBody2D

const C_GROUND := Color("1A1F2A")
const GRID := 64.0
const GROUND_FILL := preload("res://assets/sprites/ground_fill.png")
const GROUND_TOP := preload("res://assets/sprites/ground_top.png")

@export var width := 512.0:
	set(v):
		width = maxf(v, 8.0)
		_rebuild()
@export var thickness := 64.0:
	set(v):
		thickness = maxf(v, 8.0)
		_rebuild()
@export var ceiling := false:
	set(v):
		ceiling = v
		_rebuild()

var _owner_id := -1
var _shape: RectangleShape2D
var _edge: Line2D

func _ready() -> void:
	collision_layer = WorldConst.LAYER_WORLD
	collision_mask = 0
	add_to_group("ceiling" if ceiling else "ground")
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _owner_id < 0:
		_owner_id = create_shape_owner(self)
		_shape = RectangleShape2D.new()
		shape_owner_add_shape(_owner_id, _shape)
	_shape.size = Vector2(width, thickness)
	shape_owner_set_transform(_owner_id, Transform2D(0.0, Vector2(width, thickness) * 0.5))
	if _edge == null:
		_edge = Line2D.new()
		_edge.width = 2.0
		_edge.default_color = Color("7EA899")
		_edge.begin_cap_mode = Line2D.LINE_CAP_NONE
		add_child(_edge, false, Node.INTERNAL_MODE_FRONT)
	var y := thickness if ceiling else 0.0
	_edge.points = PackedVector2Array([Vector2(0.0, y), Vector2(width, y)])
	queue_redraw()

func get_span() -> Vector2:
	return Vector2(global_position.x, global_position.x + width)

func _draw() -> void:
	var accent := Color("7EA899")
	if not ceiling:
		var fade := PackedVector2Array([Vector2(0, thickness), Vector2(width, thickness),
				Vector2(width, thickness + 220.0), Vector2(0, thickness + 220.0)])
		var c0 := Color(C_GROUND, 0.55)
		var c1 := Color(C_GROUND, 0.0)
		draw_polygon(fade, PackedColorArray([c0, c0, c1, c1]))
	draw_texture_rect(GROUND_FILL, Rect2(0, 0, width, thickness), true)
	var lip_y := thickness - 16.0 if ceiling else 0.0
	var lip_source_y := 104.0 if ceiling else 0.0
	draw_texture_rect_region(GROUND_TOP, Rect2(0, lip_y, width, 16.0),
		Rect2(0, lip_source_y, 121.0, 16.0))
	var faint := Color(accent, 0.035)
	var start := ceilf(global_position.x / GRID) * GRID - global_position.x if is_inside_tree() else 0.0
	var x := start
	while x < width:
		draw_line(Vector2(x, 0), Vector2(x, thickness), faint, 1.0)
		x += GRID
	draw_line(Vector2(0, thickness * 0.5), Vector2(width, thickness * 0.5), faint, 1.0)
	var side := Color(accent, 0.35)
	draw_line(Vector2(0, 0), Vector2(0, thickness), side, 2.0)
	draw_line(Vector2(width, 0), Vector2(width, thickness), side, 2.0)
	var ey := thickness if ceiling else 0.0
	draw_rect(Rect2(0, ey - 4.0, width, 8.0), Color(accent, 0.045), true)
