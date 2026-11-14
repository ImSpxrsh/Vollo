extends Control

signal closed

const CARD_SIZE := Vector2(132, 150)
const C_PANEL := Color(0.2, 0.11, 0.05, 0.96)
const C_CARD := Color(0.29, 0.17, 0.08, 1.0)
const C_CARD_LOCKED := Color(0.16, 0.1, 0.06, 1.0)
const C_GOLD := Color("FFD166")
const C_LOCKED_BALL := Color(0.12, 0.1, 0.1, 0.9)

var highlighted := ""
var _cards := {}
var _detail_ball: TextureRect
var _detail_name: Label
var _detail_status: Label
var _detail_award: Label
var _detail_desc: Label
var _detail_bar: ProgressBar
var _detail_progress: Label
var _equip_button: Button
var _awards_count: Label
var _varieties_view: Control
var _stats_view: Control
var _tab_varieties: Button
var _tab_stats: Button
var _hint: Label
var _stat_values := {}
var _award_list: VBoxContainer

const STAT_ROWS := [
	["BEST DISTANCE", "best_distance"], ["RUNS PLAYED", "runs_played"],
	["TOTAL BOUNCES", "total_bounces"], ["COINS COLLECTED", "total_coins"],
	["COIN BALANCE", "coin_balance"], ["BEST RUN COINS", "best_run_coins"],
	["ENEMIES STOMPED", "total_stomps"], ["SHIELD SAVES", "total_shield_saves"],
	["BEST COMBO", "best_combo"], ["BEST LEVEL", "best_level"],
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	highlighted = SaveManager.selected_variety
	_refresh_all()
	_show_detail(highlighted)
	var card: Button = _cards.get(highlighted)
	if card:
		card.grab_focus.call_deferred()
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
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1140, 640)
	panel.offset_left = -570
	panel.offset_top = -320
	panel.offset_right = 570
	panel.offset_bottom = 320
	panel.add_theme_stylebox_override("panel", _box(C_PANEL, C_GOLD.darkened(0.35), 4, 22, 22))
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)
	_tab_varieties = _make_tab("VARIETIES")
	_tab_varieties.name = "TabVarieties"
	_tab_varieties.pressed.connect(_show_view.bind(false, true))
	header.add_child(_tab_varieties)
	_tab_stats = _make_tab("STATS & AWARDS")
	_tab_stats.name = "TabStats"
	_tab_stats.pressed.connect(_show_view.bind(true, true))
	header.add_child(_tab_stats)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_awards_count = _label("", 20, WorldConst.C_TEXT)
	_awards_count.name = "AwardsCount"
	_awards_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_awards_count)

	var views := Control.new()
	views.size_flags_vertical = Control.SIZE_EXPAND_FILL
	views.custom_minimum_size = Vector2(0, CARD_SIZE.y * 3 + 24)
	root.add_child(views)

	var body := HBoxContainer.new()
	body.name = "VarietiesView"
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_theme_constant_override("separation", 22)
	views.add_child(body)
	_varieties_view = body

	_stats_view = _build_stats()
	_stats_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stats_view.visible = false
	views.add_child(_stats_view)

	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)
	for data: Dictionary in SaveManager.VARIETIES:
		var card := _make_card(String(data.id))
		grid.add_child(card)
		_cards[String(data.id)] = card

	body.add_child(_build_detail())

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(footer)
	_hint = _label("", 14, WorldConst.C_DIM)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_hint)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "BACK"
	back.custom_minimum_size = Vector2(160, 46)
	back.pressed.connect(close)
	footer.add_child(back)
	_show_view(false, false)

