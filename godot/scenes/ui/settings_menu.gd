extends PopupWindowSceneContainer

func _ready() -> void:
	super._ready()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tabs := get_tabs()
	if tabs:
		tabs.current_tab = 0

func get_tabs() -> TabContainer:
	return instance as TabContainer

func get_gameplay_menu() -> Node:
	var tabs := get_tabs()
	return tabs.get_node_or_null(^"Gameplay") if tabs else null

func save_settings() -> void:
	var gameplay := get_gameplay_menu()
	if gameplay and gameplay.has_method(&"save"):
		gameplay.save()
	SaveManager.save_data()

func close() -> void:
	if is_opened and not is_reparenting:
		save_settings()
		AudioManager.play("click")
	super.close()
