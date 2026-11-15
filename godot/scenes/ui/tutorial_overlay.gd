extends CanvasLayer

const KEYS := ["1", "2", "3"]
const GROUND_Y := 428.0
const TARGET_RADIUS := 150.0
const FREE_HOLD := 0.6
const GOLD := Color("FFD166")

var ball: Node2D
var lesson := -1
var target := 0
var frozen := false
var _lessons: Array = MapStore.TUTORIAL_LESSONS
var _rewinding := false
var _completed := false
var _box: PanelContainer
var _title: Label
var _text: Label
var _prompt: Label
var _dots: HBoxContainer
var _flash: Label
var _flash_tween: Tween
var _marker: Node2D

func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_card()
	_flash = _label(30, Color.WHITE)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_flash.offset_left = -400
	_flash.offset_right = 400
	_flash.offset_top = -120
	_flash.offset_bottom = -70
	_flash.add_theme_color_override("font_shadow_color", Color(0.2, 0.06, 0.02, 0.95))
	_flash.add_theme_constant_override("shadow_offset_x", 3)
	_flash.add_theme_constant_override("shadow_offset_y", 3)
	_flash.modulate.a = 0.0
	add_child(_flash)
	_marker = Node2D.new()
	_marker.name = "TutorialMarker"
	_marker.set_script(preload("res://scenes/ui/tutorial_marker.gd"))
	_marker.visible = false
	GameManager.item_placed.connect(_on_item_placed)
	GameManager.selection_changed.connect(func(_i: int, _f: bool) -> void: _refresh_prompt())
	GameManager.tutorial_mistake.connect(_on_mistake)
	GameManager.state_changed.connect(_on_state_changed)
	_add_marker.call_deferred()

func _add_marker() -> void:
	if ball and is_instance_valid(ball):
		ball.get_parent().add_child(_marker)