func _build_detail() -> Control:
	var detail := PanelContainer.new()
	detail.name = "Detail"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_stylebox_override("panel", _box(Color(0.12, 0.07, 0.03, 0.9), Color(0, 0, 0, 0), 0, 18, 18))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	detail.add_child(col)
	_detail_ball = TextureRect.new()
	_detail_ball.custom_minimum_size = Vector2(170, 170)
	_detail_ball.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_ball.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_ball.pivot_offset = Vector2(85, 85)
	col.add_child(_detail_ball)
	_detail_name = _label("", 30, WorldConst.C_TEXT)
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_detail_name)
	_detail_status = _label("", 16, WorldConst.C_DIM)
	_detail_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_detail_status)
	col.add_child(HSeparator.new())
	_detail_award = _label("", 20, C_GOLD)
	_detail_award.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_detail_award)
	_detail_desc = _label("", 16, WorldConst.C_TEXT)
	_detail_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_detail_desc)
	_detail_bar = ProgressBar.new()
	_detail_bar.custom_minimum_size = Vector2(300, 18)
	_detail_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail_bar.show_percentage = false
	_detail_bar.max_value = 1.0
	_detail_bar.step = 0.0
	_detail_bar.add_theme_stylebox_override("background", _box(Color(0.06, 0.03, 0.02), Color(0, 0, 0), 2, 9, 0))
	_detail_bar.add_theme_stylebox_override("fill", _box(Color("53A548"), Color(0, 0, 0, 0), 0, 9, 0))
	col.add_child(_detail_bar)
	_detail_progress = _label("", 14, WorldConst.C_DIM)
	_detail_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_detail_progress)
	_equip_button = Button.new()
	_equip_button.name = "EquipButton"
	_equip_button.custom_minimum_size = Vector2(220, 50)
	_equip_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_equip_button.pressed.connect(_on_equip)
	col.add_child(_equip_button)
	return detail

func _make_tab(text: String) -> Button:
	var tab := Button.new()
	tab.text = text
	tab.toggle_mode = true
	tab.focus_mode = Control.FOCUS_ALL
	tab.custom_minimum_size = Vector2(0, 52)
	tab.add_theme_font_size_override("font_size", 24)
	return tab

func _style_tab(tab: Button, active: bool) -> void:
	tab.button_pressed = active
	var bg := C_CARD if active else C_CARD_LOCKED
	var border := C_GOLD if active else Color(0, 0, 0, 0.5)
	var normal := _box(bg, border, 3 if active else 2, 14, 0)
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.08)
	for state in ["normal", "pressed", "hover_pressed"]:
		tab.add_theme_stylebox_override(state, normal)
	tab.add_theme_stylebox_override("hover", hover)
	tab.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.4), 2, 14, 0))
	var text_color := C_GOLD if active else WorldConst.C_DIM
	for c in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		tab.add_theme_color_override(c, text_color)

func _show_view(stats: bool, user := false) -> void:
	if user:
		AudioManager.play("click")
	_varieties_view.visible = not stats
	_stats_view.visible = stats
	_style_tab(_tab_varieties, not stats)
	_style_tab(_tab_stats, stats)
	if stats:
		_refresh_stats()
		_hint.text = "Lifetime stats from every run  ·  Esc to go back"
	else:
		_hint.text = "Everyone starts yellow. Click a ball to see the award that unlocks it  ·  Esc to go back"
		var card: Button = _cards.get(highlighted)
		if user and card:
			card.grab_focus()

func _build_stats() -> Control:
	var view := HBoxContainer.new()
	view.name = "StatsView"
	view.add_theme_constant_override("separation", 22)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	view.add_child(left)
	left.add_child(_label("LIFETIME", 18, C_GOLD))
	var stat_grid := GridContainer.new()
	stat_grid.name = "StatGrid"
	stat_grid.columns = 2
	stat_grid.add_theme_constant_override("h_separation", 12)
	stat_grid.add_theme_constant_override("v_separation", 10)
	left.add_child(stat_grid)
	for row: Array in STAT_ROWS:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(206, 74)
		card.add_theme_stylebox_override("panel", _box(C_CARD, Color(0, 0, 0, 0.5), 2, 14, 10))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		card.add_child(col)
		col.add_child(_label(String(row[0]), 12, WorldConst.C_DIM))
		var value := _label("0", 26, WorldConst.C_TEXT)
		col.add_child(value)
		_stat_values[String(row[1])] = value
		stat_grid.add_child(card)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	view.add_child(right)
	right.add_child(_label("AWARDS", 18, C_GOLD))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_award_list = VBoxContainer.new()
	_award_list.name = "AwardList"
	_award_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_award_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_award_list)
	return view

