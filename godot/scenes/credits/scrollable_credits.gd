@tool
extends Control

const PITCH_VIDEO := "res://assets/video/team_pitch.ogv"
const SPLIT_AT := "[font_size=32]Art[/font_size]"
const CAPTION := "[font_size=20]The team pitching together at NJX[/font_size]\n"

@onready var credits_label : RichTextLabel = %CreditsLabel

@export var input_scroll_speed : float = 10.0

var _scroll: ScrollContainer
var _video: VideoStreamPlayer

func _on_visibility_changed() -> void:
	await draw
	if is_visible_in_tree():
		if _scroll:
			_scroll.scroll_vertical = 0
		if _video and not _video.is_playing():
			_video.play()
		if credits_label.is_inside_tree():
			credits_label.grab_focus()

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	if not Engine.is_editor_hint():
		_build_layout()

func _build_layout() -> void:
	var text := credits_label.text
	var cut := text.find(SPLIT_AT)
	if cut < 0:
		return
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	_scroll.add_child(column)
	remove_child(credits_label)
	credits_label.fit_content = true
	credits_label.scroll_active = false
	credits_label.set("auto_update", false)
	var rest := credits_label.duplicate() as RichTextLabel
	credits_label.text = text.left(cut)
	rest.text = text.substr(cut)
	column.add_child(credits_label)
	if ResourceLoader.exists(PITCH_VIDEO):
		_video = VideoStreamPlayer.new()
		_video.name = "PitchVideo"
		_video.stream = load(PITCH_VIDEO)
		_video.expand = true
		_video.loop = true
		_video.autoplay = true
		_video.volume_db = -80.0
		_video.custom_minimum_size = Vector2(480, 270)
		_video.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(_video)
		var caption := rest.duplicate() as RichTextLabel
		caption.text = CAPTION
		column.add_child(caption)
	column.add_child(rest)

func _process(delta : float) -> void:
	if Engine.is_editor_hint() or not visible or _scroll == null:
		return
	var input_axis = Input.get_axis("ui_up", "ui_down")
	if abs(input_axis) > 0.5:
		_scroll.scroll_vertical += int(input_axis * delta * input_scroll_speed * 60.0)
