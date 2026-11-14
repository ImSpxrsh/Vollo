extends Control

const BACKDROP_TEXTURE := preload("res://assets/backdrop_night.png")
const MOON_TEXTURE := preload("res://assets/sprites/pixel_moon.png")
const RAMP_TEXTURE := preload("res://assets/sprites/ramp.png")
const TRAMPOLINE_TEXTURE := preload("res://assets/sprites/trampoline_idle.png")
const WALL_TEXTURE := preload("res://assets/sprites/blue_wall.png")

const PAGES := [
	{
		"eyebrow": "YOUR LITTLE ROLLING PROBLEM",
		"title": "MEET VARIETY",
		"body": "Variety is a cheerful yellow ball with one habit: once the rolling starts, it never stops."
	},
	{
		"eyebrow": "THE ROAD ENDS HERE",
		"title": "THERE IS NO GROUND AHEAD",
		"body": "Variety rolls off the starting ledge. You are the guardian now — every safe landing has to be built just before it is needed."
	},
	{
		"eyebrow": "THREE TEMPORARY TOOLS",
		"title": "BOUNCE. GUIDE. BRIDGE.",
		"body": "Green trampolines gain height. Yellow ramps guide the roll. Gray floors buy a few precious seconds. Every piece flickers, then disappears."
	},
	{
		"eyebrow": "ONE MORE TRY",
		"title": "KEEP VARIETY ROLLING",
		"body": "Use 1, 2, and 3 to choose a trampoline, ramp, or floor. Click to place it, press R to flip the ramp, and never touch red."
	},
]

@onready var eyebrow: Label = %Eyebrow
@onready var title_label: Label = %Title
@onready var body_label: Label = %Body
@onready var page_label: Label = %Page
@onready var next_button: Button = %NextButton
@onready var start_screen: Control = %StartScreen
@onready var story_panel: VBoxContainer = %StoryPanel
@onready var brand: Label = $Brand
@onready var start_prompt: Label = $StartScreen/Prompt

var page := -1
var _busy := false
var _time := 0.0
var _story_panel_x := 0.0
var _page_tween: Tween

func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	next_button.pressed.connect(_advance)
	_story_panel_x = story_panel.position.x
	_show_page(false)

func _process(delta: float) -> void:
	_time += delta
	if page < 0:
		start_prompt.modulate.a = 0.68 + 0.32 * sin(_time * 2.4)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("move_right"):
		get_viewport().set_input_as_handled()
		_advance()

func _advance() -> void:
	if _busy:
		return
	AudioManager.play("click")
	if page < 0:
		page = 0
		_show_page(true)
		return
	if page >= PAGES.size() - 1:
		_busy = true
		SceneTransition.change_scene("res://scenes/game/main.tscn")
		return
	page += 1
	_show_page(true)

func _show_page(animate: bool) -> void:
	start_screen.visible = page < 0
	story_panel.visible = page >= 0
	brand.visible = page >= 0
	if page < 0:
		queue_redraw()
		return
	var data: Dictionary = PAGES[page]
	eyebrow.text = data.eyebrow
	title_label.text = data.title
	body_label.text = data.body
	page_label.text = "%02d  /  %02d" % [page + 1, PAGES.size()]
	next_button.text = "START RUN" if page == PAGES.size() - 1 else "CONTINUE"
	queue_redraw()
	if animate:
		if _page_tween and _page_tween.is_valid():
			_page_tween.kill()
		var panel := story_panel as Control
		panel.modulate.a = 0.0
		panel.position.x = _story_panel_x + 24.0
		_page_tween = create_tween().set_parallel()
		_page_tween.tween_property(panel, "modulate:a", 1.0, 0.25)
		_page_tween.tween_property(panel, "position:x", _story_panel_x, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if page < 0:
		_draw_title_screen(w, h)
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("090B17"))
	for i in 9:
		var y := h * float(i) / 8.0
		draw_circle(Vector2(w * (0.08 + fmod(i * 0.23, 0.82)), y), 2.0 + i % 3, Color(0.55, 0.72, 1.0, 0.22))
	_draw_island(Vector2(w * 0.03, h * 0.23), Vector2(w * 0.27, 42.0))
	_draw_island(Vector2(w * 0.72, h * 0.57), Vector2(w * 0.25, 42.0))
	_draw_island(Vector2(w * 0.08, h * 0.86), Vector2(w * 0.20, 34.0))
	var center := Vector2(w * 0.32, h * 0.51)
	var c := Color("FFD84A")
	draw_circle(center + Vector2(0, 18), 58.0, Color(0.0, 0.0, 0.0, 0.35))
	draw_circle(center, 58.0, c)
	draw_arc(center, 58.0, 0, TAU, 64, c.lightened(0.28), 4.0, true)
	draw_circle(center + Vector2(-19, -14), 6.0, Color("172033"))
	draw_circle(center + Vector2(19, -14), 6.0, Color("172033"))
	draw_arc(center + Vector2(0, 2), 22.0, 0.25, PI - 0.25, 18, Color("172033"), 4.0, true)
	if page >= 2:
		draw_polyline(PackedVector2Array([center + Vector2(-8, -54), center + Vector2(-18, -24), center + Vector2(1, -8), center + Vector2(-8, 18)]), Color("FFF3D1"), 4.0)
		for i in 6:
			var a := TAU * float(i) / 6.0
			var p := center + Vector2.from_angle(a) * 78.0
			draw_colored_polygon(PackedVector2Array([p + Vector2.from_angle(a) * 10.0, p + Vector2.from_angle(a + 2.45) * 8.0, p + Vector2.from_angle(a - 2.45) * 8.0]), c.lightened(0.25))

