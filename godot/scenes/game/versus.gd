extends Node2D

const BALL := preload("res://scenes/game/Ball.tscn")
const BOT := preload("res://scenes/game/bot_controller.gd")
const CAMERA := preload("res://scenes/game/GameCamera.tscn")
const GROUND := preload("res://scenes/chunks/ground_segment.gd")
const GENERATOR := preload("res://scenes/chunks/LevelGenerator.gd")
const PLACER := preload("res://scenes/game/ItemPlacer.gd")
const BACKGROUNDS: Array[Texture2D] = [
	preload("res://assets/background_mountain_farm.png"),
	preload("res://assets/background_forest_cottage.png"),
	preload("res://assets/background_pixel_farm.png"),
	preload("res://assets/background_forest_path.png"),
]
const HALF_H := 358.0
const ZOOM := 0.58
const P_COLORS := [Color("FFD166"), Color("7CE0FF")]
const COUNTDOWN := 3

var balls: Array[Node2D] = []
var placers: Array[Node2D] = []
var views: Array[SubViewport] = []
var world: Node2D
var _backdrops: Array[TextureRect] = []
var _ceiling: StaticBody2D
var _hud: CanvasLayer
var _panels: Array[Dictionary] = []
var _lead_label: Label
var _out_shades: Array[ColorRect] = []
var _results: Control
var _results_shown := false
var _countdown_label: Label
var bot: Node
var _p2_name := "P2"

func _ready() -> void:
	ensure_p2_actions()
	GameManager.versus = true
	_p2_name = "BOT" if GameManager.versus_bot else "P2"
	_build_split()
	_build_world()
	_build_hud()
	GameManager.player_out.connect(_on_player_out)
	GameManager.versus_over.connect(_on_versus_over)
	for i in 2:
		GameManager.player(i).level_changed.connect(_on_level_changed.bind(i))
	GameManager.start_run()
	_start_countdown()

static func ensure_p2_actions() -> void:
	var keys := {
		"p2_left": [KEY_LEFT], "p2_right": [KEY_RIGHT], "p2_up": [KEY_UP], "p2_down": [KEY_DOWN],
		"p2_place_item": [KEY_ENTER, KEY_KP_ENTER], "p2_select_1": [KEY_COMMA], "p2_select_2": [KEY_PERIOD],
		"p2_select_3": [KEY_SLASH], "p2_flip_item": [KEY_APOSTROPHE], "p2_cycle": [],
	}
	var pad_buttons := {"p2_place_item": JOY_BUTTON_A, "p2_cycle": JOY_BUTTON_X, "p2_flip_item": JOY_BUTTON_Y}
	var pad_axes := {"p2_left": [JOY_AXIS_LEFT_X, -1.0], "p2_right": [JOY_AXIS_LEFT_X, 1.0],
		"p2_up": [JOY_AXIS_LEFT_Y, -1.0], "p2_down": [JOY_AXIS_LEFT_Y, 1.0]}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.3)
		for k: Key in keys[action]:
			var ev := InputEventKey.new()
			ev.keycode = k
			InputMap.action_add_event(action, ev)
		if pad_buttons.has(action):
			var jb := InputEventJoypadButton.new()
			jb.button_index = pad_buttons[action]
			jb.device = -1
			InputMap.action_add_event(action, jb)
		if pad_axes.has(action):
			var ja := InputEventJoypadMotion.new()
			ja.axis = pad_axes[action][0]
			ja.axis_value = pad_axes[action][1]
			ja.device = -1
			InputMap.action_add_event(action, ja)

