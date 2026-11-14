extends Node

enum State { MENU, PLAYING, PAUSED, GAME_OVER }
enum Item { TRAMPOLINE, RAMP, FLOOR }

signal state_changed(state: State)
signal distance_changed(meters: int)
signal combo_changed(multiplier: int)
signal energy_changed(value: float, max_value: float)
signal stars_changed(total: int)
signal health_changed(value: int, max_value: int)
signal form_changed(form_name: String, stage: int)
signal selection_changed(item: Item, ramp_flipped: bool)
signal item_placed(item: Item, position: Vector2)
signal bounced(clutch: bool, position: Vector2)
signal run_over(distance: int, best: int, is_new_best: bool, bounces: int)
signal level_changed(level_number: int, level_name: String, theme_index: int)
signal slowmo_changed(active: bool)
signal boost_changed(active: bool)
signal stomped(position: Vector2, bonus_metres: int)
signal player_out(player: int)
signal versus_over(winner: int, distances: Array)

const ITEM_NAMES := ["Trampoline", "Ramp", "Floor"]
const ITEM_COST := [0.0, 0.0, 0.0]
const ITEM_COOLDOWN := [0.82, 0.68, 0.42]
const MAX_ENERGY := 100.0
const ENERGY_REGEN := 12.0
const MAX_COMBO := 5
const MAX_HEALTH := 3
const STOMP_BONUS := 6
const FORM_NAMES := ["SUNNY", "EMBER", "PRISM", "FALLEN"]
const COMBO_TIMEOUT := 3.0
const CLUTCH_BONUS := 5
const LEVEL_LENGTH_METRES := 60
const LEVEL_NAMES := ["HARVEST HEIGHTS", "COTTAGE WOODS", "PIXEL HOMESTEAD", "GREENWOOD PATH"]
const GUIDED_LEVELS := 3
const SLOWMO_SCALE := 0.55
const SLOWMO_TIME := 3.5
const BOOST_BONUS := 8
const VERSUS_SCENE := "res://scenes/game/versus.tscn"

var state: State = State.MENU
var best := 0
var trauma := 0.0
var slowmo_left := 0.0
var versus := false
var versus_varieties: Array[String] = ["yellow", "orange"]
var players: Array[PlayerState] = []
var versus_bot := false
var bot_difficulty := 1
var input_locked := false

var _hitstop_id := 0

var distance: int:
	get: return players[0].distance
var travelled: int:
	get: return players[0].travelled
var bonus: int:
	get: return players[0].bonus
var combo: int:
	get: return players[0].combo
var bounces: int:
	get: return players[0].bounces
var stars: int:
	get: return players[0].stars
var max_health: int:
	get: return players[0].max_health
var health: int:
	get: return players[0].health
var stomps: int:
	get: return players[0].stomps
var form_stage: int:
	get: return players[0].form_stage
var energy: float:
	get: return players[0].energy
	set(v): players[0].set_energy(v)
var selected_item: Item:
	get: return players[0].selected_item as Item
	set(v): players[0].selected_item = v
var ramp_flipped: bool:
	get: return players[0].ramp_flipped
var airborne: bool:
	get: return players[0].airborne
var level_number: int:
	get: return players[0].level_number
var theme_index: int:
	get: return players[0].theme_index
var best_combo: int:
	get: return players[0].best_combo
var shield_saves: int:
	get: return players[0].shield_saves
var boost_active: bool:
	get: return players[0].boost_active

func _init() -> void:
	for i in 2:
		players.append(PlayerState.new(i))
	var p0 := players[0]
	p0.distance_changed.connect(distance_changed.emit)
	p0.combo_changed.connect(combo_changed.emit)
	p0.energy_changed.connect(energy_changed.emit)
	p0.stars_changed.connect(stars_changed.emit)
	p0.health_changed.connect(health_changed.emit)
	p0.form_changed.connect(form_changed.emit)
	p0.selection_changed.connect(func(item: int, flipped: bool) -> void: selection_changed.emit(item as Item, flipped))
	p0.item_placed.connect(func(item: int, pos: Vector2) -> void: item_placed.emit(item as Item, pos))
	p0.bounced.connect(bounced.emit)
	p0.level_changed.connect(level_changed.emit)
	p0.boost_changed.connect(boost_changed.emit)
	p0.stomped.connect(stomped.emit)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	best = SaveManager.high_score

