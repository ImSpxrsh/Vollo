class_name MapStore
extends RefCounted

const DIR := "user://maps"

static var editing: Dictionary = {}

# The tutorial plays like a real run: after the start platform there is no
# ground, only open air, hazards and the odd rest bridge. Every lesson starts on
# a bridge (its checkpoint), slows time while the card explains, and freezes
# time at each step's "hold" x until the player builds the glowing piece.
# Item ids: 0 trampoline, 1 ramp, 2 floor. Lane: bridges/floors have their top
# at y 460, so the ball rolls at y 428.
const TUTORIAL := {
	"name": "Tutorial",
	"objects": [
		# FLOOR: the start platform ends at x 870.
		{"k": "coin", "x": 980, "y": 420}, {"k": "coin", "x": 1080, "y": 420}, {"k": "coin", "x": 1180, "y": 420},
		{"k": "bridge", "x": 1405, "y": 460},
		# TRAMPOLINE + CATCH: a red wall in the gap.
		{"k": "low_wall", "x": 1910, "h": 1.0},
		{"k": "coin", "x": 1610, "y": 193}, {"k": "coin", "x": 1710, "y": 108}, {"k": "coin", "x": 1810, "y": 93},
		{"k": "coin", "x": 2010, "y": 274},
		{"k": "bridge", "x": 2330, "y": 460},
		# RAMP: small spikes in the gap.
		{"k": "spikes_low", "x": 2640, "n": 2, "gy": 520},
		{"k": "coin", "x": 2560, "y": 320}, {"k": "coin", "x": 2660, "y": 300}, {"k": "coin", "x": 2760, "y": 350},
		{"k": "bridge", "x": 3070, "y": 460},
		# FLIP: a wall hanging from the sky.
		{"k": "hang_wall", "x": 3600, "h": 1.0},
		{"k": "coin", "x": 3240, "y": 228}, {"k": "coin", "x": 3420, "y": 300},
		{"k": "bridge", "x": 3775, "y": 460},
		# STOMP: a devil ball waiting in the air.
		{"k": "enemy", "x": 4405, "y": 350, "bob": 0.0},
		{"k": "coin", "x": 4035, "y": 193}, {"k": "coin", "x": 4135, "y": 108}, {"k": "coin", "x": 4235, "y": 93},
		{"k": "coin", "x": 4655, "y": 150}, {"k": "coin", "x": 4815, "y": 200},
		{"k": "bridge", "x": 5240, "y": 460},
		# ON YOUR OWN: lay floors yourself and grab the power-ups.
		{"k": "coin", "x": 5560, "y": 420}, {"k": "coin", "x": 5660, "y": 420},
		{"k": "shield", "x": 5820, "y": 415},
		{"k": "coin", "x": 5980, "y": 420}, {"k": "coin", "x": 6080, "y": 420},
		{"k": "slowmo", "x": 6240, "y": 415},
		{"k": "coin", "x": 6400, "y": 420},
		{"k": "booster", "x": 6560, "y": 420},
		{"k": "bridge", "x": 6880, "y": 460},
		# CLUTCH + COMBO: bounce right next to spikes, twice.
		{"k": "spikes_low", "x": 7130, "n": 2, "gy": 520},
		{"k": "spikes_low", "x": 7680, "n": 2, "gy": 520},
		{"k": "coin", "x": 7240, "y": 108}, {"k": "coin", "x": 7340, "y": 93},
		{"k": "coin", "x": 7860, "y": 108}, {"k": "coin", "x": 7960, "y": 93},
		{"k": "bridge", "x": 8420, "y": 460},
		{"k": "finish", "x": 8480},
	],
}

