class_name Ball
extends RigidBody2D

signal died
signal shield_changed(active: bool)
signal boost_changed(active: bool)

const RADIUS := 32.0
const START_SPEED := 300.0
const MAX_SPEED := 720.0
const ACCELERATION := 7.0
const FALL_LIMIT_Y := 760.0
const TRAMPOLINE_VELOCITY := -650.0
const RAMP_UP_VELOCITY := -390.0
const INVULN_TIME := 0.75
const TRAIL_POINTS := 24
const SUNNY := Color("FFD84A")
const SHIELDED := Color("4CC9FF")
const BOOST_TIME := 1.6
## After a hit the ball blinks for this long, costs no more hearts and passes
## straight through walls, spikes and enemies instead of being knocked away.
const HIT_INVULN := 1.2
const RESCUE_Y := 250.0
const CLUTCH_RADIUS := 230.0
const STOMP_WINDOW := 0.6
const STOMP_VY := -560.0
const VS_CLUTCH_SPEED := 18.0
const VS_STOMP_SPEED := 30.0
const VS_BOOST_SPEED := 40.0
const VS_HIT_SPEED_MULT := 0.82
const VS_MIN_SPEED := 240.0
const BOOST_SPEED_MULT := 1.3
const SPRITE_DIAMETER := 70.0
const BOUNCE_SPARKLE := preload("res://assets/art/particle_bounce.png")
const DEATH_PIECES := preload("res://assets/art/particle_death.png")

var speed := START_SPEED
var has_shield := false
var dead := false
var start_x := 0.0
@export var player_index := 0
var private_visibility := 0
var variety_id := "yellow"
var variety_color := SUNNY
var boost_left := 0.0

var _pending_vy := NAN
var _pending_pos := Vector2(NAN, NAN)
var _pending_y := NAN
var _stomp_charge := 0.0
var _invuln_left := 0.0
## Time left passing through hazards after a hit (see HIT_INVULN).
var _ghost_left := 0.0
var _item_cooldown := 0.0
var _roll_angle := 0.0
var _form_root: Node2D
var _body_sprite: Sprite2D
var _boost_glow: Polygon2D
var _shield_ring: Line2D
var _squash_tween: Tween
var _last_vertical_velocity := 0.0
var _was_grounded := false

@onready var visual: Node2D = $Visual
@onready var trail: Line2D = $Trail
@onready var hazard_sensor: Area2D = $HazardSensor

func _ready() -> void:
	start_x = global_position.x
	variety_id = GameManager.versus_varieties[player_index] if GameManager.versus else SaveManager.selected_variety
	variety_color = SaveManager.get_variety_color(variety_id)
	collision_layer = WorldConst.LAYER_BALL
	collision_mask = WorldConst.LAYER_WORLD | WorldConst.LAYER_HAZARD
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	contact_monitor = true
	max_contacts_reported = 8
	lock_rotation = true
	_build_visual()
	_setup_trail()
	if SaveManager.has_upgrade("head_start") and not GameManager.versus:
		has_shield = true
	body_entered.connect(_on_body_entered)
	hazard_sensor.area_entered.connect(_on_area_entered)
	hazard_sensor.body_entered.connect(_on_body_entered)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var velocity := state.linear_velocity
	if not is_nan(_pending_y):
		var xf := state.transform
		xf.origin.y = _pending_y
		state.transform = xf
		_pending_y = NAN
	if not is_nan(_pending_pos.x):
		var moved := state.transform
		moved.origin = _pending_pos
		state.transform = moved
		_pending_pos = Vector2(NAN, NAN)
		velocity = Vector2.ZERO
	if not is_nan(_pending_vy):
		velocity.y = _pending_vy
		_pending_vy = NAN
	if GameManager.is_alive(player_index) and not dead:
		velocity.x = speed * (BOOST_SPEED_MULT if boost_left > 0.0 else 1.0)
	state.linear_velocity = velocity

