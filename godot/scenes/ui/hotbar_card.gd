extends Button

const CARD_SIZE := Vector2(136, 122)

@export var item := 0

var selected := false
var affordable := true
var cooldown := 0.0
var ramp_flipped := false

var key_label: Label
var key_cap: TextureRect
var cost_label: Label
var name_label: Label
var icon_tile: PanelContainer
var icon_texture: TextureRect
var icon_proc: Control
var slope_hint: Control
var cooldown_overlay: Control
var frame_idle: NinePatchRect
var frame_selected: NinePatchRect

var _icon_art_is_flipped := false
var _styles := {}
var _style_key := ""
var _cool_box: StyleBoxFlat
var _content: Array[CanvasItem] = []

func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	text = ""
	_build_styles()
	_build_children()
	pressed.connect(_on_pressed)
	set_ramp_flipped(GameManager.ramp_flipped)
	refresh(true)

func _build_styles() -> void:
	var mk := func(bg: Color, border: Color, bw: int, glow: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = bg
		s.border_color = border
		s.set_border_width_all(bw)
		s.set_corner_radius_all(12)
		s.anti_aliasing = true
		if glow.a > 0.0:
			s.shadow_color = glow
			s.shadow_size = 10
		return s
	var panel := WorldConst.C_PANEL
	_styles["normal"] = mk.call(panel, Color("D99B45"), 2, Color(0.18, 0.07, 0.02, 0.48))
	_styles["selected"] = mk.call(Color("9D5825"), Color("FFD166"), 4, Color(1.0, 0.65, 0.2, 0.34))
	_styles["poor"] = mk.call(Color("6B3024"), Color(WorldConst.C_HAZARD, 0.75), 2, Color(0.18, 0.05, 0.02, 0.4))
	_styles["poor_selected"] = mk.call(Color("7D3425"), WorldConst.C_HAZARD, 3, Color(WorldConst.C_HAZARD, 0.3))
	_styles["cooling"] = mk.call(Color("5A4635"), Color("9A7650"), 2, Color(0.12, 0.06, 0.02, 0.35))
	_styles["cooling_selected"] = mk.call(Color("705037"), Color("FFD166"), 3, Color(1.0, 0.65, 0.2, 0.2))
	_cool_box = StyleBoxFlat.new()
	_cool_box.bg_color = Color(0.18, 0.10, 0.05, 0.58)
	_cool_box.set_corner_radius_all(12)

func _label(txt: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l

func _icon_paths() -> Array:
	match item:
		0: return [UiArt.ICON_TRAMPOLINE_UI, UiArt.ICON_TRAMPOLINE]
		1: return [UiArt.ICON_RAMP_UI, UiArt.ICON_RAMP]
		2: return [UiArt.ICON_FLOOR_UI]
	return [""]

func _build_children() -> void:
	frame_idle = null
	frame_selected = null

	var cap_tex := UiArt.load_texture(UiArt.keycap(item + 1))
	if cap_tex:
		key_cap = TextureRect.new()
		key_cap.texture = cap_tex
		key_cap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		key_cap.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		key_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_cap.position = Vector2(8, 6)
		key_cap.size = Vector2(24, 24)
		add_child(key_cap)
	else:
		key_label = _label("[%d]" % (item + 1), 14, WorldConst.C_DIM)
		key_label.position = Vector2(10, 6)
	cost_label = _label("READY", 12, WorldConst.C_ACCENT)
	cost_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	cost_label.offset_left = -64
	cost_label.offset_right = -10
	cost_label.offset_top = 6
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_label.z_index = 7
	name_label = _label(String(GameManager.ITEM_NAMES[item]).to_upper(), 14, WorldConst.C_TEXT)
	name_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_top = -28
	name_label.offset_bottom = -8
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var icon_rect := Rect2(CARD_SIZE.x * 0.5 - 30.0, 30.0, 60.0, 58.0)
	var ui_icon := UiArt.load_texture(_icon_paths()[0])
	var big_icon: Texture2D = null
	if ui_icon == null and _icon_paths().size() > 1:
		big_icon = UiArt.load_texture(_icon_paths()[1])
	if ui_icon or big_icon:
		icon_texture = TextureRect.new()
		icon_texture.texture = ui_icon if ui_icon else big_icon
		icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_art_is_flipped = false
		if big_icon:
			icon_tile = PanelContainer.new()
			icon_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tile := StyleBoxFlat.new()
			tile.bg_color = Color("F6D58D")
			tile.set_corner_radius_all(10)
			tile.set_content_margin_all(3)
			icon_tile.add_theme_stylebox_override("panel", tile)
			icon_tile.position = icon_rect.position
			icon_tile.size = icon_rect.size
			icon_tile.add_child(icon_texture)
			add_child(icon_tile)
			_content.append(icon_tile)
		else:
			icon_texture.position = icon_rect.position
			icon_texture.size = icon_rect.size
			add_child(icon_texture)
			_content.append(icon_texture)
	else:
		icon_proc = Control.new()
		icon_proc.set_script(preload("res://scenes/ui/item_icon.gd"))
		icon_proc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_proc.set("item", item)
		icon_proc.position = icon_rect.position
		icon_proc.size = icon_rect.size
		add_child(icon_proc)
		_content.append(icon_proc)
	if item == GameManager.Item.RAMP:
		slope_hint = Control.new()
		slope_hint.set_script(preload("res://scenes/ui/item_icon.gd"))
		slope_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slope_hint.set("small_slope", true)
		slope_hint.position = Vector2(CARD_SIZE.x - 30.0, 30.0)
		slope_hint.size = Vector2(20, 16)
		add_child(slope_hint)
		var r_label := _label("R", 11, WorldConst.C_DIM)
		r_label.position = Vector2(CARD_SIZE.x - 25.0, 46.0)
	if key_label:
		_content.append(key_label)
	if key_cap:
		_content.append(key_cap)
	_content.append(name_label)
	cooldown_overlay = Control.new()
	cooldown_overlay.name = "CooldownOverlay"
	cooldown_overlay.z_index = 5
	cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cooldown_overlay.draw.connect(_draw_cooldown)
	add_child(cooldown_overlay)

func set_ramp_flipped(flipped: bool) -> void:
	ramp_flipped = flipped
	if item != GameManager.Item.RAMP:
		return
	if slope_hint:
		slope_hint.set("flipped", flipped)
	if icon_texture:
		icon_texture.flip_h = flipped != _icon_art_is_flipped
	if icon_proc:
		icon_proc.set("flipped", flipped)

func refresh(force := false) -> void:
	var previous_cool := cooldown
	var now_affordable: bool = GameManager.can_afford(item)
	var now_cool: float = GameManager.cooldown_ratio(item)
	var now_selected: bool = GameManager.selected_item == item
	if not force and now_affordable == affordable and now_selected == selected and is_equal_approx(now_cool, cooldown):
		return
	var selection_changed := now_selected != selected
	affordable = now_affordable
	selected = now_selected
	cooldown = now_cool
	var key := "normal"
	if now_cool > 0.0:
		key = "cooling_selected" if selected else "cooling"
	elif selected:
		key = "selected" if affordable else "poor_selected"
	elif not affordable:
		key = "poor"
	if key != _style_key or force:
		_style_key = key
		_apply_style(key)
	if selection_changed and selected and not force:
		pivot_offset = size * 0.5
		var t := create_tween()
		t.tween_property(self, "scale", Vector2(1.07, 1.07), 0.07)
		t.tween_property(self, "scale", Vector2.ONE, 0.12)
	var seconds_left := now_cool * float(GameManager.ITEM_COOLDOWN[item])
	cost_label.text = "%.1fs" % seconds_left if now_cool > 0.0 else "READY"
	cost_label.add_theme_color_override("font_color", Color("FFD166") if now_cool > 0.0 else WorldConst.C_ACCENT)
	if not force and previous_cool > 0.0 and now_cool <= 0.0:
		_flash_ready()
	cooldown_overlay.queue_redraw()

func _flash_ready() -> void:
	pivot_offset = size * 0.5
	var tween := create_tween().set_parallel()
	modulate = Color(1.2, 1.08, 0.72, 1.0)
	scale = Vector2(1.08, 1.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.32)
	tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _apply_style(key: String) -> void:
	var has_frames := frame_idle != null or frame_selected != null
	var sb: StyleBox = _styles[key]
	if has_frames:
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.055, 0.065, 0.085, 0.88) if cooldown > 0.0 else Color(WorldConst.C_PANEL, 0.8)
		fill.set_corner_radius_all(8)
		fill.set_expand_margin_all(-5.0)
		sb = fill
		var sel_frame := frame_selected if frame_selected else frame_idle
		if frame_idle:
			frame_idle.visible = not selected or frame_selected == null
		if frame_selected:
			frame_selected.visible = selected
		var tint := Color(0.62, 0.66, 0.74) if cooldown > 0.0 else Color.WHITE
		for f in [frame_idle, frame_selected]:
			if f:
				f.modulate = tint
		if sel_frame and selected and frame_selected == null:
			sel_frame.modulate = Color(0.6, 1.0, 0.95) if affordable else tint
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		add_theme_stylebox_override(st, sb)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	cost_label.add_theme_color_override("font_color", Color("FFD166") if cooldown > 0.0 else WorldConst.C_ACCENT)
	for c in _content:
		c.modulate = Color(0.66, 0.7, 0.78, 0.62) if cooldown > 0.0 else Color.WHITE

func _draw_cooldown() -> void:
	if cooldown <= 0.0:
		return
	cooldown_overlay.draw_style_box(_cool_box, Rect2(Vector2.ZERO, Vector2(size.x, size.y * cooldown)))

func _on_pressed() -> void:
	if GameManager.selected_item != item:
		AudioManager.play("click")
	GameManager.select_item(item)
	refresh(true)
