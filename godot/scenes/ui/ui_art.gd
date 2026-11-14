class_name UiArt

const BACKDROP_NIGHT := "res://assets/background_mountain_farm.png"
const ICON_TRAMPOLINE := "res://assets/icon_trampoline.png"
const ICON_RAMP := "res://assets/icon_ramp.png"
const BALL_DEAD := "res://assets/ball_dead.png"

const SPRITES_DIR := "res://assets/sprites/"
const ART_DIR := "res://assets/art/"
const SLOT_IDLE := ART_DIR + "slot_idle.png"
const SLOT_SELECTED := ART_DIR + "slot_selected.png"
const ICON_TRAMPOLINE_UI := ART_DIR + "icon_trampoline.png"
const ICON_RAMP_UI := ART_DIR + "icon_ramp.png"
const ICON_WALL_UI := ART_DIR + "icon_wall.png"
const ICON_FLOOR_UI := ART_DIR + "floor.png"
const COOLDOWN_BAR := ART_DIR + "cooldown_bar.png"
const KEYCAP_SPACE := ART_DIR + "keycap_space.png"
const DISTANCE_BADGE := ART_DIR + "distance_badge.png"
const GAME_OVER_PANEL := ART_DIR + "game_over_panel.png"
const COIN := ART_DIR + "coin.png"
const SLOWMO_CLOCK := ART_DIR + "slowmo_clock.png"
const SPEED_BOOSTER := ART_DIR + "speed_booster.png"
const SHIELD := ART_DIR + "shield_pickup.png"
const MANIFEST := SPRITES_DIR + "manifest.json"

static var _cache := {}
static var _manifest: Variant = null

static func keycap(n: int) -> String:
	return ART_DIR + "keycap_%d.png" % n

static func load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null and FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	_cache[path] = tex
	return tex

static func has_texture(path: String) -> bool:
	return load_texture(path) != null

static func first_texture(paths: Array) -> Texture2D:
	for p in paths:
		var t := load_texture(String(p))
		if t:
			return t
	return null

static func nine_slice_margins(path: String, fallback := 16) -> Array:
	var out: Array = [fallback, fallback, fallback, fallback]
	var entry := _manifest_entry(path.get_file())
	if entry.is_empty():
		return out
	for k in entry.keys():
		var key := String(k).to_lower()
		if not (key.contains("slice") or key.contains("patch") or key.contains("margin")):
			continue
		var v: Variant = entry[k]
		if v is float or v is int:
			var m := int(v)
			return [m, m, m, m]
		if v is Array and v.size() >= 4:
			return [int(v[0]), int(v[1]), int(v[2]), int(v[3])]
		if v is Array and v.size() == 2:
			return [int(v[0]), int(v[1]), int(v[0]), int(v[1])]
		if v is Dictionary:
			var d: Dictionary = v
			return [int(d.get("left", fallback)), int(d.get("top", fallback)), int(d.get("right", fallback)), int(d.get("bottom", fallback))]
	return out

static func _manifest_entry(file_name: String) -> Dictionary:
	if _manifest == null:
		_manifest = {}
		if FileAccess.file_exists(MANIFEST):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
			if parsed != null:
				_manifest = parsed
	var stem := file_name.get_basename()
	return _find_entry(_manifest, file_name, stem)

static func _find_entry(node: Variant, file_name: String, stem: String) -> Dictionary:
	if node is Dictionary:
		for k in node.keys():
			var key := String(k)
			if (key == file_name or key == stem) and node[k] is Dictionary:
				return node[k]
		for k in ["file", "name", "path", "filename"]:
			if node.has(k) and String(node[k]).get_file() in [file_name, stem]:
				return node
		for v in node.values():
			var found := _find_entry(v, file_name, stem)
			if not found.is_empty():
				return found
	elif node is Array:
		for v in node:
			var found := _find_entry(v, file_name, stem)
			if not found.is_empty():
				return found
	return {}

static func nine_patch(path: String, fallback := 16) -> NinePatchRect:
	var tex := load_texture(path)
	if tex == null:
		return null
	var n := NinePatchRect.new()
	n.texture = tex
	var m := nine_slice_margins(path, fallback)
	var half := Vector2i(tex.get_size()) / 2
	n.patch_margin_left = mini(m[0], half.x)
	n.patch_margin_top = mini(m[1], half.y)
	n.patch_margin_right = mini(m[2], half.x)
	n.patch_margin_bottom = mini(m[3], half.y)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n
