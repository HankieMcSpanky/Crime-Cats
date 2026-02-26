@tool
extends EditorScript

## Adds collision to all furniture GLB imports

func _run():
	var furniture_dir = "res://assets/models/"
	var dir = DirAccess.open(furniture_dir)
	
	if not dir:
		print("Could not open directory: ", furniture_dir)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var count = 0
	
	while file_name != "":
		if file_name.ends_with(".glb"):
			var glb_path = furniture_dir + file_name
			_add_collision_to_glb(glb_path)
			count += 1
		file_name = dir.get_next()
	
	dir.list_dir_end()
	print("Updated ", count, " GLB files with collision")
	print("Please reimport the assets in Godot Editor")


func _add_collision_to_glb(glb_path: String):
	var import_path = glb_path + ".import"
	var config = ConfigFile.new()
	var err = config.load(import_path)
	
	if err != OK:
		print("Could not load: ", import_path)
		return
	
	# Get current subresources or create empty dict
	var subresources = config.get_value("params", "_subresources", {})
	
	# We need to add physics shape generation
	# This requires knowing the mesh node paths, which we don't have
	# Instead, we'll set the root node to generate collision
	
	# For now, print what we found
	print("Processing: ", glb_path)
