extends SceneTree

var failures := 0
var main: Node

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	await test_cooldown_blocks_then_recovers()
	await reset()
	await test_tools_have_independent_cooldowns()
	await reset()
	await test_placement_bounds_follow_ball_forever()
	await reset()
	await test_restart_clears_cooldowns()
	await reset()
	print("cooldown tests: %d failed" % failures)
	quit(failures)

func gm() -> Node:
	return root.get_node("GameManager")

func start_main() -> void:
	main = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame

func reset() -> void:
	paused = false
	Engine.time_scale = 1.0
	if main and is_instance_valid(main):
		main.queue_free()
		main = null
	await process_frame
	await process_frame

func check(value: bool, message: String) -> void:
	if value:
		print("PASS ", message)
	else:
		failures += 1
		print("FAIL ", message)

func wait_physics(count: int) -> void:
	for i in count:
		await physics_frame

func test_cooldown_blocks_then_recovers() -> void:
	await start_main()
	var placer := main.get_node("ItemPlacer")
	var ball := main.get_node("Ball") as Node2D
	gm().select_item(2)
	check(placer.place_at(ball.position + Vector2(430, 55)), "first floor places")
	check(not placer.place_at(ball.position + Vector2(650, 55)), "cooldown blocks immediate duplicate")
	check(gm().cooldown_remaining(2) > 0.0, "remaining cooldown is observable")
	await wait_physics(28)
	check(placer.place_at(ball.position + Vector2(650, 55)), "floor places again after cooldown")

func test_tools_have_independent_cooldowns() -> void:
	await start_main()
	var placer := main.get_node("ItemPlacer")
	var ball := main.get_node("Ball") as Node2D
	gm().select_item(2)
	check(placer.place_at(ball.position + Vector2(390, 55)), "floor starts its cooldown")
	gm().select_item(1)
	check(placer.place_at(ball.position + Vector2(620, 10)), "ramp remains ready while floor cools")

func test_placement_bounds_follow_ball_forever() -> void:
	await start_main()
	var placer := main.get_node("ItemPlacer")
	var ball := main.get_node("Ball") as Node2D
	ball.position = Vector2(5000, 400)
	gm().select_item(2)
	check(placer.place_at(Vector2(5550, 455)), "placement range follows ball beyond first screen")
	check(not placer.place_at(Vector2(3500, 455)), "placement too far behind is rejected")

func test_restart_clears_cooldowns() -> void:
	await start_main()
	var placer := main.get_node("ItemPlacer")
	var ball := main.get_node("Ball") as Node2D
	gm().select_item(0)
	check(placer.place_at(ball.position + Vector2(390, 20)), "trampoline starts cooldown")
	check(not gm().is_ready(0), "trampoline is cooling down")
	gm().start_run()
	check(gm().is_ready(0), "new run clears every cooldown")
