extends Node

signal settings_changed
signal variety_unlocked(variety_id: String, display_name: String)
signal award_earned(award_id: String, award_name: String, variety_id: String)
## Emitted after every save to disk; the account sync uploads a moment later.
signal progress_saved

const SAVE_PATH := "user://save_data.cfg"
const UPGRADES := [
	{"id": "head_start", "name": "Head Start", "desc": "Begin every run inside a shield bubble", "cost": 40, "icon": "res://assets/art/shield_pickup.png"},
	{"id": "long_life", "name": "Sturdy Pieces", "desc": "Placed pieces last 5 s instead of 4", "cost": 50, "icon": "res://assets/art/floor.png"},
	{"id": "quick_hands", "name": "Quick Hands", "desc": "Piece cooldowns are 20% shorter", "cost": 60, "icon": "res://assets/art/keycap_1.png"},
	{"id": "magnet", "name": "Coin Magnet", "desc": "Nearby coins fly to you", "cost": 70, "icon": "res://assets/art/coin.png"},
	{"id": "extra_heart", "name": "Extra Heart", "desc": "Start runs with 4 hearts instead of 3", "cost": 90, "icon": "res://assets/art/variety_pink.png"},
]
const VARIETIES := [
	{"id": "yellow", "name": "YELLOW", "color": Color("FFD02A"), "award": ""},
	{"id": "orange", "name": "ORANGE", "color": Color("FF8A1C"), "award": "first_steps"},
	{"id": "lime", "name": "LIME", "color": Color("A7E52C"), "award": "spring_loaded"},
	{"id": "green", "name": "GREEN", "color": Color("39BE62"), "award": "pocket_change"},
	{"id": "teal", "name": "TEAL", "color": Color("22B6AA"), "award": "stomper"},
	{"id": "cyan", "name": "CYAN", "color": Color("2BC4E5"), "award": "long_roll"},
	{"id": "sky_blue", "name": "SKY BLUE", "color": Color("72B5F0"), "award": "combo_artist"},
	{"id": "blue", "name": "BLUE", "color": Color("3473DE"), "award": "close_call"},
	{"id": "pink", "name": "PINK", "color": Color("F276B5"), "award": "sweet_tooth"},
	{"id": "brown", "name": "BROWN", "color": Color("A36B3F"), "award": "never_give_up"},
	{"id": "gray", "name": "GRAY", "color": Color("9EA8B8"), "award": "level_five"},
	{"id": "white", "name": "WHITE", "color": Color("F1F2F4"), "award": "legend"},
]
const AWARDS := [
	{"id": "first_steps", "name": "First Steps", "desc": "Roll 25 m in one run", "stat": "best_distance", "target": 25},
	{"id": "spring_loaded", "name": "Spring Loaded", "desc": "Bounce 25 times in total", "stat": "total_bounces", "target": 25},
	{"id": "pocket_change", "name": "Pocket Change", "desc": "Collect 30 coins in total", "stat": "total_coins", "target": 30},
	{"id": "stomper", "name": "Stomper", "desc": "Bounce 5 enemies away in total", "stat": "total_stomps", "target": 5},
	{"id": "long_roll", "name": "Long Roll", "desc": "Roll 120 m in one run", "stat": "best_distance", "target": 120},
	{"id": "combo_artist", "name": "Combo Artist", "desc": "Hit a x3 clutch combo", "stat": "best_combo", "target": 3},
	{"id": "close_call", "name": "Close Call", "desc": "Let a shield save you 3 times", "stat": "total_shield_saves", "target": 3},
	{"id": "sweet_tooth", "name": "Sweet Tooth", "desc": "Collect 20 coins in one run", "stat": "best_run_coins", "target": 20},
	{"id": "never_give_up", "name": "Never Give Up", "desc": "Finish 20 runs", "stat": "runs_played", "target": 20},
	{"id": "level_five", "name": "Level Five", "desc": "Reach level 5 in one run", "stat": "best_level", "target": 5},
	{"id": "legend", "name": "Legend", "desc": "Roll 400 m in one run", "stat": "best_distance", "target": 400},
]
const STAT_KEYS := ["total_bounces", "total_coins", "total_stomps", "total_shield_saves", "runs_played",
		"best_distance", "best_combo", "best_run_coins", "best_level", "tutorial_done", "maps_cleared"]

