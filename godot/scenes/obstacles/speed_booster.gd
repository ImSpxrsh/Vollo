extends Pickup

func _ready() -> void:
	art = preload("res://assets/art/speed_booster.png")
	art_size = 92.0
	radius = 34.0
	bob_height = 4.0
	super._ready()

func _collect(ball: Node2D) -> void:
	if ball.has_method("boost"):
		ball.call_deferred("boost")
