class_name BaseItem
extends StaticBody2D

const EXPIRE_TIME := 1.0
const EXPIRE_SHADER := preload("res://shaders/item_expire.gdshader")
const BLUE_WALL_TEXTURE := preload("res://assets/art/icon_wall.png")
const FLOOR_TEXTURE := preload("res://assets/art/floor.png")

@export var size := Vector2(128.0, 20.0)
@export var color := Color("00F5D4")
@export var lifetime := 4.0

var age := 0.0
var expire_ratio := 0.0
var visual: Node2D
var _body_poly: Polygon2D
var _top_line: Line2D
var _material: ShaderMaterial
var _expired := false

func _init() -> void:
	collision_layer = 1
	collision_mask = 0

func _ready() -> void:
	add_to_group("item")
	if SaveManager.has_upgrade("long_life"):
		lifetime += 1.0
	_build_collision()
	_build_visual()
	_spawn_pop()
	AudioManager.play("place")

func _physics_process(delta: float) -> void:
	if _expired:
		return
	age += delta
	var left := lifetime - age
	if left <= EXPIRE_TIME:
		if _material == null:
			_material = ShaderMaterial.new()
			_material.shader = EXPIRE_SHADER
			_material.set_shader_parameter("edge_color", Color("FF3366"))
			visual.material = _material
		expire_ratio = clampf(1.0 - left / EXPIRE_TIME, 0.0, 1.0)
		_material.set_shader_parameter("expire_ratio", expire_ratio)
	if age >= lifetime:
		_expired = true
		AudioManager.play("expire")
		queue_free()

func get_corners() -> PackedVector2Array:
	var h := size * 0.5
	return PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])

func react() -> void:
	if visual == null:
		return
	var tw := create_tween()
	visual.scale = Vector2(1.08, 0.7)
	tw.tween_property(visual, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _build_collision() -> void:
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		add_child(cs)
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect

func _build_visual() -> void:
	visual = get_node_or_null("Visual") as Node2D
	if visual == null:
		visual = Node2D.new()
		visual.name = "Visual"
		add_child(visual)
	if is_in_group("wall"):
		var wall_art := Sprite2D.new()
		wall_art.name = "WallArt"
		wall_art.texture = BLUE_WALL_TEXTURE
		wall_art.scale = Vector2(size.x * 1.5 / BLUE_WALL_TEXTURE.get_width(), size.y * 1.1 / BLUE_WALL_TEXTURE.get_height())
		wall_art.use_parent_material = true
		visual.add_child(wall_art)
		return
	if is_in_group("floor"):
		var floor_art := Sprite2D.new()
		floor_art.name = "FloorArt"
		floor_art.texture = FLOOR_TEXTURE
		floor_art.scale = Vector2((size.x + 8.0) / FLOOR_TEXTURE.get_width(), (size.y + 14.0) / FLOOR_TEXTURE.get_height())
		floor_art.position.y = 3.0
		floor_art.use_parent_material = true
		visual.add_child(floor_art)
		return
	var glow := Polygon2D.new()
	var g := size * 0.5 + Vector2(5.0, 5.0)
	glow.polygon = PackedVector2Array([Vector2(-g.x, -g.y), Vector2(g.x, -g.y), Vector2(g.x, g.y), Vector2(-g.x, g.y)])
	glow.color = Color(color, 0.16)
	glow.use_parent_material = true
	visual.add_child(glow)
	_body_poly = Polygon2D.new()
	_body_poly.polygon = get_corners()
	var top := color
	var bottom := color.darkened(0.45)
	_body_poly.vertex_colors = PackedColorArray([top, top, bottom, bottom])
	_body_poly.use_parent_material = true
	visual.add_child(_body_poly)
	var h := size * 0.5
	_top_line = Line2D.new()
	_top_line.points = PackedVector2Array([Vector2(-h.x + 1.0, -h.y + 1.5), Vector2(h.x - 1.0, -h.y + 1.5)])
	_top_line.width = minf(3.0, size.y * 0.3)
	_top_line.default_color = color.lightened(0.55)
	_top_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_top_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_top_line.use_parent_material = true
	visual.add_child(_top_line)

func _spawn_pop() -> void:
	visual.scale = Vector2(0.55, 0.55)
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
