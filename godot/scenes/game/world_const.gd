class_name WorldConst

const GROUND_Y := 460.0
const METRE := 64.0
const LAYER_WORLD := 1
const LAYER_BALL := 2
const LAYER_HAZARD := 4
const LAYER_PICKUPS := 8
const LAYER_PIECES := [32, 64]
const VISIBILITY_PRIVATE := [2, 4]

static func set_visibility_recursive(node: Node, layer: int) -> void:
	if node is CanvasItem:
		(node as CanvasItem).visibility_layer = layer
	for child in node.get_children(true):
		set_visibility_recursive(child, layer)

const C_BG := Color("6E9B45")
const C_PANEL := Color(0.36, 0.18, 0.07, 0.94)
const C_ACCENT := Color("53A548")
const C_HAZARD := Color("D93B2B")
const C_RAMP := Color("FFD166")
const C_WALL := Color("8C6A45")
const C_TEXT := Color("FFE5A8")
const C_DIM := Color("C49A68")