func _draw_island(pos: Vector2, island_size: Vector2) -> void:
	var rock := PackedVector2Array([
		pos, pos + Vector2(island_size.x, 0), pos + Vector2(island_size.x * 0.82, island_size.y),
		pos + Vector2(island_size.x * 0.60, island_size.y * 1.8), pos + Vector2(island_size.x * 0.34, island_size.y * 1.25),
		pos + Vector2(island_size.x * 0.12, island_size.y)
	])
	draw_colored_polygon(rock, Color("202945"))
	draw_line(pos, pos + Vector2(island_size.x, 0), Color("79E7D3"), 5.0, true)

func _draw_title_screen(w: float, h: float) -> void:
	draw_texture_rect(BACKDROP_TEXTURE, Rect2(0, 0, w, h), false)
	draw_rect(Rect2(0, 0, w, h), Color(0.025, 0.035, 0.07, 0.34))
	for i in 12:
		var bw := 54.0 + float((i * 31) % 58)
		var bh := 80.0 + float((i * 47) % 145)
		var bx := float(i) * (w / 11.0) - 24.0
		draw_rect(Rect2(bx, h * 0.34 - bh * 0.15, bw, bh), Color(0.035, 0.05, 0.09, 0.60), true)
	draw_texture_rect(MOON_TEXTURE, Rect2(w * 0.73, 42.0, 110.0, 112.0), false)
	var ground_y := h * 0.69
	draw_rect(Rect2(-20.0, ground_y, w * 0.58, h - ground_y + 20.0), Color("171A27"), true)
	draw_line(Vector2(-20, ground_y), Vector2(w * 0.58, ground_y), Color("8B9C8D"), 4.0)
	draw_rect(Rect2(w * 0.78, ground_y + 34.0, w * 0.24, h - ground_y), Color("171A27"), true)
	draw_line(Vector2(w * 0.78, ground_y + 34.0), Vector2(w, ground_y + 34.0), Color("8B9C8D"), 4.0)
	draw_texture_rect(RAMP_TEXTURE, Rect2(w * 0.17, ground_y - 70.0, 110.0, 62.0), false)
	draw_texture_rect(TRAMPOLINE_TEXTURE, Rect2(w * 0.30, ground_y - 60.0, 124.0, 56.0), false)
	draw_rect(Rect2(w * 0.07, ground_y - 20.0, 118.0, 18.0), Color("9EA39A"), true)
	draw_line(Vector2(w * 0.07, ground_y - 20.0), Vector2(w * 0.07 + 118.0, ground_y - 20.0), Color("E3DFC8"), 3.0)
	var ball_pos := Vector2(w * 0.51, ground_y - 28.0)
	draw_circle(ball_pos + Vector2(0, 5), 25.0, Color(0, 0, 0, 0.35))
	draw_circle(ball_pos, 24.0, Color("FFD84A"))
	draw_arc(ball_pos, 23.0, 0, TAU, 32, Color("FFF1A6"), 3.0)
	draw_circle(ball_pos + Vector2(-8, -5), 2.8, Color("172033"))
	draw_circle(ball_pos + Vector2(8, -5), 2.8, Color("172033"))
	draw_arc(ball_pos + Vector2(0, 1), 9.0, 0.2, PI - 0.2, 12, Color("172033"), 2.4)
	for i in 5:
		var sx := w * 0.82 + i * 28.0
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 11, ground_y + 34), Vector2(sx, ground_y - 18), Vector2(sx + 11, ground_y + 34)]), Color("A83E4F"))
