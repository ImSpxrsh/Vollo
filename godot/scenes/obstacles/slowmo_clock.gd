extends Pickup

func _ready() -> void:
	art = preload("res://assets/art/slowmo_clock.png")
	art_size = 62.0
	radius = 30.0
	super._ready()

func _process(delta: float) -> void:
	super._process(delta)
	if _sprite and not _taken:
		_sprite.rotation = sin(_time * 1.6) * 0.18

func _collect(_ball: Node2D) -> void:
	AudioManager.play("pickup", 0.0, -2.0)
	GameManager.start_slowmo()