func _process(delta: float) -> void:
	trauma = maxf(0.0, trauma - delta * 1.6)
	if state != State.PLAYING:
		return
	if slowmo_left > 0.0:
		slowmo_left -= delta / maxf(Engine.time_scale, 0.01)
		if slowmo_left <= 0.0:
			slowmo_left = 0.0
			if Engine.time_scale > 0.1:
				Engine.time_scale = 1.0
			slowmo_changed.emit(false)
	for i in player_count():
		if players[i].alive:
			players[i].tick(delta)

func player(p := 0) -> PlayerState:
	return players[clampi(p, 0, players.size() - 1)]

func player_count() -> int:
	return 2 if versus else 1

func start_run() -> void:
	trauma = 0.0
	slowmo_left = 0.0
	if not versus:
		SaveManager.begin_run()
	var hearts := MAX_HEALTH + (1 if SaveManager.has_upgrade("extra_heart") and not versus else 0)
	var cd := 0.8 if SaveManager.has_upgrade("quick_hands") and not versus else 1.0
	for i in players.size():
		players[i].reset(hearts, cd)
		players[i].alive = i < player_count()
		players[i].variety_id = versus_varieties[i] if versus else SaveManager.selected_variety
	best = SaveManager.high_score
	Engine.time_scale = 1.0
	get_tree().paused = false
	_set_state(State.PLAYING)
	for i in player_count():
		players[i].emit_all()

func start_versus(variety_a: String, variety_b: String, bot := false, difficulty := 1) -> void:
	versus = true
	versus_bot = bot
	bot_difficulty = clampi(difficulty, 0, 2)
	versus_varieties.assign([variety_a, variety_b])
	get_tree().paused = false
	Engine.time_scale = 1.0
	SceneTransition.change_scene(VERSUS_SCENE)

func hurt_variety(p := 0) -> int:
	if state != State.PLAYING or not player(p).alive:
		return player(p).health
	var left := player(p).hurt()
	add_trauma(0.5)
	return left

func end_run(p := 0) -> void:
	if state == State.GAME_OVER:
		return
	if versus:
		_versus_player_out(p)
		return
	Engine.time_scale = 1.0
	slowmo_left = 0.0
	var p0 := players[0]
	p0.alive = false
	var is_new_best := p0.distance > SaveManager.high_score
	SaveManager.record_run(p0.distance, p0.bounces, p0.stars, p0.extra())
	best = SaveManager.high_score
	add_trauma(0.8)
	_set_state(State.GAME_OVER)
	get_tree().paused = true
	run_over.emit(p0.distance, best, is_new_best, p0.bounces)

func _versus_player_out(p: int) -> void:
	if not player(p).alive:
		return
	player(p).alive = false
	add_trauma(0.6)
	player_out.emit(p)
	for i in player_count():
		if players[i].alive and players[i].distance <= players[p].distance:
			return
	_finish_versus()

func _check_versus_lead() -> void:
	if not versus or state != State.PLAYING:
		return
	var out := -1
	var alive := -1
	for i in player_count():
		if players[i].alive:
			alive = i
		else:
			out = i
	if out >= 0 and alive >= 0 and players[alive].distance > players[out].distance:
		_finish_versus()

func _finish_versus() -> void:
	if state == State.GAME_OVER:
		return
	Engine.time_scale = 1.0
	slowmo_left = 0.0
	var distances: Array = []
	for i in player_count():
		distances.append(players[i].distance)
	var winner := 0 if distances[0] > distances[1] else (1 if distances[1] > distances[0] else -1)
	for i in player_count():
		SaveManager.add_coins(players[i].stars)
	_set_state(State.GAME_OVER)
	get_tree().paused = true
	versus_over.emit(winner, distances)

func pause() -> void:
	if state == State.PLAYING and not input_locked:
		get_tree().paused = true
		_set_state(State.PAUSED)

func resume() -> void:
	if state == State.PAUSED:
		get_tree().paused = false
		_set_state(State.PLAYING)
		Engine.time_scale = base_time_scale()

func restart_run() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	SceneTransition.reload_scene()

