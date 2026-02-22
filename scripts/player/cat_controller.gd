extends CharacterBody3D
class_name CatController

signal crime_committed(crime_type: String, points: int)
signal item_picked_up(item: Node3D)
signal item_dropped(item: Node3D)

@export_group("Nodes")
@export var visuals_path: NodePath = NodePath("Visuals")
@export var animation_tree_path: NodePath = NodePath("Visuals/AnimationTree")
@export var animation_controller_path: NodePath = NodePath("AnimationController")
@export var paw_swipe_area_path: NodePath = NodePath("PawSwipeArea")

@export_group("Camera")
@export var enable_camera_relative: bool = true

@export_group("Movement")
@export var walk_speed: float = 2.0
@export var run_speed: float = 5.0
@export var acceleration: float = 15.0
@export var air_acceleration: float = 6.0
@export var jump_velocity: float = 6.0
@export var gravity: float = 25.0
@export var max_fall_speed: float = 40.0
@export var rotation_speed: float = 15.0

@export_group("Dash/Pounce")
@export var dash_speed: float = 12.0
@export var dash_duration: float = 0.25
@export var dash_cooldown: float = 1.5

@export_group("Paw Swipe")
@export var swipe_force: float = 5.0
@export var swipe_cooldown: float = 0.3

@export_group("Item Carrying")
@export var mouth_position: Vector3 = Vector3(0, 0.15, 0.25)
@export var carry_speed_penalty: float = 0.8

var _visuals: Node3D
var _animation_tree: AnimationTree
var _animation_controller: Node
var _paw_swipe_area: Area3D

var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO

var _swipe_cooldown_timer: float = 0.0
var _is_swiping: bool = false

var _carried_item: Node3D = null
var _is_hidden: bool = false

var _nearby_interactables: Array[Node3D] = []


func _ready() -> void:
	_visuals = get_node_or_null(visuals_path) as Node3D
	_animation_tree = get_node_or_null(animation_tree_path) as AnimationTree
	_animation_controller = get_node_or_null(animation_controller_path)
	_paw_swipe_area = get_node_or_null(paw_swipe_area_path) as Area3D
	
	if _animation_controller and _animation_tree:
		_animation_controller.initialize(_animation_tree)
	
	if _paw_swipe_area:
		_paw_swipe_area.body_entered.connect(_on_swipe_area_body_entered)
		_paw_swipe_area.body_exited.connect(_on_swipe_area_body_exited)


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	
	var move_axis := _read_move_axis()
	var input_direction := _get_input_direction(move_axis)
	var is_sprinting := _is_sprinting()
	
	_handle_jump_request()
	_handle_dash_request(input_direction)
	_handle_swipe_request()
	_handle_interact_request()
	_handle_drop_request()
	
	velocity = _compute_velocity(velocity, input_direction, is_sprinting, delta)
	move_and_slide()
	
	_update_carried_item()
	
	if _animation_controller:
		_animation_controller.update_locomotion(is_on_floor(), velocity, is_sprinting, delta)


func _update_timers(delta: float) -> void:
	if _dash_cooldown_timer > 0:
		_dash_cooldown_timer -= delta
	if _swipe_cooldown_timer > 0:
		_swipe_cooldown_timer -= delta
	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0:
			_is_dashing = false


func _get_input_direction(move_axis: Vector2) -> Vector3:
	var raw := Vector3(move_axis.x, 0.0, move_axis.y)
	if enable_camera_relative:
		return _get_camera_relative_direction(raw).normalized()
	return raw.normalized()


func _read_move_axis() -> Vector2:
	var axis := Vector2.ZERO
	if Input.is_action_pressed(&"move_left"):
		axis.x -= 1.0
	if Input.is_action_pressed(&"move_right"):
		axis.x += 1.0
	if Input.is_action_pressed(&"move_forward"):
		axis.y -= 1.0
	if Input.is_action_pressed(&"move_back"):
		axis.y += 1.0
	return axis.limit_length(1.0)


func _is_sprinting() -> bool:
	return InputMap.has_action(&"sprint") and Input.is_action_pressed(&"sprint")


func _handle_jump_request() -> void:
	if _is_dashing:
		return
	if not InputMap.has_action(&"jump"):
		return
	if Input.is_action_just_pressed(&"jump") and is_on_floor():
		velocity.y = jump_velocity


func _handle_dash_request(input_direction: Vector3) -> void:
	if not InputMap.has_action(&"sprint"):
		return
	if Input.is_action_just_pressed(&"sprint") and _dash_cooldown_timer <= 0 and is_on_floor():
		_is_dashing = true
		_dash_timer = dash_duration
		_dash_cooldown_timer = dash_cooldown
		_dash_direction = input_direction if input_direction.length() > 0.1 else -_visuals.global_transform.basis.z
		_dash_direction = _dash_direction.normalized()


func _handle_swipe_request() -> void:
	if not InputMap.has_action(&"paw_swipe"):
		return
	if Input.is_action_just_pressed(&"paw_swipe") and _swipe_cooldown_timer <= 0 and not _carried_item:
		_perform_swipe()


