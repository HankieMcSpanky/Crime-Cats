extends Node
class_name GameManager

signal score_changed(new_score: int)
signal combo_changed(multiplier: float, combo_count: int)
signal suspicion_changed(new_suspicion: float)
signal game_over()
signal crime_committed(crime_type: String, points: int, position: Vector3)

@export_group("Scoring")
@export var combo_window: float = 5.0
@export var max_combo_multiplier: float = 3.5

@export_group("Suspicion")
@export var max_suspicion: float = 100.0
@export var suspicion_decay_rate: float = 3.0
@export var hidden_decay_rate: float = 8.0
@export var different_room_decay_rate: float = 5.0

var score: int = 0
var combo_count: int = 0
var combo_multiplier: float = 1.0
var combo_timer: float = 0.0

var suspicion: float = 0.0
var is_game_over: bool = false

var _player: Node3D
var _owner_ai: Node3D


func _ready() -> void:
	add_to_group("game_manager")


func _process(delta: float) -> void:
	if is_game_over:
		return
	
	_update_combo_timer(delta)
	_update_suspicion(delta)


func _update_combo_timer(delta: float) -> void:
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			_reset_combo()


func _update_suspicion(delta: float) -> void:
	# Decay suspicion when not being observed
	var decay_rate = suspicion_decay_rate
	
	if _player and _player.has_method("is_hidden") and _player.is_hidden():
		decay_rate = hidden_decay_rate
	
	if suspicion > 0:
		suspicion = max(0, suspicion - decay_rate * delta)
		suspicion_changed.emit(suspicion)


func on_crime_committed(crime_type: String, base_points: int, position: Vector3) -> void:
	if is_game_over:
		return
	
	# Apply combo multiplier
	var points = int(base_points * combo_multiplier)
	score += points
	
	# Update combo
	combo_count += 1
	combo_timer = combo_window
	_update_combo_multiplier()
	
	score_changed.emit(score)
	combo_changed.emit(combo_multiplier, combo_count)
	crime_committed.emit(crime_type, points, position)


func _update_combo_multiplier() -> void:
	match combo_count:
		1: combo_multiplier = 1.0
		2: combo_multiplier = 1.5
		3: combo_multiplier = 2.0
		4: combo_multiplier = 2.5
		5: combo_multiplier = 3.0
		_: combo_multiplier = max_combo_multiplier


func _reset_combo() -> void:
	combo_count = 0
	combo_multiplier = 1.0
	combo_changed.emit(combo_multiplier, combo_count)


func add_suspicion(amount: float) -> void:
	if is_game_over:
		return
	
	suspicion = min(max_suspicion, suspicion + amount)
	suspicion_changed.emit(suspicion)
	
	if suspicion >= max_suspicion:
		_trigger_game_over()


func _trigger_game_over() -> void:
	is_game_over = true
	game_over.emit()


func set_player(player: Node3D) -> void:
	_player = player


func set_owner_ai(owner_ai: Node3D) -> void:
	_owner_ai = owner_ai


func get_score() -> int:
	return score


func get_combo_multiplier() -> float:
	return combo_multiplier


func get_combo_count() -> int:
	return combo_count


func get_combo_timer() -> float:
	return combo_timer


func get_suspicion() -> float:
	return suspicion


func get_suspicion_percent() -> float:
	return suspicion / max_suspicion


func reset_game() -> void:
	score = 0
	combo_count = 0
	combo_multiplier = 1.0
	combo_timer = 0.0
	suspicion = 0.0
	is_game_over = false
	
	score_changed.emit(score)
	combo_changed.emit(combo_multiplier, combo_count)
	suspicion_changed.emit(suspicion)
