extends Area2D

@export var patrol_width := 120.0
@export var patrol_speed := 1.4

const RADIUS := 30.0
const ART := preload("res://assets/art/dead_ball_hazard.png")

var _time := 0.0
var _home_x := 0.0
var _art: Sprite2D

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("hazard")
	collision_layer = WorldConst.LAYER_HAZARD
	collision_mask = WorldConst.LAYER_BALL
	_home_x = position.x
	_time = randf() * TAU
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS - 4.0
	shape.shape = circle
	add_child(shape)
	_art = Sprite2D.new()
	_art.texture = ART
	_art.scale = Vector2.ONE * (RADIUS * 2.0 / ART.get_width())
	add_child(_art)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time += delta * patrol_speed
	var old_x := position.x
	position.x = _home_x + sin(_time) * patrol_width
	_art.rotation += (position.x - old_x) / RADIUS

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball") and body.has_method("hit_by_enemy"):
		body.call_deferred("hit_by_enemy", self)

func stomp() -> void:
	if not is_in_group("hazard"):
		return
	remove_from_group("hazard")
	remove_from_group("enemy")
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_process(false)
	var tw := create_tween().set_parallel(true)
	scale = Vector2(1.35, 0.55)
	tw.tween_property(self, "scale", Vector2(0.2, 1.6), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_property(self, "position:y", position.y + 40.0, 0.25)
	tw.chain().tween_callback(queue_free)