func _perform_swipe() -> void:
	_swipe_cooldown_timer = swipe_cooldown
	_is_swiping = true
	
	# Apply force to nearby objects
	for body in _nearby_interactables:
		if body is RigidBody3D:
			var direction = (body.global_position - global_position).normalized()
			direction.y = 0.3  # Add slight upward force
			direction = direction.normalized()
			body.apply_central_impulse(direction * swipe_force)
			
			# Check if it's a knockable object
			if body.has_method("on_knocked"):
				body.on_knocked(self)
	
	# Reset swipe state after brief delay
	get_tree().create_timer(0.2).timeout.connect(func(): _is_swiping = false)


func _handle_interact_request() -> void:
	if not InputMap.has_action(&"interact"):
		return
	if Input.is_action_just_pressed(&"interact"):
		if _carried_item:
			return  # Already carrying something
		
		# Find nearest interactable
		var nearest: Node3D = null
		var nearest_dist := INF
		for body in _nearby_interactables:
			if body.has_method("can_be_picked_up") and body.can_be_picked_up():
				var dist = global_position.distance_to(body.global_position)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest = body
		
		if nearest:
			_pick_up_item(nearest)


func _handle_drop_request() -> void:
	if not InputMap.has_action(&"drop_item"):
		return
	if Input.is_action_just_pressed(&"drop_item") and _carried_item:
		_drop_item()


func _pick_up_item(item: Node3D) -> void:
	_carried_item = item
	if item is RigidBody3D:
		item.freeze = true
	item.get_parent().remove_child(item)
	add_child(item)
	item.position = mouth_position
	item.rotation = Vector3.ZERO
	item_picked_up.emit(item)


func _drop_item() -> void:
	if not _carried_item:
		return
	
	var item = _carried_item
	_carried_item = null
	
	var global_pos = item.global_position
	var global_rot = item.global_rotation
	
	remove_child(item)
	get_parent().add_child(item)
	item.global_position = global_pos
	item.global_rotation = global_rot
	
	if item is RigidBody3D:
		item.freeze = false
		# Toss item forward slightly
		var toss_direction = -_visuals.global_transform.basis.z + Vector3.UP * 0.5
		item.apply_central_impulse(toss_direction * 2.0)
	
	item_dropped.emit(item)


func _update_carried_item() -> void:
	if _carried_item:
		_carried_item.position = mouth_position


func _compute_velocity(
	current_velocity: Vector3,
	input_direction: Vector3,
	is_sprinting: bool,
	delta: float
) -> Vector3:
	var v := current_velocity
	
	if _is_dashing:
		v.x = _dash_direction.x * dash_speed
		v.z = _dash_direction.z * dash_speed
		v.y = 0
	else:
		v = _apply_horizontal_movement(v, input_direction, is_sprinting, delta)
		v = _apply_gravity(v, delta)
	
	_apply_rotation(input_direction, delta)
	return v


func _apply_horizontal_movement(
	v: Vector3,
	input_direction: Vector3,
	is_sprinting: bool,
	delta: float
) -> Vector3:
	var base_speed := run_speed if is_sprinting else walk_speed
	
	# Apply carry speed penalty
	if _carried_item:
		base_speed *= carry_speed_penalty
	
	var desired_velocity := input_direction * base_speed
	var base_accel := acceleration if is_on_floor() else air_acceleration
	
	v.x = move_toward(v.x, desired_velocity.x, base_accel * delta)
	v.z = move_toward(v.z, desired_velocity.z, base_accel * delta)
	return v


func _apply_gravity(v: Vector3, delta: float) -> Vector3:
	if is_on_floor():
		return v
	v.y = clamp(v.y - gravity * delta, -max_fall_speed, max_fall_speed)
	return v


func _apply_rotation(input_direction: Vector3, delta: float) -> void:
	if not _visuals:
		return
	if input_direction.length_squared() <= 0.01:
		return
	
	var target_rotation := atan2(input_direction.x, input_direction.z)
	var current_rotation := _visuals.rotation.y
	_visuals.rotation.y = lerp_angle(current_rotation, target_rotation, rotation_speed * delta)


func _get_camera_relative_direction(raw_input: Vector3) -> Vector3:
	var viewport := get_viewport()
	if not viewport:
		return raw_input
	
	var camera := viewport.get_camera_3d()
	if not camera:
		return raw_input
	
	var cam_basis := camera.global_transform.basis
	var forward := -cam_basis.z
	var right := cam_basis.x
	
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	
	return (forward * -raw_input.z) + (right * raw_input.x)


func _on_swipe_area_body_entered(body: Node3D) -> void:
	if body != self and body is RigidBody3D:
		_nearby_interactables.append(body)


func _on_swipe_area_body_exited(body: Node3D) -> void:
	_nearby_interactables.erase(body)


func set_hidden(hidden: bool) -> void:
	_is_hidden = hidden


func is_hidden() -> bool:
	return _is_hidden


func is_carrying_item() -> bool:
	return _carried_item != null


func get_carried_item() -> Node3D:
	return _carried_item
