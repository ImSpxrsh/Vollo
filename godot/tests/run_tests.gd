extends SceneTree

var _failures := 0
var _passes := 0
var _main: Node
var _save_backup: Variant = null

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var tests := [
		"test_audio_sounds",
		"test_story_instantiates",
		"test_main_starts_run",
		"test_horizontal_hazards_generate",
		"test_map_changes_between_runs",
		"test_levels_change_with_distance",
		"test_build_tools_place",
		"test_trampoline_changes_fall",
		"test_ball_rolls_and_scores",
		"test_hazard_ends_run",
		"test_shield_absorbs_hit",
		"test_pause_resume",
		"test_menu_instantiates",
		"test_guided_levels_are_fixed",
		"test_random_levels_after_guided",
		"test_awards_unlock_varieties",
		"test_live_award_during_run",
		"test_ball_uses_selected_variety",
		"test_variety_menu_equips",
		"test_slowmo_and_boost",
		"test_hearts_and_rescue",
		"test_clutch_only_near_hazards",
		"test_bounce_enemy_away",
		"test_shop_upgrades",
		"test_pause_restores_time_after_hitstop",
		"test_versus_match",
		"test_versus_setup_menu",
		"test_versus_private_pieces_and_lock",
		"test_versus_survivor_wins_once_ahead",
		"test_versus_bot_plays",
		"test_custom_map_finish",
		"test_tutorial_holds_time", "test_tutorial_mistake_rewinds",
		"test_replay_roundtrip",
		"test_map_builder_edit",
		"test_watch_mode_bots",
	]
	_backup_save()
	var replays_before := ReplayStore.list()
	for test_name in tests:
		await _reset()
		var error: String = await call(test_name)
		if error.is_empty():
			_passes += 1
			print("PASS ", test_name)
		else:
			_failures += 1
			print("FAIL ", test_name, ": ", error)
	await _reset()
	for path in ReplayStore.list():
		if not replays_before.has(path):
			ReplayStore.remove(path)
	_restore_save()
	print("%d passed, %d failed" % [_passes, _failures])
	quit(_failures)

func _backup_save() -> void:
	var path: String = root.get_node("SaveManager").SAVE_PATH
	if FileAccess.file_exists(path):
		_save_backup = FileAccess.get_file_as_bytes(path)

func _restore_save() -> void:
	var save := root.get_node("SaveManager")
	var path: String = save.SAVE_PATH
	if _save_backup is PackedByteArray:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(_save_backup)
		f.close()
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	save.reset_progress()
	save.load_data()
	if _save_backup == null and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _sm() -> Node:
	return root.get_node("SaveManager")

func _gm() -> Node:
	return root.get_node("GameManager")

func _reset() -> void:
	paused = false
	_gm().versus = false
	_gm().versus_bot = false
	_gm().versus_watch = false
	_gm().input_locked = false
	_gm().custom_map = {}
	_gm().tutorial = false
	_gm().map_from_builder = false
	_gm().time_hold = 1.0
	Engine.time_scale = 1.0
	if _main and is_instance_valid(_main):
		_main.queue_free()
		_main = null
	await process_frame
	await process_frame

func _start_main() -> Node:
	seed(12345)
	_main = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(_main)
	await physics_frame
	return _main

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _ball() -> RigidBody2D:
	return _main.get_node("Ball")

func _remove_hazards() -> void:
	for hazard in get_nodes_in_group("hazard"):
		hazard.queue_free()

func test_audio_sounds() -> String:
	var audio := root.get_node("AudioManager")
	for sound in ["boing", "click", "death", "pickup", "deny"]:
		if not audio.has_sound(sound):
			return "missing sound " + sound
	var music_path := "res://assets/audio/voll_background.mp3"
	if not ResourceLoader.exists(music_path):
		return "missing background music"
	var music := load(music_path) as AudioStreamMP3
	if music == null or music.get_length() < 100.0:
		return "background music failed to load or is incomplete"
	if not music.loop:
		return "background music is not configured to loop"
	return ""

