extends CanvasLayer

@onready var panel: Control = $Panel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.hide()
	panel.closed.connect(_on_panel_closed)
	GameManager.state_changed.connect(_on_state_changed)

func is_open() -> bool:
	return panel.visible

func open_menu() -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	GameManager.pause()
	if GameManager.state == GameManager.State.PAUSED:
		AudioManager.play("click")
		panel.show()

func close_menu() -> void:
	if panel.visible:
		panel.close()
	elif GameManager.state == GameManager.State.PAUSED:
		GameManager.resume()

func toggle() -> void:
	if GameManager.state == GameManager.State.PLAYING:
		open_menu()
	elif GameManager.state == GameManager.State.PAUSED:
		if panel.has_method(&"has_open_window") and panel.has_open_window():
			return
		close_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if GameManager.state in [GameManager.State.PLAYING, GameManager.State.PAUSED]:
			toggle()
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree() and GameManager.state == GameManager.State.PLAYING:
		open_menu()

func _on_panel_closed() -> void:
	if GameManager.state == GameManager.State.PAUSED:
		GameManager.resume()

func _on_state_changed(state: GameManager.State) -> void:
	if state != GameManager.State.PAUSED and panel.visible:
		panel.hide()
