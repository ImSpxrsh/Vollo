extends Control

signal closed

const C_PANEL := Color(0.2, 0.11, 0.05, 0.96)
const C_ROW := Color(0.29, 0.17, 0.08, 1.0)
const C_GOLD := Color("FFD166")

var _balance: Label
var _rows := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_refresh()
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

	var header := HBoxContainer.new()
	root.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(_label("SHOP", 38, C_GOLD))
	titles.add_child(_label("Spend coins on upgrades that last forever.", 15, WorldConst.C_DIM))
	var wallet := HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 8)
	header.add_child(wallet)
	var coin := TextureRect.new()
	coin.texture = UiArt.load_texture(UiArt.COIN)
	coin.custom_minimum_size = Vector2(36, 36)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wallet.add_child(coin)
	_balance = _label("", 26, WorldConst.C_TEXT)
	_balance.name = "Balance"
	_balance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wallet.add_child(_balance)

	var list := VBoxContainer.new()
	list.name = "List"
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	root.add_child(list)
	for u: Dictionary in SaveManager.UPGRADES:
		list.add_child(_make_row(u))

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(footer)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "BACK"
	back.custom_minimum_size = Vector2(160, 46)
	back.pressed.connect(close)
	footer.add_child(back)

func _make_row(u: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _box(C_ROW, Color(0, 0, 0, 0.5), 2, 14, 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	row.add_child(h)
	var icon := TextureRect.new()
	icon.texture = UiArt.load_texture(String(u.icon))
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(text)
	text.add_child(_label(String(u.name).to_upper(), 20, WorldConst.C_TEXT))
	text.add_child(_label(String(u.desc), 15, WorldConst.C_DIM))
	var buy := Button.new()
	buy.name = "Buy_" + String(u.id)
	buy.custom_minimum_size = Vector2(170, 48)
	buy.pressed.connect(_on_buy.bind(String(u.id)))
	h.add_child(buy)
	_rows[String(u.id)] = buy
	return row

func _refresh() -> void:
	_balance.text = "%d" % SaveManager.coin_balance()
	for id: String in _rows:
		var buy: Button = _rows[id]
		var cost := int(SaveManager.get_upgrade(id).cost)
		if SaveManager.has_upgrade(id):
			buy.text = "OWNED"
			buy.disabled = true
		else:
			buy.text = "BUY  ·  %d" % cost
			buy.disabled = not SaveManager.can_buy(id)

func _on_buy(upgrade_id: String) -> void:
	if SaveManager.buy_upgrade(upgrade_id):
		AudioManager.play("buy")
	else:
		AudioManager.play("deny")
	_refresh()

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
