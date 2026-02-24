extends CharacterBody3D
class_name QuadrupedCatController

## Quadruped cat controller for Fifi (Player 2)
## Animations: Idle, Walk, Run, Jump, Land, Paw Swipe, Sit

signal crime_committed(crime_type: String, points: int)
signal item_picked_up(item: Node3D)
signal item_dropped(item: Node3D)

enum AnimState { IDLE, WALK, RUN, JUMP, FALL, LAND, PAW_SWIPE, SIT }

@export_group("Player")
@export var player_id: int = 2
@export var input_prefix: String = "p2_"

@export_group("Nodes")
@export var visuals_path: NodePath = NodePath("Visuals")
@export var animation_player_path: NodePath = NodePath("Visuals/AnimationPlayer")
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

@export_group("Idle Timeout")
@export var sit_timeout: float = 5.0

var _visuals: Node3D
var _animation_player: AnimationPlayer
var _paw_swipe_area: Area3D

var _current_anim_state: AnimState = AnimState.IDLE
var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO

var _swipe_cooldown_timer: float = 0.0
var _is_swiping: bool = false

var _idle_timer: float = 0.0
var _is_sitting: bool = false

var _carried_item: Node3D = null
var _is_hidden: bool = false

var _nearby_interactables: Array[Node3D] = []
var _was_on_floor: bool = true


func _ready() -> void:
	_visuals = get_node_or_null(visuals_path) as Node3D
	_animation_player = get_node_or_null(animation_player_path) as AnimationPlayer
	_paw_swipe_area = get_node_or_null(paw_swipe_area_path) as Area3D
	
	if _paw_swipe_area:
		_paw_swipe_area.body_entered.connect(_on_swipe_area_body_entered)
		_paw_swipe_area.body_exited.connect(_on_swipe_area_body_exited)
	
	_setup_animations()