func _build_split() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Split"
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.05, 0.03)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)
	for i in 2:
		var box := SubViewportContainer.new()
		box.name = "Half%d" % (i + 1)
		box.stretch = true
		box.position = Vector2(0, 0 if i == 0 else 720.0 - HALF_H)
		box.size = Vector2(1280, HALF_H)
		layer.add_child(box)
		var view := SubViewport.new()
		view.name = "View%d" % (i + 1)
		view.handle_input_locally = false
		view.size = Vector2i(1280, int(HALF_H))
		box.add_child(view)
		views.append(view)
		var back_layer := CanvasLayer.new()
		back_layer.layer = -5
		view.add_child(back_layer)
		var back := TextureRect.new()
		back.texture = BACKGROUNDS[0]
		back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back_layer.add_child(back)
		_backdrops.append(back)
	views[1].world_2d = views[0].world_2d
	views[0].canvas_cull_mask = 1 | WorldConst.VISIBILITY_PRIVATE[0]
	views[1].canvas_cull_mask = 1 | WorldConst.VISIBILITY_PRIVATE[1]
	var divider := ColorRect.new()
	divider.color = Color("2A160A")
	divider.position = Vector2(0, HALF_H)
	divider.size = Vector2(1280, 720.0 - HALF_H * 2.0)
	layer.add_child(divider)

func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	views[0].add_child(world)
	var start := StaticBody2D.new()
	start.name = "StartPlatform"
	start.set_script(GROUND)
	start.position = Vector2(-180, 460)
	start.set("width", 1050.0)
	start.set("thickness", 80.0)
	world.add_child(start)
	_ceiling = StaticBody2D.new()
	_ceiling.name = "Ceiling"
	_ceiling.add_to_group("ceiling")
	_ceiling.collision_layer = WorldConst.LAYER_WORLD
	_ceiling.collision_mask = 0
	var cshape := CollisionShape2D.new()
	var crect := RectangleShape2D.new()
	crect.size = Vector2(9000, 52)
	cshape.shape = crect
	cshape.position = Vector2(0, -4)
	_ceiling.add_child(cshape)
	world.add_child(_ceiling)
	var items := Node2D.new()
	items.name = "Items"
	for i in 2:
		var ball := BALL.instantiate() as Node2D
		ball.name = "Ball%d" % (i + 1)
		ball.set("player_index", i)
		ball.position = Vector2(160.0, 400.0)
		world.add_child(ball)
		(ball as CollisionObject2D).collision_mask = WorldConst.LAYER_WORLD | WorldConst.LAYER_HAZARD | WorldConst.LAYER_PIECES[i]
		ball.set("private_visibility", WorldConst.VISIBILITY_PRIVATE[i])
		balls.append(ball)
		_add_tag(ball, i)
	for i in 2:
		_make_ghost(balls[i], i)
	var generator := Node2D.new()
	generator.name = "LevelGenerator"
	generator.set_script(GENERATOR)
	generator.set("ball_path", balls[0].get_path())
	generator.set("other_ball_path", balls[1].get_path())
	world.add_child(generator)
	world.move_child(generator, 0)
	world.add_child(items)
	for i in 2:
		var placer := Node2D.new()
		placer.name = "Placer%d" % (i + 1)
		placer.set_script(PLACER)
		placer.set("ball_path", balls[i].get_path())
		placer.set("items_path", items.get_path())
		placer.set("player_index", i)
		placer.set("cursor_mode", i == 1 and not GameManager.versus_bot)
		placer.set("ai_controlled", i == 1 and GameManager.versus_bot)
		placer.set("private_pieces", true)
		world.add_child(placer)
		placers.append(placer)
		var cam := CAMERA.instantiate() as Camera2D
		cam.name = "Camera%d" % (i + 1)
		cam.set("target", balls[i].get_path())
		cam.zoom = Vector2(ZOOM, ZOOM)
		views[i].add_child(cam)
		if i == 0:
			placer.set("mouse_aim", _p1_mouse_world.bind(cam))
	if GameManager.versus_bot:
		bot = Node.new()
		bot.name = "Bot"
		bot.set_script(BOT)
		bot.set("ball", balls[1])
		bot.set("placer", placers[1])
		bot.set("player_index", 1)
		bot.set("difficulty", GameManager.bot_difficulty)
		world.add_child(bot)

