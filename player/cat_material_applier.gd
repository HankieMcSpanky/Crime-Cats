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

	# First pass: collect all meshes
	var body_meshes: Array[MeshInstance3D] = []
	var eye_count := 0
	_collect_meshes(parent, body_meshes, eye_count)

	# Second pass: add outlines to body meshes (after recursion is done)
	var outline_count := 0
	if outline_material:
		for mesh_instance in body_meshes:
			var outline := MeshInstance3D.new()
			outline.name = mesh_instance.name + "_Outline"
			outline.mesh = mesh_instance.mesh
			outline.skeleton = mesh_instance.skeleton
			outline.skin = mesh_instance.skin
			outline.material_override = outline_material
			mesh_instance.add_child(outline)
			_outline_meshes.append(outline)
			outline_count += 1

	print("CatMaterialApplier: Applied body material to ", body_meshes.size(), " meshes, outline to ", outline_count, " meshes")

func _collect_meshes(node: Node, body_meshes: Array[MeshInstance3D], eye_count: int) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var node_name := node.name.to_lower()

		if "eye" in node_name or "cornea" in node_name or "iris" in node_name or "pupil" in node_name:
			mesh_instance.material_override = _eye_material
		else:
			mesh_instance.material_override = material
			body_meshes.append(mesh_instance)

	for child in node.get_children():
		_collect_meshes(child, body_meshes, eye_count)
