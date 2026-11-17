extends Control

## Browse and play maps other players published from the MAP BUILDER.

signal closed

const C_PANEL := Color(0.2, 0.11, 0.05, 0.96)
const C_ROW := Color(0.29, 0.17, 0.08, 1.0)
const C_GOLD := Color("FFD166")

var _list: VBoxContainer
var _message: Label
var _sort := "new"
var _sort_buttons := {}
var _busy := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
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
	panel.offset_left = -440
	panel.offset_top = -320
	panel.offset_right = 440
	panel.offset_bottom = 320
	panel.add_theme_stylebox_override("panel", _box(C_PANEL, C_GOLD.darkened(0.35), 4, 22, 22))
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	root.add_child(_label("COMMUNITY MAPS", 38, C_GOLD))
	root.add_child(_label("Maps made by other players. Build your own in the MAP BUILDER and press PUBLISH.", 15, WorldConst.C_DIM))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	for s: String in ["new", "popular"]:
		var b := Button.new()
		b.name = "Sort_" + s
		b.text = "NEWEST" if s == "new" else "MOST PLAYED"
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(150, 38)
		b.pressed.connect(func() -> void:
			_sort = s
			AudioManager.play("click")
			refresh())
		tabs.add_child(b)
		_sort_buttons[s] = b
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_message = _label("", 18, WorldConst.C_DIM)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_message)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(footer)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "BACK"
	back.custom_minimum_size = Vector2(160, 46)
	back.pressed.connect(close)
	footer.add_child(back)

func refresh() -> void:
	for s: String in _sort_buttons:
		(_sort_buttons[s] as Button).set_pressed_no_signal(s == _sort)
	for child in _list.get_children():
		child.queue_free()
	if not Leaderboard.is_configured():
		_show_message("Community maps need the online server, which isn't set up in this build.")
		return
	_show_message("Loading maps...")
	var res: Dictionary = await Leaderboard.list_maps(_sort)
	if not is_inside_tree():
		return
	if not res.ok:
		var err := String(res.get("error", "unknown error"))
		if err.contains("404"):
			err = "community maps aren't switched on on the server yet."
		_show_message("Couldn't load community maps: %s" % err)
		return
	var rows: Array = res.data if typeof(res.data) == TYPE_ARRAY else []
	if rows.is_empty():
		_show_message("No maps published yet. Be the first: open the MAP BUILDER and press PUBLISH.")
		return
	_show_message("")
	for row: Variant in rows:
		if typeof(row) == TYPE_DICTIONARY:
			_list.add_child(_make_row(row))

func _show_message(text: String) -> void:
	_message.text = text
	_message.visible = not text.is_empty()

func _make_row(data: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _box(C_ROW, Color(0, 0, 0, 0.5), 2, 14, 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(text)
	var map_name := String(data.get("name", "Map"))
	var author := String(data.get("author", "?"))
	text.add_child(_label(map_name.to_upper(), 20, WorldConst.C_TEXT))
	var plays := int(data.get("plays", 0))
	text.add_child(_label("by %s   ·   %d objects   ·   %d %s" % [author, int(data.get("object_count", 0)), plays, "play" if plays == 1 else "plays"], 14, WorldConst.C_DIM))
	var map_id := String(data.get("id", ""))
	var play := Button.new()
	play.name = "Play"
	play.text = "PLAY"
	play.custom_minimum_size = Vector2(120, 44)
	play.theme_type_variation = &"BBPrimaryButton"
	play.pressed.connect(func() -> void: _play(map_id))
	h.add_child(play)
	if Leaderboard.is_logged_in() and author.to_lower() == Leaderboard.username.to_lower():
		var del := Button.new()
		del.name = "Delete"
		del.text = "DELETE"
		del.custom_minimum_size = Vector2(110, 44)
		del.pressed.connect(func() -> void: _delete(map_id))
		h.add_child(del)
	return row

func _play(map_id: String) -> void:
	if _busy:
		return
	_busy = true
	_show_message("Downloading map...")
	var res: Dictionary = await Leaderboard.get_map(map_id)
	_busy = false
	if not is_inside_tree():
		return
	if not res.ok or (res.get("map", {}).get("objects", []) as Array).is_empty():
		AudioManager.play("deny")
		_show_message("Couldn't open that map: %s" % String(res.get("error", "it's empty")))
		return
	AudioManager.play("go")
	GameManager.play_map(res.map)

func _delete(map_id: String) -> void:
	if _busy:
		return
	_busy = true
	var res: Dictionary = await Leaderboard.delete_map(map_id)
	_busy = false
	if not is_inside_tree():
		return
	AudioManager.play("expire" if res.ok else "deny")
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
