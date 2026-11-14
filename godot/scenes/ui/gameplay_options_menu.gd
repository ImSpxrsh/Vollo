extends MarginContainer

@onready var shake_slider: HSlider = %ShakeSlider
@onready var shake_value: Label = %ShakeValue
@onready var hitstop_toggle: CheckButton = %HitstopToggle
@onready var contrast_toggle: CheckButton = %ContrastToggle
@onready var motion_toggle: CheckButton = %MotionToggle

func _ready() -> void:
	load_from_save()
	shake_slider.value_changed.connect(_on_shake_changed)
	shake_slider.drag_ended.connect(func(_changed: bool) -> void: save())
	hitstop_toggle.toggled.connect(_on_hitstop_toggled)
	contrast_toggle.toggled.connect(_on_accessibility_toggled)
	motion_toggle.toggled.connect(_on_accessibility_toggled)

func load_from_save() -> void:
	shake_slider.set_value_no_signal(roundf(SaveManager.screen_shake_intensity * 100.0))
	hitstop_toggle.set_pressed_no_signal(SaveManager.hitstop_enabled)
	contrast_toggle.set_pressed_no_signal(SaveManager.high_contrast_hazards)
	motion_toggle.set_pressed_no_signal(SaveManager.reduce_motion)
	_refresh_label()

func _refresh_label() -> void:
	shake_value.text = "%d %%" % int(shake_slider.value)

func _on_shake_changed(_value: float) -> void:
	_refresh_label()
	SaveManager.screen_shake_intensity = shake_slider.value / 100.0
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		save()

func _on_hitstop_toggled(_on: bool) -> void:
	save()

func _on_accessibility_toggled(_on: bool) -> void:
	SaveManager.set_accessibility_settings(contrast_toggle.button_pressed, motion_toggle.button_pressed)

func save() -> void:
	SaveManager.set_gameplay_settings(shake_slider.value / 100.0, hitstop_toggle.button_pressed)

func _exit_tree() -> void:
	save()
