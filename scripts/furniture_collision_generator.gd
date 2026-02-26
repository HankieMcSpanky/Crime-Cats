extends Node3D
class_name FurnitureCollisionGenerator

## Automatically adds collision shapes to furniture meshes at runtime

@export var generate_on_ready: bool = true

func _ready():
	if generate_on_ready:
		call_deferred("_generate_all_collisions")


func _generate_all_collisions():
	var rooms = get_node_or_null("Rooms")
	if rooms:
		_process_node_recursive(rooms)
		print("FurnitureCollisionGenerator: Added collision to all furniture")


func _process_node_recursive(node: Node):
	# Check if this node is a furniture instance (has MeshInstance3D children)
	if node is MeshInstance3D:
		_add_collision_to_mesh(node)
	
	for child in node.get_children():
		_process_node_recursive(child)


func _add_collision_to_mesh(mesh_instance: MeshInstance3D):
	# Skip if already has a static body parent or sibling
	var parent = mesh_instance.get_parent()
	if parent is StaticBody3D:
		return
	
	for sibling in parent.get_children():
		if sibling is StaticBody3D:
			return
	
	# Create collision shape from mesh
	var mesh = mesh_instance.mesh
	if mesh == null:
		return
	
	# Create a static body as sibling
	var static_body = StaticBody3D.new()
	static_body.name = mesh_instance.name + "_Collision"
	
	# Create convex collision shape (faster than trimesh)
	var shape = mesh.create_convex_shape(true, true)  # clean and simplify
	if shape:
		var collision_shape = CollisionShape3D.new()
		collision_shape.shape = shape
		static_body.add_child(collision_shape)
		
		# Match the mesh transform
		static_body.transform = mesh_instance.transform
		
		# Add as sibling to mesh
		parent.add_child(static_body)