func _p1_mouse_world(cam: Camera2D) -> Vector2:
	var screen := get_viewport().get_mouse_position()
	var half_centre := Vector2(640.0, HALF_H * 0.5)
	return cam.get_screen_center_position() + (screen - half_centre) / cam.zoom

func _make_ghost(ball: Node2D, i: int) -> void:
	var visual := ball.get_node("Visual")
	var trail := ball.get_node("Trail")
	WorldConst.set_visibility_recursive(visual, WorldConst.VISIBILITY_PRIVATE[i])
	WorldConst.set_visibility_recursive(trail, WorldConst.VISIBILITY_PRIVATE[i])
	var body := ball.get_node_or_null("Visual/Variety/Body") as Sprite2D
	if body == null:
		return
	var ghost := Sprite2D.new()
	ghost.name = "Ghost"
	ghost.texture = body.texture
	ghost.scale = body.scale
	ghost.modulate = Color(1, 1, 1, 0.42)
	ghost.z_index = -1
	ball.add_child(ghost)
	ghost.visibility_layer = WorldConst.VISIBILITY_PRIVATE[1 - i]

func _add_tag(ball: Node2D, i: int) -> void:
	var tag := Label.new()
	tag.text = "P1" if i == 0 else _p2_name
	tag.add_theme_font_size_override("font_size", 26)
	tag.add_theme_color_override("font_color", P_COLORS[i])
	tag.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	tag.add_theme_constant_override("outline_size", 8)
	tag.position = Vector2(-18, -82)
	tag.z_index = 15
	ball.add_child(tag)

func _process(_delta: float) -> void:
	if balls.size() < 2:
		return
	var mid := (balls[0].global_position.x + balls[1].global_position.x) * 0.5
	_ceiling.global_position = Vector2(mid, -26.0)
	_update_hud()

func _on_level_changed(_number: int, _level_name: String, theme: int, p: int) -> void:
	var back := _backdrops[p]
	var tex := BACKGROUNDS[posmod(theme, BACKGROUNDS.size())]
	if back.texture == tex:
		return
	var tw := back.create_tween()
	tw.tween_property(back, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void: back.texture = tex)
	tw.tween_property(back, "modulate:a", 1.0, 0.4)

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "VersusHud"
	_hud.layer = 5
	add_child(_hud)
	for i in 2:
		var top := 0.0 if i == 0 else 720.0 - HALF_H
		var shade := ColorRect.new()
		shade.color = Color(0.05, 0.02, 0.02, 0.0)
		shade.position = Vector2(0, top)
		shade.size = Vector2(1280, HALF_H)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud.add_child(shade)
		_out_shades.append(shade)
		_panels.append(_make_panel(i, top))
	_lead_label = Label.new()
	_lead_label.position = Vector2(440, HALF_H - 13.0)
	_lead_label.size = Vector2(400, 30)
	_lead_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lead_label.add_theme_font_size_override("font_size", 16)
	_lead_label.add_theme_color_override("font_color", WorldConst.C_TEXT)
	_lead_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	_lead_label.add_theme_constant_override("outline_size", 6)
	_hud.add_child(_lead_label)
	var help := Label.new()
	help.name = "Controls"
	help.text = "P1  mouse · 1/2/3 · R flip · click to place          P2  arrows · , . / · ' flip · Enter   (or gamepad: stick · X · Y · A)"
	if GameManager.versus_bot:
		help.text = "You: mouse to aim · 1/2/3 pick a piece · R flips · click to place.   Beat the %s bot!" % ["EASY", "NORMAL", "HARD"][GameManager.bot_difficulty]
	help.position = Vector2(0, 720.0 - 30.0)
	help.size = Vector2(1280, 24)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", WorldConst.C_TEXT)
	help.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	help.add_theme_constant_override("outline_size", 6)
	_hud.add_child(help)
	var tw := help.create_tween()
	tw.tween_interval(9.0)
	tw.tween_property(help, "modulate:a", 0.0, 0.8)
	_countdown_label = Label.new()
	_countdown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 120)
	_countdown_label.add_theme_color_override("font_color", Color("FFD166"))
	_countdown_label.add_theme_color_override("font_outline_color", Color(0.15, 0.06, 0.02))
	_countdown_label.add_theme_constant_override("outline_size", 18)
	_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_countdown_label)

