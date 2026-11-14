extends BaseItem

const IDLE_TEXTURE := preload("res://assets/art/trampoline_idle.png")
const BOUNCE_TEXTURE := preload("res://assets/art/trampoline_bouncing.png")

var _art: Sprite2D
var _bounce_tween: Tween

func _build_visual() -> void:
	visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)
	_art = Sprite2D.new()
	_art.name = "TrampolineArt"
	_art.texture = IDLE_TEXTURE
	var k := (size.x + 16.0) / IDLE_TEXTURE.get_width()
	_art.scale = Vector2(k, k)
	_art.offset.y = IDLE_TEXTURE.get_height() * 0.5
	_art.position.y = -size.y * 0.5 - 6.0
	_art.use_parent_material = true
	visual.add_child(_art)

func react() -> void:
	if visual == null:
		return
	_art.texture = BOUNCE_TEXTURE
	_art.offset.y = BOUNCE_TEXTURE.get_height() * 0.5 - (BOUNCE_TEXTURE.get_height() - IDLE_TEXTURE.get_height())
	if _bounce_tween and _bounce_tween.is_valid():
		_bounce_tween.kill()
	visual.scale = Vector2(1.1, 0.75)
	_bounce_tween = create_tween()
	_bounce_tween.tween_property(visual, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_bounce_tween.parallel().tween_callback(_back_to_idle).set_delay(0.22)

func _back_to_idle() -> void:
	_art.texture = IDLE_TEXTURE
	_art.offset.y = IDLE_TEXTURE.get_height() * 0.5
