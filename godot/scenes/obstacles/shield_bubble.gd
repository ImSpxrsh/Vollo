class_name ShieldBubble
extends Area2D

const RADIUS := 26.0
const SEGMENTS := 32
const ART := preload("res://assets/art/shield_pickup.png")

@export var bob_height := 10.0
@export var bob_speed := 2.4

var _t := 0.0
var _taken := false

@onready var _visual: Node2D = $Visual
@onready var _fill: Polygon2D = $Visual/Fill
@onready var _rim: Line2D = $Visual/Rim
@onready var _shine: Line2D = $Visual/Shine

func _ready() -> void:
	add_to_group("bubble")
	_t = randf() * TAU
	var pts := PackedVector2Array()
	for i in SEGMENTS:
		pts.append(Vector2.from_angle(TAU * i / SEGMENTS) * RADIUS)
	_fill.polygon = pts
	_rim.points = pts
	var arc := PackedVector2Array()
	for i in 7:
		arc.append(Vector2.from_angle(lerpf(PI * 1.05, PI * 1.45, i / 6.0)) * (RADIUS - 7.0))
	_shine.points = arc
	_fill.visible = false
	_shine.visible = false
	_rim.modulate.a = 0.35
	var art := Sprite2D.new()
	art.name = "Art"
	art.texture = ART
	art.scale = Vector2.ONE * (RADIUS * 3.0 / ART.get_width())
	_visual.add_child(art)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _taken:
		return
	_t += delta * bob_speed
	_visual.position.y = sin(_t) * bob_height
	_visual.scale = Vector2(1.0 + 0.04 * sin(_t * 1.7), 1.0 - 0.04 * sin(_t * 1.7))

func _on_body_entered(body: Node2D) -> void:
	if _taken or not (body is RigidBody2D and body.has_method("give_shield")):
		return
	_taken = true
	body.call_deferred("give_shield")
	set_deferred("monitoring", false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_visual, "scale", Vector2.ONE * 1.8, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_visual, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(queue_free)
