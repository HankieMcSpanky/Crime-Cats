extends Area3D
class_name ScratchableSurface

signal scratched(surface: Node3D, level: int)

@export var surface_name: String = "Furniture"
@export var scratch_points: int = 15
@export var max_scratch_level: int = 3
@export var scratch_time: float = 2.0

var current_scratch_level: int = 0
var _scratch_progress: float = 0.0
var _is_scratching: bool = false
var _scratching_cat: Node3D = null

@onready var scratch_decal: Decal = $ScratchDecal if has_node("ScratchDecal") else null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if _is_scratching and _scratching_cat:
		if Input.is_action_pressed("interact"):
			_scratch_progress += delta
			
			if _scratch_progress >= scratch_time:
				_complete_scratch()
				_scratch_progress = 0.0
		else:
			_is_scratching = false
			_scratch_progress = 0.0


func _on_body_entered(body: Node3D) -> void:
	if body is CatController:
		_scratching_cat = body


func _on_body_exited(body: Node3D) -> void:
	if body == _scratching_cat:
		_scratching_cat = null
		_is_scratching = false
		_scratch_progress = 0.0


func _input(event: InputEvent) -> void:
	if _scratching_cat and event.is_action_pressed("interact"):
		if current_scratch_level < max_scratch_level:
			_is_scratching = true


func _complete_scratch() -> void:
	if current_scratch_level >= max_scratch_level:
		return
	
	current_scratch_level += 1
	scratched.emit(self, current_scratch_level)
	
	# Update scratch decal visibility/intensity
	if scratch_decal:
		scratch_decal.visible = true
		scratch_decal.modulate.a = float(current_scratch_level) / float(max_scratch_level)
	
	# Notify game manager
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.on_crime_committed("scratch", scratch_points, global_position)


func get_scratch_progress() -> float:
	return _scratch_progress / scratch_time


func is_fully_scratched() -> bool:
	return current_scratch_level >= max_scratch_level
