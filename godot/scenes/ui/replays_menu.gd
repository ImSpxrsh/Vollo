extends Control

signal closed

const C_PANEL := Color(0.2, 0.11, 0.05, 0.96)
const C_ROW := Color(0.29, 0.17, 0.08, 1.0)
const C_GOLD := Color("FFD166")
const MODE_NAMES := {"solo": "SOLO RUN", "map": "CUSTOM MAP", "versus": "2-PLAYER", "bot": "VS BOT", "watch": "BOT vs BOT"}

var _list: VBoxContainer
var _empty: Label

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
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)
	root.add_child(_label("REPLAYS", 38, C_GOLD))
	root.add_child(_label("Your last %d runs and matches are saved here automatically. RACE a solo run to play its course against your ghost." % ReplayStore.KEEP, 15, WorldConst.C_DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_empty = _label("No replays yet. Play a run or a versus match and it'll show up here.", 18, WorldConst.C_DIM)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_empty)
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
	for child in _list.get_children():
		child.queue_free()
	var paths := ReplayStore.list()
	_empty.visible = paths.is_empty()
	for path: String in paths:
		var data := ReplayStore.load_replay(path)
		if not data.is_empty():
			_list.add_child(_make_row(data))

func _make_row(data: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _box(C_ROW, Color(0, 0, 0, 0.5), 2, 14, 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	for v: String in data.get("varieties", []):
		var ball := TextureRect.new()
		ball.texture = UiArt.load_texture(SaveManager.get_variety_texture_path(v))
		ball.custom_minimum_size = Vector2(40, 40)
		ball.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ball.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(ball)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(text)
	var mode := String(MODE_NAMES.get(String(data.get("mode", "solo")), "RUN"))
	var map_name := String((data.get("map", {}) as Dictionary).get("name", ""))
	if not map_name.is_empty():
		mode += "  ·  " + map_name
	var names := " vs ".join(PackedStringArray(data.get("names", [])))
	text.add_child(_label("%s  ·  %s" % [mode, String(data.get("result", "")).to_upper()], 18, WorldConst.C_TEXT))
	var secs := int(data.get("duration", 0.0))
	text.add_child(_label("%s   ·   %s   ·   %d:%02d" % [names, String(data.get("saved_at", "")).replace("T", " ").left(16), secs / 60, secs % 60], 14, WorldConst.C_DIM))
	var watch := Button.new()
	watch.name = "Watch"
	watch.text = "WATCH"
	watch.custom_minimum_size = Vector2(120, 44)
	watch.theme_type_variation = &"BBPrimaryButton"
	watch.pressed.connect(func() -> void:
		AudioManager.play("go")
		GameManager.watch_replay(data))
	h.add_child(watch)
	if GameManager.can_race(data):
		var race := Button.new()
		race.name = "Race"
		race.text = "RACE"
		race.tooltip_text = "Play the same course with this run as a ghost"
		race.custom_minimum_size = Vector2(100, 44)
		race.pressed.connect(func() -> void:
			AudioManager.play("go")
			GameManager.race_ghost(data))
		h.add_child(race)
	var del := Button.new()
	del.name = "Delete"
	del.text = "DELETE"
	del.custom_minimum_size = Vector2(110, 44)
	del.pressed.connect(func() -> void:
		AudioManager.play("expire")
		ReplayStore.remove(String(data.path))
		refresh())
	h.add_child(del)
	return row

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