func _make_panel(i: int, top: float) -> Dictionary:
	var panel := PanelContainer.new()
	panel.position = Vector2(12, top + 10)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.12, 0.07, 0.03, 0.85)
	box.border_color = P_COLORS[i]
	box.set_border_width_all(3)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", box)
	_hud.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var name_label := Label.new()
	name_label.text = "P1" if i == 0 else _p2_name
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", P_COLORS[i])
	row.add_child(name_label)
	var hearts := HBoxContainer.new()
	hearts.add_theme_constant_override("separation", 2)
	row.add_child(hearts)
	var dist := Label.new()
	dist.custom_minimum_size = Vector2(96, 0)
	dist.add_theme_font_size_override("font_size", 26)
	dist.add_theme_color_override("font_color", WorldConst.C_TEXT)
	row.add_child(dist)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 4)
	row.add_child(tools)
	var tool_icons: Array[TextureRect] = []
	for path in [UiArt.ICON_TRAMPOLINE_UI, UiArt.ICON_RAMP_UI, UiArt.ICON_FLOOR_UI]:
		var t := TextureRect.new()
		t.texture = UiArt.load_texture(path)
		t.custom_minimum_size = Vector2(42, 30)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tools.add_child(t)
		tool_icons.append(t)
	return {"hearts": hearts, "dist": dist, "tools": tool_icons, "hearts_shown": -1, "panel": panel}

func _update_hud() -> void:
	for i in 2:
		var ps := GameManager.player(i)
		var d: Dictionary = _panels[i]
		(d.dist as Label).text = "%d m" % ps.distance
		if int(d.hearts_shown) != ps.health:
			d.hearts_shown = ps.health
			var row: HBoxContainer = d.hearts
			for c in row.get_children():
				c.queue_free()
			var tex := UiArt.load_texture(SaveManager.get_variety_texture_path(ps.variety_id))
			for h in ps.max_health:
				var icon := TextureRect.new()
				icon.texture = tex
				icon.custom_minimum_size = Vector2(26, 26)
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.modulate = Color.WHITE if h < ps.health else Color(0.3, 0.3, 0.35, 0.5)
				row.add_child(icon)
		var icons: Array = d.tools
		for k in 3:
			var icon: TextureRect = icons[k]
			var selected := ps.selected_item == k
			var cooling := ps.cooldown_ratio(k) > 0.0
			icon.modulate = Color.WHITE if selected else Color(1, 1, 1, 0.38)
			if cooling:
				icon.modulate = icon.modulate.darkened(0.5)
			icon.scale = Vector2.ONE * (1.15 if selected else 1.0)
	var gap := GameManager.player(0).distance - GameManager.player(1).distance
	if gap == 0:
		_lead_label.text = "NECK AND NECK"
	else:
		_lead_label.text = "%s LEADS BY %d m" % ["P1" if gap > 0 else _p2_name, absi(gap)]

func _start_countdown() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.input_locked = true
	get_tree().paused = true
	for n in range(COUNTDOWN, 0, -1):
		_countdown_label.text = str(n)
		_pop_countdown()
		AudioManager.play("countdown")
		await get_tree().create_timer(0.65, true, false, true).timeout
		if not is_inside_tree():
			return
	_countdown_label.text = "GO!"
	_pop_countdown()
	AudioManager.play("go")
	end_countdown()
	var tw := _countdown_label.create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(_countdown_label, "modulate:a", 0.0, 0.3)

func end_countdown() -> void:
	if not GameManager.input_locked:
		return
	GameManager.input_locked = false
	if GameManager.state == GameManager.State.PLAYING:
		get_tree().paused = false