var high_score := 0
var total_bounces := 0
var total_stars := 0
var stats := {}
var earned_awards: Array[String] = []
var coins_spent := 0
var upgrades: Array[String] = []
var unlocked_varieties: Array[String] = ["yellow"]
var selected_variety := "yellow"
var new_variety_unlocks: Array[String] = []
var run_awards: Array[String] = []
var screen_shake_intensity := 1.0
var hitstop_enabled := true
var high_contrast_hazards := false
var reduce_motion := false
var hotbar_hidden := false

var master_volume: float:
	get: return _bus_volume("Master")
	set(v): _set_bus_volume("Master", v)
var sfx_volume: float:
	get: return _bus_volume("SFX")
	set(v): _set_bus_volume("SFX", v)
var music_volume: float:
	get: return _bus_volume("Music")
	set(v): _set_bus_volume("Music", v)
var fullscreen: bool:
	get: return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	set(v): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v else DisplayServer.WINDOW_MODE_WINDOWED)

func _init() -> void:
	_clear_stats()

func _ready() -> void:
	load_data()

func _clear_stats() -> void:
	for key: String in STAT_KEYS:
		stats[key] = 0

func begin_run() -> void:
	run_awards.clear()

func record_run(distance: int, bounces: int, stars := 0, extra := {}) -> void:
	high_score = maxi(high_score, distance)
	total_bounces += bounces
	total_stars += stars
	stats.total_bounces = total_bounces
	stats.total_coins = total_stars
	stats.total_stomps = int(stats.total_stomps) + int(extra.get("stomps", 0))
	stats.total_shield_saves = int(stats.total_shield_saves) + int(extra.get("shield_saves", 0))
	stats.runs_played = int(stats.runs_played) + 1
	stats.best_distance = maxi(int(stats.best_distance), distance)
	stats.best_combo = maxi(int(stats.best_combo), int(extra.get("combo", 0)))
	stats.best_run_coins = maxi(int(stats.best_run_coins), stars)
	stats.best_level = maxi(int(stats.best_level), int(extra.get("level", 0)))
	_check_awards(stats, true)
	save_data()

func check_live_awards(live: Dictionary) -> void:
	var view := stats.duplicate()
	view.total_bounces = total_bounces + int(live.get("bounces", 0))
	view.total_coins = total_stars + int(live.get("coins", 0))
	view.total_stomps = int(stats.total_stomps) + int(live.get("stomps", 0))
	view.total_shield_saves = int(stats.total_shield_saves) + int(live.get("shield_saves", 0))
	view.best_distance = maxi(int(stats.best_distance), int(live.get("distance", 0)))
	view.best_combo = maxi(int(stats.best_combo), int(live.get("combo", 0)))
	view.best_run_coins = maxi(int(stats.best_run_coins), int(live.get("coins", 0)))
	view.best_level = maxi(int(stats.best_level), int(live.get("level", 0)))
	if _check_awards(view, true):
		save_data()

func _check_awards(view: Dictionary, notify: bool) -> bool:
	var changed := false
	for award: Dictionary in AWARDS:
		var id := String(award.id)
		if earned_awards.has(id) or int(view.get(award.stat, 0)) < int(award.target):
			continue
		earned_awards.append(id)
		changed = true
		var variety := variety_for_award(id)
		if notify:
			run_awards.append(id)
		if not variety.is_empty() and not unlocked_varieties.has(variety):
			unlocked_varieties.append(variety)
			if notify:
				new_variety_unlocks.append(variety)
				variety_unlocked.emit(variety, get_variety_name(variety))
		if notify:
			award_earned.emit(id, String(award.name), variety)
	return changed

func get_award(award_id: String) -> Dictionary:
	for award: Dictionary in AWARDS:
		if String(award.id) == award_id:
			return award
	return {}

func has_award(award_id: String) -> bool:
	return earned_awards.has(award_id)

func award_progress(award_id: String) -> float:
	var award := get_award(award_id)
	if award.is_empty():
		return 1.0
	if has_award(award_id):
		return 1.0
	return clampf(float(stats.get(award.stat, 0)) / float(award.target), 0.0, 1.0)

func award_progress_text(award_id: String) -> String:
	var award := get_award(award_id)
	if award.is_empty():
		return ""
	var value := mini(int(stats.get(award.stat, 0)), int(award.target))
	if has_award(award_id):
		value = int(award.target)
	return "%d / %d" % [value, int(award.target)]

func variety_for_award(award_id: String) -> String:
	for data: Dictionary in VARIETIES:
		if String(data.award) == award_id:
			return String(data.id)
	return ""

