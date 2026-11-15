extends Node2D

const GENERATOR := preload("res://scenes/chunks/LevelGenerator.gd")
const GROUND := preload("res://scenes/chunks/ground_segment.gd")
const BACKGROUND := preload("res://assets/background_forest_path.png")
const THEME := preload("res://resources/themes/bounce_back_theme.tres")
const MIN_X := 520.0
const SNAP := Vector2(20, 10)
const SCROLL_SPEED := 1400.0
const C_PANEL := Color(0.16, 0.08, 0.03, 0.94)
const C_GOLD := Color("FFD166")

const TOOLS := [
	{"k": "low_wall", "name": "WALL"},
	{"k": "hang_wall", "name": "HANGING WALL"},
	{"k": "spikes_low", "name": "SPIKES"},
	{"k": "spikes_high", "name": "ROOF SPIKES"},
	{"k": "enemy", "name": "DEVIL BALL"},
	{"k": "grump", "name": "GRUMP"},
	{"k": "coin", "name": "COIN"},
	{"k": "shield", "name": "SHIELD"},
	{"k": "slowmo", "name": "SLOW-MO"},
	{"k": "booster", "name": "BOOSTER"},
	{"k": "bridge", "name": "BRIDGE"},
	{"k": "finish", "name": "FINISH"},
	{"k": "erase", "name": "ERASE"},
]

var map := {"name": "My Map", "objects": []}
var tool := "low_wall"
var spike_count := 2
var _gen: Node2D
var _objects_root: Node2D
var _entries: Array = []
var _ghost: Node2D
var _ghost_key := ""
var _camera: Camera2D
var _tool_buttons := {}
var _name_edit: LineEdit
var _load_menu: OptionButton
var _status: Label
var _count_label: Label
var _ui_hover := false
var _dirty := false

func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	_gen = GENERATOR.new()
	_build_world()
	_build_ui()
	if not MapStore.editing.is_empty():
		_load_dict(MapStore.editing)
		MapStore.editing = {}
	else:
		_load_dict({"name": "My Map", "objects": [{"k": "finish", "x": 4200}]})
	_select_tool("low_wall")

func _exit_tree() -> void:
	if _gen:
		_gen.free()

func _build_world() -> void:
	var back_layer := CanvasLayer.new()
	back_layer.layer = -5
	add_child(back_layer)
	var back := TextureRect.new()
	back.texture = BACKGROUND
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back.modulate = Color(0.7, 0.7, 0.75)
	back_layer.add_child(back)
	var start := StaticBody2D.new()
	start.set_script(GROUND)
	start.position = Vector2(-180, 460)
	start.set("width", 1050.0)
	start.set("thickness", 80.0)
	add_child(start)
	var ball := Sprite2D.new()
	ball.texture = UiArt.load_texture(SaveManager.get_variety_texture_path())
	if ball.texture:
		ball.scale = Vector2.ONE * (70.0 / ball.texture.get_width())
	ball.position = Vector2(160, 388)
	add_child(ball)
	_objects_root = Node2D.new()
	_objects_root.name = "Objects"
	add_child(_objects_root)
	_ghost = Node2D.new()
	_ghost.modulate = Color(1, 1, 1, 0.5)
	_ghost.z_index = 20
	add_child(_ghost)
	_camera = Camera2D.new()
	_camera.zoom = Vector2(0.62, 0.62)
	_camera.position = Vector2(700, 360)
	add_child(_camera)
	_camera.make_current()