func _pop_countdown() -> void:
	_countdown_label.modulate.a = 1.0
	_countdown_label.pivot_offset = Vector2(640, 360)
	_countdown_label.scale = Vector2(1.5, 1.5)
	_countdown_label.create_tween().tween_property(_countdown_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_player_out(p: int) -> void:
	var shade := _out_shades[p]
	shade.create_tween().tween_property(shade, "color:a", 0.55, 0.4)
	var label := Label.new()
	label.text = "%s IS OUT  ·  %d m" % ["P1" if p == 0 else _p2_name, GameManager.player(p).distance]
	var other := 1 - p
	if GameManager.player(other).alive:
		label.text += "\n%s must pass it to win" % ("P1" if other == 0 else _p2_name)
		label.size.y = 110
	label.position = shade.position + Vector2(0, HALF_H * 0.5 - 30.0)
	label.size = Vector2(1280, 60)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", P_COLORS[p])
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.04, 0.02))
	label.add_theme_constant_override("outline_size", 10)
	_hud.add_child(label)

func _on_versus_over(winner: int, distances: Array) -> void:
	if _results_shown:
		return
	_results_shown = true
	AudioManager.play("win")
	_results = Control.new()
	_results.name = "Results"
	_results.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_results.process_mode = Node.PROCESS_MODE_ALWAYS
	_results.theme = load("res://resources/themes/bounce_back_theme.tres")
	var results_layer := CanvasLayer.new()
	results_layer.layer = 20
	results_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(results_layer)
	results_layer.add_child(_results)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.01, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_results.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -230
	panel.offset_bottom = 230
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.2, 0.11, 0.05, 0.97)
	box.border_color = P_COLORS[winner] if winner >= 0 else Color("FFD166")
	box.set_border_width_all(5)
	box.set_corner_radius_all(22)
	box.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", box)
	_results.add_child(panel)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var title := Label.new()
	title.name = "Winner"
	if winner < 0:
		title.text = "IT'S A TIE!"
	elif GameManager.versus_bot:
		title.text = "YOU WIN!" if winner == 0 else "THE BOT WINS!"
	else:
		title.text = "PLAYER %d WINS!" % (winner + 1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", P_COLORS[winner] if winner >= 0 else Color("FFD166"))
	col.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 60)
	col.add_child(row)
	for i in 2:
		var c := VBoxContainer.new()
		c.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(c)
		var ball := TextureRect.new()
		ball.texture = UiArt.load_texture(SaveManager.get_variety_texture_path(GameManager.player(i).variety_id, i != winner))
		ball.custom_minimum_size = Vector2(110, 110)
		ball.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ball.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c.add_child(ball)
		var l := Label.new()
		l.text = "%s\n%d m" % ["P1" if i == 0 else _p2_name, int(distances[i])]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_color_override("font_color", P_COLORS[i])
		c.add_child(l)
	var coins := Label.new()
	coins.text = "Coins collected go to your shop wallet: +%d" % (GameManager.player(0).stars + GameManager.player(1).stars)
	coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins.add_theme_font_size_override("font_size", 15)
	coins.add_theme_color_override("font_color", WorldConst.C_DIM)
	col.add_child(coins)
	var rematch := Button.new()
	rematch.name = "Rematch"
	rematch.text = "REMATCH  (Space)"
	rematch.custom_minimum_size = Vector2(320, 56)
	rematch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rematch.theme_type_variation = &"BBPrimaryButton"
	rematch.pressed.connect(_rematch)
	col.add_child(rematch)
	var menu := Button.new()
	menu.text = "MAIN MENU"
	menu.custom_minimum_size = Vector2(220, 46)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.pressed.connect(func() -> void:
		AudioManager.play("click")
		GameManager.go_to_menu())
	col.add_child(menu)
	panel.pivot_offset = Vector2(330, 230)
	panel.scale = Vector2(0.85, 0.85)
	panel.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if _results_shown and event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		_rematch()

func _rematch() -> void:
	AudioManager.play("click")
	GameManager.restart_run()
