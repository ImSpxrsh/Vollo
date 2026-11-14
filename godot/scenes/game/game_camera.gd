extends Camera2D

@export var target: NodePath
@export var look_ahead := 315.0
@export var follow_x := 7.5
@export var max_shake_offset := Vector2(28.0, 22.0)
@export var max_shake_rotation := 0.04

var _noise := FastNoiseLite.new()
var _time := 0.0
var _target: Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ignore_rotation = false
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 1.0
	_noise.seed = randi()
	_target = get_node_or_null(target) as Node2D
	if _target:
		position = Vector2(_target.global_position.x + look_ahead, 360.0)
	make_current()

func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_target = get_node_or_null(target) as Node2D
	if _target and is_instance_valid(_target) and not get_tree().paused:
		var target_speed := 300.0
		var speed_value: Variant = _target.get("speed")
		if speed_value is float:
			target_speed = speed_value
		var adaptive_look_ahead := look_ahead + clampf((target_speed - 300.0) / 420.0, 0.0, 1.0) * 115.0
		if SaveManager.reduce_motion:
			position.x = _target.global_position.x + look_ahead
		else:
			position.x = lerpf(position.x, _target.global_position.x + adaptive_look_ahead, 1.0 - exp(-follow_x * delta))
		position.y = 360.0
	_shake(delta)

func _shake(delta: float) -> void:
	_time += delta / maxf(Engine.time_scale, 0.05) * 30.0
	var amount := 0.0 if SaveManager.reduce_motion else pow(GameManager.trauma, 2.0) * SaveManager.screen_shake_intensity
	if amount <= 0.0001:
		offset = Vector2.ZERO
		rotation = 0.0
		return
	offset = Vector2(max_shake_offset.x * _noise.get_noise_2d(_time, 0.0),
		max_shake_offset.y * _noise.get_noise_2d(0.0, _time)) * amount
	rotation = max_shake_rotation * amount * _noise.get_noise_2d(_time, 100.0)
