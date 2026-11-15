class_name MapStore
extends RefCounted

const DIR := "user://maps"

static var editing: Dictionary = {}

const TUTORIAL := {
	"name": "Tutorial",
	"objects": [
		{"k": "ground", "x": 1290, "w": 1410},
		{"k": "low_wall", "x": 2050, "h": 0.55, "gy": 460},
		{"k": "ground", "x": 2930, "w": 1450},
		{"k": "enemy", "x": 3990, "y": 405},
		{"k": "coin", "x": 4570, "y": 420}, {"k": "coin", "x": 4730, "y": 420}, {"k": "coin", "x": 4890, "y": 420},
		{"k": "coin", "x": 5050, "y": 420}, {"k": "coin", "x": 5210, "y": 420},
		{"k": "ground", "x": 5490, "w": 1400},
		{"k": "spikes_low", "x": 6110, "n": 2, "gy": 460},
		{"k": "finish", "x": 6690},
	],
}

const TUTORIAL_LESSONS := [
	{"title": "WELCOME", "cp": 160, "at": 0, "done": 520, "item": -1,
		"text": "Your ball rolls on its own and you can't steer it.\nYour job is to BUILD the path in front of it."},
	{"title": "FLOOR", "cp": 300, "at": 560, "done": 1330, "item": 2,
		"targets": [Vector2(975, 471), Vector2(1185, 471)],
		"text": "The road ends here! Fill the gap with floors.",
		"after": "Pieces crumble after a few seconds, so always build ahead."},
	{"title": "TRAMPOLINE", "cp": 1420, "at": 1600, "done": 2150, "item": 0,
		"targets": [Vector2(1860, 439)],
		"text": "Red walls cost a heart. Put a trampoline in front of it to bounce over.",
		"after": "Boing! Trampolines are your jump button."},
	{"title": "RAMP", "cp": 2200, "at": 2330, "done": 3020, "item": 1,
		"targets": [Vector2(2650, 419)],
		"text": "A wide gap! Put a ramp at the edge to launch across in one go.",
		"after": "Tip: press R to flip a ramp so it slopes down."},
	{"title": "STOMP", "cp": 3070, "at": 3170, "done": 4150, "item": 0,
		"targets": [Vector2(3490, 439)],
		"text": "A devil ball! Its sides hurt, but landing ON it stomps it. Bounce onto it.",
		"after": "Stomped! Stomps give bonus metres."},
	{"title": "ON YOUR OWN", "cp": 4100, "at": 4180, "done": 5520, "item": 2, "free": true,
		"text": "No help this time: keep laying floors until you reach land. Grab the coins!",
		"after": "You built that yourself. That's the whole game!"},
	{"title": "CLUTCH", "cp": 5570, "at": 5650, "done": 6290, "item": 0,
		"targets": [Vector2(6000, 439)],
		"text": "Spikes! Bounce right before them. Bouncing close to danger is a CLUTCH for bonus metres.",
		"after": "Clutch! Coins buy upgrades in the SHOP."},
	{"title": "FINISH", "cp": 6310, "at": 6340, "done": 99999, "item": -1,
		"text": "Roll through the FINISH flag to complete the tutorial!"},
]

static func safe_name(map_name: String) -> String:
	var out := ""
	for ch in map_name.strip_edges():
		out += ch if (ch.is_valid_identifier() or ch.is_valid_int() or ch == "-") else "_"
	return out.left(32) if not out.is_empty() else "untitled"

static func save(map: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := "%s/%s.json" % [DIR, safe_name(String(map.get("name", "untitled")))]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(map, "\t"))
	f.close()
	return path

static func load_map(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("objects"):
		return {}
	return parsed

static func list() -> Array:
	var out: Array = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		if file.ends_with(".json"):
			out.append("%s/%s" % [DIR, file])
	out.sort()
	return out

static func remove(path: String) -> void:
	DirAccess.remove_absolute(path)
