extends CanvasLayer

const CARD_SCRIPT := preload("res://scenes/ui/hotbar_card.gd")

@onready var distance_label: Label = %DistanceLabel
@onready var best_label: Label = %BestLabel
@onready var status_label: Label = %StarsLabel
@onready var controls_label: Label = %ComboLabel
@onready var hotbar: HBoxContainer = %Hotbar
@onready var shield_tag: PanelContainer = %ShieldTag
@onready var speed_tag: PanelContainer = %SpeedTag
@onready var speed_label: Label = %SpeedLabel
@onready var milestone_label: Label = %MilestoneLabel

var cards: Array[Button] = []
var _bounces := 0
var _shards := 0
var _ball: Node
var _run_time := 0.0
var _last_milestone := 0
var _speed_tier := 0
var _milestone_y := 0.0
var _milestone_tween: Tween
var _level_banner: Label
var _level_tween: Tween
var _toasts: VBoxContainer
var _power_box: HBoxContainer
var _power_tags := {}
var _hearts: HBoxContainer
var _hint_panel: PanelContainer
var _hint_label: Label
var _hint_tween: Tween
var _hints_on := false
var _hints_shown := {}
var _placed_count := 0

func _ready() -> void:
	for i in 3:
		var card := Button.new()
		card.set_script(CARD_SCRIPT)
		card.set("item", i)
		card.name = "Tool%d" % (i + 1)
		hotbar.add_child(card)
		cards.append(card)
	hotbar.visible = true
	controls_label.visible = true
	controls_label.text = "1/2/3 SELECT   ·   CLICK PLACE   ·   R FLIPS RAMP"
	controls_label.modulate = Color(0.27, 0.11, 0.04, 0.82)
	shield_tag.visible = false
	milestone_label.visible = false
	_milestone_y = milestone_label.position.y
	_create_level_banner()
	_create_toasts()
	_create_power_tags()
	_create_hearts()
	_create_hint_panel()

	GameManager.distance_changed.connect(_on_distance_changed)
	GameManager.stars_changed.connect(_on_stars_changed)
	GameManager.bounced.connect(_on_bounced)
	GameManager.selection_changed.connect(_on_selection_changed)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.slowmo_changed.connect(func(active: bool) -> void: _set_power("slowmo", active))
	GameManager.boost_changed.connect(func(active: bool) -> void: _set_power("boost", active))
	SaveManager.award_earned.connect(_on_award_earned)
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.item_placed.connect(_on_item_placed_hint)
	GameManager.stars_changed.connect(func(total: int) -> void:
		if total == 1:
			_hint("coin", "Coins buy upgrades in the SHOP and count towards awards."))
	GameManager.selection_changed.connect(func(item: int, _flipped: bool) -> void:
		if item == GameManager.Item.RAMP:
			_hint("ramp", "Ramps launch you forward. Press R to flip one so it points down."))
	GameManager.bounced.connect(func(clutch: bool, _p: Vector2) -> void:
		if clutch:
			_hint("clutch", "Clutch! Bouncing close to danger raises your combo."))
	_hints_on = int(SaveManager.stats.get("runs_played", 0)) < 3 and not GameManager.is_custom_run()
	_on_health_changed(GameManager.health, GameManager.max_health)
	if _hints_on:
		get_tree().create_timer(0.8).timeout.connect(func() -> void:
			_hint("start", "Variety never stops rolling. Click ahead of it to place a piece."))
	_on_distance_changed(GameManager.distance)
	best_label.text = "BEST  %d m" % maxi(GameManager.best, SaveManager.high_score)
	_update_status()
	_connect_ball.call_deferred()

func _create_level_banner() -> void:
	_level_banner = Label.new()
	_level_banner.name = "LevelBanner"
	_level_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_level_banner.offset_left = -360.0
	_level_banner.offset_top = 235.0
	_level_banner.offset_right = 360.0
	_level_banner.offset_bottom = 320.0
	_level_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_banner.add_theme_font_size_override("font_size", 34)
	_level_banner.add_theme_color_override("font_color", Color(1.0, 0.78, 0.28))
	_level_banner.add_theme_color_override("font_shadow_color", Color(0.22, 0.08, 0.02, 0.95))
	_level_banner.add_theme_constant_override("shadow_offset_x", 3)
	_level_banner.add_theme_constant_override("shadow_offset_y", 4)
	_level_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_banner.visible = false
	$Root.add_child(_level_banner)