func _draw() -> void:
	var left := _camera.position.x - 1400.0 if _camera else -800.0
	var right := left + 2800.0
	for y: float in [LevelGenerator.TOP_Y, LevelGenerator.BOTTOM_Y]:
		draw_line(Vector2(left, y), Vector2(right, y), Color(1, 1, 1, 0.18), 2.0)
	draw_dashed_line(Vector2(left, 760), Vector2(right, 760), Color("FF6B6B", 0.5), 3.0, 18.0)
	var font := ThemeDB.fallback_font
	var start_m := int(floor(left / (WorldConst.METRE * 10.0)))
	for i in range(start_m, start_m + 50):
		var x := i * WorldConst.METRE * 10.0
		if x < 0.0:
			continue
		draw_line(Vector2(x, -10), Vector2(x, 30), Color(1, 1, 1, 0.35), 2.0)
		draw_string(font, Vector2(x + 6, 24), "%d m" % (i * 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.6))
	draw_rect(Rect2(Vector2(-200, -40), Vector2(MIN_X + 200, 820)), Color(0, 0, 0, 0.18))

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = THEME
	layer.add_child(root)
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 104
	top.add_theme_stylebox_override("panel", _box())
	top.mouse_entered.connect(func() -> void: _ui_hover = true)
	top.mouse_exited.connect(func() -> void: _ui_hover = false)
	root.add_child(top)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	top.add_child(rows)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	rows.add_child(bar)
	bar.add_child(_label("MAP BUILDER", 22, C_GOLD))
	_name_edit = LineEdit.new()
	_name_edit.name = "NameEdit"
	_name_edit.custom_minimum_size = Vector2(200, 38)
	_name_edit.max_length = 24
	_name_edit.placeholder_text = "Map name"
	_name_edit.text_changed.connect(func(t: String) -> void:
		map.name = t
		_dirty = true)
	bar.add_child(_name_edit)
	bar.add_child(_button("SAVE", save_map, "SaveButton"))
	_load_menu = OptionButton.new()
	_load_menu.name = "LoadMenu"
	_load_menu.custom_minimum_size = Vector2(190, 38)
	_load_menu.item_selected.connect(_on_load_selected)
	bar.add_child(_load_menu)
	bar.add_child(_button("DELETE", delete_map, "DeleteButton"))
	bar.add_child(_button("NEW", new_map, "NewButton"))
	bar.add_child(_button("CLEAR", clear_map, "ClearButton"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var play := _button("PLAY TEST", play_test, "PlayButton")
	play.theme_type_variation = &"BBPrimaryButton"
	bar.add_child(play)
	bar.add_child(_button("BACK", leave, "BackButton"))
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 4)
	rows.add_child(tools)
	for t: Dictionary in TOOLS:
		var b := Button.new()
		b.name = "Tool_" + String(t.k)
		b.text = String(t.name)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 34)
		b.add_theme_font_size_override("font_size", 13)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_select_tool.bind(String(t.k)))
		tools.add_child(b)
		_tool_buttons[String(t.k)] = b
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -40
	bottom.add_theme_stylebox_override("panel", _box())
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	var info := HBoxContainer.new()
	bottom.add_child(info)
	_status = _label("", 14, WorldConst.C_TEXT)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_status)
	_count_label = _label("", 14, C_GOLD)
	info.add_child(_count_label)
	_refresh_load_menu()

