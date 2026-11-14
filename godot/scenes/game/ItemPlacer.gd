class_name ItemPlacer
extends Node2D

const SCENES := [
	preload("res://scenes/items/Trampoline.tscn"),
	preload("res://scenes/items/Ramp.tscn"),
	preload("res://scenes/items/Floor.tscn"),
]
const SIZES := [Vector2(128, 42), Vector2(192, 82), Vector2(210, 22)]
const BALL_CLEARANCE := 34.0
const GHOST_ALPHA := 0.45
const PLACE_BEHIND := 190.0
const PLACE_AHEAD := 1030.0
const PLACE_TOP := 72.0
const PLACE_BOTTOM := 690.0
const INPUT_BUFFER := 0.16

@export var ball_path: NodePath
@export var items_path: NodePath
@export var player_index := 0
@export var cursor_mode := false
@export var cursor_speed := 620.0
@export var private_pieces := false
@export var ai_controlled := false
var mouse_aim: Callable

const CURSOR_START := Vector2(330.0, 60.0)
var _cursor := CURSOR_START

var _ghost: Polygon2D
var _ghost_edge: Line2D
var _ghost_status: Label
var _queued_item := -1
var _queued_position := Vector2.ZERO
var _deny_sound_left := 0.0

func _ready() -> void:
	_ghost = Polygon2D.new()
	_ghost.top_level = true
	_ghost.z_index = 5
	add_child(_ghost)
	_ghost_edge = Line2D.new()
	_ghost_edge.width = 2.0
	_ghost_edge.closed = true
	_ghost.add_child(_ghost_edge)
	_ghost_status = Label.new()
	_ghost_status.top_level = true
	_ghost_status.z_index = 7
	_ghost_status.add_theme_font_size_override("font_size", 16)
	_ghost_status.add_theme_color_override("font_color", Color("FFD166"))
	_ghost_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ghost_status.size = Vector2(100, 28)
	add_child(_ghost_status)
	_ghost.visible = false
	_ghost_status.visible = false
	if private_pieces:
		WorldConst.set_visibility_recursive(self, WorldConst.VISIBILITY_PRIVATE[player_index])

func _action(name: String) -> String:
	return ("p2_" + name) if cursor_mode else name

func _unhandled_input(event: InputEvent) -> void:
	if ai_controlled or not GameManager.is_alive(player_index):
		return
	if event.is_action_pressed(_action("select_1")):
		GameManager.select_item(GameManager.Item.TRAMPOLINE, player_index)
		AudioManager.play("click")
	elif event.is_action_pressed(_action("select_2")):
		GameManager.select_item(GameManager.Item.RAMP, player_index)
		AudioManager.play("click")
	elif event.is_action_pressed(_action("select_3")):
		GameManager.select_item(GameManager.Item.FLOOR, player_index)
		AudioManager.play("click")
	elif cursor_mode and event.is_action_pressed("p2_cycle"):
		GameManager.select_item(((_ps().selected_item + 1) % 3) as GameManager.Item, player_index)
		AudioManager.play("click")
	elif event.is_action_pressed(_action("flip_item")):
		GameManager.flip_ramp(player_index)
		AudioManager.play("click")
	elif event.is_action_pressed(_action("place_item")):
		_request_place(aim_position())
		get_viewport().set_input_as_handled()

func _ps() -> PlayerState:
	return GameManager.player(player_index)

func aim_position() -> Vector2:
	if not cursor_mode:
		if mouse_aim.is_valid():
			return mouse_aim.call()
		return get_global_mouse_position()
	var ball := get_node_or_null(ball_path) as Node2D
	return (ball.global_position if ball else Vector2.ZERO) + _cursor

