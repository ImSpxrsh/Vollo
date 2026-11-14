class_name KillPlane
extends Area2D

@export var target: NodePath
@export var plane_y := 1200.0

var _target: Node2D

func _ready() -> void:
	add_to_group("kill_plane")
	body_entered.connect(_on_body_entered)
	if not target.is_empty():
		_target = get_node_or_null(target) as Node2D
	global_position.y = _fall_limit()

func _physics_process(_delta: float) -> void:
	if _target and is_instance_valid(_target):
		global_position = Vector2(_target.global_position.x, _fall_limit())

func _fall_limit() -> float:
	if _target and _target.has_method("get_fall_limit_y"):
		return float(_target.call("get_fall_limit_y")) + 64.0
	return plane_y

func _on_body_entered(body: Node2D) -> void:
	if body is RigidBody2D and body.has_method("kill"):
		body.call_deferred("kill")