func go_to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	slowmo_left = 0.0
	versus = false
	versus_bot = false
	input_locked = false
	_set_state(State.MENU)
	SceneTransition.change_scene(MaaacksMenusTemplate.get_main_menu_path())

func is_playing() -> bool:
	return state == State.PLAYING

func is_alive(p := 0) -> bool:
	return state == State.PLAYING and player(p).alive

func set_travelled(meters: int, p := 0) -> void:
	if player(p).set_travelled(meters):
		_check_awards(p)
		_check_versus_lead()

func _check_awards(p := 0) -> void:
	if state != State.PLAYING or versus or p != 0:
		return
	var p0 := players[0]
	var live := p0.extra()
	live.distance = p0.distance
	live.bounces = p0.bounces
	live.coins = p0.stars
	SaveManager.check_live_awards(live)

func is_guided_level(p := 0) -> bool:
	return player(p).level_number <= GUIDED_LEVELS

func register_bounce(clutch: bool, position: Vector2, p := 0) -> void:
	player(p).register_bounce(clutch, position)
	_check_awards(p)

func register_stomp(position: Vector2, p := 0) -> void:
	if state != State.PLAYING:
		return
	var ps := player(p)
	ps.stomps += 1
	var gained := STOMP_BONUS * ps.combo
	ps.add_bonus(gained)
	ps.stomped.emit(position, gained)
	_check_awards(p)

func collect_star(p := 0) -> void:
	if state != State.PLAYING:
		return
	var ps := player(p)
	ps.stars += 1
	ps.set_energy(ps.energy + 8.0)
	ps.stars_changed.emit(ps.stars)
	ps.add_bonus(4)
	_check_awards(p)

func register_shield_save(p := 0) -> void:
	if state != State.PLAYING:
		return
	player(p).shield_saves += 1
	_check_awards(p)

func start_slowmo() -> void:
	if state != State.PLAYING:
		return
	var was_active := slowmo_left > 0.0
	slowmo_left = SLOWMO_TIME
	Engine.time_scale = SLOWMO_SCALE
	if not was_active:
		slowmo_changed.emit(true)

func is_slowmo() -> bool:
	return slowmo_left > 0.0

func set_boost(active: bool, p := 0) -> void:
	var ps := player(p)
	if active == ps.boost_active:
		return
	ps.boost_active = active
	if active and state == State.PLAYING:
		ps.add_bonus(BOOST_BONUS)
	ps.boost_changed.emit(active)

func base_time_scale() -> float:
	return SLOWMO_SCALE if slowmo_left > 0.0 and state == State.PLAYING else 1.0

func select_item(item: Item, p := 0) -> void:
	if state != State.PLAYING:
		return
	var ps := player(p)
	ps.selected_item = item
	ps.selection_changed.emit(item, ps.ramp_flipped)

func flip_ramp(p := 0) -> void:
	if state != State.PLAYING:
		return
	var ps := player(p)
	ps.ramp_flipped = not ps.ramp_flipped
	ps.selection_changed.emit(ps.selected_item, ps.ramp_flipped)

func can_afford(item: Item, p := 0) -> bool:
	return player(p).can_afford(item)

func is_ready(item: Item, p := 0) -> bool:
	return player(p).is_ready(item)

func item_cooldown(item: Item, p := 0) -> float:
	return player(p).item_cooldown(item)

func cooldown_ratio(item: Item, p := 0) -> float:
	return player(p).cooldown_ratio(item)

func cooldown_remaining(item: Item, p := 0) -> float:
	return player(p).cooldown_remaining(item)

func try_spend(item: Item, position: Vector2, p := 0) -> bool:
	if not is_alive(p):
		return false
	return player(p).spend(item, position)

func set_airborne(value: bool, p := 0) -> void:
	player(p).airborne = value

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func hitstop(duration := 0.035) -> void:
	if not SaveManager.hitstop_enabled or state != State.PLAYING:
		return
	_hitstop_id += 1
	var my_id := _hitstop_id
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	if my_id != _hitstop_id:
		return
	if state == State.PLAYING or state == State.PAUSED:
		Engine.time_scale = base_time_scale()
	else:
		Engine.time_scale = 1.0

func _set_state(s: State) -> void:
	state = s
	state_changed.emit(s)