func _build_card() -> void:
	_box = PanelContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_box.offset_left = -390
	_box.offset_right = 390
	_box.offset_top = 170
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.08, 0.03, 0.94)
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	_box.add_theme_stylebox_override("panel", style)
	add_child(_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	_box.add_child(col)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_title = _label(16, GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 6)
	_dots.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(_dots)
	for i in _lessons.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dots.add_child(dot)
	_text = _label(22, WorldConst.C_TEXT)
	col.add_child(_text)
	_prompt = _label(19, GOLD)
	col.add_child(_prompt)
	_box.visible = false

func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func current() -> Dictionary:
	return _lessons[lesson] if lesson >= 0 and lesson < _lessons.size() else {}

func _process(_delta: float) -> void:
	if ball == null or not is_instance_valid(ball) or not GameManager.is_playing() or _rewinding:
		return
	var x := ball.global_position.x
	if lesson + 1 < _lessons.size() and x >= float(_lessons[lesson + 1].at):
		_start_lesson(lesson + 1)
	var l := current()
	if not l.is_empty() and not _completed and x >= float(l.done):
		_complete_lesson()

func _start_lesson(i: int) -> void:
	lesson = i
	target = 0
	_completed = false
	var l := current()
	_title.text = "LESSON %d / %d  ·  %s" % [i + 1, _lessons.size(), String(l.title)]
	_text.text = String(l.text)
	for d in _dots.get_child_count():
		(_dots.get_child(d) as ColorRect).color = GOLD if d < i else (Color.WHITE if d == i else Color(1, 1, 1, 0.25))
	var targets: Array = l.get("targets", [])
	if int(l.item) >= 0 and not targets.is_empty():
		_freeze(true)
	elif l.get("free", false):
		frozen = false
		GameManager.set_time_hold(FREE_HOLD)
	else:
		_freeze(false)
	_show_marker()
	_refresh_prompt()
	_box.visible = true
	_box.modulate.a = 0.0
	var tw := _box.create_tween().set_ignore_time_scale(true)
	tw.tween_property(_box, "modulate:a", 1.0, 0.2)
	AudioManager.play("click")

func _complete_lesson() -> void:
	_completed = true
	_freeze(false)
	var l := current()
	if l.has("after"):
		_text.text = String(l.after)
		_prompt.text = ""
	(_dots.get_child(lesson) as ColorRect).color = GOLD

func _freeze(on: bool) -> void:
	frozen = on
	GameManager.set_time_hold(0.0 if on else 1.0)
	GameManager.player(0).clear_cooldowns()

func _show_marker() -> void:
	var l := current()
	var targets: Array = l.get("targets", [])
	_marker.visible = frozen and target < targets.size()
	if _marker.visible:
		_marker.set("item", int(l.item))
		_marker.global_position = targets[target]
		_marker.queue_redraw()

func _refresh_prompt() -> void:
	var l := current()
	if l.is_empty() or _completed:
		return
	var item := int(l.item)
	if item < 0:
		_prompt.text = ""
		return
	var item_name := String(GameManager.ITEM_NAMES[item]).to_upper()
	var picked := GameManager.player(0).selected_item == item
	if l.get("free", false):
		_prompt.text = "Press %s for FLOOR, then click ahead of the ball. Again and again!" % KEYS[item] if not picked else "Click ahead of the ball, again and again!"
	elif not frozen:
		_prompt.text = ""
	elif not picked:
		_prompt.text = "Time is stopped.  Press  [ %s ]  to pick %s" % [KEYS[item], item_name]
	else:
		var left := (l.targets as Array).size() - target
		_prompt.text = "Now click the glowing %s%s" % [item_name, "  (%d more)" % left if left > 1 else ""]

func _on_item_placed(item: int, pos: Vector2) -> void:
	if not frozen:
		return
	var l := current()
	var targets: Array = l.get("targets", [])
	GameManager.player(0).clear_cooldowns()
	if target >= targets.size():
		return
	if item != int(l.item):
		_say("That's a %s. Press %s for the %s!" % [String(GameManager.ITEM_NAMES[item]).to_upper(), KEYS[int(l.item)], String(GameManager.ITEM_NAMES[int(l.item)]).to_upper()], Color("FF8F6B"))
		return
	if pos.distance_to(targets[target]) > TARGET_RADIUS:
		_say("Close! Put it on the glowing spot.", Color("FF8F6B"))
		return
	target += 1
	if target < targets.size():
		_say("Nice! One more.", GOLD)
		_show_marker()
		_refresh_prompt()
		return
	_say("Nice!", GOLD)
	AudioManager.play("coin")
	_freeze(false)
	_marker.visible = false
	_prompt.text = "Watch it go!"

func _say(msg: String, color: Color) -> void:
	_flash.text = msg
	_flash.add_theme_color_override("font_color", color)
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.modulate.a = 1.0
	_flash_tween = _flash.create_tween().set_ignore_time_scale(true)
	_flash_tween.tween_interval(1.1)
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, 0.4)

func _on_mistake() -> void:
	if _rewinding:
		return
	_rewinding = true
	_rewind.call_deferred()

func _rewind() -> void:
	var back := maxi(lesson, 0)
	var l: Dictionary = _lessons[back]
	_say("Oops! Let's try that again.", Color("FF8F6B"))
	AudioManager.play("deny")
	frozen = false
	_marker.visible = false
	GameManager.set_time_hold(1.0)
	var scene := ball.get_parent()
	var items := scene.get_node_or_null("Items")
	if items:
		for piece in items.get_children():
			piece.queue_free()
	var gen := scene.get_node_or_null("LevelGenerator")
	ball.call("teleport", Vector2(float(l.cp), GROUND_Y))
	if gen:
		gen.call("reset")
	GameManager.player(0).clear_cooldowns()
	lesson = back - 1
	_completed = false
	await get_tree().process_frame
	var cam := get_viewport().get_camera_2d()
	if cam:
		cam.reset_smoothing()
	_rewinding = false

func _on_state_changed(state: int) -> void:
	if state == GameManager.State.GAME_OVER:
		GameManager.set_time_hold(1.0)
		_box.visible = false
		_marker.visible = false