func _refresh_stats() -> void:
	for key: String in _stat_values:
		var value := SaveManager.coin_balance() if key == "coin_balance" else int(SaveManager.stats.get(key, 0))
		var text := str(value)
		if key == "best_distance":
			text = "%d m" % value
		elif key == "best_combo":
			text = "x%d" % value
		(_stat_values[key] as Label).text = text
	for child in _award_list.get_children():
		child.queue_free()
	for award: Dictionary in SaveManager.AWARDS:
		_award_list.add_child(_make_award_row(award))

func _make_award_row(award: Dictionary) -> Control:
	var award_id := String(award.id)
	var earned := SaveManager.has_award(award_id)
	var variety_id := SaveManager.variety_for_award(award_id)
	var row := PanelContainer.new()
	row.name = "Award_" + award_id
	var bg := C_CARD if earned else Color(0.12, 0.07, 0.03, 0.9)
	var row_box := _box(bg, C_GOLD.darkened(0.2) if earned else Color(0, 0, 0, 0), 2 if earned else 0, 12, 6)
	row_box.content_margin_left = 12
	row_box.content_margin_right = 12
	row.add_theme_stylebox_override("panel", row_box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)

	var star := _label("★" if earned else "☆", 22, C_GOLD if earned else Color(1, 1, 1, 0.25))
	star.custom_minimum_size = Vector2(24, 0)
	star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(star)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", -2)
	h.add_child(text_col)
	text_col.add_child(_label(String(award.name).to_upper(), 16, C_GOLD if earned else WorldConst.C_TEXT))
	text_col.add_child(_label(String(award.desc), 13, WorldConst.C_DIM))

	if not variety_id.is_empty():
		var reward := HBoxContainer.new()
		reward.add_theme_constant_override("separation", 6)
		reward.custom_minimum_size = Vector2(118, 0)
		h.add_child(reward)
		var icon := TextureRect.new()
		icon.texture = UiArt.load_texture(SaveManager.get_variety_texture_path(variety_id))
		icon.custom_minimum_size = Vector2(26, 26)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.modulate = Color.WHITE if earned else C_LOCKED_BALL
		reward.add_child(icon)
		var reward_name := _label(SaveManager.get_variety_name(variety_id), 13,
				SaveManager.get_variety_color(variety_id).lightened(0.15) if earned else WorldConst.C_DIM)
		reward_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		reward_name.size_flags_vertical = Control.SIZE_EXPAND_FILL
		reward.add_child(reward_name)

	var prog := VBoxContainer.new()
	prog.alignment = BoxContainer.ALIGNMENT_CENTER
	prog.add_theme_constant_override("separation", 2)
	h.add_child(prog)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(150, 12)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.0
	bar.value = SaveManager.award_progress(award_id)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _box(Color(0.06, 0.03, 0.02), Color(0, 0, 0), 1, 6, 0))
	bar.add_theme_stylebox_override("fill", _box(C_GOLD if earned else Color("53A548"), Color(0, 0, 0, 0), 0, 6, 0))
	prog.add_child(bar)
	var amount := _label(SaveManager.award_progress_text(award_id), 12, C_GOLD if earned else WorldConst.C_DIM)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prog.add_child(amount)
	return row

func _make_card(variety_id: String) -> Button:
	var card := Button.new()
	card.name = "Card_" + variety_id
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_ALL
	card.pressed.connect(_on_card_pressed.bind(variety_id))
	card.focus_entered.connect(_show_detail.bind(variety_id))
	var ball := TextureRect.new()
	ball.name = "Ball"
	ball.texture = UiArt.load_texture(SaveManager.get_variety_texture_path(variety_id))
	ball.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ball.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ball.position = Vector2((CARD_SIZE.x - 86.0) * 0.5, 12)
	ball.size = Vector2(86, 86)
	card.add_child(ball)
	var lock := _label("?", 40, Color(1, 1, 1, 0.55))
	lock.name = "Lock"
	lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock.position = ball.position
	lock.size = ball.size
	card.add_child(lock)
	var name_label := _label(SaveManager.get_variety_name(variety_id), 14, WorldConst.C_TEXT)
	name_label.name = "Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(0, 104)
	name_label.size = Vector2(CARD_SIZE.x, 20)
	card.add_child(name_label)
	var tag := _label("", 11, C_GOLD)
	tag.name = "Tag"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.position = Vector2(0, 124)
	tag.size = Vector2(CARD_SIZE.x, 16)
	card.add_child(tag)
	return card

