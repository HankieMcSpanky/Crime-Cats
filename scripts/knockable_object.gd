extends RigidBody3D
class_name KnockableObject

## Object that can be knocked over by the cat

@export var knock_force: float = 3.0
@export var upward_force: float = 1.5
@export var can_be_knocked: bool = true

var _initial_transform: Transform3D
var _has_been_knocked: bool = false


func _ready() -> void:
	_initial_transform = global_transform
	
	# Make sure we have collision
	if get_child_count() == 0:
		push_warning("KnockableObject needs a CollisionShape3D child")


func knock(direction: Vector3, force_multiplier: float = 1.0) -> void:
	if not can_be_knocked:
		return
	
	# Unfreeze if frozen
	freeze = false
	
	# Calculate knock direction with some upward force
	var knock_direction := direction.normalized()
	knock_direction.y = upward_force
	knock_direction = knock_direction.normalized()
	
	# Apply impulse
	var impulse := knock_direction * knock_force * force_multiplier
	apply_central_impulse(impulse)
	
	# Add some spin
	var torque := Vector3(
		randf_range(-2, 2),
		randf_range(-1, 1),
		randf_range(-2, 2)
	)
	apply_torque_impulse(torque)
	
	_has_been_knocked = true


func reset_position() -> void:
	global_transform = _initial_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_has_been_knocked = false
