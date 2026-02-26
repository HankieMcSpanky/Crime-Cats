@tool
extends SceneTree

func _init():
	var scene = load("res://catspack_fbx/CatStray_Anim_IP.fbx")
	if scene:
		var instance = scene.instantiate()
		print("=== Cat Model Info ===")
		_find_mesh_info(instance, "")
		instance.queue_free()
	quit()

func _find_mesh_info(node: Node, path: String):
	var current_path = path + "/" + node.name if path else node.name
	
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		var aabb = mesh_instance.get_aabb()
		print("MeshInstance3D at: ", current_path)
		print("  AABB Size: ", aabb.size)
		print("  AABB Position: ", aabb.position)
	
	if node is Node3D:
		var n3d = node as Node3D
		print("Node3D: ", current_path, " Scale: ", n3d.scale, " Position: ", n3d.position)
	
	for child in node.get_children():
		_find_mesh_info(child, current_path)
