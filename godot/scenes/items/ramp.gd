extends BaseItem

const RAMP_TEXTURE := preload("res://assets/art/icon_ramp.png")

@export var flipped := false

func _build_collision() -> void:
	var inherited_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if inherited_shape:
		inherited_shape.disabled = true
		inherited_shape.queue_free()
	var collision := CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	var points := PackedVector2Array([
		Vector2(-size.x * 0.5, size.y * 0.5),
		Vector2(size.x * 0.5, size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
	])
	if flipped:
		for i in points.size():
			points[i].x *= -1.0
	collision.polygon = points
	add_child(collision)

func _build_visual() -> void:
	visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)
	var art := Sprite2D.new()
	art.name = "RampArt"
	art.texture = RAMP_TEXTURE
	art.scale = Vector2(size.x / RAMP_TEXTURE.get_width(), size.y / RAMP_TEXTURE.get_height())
	art.flip_h = flipped
	art.use_parent_material = true
	visual.add_child(art)

func react() -> void:
	if visual == null:
		return
	var tween := create_tween()
	visual.scale = Vector2(0.92, 1.08)
	tween.tween_property(visual, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