func _on_level_changed(number: int, level_name: String, _theme_index: int) -> void:
	if GameManager.is_custom_run():
		return
	if _level_tween and _level_tween.is_valid():
		_level_tween.kill()
	var stage := "WARM-UP" if number <= GameManager.GUIDED_LEVELS else "RANDOM ROUTE"
	_level_banner.text = "LEVEL %d  ·  %s\n%s" % [number, stage, level_name]
	_level_banner.visible = true
	_level_banner.modulate = Color(1, 1, 1, 0)
	_level_banner.scale = Vector2(0.82, 0.82)
	_level_banner.pivot_offset = _level_banner.size * 0.5
	_level_tween = create_tween()
	_level_tween.set_parallel(true)
	_level_tween.tween_property(_level_banner, "modulate:a", 1.0, 0.2)
	_level_tween.tween_property(_level_banner, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_level_tween.set_parallel(false)
	_level_tween.tween_interval(1.15)
	_level_tween.tween_property(_level_banner, "modulate:a", 0.0, 0.42)
	_level_tween.tween_callback(_level_banner.hide)

func _connect_ball() -> void:
	for _attempt in 30:
		if not is_inside_tree():
			return
		_ball = get_tree().get_first_node_in_group("ball")
		if _ball:
			break
		await get_tree().process_frame
	if _ball and _ball.has_signal("shield_changed"):
		_ball.connect("shield_changed", _on_shield_changed)
		_on_shield_changed(bool(_ball.get("has_shield")))

func _process(delta: float) -> void:
	_run_time += delta
	for card in cards:
		card.call("refresh")
	controls_label.modulate.a = lerpf(controls_label.modulate.a, 0.24 if _run_time > 7.0 else 0.68, 1.0 - exp(-delta * 3.0))
	_update_speed()

func _on_distance_changed(meters: int) -> void:
	if meters >= 9:
		_hint("hazard", "Red towers, spikes and devil balls cost a heart. Bounce over them!")
	if meters >= 30:
		_hint("stomp", "Fall onto an enemy, or hit it right after a trampoline, to bounce it away.")
	distance_label.text = "%d m" % meters
	var milestone := meters / 50
	if milestone > _last_milestone and meters > 0:
		_last_milestone = milestone
		_show_milestone(milestone * 50)

func _on_stars_changed(total: int) -> void:
	_shards = total
	_update_status()

func _on_bounced(_clutch: bool, _position: Vector2) -> void:
	_bounces += 1
	_update_status()

func _update_status() -> void:
	status_label.text = "BOUNCES  %d   ·   COINS  %d" % [_bounces, _shards]

func _on_selection_changed(_item: int, ramp_flipped: bool) -> void:
	for card in cards:
		card.call("set_ramp_flipped", ramp_flipped)
		card.call("refresh", true)

func _on_state_changed(state: int) -> void:
	if state == GameManager.State.PLAYING:
		best_label.text = "BEST  %d m" % maxi(GameManager.best, SaveManager.high_score)

func _on_shield_changed(active: bool) -> void:
	shield_tag.visible = active
	if active:
		_pulse(shield_tag)

func _update_speed() -> void:
	if _ball == null or not is_instance_valid(_ball):
		return
	var raw_speed: Variant = _ball.get("speed")
	if not (raw_speed is float):
		return
	var ratio := float(raw_speed) / 300.0
	var danger := ratio >= 1.7
	speed_label.text = ("DANGER  x%.1f" if danger else "PACE  x%.1f") % ratio
	speed_label.add_theme_color_override("font_color", Color(1, 0.82, 0.52) if danger else Color(0.88, 1, 0.58))
	speed_tag.modulate = Color(0.86, 0.45, 0.32) if danger else Color.WHITE
	var tier := maxi(0, int(floor((ratio - 1.0) / 0.35)))
	if tier > _speed_tier:
		_speed_tier = tier
		_pulse(speed_tag)

func _show_milestone(meters: int) -> void:
	if _milestone_tween and _milestone_tween.is_valid():
		_milestone_tween.kill()
	milestone_label.text = "%d m  —  KEEP ROLLING" % meters
	milestone_label.visible = true
	milestone_label.modulate = Color(1.0, 0.82, 0.4, 0.0)
	milestone_label.position.y = _milestone_y + 10.0
	_milestone_tween = create_tween()
	_milestone_tween.set_parallel(true)
	_milestone_tween.tween_property(milestone_label, "modulate:a", 1.0, 0.14)
	_milestone_tween.tween_property(milestone_label, "position:y", _milestone_y, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_milestone_tween.set_parallel(false)
	_milestone_tween.tween_interval(0.65)
	_milestone_tween.tween_property(milestone_label, "modulate:a", 0.0, 0.3)
	_milestone_tween.tween_callback(milestone_label.hide)
	_pulse(distance_label)

func _pulse(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(1.14, 1.14)
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _create_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.name = "Toasts"
	_toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toasts.offset_left = -380.0
	_toasts.offset_right = -20.0
	_toasts.offset_top = 96.0
	_toasts.offset_bottom = 420.0
	_toasts.add_theme_constant_override("separation", 8)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(_toasts)

func toast(title: String, body: String, icon_path := "", accent := Color("FFD166")) -> void:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.12, 0.07, 0.04, 0.9)
	box.border_color = accent
	box.set_border_width_all(3)
	box.set_corner_radius_all(12)
	box.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var tex := UiArt.load_texture(icon_path)
	if tex:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = Vector2(46, 46)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", accent)
	text.add_child(t)
	var b := Label.new()
	b.text = body
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", WorldConst.C_TEXT)
	text.add_child(b)
	_toasts.add_child(card)
	card.modulate.a = 0.0
	var tw := card.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.18)
	tw.tween_interval(3.2)
	tw.tween_property(card, "modulate:a", 0.0, 0.45)
	tw.tween_callback(card.queue_free)

func _on_award_earned(_award_id: String, award_name: String, variety_id: String) -> void:
	if variety_id.is_empty():
		toast("AWARD  ·  " + award_name.to_upper(), "Nice!", UiArt.COIN)
		return
	toast("AWARD  ·  " + award_name.to_upper(), "%s variety unlocked!" % SaveManager.get_variety_name(variety_id),
		SaveManager.get_variety_texture_path(variety_id), SaveManager.get_variety_color(variety_id).lightened(0.2))
	AudioManager.play("pickup", 0.0, 2.0)

func _create_power_tags() -> void:
	_power_box = HBoxContainer.new()
	_power_box.name = "PowerTags"
	_power_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_power_box.offset_left = 20.0
	_power_box.offset_right = 420.0
	_power_box.offset_top = 74.0
	_power_box.offset_bottom = 114.0
	_power_box.add_theme_constant_override("separation", 10)
	_power_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(_power_box)
	_power_tags["slowmo"] = _make_power_tag("SLOW-MO", UiArt.SLOWMO_CLOCK, Color("F6B13B"))
	_power_tags["boost"] = _make_power_tag("BOOST", UiArt.SPEED_BOOSTER, Color("4ADE80"))

func _make_power_tag(text: String, icon_path: String, accent: Color) -> PanelContainer:
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.06, 0.03, 0.85)
	box.border_color = accent
	box.set_border_width_all(2)
	box.set_corner_radius_all(16)
	box.content_margin_left = 10
	box.content_margin_right = 12
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	tag.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(row)
	var icon := TextureRect.new()
	icon.texture = UiArt.load_texture(icon_path)
	icon.custom_minimum_size = Vector2(26, 26)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", accent)
	row.add_child(l)
	tag.visible = false
	_power_box.add_child(tag)
	return tag

