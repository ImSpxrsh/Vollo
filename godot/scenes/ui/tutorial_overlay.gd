extends CanvasLayer

## Interactive tutorial. The course (MapStore.TUTORIAL) plays like a real run:
## no ground after the start platform, only hazards, coins and rest bridges.
## Each lesson slows time while its card is read; when the ball reaches a
## step's "hold" x and the player still hasn't built the glowing piece, time
## stops completely until they do. Wrong pieces are refused, and a piece
## dropped near the glowing spot snaps onto it.

const KEYS := ["1", "2", "3"]
const LANE_Y := 428.0
const TARGET_RADIUS := 150.0
const SLOW := 0.3
const FREE_HOLD := 0.6
const GUIDED_LIFETIME := 7.0
const GOLD := Color("FFD166")
const WARN := Color("FF8F6B")

var ball: Node2D
var lesson := -1
var step := 0
var frozen := false
var keys_tried := {}
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
var _placer: Node

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
	GameManager.placement_filter = _filter
	GameManager.item_placed.connect(_on_item_placed)
	GameManager.selection_changed.connect(_on_selection_changed)
	GameManager.tutorial_mistake.connect(_on_mistake)
	GameManager.state_changed.connect(_on_state_changed)
	_add_marker.call_deferred()

func _exit_tree() -> void:
	if GameManager.placement_filter == Callable(self, "_filter"):
		GameManager.placement_filter = Callable()

func _add_marker() -> void:
	if ball and is_instance_valid(ball):
		ball.get_parent().add_child(_marker)
		_placer = ball.get_parent().get_node_or_null("ItemPlacer")

# --- card -------------------------------------------------------------------

