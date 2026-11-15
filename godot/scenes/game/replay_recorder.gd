class_name ReplayRecorder
extends Node

const RATE := 1.0 / 30.0

var balls: Array = []
var generator: Node
var data := {}
var last_path := ""
var _t := 0.0
var _acc := 0.0
var _running := false

func setup(ball_nodes: Array, gen: Node, mode: String, names: Array) -> void:
	balls = ball_nodes
	generator = gen
	var varieties: Array = []
	for i in balls.size():
		varieties.append(GameManager.player(i).variety_id)
	data = {
		"mode": mode,
		"names": names,
		"varieties": varieties,
		"seed": 0,
		"map": GameManager.custom_map.duplicate(true),
		"start": [],
		"frames": [],
		"pieces": [],
		"stomps": [],
		"result": "",
		"distances": [],
	}
	for i in balls.size():
		var ps := GameManager.player(i)
		ps.item_placed.connect(_on_item_placed.bind(i))
		ps.stomped.connect(_on_stomped.bind(i))
	GameManager.run_over.connect(_on_run_over)
	GameManager.versus_over.connect(_on_versus_over)

func _physics_process(delta: float) -> void:
	if balls.is_empty():
		return
	if not _running:
		if not GameManager.is_playing() or GameManager.input_locked:
			return
		_running = true
		data.seed = int(generator.call("get_run_seed"))
		for b: Node2D in balls:
			data.start.append(b.global_position.x)
		_snapshot()
	if not GameManager.is_playing():
		return
	_t += delta
	_acc += delta
	if _acc >= RATE:
		_acc -= RATE
		_snapshot()

func _snapshot() -> void:
	var frame := [_t]
	for i in balls.size():
		var b: Node2D = balls[i]
		var ps := GameManager.player(i)
		frame.append_array([
			roundf(b.global_position.x * 10.0) / 10.0,
			roundf(b.global_position.y * 10.0) / 10.0,
			snappedf(float(b.get("_roll_angle")), 0.01),
			1 if (b.get("dead") == true or not ps.alive) else 0,
			ps.distance,
			ps.health,
			1 if b.get("has_shield") == true else 0,
		])
	data.frames.append(frame)

func _on_item_placed(item: int, pos: Vector2, p: int) -> void:
	if not _running:
		return
	data.pieces.append([_t, p, item, pos.x, pos.y, GameManager.player(p).ramp_flipped])

func _on_stomped(pos: Vector2, _bonus: int, p: int) -> void:
	if _running:
		data.stomps.append([_t, p, pos.x, pos.y])

func _on_run_over(distance: int, _best: int, _is_new_best: bool, _bounces: int) -> void:
	_finish(["%d m" % distance], [distance])

func _on_versus_over(winner: int, distances: Array) -> void:
	var names: Array = data.names
	_finish(["%s wins" % names[winner]] if winner >= 0 else ["Tie"], distances)

func _finish(result: Array, distances: Array) -> void:
	if not _running or data.frames.size() < 30:
		return
	_snapshot()
	_running = false
	data.result = String(result[0])
	data.distances = distances
	data.duration = _t
	last_path = ReplayStore.save(data)
	balls = []
