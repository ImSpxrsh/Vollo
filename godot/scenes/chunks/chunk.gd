class_name Chunk
extends Node2D

@export_range(0.0, 1.0) var difficulty := 0.0
@export var weight := 1.0
@export var min_distance := 0
@export_range(0.0, 1.0) var bubble_chance := 0.15

var rng: RandomNumberGenerator

func _ready() -> void:
	add_to_group("chunk")
	for b in find_children("*", "", true, false):
		if b.is_in_group("bubble") or b is ShieldBubble:
			var roll := rng.randf() if rng else randf()
			if roll >= bubble_chance:
				b.queue_free()

func get_exit_anchor() -> Marker2D:
	return get_node("ExitAnchor") as Marker2D

func get_length() -> float:
	return get_exit_anchor().position.x

func get_pit_ranges() -> Array[Vector2]:
	var spans: Array[Vector2] = []
	for c in get_children():
		if c is GroundSegment and not (c as GroundSegment).ceiling:
			var g := c as GroundSegment
			spans.append(Vector2(g.position.x, g.position.x + g.width))
	spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var pits: Array[Vector2] = []
	var cursor := 0.0
	for s in spans:
		if s.x > cursor + 0.5:
			pits.append(Vector2(cursor, s.x))
		cursor = maxf(cursor, s.y)
	if cursor < get_length() - 0.5:
		pits.append(Vector2(cursor, get_length()))
	return pits
