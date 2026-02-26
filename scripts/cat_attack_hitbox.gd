extends Area3D
class_name CatAttackHitbox

## Detects and knocks over nearby objects when cat attacks

@export var knock_radius: float = 1.0
@export var knock_force: float = 4.0

var _cat_animation_controller: Node


func _ready() -> void:
	# Find the animation controller in parent
	var parent := get_parent()
	while parent:
		if parent.has_node("CatAnimationController"):
			_cat_animation_controller = parent.get_node("CatAnimationController")
			break
		parent = parent.get_parent()
	
	if _cat_animation_controller:
		if _cat_animation_controller.has_signal("attack_triggered"):
			_cat_animation_controller.attack_triggered.connect(_on_attack)


func _on_attack() -> void:
	# Get all overlapping bodies
	var bodies := get_overlapping_bodies()
	
	for body in bodies:
		if body is KnockableObject:
			# Calculate direction from cat to object
			var direction := body.global_position - global_position
			direction.y = 0  # Keep horizontal
			if direction.length() < 0.1:
				direction = Vector3.FORWARD
			
			body.knock(direction, knock_force)
		elif body is RigidBody3D:
			# Also knock over any RigidBody3D
			var direction := body.global_position - global_position
			direction.y = 0.5
			direction = direction.normalized()
			body.apply_central_impulse(direction * knock_force)