func get_variety(variety_id: String) -> Dictionary:
	for data: Dictionary in VARIETIES:
		if String(data.id) == variety_id:
			return data
	return VARIETIES[0]

func get_variety_color(variety_id := selected_variety) -> Color:
	return get_variety(variety_id).color as Color

func get_variety_name(variety_id: String) -> String:
	return String(get_variety(variety_id).name)

func get_variety_texture_path(variety_id := selected_variety, dead := false) -> String:
	return "res://assets/art/variety_%s%s.png" % [String(get_variety(variety_id).id), "_dead" if dead else ""]

func get_variety_requirement(variety_id: String) -> String:
	var award := get_award(String(get_variety(variety_id).award))
	if award.is_empty():
		return "Starter variety"
	return "Award: %s — %s" % [award.name, award.desc]

func is_variety_unlocked(variety_id: String) -> bool:
	return unlocked_varieties.has(variety_id)

func select_variety(variety_id: String) -> bool:
	if not unlocked_varieties.has(variety_id):
		return false
	selected_variety = variety_id
	new_variety_unlocks.erase(variety_id)
	save_data()
	settings_changed.emit()
	return true

func mark_variety_seen(variety_id: String) -> void:
	new_variety_unlocks.erase(variety_id)

func take_new_variety_unlocks() -> Array[String]:
	var result := new_variety_unlocks.duplicate()
	new_variety_unlocks.clear()
	return result

func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	total_stars += amount
	stats.total_coins = total_stars
	save_data()

func coin_balance() -> int:
	return maxi(0, total_stars - coins_spent)

func get_upgrade(upgrade_id: String) -> Dictionary:
	for u: Dictionary in UPGRADES:
		if String(u.id) == upgrade_id:
			return u
	return {}

func has_upgrade(upgrade_id: String) -> bool:
	return upgrades.has(upgrade_id)

func can_buy(upgrade_id: String) -> bool:
	var u := get_upgrade(upgrade_id)
	return not u.is_empty() and not has_upgrade(upgrade_id) and coin_balance() >= int(u.cost)

func buy_upgrade(upgrade_id: String) -> bool:
	if not can_buy(upgrade_id):
		return false
	coins_spent += int(get_upgrade(upgrade_id).cost)
	upgrades.append(upgrade_id)
	save_data()
	settings_changed.emit()
	return true

func set_gameplay_settings(shake: float, hitstop: bool) -> void:
	screen_shake_intensity = clampf(shake, 0.0, 1.0)
	hitstop_enabled = hitstop
	save_data()
	settings_changed.emit()

func set_accessibility_settings(high_contrast: bool, reduced_motion: bool) -> void:
	high_contrast_hazards = high_contrast
	reduce_motion = reduced_motion
	save_data()
	settings_changed.emit()

func set_hotbar_hidden(hidden: bool) -> void:
	hotbar_hidden = hidden
	save_data()
	settings_changed.emit()

func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "high_score", high_score)
	cfg.set_value("progress", "total_bounces", total_bounces)
	cfg.set_value("progress", "total_stars", total_stars)
	cfg.set_value("progress", "stats", stats)
	cfg.set_value("progress", "earned_awards", earned_awards)
	cfg.set_value("progress", "coins_spent", coins_spent)
	cfg.set_value("progress", "upgrades", upgrades)
	cfg.set_value("progress", "unlocked_varieties", unlocked_varieties)
	cfg.set_value("progress", "new_varieties", new_variety_unlocks)
	cfg.set_value("progress", "selected_variety", selected_variety)
	cfg.set_value("settings", "screen_shake_intensity", screen_shake_intensity)
	cfg.set_value("settings", "hitstop_enabled", hitstop_enabled)
	cfg.set_value("settings", "high_contrast_hazards", high_contrast_hazards)
	cfg.set_value("settings", "reduce_motion", reduce_motion)
	cfg.set_value("settings", "hotbar_hidden", hotbar_hidden)
	cfg.set_value("settings", "master_volume", master_volume)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.save(SAVE_PATH)
	progress_saved.emit()

## Progress that follows your account between devices. Settings stay per device.
func progress_snapshot() -> Dictionary:
	return {
		"v": 1,
		"high_score": high_score,
		"total_bounces": total_bounces,
		"total_stars": total_stars,
		"coins_spent": coins_spent,
		"stats": stats.duplicate(),
		"earned_awards": earned_awards.duplicate(),
		"upgrades": upgrades.duplicate(),
		"unlocked_varieties": unlocked_varieties.duplicate(),
		"selected_variety": selected_variety,
	}

