class_name LevelGenerator
extends Node2D

const START_X := 900.0
const AHEAD := 3400.0
const BEHIND := 1500.0
const TOP_Y := 80.0
const BOTTOM_Y := 650.0
const LEVEL_SPAN_PX := 3840.0
const LEVEL_GAP := 400.0
const THEME_PATTERN_POOLS := [
	[0, 1, 2, 3, 6],
	[0, 2, 3, 4, 6],
	[1, 2, 4, 5, 6],
	[2, 3, 4, 5, 6],
]
const THEME_SPACING := [1.08, 1.0, 0.94, 0.88]

const GUIDED_COURSE := [
	{
		"spacing": 700.0,
		"steps": [
			{"k": "low_wall", "x": 120, "h": 0.5, "y": 330},
			{"k": "coins", "y": 420, "extra": "bridge"},
			{"k": "low_wall", "x": 110, "h": 0.65, "y": 300, "extra": "shield"},
			{"k": "hang_wall", "x": 120, "h": 0.5, "y": 470},
		],
	},
	{
		"spacing": 600.0,
		"steps": [
			{"k": "spikes_low", "x": 60, "n": 2, "y": 360},
			{"k": "hang_wall", "x": 110, "h": 0.7, "y": 480},
			{"k": "low_wall", "x": 90, "h": 0.8, "y": 280, "extra": "slowmo"},
			{"k": "spikes_both", "x": 50, "n": 2, "y": 365},
			{"k": "offset", "x": 30, "h": 0.75, "y": 345, "extra": "bridge"},
		],
	},
	{
		"spacing": 600.0,
		"steps": [
			{"k": "low_wall", "x": 90, "h": 1.0, "y": 255},
			{"k": "enemy", "x": 130, "y": 265, "extra": "booster"},
			{"k": "spikes_both", "x": 40, "n": 3, "y": 360, "extra": "slowmo"},
			{"k": "grump", "x": 140, "y": 300},
			{"k": "hang_wall", "x": 120, "h": 1.0, "y": 490, "extra": "shield"},
		],
	},
]

const HAZARD_WALL := preload("res://scenes/obstacles/HazardWall.tscn")
const SPIKE := preload("res://scenes/obstacles/Spike.tscn")
const WANDERER := preload("res://scenes/obstacles/WanderingHazard.tscn")
const GRUMP := preload("res://scenes/obstacles/GrumpBall.tscn")
const SHIELD := preload("res://scenes/obstacles/ShieldBubble.tscn")
const STAR := preload("res://scenes/obstacles/StarPickup.tscn")
const SLOWMO := preload("res://scenes/obstacles/SlowMoClock.tscn")
const BOOSTER := preload("res://scenes/obstacles/SpeedBooster.tscn")
const BRIDGE := preload("res://scenes/obstacles/RestBridge.tscn")
const WARNING_TEXTURE := preload("res://assets/art/warning_sign.png")
const LANTERN_TEXTURE := preload("res://assets/art/lantern_post.png")
const PIPE_TEXTURE := preload("res://assets/art/broken_pipe.png")
const FENCE_TEXTURE := preload("res://assets/art/chain_fence.png")

@export var ball_path: NodePath
@export var other_ball_path: NodePath

var _rng := RandomNumberGenerator.new()
var _ball: Node2D
var _other_ball: Node2D
var _patterns: Array[Node2D] = []
var _next_x := START_X
var _pattern_index := 0
var _last_pattern_type := -1
var _seed_is_explicit := false
var _layout_codes: Array[String] = []
var _origin_x := 160.0
var _next_level_x := 0.0
var _level := 1
var _step_in_level := 0
var _random_index := 0
static var _run_nonce := 0

func _init() -> void:
	_randomize_run_seed()

func _ready() -> void:
	_ball = get_node_or_null(ball_path) as Node2D
	if not other_ball_path.is_empty():
		_other_ball = get_node_or_null(other_ball_path) as Node2D
	reset()

func _physics_process(_delta: float) -> void:
	if _ball and is_instance_valid(_ball):
		var x := _ball.global_position.x
		if _other_ball and is_instance_valid(_other_ball):
			var ox := _other_ball.global_position.x
			if _other_ball.get("dead") == true:
				ox = x
			elif _ball.get("dead") == true:
				x = ox
			update_for_range(minf(x, ox), maxf(x, ox))
		else:
			update_for_x(x)

func seed_rng(value: int) -> void:
	_rng.seed = value
	_seed_is_explicit = true

