extends Node

@export var difficulty := 1
@export var player_index := 1

var ball: RigidBody2D
var placer: Node2D

const LEVELS := [
	[0.42, 0.85, 0.45, 44.0],
	[0.2, 1.25, 0.15, 16.0],
	[0.11, 1.5, 0.0, 0.0],
	[0.05, 1.8, 0.0, 0.0],
]
const STEP := 1.0 / 30.0
const RADIUS := 30.0
const FALL_Y := 690.0
const FLOOR_LANE_Y := 520.0
const CLEARANCE := 64.0
const TRAMP_OFFSET := 58.0
const LOW_Y := 470.0
const JUMP_WINDOW := 0.8

var _think_left := 0.0
var _rng := RandomNumberGenerator.new()
var _shape := CircleShape2D.new()
var _gravity := 627.0
var last_action := ""
var debug := false
var history: Array[String] = []

func _ready() -> void:
	_rng.randomize()
	_shape.radius = RADIUS
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 627.0))

func _physics_process(delta: float) -> void:
	if ball == null or placer == null or not is_instance_valid(ball):
		return
	if not GameManager.is_alive(player_index) or ball.get("dead") == true:
		return
	_think_left -= delta
	if _think_left > 0.0:
		return
	_think_left = LEVELS[difficulty][0] * _rng.randf_range(0.8, 1.2)
	think()

func think() -> String:
	if difficulty >= 3:
		return _plan()
	var event := predict()
	if event.is_empty():
		return ""
	if _rng.randf() < LEVELS[difficulty][2]:
		return ""
	var action := _respond(event)
	if debug:
		print("  bot ball=%s v=%s event=%s t=%.2f low=%s -> %s" % [ball.global_position.round(), ball.linear_velocity.round(), event.kind, event.t, event.get("low", "-"), action])
	if not action.is_empty():
		last_action = action
	return action

func predict() -> Dictionary:
	var pos := ball.global_position
	var vel := ball.linear_velocity
	var speed := float(ball.get("speed"))
	if float(ball.get("boost_left")) > 0.0:
		return {}
	vel.x = speed
	var horizon: float = LEVELS[difficulty][1]
	var space := ball.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = WorldConst.LAYER_WORLD | WorldConst.LAYER_HAZARD | ball.collision_mask
	query.exclude = [ball.get_rid()]
	var t := 0.0
	var supported_steps := 0
	while t < horizon:
		t += STEP
		vel.y += _gravity * STEP
		pos += vel * STEP
		if pos.y > FALL_Y:
			return {"kind": "fall", "t": t, "pos": pos}
		query.transform = Transform2D(0.0, pos)
		var hits := space.intersect_shape(query, 8)
		var hazard: Node2D = null
		var support: Node2D = null
		for hit in hits:
			var c := hit.get("collider") as Node2D
			if c == null:
				continue
			if c.is_in_group("hazard"):
				hazard = c
				break
			if c is StaticBody2D:
				support = c
		if hazard:
			return {"kind": "hazard", "t": t, "pos": pos, "node": hazard, "low": _is_low(hazard, pos)}
		if support:
			if support.is_in_group("trampoline"):
				vel.y = -650.0
			elif support.is_in_group("ramp"):
				vel.y = 280.0 if support.get("flipped") == true else -390.0
			elif support.is_in_group("ceiling") or support.global_position.y < pos.y - 10.0:
				vel.y = maxf(vel.y, 150.0)
			else:
				vel.y = minf(vel.y, 0.0)
				pos.y -= 2.0
				supported_steps += 1
	return {}

func _is_low(hazard: Node2D, at: Vector2) -> bool:
	if hazard.is_in_group("hazard_wall"):
		return hazard.global_transform.y.y > 0.0
	if hazard.is_in_group("spike"):
		return absf(wrapf(hazard.global_rotation, -PI, PI)) < 1.0
	if hazard.is_in_group("enemy"):
		return at.y >= hazard.global_position.y - 10.0
	return hazard.global_position.y > 360.0