const TUTORIAL_LESSONS := [
	{"title": "WELCOME", "cp": 160, "at": 0, "keys": true,
		"text": "Voll rolls by itself and you can't steer it. Past this platform there is NO ground: whatever it rolls on, you build.",
		"after_card": "1 TRAMPOLINE bounces  ·  2 RAMP hops  ·  3 FLOOR catches.\nIn real runs, every hit or fall costs a heart (top-left): lose all 3 and the run ends. Here, a mistake just rewinds.",
		"after_speed": 0.3},
	{"title": "FLOOR", "cp": 600, "at": 560, "done": 1300,
		"text": "The platform ends! Build a road over the gap.",
		"steps": [
			{"item": 2, "pos": Vector2(975, 471), "hold": 790, "tip": "Click the glowing FLOOR right at the edge"},
			{"item": 2, "pos": Vector2(1185, 471), "hold": 990, "tip": "One more FLOOR to reach the bridge"},
		],
		"after": "Pieces crumble after a few seconds: keep building ahead!"},
	{"title": "TRAMPOLINE", "cp": 1350, "at": 1330, "done": 2230,
		"text": "A red wall! Walls, spikes and devil balls hurt. Bounce over the wall, then catch yourself.",
		"steps": [
			{"item": 0, "pos": Vector2(1564, 439), "hold": 1440, "tip": "Put the TRAMPOLINE at the end of the bridge"},
			{"item": 2, "pos": Vector2(2110, 471), "hold": 1640, "tip": "Catch it! Put a FLOOR where it will land"},
		],
		"after": "Bounce, then catch: that's the rhythm of Voll!"},
	{"title": "RAMP", "cp": 2275, "at": 2250, "done": 2965,
		"text": "Small spikes in the gap. A RAMP gives a quick, low hop: lighter than a trampoline.",
		"steps": [
			{"item": 1, "pos": Vector2(2531, 419), "hold": 2380, "flip": false, "tip": "Put the RAMP at the end of the bridge"},
			{"item": 2, "pos": Vector2(2850, 471), "hold": 2520, "tip": "Catch it with a FLOOR past the spikes"},
		],
		"after": "Ramps for small hops, trampolines for big ones."},
	{"title": "FLIP THE RAMP", "cp": 3010, "at": 2990, "done": 3700,
		"text": "A wall hangs from the sky! Your bounce would hit it. Press R to FLIP a ramp: a flipped ramp knocks the ball DOWN.",
		"steps": [
			{"item": 0, "pos": Vector2(3239, 439), "hold": 3120, "tip": "TRAMPOLINE at the end of the bridge"},
			{"item": 1, "pos": Vector2(3305, 72), "hold": 3240, "flip": true, "tip": "Click the glowing FLIPPED RAMP above the ball"},
			{"item": 2, "pos": Vector2(3560, 471), "hold": 3340, "tip": "Catch it with a FLOOR under the wall"},
		],
		"after": "Flipped ramps push you down. R flips back and forth."},
	{"title": "STOMP", "cp": 3720, "at": 3700, "done": 5140,
		"text": "A devil ball! Touching its side hurts, but landing ON TOP stomps it and bounces you high.",
		"steps": [
			{"item": 0, "pos": Vector2(3944, 439), "hold": 3835, "tip": "TRAMPOLINE at the end of the bridge to land on it"},
			{"item": 2, "pos": Vector2(5025, 471), "hold": 4475, "tip": "Stomped! Now catch yourself with a FLOOR"},
		],
		"after": "Stomped! Bonus metres. Grumpy balls can be stomped too."},
	{"title": "ON YOUR OWN", "cp": 5180, "at": 5160, "done": 6790, "free": true,
		"text": "No glowing spots now. Keep laying FLOORS ahead of the ball until the next bridge, and grab the power-ups!",
		"prompt": "SHIELD blocks one hit  ·  CLOCK slows time  ·  BOOSTER = speed, can't be hurt",
		"after": "You built that yourself! The ghost shows each piece's cooldown."},
	{"title": "CLUTCH & COMBO", "cp": 6810, "at": 6790, "done": 8140,
		"text": "Bouncing right next to danger is a CLUTCH: bonus metres! Chain clutches within 3 seconds for a COMBO, up to x5.",
		"steps": [
			{"item": 0, "pos": Vector2(7049, 439), "hold": 6930, "tip": "TRAMPOLINE at the end of the bridge, close to the spikes"},
			{"item": 0, "pos": Vector2(7600, 439), "hold": 7150, "tip": "Another TRAMPOLINE where it lands, for a combo"},
			{"item": 2, "pos": Vector2(8200, 471), "hold": 7720, "tip": "Catch it with a FLOOR"},
		],
		"after": "COMBO! Your combo multiplies clutch and stomp bonuses."},
	{"title": "FINISH", "cp": 6810, "at": 8150, "free": true, "speed": 0.4,
		"text": "Your score is metres travelled plus bonuses. Coins buy upgrades in the SHOP, and every 60 m is a new level. Esc or P pauses.\nRoll through the FINISH flag!"},
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