func _set_power(power: String, active: bool) -> void:
	var tag: PanelContainer = _power_tags.get(power)
	if tag == null:
		return
	tag.visible = active
	if active:
		_pulse(tag)

func _create_hearts() -> void:
	_hearts = HBoxContainer.new()
	_hearts.name = "Hearts"
	_hearts.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hearts.offset_left = 20.0
	_hearts.offset_top = 20.0
	_hearts.offset_right = 300.0
	_hearts.offset_bottom = 64.0
	_hearts.add_theme_constant_override("separation", 6)
	_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(_hearts)

func _on_health_changed(value: int, max_value: int) -> void:
	var lost_before := 0
	for child in _hearts.get_children():
		if child.get_meta("lost", false):
			lost_before += 1
		child.queue_free()
	var full := UiArt.load_texture(SaveManager.get_variety_texture_path())
	var cracked := UiArt.load_texture(SaveManager.get_variety_texture_path(SaveManager.selected_variety, true))
	for i in max_value:
		var icon := TextureRect.new()
		var lost := i >= value
		icon.texture = cracked if lost else full
		icon.set_meta("lost", lost)
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate = Color(0.45, 0.45, 0.5, 0.6) if lost else Color.WHITE
		_hearts.add_child(icon)
		if lost and i == value and max_value - value > lost_before:
			icon.pivot_offset = Vector2(20, 20)
			icon.scale = Vector2(1.6, 1.6)
			icon.create_tween().tween_property(icon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _create_hint_panel() -> void:
	_hint_panel = PanelContainer.new()
	_hint_panel.name = "HintPanel"
	_hint_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_panel.offset_left = -330.0
	_hint_panel.offset_right = 330.0
	_hint_panel.offset_top = -200.0
	_hint_panel.offset_bottom = -150.0
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.06, 0.03, 0.88)
	box.border_color = Color("FFD166")
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(10)
	_hint_panel.add_theme_stylebox_override("panel", box)
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 18)
	_hint_label.add_theme_color_override("font_color", WorldConst.C_TEXT)
	_hint_panel.add_child(_hint_label)
	_hint_panel.visible = false
	$Root.add_child(_hint_panel)

func _hint(id: String, text: String) -> void:
	if not _hints_on or _hints_shown.has(id) or GameManager.state != GameManager.State.PLAYING:
		return
	_hints_shown[id] = true
	if _hint_tween and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_label.text = text
	_hint_panel.visible = true
	_hint_panel.modulate.a = 0.0
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint_panel, "modulate:a", 1.0, 0.2)
	_hint_tween.tween_interval(4.0)
	_hint_tween.tween_property(_hint_panel, "modulate:a", 0.0, 0.4)
	_hint_tween.tween_callback(_hint_panel.hide)

func _on_item_placed_hint(_item: int, _position: Vector2) -> void:
	_placed_count += 1
	if _placed_count == 1:
		_hint("tools", "1 Trampoline  ·  2 Ramp  ·  3 Floor. Pieces vanish after a few seconds.")
