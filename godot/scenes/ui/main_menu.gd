extends MainMenu

const NEON_GRID_PATH := "res://shaders/neon_grid.gdshader"
const VARIETY_MENU := preload("res://scenes/ui/VarietyMenu.tscn")
const SHOP_MENU := preload("res://scenes/ui/ShopMenu.tscn")
const VERSUS_SETUP := preload("res://scenes/ui/VersusSetup.tscn")
const LEADERBOARD_MENU := preload("res://scenes/ui/LeaderboardMenu.tscn")
const REPLAYS_MENU := preload("res://scenes/ui/ReplaysMenu.tscn")
const COMMUNITY_MENU := preload("res://scenes/ui/CommunityMapsMenu.tscn")
const BACKDROP_MARGIN := Vector2(70, 40)

@onready var grid_rect: ColorRect = $BackgroundLayer/Grid
@onready var backdrop: TextureRect = $BackgroundLayer/Backdrop
@onready var shade: ColorRect = $BackgroundLayer/Shade
@onready var demo: Node2D = $BackgroundLayer/MenuDemo
@onready var title_label: Label = $TitleBlock/TitleLabel
@onready var best_badge: PanelContainer = $TitleBlock/BestBadge
@onready var best_label: Label = $TitleBlock/BestBadge/BestLabel

var _grid_mat: ShaderMaterial
var _time := 0.0
var varieties_button: Button
var shop_button: Button
var versus_button: Button
var leaderboard_button: Button
var tutorial_button: Button
var _grid: GridContainer
var _title_ball: TextureRect

func _ready() -> void:
	super._ready()
	get_tree().paused = false
	Engine.time_scale = 1.0
	_setup_background()
	_add_varieties_button()
	_add_title_ball()
	_add_team_card()
	_update_best()
	_start_title_bob()

func _add_team_card() -> void:
	var card := PanelContainer.new()
	card.name = "TeamCard"
	card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.offset_right = -18
	card.offset_bottom = -18
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = "Open credits"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.08, 0.03, 0.9)
	style.border_color = Color("FFD166")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	var head := Label.new()
	head.text = "CREATED BY"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 13)
	head.add_theme_color_override("font_color", Color("FFD166"))
	col.add_child(head)
	var photo := TextureRect.new()
	photo.texture = load("res://assets/art/team_photo.png")
	photo.custom_minimum_size = Vector2(150, 150)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(photo)
	var names := Label.new()
	names.text = "Andrew · Sparsh · Adharv"
	names.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	names.add_theme_font_size_override("font_size", 13)
	names.add_theme_color_override("font_color", WorldConst.C_TEXT)
	col.add_child(names)
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			AudioManager.play("click")
			_on_credits_button_pressed())
	card.mouse_entered.connect(func() -> void: card.modulate = Color(1.08, 1.08, 1.08))
	card.mouse_exited.connect(func() -> void: card.modulate = Color.WHITE)
	add_child(card)

func _setup_background() -> void:
	grid_rect.color = WorldConst.C_BG
	var tex := UiArt.load_texture(UiArt.BACKDROP_NIGHT)
	backdrop.texture = tex
	backdrop.visible = tex != null
	shade.visible = tex != null
	if tex:
		grid_rect.visible = false
		_layout_backdrop()
	elif ResourceLoader.exists(NEON_GRID_PATH):
		var shader := load(NEON_GRID_PATH) as Shader
		if shader:
			_grid_mat = ShaderMaterial.new()
			_grid_mat.shader = shader
			grid_rect.material = _grid_mat

func _layout_backdrop() -> void:
	var vp := get_viewport_rect().size
	backdrop.size = vp + BACKDROP_MARGIN * 2.0
	var drift := Vector2(sin(_time * 0.11) * BACKDROP_MARGIN.x * 0.8, sin(_time * 0.07 + 1.3) * BACKDROP_MARGIN.y * 0.6)
	var mouse := get_viewport().get_mouse_position()
	if vp.x > 0.0 and vp.y > 0.0:
		drift += (mouse / vp - Vector2(0.5, 0.5)) * Vector2(-18.0, -10.0)
	backdrop.position = -BACKDROP_MARGIN + drift

func _process(delta: float) -> void:
	_time += delta
	if _title_ball:
		_title_ball.rotation = sin(_time * 1.3) * 0.25
	if backdrop.visible:
		_layout_backdrop()
	elif _grid_mat:
		_grid_mat.set_shader_parameter("scroll", Vector2(float(demo.get("scroll")), 0.0))
		_grid_mat.set_shader_parameter("resolution", grid_rect.size)

