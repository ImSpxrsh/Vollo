extends "res://addons/maaacks_menus_template/base/nodes/menus/options_menu/paginated_tab_container.gd"

@export var force_show_controls := false
@export var show_input_sensitivity := false

func _ready():
	var inputs_actions := AppSettings.get_action_names()
	for iter in range(get_tab_count()):
		if get("tab_%d/title" % iter) == "Controls":
			set("tab_%d/hidden" % iter, inputs_actions.is_empty() and not force_show_controls)
			continue
		if get("tab_%d/title" % iter) == "Inputs":
			set("tab_%d/hidden" % iter, not show_input_sensitivity)
			continue
