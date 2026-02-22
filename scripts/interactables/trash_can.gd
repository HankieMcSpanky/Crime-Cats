extends RigidBody3D
class_name TrashCan

signal tipped_over(trash_can: Node3D)

@export var tip_points: int = 40
@export var tip_angle_threshold: float = 45.0
@export var garbage_items: Array[PackedScene] = []
@export var garbage_count: int = 5

var _has_tipped: bool = false
var _garbage_spawned: Array[Node3D] = []


func _ready() -> void:
	# Set collision layer
	collision_layer = 2
	collision_mask = 1


func _physics_process(_delta: float) -> void:
	if _has_tipped:
		return
	
	# Check if tipped over
	var up_vector = global_transform.basis.y
	var angle_from_up = rad_to_deg(acos(up_vector.dot(Vector3.UP)))
	
	if angle_from_up > tip_angle_threshold:
		_tip_over()


func _tip_over() -> void:
	_has_tipped = true
	tipped_over.emit(self)
	
	# Spawn garbage items
	_spawn_garbage()
	
	# Notify game manager
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.on_crime_committed("trash", tip_points, global_position)


func _spawn_garbage() -> void:
	var spawn_pos = global_position + Vector3.UP * 0.3
	
	for i in range(garbage_count):
		var garbage: RigidBody3D
		
		if garbage_items.size() > 0:
			var scene = garbage_items[randi() % garbage_items.size()]
			garbage = scene.instantiate() as RigidBody3D
		else:
			# Create default garbage (small boxes)
			garbage = _create_default_garbage()
		
		get_parent().add_child(garbage)
		garbage.global_position = spawn_pos + Vector3(
			randf_range(-0.2, 0.2),
			randf_range(0, 0.3),
			randf_range(-0.2, 0.2)
		)
		
		# Apply random impulse
		garbage.apply_central_impulse(Vector3(
			randf_range(-1, 1),
			randf_range(0.5, 1.5),
			randf_range(-1, 1)
		))
		
		_garbage_spawned.append(garbage)


func _create_default_garbage() -> RigidBody3D:
	var garbage = RigidBody3D.new()
	
	var mesh = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.08, 0.08, 0.08)
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(
		randf_range(0.3, 0.6),
		randf_range(0.3, 0.5),
		randf_range(0.2, 0.4)
	)
	box_mesh.material = material
	mesh.mesh = box_mesh
	garbage.add_child(mesh)
	
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.08, 0.08, 0.08)
	collision.shape = shape
	garbage.add_child(collision)
	
	garbage.mass = 0.1
	garbage.collision_layer = 2
	garbage.collision_mask = 1
	
	return garbage


func on_knocked(_knocker: Node3D) -> void:
	# Apply extra force when knocked by cat
	apply_central_impulse(Vector3(randf_range(-2, 2), 1, randf_range(-2, 2)))
