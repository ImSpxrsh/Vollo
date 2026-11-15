extends Control

signal closed

const C_PANEL := Color(0.2, 0.11, 0.05, 0.96)
const C_ROW := Color(0.29, 0.17, 0.08, 1.0)
const C_ME := Color(0.45, 0.28, 0.08, 1.0)
const C_GOLD := Color("FFD166")
const C_BAD := Color("FF8A65")
const MEDALS := [Color("FFD166"), Color("D9E2EC"), Color("E0A36B")]

var _list: VBoxContainer
var _list_status: Label
var _account_box: VBoxContainer
var _status: Label
var _name_edit: LineEdit
var _pass_edit: LineEdit
var _busy := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	Leaderboard.account_changed.connect(_build_account)
	_build_account()
	refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	if not visible:
		return
	AudioManager.play("click")
	closed.emit()
	hide()
	if get_signal_connection_list("hidden").is_empty():
		queue_free()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -480
	panel.offset_top = -320
	panel.offset_right = 480
	panel.offset_bottom = 320
	panel.add_theme_stylebox_override("panel", _box(C_PANEL, C_GOLD.darkened(0.35), 4, 22, 22))
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)
	root.add_child(_label("LEADERBOARD", 38, C_GOLD))
	root.add_child(_label("The furthest anyone has rolled. Make an account to get on it.", 15, WorldConst.C_DIM))

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root.add_child(body)

	var board := PanelContainer.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_stretch_ratio = 1.6
	board.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.22), Color(0, 0, 0, 0), 0, 14, 10))
	body.add_child(board)
	var board_v := VBoxContainer.new()
	board.add_child(board_v)
	_list_status = _label("", 16, WorldConst.C_DIM)
	_list_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board_v.add_child(_list_status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	board_v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	var side := PanelContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_stylebox_override("panel", _box(C_ROW, Color(0, 0, 0, 0.5), 2, 14, 14))
	body.add_child(side)
	_account_box = VBoxContainer.new()
	_account_box.name = "Account"
	_account_box.add_theme_constant_override("separation", 10)
	side.add_child(_account_box)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 10)
	root.add_child(footer)
	var again := Button.new()
	again.name = "RefreshButton"
	again.text = "REFRESH"
	again.custom_minimum_size = Vector2(160, 46)
	again.pressed.connect(refresh)
	footer.add_child(again)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "BACK"
	back.custom_minimum_size = Vector2(160, 46)
	back.pressed.connect(close)
	footer.add_child(back)

func refresh() -> void:
	if not Leaderboard.is_configured():
		_list_status.text = "The online leaderboard isn't switched on in this build."
		return
	_list_status.text = "Loading..."
	var res: Dictionary = await Leaderboard.top(50)
	if not is_inside_tree():
		return
	for child in _list.get_children():
		child.queue_free()
	if not res.ok:
		_list_status.text = String(res.error)
		return
	var rows: Array = res.data if res.data is Array else []
	_list_status.text = "No scores yet. Be the first!" if rows.is_empty() else ""
	_list_status.visible = rows.is_empty()
	for row: Dictionary in rows:
		_list.add_child(_make_row(row))