func _physics_process(delta: float) -> void:
	if dead:
		return
	_invuln_left = maxf(0.0, _invuln_left - delta)
	if _ghost_left > 0.0:
		_ghost_left = maxf(0.0, _ghost_left - delta)
		if _ghost_left <= 0.0:
			_set_ghost(false)
	_item_cooldown = maxf(0.0, _item_cooldown - delta)
	_stomp_charge = maxf(0.0, _stomp_charge - delta)
	if boost_left > 0.0:
		boost_left -= delta
		if boost_left <= 0.0:
			boost_left = 0.0
			boost_changed.emit(false)
			GameManager.set_boost(false, player_index)
	if GameManager.is_alive(player_index):
		var travelled_px := maxf(0.0, global_position.x - start_x)
		var late_run_push := minf(5.0, travelled_px / 9000.0)
		var accel := 0.0 if GameManager.tutorial else ACCELERATION * 0.55 if GameManager.is_guided_level(player_index) else ACCELERATION + late_run_push
		speed = minf(MAX_SPEED, speed + accel * delta)
		GameManager.set_travelled(maxi(0, int((global_position.x - start_x) / WorldConst.METRE)), player_index)
		var grounded := false
		for contact in get_colliding_bodies():
			if contact.is_in_group("ground") or contact.is_in_group("floor") or contact.is_in_group("ramp") or contact.is_in_group("trampoline"):
				grounded = true
				break
		GameManager.set_airborne(not grounded, player_index)
		if grounded and not _was_grounded and _last_vertical_velocity > 250.0:
			_land_squash(_last_vertical_velocity)
		_was_grounded = grounded
	if global_position.y > FALL_LIMIT_Y:
		_fall_out()
	for body in get_colliding_bodies():
		_handle_body(body)
	_last_vertical_velocity = linear_velocity.y

func _process(delta: float) -> void:
	_roll_angle += delta * linear_velocity.x / RADIUS
	if _form_root:
		_form_root.rotation = _roll_angle
	if _boost_glow:
		_boost_glow.visible = boost_left > 0.0
		if _boost_glow.visible:
			_boost_glow.scale = Vector2.ONE * (1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.03))
	if _shield_ring:
		_shield_ring.visible = has_shield
		if has_shield:
			_shield_ring.rotation -= delta * 1.7
			_shield_ring.modulate.a = 0.68 + 0.25 * sin(Time.get_ticks_msec() * 0.006)
	visual.modulate.a = 0.35 if (boost_left <= 0.0 and _invuln_left > 0.0 and int(_invuln_left * 18.0) % 2 == 0) else 1.0
	_update_trail()

func bounce(vy: float) -> void:
	if dead:
		return
	var clutch := is_near_hazard(CLUTCH_RADIUS)
	_stomp_charge = STOMP_WINDOW
	_pending_vy = vy
	linear_velocity.y = vy
	_stretch(Vector2(0.76, 1.28))
	_burst(global_position + Vector2(0, RADIUS), variety_color, 14, 250.0, 0.42)
	_pop_sprite(BOUNCE_SPARKLE, global_position + Vector2(0, RADIUS * 0.6), 0.32)
	AudioManager.play("boing", 0.04, 0.0, 1.0 + (0.08 * GameManager.player(player_index).combo if clutch else 0.0))
	GameManager.register_bounce(clutch, global_position, player_index)
	if clutch:
		versus_speed_change(VS_CLUTCH_SPEED)
	if clutch:
		AudioManager.play("clutch", 0.02, -3.0, 1.0 + 0.06 * GameManager.player(player_index).combo)
		var c: int = GameManager.player(player_index).combo
		_popup("CLUTCH!" if c <= 1 else "CLUTCH  x%d" % c, Color("FFD166"))
	GameManager.add_trauma(0.14)
	GameManager.hitstop(0.025)

func kill() -> void:
	if dead or _invuln_left > 0.0 or boost_left > 0.0 or not GameManager.is_alive(player_index):
		return
	if has_shield:
		_consume_shield()
		return
	var left: int = GameManager.hurt_variety(player_index)
	if left > 0:
		_take_hit(left)
		return
	_die()

