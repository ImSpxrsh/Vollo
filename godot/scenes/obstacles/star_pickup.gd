extends Area2D

var _time := 0.0
var _home_y := 0.0
var _taken := false
var _ball: Node2D
var _magnet := false
const MAGNET_RADIUS := 170.0
const MAGNET_SPEED := 900.0

@onready var _art: Sprite2D = $Art

func _ready() -> void:
	_home_y = position.y
	_magnet = SaveManager.has_upgrade("magnet")
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _taken:
		return
	_time += delta
	if _magnet and _pull_to_ball(delta):
		return
	position.y = _home_y + sin(_time * 2.1) * 6.0
	_art.rotation = sin(_time * 1.4) * 0.08
	_art.scale = Vector2(0.34 * absf(cos(_time * 2.2)) + 0.04, 0.34)

func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("ball"):
		return
	_taken = true
	GameManager.collect_star(int(body.get("player_index")) if body.get("player_index") != null else 0)
	if body.has_method("versus_speed_change"):
		body.call("versus_speed_change", 5.0)
	AudioManager.play("coin", 0.05, -4.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.16)
	tw.chain().tween_callback(queue_free)

func _pull_to_ball(delta: float) -> bool:
	if _ball == null or not is_instance_valid(_ball):
		_ball = get_tree().get_first_node_in_group("ball") as Node2D
		if _ball == null:
			return false
	var to_ball := _ball.global_position - global_position
	if to_ball.length() > MAGNET_RADIUS:
		return false
	global_position += to_ball.normalized() * minf(to_ball.length(), MAGNET_SPEED * delta)
	return true
