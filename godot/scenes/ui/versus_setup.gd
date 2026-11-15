extends Control

signal closed

const C_PANEL := Color(0.2, 0.11, 0.05, 0.96)
const C_GOLD := Color("FFD166")
const P_COLORS := [Color("FFD166"), Color("7CE0FF")]
const GUEST_VARIETIES := ["orange", "blue"]
const MODES := ["VS PLAYER 2", "VS BOT · EASY", "VS BOT · NORMAL", "VS BOT · HARD", "VS BOT · EXTREME", "WATCH BOTS PLAY"]
const WATCH := 5

var choices: Array[String] = ["yellow", "orange"]
var _options: Array = [[], []]
var _balls: Array[TextureRect] = []
var _names: Array[Label] = []
var opponent := 0
var _mode_buttons: Array[Button] = []
var _p2_title: Label
var _p1_title: Label
var _p1_controls: Label
var _p2_controls: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for data: Dictionary in SaveManager.VARIETIES:
		var id := String(data.id)
		if SaveManager.is_variety_unlocked(id):
			_options[0].append(id)
			_options[1].append(id)
		elif GUEST_VARIETIES.has(id):
			_options[1].append(id)
	choices[0] = SaveManager.selected_variety
	choices[1] = _first_other(1, choices[0])
	_build()
	_refresh()

func _first_other(p: int, avoid: String) -> String:
	for id: String in _options[p]:
		if id != avoid:
			return id
	return avoid

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_A: cycle(0, -1)
			KEY_D: cycle(0, 1)
			KEY_LEFT: cycle(1, -1)
			KEY_RIGHT: cycle(1, 1)
			KEY_ENTER, KEY_SPACE: start()
			KEY_B: set_opponent(posmod(opponent + 1, MODES.size()))

func close() -> void:
	if not visible:
		return
	AudioManager.play("click")
	closed.emit()
	hide()
	if get_signal_connection_list("hidden").is_empty():
		queue_free()

func cycle(p: int, step: int) -> void:
	var list: Array = _options[p]
	var i := list.find(choices[p])
	choices[p] = String(list[posmod(i + step, list.size())])
	AudioManager.play("click")
	_refresh()

func set_opponent(value: int) -> void:
	opponent = clampi(value, 0, MODES.size() - 1)
	AudioManager.play("click")
	_refresh()

func start() -> void:
	AudioManager.play("go")
	if opponent == WATCH:
		GameManager.start_versus(choices[0], choices[1], true, 3, true)
	else:
		GameManager.start_versus(choices[0], choices[1], opponent > 0, opponent - 1)

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -480
	panel.offset_right = 480
	panel.offset_top = -300
	panel.offset_bottom = 300
	var box := StyleBoxFlat.new()
	box.bg_color = C_PANEL
	box.border_color = C_GOLD.darkened(0.35)
	box.set_border_width_all(4)
	box.set_corner_radius_all(22)
	box.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", box)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	col.add_child(_label("VERSUS", 40, C_GOLD, true))
	col.add_child(_label("Split screen, same course, each side builds their own pieces. Last ball rolling wins!", 15, WorldConst.C_DIM, true))
	var modes := GridContainer.new()
	modes.columns = 3
	modes.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	modes.add_theme_constant_override("h_separation", 10)
	modes.add_theme_constant_override("v_separation", 8)
	col.add_child(modes)
	for m in MODES.size():
		var b := Button.new()
		b.name = "Mode%d" % m
		b.text = MODES[m]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(260, 40)
		b.pressed.connect(set_opponent.bind(m))
		modes.add_child(b)
		_mode_buttons.append(b)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 80)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	var controls := [
		"Mouse to aim · click to place\n1 / 2 / 3 pick a piece · R flips\nA / D change ball",
		"Arrows aim · Enter places\n,  .  /  pick a piece · ' flips\nGamepad: stick · A · X · Y\n← / → change ball (here)",
	]
	for p in 2:
		var c := VBoxContainer.new()
		c.alignment = BoxContainer.ALIGNMENT_CENTER
		c.add_theme_constant_override("separation", 8)
		row.add_child(c)
		var title := _label("PLAYER %d" % (p + 1), 26, P_COLORS[p], true)
		c.add_child(title)
		if p == 1:
			_p2_title = title
		else:
			_p1_title = title
		var pick := HBoxContainer.new()
		pick.alignment = BoxContainer.ALIGNMENT_CENTER
		c.add_child(pick)
		var prev := Button.new()
		prev.name = "Prev%d" % (p + 1)
		prev.text = "<"
		prev.custom_minimum_size = Vector2(44, 44)
		prev.pressed.connect(cycle.bind(p, -1))
		pick.add_child(prev)
		var ball := TextureRect.new()
		ball.custom_minimum_size = Vector2(130, 130)
		ball.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ball.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pick.add_child(ball)
		_balls.append(ball)
		var next := Button.new()
		next.name = "Next%d" % (p + 1)
		next.text = ">"
		next.custom_minimum_size = Vector2(44, 44)
		next.pressed.connect(cycle.bind(p, 1))
		pick.add_child(next)
		var n := _label("", 20, WorldConst.C_TEXT, true)
		c.add_child(n)
		_names.append(n)
		var help := _label(controls[p], 14, WorldConst.C_DIM, true)
		c.add_child(help)
		if p == 1:
			_p2_controls = help
		else:
			_p1_controls = help
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	col.add_child(buttons)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(160, 52)
	back.pressed.connect(close)
	buttons.add_child(back)
	var go := Button.new()
	go.name = "StartButton"
	go.text = "START  (Enter)"
	go.custom_minimum_size = Vector2(280, 52)
	go.theme_type_variation = &"BBPrimaryButton"
	go.pressed.connect(start)
	buttons.add_child(go)

func _refresh() -> void:
	for m in _mode_buttons.size():
		_mode_buttons[m].set_pressed_no_signal(m == opponent)
	if _p2_title:
		_p2_title.text = "PLAYER 2" if opponent == 0 else ("BOT 2 · EXTREME" if opponent == WATCH else "BOT · " + GameManager.BOT_NAMES[opponent - 1])
		_p2_controls.text = "Arrows aim · Enter places\n,  .  /  pick a piece · ' flips\nGamepad: stick · A · X · Y\n← / → change ball (here)" if opponent == 0 \
			else "The computer builds its own pieces.\nB switches opponent · ← / → change its ball"
		_p1_title.text = "BOT 1 · EXTREME" if opponent == WATCH else "PLAYER 1"
		_p1_controls.text = "Sit back and watch.\nTab in the match speeds it up\nA / D change its ball" if opponent == WATCH \
			else "Mouse to aim · click to place\n1 / 2 / 3 pick a piece · R flips\nA / D change ball"
	for p in 2:
		_balls[p].texture = UiArt.load_texture(SaveManager.get_variety_texture_path(choices[p]))
		_names[p].text = SaveManager.get_variety_name(choices[p])
		_names[p].add_theme_color_override("font_color", SaveManager.get_variety_color(choices[p]).lightened(0.2))

func _label(text: String, size: int, color: Color, centered := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
