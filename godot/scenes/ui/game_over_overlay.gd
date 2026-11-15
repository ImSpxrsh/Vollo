extends CanvasLayer

const INPUT_GRACE := 0.22

@onready var root: Control = $Root
@onready var dim: ColorRect = $Root/Dim
@onready var panel: PanelContainer = %Panel
@onready var header_label: Label = %HeaderLabel
@onready var verdict_label: Label = %VerdictLabel
@onready var distance_label: Label = %DistanceLabel
@onready var dead_icon: TextureRect = %DeadIcon
@onready var new_best_badge: PanelContainer = %NewBestBadge
@onready var best_value: Label = %BestValue
@onready var bounces_value: Label = %BouncesValue
@onready var stars_label: Label = %StarsLabel
@onready var bounce_back_button: Button = %BounceBackButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var hint_label: Label = %HintLabel
@onready var space_cap: TextureRect = %SpaceCap

var shown := false
var last_distance := 0
var last_best := 0
var last_new_best := false
var last_bounces := 0
var _since_shown := 0.0
var _leaving := false
var _badge_tween: Tween
var _awards_label: Label
var _progress_label: Label
var _online_label: Label
var _replay_button: Button
var _header_art: Control
var _best_before_run := 0
var _hint_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameManager.run_over.connect(_on_run_over)
	GameManager.state_changed.connect(_on_state_changed)
	bounce_back_button.pressed.connect(restart)
	main_menu_button.pressed.connect(go_to_menu)
	var dead := UiArt.load_texture(SaveManager.get_variety_texture_path(SaveManager.selected_variety, true))
	dead_icon.texture = dead
	dead_icon.visible = dead != null
	var cap := UiArt.load_texture(UiArt.KEYCAP_SPACE)
	space_cap.texture = cap
	space_cap.visible = cap != null
	header_label.text = "CRASHED"
	_awards_label = Label.new()
	_awards_label.name = "AwardsLabel"
	_awards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_awards_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_awards_label.add_theme_font_size_override("font_size", 15)
	_awards_label.add_theme_color_override("font_color", Color("8A3B12"))
	_awards_label.visible = false
	stars_label.add_sibling(_awards_label)
	_progress_label = _small_label("ProgressLabel", Color("8A3B12"))
	_awards_label.add_sibling(_progress_label)
	_online_label = _small_label("OnlineLabel", Color("B5651D"))
	_progress_label.add_sibling(_online_label)
	Leaderboard.score_posted.connect(_on_score_posted)
	_replay_button = Button.new()
	_replay_button.name = "ReplayButton"
	_replay_button.text = "Watch Replay"
	_replay_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_replay_button.theme_type_variation = &"BBGhostButton"
	_replay_button.pressed.connect(watch_replay)
	main_menu_button.add_sibling(_replay_button)
	if GameManager.map_from_builder:
		main_menu_button.text = "Back to Builder"
	_best_before_run = SaveManager.high_score
	_apply_header_art()

func _small_label(node_name: String, color: Color) -> Label:
	var l := Label.new()
	l.name = node_name
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", color)
	l.visible = false
	return l

func _apply_header_art() -> void:
	var tex := UiArt.load_texture(UiArt.GAME_OVER_PANEL)
	if tex == null:
		return
	var k := tex.get_size() / Vector2(262.0, 176.0)
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(Vector2(30, 24) * k, Vector2(202, 30) * k)
	var header_art := TextureRect.new()
	header_art.name = "HeaderArt"
	header_art.texture = atlas
	header_art.custom_minimum_size = Vector2(0, 52)
	header_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_label.add_sibling(header_art)
	header_label.visible = false
	_header_art = header_art

func _on_run_over(distance: int, best: int, is_new_best: bool, bounces: int) -> void:
	last_distance = distance
	last_best = best
	last_new_best = is_new_best
	last_bounces = bounces
	stars_label.text = "COINS  %d THIS RUN  ·  %d TOTAL" % [GameManager.stars, SaveManager.total_stars]
	var lines: Array[String] = []
	for award_id in SaveManager.run_awards:
		var award := SaveManager.get_award(award_id)
		var variety := SaveManager.variety_for_award(award_id)
		var reward := ("  →  %s unlocked" % SaveManager.get_variety_name(variety)) if not variety.is_empty() else ""
		lines.append("★ %s%s" % [String(award.get("name", award_id)).to_upper(), reward])
	_awards_label.text = "\n".join(PackedStringArray(lines))
	_awards_label.visible = not lines.is_empty()
	var progress_lines := PackedStringArray()
	for line in [_best_delta_text(distance, best, is_new_best), _next_award_text()]:
		if not String(line).is_empty():
			progress_lines.append(line)
	_progress_label.text = "\n".join(progress_lines)
	_progress_label.visible = not progress_lines.is_empty()
	_online_label.text = _online_text(distance)
	_online_label.visible = not _online_label.text.is_empty()
	_apply_course_header()
	_replay_button.visible = not GameManager.tutorial
	show_results()

func _best_delta_text(distance: int, best: int, is_new_best: bool) -> String:
	if is_new_best:
		return "+%d m vs best" % (distance - _best_before_run) if _best_before_run > 0 else ""
	var short := best - distance
	return "Tied your best" if short <= 0 else "%d m short of your best" % short

func _apply_course_header() -> void:
	if not GameManager.is_custom_run():
		return
	header_label.visible = true
	if _header_art:
		_header_art.visible = false
	if GameManager.cleared:
		header_label.text = "TUTORIAL COMPLETE!" if GameManager.tutorial else "COURSE CLEAR!"
		_progress_label.text = "You're ready for the real thing. Press PLAY on the menu!" if GameManager.tutorial else "You beat %s." % String(GameManager.custom_map.get("name", "this map"))
	else:
		header_label.text = "CRASHED"
		_progress_label.text = "Map: %s" % String(GameManager.custom_map.get("name", "custom"))
	_progress_label.visible = true