func _refresh_all() -> void:
	_awards_count.text = "AWARDS  %d / %d" % [SaveManager.earned_awards.size(), SaveManager.AWARDS.size()]
	for variety_id: String in _cards:
		_refresh_card(variety_id)
	if _stats_view.visible:
		_refresh_stats()

func _refresh_card(variety_id: String) -> void:
	var card: Button = _cards[variety_id]
	var unlocked := SaveManager.is_variety_unlocked(variety_id)
	var equipped := SaveManager.selected_variety == variety_id
	var focused := variety_id == highlighted
	var border := C_GOLD if equipped else (Color("FFFFFF", 0.7) if focused else Color(0, 0, 0, 0.5))
	var bg := C_CARD if unlocked else C_CARD_LOCKED
	var normal := _box(bg, border, 4 if equipped or focused else 2, 16, 0)
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", _box(bg.lightened(0.08), border if equipped or focused else Color(1, 1, 1, 0.35), 3, 16, 0))
	card.add_theme_stylebox_override("pressed", normal)
	card.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.0), 0, 16, 0))
	(card.get_node("Ball") as TextureRect).modulate = Color.WHITE if unlocked else C_LOCKED_BALL
	(card.get_node("Lock") as Label).visible = not unlocked
	var tag := card.get_node("Tag") as Label
	if equipped:
		tag.text = "EQUIPPED"
		tag.add_theme_color_override("font_color", C_GOLD)
	elif SaveManager.new_variety_unlocks.has(variety_id):
		tag.text = "NEW!"
		tag.add_theme_color_override("font_color", Color("7CFF6B"))
	elif not unlocked:
		tag.text = "%d%%" % roundi(SaveManager.award_progress(String(SaveManager.get_variety(variety_id).award)) * 100.0)
		tag.add_theme_color_override("font_color", WorldConst.C_DIM)
	else:
		tag.text = ""

func _show_detail(variety_id: String) -> void:
	var previous := highlighted
	highlighted = variety_id
	if _cards.has(previous):
		_refresh_card(previous)
	_refresh_card(variety_id)
	var unlocked := SaveManager.is_variety_unlocked(variety_id)
	var equipped := SaveManager.selected_variety == variety_id
	var award_id := String(SaveManager.get_variety(variety_id).award)
	_detail_ball.texture = UiArt.load_texture(SaveManager.get_variety_texture_path(variety_id))
	_detail_ball.modulate = Color.WHITE if unlocked else C_LOCKED_BALL
	_detail_name.text = SaveManager.get_variety_name(variety_id)
	_detail_name.add_theme_color_override("font_color", SaveManager.get_variety_color(variety_id).lightened(0.15) if unlocked else WorldConst.C_DIM)
	if equipped:
		_detail_status.text = "Rolling with this one"
	elif unlocked:
		_detail_status.text = "Unlocked"
	else:
		_detail_status.text = "Locked"
	if award_id.is_empty():
		_detail_award.text = "STARTER"
		_detail_desc.text = "The original. Always yours."
		_detail_bar.visible = false
		_detail_progress.text = ""
	else:
		var award := SaveManager.get_award(award_id)
		_detail_award.text = ("★ " if SaveManager.has_award(award_id) else "") + String(award.name).to_upper()
		_detail_desc.text = String(award.desc)
		_detail_bar.visible = true
		_detail_bar.value = SaveManager.award_progress(award_id)
		_detail_progress.text = "Earned!" if SaveManager.has_award(award_id) else SaveManager.award_progress_text(award_id)
	_equip_button.disabled = not unlocked or equipped
	_equip_button.text = "EQUIPPED" if equipped else ("EQUIP" if unlocked else "LOCKED")
	if unlocked:
		SaveManager.mark_variety_seen(variety_id)
	_detail_ball.scale = Vector2(0.9, 0.9)
	create_tween().tween_property(_detail_ball, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_card_pressed(variety_id: String) -> void:
	AudioManager.play("click")
	if highlighted == variety_id and SaveManager.is_variety_unlocked(variety_id):
		_on_equip()
	else:
		_show_detail(variety_id)

func _on_equip() -> void:
	if not SaveManager.select_variety(highlighted):
		AudioManager.play("deny")
		return
	AudioManager.play("pickup")
	_refresh_all()
	_show_detail(highlighted)

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
