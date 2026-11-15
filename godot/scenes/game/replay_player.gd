extends Node2D

const GROUND := preload("res://scenes/chunks/ground_segment.gd")
const GENERATOR := preload("res://scenes/chunks/LevelGenerator.gd")
const BACKGROUNDS: Array[Texture2D] = [
	preload("res://assets/background_mountain_farm.png"),
	preload("res://assets/background_forest_cottage.png"),
	preload("res://assets/background_pixel_farm.png"),
	preload("res://assets/background_forest_path.png"),
]
const STRIDE := 7
const SPRITE_SIZE := 70.0
const P_COLORS := [Color("FFD166"), Color("7CE0FF")]
const SPEEDS := [1.0, 2.0, 4.0, 0.5]

var data := {}
var _frames: Array = []
var _players := 1
var _t := 0.0
var _frame_i := 0
var _piece_i := 0
var _stomp_i := 0
var _speed_i := 0
var _paused := false
var _done := false
var world: Node2D
var _lead: Node2D
var _trail: Node2D
var _generator: Node2D
var _sprites: Array[Sprite2D] = []
var _tags: Array[Label] = []
var _camera: Camera2D
var _hud_labels: Array[Label] = []
var _bar: ProgressBar
var _status: Label
var _end_panel: Control
var _back: TextureRect
var _theme := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	Engine.time_scale = 1.0
	data = ReplayStore.pending
	if data.is_empty():
		GameManager.go_to_menu()
		return
	_frames = data.frames
	_players = (data.names as Array).size()
	GameManager.custom_map = data.get("map", {})
	_build_world()
	_build_hud()
	_apply_frame(0.0)

func _build_world() -> void:
	var back_layer := CanvasLayer.new()
	back_layer.layer = -5
	add_child(back_layer)
	var back := TextureRect.new()
	_back = back
	back.texture = BACKGROUNDS[0]
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back_layer.add_child(back)
	world = Node2D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	var start := StaticBody2D.new()
	start.set_script(GROUND)
	start.position = Vector2(-180, 460)
	start.set("width", 1050.0)
	start.set("thickness", 80.0)
	world.add_child(start)
	_lead = Node2D.new()
	_lead.name = "Lead"
	var starts: Array = data.get("start", [160.0])
	_lead.position = Vector2(float(starts[0]) if not starts.is_empty() else 160.0, 400)
	world.add_child(_lead)
	_trail = Node2D.new()
	_trail.name = "Trail"
	_trail.position = _lead.position
	world.add_child(_trail)
	_generator = Node2D.new()
	_generator.name = "LevelGenerator"
	_generator.set_script(GENERATOR)
	_generator.call("seed_rng", int(data.seed))
	_generator.set("ball_path", _trail.get_path())
	_generator.set("other_ball_path", _lead.get_path())
	world.add_child(_generator)
	for i in _players:
		var s := Sprite2D.new()
		var tex := UiArt.load_texture(SaveManager.get_variety_texture_path(String(data.varieties[i])))
		s.texture = tex
		if tex:
			s.scale = Vector2.ONE * (SPRITE_SIZE / maxf(tex.get_width(), tex.get_height()))
		s.z_index = 10
		if i == 1:
			s.modulate = Color(1, 1, 1, 0.92)
		world.add_child(s)
		_sprites.append(s)
		var tag := Label.new()
		tag.text = String(data.names[i])
		tag.add_theme_font_size_override("font_size", 22)
		tag.add_theme_color_override("font_color", P_COLORS[i])
		tag.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
		tag.add_theme_constant_override("outline_size", 8)
		tag.z_index = 15
		tag.visible = _players > 1
		world.add_child(tag)
		_tags.append(tag)
	_camera = Camera2D.new()
	_camera.zoom = Vector2.ONE * (0.72 if _players > 1 else 0.9)
	_camera.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_camera)
	_camera.make_current()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var top := HBoxContainer.new()
	top.position = Vector2(16, 12)
	top.add_theme_constant_override("separation", 30)
	layer.add_child(top)
	var title := _label("REPLAY", 30, Color("FFD166"))
	top.add_child(title)
	for i in _players:
		var l := _label("", 24, P_COLORS[i])
		top.add_child(l)
		_hud_labels.append(l)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.position = Vector2(16, 676)
	_bar.size = Vector2(1248, 10)
	_bar.max_value = maxf(0.01, float(data.get("duration", 1.0)))
	layer.add_child(_bar)
	_status = _label("", 15, WorldConst.C_TEXT)
	_status.position = Vector2(16, 690)
	_status.size = Vector2(1248, 24)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_status)
	_end_panel = VBoxContainer.new()
	_end_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_end_panel.offset_left = -200
	_end_panel.offset_right = 200
	_end_panel.offset_top = -110
	_end_panel.offset_bottom = 110
	_end_panel.theme = load("res://resources/themes/bounce_back_theme.tres")
	_end_panel.visible = false
	layer.add_child(_end_panel)
	var result := _label(String(data.get("result", "")).to_upper(), 40, Color("FFD166"))
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_panel.add_child(result)
	var again := Button.new()
	again.name = "WatchAgain"
	again.text = "WATCH AGAIN  (R)"
	again.custom_minimum_size = Vector2(0, 50)
	again.pressed.connect(restart)
	_end_panel.add_child(again)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "BACK  (Esc)"
	back.custom_minimum_size = Vector2(0, 46)
	back.pressed.connect(leave)
	_end_panel.add_child(back)
	_update_status()

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _process(delta: float) -> void:
	if data.is_empty() or _paused or _done:
		return
	_t += delta
	_apply_frame(_t)

