@tool
extends SceneTree

func _init():
	var scene = load("res://catspack_fbx/CatStray_Anim_IP.fbx")
	if scene:
		var instance = scene.instantiate()
		print("=== Searching for AnimationPlayer ===")
		_find_animation_players(instance, "")
		instance.queue_free()
	quit()

func _find_animation_players(node: Node, path: String):
	var current_path = path + "/" + node.name if path else node.name
	
	if node is AnimationPlayer:
		print("Found AnimationPlayer at: ", current_path)
		var anim_player = node as AnimationPlayer
		print("Animations:")
		for anim_name in anim_player.get_animation_list():
			print("  - ", anim_name)
	
	for child in node.get_children():
		_find_animation_players(child, current_path)
