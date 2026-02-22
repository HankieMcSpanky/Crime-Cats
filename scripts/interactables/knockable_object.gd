extends RigidBody3D
class_name KnockableObject

signal knocked(knocker: Node3D)
signal broken(position: Vector3)

@export_group("Object Settings")
@export var object_name: String = "Object"
@export var knock_points: int = 10
@export var break_points: int = 25

@export_group("Breaking")
@export var is_breakable: bool = true
@export var break_velocity_threshold: float = 4.0
@export var break_sound: AudioStream
@export var break_particles_scene: PackedScene

@export_group("Pickup")
@export var can_pickup: bool = false
@export var steal_points: int = 30

var _has_been_knocked: bool = false
var _initial_position: Vector3
var _initial_rotation: Vector3
var _is_broken: bool = false


func _ready() -> void:
	_initial_position = global_position
	_initial_rotation = global_rotation
	
	# Connect to body entered for break detection
	body_entered.connect(_on_body_entered)
	
	# Set collision layer to interactables (layer 2)
	collision_layer = 2
	collision_mask = 1  # Collide with world


func _on_body_entered(body: Node) -> void:
	if _is_broken:
		return
	
	# Check if we hit the ground hard enough to break
	if is_breakable and linear_velocity.length() > break_velocity_threshold:
		_break()


func on_knocked(knocker: Node3D) -> void:
	if _has_been_knocked:
		return
	
	_has_been_knocked = true
	knocked.emit(knocker)
	
	# Notify game manager
	var game_manager = _get_game_manager()
	if game_manager:
		game_manager.on_crime_committed("knock", knock_points, global_position)


func _break() -> void:
	if _is_broken:
		return
	
	_is_broken = true
	broken.emit(global_position)
	
	# Play break sound
	if break_sound:
		var audio = AudioStreamPlayer3D.new()
		get_parent().add_child(audio)
		audio.global_position = global_position
		audio.stream = break_sound
		audio.play()
		audio.finished.connect(audio.queue_free)
	
	# Spawn break particles
	if break_particles_scene:
		var particles = break_particles_scene.instantiate()
		get_parent().add_child(particles)
		particles.global_position = global_position
		if particles.has_method("emit"):
			particles.emit()
	
	# Notify game manager
	var game_manager = _get_game_manager()
	if game_manager:
		game_manager.on_crime_committed("break", break_points, global_position)
	
	# Remove object
	queue_free()


func can_be_picked_up() -> bool:
	return can_pickup and not _is_broken


func get_steal_points() -> int:
	return steal_points


func reset() -> void:
	_has_been_knocked = false
	_is_broken = false
	global_position = _initial_position
	global_rotation = _initial_rotation
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func _get_game_manager() -> Node:
	return get_tree().get_first_node_in_group("game_manager")
