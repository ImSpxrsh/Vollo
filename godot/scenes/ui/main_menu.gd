extends MainMenu

const NEON_GRID_PATH := "res://shaders/neon_grid.gdshader"
const VARIETY_MENU := preload("res://scenes/ui/VarietyMenu.tscn")
const SHOP_MENU := preload("res://scenes/ui/ShopMenu.tscn")
const VERSUS_SETUP := preload("res://scenes/ui/VersusSetup.tscn")
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
var _title_ball: TextureRect

func _ready() -> void:
	super._ready()
	get_tree().paused = false
	Engine.time_scale = 1.0
	_setup_background()
	_add_varieties_button()
	_add_title_ball()
	_update_best()
	_start_title_bob()

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
	_update_varieties_button()

func _update_varieties_button() -> void:
	if varieties_button == null:
		return
	var fresh := SaveManager.new_variety_unlocks.size()
	varieties_button.text = "VARIETIES  ·  NEW!" if fresh > 0 else "VARIETIES"
	if shop_button:
		shop_button.text = "SHOP  ·  %d COINS" % SaveManager.coin_balance()

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

func _close_sub_menu() -> void:
	super._close_sub_menu()
	_update_best()
	_update_varieties_button()
	_update_title_ball()
	if demo and demo.has_method("refresh_variety"):
		demo.call("refresh_variety")