func _make_row(row: Dictionary) -> Control:
	var rank := int(row.get("rank", 0))
	var who := String(row.get("username", "?"))
	var mine := Leaderboard.is_logged_in() and who.to_lower() == Leaderboard.username.to_lower()
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _box(C_ME if mine else C_ROW, C_GOLD if mine else Color(0, 0, 0, 0), 2 if mine else 0, 10, 6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	box.add_child(h)
	var place := _label("#%d" % rank, 20, MEDALS[rank - 1] if rank >= 1 and rank <= 3 else WorldConst.C_DIM)
	place.custom_minimum_size = Vector2(54, 0)
	h.add_child(place)
	var ball := TextureRect.new()
	ball.texture = UiArt.load_texture(SaveManager.get_variety_texture_path(String(row.get("variety", "yellow"))))
	ball.custom_minimum_size = Vector2(32, 32)
	ball.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ball.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(ball)
	var name_label := _label(who + ("  (you)" if mine else ""), 20, WorldConst.C_TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	h.add_child(name_label)
	h.add_child(_label("%d m" % int(row.get("best", 0)), 20, C_GOLD))
	return box

func _build_account() -> void:
	for child in _account_box.get_children():
		child.queue_free()
	_name_edit = null
	_pass_edit = null
	if Leaderboard.is_logged_in():
		_account_box.add_child(_label("SIGNED IN AS", 15, WorldConst.C_DIM))
		_account_box.add_child(_label(Leaderboard.username, 28, C_GOLD))
		_account_box.add_child(_label("Online best:  %d m" % Leaderboard.online_best, 18, WorldConst.C_TEXT))
		var rank_text := ("World rank:  #%d" % Leaderboard.online_rank) if Leaderboard.online_rank > 0 else "World rank:  play a run!"
		_account_box.add_child(_label(rank_text, 18, WorldConst.C_TEXT))
		var note := _label("Your best single-player run is posted automatically.", 14, WorldConst.C_DIM)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_account_box.add_child(note)
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_account_box.add_child(spacer)
		var out := Button.new()
		out.name = "LogoutButton"
		out.text = "LOG OUT"
		out.custom_minimum_size = Vector2(0, 44)
		out.pressed.connect(_on_logout)
		_account_box.add_child(out)
	else:
		_account_box.add_child(_label("YOUR ACCOUNT", 22, C_GOLD))
		_name_edit = LineEdit.new()
		_name_edit.name = "NameEdit"
		_name_edit.placeholder_text = "Name (3-16 letters)"
		_name_edit.max_length = 16
		_name_edit.custom_minimum_size = Vector2(0, 42)
		_account_box.add_child(_name_edit)
		_pass_edit = LineEdit.new()
		_pass_edit.name = "PassEdit"
		_pass_edit.placeholder_text = "Password"
		_pass_edit.secret = true
		_pass_edit.custom_minimum_size = Vector2(0, 42)
		_pass_edit.text_submitted.connect(func(_t: String) -> void: _on_login())
		_account_box.add_child(_pass_edit)
		var login := Button.new()
		login.name = "LoginButton"
		login.text = "LOG IN"
		login.custom_minimum_size = Vector2(0, 44)
		login.pressed.connect(_on_login)
		_account_box.add_child(login)
		var make := Button.new()
		make.name = "RegisterButton"
		make.text = "CREATE ACCOUNT"
		make.custom_minimum_size = Vector2(0, 44)
		make.pressed.connect(_on_register)
		_account_box.add_child(make)
		var note := _label("No email needed. Don't reuse a password from another site.", 13, WorldConst.C_DIM)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_account_box.add_child(note)
	_status = _label("", 15, C_BAD)
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_account_box.add_child(_status)

func _on_login() -> void:
	await _submit_form(false)

func _on_register() -> void:
	await _submit_form(true)

func _submit_form(create: bool) -> void:
	if _busy or _name_edit == null:
		return
	if not Leaderboard.is_configured():
		_status.text = "The online leaderboard isn't switched on in this build."
		return
	var user_name := _name_edit.text.strip_edges()
	var password := _pass_edit.text
	if user_name.is_empty() or password.is_empty():
		_status.text = "Type a name and a password."
		AudioManager.play("deny")
		return
	_busy = true
	_status.text = "Creating account..." if create else "Logging in..."
	AudioManager.play("click")
	var res: Dictionary
	if create:
		res = await Leaderboard.register(user_name, password)
	else:
		res = await Leaderboard.login(user_name, password)
	_busy = false
	if not is_inside_tree():
		return
	if res.ok:
		AudioManager.play("buy")
		refresh()
	else:
		AudioManager.play("deny")
		if _status:
			_status.text = String(res.error)

func _on_logout() -> void:
	AudioManager.play("click")
	Leaderboard.logout()
	refresh()

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

func _box(bg: Color, border: Color, border_width: int, radius: int, margin: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_width)
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(margin)
	return b