func _setup_animations() -> void:
	if not _animation_player:
		return
	
	# Create procedural animations for quadruped cat
	var lib = AnimationLibrary.new()
	
	# Idle - slight breathing movement
	var idle_anim = Animation.new()
	idle_anim.length = 2.0
	idle_anim.loop_mode = Animation.LOOP_LINEAR
	var idle_track = idle_anim.add_track(Animation.TYPE_POSITION_3D)
	idle_anim.track_set_path(idle_track, ".:position")
	idle_anim.track_insert_key(idle_track, 0.0, Vector3.ZERO)
	idle_anim.track_insert_key(idle_track, 1.0, Vector3(0, 0.02, 0))
	idle_anim.track_insert_key(idle_track, 2.0, Vector3.ZERO)
	lib.add_animation("idle", idle_anim)
	
	# Walk cycle - bobbing motion
	var walk_anim = Animation.new()
	walk_anim.length = 0.8
	walk_anim.loop_mode = Animation.LOOP_LINEAR
	var walk_track = walk_anim.add_track(Animation.TYPE_POSITION_3D)
	walk_anim.track_set_path(walk_track, ".:position")
	walk_anim.track_insert_key(walk_track, 0.0, Vector3.ZERO)
	walk_anim.track_insert_key(walk_track, 0.2, Vector3(0, 0.03, 0))
	walk_anim.track_insert_key(walk_track, 0.4, Vector3.ZERO)
	walk_anim.track_insert_key(walk_track, 0.6, Vector3(0, 0.03, 0))
	walk_anim.track_insert_key(walk_track, 0.8, Vector3.ZERO)
	lib.add_animation("walk", walk_anim)
	
	# Run - faster bobbing
	var run_anim = Animation.new()
	run_anim.length = 0.4
	run_anim.loop_mode = Animation.LOOP_LINEAR
	var run_track = run_anim.add_track(Animation.TYPE_POSITION_3D)
	run_anim.track_set_path(run_track, ".:position")
	run_anim.track_insert_key(run_track, 0.0, Vector3.ZERO)
	run_anim.track_insert_key(run_track, 0.1, Vector3(0, 0.05, 0))
	run_anim.track_insert_key(run_track, 0.2, Vector3.ZERO)
	run_anim.track_insert_key(run_track, 0.3, Vector3(0, 0.05, 0))
	run_anim.track_insert_key(run_track, 0.4, Vector3.ZERO)
	lib.add_animation("run", run_anim)
	
	# Jump - crouch then spring
	var jump_anim = Animation.new()
	jump_anim.length = 0.3
	jump_anim.loop_mode = Animation.LOOP_NONE
	var jump_track = jump_anim.add_track(Animation.TYPE_SCALE_3D)
	jump_anim.track_set_path(jump_track, ".:scale")
	jump_anim.track_insert_key(jump_track, 0.0, Vector3.ONE)
	jump_anim.track_insert_key(jump_track, 0.1, Vector3(1.1, 0.8, 1.1))  # Crouch
	jump_anim.track_insert_key(jump_track, 0.2, Vector3(0.9, 1.2, 0.9))  # Spring
	jump_anim.track_insert_key(jump_track, 0.3, Vector3.ONE)
	lib.add_animation("jump", jump_anim)
	
	# Land - cushion impact
	var land_anim = Animation.new()
	land_anim.length = 0.25
	land_anim.loop_mode = Animation.LOOP_NONE
	var land_track = land_anim.add_track(Animation.TYPE_SCALE_3D)
	land_anim.track_set_path(land_track, ".:scale")
	land_anim.track_insert_key(land_track, 0.0, Vector3(0.9, 1.1, 0.9))
	land_anim.track_insert_key(land_track, 0.1, Vector3(1.15, 0.85, 1.15))  # Squash
	land_anim.track_insert_key(land_track, 0.25, Vector3.ONE)
	lib.add_animation("land", land_anim)
	
	# Paw swipe
	var swipe_anim = Animation.new()
	swipe_anim.length = 0.3
	swipe_anim.loop_mode = Animation.LOOP_NONE
	var swipe_track = swipe_anim.add_track(Animation.TYPE_ROTATION_3D)
	swipe_anim.track_set_path(swipe_track, ".:rotation")
	swipe_anim.track_insert_key(swipe_track, 0.0, Vector3.ZERO)
	swipe_anim.track_insert_key(swipe_track, 0.15, Vector3(0, 0.3, 0.2))  # Lean into swipe
	swipe_anim.track_insert_key(swipe_track, 0.3, Vector3.ZERO)
	lib.add_animation("paw_swipe", swipe_anim)
	
	# Sit - lower down
	var sit_anim = Animation.new()
	sit_anim.length = 0.5
	sit_anim.loop_mode = Animation.LOOP_NONE
	var sit_track = sit_anim.add_track(Animation.TYPE_POSITION_3D)
	sit_anim.track_set_path(sit_track, ".:position")
	sit_anim.track_insert_key(sit_track, 0.0, Vector3.ZERO)
	sit_anim.track_insert_key(sit_track, 0.5, Vector3(0, -0.05, 0))
	lib.add_animation("sit", sit_anim)
	
	_animation_player.add_animation_library("cat", lib)


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	
	var move_axis := _read_move_axis()
	var input_direction := _get_input_direction(move_axis)
	var is_sprinting := _is_sprinting()
	
	# Track idle time for sit animation
	if move_axis.length() < 0.1 and is_on_floor() and not _is_swiping:
		_idle_timer += delta
		if _idle_timer >= sit_timeout and not _is_sitting:
			_is_sitting = true
			_play_animation("sit")
	else:
		_idle_timer = 0.0
		if _is_sitting:
			_is_sitting = false
	
	_handle_jump_request()
	_handle_dash_request(input_direction)
	_handle_swipe_request()
	_handle_interact_request()
	_handle_drop_request()
	
	velocity = _compute_velocity(velocity, input_direction, is_sprinting, delta)
	
	var was_on_floor = is_on_floor()
	move_and_slide()
	
	# Detect landing
	if not _was_on_floor and is_on_floor():
		_play_animation("land")
		_change_anim_state(AnimState.LAND)
	_was_on_floor = is_on_floor()
	
	_update_carried_item()
	_update_animation_state(move_axis, is_sprinting)


func _update_timers(delta: float) -> void:
	if _dash_cooldown_timer > 0:
		_dash_cooldown_timer -= delta
	if _swipe_cooldown_timer > 0:
		_swipe_cooldown_timer -= delta
	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0:
			_is_dashing = false


func _update_animation_state(move_axis: Vector2, is_sprinting: bool) -> void:
	if _is_swiping or _is_sitting:
		return
	
	if not is_on_floor():
		if velocity.y > 0:
			_change_anim_state(AnimState.JUMP)
		else:
			_change_anim_state(AnimState.FALL)
	elif move_axis.length() > 0.1:
		if is_sprinting:
			_change_anim_state(AnimState.RUN)
			_play_animation("run")
		else:
			_change_anim_state(AnimState.WALK)
			_play_animation("walk")
	else:
		if _current_anim_state != AnimState.LAND:
			_change_anim_state(AnimState.IDLE)
			_play_animation("idle")


func _change_anim_state(new_state: AnimState) -> void:
	if _current_anim_state == new_state:
		return
	_current_anim_state = new_state


func _play_animation(anim_name: String) -> void:
	if _animation_player and _animation_player.has_animation("cat/" + anim_name):
		if _animation_player.current_animation != "cat/" + anim_name:
			_animation_player.play("cat/" + anim_name)


