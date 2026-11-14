extends Area2D

@export var bob_height := 42.0
@export var bob_speed := 1.8

var _time := 0.0
var _home_y := 0.0

func _ready() -> void:
	add_to_group("enemy")
	_home_y = position.y
	_time = randf() * TAU
	var halo := Polygon2D.new()
	halo.name = "DangerHalo"
	var points := PackedVector2Array()
	for i in 28:
		points.append(Vector2.from_angle(TAU * float(i) / 28.0) * 39.0)
	halo.polygon = points
	halo.color = Color(0.55, 0.18, 0.78, 0.20)
	halo.z_index = -1
	add_child(halo)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time += delta * bob_speed
	position.y = _home_y + sin(_time) * bob_height

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
