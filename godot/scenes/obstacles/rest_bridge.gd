extends StaticBody2D

const WIDTH := 230.0
const ART := preload("res://assets/art/suspension_bridge.png")

func _ready() -> void:
	add_to_group("ground")
	add_to_group("rest_bridge")
	collision_layer = WorldConst.LAYER_WORLD
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(WIDTH - 20.0, 18.0)
	shape.shape = rect
	shape.position.y = 9.0
	shape.one_way_collision = true
	add_child(shape)
	var art := Sprite2D.new()
	art.texture = ART
	var k := WIDTH / ART.get_width()
	art.scale = Vector2(k, k)
	art.position.y = -ART.get_height() * k * 0.5 + 18.0
	art.z_index = -1
	add_child(art)