func _build_card() -> void:
	# Top-right: the ball always sits on the left third of the screen, so the
	# card never hides it, even at the top of a big bounce.
	_box = PanelContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_box.offset_left = -560
	_box.offset_right = -16
	_box.offset_top = 118
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.08, 0.03, 0.94)
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	_box.add_theme_stylebox_override("panel", style)
	add_child(_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
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
	_text = _label(20, WorldConst.C_TEXT)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(_text)
	_prompt = _label(19, GOLD)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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

# --- lesson state -----------------------------------------------------------

func current() -> Dictionary:
	return _lessons[lesson] if lesson >= 0 and lesson < _lessons.size() else {}

func steps() -> Array:
	return current().get("steps", [])

func current_step() -> Dictionary:
	var s := steps()
	return s[step] if step < s.size() else {}

func has_pending_step() -> bool:
	return not _completed and step < steps().size()

func _process(_delta: float) -> void:
	if ball == null or not is_instance_valid(ball) or not GameManager.is_playing() or _rewinding:
		return
	var x := ball.global_position.x
	if lesson + 1 < _lessons.size() and x >= float(_lessons[lesson + 1].at) and not has_pending_step():
		_start_lesson(lesson + 1)
	var l := current()
	if l.is_empty():
		return
	if has_pending_step() and not frozen and x >= float(current_step().hold):
		_freeze()
	if not _completed and not has_pending_step() and l.has("done") and x >= float(l.done):
		_complete_lesson()

func _start_lesson(i: int) -> void:
	lesson = i
	step = 0
	keys_tried.clear()
	_completed = false
	var l := current()
	_title.text = "LESSON %d / %d  ·  %s" % [i + 1, _lessons.size(), String(l.title)]
	_text.text = String(l.text)
	for d in _dots.get_child_count():
		(_dots.get_child(d) as ColorRect).color = GOLD if d < i else (Color.WHITE if d == i else Color(1, 1, 1, 0.25))
	if l.get("keys", false):
		_set_hold(0.0)
	elif not steps().is_empty():
		_set_hold(SLOW)
	else:
		_set_hold(float(l.get("speed", FREE_HOLD if l.get("free", false) else 1.0)))
	GameManager.player(0).clear_cooldowns()
	_show_marker()
	_refresh_prompt()
	_box.visible = true
	_box.modulate.a = 0.0
	var tw := _box.create_tween().set_ignore_time_scale(true)
	tw.tween_property(_box, "modulate:a", 1.0, 0.2)
	AudioManager.play("click")

func _complete_lesson() -> void:
	_completed = true
	var l := current()
	_set_hold(float(l.get("after_speed", 1.0)))
	_marker.visible = false
	if l.has("after_card") or l.has("after"):
		_text.text = String(l.get("after_card", l.get("after", "")))
	if l.has("after"):
		# The next lesson usually starts a moment later, so also show the
		# takeaway as a big flash that outlives the card.
		_say(String(l.after), GOLD, 3.0)
	_prompt.text = ""
	(_dots.get_child(lesson) as ColorRect).color = GOLD

func _set_hold(value: float) -> void:
	frozen = value <= 0.0
	GameManager.set_time_hold(value)

func _freeze() -> void:
	_set_hold(0.0)
	AudioManager.play("click")
	_show_marker()
	_refresh_prompt()

func _show_marker() -> void:
	var s := current_step()
	_marker.visible = not s.is_empty() and not _completed
	if _marker.visible:
		var item := int(s.item)
		var picked := GameManager.player(0).selected_item == item
		var flip_ok := item != GameManager.Item.RAMP or GameManager.player(0).ramp_flipped == bool(s.get("flip", false))
		_marker.set("item", item)
		_marker.set("flipped", bool(s.get("flip", false)))
		_marker.set("label", "CLICK HERE" if picked and flip_ok else ("PRESS R" if picked else "PRESS %s" % KEYS[item]))
		_marker.global_position = s.pos
		_marker.queue_redraw()

func _item_name(item: int) -> String:
	return String(GameManager.ITEM_NAMES[item]).to_upper()

func _refresh_prompt() -> void:
	var l := current()
	if l.is_empty() or _completed:
		return
	if l.get("keys", false):
		var marks := PackedStringArray()
		for i in 3:
			marks.append("[%s %s%s]" % [KEYS[i], _item_name(i), " ✓" if keys_tried.has(i) else ""])
		_prompt.text = "Time is stopped. Press 1, 2 and 3 to try each piece:\n" + "  ".join(marks)
		return
	if l.get("free", false):
		_prompt.text = String(l.get("prompt", ""))
		return
	var s := current_step()
	if s.is_empty():
		_prompt.text = "Watch it go!"
		return
	var item := int(s.item)
	var want_flip := bool(s.get("flip", false))
	var ps := GameManager.player(0)
	var lead := "TIME STOPPED  ·  " if frozen else "Step %d of %d  ·  " % [step + 1, steps().size()]
	if ps.selected_item != item:
		_prompt.text = lead + "Press  [ %s ]  for the %s" % [KEYS[item], _item_name(item)]
	elif item == GameManager.Item.RAMP and ps.ramp_flipped != want_flip:
		_prompt.text = lead + "Press  [ R ]  to flip the ramp so it slopes %s" % ("DOWN" if want_flip else "UP")
	else:
		_prompt.text = lead + String(s.get("tip", "Click the glowing %s" % _item_name(item)))

func _on_selection_changed(item: int, _flipped: bool) -> void:
	var l := current()
	if l.get("keys", false) and not _completed:
		keys_tried[item] = true
		if keys_tried.size() >= 3:
			_say("Nice! Here we go.", GOLD)
			AudioManager.play("coin")
			_complete_lesson()
			return
	_show_marker()
	_refresh_prompt()

# --- placement gate ---------------------------------------------------------

## GameManager.placement_filter: returns where to build, or null to refuse.
func _filter(item: int, pos: Vector2, preview: bool) -> Variant:
	var l := current()
	if l.is_empty() or _rewinding:
		return null
	if l.get("keys", false) and not _completed:
		if not preview:
			_say("First press 1, 2 and 3 to try each piece!", WARN)
		return null
	if l.get("free", false) or (steps().is_empty() and _completed):
		return pos
	var s := current_step()
	if s.is_empty():
		if not preview:
			_say("Hands off! Watch this one play out.", WARN)
		return null
	var want := int(s.item)
	if item != want:
		if not preview:
			_say("That's a %s. Press %s for the %s!" % [_item_name(item), KEYS[want], _item_name(want)], WARN)
		return null
	if item == GameManager.Item.RAMP and GameManager.player(0).ramp_flipped != bool(s.get("flip", false)):
		if not preview:
			_say("Press R to flip the ramp first!", WARN)
		return null
	if pos.distance_to(s.pos) > TARGET_RADIUS:
		if not preview:
			_say("Put it on the glowing spot.", WARN)
		return null
	return s.pos

func _on_item_placed(item: int, _pos: Vector2) -> void:
	if not has_pending_step() or item != int(current_step().item):
		return
	# item_placed fires just before the piece node exists, so wait a moment.
	_extend_last_piece.call_deferred()
	GameManager.player(0).clear_cooldowns()
	step += 1
	if has_pending_step():
		_say("Nice! Next one.", GOLD)
		if frozen and ball.global_position.x < float(current_step().hold):
			_set_hold(SLOW)
		_show_marker()
		_refresh_prompt()
		return
	_say("Nice!", GOLD)
	AudioManager.play("coin")
	_set_hold(1.0)
	_marker.visible = false
	_prompt.text = "Watch it go!"

## Guided pieces may be built long before the ball reaches them.
func _extend_last_piece() -> void:
	if _placer == null or not is_instance_valid(_placer):
		return
	var piece: Variant = _placer.get("last_placed")
	if is_instance_valid(piece):
		(piece as Node).set("lifetime", GUIDED_LIFETIME)

func _say(msg: String, color: Color, seconds := 1.1) -> void:
	_flash.text = msg
	_flash.add_theme_color_override("font_color", color)
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.modulate.a = 1.0
	_flash_tween = _flash.create_tween().set_ignore_time_scale(true)
	_flash_tween.tween_interval(seconds)
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, 0.4)

# --- mistakes ---------------------------------------------------------------

func _on_mistake() -> void:
	if _rewinding:
		return
	_rewinding = true
	_rewind.call_deferred()

func _rewind() -> void:
	var back := maxi(lesson, 0)
	var cp := float(_lessons[back].cp)
	_say("Oops! Let's try that again.", WARN)
	AudioManager.play("deny")
	_marker.visible = false
	_set_hold(1.0)
	var scene := ball.get_parent()
	var items := scene.get_node_or_null("Items")
	if items:
		for piece in items.get_children():
			piece.queue_free()
	var gen := scene.get_node_or_null("LevelGenerator")
	# Drop in from slightly above: bridges are one-way and let a ball that
	# starts inside them sink through.
	ball.call("teleport", Vector2(cp, LANE_Y - 24.0))
	if gen:
		gen.call("reset")
	GameManager.player(0).clear_cooldowns()
	# Restart from the lesson the checkpoint belongs to (every checkpoint sits
	# on the start platform or a rest bridge).
	var restart := 0
	for i in _lessons.size():
		if float(_lessons[i].at) <= cp:
			restart = i
	lesson = restart - 1
	step = 0
	_completed = true
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
