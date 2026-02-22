extends Node3D
class_name ToiletPaper

signal unrolled(rotations: int)

@export var points_per_rotation: int = 20
@export var max_rotations: int = 10
@export var unroll_speed: float = 2.0

var current_rotations: int = 0
var _is_unrolling: bool = false
var _unroll_progress: float = 0.0
var _cat_nearby: Node3D = null

@onready var roll_mesh: MeshInstance3D = $RollMesh if has_node("RollMesh") else null
@onready var paper_trail: Node3D = $PaperTrail if has_node("PaperTrail") else null
@onready var interact_area: Area3D = $InteractArea if has_node("InteractArea") else null

var _paper_segments: Array[MeshInstance3D] = []
var _initial_roll_scale: Vector3


func _ready() -> void:
	if interact_area:
		interact_area.body_entered.connect(_on_area_body_entered)
		interact_area.body_exited.connect(_on_area_body_exited)
	
	if roll_mesh:
		_initial_roll_scale = roll_mesh.scale


func _process(delta: float) -> void:
	if _cat_nearby and current_rotations < max_rotations:
		if Input.is_action_pressed("interact"):
			_is_unrolling = true
			_unroll_progress += delta * unroll_speed
			
			# Rotate the roll
			if roll_mesh:
				roll_mesh.rotate_x(delta * unroll_speed * 5)
			
			# Check for complete rotation
			if _unroll_progress >= 1.0:
				_complete_rotation()
				_unroll_progress = 0.0
		else:
			_is_unrolling = false


func _on_area_body_entered(body: Node3D) -> void:
	if body is CatController:
		_cat_nearby = body


func _on_area_body_exited(body: Node3D) -> void:
	if body == _cat_nearby:
		_cat_nearby = null
		_is_unrolling = false


func _complete_rotation() -> void:
	current_rotations += 1
	unrolled.emit(current_rotations)
	
	# Shrink the roll
	if roll_mesh:
		var shrink_factor = 1.0 - (float(current_rotations) / float(max_rotations) * 0.7)
		roll_mesh.scale = _initial_roll_scale * shrink_factor
	
	# Add paper segment to trail
	_add_paper_segment()
	
	# Notify game manager
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.on_crime_committed("toilet_paper", points_per_rotation, global_position)


func _add_paper_segment() -> void:
	var segment = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(0.1, 0.3)
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.95, 0.9)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material
	
	segment.mesh = quad
	
	if paper_trail:
		paper_trail.add_child(segment)
	else:
		add_child(segment)
	
	# Position based on rotation count
	var offset = current_rotations * 0.15
	segment.position = Vector3(0, -0.5 - offset * 0.3, offset * 0.1)
	segment.rotation.x = randf_range(-0.3, 0.3)
	segment.rotation.z = randf_range(-0.2, 0.2)
	
	_paper_segments.append(segment)


func is_fully_unrolled() -> bool:
	return current_rotations >= max_rotations


func get_unroll_progress() -> float:
	return _unroll_progress
