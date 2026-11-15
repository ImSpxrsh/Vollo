extends Node2D

@onready var ball: RigidBody2D = $Ball
@onready var camera: Camera2D = $GameCamera
@onready var grid: ColorRect = $Background/Grid
@onready var ceiling: Node2D = $Ceiling
@onready var background: CanvasLayer = $Background
@onready var backdrop: TextureRect = $Background/Backdrop

const MOON_TEXTURE := preload("res://assets/sprites/pixel_moon.png")
const FOG_TEXTURE := preload("res://assets/sprites/fog_cloud.png")
const LEVEL_BACKGROUNDS: Array[Texture2D] = [
	preload("res://assets/background_mountain_farm.png"),
	preload("res://assets/background_forest_cottage.png"),
	preload("res://assets/background_pixel_farm.png"),
	preload("res://assets/background_forest_path.png"),
]
const TUTORIAL_OVERLAY := preload("res://scenes/ui/tutorial_overlay.gd")
var recorder: ReplayRecorder
const GRID_ALPHA := [0.0, 0.0, 0.0, 0.0]
const GRID_HUE := [0.22, 0.30, 0.12, 0.26]
var _moon: Sprite2D
var _fog: Sprite2D
var _next_backdrop: TextureRect
var _theme_tween: Tween
var _current_theme := -1

func _ready() -> void:
	_setup_background_crossfade()
	_moon = Sprite2D.new()
	_moon.name = "MoonArt"
	_moon.texture = MOON_TEXTURE
	_moon.scale = Vector2(1.45, 1.45)
	_moon.z_index = -2
	add_child(_moon)
	_fog = Sprite2D.new()
	_fog.name = "FogArt"
	_fog.texture = FOG_TEXTURE
	_fog.scale = Vector2(2.15, 2.15)
	_fog.modulate.a = 0.58
	_fog.z_index = -1
	add_child(_fog)
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.versus = false
	GameManager.start_run()
	if GameManager.tutorial:
		var overlay := CanvasLayer.new()
		overlay.name = "Tutorial"
		overlay.set_script(TUTORIAL_OVERLAY)
		overlay.set("ball", ball)
		add_child(overlay)
	else:
		recorder = ReplayRecorder.new()
		recorder.name = "Recorder"
		add_child(recorder)
		var who := Leaderboard.username if Leaderboard.is_logged_in() else "YOU"
		var mode := "map" if GameManager.is_custom_run() else "solo"
		recorder.setup([ball], $LevelGenerator, mode, [who])

func _setup_background_crossfade() -> void:
	_next_backdrop = TextureRect.new()
	_next_backdrop.name = "BackdropNext"
	_next_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_next_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_next_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_next_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_backdrop.modulate.a = 0.0
	background.add_child(_next_backdrop)
	background.move_child(_next_backdrop, backdrop.get_index() + 1)
	backdrop.texture = LEVEL_BACKGROUNDS[0]
	backdrop.modulate = Color.WHITE

func _on_level_changed(_number: int, _level_name: String, new_theme: int) -> void:
	new_theme = posmod(new_theme, LEVEL_BACKGROUNDS.size())
	if new_theme == _current_theme:
		return
	_current_theme = new_theme
	_apply_atmosphere(new_theme)
	if _theme_tween and _theme_tween.is_valid():
		_theme_tween.kill()
	if backdrop.texture == LEVEL_BACKGROUNDS[new_theme]:
		backdrop.modulate.a = 1.0
		_next_backdrop.modulate.a = 0.0
		return
	var old_backdrop := backdrop
	var new_backdrop := _next_backdrop
	new_backdrop.texture = LEVEL_BACKGROUNDS[new_theme]
	new_backdrop.modulate = Color(1, 1, 1, 0)
	_theme_tween = create_tween()
	_theme_tween.set_parallel(true)
	_theme_tween.tween_property(old_backdrop, "modulate:a", 0.0, 1.15).set_trans(Tween.TRANS_SINE)
	_theme_tween.tween_property(new_backdrop, "modulate:a", 1.0, 1.15).set_trans(Tween.TRANS_SINE)
	_theme_tween.set_parallel(false)
	_theme_tween.tween_callback(func() -> void:
		backdrop = new_backdrop
		_next_backdrop = old_backdrop
		_next_backdrop.modulate.a = 0.0
	)

func _apply_atmosphere(theme: int) -> void:
	grid.modulate.a = GRID_ALPHA[theme]
	var mat := grid.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("hue_shift", GRID_HUE[theme])
	_moon.visible = false
	_fog.visible = false

func _process(_delta: float) -> void:
	var center := camera.get_screen_center_position()
	ceiling.global_position.x = ball.global_position.x - 1500.0
	_moon.global_position = center + Vector2(450.0, -220.0)
	_fog.global_position = center + Vector2(160.0, -50.0)
	var mat := grid.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("resolution", grid.size)
		mat.set_shader_parameter("scroll", camera.get_screen_center_position())
