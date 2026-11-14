class_name Pickup
extends Area2D

var art: Texture2D
var art_size := 64.0
var radius := 28.0
var bob_height := 7.0

var _time := 0.0
var _taken := false
var _sprite: Sprite2D

func _ready() -> void:
	add_to_group("pickup")
	collision_layer = WorldConst.LAYER_PICKUPS
	collision_mask = WorldConst.LAYER_BALL
	_time = randf() * TAU
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	if art:
		_sprite = Sprite2D.new()
		_sprite.texture = art
		_sprite.scale = Vector2.ONE * (art_size / maxf(art.get_width(), art.get_height()))
		add_child(_sprite)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _taken or _sprite == null:
		return
	_time += delta
	_sprite.position.y = sin(_time * 2.4) * bob_height

func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("ball"):
		return
	_taken = true
	set_deferred("monitoring", false)
	_collect(body)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE * 1.6, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(queue_free)

func _collect(_ball: Node2D) -> void:
	pass
