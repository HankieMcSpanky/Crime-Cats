extends Node3D
class_name Curtain

signal curtain_pulled_down(curtain: Node3D)

@export var pull_down_points: int = 50
@export var pull_force_required: float = 2.0
@export var fall_time: float = 2.0

var _current_pull_force: float = 0.0
var _is_pulled_down: bool = false
var _cat_hanging: Node3D = null
var _pull_timer: float = 0.0

@onready var curtain_mesh: MeshInstance3D = $CurtainMesh
@onready var rod: RigidBody3D = $Rod
@onready var grab_area: Area3D = $GrabArea


func _ready() -> void:
	if grab_area:
		grab_area.body_entered.connect(_on_grab_area_body_entered)
		grab_area.body_exited.connect(_on_grab_area_body_exited)


func _physics_process(delta: float) -> void:
	if _is_pulled_down:
		return
	
	if _cat_hanging:
		_pull_timer += delta
		_current_pull_force += delta * 0.5
		
		# Stretch curtain visual
		if curtain_mesh:
			curtain_mesh.scale.y = 1.0 + (_current_pull_force * 0.1)
		
		if _current_pull_force >= pull_force_required:
			_pull_down()


func _on_grab_area_body_entered(body: Node3D) -> void:
	if body is CatController and not _is_pulled_down:
		_cat_hanging = body
		_pull_timer = 0.0


func _on_grab_area_body_exited(body: Node3D) -> void:
	if body == _cat_hanging:
		_cat_hanging = null
		_current_pull_force = 0.0
		
		# Reset curtain stretch
		if curtain_mesh:
			curtain_mesh.scale.y = 1.0


func _pull_down() -> void:
	_is_pulled_down = true
	curtain_pulled_down.emit(self)
	
	# Make rod fall
	if rod:
		rod.freeze = false
		rod.apply_central_impulse(Vector3(0, -2, 1))
	
	# Animate curtain falling
	var tween = create_tween()
	tween.tween_property(curtain_mesh, "position:y", curtain_mesh.position.y - 1.5, fall_time)
	tween.parallel().tween_property(curtain_mesh, "rotation:x", deg_to_rad(45), fall_time)
	
	# Notify game manager
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.on_crime_committed("curtain", pull_down_points, global_position)
	
	# Release cat
	_cat_hanging = null