func is_near_hazard(radius: float) -> bool:
	for node in get_tree().get_nodes_in_group("hazard"):
		var n := node as Node2D
		if n == null or not is_instance_valid(n):
			continue
		var closest := n.global_position
		if n.is_in_group("hazard_wall"):
			closest = Geometry2D.get_closest_point_to_segment(global_position, n.global_position, n.to_global(Vector2(0, -256)))
		if closest.distance_to(global_position) <= radius:
			return true
	return false

func hit_by_enemy(enemy: Node2D) -> void:
	if dead or enemy == null or not is_instance_valid(enemy) or not enemy.is_in_group("hazard"):
		return
	var from_above := linear_velocity.y > 80.0 and global_position.y < enemy.global_position.y - 12.0
	if not (from_above or _stomp_charge > 0.0 or boost_left > 0.0):
		kill()
		return
	if enemy.has_method("stomp"):
		enemy.call("stomp")
	_stomp_charge = 0.0
	_pending_vy = STOMP_VY
	linear_velocity.y = STOMP_VY
	_stretch(Vector2(1.3, 0.72))
	_burst(enemy.global_position, Color("B06BFF"), 22, 340.0, 0.5)
	AudioManager.play("stomp", 0.05, 0.0)
	GameManager.register_stomp(enemy.global_position, player_index)
	versus_speed_change(VS_STOMP_SPEED)
	GameManager.add_trauma(0.3)
	GameManager.hitstop(0.06)
	_popup("BOUNCED BACK!  +%d m" % (GameManager.STOMP_BONUS * GameManager.player(player_index).combo), Color("C79BFF"))

func versus_speed_change(amount: float, mult := 1.0) -> void:
	if not GameManager.versus:
		return
	speed = clampf(speed * mult + amount, VS_MIN_SPEED, MAX_SPEED)

func _take_hit(hearts_left: int) -> void:
	versus_speed_change(0.0, VS_HIT_SPEED_MULT)
	_invuln_left = HIT_INVULN
	# No knockback: keep the current path and ghost through whatever was hit,
	# so one mistake costs exactly one heart.
	_ghost_left = HIT_INVULN
	_set_ghost(true)
	_stretch(Vector2(1.3, 0.7))
	_burst(global_position, WorldConst.C_HAZARD, 18, 320.0, 0.5)
	AudioManager.play("hurt", 0.04, -2.0)
	GameManager.hitstop(0.05)
	_popup("OUCH!  %d %s LEFT" % [hearts_left, "HEART" if hearts_left == 1 else "HEARTS"], Color("FF6B6B"))
	_update_hurt_look(hearts_left)

## While ghosting, solid hazards (red walls) stop colliding with the ball;
## spikes and enemies are already ignored because kill() checks _invuln_left.
func _set_ghost(on: bool) -> void:
	if on:
		collision_mask &= ~WorldConst.LAYER_HAZARD
	else:
		collision_mask |= WorldConst.LAYER_HAZARD

func teleport(pos: Vector2) -> void:
	_pending_pos = pos
	_pending_y = NAN
	_pending_vy = NAN
	global_position = pos
	linear_velocity = Vector2.ZERO
	speed = START_SPEED
	_ghost_left = 0.0
	_set_ghost(false)
	_invuln_left = 0.6
	_stomp_charge = 0.0
	if trail:
		trail.clear_points()

func _fall_out() -> void:
	if dead or not GameManager.is_alive(player_index):
		return
	# Falling while still blinking from a hit is part of that same mistake:
	# bounce back without taking a second heart.
	var free_rescue := _ghost_left > 0.0
	var left: int = GameManager.player(player_index).health
	if not free_rescue:
		versus_speed_change(0.0, VS_HIT_SPEED_MULT)
		left = GameManager.hurt_variety(player_index)
		if left <= 0:
			_die()
			return
	_ghost_left = 0.0
	_set_ghost(false)
	_invuln_left = HIT_INVULN + 0.4
	_pending_y = RESCUE_Y
	_pending_vy = -120.0
	linear_velocity.y = -120.0
	AudioManager.play("hurt", 0.04, -4.0, 1.2)
	GameManager.add_trauma(0.35)
	_popup("BOUNCE BACK!  %d %s LEFT" % [left, "HEART" if left == 1 else "HEARTS"], Color("7CE0FF"))
	_update_hurt_look(left)

