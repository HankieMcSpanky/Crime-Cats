extends Node

@export var material: Material
@export var outline_material: Material
@export var eye_color: Color = Color(0.2, 0.7, 0.2, 1.0)  # Green eyes

var _eye_material: StandardMaterial3D
var _outline_meshes: Array[MeshInstance3D] = []

func _ready() -> void:
	# Create eye material
	_eye_material = StandardMaterial3D.new()
	_eye_material.albedo_color = eye_color
	_eye_material.roughness = 0.2
	_eye_material.metallic = 0.1

	# Wait a frame to ensure the scene is fully loaded
	await get_tree().process_frame
	_apply_material()

func _apply_material() -> void:
	if material == null:
		push_warning("CatMaterialApplier: No material assigned")
		return

	var parent = get_parent()
	if parent == null:
		return

	var body_count := 0
	var eye_count := 0
	var outline_count := 0
	var result = _apply_material_recursive(parent)
	body_count = result[0]
	eye_count = result[1]
	outline_count = result[2]
	print("CatMaterialApplier: Applied body material to ", body_count, " meshes, eye material to ", eye_count, " meshes, outline to ", outline_count, " meshes")

func _apply_material_recursive(node: Node) -> Array:
	var body_count := 0
	var eye_count := 0
	var outline_count := 0

	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var node_name := node.name.to_lower()

		# Check if this is an eye mesh
		if "eye" in node_name or "cornea" in node_name or "iris" in node_name or "pupil" in node_name:
			mesh_instance.material_override = _eye_material
			eye_count += 1
		else:
			# Apply fur material to body
			mesh_instance.material_override = material
			body_count += 1

			# Create outline duplicate for x-ray through walls
			if outline_material:
				var outline := MeshInstance3D.new()
				outline.name = node.name + "_Outline"
				outline.mesh = mesh_instance.mesh
				outline.skeleton = mesh_instance.skeleton
				outline.skin = mesh_instance.skin
				outline.material_override = outline_material
				mesh_instance.add_child(outline)
				_outline_meshes.append(outline)
				outline_count += 1

	# Recurse to children
	for child in node.get_children():
		var result = _apply_material_recursive(child)
		body_count += result[0]
		eye_count += result[1]
		outline_count += result[2]

	return [body_count, eye_count, outline_count]