func _box() -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = C_PANEL
	b.set_content_margin_all(8)
	return b

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _button(text: String, cb: Callable, node_name: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_font_size_override("font_size", 15)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b

func _select_tool(k: String) -> void:
	tool = k
	for key: String in _tool_buttons:
		(_tool_buttons[key] as Button).set_pressed_no_signal(key == k)
	_ghost_key = ""
	_update_status()

func _update_status() -> void:
	var help := "Click: place   ·   Right click: delete   ·   A / D, arrows or wheel: scroll"
	if tool in ["spikes_low", "spikes_high"]:
		help += "   ·   Q / E: spikes in a row (%d)" % spike_count
	elif tool in ["low_wall", "hang_wall"]:
		help += "   ·   Mouse height sets wall height"
	_status.text = help
	var length := _finish_x() / WorldConst.METRE
	_count_label.text = "%d objects   ·   %d m long%s" % [(map.objects as Array).size(), length, "   ·   unsaved" if _dirty else ""]

func _finish_x() -> float:
	var fx := 0.0
	for obj: Dictionary in map.objects:
		fx = maxf(fx, float(obj.x) + (0.0 if obj.k == "finish" else LevelGenerator.FINISH_PAD))
	for obj: Dictionary in map.objects:
		if obj.k == "finish":
			return float(obj.x)
	return fx

func _process(delta: float) -> void:
	var dir := 0.0
	if not _name_edit.has_focus():
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			dir -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			dir += 1.0
	if dir != 0.0:
		_scroll(dir * SCROLL_SPEED * delta)
	_update_ghost()

func _scroll(amount: float) -> void:
	_camera.position.x = clampf(_camera.position.x + amount, 500.0, 60000.0)
	queue_redraw()

func _mouse_object() -> Dictionary:
	var m := get_global_mouse_position()
	var x := snappedf(m.x, SNAP.x)
	var y := clampf(snappedf(m.y, SNAP.y), 100.0, 640.0)
	var obj := {"k": tool, "x": x}
	match tool:
		"low_wall":
			obj.h = snappedf(clampf((LevelGenerator.BOTTOM_Y - y) / 256.0, 0.2, 1.0), 0.05)
		"hang_wall":
			obj.h = snappedf(clampf((y - LevelGenerator.TOP_Y) / 256.0, 0.2, 1.0), 0.05)
		"spikes_low", "spikes_high":
			obj.n = spike_count
		"finish":
			pass
		_:
			obj.y = y
	return obj

func _update_ghost() -> void:
	if tool == "erase" or _ui_hover:
		_ghost.visible = false
		return
	_ghost.visible = true
	var obj := _mouse_object()
	var key := JSON.stringify(obj)
	if key == _ghost_key:
		return
	_ghost_key = key
	for c in _ghost.get_children():
		c.free()
	var holder := _make_holder(obj)
	_ghost.add_child(holder)
	var ok := float(obj.x) >= MIN_X
	_ghost.modulate = Color(1, 1, 1, 0.5) if ok else Color(1, 0.3, 0.3, 0.45)

func _make_holder(obj: Dictionary) -> Node2D:
	var holder := Node2D.new()
	holder.position.x = float(obj.x)
	holder.process_mode = Node.PROCESS_MODE_DISABLED
	_gen.call("spawn_object", holder, obj)
	return holder

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if tool == "erase":
					erase_near(get_global_mouse_position())
				else:
					place(_mouse_object())
			MOUSE_BUTTON_RIGHT:
				erase_near(get_global_mouse_position())
			MOUSE_BUTTON_WHEEL_UP:
				_scroll(-160.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				_scroll(160.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_ESCAPE:
			leave()
		elif _name_edit.has_focus():
			return
		elif key == KEY_Q:
			spike_count = maxi(1, spike_count - 1)
			_ghost_key = ""
			_update_status()
		elif key == KEY_E:
			spike_count = mini(6, spike_count + 1)
			_ghost_key = ""
			_update_status()
		elif key == KEY_S and (event as InputEventKey).is_command_or_control_pressed():
			save_map()

func place(obj: Dictionary) -> bool:
	if float(obj.x) < MIN_X:
		AudioManager.play("deny")
		return false
	if obj.k == "finish":
		for i in range(_entries.size() - 1, -1, -1):
			if _entries[i].obj.k == "finish":
				_remove_entry(i)
	_add_entry(obj)
	_dirty = true
	AudioManager.play("place")
	_update_status()
	return true

func _add_entry(obj: Dictionary) -> void:
	var holder := _make_holder(obj)
	_objects_root.add_child(holder)
	_entries.append({"obj": obj, "node": holder})
	map.objects.append(obj)

func _anchor(obj: Dictionary) -> Vector2:
	match String(obj.k):
		"low_wall":
			return Vector2(obj.x, LevelGenerator.BOTTOM_Y - 128.0 * float(obj.h))
		"hang_wall":
			return Vector2(obj.x, LevelGenerator.TOP_Y + 128.0 * float(obj.h))
		"spikes_low":
			return Vector2(float(obj.x) + 31.0 * (int(obj.n) - 1), LevelGenerator.BOTTOM_Y - 30.0)
		"spikes_high":
			return Vector2(float(obj.x) + 31.0 * (int(obj.n) - 1), LevelGenerator.TOP_Y + 30.0)
		"finish":
			return Vector2(float(obj.x) + 60.0, 300.0)
	return Vector2(obj.x, obj.get("y", 360.0))

func erase_near(pos: Vector2) -> bool:
	var best := -1
	var best_d := 110.0
	for i in _entries.size():
		var d := _anchor(_entries[i].obj).distance_to(pos)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return false
	_remove_entry(best)
	_dirty = true
	AudioManager.play("expire")
	_update_status()
	return true

func _remove_entry(i: int) -> void:
	var entry: Dictionary = _entries[i]
	(entry.node as Node).queue_free()
	map.objects.erase(entry.obj)
	_entries.remove_at(i)

func _load_dict(data: Dictionary) -> void:
	for i in range(_entries.size() - 1, -1, -1):
		_remove_entry(i)
	map = {"name": String(data.get("name", "My Map")), "objects": []}
	for obj: Dictionary in data.get("objects", []):
		_add_entry(obj.duplicate())
	_name_edit.text = map.name
	_dirty = false
	_update_status()

func to_dict() -> Dictionary:
	return {"name": String(map.name), "objects": (map.objects as Array).duplicate(true)}

func save_map() -> void:
	if String(map.name).strip_edges().is_empty():
		map.name = "My Map"
		_name_edit.text = map.name
	var path := MapStore.save(to_dict())
	_dirty = path.is_empty()
	AudioManager.play("buy" if not path.is_empty() else "deny")
	_refresh_load_menu(path)
	_update_status()

func _refresh_load_menu(select := "") -> void:
	_load_menu.clear()
	_load_menu.add_item("LOAD MAP...")
	_load_menu.set_item_metadata(0, "")
	var i := 1
	for path: String in MapStore.list():
		_load_menu.add_item(path.get_file().get_basename().replace("_", " "))
		_load_menu.set_item_metadata(i, path)
		if path == select:
			_load_menu.select(i)
		i += 1

func _on_load_selected(index: int) -> void:
	var path := String(_load_menu.get_item_metadata(index))
	if path.is_empty():
		return
	var data := MapStore.load_map(path)
	if data.is_empty():
		AudioManager.play("deny")
		return
	_load_dict(data)
	AudioManager.play("click")

func delete_map() -> void:
	var path := String(_load_menu.get_item_metadata(_load_menu.selected)) if _load_menu.selected >= 0 else ""
	if path.is_empty():
		AudioManager.play("deny")
		return
	MapStore.remove(path)
	AudioManager.play("expire")
	_refresh_load_menu()

func new_map() -> void:
	AudioManager.play("click")
	_load_dict({"name": "My Map", "objects": [{"k": "finish", "x": 4200}]})
	_load_menu.select(0)

func clear_map() -> void:
	AudioManager.play("click")
	var keep_name := String(map.name)
	_load_dict({"name": keep_name, "objects": []})
	_dirty = true

func play_test() -> void:
	AudioManager.play("go")
	if (map.objects as Array).size() > 0:
		MapStore.save(to_dict())
	GameManager.play_map(to_dict(), true)

func leave() -> void:
	AudioManager.play("click")
	if _dirty and (map.objects as Array).size() > 0:
		MapStore.save(to_dict())
	GameManager.go_to_menu()