func _apply_frame(t: float) -> void:
	while _frame_i < _frames.size() - 2 and float(_frames[_frame_i + 1][0]) <= t:
		_frame_i += 1
	var a: Array = _frames[_frame_i]
	var b: Array = _frames[mini(_frame_i + 1, _frames.size() - 1)]
	var span := float(b[0]) - float(a[0])
	var k := clampf((t - float(a[0])) / span, 0.0, 1.0) if span > 0.0 else 0.0
	var lead_x := -INF
	var lead_y := 360.0
	var trail_x := INF
	for i in _players:
		var o := 1 + i * STRIDE
		var pos := Vector2(lerpf(a[o], b[o], k), lerpf(a[o + 1], b[o + 1], k))
		_sprites[i].global_position = pos
		_sprites[i].rotation = lerpf(a[o + 2], b[o + 2], k)
		var dead := int(a[o + 3]) == 1
		_sprites[i].modulate.a = 0.45 if dead else 1.0
		_tags[i].global_position = pos + Vector2(-20, -84)
		var hearts := "♥".repeat(maxi(0, int(a[o + 5])))
		_hud_labels[i].text = "%s  %d m  %s%s" % [String(data.names[i]), int(a[o + 4]), hearts, "  OUT" if dead else ""]
		if not dead and pos.x > lead_x:
			lead_x = pos.x
			lead_y = pos.y
		if not dead:
			trail_x = minf(trail_x, pos.x)
		_collect_near(pos)
	var best_dist := 0
	for i in _players:
		best_dist = maxi(best_dist, int(a[1 + i * STRIDE + 4]))
	var theme := posmod(int(best_dist / GameManager.LEVEL_LENGTH_METRES), BACKGROUNDS.size())
	if theme != _theme:
		_theme = theme
		var tw := _back.create_tween()
		tw.tween_property(_back, "modulate:a", 0.2, 0.3)
		tw.tween_callback(func() -> void: _back.texture = BACKGROUNDS[theme])
		tw.tween_property(_back, "modulate:a", 1.0, 0.3)
	if lead_x == -INF:
		lead_x = _sprites[0].global_position.x
	_lead.global_position = Vector2(lead_x, lead_y)
	_trail.global_position = Vector2(lead_x if trail_x == INF else trail_x, lead_y)
	_camera.global_position = Vector2(lead_x + 260.0, 360.0)
	var pieces: Array = data.pieces
	while _piece_i < pieces.size() and float(pieces[_piece_i][0]) <= t:
		_spawn_piece(pieces[_piece_i])
		_piece_i += 1
	var stomps: Array = data.stomps
	while _stomp_i < stomps.size() and float(stomps[_stomp_i][0]) <= t:
		_stomp_at(Vector2(stomps[_stomp_i][2], stomps[_stomp_i][3]))
		_stomp_i += 1
	_bar.value = t
	if t >= float(data.get("duration", 0.0)) and _frame_i >= _frames.size() - 2:
		_finish()

func _spawn_piece(row: Array) -> void:
	var item := int(row[2])
	var node := (ItemPlacer.SCENES[item] as PackedScene).instantiate() as Node2D
	if item == GameManager.Item.RAMP:
		node.set("flipped", bool(row[5]))
	node.position = Vector2(row[3], row[4])
	world.add_child(node)
	(node as CollisionObject2D).collision_layer = 0
	if int(row[1]) == 1 and _players > 1:
		node.modulate = Color(0.75, 0.92, 1.0)

func _collect_near(pos: Vector2) -> void:
	for holder in _generator.call("get_patterns"):
		for child in (holder as Node).get_children():
			if child.has_method("take_visual") and (child as Node2D).global_position.distance_to(pos) < 48.0:
				child.call("take_visual")

func _stomp_at(pos: Vector2) -> void:
	for holder in _generator.call("get_patterns"):
		for child in (holder as Node).get_children():
			if child.is_in_group("enemy") and child.has_method("stomp") and (child as Node2D).global_position.distance_to(pos) < 90.0:
				child.call("stomp")
				return

func _finish() -> void:
	_done = true
	_end_panel.visible = true
	var first := _end_panel.get_node_or_null("WatchAgain") as Button
	if first:
		first.grab_focus()

func _update_status() -> void:
	_status.text = "%s   ·   Space %s   ·   Tab speed x%s   ·   R restart   ·   Esc back" % [
		String(data.get("saved_at", "")), "play" if _paused else "pause", str(SPEEDS[_speed_i]).trim_suffix(".0")]

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_SPACE:
			if not _done:
				_paused = not _paused
				get_tree().paused = _paused
		KEY_TAB:
			_speed_i = (_speed_i + 1) % SPEEDS.size()
			Engine.time_scale = SPEEDS[_speed_i]
		KEY_R:
			restart()
		KEY_ESCAPE:
			leave()
		_:
			return
	get_viewport().set_input_as_handled()
	_update_status()

func restart() -> void:
	AudioManager.play("click")
	get_tree().paused = false
	Engine.time_scale = 1.0
	SceneTransition.reload_scene()

func leave() -> void:
	AudioManager.play("click")
	get_tree().paused = false
	Engine.time_scale = 1.0
	GameManager.custom_map = {}
	ReplayStore.pending = {}
	GameManager.go_to_menu()
