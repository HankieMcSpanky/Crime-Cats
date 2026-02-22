extends CanvasLayer
class_name GameHUD

@export var game_manager_path: NodePath

@onready var suspicion_bar: ProgressBar = $SuspicionContainer/SuspicionBar
@onready var suspicion_label: Label = $SuspicionContainer/SuspicionLabel
@onready var score_label: Label = $ScoreContainer/ScoreLabel
@onready var combo_label: Label = $ScoreContainer/ComboLabel
@onready var combo_timer_bar: ProgressBar = $ScoreContainer/ComboTimerBar
@onready var crime_feed: VBoxContainer = $CrimeFeedContainer/CrimeFeed
@onready var visibility_icon: TextureRect = $VisibilityContainer/VisibilityIcon
@onready var game_over_panel: Panel = $GameOverPanel

var _game_manager: GameManager
var _crime_feed_entries: Array[Control] = []


func _ready() -> void:
	if game_manager_path:
		_game_manager = get_node(game_manager_path) as GameManager
	else:
		_game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	
	if _game_manager:
		_game_manager.score_changed.connect(_on_score_changed)
		_game_manager.combo_changed.connect(_on_combo_changed)
		_game_manager.suspicion_changed.connect(_on_suspicion_changed)
		_game_manager.crime_committed.connect(_on_crime_committed)
		_game_manager.game_over.connect(_on_game_over)
	
	_update_score(0)
	_update_combo(1.0, 0)
	_update_suspicion(0)
	
	if game_over_panel:
		game_over_panel.visible = false


func _process(_delta: float) -> void:
	if _game_manager:
		_update_combo_timer()


func _update_score(new_score: int) -> void:
	if score_label:
		score_label.text = "SCORE: %d" % new_score


func _update_combo(multiplier: float, count: int) -> void:
	if combo_label:
		if count > 1:
			combo_label.text = "x%.1f COMBO!" % multiplier
			combo_label.visible = true
		else:
			combo_label.visible = false


func _update_combo_timer() -> void:
	if combo_timer_bar and _game_manager:
		var timer = _game_manager.get_combo_timer()
		var max_time = _game_manager.combo_window
		combo_timer_bar.value = (timer / max_time) * 100
		combo_timer_bar.visible = timer > 0


func _update_suspicion(new_suspicion: float) -> void:
	if suspicion_bar and _game_manager:
		var percent = (new_suspicion / _game_manager.max_suspicion) * 100
		suspicion_bar.value = percent
		
		# Change color based on suspicion level
		var style = suspicion_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if style:
			if percent < 33:
				style.bg_color = Color(0.2, 0.8, 0.2)  # Green
			elif percent < 66:
				style.bg_color = Color(1.0, 0.8, 0.0)  # Yellow
			else:
				style.bg_color = Color(1.0, 0.2, 0.2)  # Red


func _on_score_changed(new_score: int) -> void:
	_update_score(new_score)


func _on_combo_changed(multiplier: float, count: int) -> void:
	_update_combo(multiplier, count)


func _on_suspicion_changed(new_suspicion: float) -> void:
	_update_suspicion(new_suspicion)


func _on_crime_committed(crime_type: String, points: int, _position: Vector3) -> void:
	_add_crime_feed_entry(crime_type, points)


func _add_crime_feed_entry(crime_type: String, points: int) -> void:
	if not crime_feed:
		return
	
	var entry = Label.new()
	entry.text = "%s +%d" % [_get_crime_display_name(crime_type), points]
	entry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	entry.add_theme_color_override("font_color", Color(1, 1, 0.5))
	entry.add_theme_font_size_override("font_size", 18)
	
	crime_feed.add_child(entry)
	_crime_feed_entries.append(entry)
	
	# Animate and remove after delay
	var tween = create_tween()
	tween.tween_property(entry, "modulate:a", 0.0, 2.0).set_delay(1.0)
	tween.tween_callback(func():
		_crime_feed_entries.erase(entry)
		entry.queue_free()
	)
	
	# Limit feed entries
	while _crime_feed_entries.size() > 5:
		var old_entry = _crime_feed_entries.pop_front()
		old_entry.queue_free()


func _get_crime_display_name(crime_type: String) -> String:
	match crime_type:
		"knock": return "Knocked!"
		"break": return "Broken!"
		"steal": return "Stolen!"
		"scratch": return "Scratched!"
		"curtain": return "Curtain Down!"
		"trash": return "Trash Spilled!"
		"toilet_paper": return "Unrolled!"
		_: return crime_type.capitalize()


func _on_game_over() -> void:
	if game_over_panel:
		game_over_panel.visible = true
		
		var final_score_label = game_over_panel.get_node_or_null("FinalScoreLabel") as Label
		if final_score_label and _game_manager:
			final_score_label.text = "FINAL SCORE: %d" % _game_manager.get_score()


func set_visibility_state(is_hidden: bool) -> void:
	if visibility_icon:
		# Change icon color based on visibility
		if is_hidden:
			visibility_icon.modulate = Color(0.3, 0.8, 0.3)  # Green - safe
		else:
			visibility_icon.modulate = Color(1.0, 0.5, 0.5)  # Red - exposed