func test_story_instantiates() -> String:
	var story: Node = load("res://scenes/story/IntroStory.tscn").instantiate()
	root.add_child(story)
	await process_frame
	var result := ""
	var start_screen := story.get_node_or_null("StartScreen") as Control
	var start_title := story.get_node_or_null("StartScreen/TitleStack/StartTitle") as Label
	if start_screen == null or not start_screen.visible:
		result = "cinematic start screen is missing"
	elif start_title == null or start_title.text != "VOLL":
		result = "start screen title is not VOLL"
	elif story.get_node_or_null("StoryPanel/Title") == null:
		result = "story title missing"
	elif (story.get_node("StoryPanel/Title") as Label).text != "MEET VARIETY":
		result = "story does not introduce Variety"
	story.queue_free()
	await process_frame
	return result

func test_main_starts_run() -> String:
	await _start_main()
	for node_name in ["Ball", "StartPlatform", "Ceiling", "LevelGenerator", "Items", "ItemPlacer", "GameCamera", "HUD", "GameOverOverlay", "PauseMenu"]:
		if _main.get_node_or_null(node_name) == null:
			return "main scene missing " + node_name
	return "" if _gm().state == 1 else "run did not enter PLAYING"

func test_horizontal_hazards_generate() -> String:
	await _start_main()
	var generator := _main.get_node("LevelGenerator")
	var patterns: Array = generator.get_patterns()
	if patterns.size() < 4:
		return "only %d hazard patterns generated" % patterns.size()
	var hazards := 0
	for pattern in patterns:
		for child in pattern.get_children():
			if child.is_in_group("hazard"):
				hazards += 1
	return "" if hazards >= 2 else "authored course did not generate enough red hazards"

func test_map_changes_between_runs() -> String:
	await _start_main()
	var generator: Node = _main.get_node("LevelGenerator")
	var far: float = 4000.0 * (generator.guided_level_count() + 2)
	generator.seed_rng(101)
	generator.reset()
	generator.update_for_x(far)
	var first_layout: String = generator.get_layout_signature()
	generator.seed_rng(202)
	generator.reset()
	generator.update_for_x(far)
	var second_layout: String = generator.get_layout_signature()
	if first_layout.is_empty() or second_layout.is_empty():
		return "generator did not record a layout"
	return "" if first_layout != second_layout else "different runs produced the same map"

func test_levels_change_with_distance() -> String:
	await _start_main()
	var starting_theme: int = _gm().theme_index
	_gm().set_travelled(60)
	await process_frame
	if _gm().level_number != 2 or _gm().theme_index == starting_theme:
		return "reaching the level boundary did not change the stage"
	var backdrop := _main.get_node("Background/Backdrop") as TextureRect
	var next_backdrop := _main.get_node_or_null("Background/BackdropNext") as TextureRect
	if backdrop == null or next_backdrop == null or next_backdrop.texture == null:
		return "level transition background was not prepared"
	return ""

func test_ball_rolls_and_scores() -> String:
	await _start_main()
	_remove_hazards()
	var start_x := _ball().position.x
	await _frames(55)
	if _ball().position.x <= start_x + 180.0:
		return "Variety did not auto-roll"
	return "" if _gm().distance >= 4 else "distance score did not increase"

func test_build_tools_place() -> String:
	await _start_main()
	var placer := _main.get_node("ItemPlacer")
	var items := _main.get_node("Items")
	var positions := [Vector2(390, 405), Vector2(525, 390), Vector2(650, 460)]
	for item in 3:
		_gm().select_item(item)
		if not placer.place_at(positions[item]):
			return "tool %d refused a valid placement" % item
	await _frames(2)
	if items.get_child_count() != 3:
		return "expected 3 placed tools, found %d" % items.get_child_count()
	return "" if not _gm().is_ready(2) else "floor cooldown did not start"

func test_trampoline_changes_fall() -> String:
	await _start_main()
	_remove_hazards()
	var placer := _main.get_node("ItemPlacer")
	_gm().select_item(0)
	if not placer.place_at(_ball().position + Vector2(175, 18)):
		return "trampoline placement failed"
	await _frames(50)
	return "" if _gm().bounces > 0 else "Variety did not bounce on the trampoline"