func _respond(event: Dictionary) -> String:
	var t: float = event.t
	match String(event.kind):
		"fall":
			if ball.global_position.y > LOW_Y:
				var lead := clampf(t * 0.5, 0.12, 0.4)
				if _place(GameManager.Item.TRAMPOLINE, _future(lead) + Vector2(0, TRAMP_OFFSET)):
					return "tramp"
			var catch_t := _time_at_y(FLOOR_LANE_Y, t)
			var p := _future(catch_t) + Vector2(0, 46)
			return "floor" if _place(GameManager.Item.FLOOR, p) else ("tramp" if _place(GameManager.Item.TRAMPOLINE, p + Vector2(0, 12)) else "")
		"hazard":
			if bool(event.low):
				if t > JUMP_WINDOW:
					return ""
				var lead := clampf(t - 0.3, 0.1, 0.45)
				var p := _future(lead) + Vector2(0, TRAMP_OFFSET)
				if _place(GameManager.Item.TRAMPOLINE, p):
					return "tramp"
				var wait := GameManager.player(player_index).cooldown_remaining(GameManager.Item.TRAMPOLINE)
				if wait < t - 0.25 and difficulty > 0:
					return ""
				_set_flip(false)
				return "ramp_up" if _place(GameManager.Item.RAMP, p + Vector2(0, 20)) else ""
			if ball.linear_velocity.y < 0.0:
				var above := _future(0.12) - Vector2(0, CLEARANCE)
				return "ceiling" if _place(GameManager.Item.FLOOR, above) else ""
			_set_flip(true)
			var under := _future(0.12) + Vector2(0, CLEARANCE)
			return "ramp_down" if _place(GameManager.Item.RAMP, under) else ""
	return ""

func _future(t: float) -> Vector2:
	var v := ball.linear_velocity
	v.x = float(ball.get("speed"))
	return ball.global_position + v * t + Vector2(0, 0.5 * _gravity * t * t)

func _time_at_y(y: float, max_t: float) -> float:
	var t := 0.05
	while t < max_t:
		if _future(t).y >= y:
			return maxf(0.12, t - 0.05)
		t += STEP
	return maxf(0.12, max_t * 0.6)

func _set_flip(flipped: bool) -> void:
	if GameManager.player(player_index).ramp_flipped != flipped:
		GameManager.flip_ramp(player_index)

func _place(item: int, world_pos: Vector2) -> bool:
	if not GameManager.player(player_index).is_ready(item):
		return false
	var jitter: float = LEVELS[difficulty][3]
	var p := world_pos + Vector2(_rng.randf_range(-jitter, jitter), _rng.randf_range(-jitter, jitter) * 0.5)
	GameManager.select_item(item, player_index)
	return bool(placer.call("place_at", p))

const PLAN_HORIZON := 2.2
const PLAN_STEP := 1.0 / 30.0
const PLAN_RADIUS := 37.0
const COMMIT_T := 0.3
const PLAN_BUDGET_USEC := 8000
const HALF := [Vector2(64, 21), Vector2(96, 41), Vector2(105, 11)]
const VY_TRAMP := -650.0
const VY_RAMP_UP := -390.0
const VY_RAMP_DOWN := 280.0

func _plan() -> String:
	if float(ball.get("boost_left")) > 0.0:
		return ""
	var query := _plan_query()
	var base := _simulate(query, {})
	if base.safe:
		return ""
	var best := {}
	var best_score := _score(base)
	var path: Array = base.path
	var ps := GameManager.player(player_index)
	var started := Time.get_ticks_usec()
	for k in range(1, path.size()):
		if Time.get_ticks_usec() - started > PLAN_BUDGET_USEC:
			break
		var tau := k * PLAN_STEP
		if tau > minf(base.t, 1.3):
			break
		var at: Vector2 = path[k][0]
		var vel: Vector2 = path[k][1]
		for c in _candidates(at, vel):
			if Time.get_ticks_usec() - started > PLAN_BUDGET_USEC:
				break
			if not ps.is_ready(c.item):
				continue
			c.tau = tau
			if bool(placer.call("overlaps_ball", c.item, Transform2D(0.0, c.pos))) or not bool(placer.call("in_range", c.pos)):
				continue
			var sim := _simulate(query, c)
			var score := _score(sim)
			if score <= best_score + 0.01:
				continue
			for shift in [-PLAN_STEP, PLAN_STEP]:
				var alt: Dictionary = c.duplicate()
				alt.tau = tau + shift
				score = minf(score, _score(_simulate(query, alt)))
			score -= tau * 0.05
			if score > best_score + 0.01:
				best_score = score
				best = c
	if best.is_empty():
		return ""
	if float(best.tau) > COMMIT_T and float(base.t) > float(best.tau) + 0.35:
		return ""
	if int(best.item) == GameManager.Item.RAMP:
		_set_flip(bool(best.flip))
	GameManager.select_item(int(best.item), player_index)
	if bool(placer.call("place_at", best.pos)):
		last_action = String(best.name)
		if debug:
			history.append("%s@%.2f %s y=%d" % [best.name, best.tau, str((best.pos - ball.global_position).round()), ball.global_position.y])
		return last_action
	return ""