func watch_replay() -> void:
	if not shown or _leaving:
		return
	var rec: Variant = get_tree().current_scene.get("recorder") if get_tree().current_scene else null
	if rec == null or String(rec.last_path).is_empty():
		AudioManager.play("deny")
		return
	var data := ReplayStore.load_replay(String(rec.last_path))
	if data.is_empty():
		AudioManager.play("deny")
		return
	_leaving = true
	AudioManager.play("click")
	GameManager.watch_replay(data)

func _online_text(distance: int) -> String:
	if GameManager.is_custom_run():
		return ""
	if not Leaderboard.is_configured() or GameManager.versus:
		return ""
	if not Leaderboard.is_logged_in():
		return "Log in on the LEADERBOARD to post your best online"
	if distance > Leaderboard.online_best:
		return "Posting to the leaderboard..."
	if Leaderboard.online_rank > 0:
		return "WORLD RANK  #%d  ·  online best %d m" % [Leaderboard.online_rank, Leaderboard.online_best]
	return ""

func _on_score_posted(online_best: int, rank: int) -> void:
	if _online_label == null or not shown:
		return
	_online_label.text = "NEW ONLINE BEST  ·  WORLD RANK  #%d" % rank if rank > 0 else "Online best %d m" % online_best
	_online_label.visible = true

func _next_award_text() -> String:
	var pick := ""
	var pick_progress := -1.0
	for award: Dictionary in SaveManager.AWARDS:
		var award_id := String(award.id)
		if SaveManager.has_award(award_id):
			continue
		var p := SaveManager.award_progress(award_id)
		if p > pick_progress:
			pick = award_id
			pick_progress = p
	if pick.is_empty():
		return "ALL AWARDS EARNED"
	return "NEXT AWARD: %s — %s" % [String(SaveManager.get_award(pick).name).to_upper(), SaveManager.award_progress_text(pick)]

func show_results() -> void:
	_stop_loops()
	shown = true
	_leaving = false
	visible = true
	_since_shown = 0.0
	distance_label.text = "0 m"
	best_value.text = "%d m" % last_best
	bounces_value.text = "%d" % last_bounces
	verdict_label.text = _run_verdict()
	new_best_badge.visible = last_new_best
	new_best_badge.get_parent().visible = last_new_best
	bounce_back_button.release_focus()

	dim.color.a = 0.0
	panel.modulate.a = 0.0
	await get_tree().process_frame
	if not shown:
		return
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.9, 0.9)
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true).set_parallel()
	t.tween_property(dim, "color:a", 0.62, 0.22)
	t.tween_property(panel, "modulate:a", 1.0, 0.18)
	t.tween_property(panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_method(_set_distance_text, 0.0, float(last_distance), 0.5).set_delay(0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var button_pop := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	bounce_back_button.pivot_offset = bounce_back_button.size * 0.5
	bounce_back_button.scale = Vector2(0.96, 0.96)
	button_pop.tween_interval(0.3)
	button_pop.tween_property(bounce_back_button, "scale", Vector2(1.04, 1.04), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	button_pop.tween_property(bounce_back_button, "scale", Vector2.ONE, 0.16)
	if last_new_best:
		new_best_badge.pivot_offset = new_best_badge.size * 0.5
		_badge_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_loops()
		_badge_tween.tween_property(new_best_badge, "scale", Vector2(1.08, 1.08), 0.45).set_trans(Tween.TRANS_SINE)
		_badge_tween.tween_property(new_best_badge, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	_hint_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_loops()
	_hint_tween.tween_property(hint_label, "modulate:a", 0.35, 0.7)
	_hint_tween.tween_property(hint_label, "modulate:a", 1.0, 0.7)
	await get_tree().create_timer(INPUT_GRACE, true, false, true).timeout
	if shown and is_inside_tree():
		bounce_back_button.grab_focus()

func _set_distance_text(v: float) -> void:
	distance_label.text = "%d m" % int(round(v))

func _run_verdict() -> String:
	if last_new_best:
		return "NEW GROUND. NOW GO FURTHER."
	if last_distance < 20:
		return "BUILD CLOSE. BUILD LATE. TRY AGAIN."
	if last_bounces < 2:
		return "TRAMPOLINES BUY YOU TIME."
	if last_distance >= maxi(1, int(last_best * 0.85)):
		return "SO CLOSE. ONE MORE RUN."
	return "EVERY CRASH TEACHES THE NEXT PATH."

func _stop_loops() -> void:
	if _badge_tween and _badge_tween.is_valid():
		_badge_tween.kill()
	if _hint_tween and _hint_tween.is_valid():
		_hint_tween.kill()
	new_best_badge.scale = Vector2.ONE
	hint_label.modulate.a = 1.0

func _process(delta: float) -> void:
	if shown:
		_since_shown += delta

func _accepting_input() -> bool:
	return shown and not _leaving and _since_shown >= INPUT_GRACE

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("restart") and _accepting_input():
		get_viewport().set_input_as_handled()
		restart()

func restart() -> void:
	if not shown or _leaving:
		return
	_leaving = true
	AudioManager.play("click")
	GameManager.restart_run()

func go_to_menu() -> void:
	if not shown or _leaving:
		return
	_leaving = true
	AudioManager.play("click")
	GameManager.go_to_menu()

func _on_state_changed(state: int) -> void:
	if state == GameManager.State.PLAYING:
		_best_before_run = SaveManager.high_score
	if state == GameManager.State.PLAYING and shown:
		shown = false
		_stop_loops()
		visible = false
