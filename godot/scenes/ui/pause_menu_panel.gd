extends "res://scenes/windows/pause_menu.gd"

@onready var restart_button: Button = menu_buttons.get_node(^"RestartButton")

func _ready() -> void:
	super._ready()
	title_label.text = "PAUSED"
	title_label.theme_type_variation = &"BBHeading"
	close_button.text = "RESUME"
	close_button.theme_type_variation = &"BBPrimaryButton"
	restart_button.text = "RESTART"
	options_button.text = "SETTINGS"
	main_menu_button.text = "MAIN MENU"
	for b: Button in [close_button, restart_button, options_button, main_menu_button]:
		b.custom_minimum_size = Vector2(0, 50)
		b.focus_mode = Control.FOCUS_ALL

func _refresh_exit_button() -> void:
	exit_button.visible = false

func _on_restart_button_pressed() -> void:
	AudioManager.play("click")
	GameManager.restart_run()

func _on_main_menu_button_pressed() -> void:
	AudioManager.play("click")
	GameManager.go_to_menu()

func _on_options_button_pressed() -> void:
	AudioManager.play("click")
	super._on_options_button_pressed()

func has_open_window() -> bool:
	return open_window != null