func test_hazard_ends_run() -> String:
	await _start_main()
	_remove_hazards()
	var hearts: int = _gm().max_health
	for i in hearts:
		_ball()._invuln_left = 0.0
		_ball().kill()
		await _frames(2)
		if i < hearts - 1 and _gm().state != 1:
			return "run ended after %d of %d hits" % [i + 1, hearts]
	return "" if _gm().state == 3 else "losing every heart did not end the run"

func test_shield_absorbs_hit() -> String:
	await _start_main()
	_ball().give_shield()
	_ball().kill()
	await _frames(2)
	if _ball().has_shield:
		return "shield was not consumed"
	return "" if _gm().state == 1 else "shield did not keep the run alive"

func test_pause_resume() -> String:
	await _start_main()
	_gm().pause()
	if _gm().state != 2 or not paused:
		return "pause failed"
	_gm().resume()
	return "" if _gm().state == 1 and not paused else "resume failed"

func test_menu_instantiates() -> String:
	var menu: Node = load("res://scenes/ui/MainMenu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var title := menu.get_node_or_null("TitleBlock/TitleLabel") as Label
	var result := "" if title and title.text == "VOLL" else "menu title is not VOLL"
	menu.queue_free()
	await process_frame
	return result

func _build_far(generator: Node, seed_value: int) -> void:
	generator.seed_rng(seed_value)
	generator.reset()
	var x := 0.0
	while x < 4000.0 * (generator.guided_level_count() + 2):
		x += 2500.0
		generator.update_for_x(x)

func test_guided_levels_are_fixed() -> String:
	await _start_main()
	var generator: Node = _main.get_node("LevelGenerator")
	_build_far(generator, 11)
	var first: Array[String] = []
	for level in range(1, generator.guided_level_count() + 1):
		first.append(generator.get_level_signature(level))
	_build_far(generator, 99)
	for level in range(1, generator.guided_level_count() + 1):
		if first[level - 1].is_empty():
			return "guided level %d generated nothing" % level
		if generator.get_level_signature(level) != first[level - 1]:
			return "guided level %d changed between runs" % level
	var course: Array = load("res://scenes/chunks/LevelGenerator.gd").GUIDED_COURSE
	for level in range(1, generator.guided_level_count() + 1):
		var built: int = first[level - 1].split("|").size()
		var authored: int = (course[level - 1].steps as Array).size()
		if built < authored:
			return "guided level %d only built %d of its %d steps" % [level, built, authored]
	if first[0].contains("enemy") or first[0].contains("grump") or first[0].contains("spikes"):
		return "level 1 is not gentle: " + first[0]
	return ""

func test_random_levels_after_guided() -> String:
	await _start_main()
	var generator: Node = _main.get_node("LevelGenerator")
	var level: int = generator.guided_level_count() + 1
	_build_far(generator, 11)
	var a: String = generator.get_level_signature(level)
	_build_far(generator, 99)
	var b: String = generator.get_level_signature(level)
	if a.is_empty() or b.is_empty():
		return "first random level was not generated"
	return "" if a != b else "first random level is the same for two seeds"


func test_awards_unlock_varieties() -> String:
	var save := _sm()
	save.reset_progress()
	if save.unlocked_varieties != ["yellow"] or save.selected_variety != "yellow":
		return "fresh save should only have the yellow variety"
	if save.select_variety("orange"):
		return "could equip a locked variety"
	save.begin_run()
	save.record_run(30, 3, 2, {"combo": 1, "shield_saves": 0, "level": 1})
	if not save.has_award("first_steps") or not save.is_variety_unlocked("orange"):
		return "rolling 30 m did not earn First Steps / ORANGE"
	if save.is_variety_unlocked("white"):
		return "WHITE unlocked too early"
	if not save.run_awards.has("first_steps"):
		return "award was not listed for the run"
	if not save.select_variety("orange"):
		return "could not equip an unlocked variety"
	for i in 10:
		save.record_run(5, 2, 3)
	if not save.has_award("pocket_change"):
		return "30 lifetime coins did not earn Pocket Change"
	save.reset_progress()
	return ""

func test_live_award_during_run() -> String:
	_sm().reset_progress()
	await _start_main()
	var earned: Array[String] = []
	var on_award := func(id: String, _n: String, _v: String) -> void: earned.append(id)
	_sm().award_earned.connect(on_award)
	_gm().set_travelled(26)
	_sm().award_earned.disconnect(on_award)
	_sm().reset_progress()
	return "" if earned.has("first_steps") else "award did not pop during the run"

func test_ball_uses_selected_variety() -> String:
	var save := _sm()
	save.reset_progress()
	save.unlocked_varieties.append("pink")
	save.select_variety("pink")
	await _start_main()
	var body := _ball().get_node_or_null("Visual/Variety/Body") as Sprite2D
	var result := ""
	if body == null or body.texture == null:
		result = "ball has no variety sprite"
	elif not body.texture.resource_path.contains("variety_pink"):
		result = "ball is not using the pink art: " + body.texture.resource_path
	save.reset_progress()
	return result

func test_variety_menu_equips() -> String:
	var save := _sm()
	save.reset_progress()
	save.unlocked_varieties.append("teal")
	var menu: Node = load("res://scenes/ui/VarietyMenu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var result := ""
	var grid := menu.find_child("Grid", true, false)
	if grid == null or grid.get_child_count() != 12:
		result = "menu should show 12 varieties"
	else:
		menu.call("_on_card_pressed", "white")
		menu.call("_on_equip")
		if save.selected_variety != "yellow":
			result = "locked variety got equipped"
		menu.call("_on_card_pressed", "teal")
		menu.call("_on_card_pressed", "teal")
		if result.is_empty() and save.selected_variety != "teal":
			result = "unlocked variety did not equip"
	menu.queue_free()
	await process_frame
	save.reset_progress()
	return result

func test_slowmo_and_boost() -> String:
	await _start_main()
	_remove_hazards()
	_gm().start_slowmo()
	if not _gm().is_slowmo() or Engine.time_scale > 0.9:
		return "hourglass did not slow time"
	_ball().boost()
	_ball().kill()
	await _frames(2)
	if _gm().state != 1:
		return "boost did not protect the ball"
	if not _gm().boost_active:
		return "boost state was not reported"
	Engine.time_scale = 1.0
	return ""

func test_hearts_and_rescue() -> String:
	await _start_main()
	_remove_hazards()
	var start: int = _gm().health
	_ball().global_position.y = 900.0
	await _frames(3)
	if _gm().health != start - 1:
		return "falling out did not cost exactly one heart"
	if _gm().state != 1:
		return "falling out with hearts left ended the run"
	if _ball().global_position.y > 500.0:
		return "ball was not bounced back up after falling (y=%d)" % _ball().global_position.y
	return ""

func test_clutch_only_near_hazards() -> String:
	await _start_main()
	_remove_hazards()
	await _frames(2)
	_ball().bounce(-600.0)
	if _gm().combo != 1:
		return "a bounce far from hazards counted as clutch"
	var spike: Node2D = load("res://scenes/obstacles/Spike.tscn").instantiate()
	_main.add_child(spike)
	spike.global_position = _ball().global_position + Vector2(120, 60)
	await _frames(1)
	_ball().bounce(-600.0)
	return "" if _gm().combo == 2 else "a bounce next to a spike was not a clutch"

func test_bounce_enemy_away() -> String:
	await _start_main()
	_remove_hazards()
	var enemy: Node2D = load("res://scenes/obstacles/GrumpBall.tscn").instantiate()
	_main.add_child(enemy)
	enemy.global_position = _ball().global_position + Vector2(0, 40)
	await _frames(1)
	var hearts: int = _gm().health
	_ball().bounce(-600.0)
	_ball().hit_by_enemy(enemy)
	await _frames(2)
	if _gm().stomps != 1:
		return "enemy was not bounced away after a trampoline launch"
	if _gm().health != hearts:
		return "bouncing an enemy away cost a heart"
	var enemy2: Node2D = load("res://scenes/obstacles/WanderingHazard.tscn").instantiate()
	_main.add_child(enemy2)
	enemy2.global_position = _ball().global_position + Vector2(0, -60)
	await _frames(40)
	_ball()._stomp_charge = 0.0
	_ball()._invuln_left = 0.0
	_ball().linear_velocity = Vector2(300, -200)
	_ball().hit_by_enemy(enemy2)
	return "" if _gm().health == hearts - 1 else "touching an enemy from below did not hurt"

func test_shop_upgrades() -> String:
	var save := _sm()
	save.reset_progress()
	if save.buy_upgrade("head_start"):
		return "bought an upgrade with no coins"
	save.record_run(10, 0, 100)
	if save.coin_balance() != 100:
		return "coin balance should be 100"
	if not save.buy_upgrade("extra_heart") or save.coin_balance() != 10:
		return "buying Extra Heart did not spend 90 coins"
	if save.buy_upgrade("extra_heart"):
		return "bought the same upgrade twice"
	if int(save.stats.total_coins) != 100:
		return "spending coins lowered lifetime coin stats"
	await _start_main()
	var result := "" if _gm().max_health == 4 and _gm().health == 4 else "Extra Heart did not give 4 hearts"
	save.reset_progress()
	return result

func test_pause_restores_time_after_hitstop() -> String:
	await _start_main()
	var was_enabled: bool = _sm().hitstop_enabled
	_sm().hitstop_enabled = true
	_gm().hitstop(0.05)
	_gm().pause()
	await create_timer(0.15, true, false, true).timeout
	_gm().resume()
	_sm().hitstop_enabled = was_enabled
	return "" if Engine.time_scale > 0.9 else "time stayed slowed (%.2f) after pausing during a hitstop" % Engine.time_scale

func test_versus_match() -> String:
	_gm().versus_varieties.assign(["yellow", "orange"])
	_main = load("res://scenes/game/versus.tscn").instantiate()
	root.add_child(_main)
	await _frames(2)
	_main.end_countdown()
	await _frames(2)
	if not _gm().versus or _gm().player_count() != 2:
		return "versus mode did not start with two players"
	var balls: Array = _main.balls
	if balls.size() != 2 or balls[1].player_index != 1:
		return "versus needs two balls with player indexes"
	if not String(balls[1].get_node("Visual/Variety/Body").texture.resource_path).contains("variety_orange"):
		return "player 2 is not using their chosen variety"
	var p2_placer: Node = _main.placers[1]
	_gm().select_item(2, 1)
	if not p2_placer.place_at(balls[1].global_position + Vector2(260, 80)):
		return "player 2 could not place a piece"
	if _gm().player(1).is_ready(2) or not _gm().player(0).is_ready(2):
		return "cooldowns are not per player"
	for h in _gm().player(0).max_health:
		balls[0]._invuln_left = 0.0
		balls[0].kill()
		await _frames(1)
	if _gm().player(0).alive or _gm().state != 1:
		return "player 1 being out should not end the match while player 2 rolls"
	var result := {"winner": -2}
	_gm().versus_over.connect(func(w: int, _d: Array) -> void: result.winner = w, CONNECT_ONE_SHOT)
	_gm().player(1).add_bonus(500)
	for h in _gm().player(1).max_health:
		balls[1]._invuln_left = 0.0
		balls[1].kill()
		await _frames(1)
	if _gm().state != 3:
		return "match did not end when both players were out"
	return "" if result.winner == 1 else "wrong winner (%d)" % result.winner

func test_versus_setup_menu() -> String:
	var menu: Node = load("res://scenes/ui/VersusSetup.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var result := ""
	if menu.choices[0] == menu.choices[1]:
		result = "both players start with the same ball"
	menu.cycle(1, 1)
	if result.is_empty() and not _sm().is_variety_unlocked(menu.choices[1]) and not menu.GUEST_VARIETIES.has(menu.choices[1]):
		result = "player 2 got a locked, non-guest variety"
	menu.queue_free()
	await process_frame
	return result

func _start_versus(bot := false) -> void:
	_gm().versus_varieties.assign(["yellow", "orange"])
	_gm().versus_bot = bot
	_gm().bot_difficulty = 2
	_main = load("res://scenes/game/versus.tscn").instantiate()
	root.add_child(_main)
	await _frames(2)

func test_versus_private_pieces_and_lock() -> String:
	await _start_versus()
	_gm().pause()
	if _gm().state != 1 or not paused:
		return "pause during the countdown should be ignored (state %d, paused %s)" % [_gm().state, paused]
	_main.end_countdown()
	await _frames(2)
	if paused:
		return "countdown did not unfreeze the world"
	var balls: Array = _main.balls
	_gm().select_item(2, 0)
	if not _main.placers[0].place_at(balls[0].global_position + Vector2(260, 80)):
		return "player 1 could not place"
	await _frames(1)
	var piece: CollisionObject2D = _main.world.get_node("Items").get_child(0)
	if piece.collision_layer & balls[1].collision_mask:
		return "player 2's ball collides with player 1's piece"
	if not (piece.collision_layer & balls[0].collision_mask):
		return "player 1's ball does not collide with their own piece"
	if (piece as CanvasItem).visibility_layer & _main.views[1].canvas_cull_mask:
		return "player 1's piece is drawn in player 2's half"
	return ""

func test_versus_survivor_wins_once_ahead() -> String:
	await _start_versus()
	_main.end_countdown()
	await _frames(2)
	var balls: Array = _main.balls
	_gm().player(0).add_bonus(40)
	for h in _gm().player(0).max_health:
		balls[0]._invuln_left = 0.0
		balls[0].kill()
		await _frames(1)
	if _gm().state != 1:
		return "match ended although player 2 is still behind"
	_gm().player(1).add_bonus(60)
	_gm().set_travelled(_gm().player(1).travelled + 1, 1)
	return "" if _gm().state == 3 else "survivor passing the fallen player's distance did not win"

func test_versus_bot_plays() -> String:
	await _start_versus(true)
	_main.end_countdown()
	if _main.bot == null:
		return "no bot in a vs-bot match"
	if not _main.placers[1].ai_controlled:
		return "bot's placer still takes keyboard input"
	await _frames(300)
	var items := 0
	for piece in _main.world.get_node("Items").get_children():
		if piece.collision_layer == WorldConst.LAYER_PIECES[1]:
			items += 1
	if items == 0 and _main.bot.last_action.is_empty():
		return "bot never placed a piece in 5 seconds"
	return "" if _gm().player(1).distance > 10 else "bot made no progress"


const TEST_MAP := {"name": "Test", "objects": [{"k": "low_wall", "x": 1500, "h": 0.5}, {"k": "coin", "x": 1800, "y": 380}, {"k": "finish", "x": 2600}]}

func test_custom_map_finish() -> String:
	var best_before: int = _sm().high_score
	_gm().custom_map = TEST_MAP.duplicate(true)
	await _start_main()
	var gen: Node = _main.get_node("LevelGenerator")
	if not gen.custom or not gen.get_layout_signature().begins_with("M:low_wall:1500|M:coin:1800"):
		return "custom map layout not used: " + gen.get_layout_signature()
	if absf(gen.finish_x - 2600.0) > 0.1:
		return "finish line at %s" % gen.finish_x
	gen.finish_x = _ball().global_position.x - 1.0
	await _frames(2)
	if not _gm().cleared or _gm().state != 3:
		return "passing the finish did not clear the course"
	if _sm().high_score != best_before:
		return "custom maps should not change the high score"
	return ""

func test_tutorial_holds_time() -> String:
	_gm().custom_map = MapStore.TUTORIAL.duplicate(true)
	_gm().tutorial = true
	await _start_main()
	await _frames(3)
	if not _main.has_node("Tutorial"):
		return "tutorial overlay missing"
	var tut: Node = _main.get_node("Tutorial")
	var placer: Node = _main.get_node("ItemPlacer")
	var mistakes := [0]
	_gm().tutorial_mistake.connect(func() -> void: mistakes[0] += 1)
	var froze := 0
	var next_floor := 0.0
	var f := 0
	while _gm().state != _gm().State.GAME_OVER and f < 60 * 90:
		await process_frame
		f += 1
		var l: Dictionary = tut.current()
		if tut.frozen:
			if Engine.time_scale > 0.01:
				return "frozen lesson did not stop time (scale %s)" % Engine.time_scale
			froze += 1
			_gm().select_item(int(l.item))
			placer.place_at(l.targets[tut.target])
		elif l.get("free", false) and not tut._completed:
			_gm().select_item(2)
			var bx := _ball().global_position.x
			next_floor = maxf(next_floor, bx + 160.0)
			if next_floor < bx + 420.0 and _gm().player(0).is_ready(2) and placer.place_at(Vector2(next_floor, 471)):
				next_floor += 205.0
	if froze < 5:
		return "tutorial only froze %d times" % froze
	if mistakes[0] > 0:
		return "following the glowing spots still caused %d mistakes" % mistakes[0]
	if not _gm().cleared:
		return "tutorial not finished (x=%d)" % int(_ball().global_position.x)
	if _gm().player(0).stomps < 1:
		return "stomp lesson did not stomp"
	return ""

func test_tutorial_mistake_rewinds() -> String:
	_gm().custom_map = MapStore.TUTORIAL.duplicate(true)
	_gm().tutorial = true
	await _start_main()
	await _frames(3)
	var tut: Node = _main.get_node("Tutorial")
	_ball().teleport(Vector2(1500, 428))
	await _frames(30)
	var hp: int = _gm().health
	_ball()._invuln_left = 0.0
	_ball().kill()
	await _frames(3)
	if _gm().health != hp:
		return "tutorial hits should not cost hearts"
	if absf(_ball().global_position.x - float(MapStore.TUTORIAL_LESSONS[tut.lesson + 1].cp)) > 40.0:
		return "mistake did not rewind to the lesson start (x=%d)" % int(_ball().global_position.x)
	return ""

func test_replay_roundtrip() -> String:
	await _start_main()
	var rec: Node = _main.get("recorder")
	if rec == null:
		return "solo runs have no recorder"
	_gm().select_item(2)
	await _frames(20)
	_main.get_node("ItemPlacer").place_at(_ball().global_position + Vector2(300, 60))
	await _frames(60)
	for h in _gm().max_health:
		_ball()._invuln_left = 0.0
		_ball().kill()
		await _frames(1)
	if String(rec.last_path).is_empty():
		return "no replay saved when the run ended"
	var data := ReplayStore.load_replay(rec.last_path)
	if (data.get("frames", []) as Array).size() < 20 or (data.get("pieces", []) as Array).size() < 1:
		return "replay is missing frames or pieces"
	_main.queue_free()
	paused = false
	ReplayStore.pending = data
	_main = load("res://scenes/game/replay_player.tscn").instantiate()
	root.add_child(_main)
	Engine.time_scale = 4.0
	for i in 600:
		await process_frame
		if _main._done:
			break
	Engine.time_scale = 1.0
	if not _main._done:
		return "replay did not reach the end"
	if _main._piece_i != (data.pieces as Array).size():
		return "replay did not spawn every piece"
	ReplayStore.pending = {}
	return ""

func test_map_builder_edit() -> String:
	_main = load("res://scenes/ui/MapBuilder.tscn").instantiate()
	root.add_child(_main)
	await process_frame
	if _main.place({"k": "coin", "x": 100, "y": 300}):
		return "placing inside the start area should be refused"
	if not _main.place({"k": "enemy", "x": 1500, "y": 400}) or not _main.place({"k": "spikes_low", "x": 1900, "n": 3}):
		return "could not place objects"
	_main.place({"k": "finish", "x": 3000})
	var finishes: Array = _main.to_dict().objects.filter(func(o: Dictionary) -> bool: return o.k == "finish")
	if finishes.size() != 1 or int(finishes[0].x) != 3000:
		return "a map should have exactly one finish line"
	if not _main.erase_near(Vector2(1500, 400)):
		return "right-click erase missed the devil ball"
	if _main.to_dict().objects.size() != 2:
		return "expected 2 objects, got %d" % _main.to_dict().objects.size()
	return ""

func test_watch_mode_bots() -> String:
	_gm().versus_varieties.assign(["yellow", "orange"])
	_gm().versus_bot = true
	_gm().versus_watch = true
	_gm().bot_difficulty = 3
	_main = load("res://scenes/game/versus.tscn").instantiate()
	root.add_child(_main)
	await _frames(2)
	_main.end_countdown()
	if _main.bots.size() != 2 or not _main.placers[0].ai_controlled or not _main.placers[1].ai_controlled:
		return "watch mode needs two bot-controlled players"
	await _frames(240)
	var pieces: int = _main.world.get_node("Items").get_child_count()
	if pieces < 1 and _gm().state == 1:
		return "the bots never placed anything"
	return ""