func get_run_seed() -> int:
	return _rng.seed

func get_layout_signature() -> String:
	return "|".join(_layout_codes)

func get_level_signature(level: int) -> String:
	var prefix := "L%d:" % level
	return "|".join(PackedStringArray(_layout_codes.filter(func(code: String) -> bool: return code.begins_with(prefix))))

func get_patterns() -> Array:
	var live: Array = []
	for pattern in _patterns:
		if is_instance_valid(pattern):
			live.append(pattern)
	return live

func get_rows() -> Array:
	return get_patterns()

static func guided_level_count() -> int:
	return GUIDED_COURSE.size()

func reset() -> void:
	if _seed_is_explicit:
		_seed_is_explicit = false
	else:
		_randomize_run_seed()
	for pattern in _patterns:
		if is_instance_valid(pattern):
			pattern.queue_free()
	_patterns.clear()
	_next_x = START_X
	_pattern_index = 0
	_last_pattern_type = -1
	_layout_codes.clear()
	_level = 1
	_step_in_level = 0
	_random_index = 0
	if _ball and is_instance_valid(_ball):
		var start: Variant = _ball.get("start_x")
		_origin_x = float(start) if start is float and float(start) != 0.0 else _ball.global_position.x
	_next_level_x = _origin_x + LEVEL_SPAN_PX
	var x := _ball.global_position.x if _ball and is_instance_valid(_ball) else 0.0
	update_for_x(x)

func _randomize_run_seed() -> void:
	_run_nonce += 1
	_rng.seed = Time.get_ticks_usec() ^ get_instance_id() ^ (_run_nonce * 7919)

func update_for_x(x: float) -> void:
	update_for_range(x, x)

func update_for_range(trail_x: float, lead_x: float) -> void:
	var x := trail_x
	var guard := 0
	while _next_x < lead_x + AHEAD and guard < 48:
		_spawn_next()
		guard += 1
	while not _patterns.is_empty():
		var first := _patterns[0]
		if not is_instance_valid(first):
			_patterns.pop_front()
			continue
		if first.global_position.x < x - BEHIND:
			_patterns.pop_front()
			first.queue_free()
		else:
			break

func current_metres() -> float:
	return maxf(0.0, (_next_x - START_X) / WorldConst.METRE)

func current_level() -> int:
	return _level

func _spawn_next() -> void:
	if _next_x + 650.0 > _next_level_x:
		_start_next_level()
	elif _level <= GUIDED_COURSE.size():
		_spawn_guided()
	else:
		_spawn_random()

func _new_holder(x: float, label: String) -> Node2D:
	var holder := Node2D.new()
	holder.name = "%s_%03d" % [label, _pattern_index]
	holder.position.x = x
	add_child(holder)
	holder.add_to_group("hazard_pattern")
	_patterns.append(holder)
	_pattern_index += 1
	return holder

func _start_next_level() -> void:
	var x := maxf(_next_x, _next_level_x - 300.0)
	var holder := _new_holder(x, "LevelGap")
	_add_star_arc(holder, 60.0, 380.0, -30.0, 5)
	_layout_codes.append("N%d:%d" % [_level + 1, roundi(x)])
	_level += 1
	_step_in_level = 0
	_next_level_x += LEVEL_SPAN_PX
	_next_x = x + LEVEL_GAP

func _spawn_guided() -> void:
	var level_data: Dictionary = GUIDED_COURSE[_level - 1]
	var steps: Array = level_data.steps
	var step: Dictionary = steps[_step_in_level] if _step_in_level < steps.size() else {"k": "coins", "y": 380}
	var holder := _new_holder(_next_x, "Guided")
	var route_y := float(step.get("y", 360))
	var hx := float(step.get("x", 100))
	var height := float(step.get("h", 1.0))
	match String(step.k):
		"low_wall":
			_add_wall(holder, hx, BOTTOM_Y, false, height)
		"hang_wall":
			_add_wall(holder, hx, TOP_Y, true, height)
		"spikes_low":
			_add_spike_bank(holder, hx, BOTTOM_Y, false, int(step.get("n", 2)))
		"spikes_both":
			_add_spike_bank(holder, hx, BOTTOM_Y, false, int(step.get("n", 2)))
			_add_spike_bank(holder, hx, TOP_Y, true, int(step.get("n", 2)))
		"offset":
			_add_wall(holder, hx, BOTTOM_Y, false, height)
			_add_wall(holder, hx + 280.0, TOP_Y, true, height)
		"enemy":
			_add_enemy(holder, hx, route_y + 100.0, 60.0)
		"grump":
			_add_grump(holder, hx, route_y + 120.0, 110.0)
	var arc := 18.0 if route_y > 350.0 else -18.0
	_add_star_arc(holder, 150.0 if String(step.k) != "coins" else 40.0, route_y, arc, 4 if String(step.k) == "coins" else 3)
	_add_extra(holder, String(step.get("extra", "")), route_y)
	_add_dressing(holder, true)
	_layout_codes.append("L%d:%s:%d:%d" % [_level, step.k, roundi(route_y), roundi(_next_x)])
	_step_in_level += 1
	_next_x += float(level_data.spacing)