func _update_hurt_look(hearts_left: int) -> void:
	if _body_sprite == null or hearts_left != 1:
		return
	var cracked := UiArt.load_texture(SaveManager.get_variety_texture_path(variety_id, true))
	if cracked:
		_body_sprite.texture = cracked
		_body_sprite.scale = Vector2.ONE * (SPRITE_DIAMETER * 1.12 / maxf(cracked.get_width(), 1.0))

func _popup(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.02))
	label.add_theme_constant_override("outline_size", 8)
	label.z_index = 20
	get_parent().add_child(label)
	if private_visibility != 0:
		label.visibility_layer = private_visibility
	label.global_position = global_position + Vector2(-80, -86)
	var tw := label.create_tween().set_parallel(true)
	tw.tween_property(label, "global_position:y", label.global_position.y - 48.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.5)
	tw.chain().tween_callback(label.queue_free)

func _die() -> void:
	dead = true
	if GameManager.versus:
		set_deferred("freeze", true)
	if _body_sprite:
		var dead_tex := UiArt.load_texture(SaveManager.get_variety_texture_path(variety_id, true))
		if dead_tex:
			_body_sprite.texture = dead_tex
			_body_sprite.scale = Vector2.ONE * (SPRITE_DIAMETER * 1.15 / maxf(dead_tex.get_width(), 1.0))
		_form_root.rotation = 0.0
	_burst(global_position, WorldConst.C_HAZARD, 30, 420.0, 0.75, true)
	_pop_sprite(DEATH_PIECES, global_position, 0.5, true)
	_stretch(Vector2(1.38, 0.62))
	AudioManager.play("death")
	died.emit()
	GameManager.end_run(player_index)

func give_shield() -> void:
	if dead:
		return
	has_shield = true
	shield_changed.emit(true)
	AudioManager.play("pickup")

func boost() -> void:
	if dead:
		return
	var was_boosting := boost_left > 0.0
	boost_left = BOOST_TIME
	versus_speed_change(VS_BOOST_SPEED)
	_stretch(Vector2(1.3, 0.8))
	_burst(global_position, Color("4ADE80"), 20, 320.0, 0.45)
	AudioManager.play("pickup", 0.06, -2.0)
	GameManager.add_trauma(0.18)
	if not was_boosting:
		boost_changed.emit(true)
		GameManager.set_boost(true, player_index)

func get_fall_limit_y() -> float:
	return FALL_LIMIT_Y

func _on_body_entered(body: Node) -> void:
	_handle_body(body)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		hit_by_enemy(area)
	elif area.is_in_group("hazard"):
		kill()

func _handle_body(body: Node) -> void:
	if dead:
		return
	if body.is_in_group("hazard"):
		kill()
	elif body.is_in_group("ceiling"):
		_use_ceiling()
	elif body.is_in_group("trampoline"):
		_use_trampoline(body)
	elif body.is_in_group("ramp"):
		_use_ramp(body)

func _use_trampoline(body: Node) -> void:
	if _item_cooldown > 0.0:
		return
	_item_cooldown = 0.22
	bounce(TRAMPOLINE_VELOCITY)
	if body.has_method("react"):
		body.call("react")

func _use_ramp(body: Node) -> void:
	if _item_cooldown > 0.0:
		return
	_item_cooldown = 0.18
	var flipped_value: Variant = body.get("flipped")
	_pending_vy = 280.0 if flipped_value is bool and flipped_value else RAMP_UP_VELOCITY
	linear_velocity.y = _pending_vy
	_stretch(Vector2(1.18, 0.82))
	AudioManager.play("boing", 0.06, -6.0)
	if body.has_method("react"):
		body.call("react")

func _use_ceiling() -> void:
	if linear_velocity.y >= 0.0:
		return
	_pending_vy = 150.0
	linear_velocity.y = 150.0
	_stretch(Vector2(1.18, 0.82))
	GameManager.add_trauma(0.04)

