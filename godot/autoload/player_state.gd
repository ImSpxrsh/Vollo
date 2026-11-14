class_name PlayerState
extends RefCounted

signal distance_changed(meters: int)
signal combo_changed(multiplier: int)
signal energy_changed(value: float, max_value: float)
signal stars_changed(total: int)
signal health_changed(value: int, max_value: int)
signal form_changed(form_name: String, stage: int)
signal selection_changed(item: int, ramp_flipped: bool)
signal item_placed(item: int, position: Vector2)
signal bounced(clutch: bool, position: Vector2)
signal level_changed(level_number: int, level_name: String, theme_index: int)
signal boost_changed(active: bool)
signal stomped(position: Vector2, bonus_metres: int)

var index := 0
var variety_id := "yellow"
var alive := true
var distance := 0
var travelled := 0
var bonus := 0
var combo := 1
var bounces := 0
var stars := 0
var max_health := 3
var health := 3
var stomps := 0
var form_stage := 0
var energy := 100.0
var selected_item := 0
var ramp_flipped := false
var airborne := false
var level_number := 1
var theme_index := 0
var best_combo := 1
var shield_saves := 0
var boost_active := false
var cooldown_mult := 1.0

var _cooldown_left := [0.0, 0.0, 0.0]
var _combo_timer := 0.0

func _init(player_index := 0) -> void:
	index = player_index

func reset(hearts: int, cooldown_multiplier: float) -> void:
	alive = true
	distance = 0
	travelled = 0
	bonus = 0
	combo = 1
	bounces = 0
	stars = 0
	max_health = hearts
	health = hearts
	stomps = 0
	form_stage = 0
	energy = GameManager.MAX_ENERGY
	selected_item = 0
	ramp_flipped = false
	airborne = false
	level_number = 1
	theme_index = 0
	best_combo = 1
	shield_saves = 0
	boost_active = false
	cooldown_mult = cooldown_multiplier
	_cooldown_left = [0.0, 0.0, 0.0]
	_combo_timer = 0.0

func emit_all() -> void:
	distance_changed.emit(distance)
	combo_changed.emit(combo)
	energy_changed.emit(energy, GameManager.MAX_ENERGY)
	stars_changed.emit(stars)
	health_changed.emit(health, max_health)
	form_changed.emit(GameManager.FORM_NAMES[form_stage], form_stage)
	selection_changed.emit(selected_item, ramp_flipped)
	level_changed.emit(level_number, GameManager.LEVEL_NAMES[theme_index], theme_index)

func tick(delta: float) -> void:
	set_energy(energy + GameManager.ENERGY_REGEN * delta)
	for i in 3:
		_cooldown_left[i] = maxf(0.0, _cooldown_left[i] - delta)
	if combo > 1:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			combo = 1
			combo_changed.emit(combo)

func set_travelled(meters: int) -> bool:
	if meters <= travelled:
		return false
	travelled = meters
	update_distance()
	var next_level := int(travelled / GameManager.LEVEL_LENGTH_METRES) + 1
	if next_level != level_number:
		level_number = next_level
		theme_index = (level_number - 1) % GameManager.LEVEL_NAMES.size()
		level_changed.emit(level_number, GameManager.LEVEL_NAMES[theme_index], theme_index)
	return true

func update_distance() -> void:
	distance = travelled + bonus
	distance_changed.emit(distance)

func add_bonus(metres: int) -> void:
	bonus += metres
	update_distance()

func register_bounce(clutch: bool, position: Vector2) -> void:
	bounces += 1
	if clutch:
		combo = mini(GameManager.MAX_COMBO, combo + 1)
		best_combo = maxi(best_combo, combo)
		_combo_timer = GameManager.COMBO_TIMEOUT
		bonus += GameManager.CLUTCH_BONUS * combo
		combo_changed.emit(combo)
		update_distance()
	bounced.emit(clutch, position)

func hurt() -> int:
	if health <= 0:
		return health
	health -= 1
	form_stage = mini(form_stage + 1, GameManager.FORM_NAMES.size() - 1)
	health_changed.emit(health, max_health)
	form_changed.emit(GameManager.FORM_NAMES[form_stage], form_stage)
	return health

func extra() -> Dictionary:
	return {"combo": best_combo, "shield_saves": shield_saves, "level": level_number, "stomps": stomps}

func can_afford(item: int) -> bool:
	return energy >= GameManager.ITEM_COST[item]

func is_ready(item: int) -> bool:
	return _cooldown_left[item] <= 0.0

func item_cooldown(item: int) -> float:
	return GameManager.ITEM_COOLDOWN[item] * cooldown_mult

func cooldown_ratio(item: int) -> float:
	return clampf(_cooldown_left[item] / item_cooldown(item), 0.0, 1.0)

func cooldown_remaining(item: int) -> float:
	return maxf(0.0, _cooldown_left[item])

func spend(item: int, position: Vector2) -> bool:
	if not can_afford(item) or not is_ready(item):
		return false
	set_energy(energy - GameManager.ITEM_COST[item])
	_cooldown_left[item] = item_cooldown(item)
	item_placed.emit(item, position)
	return true

func set_energy(value: float) -> void:
	var v := clampf(value, 0.0, GameManager.MAX_ENERGY)
	if not is_equal_approx(v, energy):
		energy = v
		energy_changed.emit(energy, GameManager.MAX_ENERGY)