func _spawn_random() -> void:
	var holder := _new_holder(_next_x, "Random")
	var random_levels := _level - GUIDED_COURSE.size() - 1
	var difficulty := clampf(0.2 + random_levels * 0.14 + _step_in_level * 0.015, 0.0, 1.0)
	var theme_index := posmod(_level - 1, THEME_PATTERN_POOLS.size())
	var route_y := 350.0
	var pattern_type := _choose_pattern_type(difficulty, theme_index)
	match pattern_type:
		0:
			_add_wall(holder, _rng.randf_range(55.0, 135.0), BOTTOM_Y, false, _rng.randf_range(0.8, 1.0))
			route_y = _rng.randf_range(225.0, 285.0)
		1:
			_add_wall(holder, _rng.randf_range(65.0, 145.0), TOP_Y, true, _rng.randf_range(0.8, 1.0))
			route_y = _rng.randf_range(465.0, 525.0)
		2:
			var teeth_x := _rng.randf_range(20.0, 85.0)
			var teeth_count := _rng.randi_range(2, 3)
			_add_spike_bank(holder, teeth_x, BOTTOM_Y, false, teeth_count)
			_add_spike_bank(holder, teeth_x, TOP_Y, true, teeth_count)
			route_y = _rng.randf_range(335.0, 395.0)
		3:
			_add_wall(holder, _rng.randf_range(10.0, 55.0), BOTTOM_Y, false)
			_add_wall(holder, _rng.randf_range(245.0, 325.0), TOP_Y, true)
			route_y = _rng.randf_range(315.0, 375.0)
		4:
			_add_enemy(holder, _rng.randf_range(90.0, 165.0), _rng.randf_range(315.0, 405.0), _rng.randf_range(68.0, 108.0))
			_add_spike_bank(holder, _rng.randf_range(285.0, 340.0), BOTTOM_Y, false, 2)
			route_y = _rng.randf_range(230.0, 290.0)
		5:
			_add_spike_bank(holder, _rng.randf_range(5.0, 40.0), TOP_Y, true, 2)
			_add_wall(holder, _rng.randf_range(215.0, 280.0), BOTTOM_Y, false)
			route_y = _rng.randf_range(245.0, 305.0)
		_:
			route_y = _rng.randf_range(260.0, 320.0)
			_add_grump(holder, _rng.randf_range(120.0, 200.0), route_y + _rng.randf_range(120.0, 170.0), _rng.randf_range(90.0, 150.0))
			if difficulty > 0.5:
				_add_spike_bank(holder, _rng.randf_range(20.0, 60.0), TOP_Y, true, 2)
	_add_star_arc(holder, _rng.randf_range(110.0, 160.0), route_y, _rng.randf_range(12.0, 26.0) * (-1.0 if route_y > 350.0 else 1.0), 3)
	if difficulty > 0.55 and _rng.randf() < lerpf(0.15, 0.42, difficulty):
		_add_enemy(holder, _rng.randf_range(330.0, 385.0), route_y + _rng.randf_range(55.0, 85.0), 54.0)
	var roll := _rng.randf()
	var extra := ""
	if roll < lerpf(0.10, 0.06, difficulty):
		extra = "shield"
	elif roll < lerpf(0.18, 0.13, difficulty):
		extra = "slowmo"
	elif roll < lerpf(0.26, 0.21, difficulty):
		extra = "booster"
	elif roll < lerpf(0.36, 0.25, difficulty) and pattern_type in [0, 2, 3]:
		extra = "bridge"
	_add_extra(holder, extra, route_y)
	_add_dressing(holder, false)
	_layout_codes.append("L%d:%d:%d:%d" % [_level, pattern_type, roundi(route_y), roundi(_next_x)])
	_step_in_level += 1
	_random_index += 1
	var spacing := lerpf(610.0, 430.0, difficulty)
	_next_x += spacing * THEME_SPACING[theme_index] + _rng.randf_range(-45.0, 45.0)

