extends CanvasLayer

const FADE_TIME := 0.25

var _rect: ColorRect
var _busy := false
var _queued: Callable

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0.0509804, 0.0588235, 0.0784314, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)

func change_scene(path: String) -> void:
	_transition(func() -> void: get_tree().change_scene_to_file(path))

func reload_scene() -> void:
	_transition(func() -> void: get_tree().reload_current_scene())

func _transition(swap: Callable) -> void:
	if _busy:
		_queued = swap
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	t.tween_property(_rect, "color:a", 1.0, FADE_TIME)
	await t.finished
	get_tree().paused = false
	Engine.time_scale = 1.0
	swap.call()
	await get_tree().process_frame
	await get_tree().process_frame
	var t2 := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	t2.tween_property(_rect, "color:a", 0.0, FADE_TIME)
	await t2.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	if _queued.is_valid():
		var next := _queued
		_queued = Callable()
		_transition(next)