func _process(delta: float) -> void:
	_deny_sound_left = maxf(0.0, _deny_sound_left - delta)
	if cursor_mode:
		var move := Input.get_vector("p2_left", "p2_right", "p2_up", "p2_down")
		var real_delta := delta / maxf(Engine.time_scale, 0.05)
		_cursor += move * cursor_speed * real_delta
		_cursor.x = clampf(_cursor.x, -PLACE_BEHIND + 20.0, PLACE_AHEAD * 0.75)
		_cursor.y = clampf(_cursor.y, -330.0, 330.0)
	if ai_controlled or not GameManager.is_alive(player_index):
		_ghost.visible = false
		_ghost_status.visible = false
		_queued_item = -1
		return
	_try_queued_placement()
	var item: int = _ps().selected_item
	var t := placement_transform(item, aim_position())
	var geometry_ok := not overlaps_ball(item, t) and in_range(t.origin)
	var ready := _ps().is_ready(item)
	var ok := _ps().can_afford(item) and ready and geometry_ok
	var col := WorldConst.C_ACCENT if ok else (Color("FFD166") if geometry_ok and not ready else WorldConst.C_HAZARD)
	var h: Vector2 = SIZES[item] * 0.5
	var poly := _preview_polygon(item, h)
	_ghost.polygon = poly
	_ghost.color = Color(col, GHOST_ALPHA if ready else 0.26)
	_ghost_edge.points = poly
	_ghost_edge.default_color = Color(col, minf(1.0, GHOST_ALPHA + 0.35))
	_ghost.global_transform = t
	_ghost.visible = true
	if cursor_mode:
		_ghost_edge.width = 4.0
	var cooldown := _ps().cooldown_remaining(item)
	_ghost_status.visible = geometry_ok and cooldown > 0.0
	if _ghost_status.visible:
		_ghost_status.text = "%.1fs" % cooldown
		_ghost_status.global_position = t.origin + Vector2(-50.0, -h.y - 34.0)

func _preview_polygon(item: int, half_size: Vector2) -> PackedVector2Array:
	if item == GameManager.Item.RAMP:
		if _ps().ramp_flipped:
			return PackedVector2Array([Vector2(-half_size.x, -half_size.y), Vector2(-half_size.x, half_size.y), Vector2(half_size.x, half_size.y)])
		return PackedVector2Array([Vector2(-half_size.x, half_size.y), Vector2(half_size.x, -half_size.y), Vector2(half_size.x, half_size.y)])
	return PackedVector2Array([Vector2(-half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y), Vector2(half_size.x, half_size.y), Vector2(-half_size.x, half_size.y)])

func _request_place(world_pos: Vector2) -> void:
	var item: int = _ps().selected_item
	var t := placement_transform(item, world_pos)
	if overlaps_ball(item, t) or not in_range(t.origin):
		_play_deny()
		return
	if _ps().is_ready(item):
		place_at(world_pos)
		return
	if _ps().cooldown_remaining(item) <= INPUT_BUFFER:
		_queued_item = item
		_queued_position = world_pos
		return
	_play_deny()

func _try_queued_placement() -> void:
	if _queued_item < 0 or not _ps().is_ready(_queued_item):
		return
	var item := _queued_item
	var position := _queued_position
	_queued_item = -1
	var previous := _ps().selected_item
	_ps().selected_item = item
	place_at(position)
	_ps().selected_item = previous

func _play_deny() -> void:
	if ai_controlled or _deny_sound_left > 0.0:
		return
	_deny_sound_left = 0.12
	AudioManager.play("deny")

func place_at(world_pos: Vector2) -> bool:
	if not GameManager.is_alive(player_index):
		return false
	var item: int = _ps().selected_item
	var t := placement_transform(item, world_pos)
	if overlaps_ball(item, t) or not in_range(t.origin):
		_play_deny()
		return false
	if not GameManager.try_spend(item, t.origin, player_index):
		_play_deny()
		return false
	var node := (SCENES[item] as PackedScene).instantiate() as Node2D
	if item == GameManager.Item.RAMP:
		node.set("flipped", _ps().ramp_flipped)
	node.position = t.origin
	node.rotation = t.get_rotation()
	var parent := get_node_or_null(items_path)
	if parent == null:
		parent = get_parent()
	if private_pieces:
		(node as CollisionObject2D).collision_layer = WorldConst.LAYER_PIECES[player_index]
	parent.add_child(node)
	node.global_position = t.origin
	if private_pieces:
		WorldConst.set_visibility_recursive(node, WorldConst.VISIBILITY_PRIVATE[player_index])
	return true

func in_range(world_pos: Vector2) -> bool:
	var ball := get_node_or_null(ball_path) as Node2D
	if ball == null:
		return false
	var relative := world_pos - ball.global_position
	return relative.x >= -PLACE_BEHIND and relative.x <= PLACE_AHEAD \
		and world_pos.y >= PLACE_TOP and world_pos.y <= PLACE_BOTTOM

func item_rotation(item: int) -> float:
	return 0.0

func placement_transform(item: int, world_pos: Vector2) -> Transform2D:
	var rot := item_rotation(item)
	return Transform2D(rot, world_pos)

func overlaps_ball(item: int, t: Transform2D) -> bool:
	var ball := get_node_or_null(ball_path) as Node2D
	if ball == null:
		return false
	var local := t.affine_inverse() * ball.global_position
	var h: Vector2 = SIZES[item] * 0.5
	var closest := Vector2(clampf(local.x, -h.x, h.x), clampf(local.y, -h.y, h.y))
	return closest.distance_to(local) < BALL_CLEARANCE