func _choose_pattern_type(difficulty: float, theme_index: int) -> int:
	var pool: Array = THEME_PATTERN_POOLS[theme_index]
	var choice: int
	if difficulty > 0.72 and _rng.randf() < 0.24:
		choice = _rng.randi_range(0, 6)
	else:
		choice = int(pool[_rng.randi_range(0, pool.size() - 1)])
	if choice == _last_pattern_type:
		var alternatives: Array = pool.filter(func(value: int) -> bool: return value != choice)
		choice = int(alternatives[_rng.randi_range(0, alternatives.size() - 1)])
	_last_pattern_type = choice
	return choice

func _add_wall(holder: Node2D, x: float, base_y: float, inverted: bool, height := 1.0) -> void:
	var wall := HAZARD_WALL.instantiate() as Node2D
	var sink := 256.0 * (1.0 - clampf(height, 0.2, 1.0))
	wall.position = Vector2(x, base_y - sink if inverted else base_y + sink)
	wall.scale.y = -1.0 if inverted else 1.0
	holder.add_child(wall)
	_add_warning(holder, x - 74.0, 600.0 if not inverted else 130.0)

func _add_spike_bank(holder: Node2D, x: float, base_y: float, inverted: bool, count: int) -> void:
	for i in count:
		var spike := SPIKE.instantiate() as Node2D
		spike.position = Vector2(x + i * 62.0, base_y)
		spike.rotation = PI if inverted else 0.0
		holder.add_child(spike)

func _add_enemy(holder: Node2D, x: float, y: float, bob: float) -> void:
	var enemy := WANDERER.instantiate() as Node2D
	enemy.position = Vector2(x, y)
	enemy.set("bob_height", bob)
	holder.add_child(enemy)

func _add_grump(holder: Node2D, x: float, y: float, patrol: float) -> void:
	var grump := GRUMP.instantiate() as Node2D
	grump.position = Vector2(x, y)
	grump.set("patrol_width", patrol)
	holder.add_child(grump)

func _add_extra(holder: Node2D, kind: String, route_y: float) -> void:
	match kind:
		"shield":
			_add_at(holder, SHIELD, Vector2(300.0, route_y - 60.0))
		"slowmo":
			_add_at(holder, SLOWMO, Vector2(320.0, route_y - 30.0))
		"booster":
			_add_at(holder, BOOSTER, Vector2(330.0, route_y + 10.0))
		"bridge":
			_add_at(holder, BRIDGE, Vector2(320.0, minf(route_y + 90.0, 560.0)))

func _add_at(holder: Node2D, scene: PackedScene, pos: Vector2) -> void:
	var node := scene.instantiate() as Node2D
	node.position = pos
	holder.add_child(node)

func _add_star(holder: Node2D, x: float, y: float) -> void:
	_add_at(holder, STAR, Vector2(x, y))

func _add_star_arc(holder: Node2D, start_x: float, y: float, arc_height: float, count: int) -> void:
	for i in count:
		var t := float(i) / maxf(1.0, float(count - 1))
		var curve := sin(t * PI) * arc_height
		_add_star(holder, start_x + i * 66.0, y + curve)

func _add_warning(holder: Node2D, x: float, y: float) -> void:
	var warning := Sprite2D.new()
	warning.texture = WARNING_TEXTURE
	warning.position = Vector2(x, y)
	warning.scale = Vector2.ONE * 0.22
	warning.modulate.a = 0.85
	warning.z_index = -2
	holder.add_child(warning)

func _add_dressing(holder: Node2D, guided: bool) -> void:
	var r := float(_pattern_index * 37 % 100) / 100.0 if guided else _rng.randf()
	var prop := Sprite2D.new()
	var y := 600.0
	var target_size := 110.0
	if r < 0.4:
		prop.texture = LANTERN_TEXTURE
		target_size = 120.0
	elif r < 0.7:
		prop.texture = FENCE_TEXTURE
		y = 620.0
	else:
		prop.texture = PIPE_TEXTURE
		y = 150.0
	prop.position = Vector2(-110.0 + r * 40.0, y)
	prop.modulate = Color(0.8, 0.84, 0.9, 0.55)
	prop.z_index = -3
	var max_dimension := maxf(prop.texture.get_width(), prop.texture.get_height())
	prop.scale = Vector2.ONE * (target_size / max_dimension)
	holder.add_child(prop)
