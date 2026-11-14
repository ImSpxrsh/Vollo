class_name Spike
extends Area2D

@export var pulse_speed := 3.2
@export var pulse_amount := 0.12

var _t := 0.0
var _reduce_motion := false
var _stripes: Node2D
const SPIKES_TEXTURE := preload("res://assets/art/spike.png")
const HC_C_WARN := Color("FFD02A")
var _hc_outline := PackedVector2Array([Vector2(-30.0, 6.0), Vector2(0.0, -72.0), Vector2(30.0, 6.0)])
const HC_WIDTH := 7.0
const HC_DASH := 10.0

@onready var _glow: Polygon2D = $Glow
@onready var _core: Polygon2D = $Core

func _ready() -> void:
	add_to_group("hazard")
	add_to_group("spike")
	_t = randf() * TAU
	var art := Sprite2D.new()
	art.name = "SpikeArt"
	art.texture = SPIKES_TEXTURE
	var k := 66.0 / SPIKES_TEXTURE.get_height()
	art.scale = Vector2(k, k)
	art.offset.y = -SPIKES_TEXTURE.get_height() * 0.5
	art.position = Vector2(0.0, 4.0)
	art.z_index = -1
	add_child(art)
	$Glow.show()
	$Glow.modulate.a = 0.7
	$Glow.color = Color(0.62, 0.3, 0.9, 0.35)
	$Core.hide()
	_stripes = Node2D.new()
	_stripes.name = "HazardStripes"
	_stripes.z_index = 1
	_stripes.draw.connect(_draw_stripes)
	add_child(_stripes)
	body_entered.connect(_on_body_entered)
	SaveManager.settings_changed.connect(_apply_settings)
	_apply_settings()

func _apply_settings() -> void:
	_stripes.visible = SaveManager.high_contrast_hazards
	_reduce_motion = SaveManager.reduce_motion
	if _reduce_motion:
		_glow.scale = Vector2.ONE
		_glow.modulate.a = 0.75
		_core.modulate = Color.WHITE
	set_process(not _reduce_motion)

func _draw_stripes() -> void:
	var n := _hc_outline.size()
	var dash_index := 0
	for i in n:
		var a := _hc_outline[i]
		var b := _hc_outline[(i + 1) % n]
		var length := a.distance_to(b)
		var d := 0.0
		while d < length:
			var e := minf(d + HC_DASH, length)
			var c := Color.BLACK if dash_index % 2 == 0 else HC_C_WARN
			_stripes.draw_line(a.lerp(b, d / length), a.lerp(b, e / length), c, HC_WIDTH)
			d = e
			dash_index += 1
	for p: Vector2 in _hc_outline:
		_stripes.draw_circle(p, HC_WIDTH * 0.5, Color.BLACK)

func _process(delta: float) -> void:
	_t += delta * pulse_speed
	var s := sin(_t)
	_glow.scale = Vector2.ONE * (1.0 + pulse_amount * (0.5 + 0.5 * s))
	_glow.modulate.a = 0.75 + 0.25 * s
	_core.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.25, 1.1, 1.15), 0.5 + 0.5 * s)

func _on_body_entered(body: Node2D) -> void:
	if body is RigidBody2D and body.has_method("kill"):
		body.call_deferred("kill")