func _get_input_direction(move_axis: Vector2) -> Vector3:
	var raw := Vector3(move_axis.x, 0.0, move_axis.y)
	if enable_camera_relative:
		return _get_camera_relative_direction(raw).normalized()
	return raw.normalized()


func _read_move_axis() -> Vector2:
	var axis := Vector2.ZERO
	var left_action = input_prefix + "move_left" if InputMap.has_action(input_prefix + "move_left") else "move_left"
	var right_action = input_prefix + "move_right" if InputMap.has_action(input_prefix + "move_right") else "move_right"
	var forward_action = input_prefix + "move_forward" if InputMap.has_action(input_prefix + "move_forward") else "move_forward"
	var back_action = input_prefix + "move_back" if InputMap.has_action(input_prefix + "move_back") else "move_back"
	
	if Input.is_action_pressed(left_action):
		axis.x -= 1.0
	if Input.is_action_pressed(right_action):
		axis.x += 1.0
	if Input.is_action_pressed(forward_action):
		axis.y -= 1.0
	if Input.is_action_pressed(back_action):
		axis.y += 1.0
	return axis.limit_length(1.0)


func _is_sprinting() -> bool:
	var sprint_action = input_prefix + "sprint" if InputMap.has_action(input_prefix + "sprint") else "sprint"
	return InputMap.has_action(sprint_action) and Input.is_action_pressed(sprint_action)


func _handle_jump_request() -> void:
	if _is_dashing:
		return
	var jump_action = input_prefix + "jump" if InputMap.has_action(input_prefix + "jump") else "jump"
	if not InputMap.has_action(jump_action):
		return
	if Input.is_action_just_pressed(jump_action) and is_on_floor():
		velocity.y = jump_velocity
		_play_animation("jump")
		_change_anim_state(AnimState.JUMP)


func _handle_dash_request(input_direction: Vector3) -> void:
	var sprint_action = input_prefix + "sprint" if InputMap.has_action(input_prefix + "sprint") else "sprint"
	if not InputMap.has_action(sprint_action):
		return
	if Input.is_action_just_pressed(sprint_action) and _dash_cooldown_timer <= 0 and is_on_floor():
		_is_dashing = true
		_dash_timer = dash_duration
		_dash_cooldown_timer = dash_cooldown
		_dash_direction = input_direction if input_direction.length() > 0.1 else -_visuals.global_transform.basis.z
		_dash_direction = _dash_direction.normalized()


func _handle_swipe_request() -> void:
	var swipe_action = input_prefix + "paw_swipe" if InputMap.has_action(input_prefix + "paw_swipe") else "paw_swipe"
	if not InputMap.has_action(swipe_action):
		return
	if Input.is_action_just_pressed(swipe_action) and _swipe_cooldown_timer <= 0 and not _carried_item:
		_perform_swipe()


func _perform_swipe() -> void:
	_swipe_cooldown_timer = swipe_cooldown
	_is_swiping = true
	_play_animation("paw_swipe")
	
	for body in _nearby_interactables:
		if body is RigidBody3D:
			var direction = (body.global_position - global_position).normalized()
			direction.y = 0.3
			direction = direction.normalized()
			body.apply_central_impulse(direction * swipe_force)
			
			if body.has_method("on_knocked"):
				body.on_knocked(self)
	
	get_tree().create_timer(0.3).timeout.connect(func(): _is_swiping = false)


func _handle_interact_request() -> void:
	var interact_action = input_prefix + "interact" if InputMap.has_action(input_prefix + "interact") else "interact"
	if not InputMap.has_action(interact_action):
		return
	if Input.is_action_just_pressed(interact_action):
		if _carried_item:
			return
		
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
	var drop_action = input_prefix + "drop_item" if InputMap.has_action(input_prefix + "drop_item") else "drop_item"
	if not InputMap.has_action(drop_action):
		return
	if Input.is_action_just_pressed(drop_action) and _carried_item:
		_drop_item()


func _pick_up_item(item: Node3D) -> void:
	_carried_item = item
	if item is RigidBody3D:
		item.freeze = true
	item.get_parent().remove_child(item)
	add_child(item)
	item.position = Vector3(0, 0.15, 0.25)
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
		var toss_direction = -_visuals.global_transform.basis.z + Vector3.UP * 0.5
		item.apply_central_impulse(toss_direction * 2.0)
	
	item_dropped.emit(item)


func _update_carried_item() -> void:
	if _carried_item:
		_carried_item.position = Vector3(0, 0.15, 0.25)


func _compute_velocity(current_velocity: Vector3, input_direction: Vector3, is_sprinting: bool, delta: float) -> Vector3:
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


func _apply_horizontal_movement(v: Vector3, input_direction: Vector3, is_sprinting: bool, delta: float) -> Vector3:
	var base_speed := run_speed if is_sprinting else walk_speed
	if _carried_item:
		base_speed *= 0.8
	
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