func _add_varieties_button() -> void:
	varieties_button = Button.new()
	varieties_button.name = "VarietiesButton"
	varieties_button.custom_minimum_size = Vector2(0, 42)
	varieties_button.pressed.connect(open_varieties)
	versus_button = Button.new()
	versus_button.name = "VersusButton"
	versus_button.text = "2-PLAYER VERSUS"
	versus_button.custom_minimum_size = Vector2(0, 42)
	versus_button.pressed.connect(open_versus)
	new_game_button.add_sibling(versus_button)
	versus_button.add_sibling(varieties_button)
	shop_button = Button.new()
	shop_button.name = "ShopButton"
	shop_button.custom_minimum_size = Vector2(0, 42)
	shop_button.pressed.connect(open_shop)
	varieties_button.add_sibling(shop_button)
	leaderboard_button = Button.new()
	leaderboard_button.name = "LeaderboardButton"
	leaderboard_button.text = "LEADERBOARD"
	leaderboard_button.custom_minimum_size = Vector2(0, 42)
	leaderboard_button.pressed.connect(open_leaderboard)
	shop_button.add_sibling(leaderboard_button)
	tutorial_button = _menu_button("TutorialButton", "TUTORIAL", open_tutorial)
	var replays_button := _menu_button("ReplaysButton", "REPLAYS", open_replays)
	var builder_button := _menu_button("BuilderButton", "MAP BUILDER", open_builder)
	var community_button := _menu_button("CommunityButton", "COMMUNITY MAPS", open_community)
	_grid = GridContainer.new()
	_grid.name = "MoreButtons"
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	new_game_button.add_sibling(_grid)
	var order: Array[Control] = [tutorial_button, versus_button, varieties_button, shop_button, leaderboard_button, replays_button, builder_button, community_button]
	for n in ["OptionsButton", "CreditsButton", "ExitButton"]:
		var b := new_game_button.get_parent().get_node_or_null(n) as Control
		if b:
			order.append(b)
	for b in order:
		if b.get_parent():
			b.get_parent().remove_child(b)
		# 34 px tall so the sixth row (COMMUNITY MAPS) fits where five rows of 40 did.
		b.custom_minimum_size = Vector2(196, 34)
		_grid.add_child(b)
	var box := new_game_button.get_parent() as Control
	box.offset_left = -200
	box.offset_right = 200
	_update_varieties_button()

func _update_varieties_button() -> void:
	if varieties_button == null:
		return
	var fresh := SaveManager.new_variety_unlocks.size()
	varieties_button.text = "VARIETIES  ·  NEW!" if fresh > 0 else "VARIETIES"
	if shop_button:
		shop_button.text = "SHOP  ·  %d" % SaveManager.coin_balance()
	if tutorial_button:
		tutorial_button.text = "TUTORIAL" if int(SaveManager.stats.get("tutorial_done", 0)) > 0 else "TUTORIAL  ·  NEW?"

func open_varieties() -> void:
	if sub_menu != null:
		return
	AudioManager.play("click")
	_open_sub_menu(VARIETY_MENU)

func open_versus() -> void:
	if sub_menu != null:
		return
	AudioManager.play("click")
	_open_sub_menu(VERSUS_SETUP)

func open_shop() -> void:
	if sub_menu != null:
		return
	AudioManager.play("click")
	_open_sub_menu(SHOP_MENU)

func _menu_button(node_name: String, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.pressed.connect(cb)
	return b

func open_tutorial() -> void:
	if sub_menu != null:
		return
	AudioManager.play("go")
	GameManager.play_map(MapStore.TUTORIAL, false, true)

func open_builder() -> void:
	if sub_menu != null:
		return
	AudioManager.play("click")
	GameManager.open_builder()

func open_community() -> void:
	if sub_menu != null:
		return
	AudioManager.play("click")
	_open_sub_menu(COMMUNITY_MENU)

func open_replays() -> void:
	if sub_menu != null:
		return
	AudioManager.play("click")
	_open_sub_menu(REPLAYS_MENU)

func open_leaderboard() -> void:
	if sub_menu != null:
		return
	AudioManager.play("click")
	_open_sub_menu(LEADERBOARD_MENU)

func _add_title_ball() -> void:
	_title_ball = TextureRect.new()
	_title_ball.name = "TitleBall"
	_title_ball.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title_ball.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title_ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_ball.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title_ball.offset_left = 150.0
	_title_ball.offset_right = 230.0
	_title_ball.offset_top = 28.0
	_title_ball.offset_bottom = 108.0
	_title_ball.pivot_offset = Vector2(40, 40)
	$TitleBlock.add_child(_title_ball)
	_update_title_ball()

func _update_title_ball() -> void:
	if _title_ball:
		_title_ball.texture = UiArt.load_texture(SaveManager.get_variety_texture_path())

func _update_best() -> void:
	var best := SaveManager.high_score
	best_label.text = "BEST  %d m" % best
	best_badge.visible = best > 0

func _start_title_bob() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var base_y := title_label.position.y
	var t := create_tween().set_loops()
	t.tween_property(title_label, "position:y", base_y - 7.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(title_label, "position:y", base_y + 7.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func load_game_scene() -> void:
	SceneTransition.change_scene(get_game_scene_path())

func try_exit_game() -> void:
	if OS.has_feature("web"):
		return
	super.try_exit_game()

func _input(event: InputEvent) -> void:
	super._input(event)
	if sub_menu != null or exit_confirmation.visible:
		return
	if event.is_action_pressed("select_1"):
		AudioManager.play("click")
		new_game()
	elif event.is_action_pressed("select_2"):
		AudioManager.play("click")
		_on_options_button_pressed()
	elif event.is_action_pressed("select_3"):
		AudioManager.play("click")
		_on_credits_button_pressed()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_4:
		open_varieties()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_5:
		open_shop()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_V:
		open_versus()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_L:
		open_leaderboard()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_T:
		open_tutorial()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_M:
		open_builder()

func _close_sub_menu() -> void:
	super._close_sub_menu()
	_update_best()
	_update_varieties_button()
	_update_title_ball()
	if demo and demo.has_method("refresh_variety"):
		demo.call("refresh_variety")