## Merges account progress into this device: counters keep the larger value,
## upgrades / varieties / awards are combined. Returns true if anything changed.
func merge_progress(cloud: Dictionary) -> bool:
	if cloud.is_empty():
		return false
	var before := JSON.stringify(progress_snapshot())
	high_score = maxi(high_score, int(cloud.get("high_score", 0)))
	total_bounces = maxi(total_bounces, int(cloud.get("total_bounces", 0)))
	total_stars = maxi(total_stars, int(cloud.get("total_stars", 0)))
	coins_spent = maxi(coins_spent, int(cloud.get("coins_spent", 0)))
	var cloud_stats: Variant = cloud.get("stats", {})
	if cloud_stats is Dictionary:
		for key: String in STAT_KEYS:
			stats[key] = maxi(int(stats.get(key, 0)), int((cloud_stats as Dictionary).get(key, 0)))
	stats.total_bounces = total_bounces
	stats.total_coins = total_stars
	for id: Variant in cloud.get("earned_awards", []):
		if not get_award(String(id)).is_empty() and not earned_awards.has(String(id)):
			earned_awards.append(String(id))
	for id: Variant in cloud.get("upgrades", []):
		if not get_upgrade(String(id)).is_empty() and not upgrades.has(String(id)):
			upgrades.append(String(id))
	for id: Variant in cloud.get("unlocked_varieties", []):
		if _is_variety(String(id)) and not unlocked_varieties.has(String(id)):
			unlocked_varieties.append(String(id))
	var picked := String(cloud.get("selected_variety", ""))
	if selected_variety == "yellow" and unlocked_varieties.has(picked):
		selected_variety = picked
	var changed := JSON.stringify(progress_snapshot()) != before
	if changed:
		save_data()
		settings_changed.emit()
	return changed

func _is_variety(variety_id: String) -> bool:
	for v: Dictionary in VARIETIES:
		if String(v.id) == variety_id:
			return true
	return false

func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	high_score = int(cfg.get_value("progress", "high_score", 0))
	total_bounces = int(cfg.get_value("progress", "total_bounces", 0))
	total_stars = int(cfg.get_value("progress", "total_stars", 0))
	_clear_stats()
	var saved_stats: Variant = cfg.get_value("progress", "stats", {})
	if saved_stats is Dictionary:
		for key: String in STAT_KEYS:
			stats[key] = int((saved_stats as Dictionary).get(key, 0))
	stats.total_bounces = total_bounces
	stats.total_coins = total_stars
	stats.best_distance = maxi(int(stats.best_distance), high_score)
	var awards: Array = cfg.get_value("progress", "earned_awards", [])
	earned_awards.assign(awards)
	coins_spent = int(cfg.get_value("progress", "coins_spent", 0))
	var bought: Array = cfg.get_value("progress", "upgrades", [])
	upgrades.assign(bought)
	var varieties: Array = cfg.get_value("progress", "unlocked_varieties", ["yellow"])
	unlocked_varieties.assign(varieties)
	if not unlocked_varieties.has("yellow"):
		unlocked_varieties.push_front("yellow")
	var fresh: Array = cfg.get_value("progress", "new_varieties", [])
	new_variety_unlocks.assign(fresh)
	selected_variety = str(cfg.get_value("progress", "selected_variety", "yellow"))
	_check_awards(stats, false)
	if not unlocked_varieties.has(selected_variety):
		selected_variety = "yellow"
	screen_shake_intensity = float(cfg.get_value("settings", "screen_shake_intensity", 1.0))
	hitstop_enabled = bool(cfg.get_value("settings", "hitstop_enabled", true))
	high_contrast_hazards = bool(cfg.get_value("settings", "high_contrast_hazards", false))
	reduce_motion = bool(cfg.get_value("settings", "reduce_motion", false))
	hotbar_hidden = bool(cfg.get_value("settings", "hotbar_hidden", false))

func reset_progress() -> void:
	high_score = 0
	total_bounces = 0
	total_stars = 0
	_clear_stats()
	earned_awards.clear()
	run_awards.clear()
	coins_spent = 0
	upgrades.clear()
	unlocked_varieties.assign(["yellow"])
	selected_variety = "yellow"
	new_variety_unlocks.clear()
	save_data()

func _bus_volume(bus: String) -> float:
	var idx := AudioServer.get_bus_index(bus)
	return db_to_linear(AudioServer.get_bus_volume_db(idx)) if idx >= 0 else 1.0

func _set_bus_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))