func _candidates(at: Vector2, vel: Vector2) -> Array:
	var out := []
	var r := RADIUS + 2.0
	out.append({"item": GameManager.Item.TRAMPOLINE, "pos": at + Vector2(0, r + HALF[0].y), "name": "tramp"})
	out.append({"item": GameManager.Item.FLOOR, "pos": at + Vector2(70, r + HALF[2].y), "name": "floor"})
	out.append({"item": GameManager.Item.RAMP, "pos": at + Vector2(0, r + HALF[1].y * 0.5), "flip": false, "name": "ramp_up"})
	out.append({"item": GameManager.Item.RAMP, "pos": at + Vector2(0, r + HALF[1].y * 0.5), "flip": true, "name": "ramp_down"})
	if vel.y < -60.0:
		out.append({"item": GameManager.Item.FLOOR, "pos": at + Vector2(40, -r - HALF[2].y), "name": "ceiling"})
	return out

func _score(sim: Dictionary) -> float:
	if sim.safe:
		return 10.0 - absf(float(sim.end_y) - 360.0) / 400.0
	return float(sim.t)

func _plan_query() -> PhysicsShapeQueryParameters2D:
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = PLAN_RADIUS
	query.shape = shape
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = WorldConst.LAYER_WORLD | WorldConst.LAYER_HAZARD | ball.collision_mask
	query.exclude = [ball.get_rid()]
	return query

func _simulate(query: PhysicsShapeQueryParameters2D, piece: Dictionary) -> Dictionary:
	var pos := ball.global_position
	var vel := ball.linear_velocity
	vel.x = float(ball.get("speed"))
	var space := ball.get_world_2d().direct_space_state
	var path := [[pos, vel]]
	var used := piece.is_empty()
	var t := 0.0
	while t < PLAN_HORIZON:
		t += PLAN_STEP
		vel.y += _gravity * PLAN_STEP
		pos += vel * PLAN_STEP
		if not used and t >= float(piece.tau) - 0.001:
			used = true
			_apply_piece(piece, pos, vel)
			pos = _last_pos
			vel = _last_vel
		elif not piece.is_empty() and used and int(piece.item) == GameManager.Item.FLOOR and String(piece.name) == "floor":
			var p: Vector2 = piece.pos
			if absf(pos.x - p.x) <= HALF[2].x and pos.y > p.y - HALF[2].y - RADIUS and pos.y < p.y and vel.y > 0.0:
				pos.y = p.y - HALF[2].y - RADIUS
				vel.y = 0.0
		if pos.y > FALL_Y:
			return {"safe": false, "t": t, "path": path, "end_y": pos.y}
		query.transform = Transform2D(0.0, pos)
		var hits := space.intersect_shape(query, 8)
		for hit in hits:
			var c := hit.get("collider") as Node2D
			if c == null:
				continue
			if c.is_in_group("hazard"):
				return {"safe": false, "t": t, "path": path, "end_y": pos.y}
		for hit in hits:
			var c := hit.get("collider") as Node2D
			if c == null or not (c is StaticBody2D):
				continue
			if c.is_in_group("trampoline"):
				vel.y = VY_TRAMP
			elif c.is_in_group("ramp"):
				vel.y = VY_RAMP_DOWN if c.get("flipped") == true else VY_RAMP_UP
			elif c.is_in_group("ceiling") or c.global_position.y < pos.y - 10.0:
				vel.y = maxf(vel.y, 150.0)
			else:
				vel.y = minf(vel.y, 0.0)
				pos.y -= 2.0
			break
		path.append([pos, vel])
	return {"safe": true, "t": t, "path": path, "end_y": pos.y}

var _last_pos := Vector2.ZERO
var _last_vel := Vector2.ZERO

func _apply_piece(piece: Dictionary, pos: Vector2, vel: Vector2) -> void:
	match String(piece.name):
		"tramp":
			vel.y = VY_TRAMP
		"ramp_up":
			vel.y = VY_RAMP_UP
		"ramp_down":
			vel.y = VY_RAMP_DOWN
		"floor":
			pos.y = float(piece.pos.y) - HALF[2].y - RADIUS
			vel.y = 0.0
		"ceiling":
			vel.y = maxf(vel.y, 150.0)
	_last_pos = pos
	_last_vel = vel