func _consume_shield() -> void:
	has_shield = false
	_invuln_left = INVULN_TIME
	shield_changed.emit(false)
	GameManager.register_shield_save(player_index)
	_pending_vy = -520.0
	linear_velocity.y = -520.0
	_burst(global_position, SHIELDED, 30, 360.0, 0.55, true)
	GameManager.add_trauma(0.38)
	AudioManager.play("pickup")

func _build_visual() -> void:
	_form_root = Node2D.new()
	_form_root.name = "Variety"
	visual.add_child(_form_root)
	_boost_glow = Polygon2D.new()
	_boost_glow.polygon = _circle_points(RADIUS + 10.0, 32)
	_boost_glow.color = Color(0.29, 0.87, 0.5, 0.35)
	_boost_glow.visible = false
	visual.add_child(_boost_glow)
	visual.move_child(_boost_glow, 0)
	var tex := UiArt.load_texture(SaveManager.get_variety_texture_path(variety_id))
	if tex:
		_body_sprite = Sprite2D.new()
		_body_sprite.name = "Body"
		_body_sprite.texture = tex
		_body_sprite.scale = Vector2.ONE * (SPRITE_DIAMETER / maxf(tex.get_width(), 1.0))
		_form_root.add_child(_body_sprite)
	else:
		var body := Polygon2D.new()
		body.polygon = _circle_points(RADIUS, 40)
		body.color = variety_color
		_form_root.add_child(body)
	_shield_ring = Line2D.new()
	_shield_ring.points = _circle_points(RADIUS + 12.0, 40)
	_shield_ring.closed = true
	_shield_ring.width = 4.0
	_shield_ring.default_color = SHIELDED
	_shield_ring.visible = false
	visual.add_child(_shield_ring)

func _pop_sprite(tex: Texture2D, pos: Vector2, size_scale: float, always := false) -> void:
	var fx := Sprite2D.new()
	fx.texture = tex
	fx.global_position = pos
	fx.scale = Vector2.ONE * size_scale * 0.6
	fx.z_index = 5
	fx.process_mode = Node.PROCESS_MODE_ALWAYS if always else Node.PROCESS_MODE_INHERIT
	get_parent().add_child(fx)
	var tw := fx.create_tween().set_parallel(true)
	if always:
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(fx, "scale", Vector2.ONE * size_scale * 1.25, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(fx, "modulate:a", 0.0, 0.45).set_delay(0.12)
	tw.chain().tween_callback(fx.queue_free)

func _stretch(value: Vector2) -> void:
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	visual.scale = value
	_squash_tween = create_tween()
	_squash_tween.tween_property(visual, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _land_squash(impact_velocity: float) -> void:
	var amount := clampf(impact_velocity / 1100.0, 0.12, 0.3)
	_stretch(Vector2(1.0 + amount, 1.0 - amount))

func _burst(pos: Vector2, color: Color, amount: int, velocity: float, life: float, always := false) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = life
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = velocity * 0.35
	particles.initial_velocity_max = velocity
	particles.gravity = Vector2(0, 500)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 7.0
	particles.color = color
	particles.process_mode = Node.PROCESS_MODE_ALWAYS if always else Node.PROCESS_MODE_INHERIT
	get_parent().add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

func _setup_trail() -> void:
	trail.top_level = true
	trail.global_position = Vector2.ZERO
	trail.width = RADIUS * 0.72
	trail.joint_mode = Line2D.LINE_JOINT_ROUND
	var gradient := Gradient.new()
	gradient.set_color(0, Color(variety_color, 0.0))
	gradient.set_color(1, Color(variety_color, 0.42))
	trail.gradient = gradient

func _update_trail() -> void:
	if dead:
		if trail.get_point_count() > 0:
			trail.remove_point(0)
		return
	trail.add_point(global_position)
	while trail.get_point_count() > TRAIL_POINTS:
		trail.remove_point(0)

static func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		points.append(Vector2.from_angle(TAU * float(i) / count) * radius)
	return points
