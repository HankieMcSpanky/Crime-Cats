extends Node3D
class_name CatFlap

## A cat flap that swings open when the cat passes through

@export var swing_speed: float = 8.0
@export var max_swing_angle: float = 70.0
@export var return_speed: float = 3.0

var _current_angle: float = 0.0
var _target_angle: float = 0.0
var _flap_mesh: MeshInstance3D
var _trigger_area: Area3D

func _ready() -> void:
	_setup_flap()

func _setup_flap() -> void:
	# Create the swinging flap mesh
	_flap_mesh = MeshInstance3D.new()
	_flap_mesh.name = "FlapMesh"
	var box := BoxMesh.new()
	box.size = Vector3(0.25, 0.32, 0.02)
	_flap_mesh.mesh = box
	
	# Create material for the flap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.25, 0.15)  # Brown color
	_flap_mesh.material_override = mat
	
	# Position the flap - pivot at top
	_flap_mesh.position = Vector3(0, -0.16, 0)
	
	# Create pivot node for rotation
	var pivot := Node3D.new()
	pivot.name = "FlapPivot"
	pivot.position = Vector3(0, 0.16, 0)  # Top of the flap opening
	add_child(pivot)
	pivot.add_child(_flap_mesh)
	
	# Create trigger area for cat detection
	_trigger_area = Area3D.new()
	_trigger_area.name = "TriggerArea"
	add_child(_trigger_area)
	
	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.4, 0.4, 0.6)
	collision.shape = box_shape
	_trigger_area.add_child(collision)
	
	_trigger_area.body_entered.connect(_on_body_entered)
	_trigger_area.body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	var pivot := get_node_or_null("FlapPivot")
	if not pivot:
		return
	
	# Smoothly move towards target angle
	if abs(_target_angle) > 0.1:
		_current_angle = lerp(_current_angle, _target_angle, swing_speed * delta)
	else:
		# Return to closed position
		_current_angle = lerp(_current_angle, 0.0, return_speed * delta)
	
	pivot.rotation_degrees.x = _current_angle

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name.to_lower().contains("cat") or body.name.to_lower().contains("player"):
		# Determine swing direction based on which side the cat is approaching from
		var local_pos := to_local(body.global_position)
		if local_pos.z > 0:
			_target_angle = -max_swing_angle  # Swing inward
		else:
			_target_angle = max_swing_angle  # Swing outward

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name.to_lower().contains("cat") or body.name.to_lower().contains("player"):
		_target_angle = 0.0
