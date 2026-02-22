extends CharacterBody3D
class_name OwnerAI

signal player_spotted(player: Node3D)
signal player_lost()
signal state_changed(new_state: String)

enum State { PATROL, IDLE, INVESTIGATE, CHASE, SEARCH, RETURN }

@export_group("Movement")
@export var patrol_speed: float = 1.5
@export var chase_speed: float = 3.0
@export var rotation_speed: float = 5.0

@export_group("Vision")
@export var vision_range: float = 8.0
@export var vision_angle: float = 90.0
@export var vision_height: float = 2.0

@export_group("Suspicion")
@export var idle_suspicion_rate: float = 5.0
@export var running_suspicion_rate: float = 10.0
@export var crime_suspicion_rate: float = 25.0
@export var near_crime_suspicion_rate: float = 15.0

@export_group("Patrol")
@export var patrol_path: Path3D
@export var waypoint_wait_time: float = 3.0

@export_group("Search")
@export var search_duration: float = 5.0
@export var investigate_duration: float = 3.0

var current_state: State = State.PATROL
var _current_waypoint_index: int = 0
var _waypoint_wait_timer: float = 0.0
var _search_timer: float = 0.0
var _investigate_timer: float = 0.0

var _target_position: Vector3
var _last_known_player_position: Vector3

var _vision_area: Area3D
var _players_in_vision: Array[Node3D] = []
var _game_manager: GameManager

var _gravity: float = 20.0


func _ready() -> void:
	_setup_vision_cone()
	_game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	
	if patrol_path and patrol_path.curve.point_count > 0:
		_target_position = patrol_path.curve.get_point_position(0) + patrol_path.global_position


func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0
	
	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.IDLE:
			_process_idle(delta)
		State.INVESTIGATE:
			_process_investigate(delta)
		State.CHASE:
			_process_chase(delta)
		State.SEARCH:
			_process_search(delta)
		State.RETURN:
			_process_return(delta)
	
	_check_vision()
	move_and_slide()


func _setup_vision_cone() -> void:
	_vision_area = Area3D.new()
	add_child(_vision_area)
	
	# Create vision cone collision shape
	var shape = ConvexPolygonShape3D.new()
	var points: PackedVector3Array = []
	
	# Create cone points
	var segments = 8
	var half_angle = deg_to_rad(vision_angle / 2)
	
	points.append(Vector3.ZERO)  # Apex at owner position
	
	for i in range(segments + 1):
		var angle = -half_angle + (half_angle * 2 * i / segments)
		var x = sin(angle) * vision_range
		var z = -cos(angle) * vision_range
		points.append(Vector3(x, -vision_height / 2, z))
		points.append(Vector3(x, vision_height / 2, z))
	
	shape.points = points
	
	var collision = CollisionShape3D.new()
	collision.shape = shape
	_vision_area.add_child(collision)
	
	_vision_area.collision_layer = 0
	_vision_area.collision_mask = 4  # Player layer
	
	_vision_area.body_entered.connect(_on_vision_body_entered)
	_vision_area.body_exited.connect(_on_vision_body_exited)


func _on_vision_body_entered(body: Node3D) -> void:
	if body is CatController:
		_players_in_vision.append(body)


func _on_vision_body_exited(body: Node3D) -> void:
	_players_in_vision.erase(body)


func _check_vision() -> void:
	for player in _players_in_vision:
		if _can_see_player(player):
			_on_player_visible(player)
			return
	
	# No player visible
	if current_state == State.CHASE:
		_change_state(State.SEARCH)
		_last_known_player_position = _target_position


func _can_see_player(player: Node3D) -> bool:
	# Check if player is hidden
	if player.has_method("is_hidden") and player.is_hidden():
		return false
	
	# Raycast to check line of sight
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.5,
		player.global_position + Vector3.UP * 0.2
	)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	if result and result.collider == player:
		return true
	
	return false


func _on_player_visible(player: Node3D) -> void:
	_target_position = player.global_position
	_last_known_player_position = player.global_position
	
	if current_state != State.CHASE:
		_change_state(State.CHASE)
		player_spotted.emit(player)
	
	# Add suspicion based on player behavior
	if _game_manager:
		var suspicion_amount = idle_suspicion_rate * get_process_delta_time()
		
		if player.has_method("is_carrying_item") and player.is_carrying_item():
			suspicion_amount = crime_suspicion_rate * get_process_delta_time()
		elif player.velocity.length() > 3.0:
			suspicion_amount = running_suspicion_rate * get_process_delta_time()
		
		_game_manager.add_suspicion(suspicion_amount)


func _process_patrol(delta: float) -> void:
	if not patrol_path or patrol_path.curve.point_count == 0:
		_change_state(State.IDLE)
		return
	
	var distance_to_waypoint = global_position.distance_to(_target_position)
	
	if distance_to_waypoint < 0.5:
		_waypoint_wait_timer += delta
		velocity.x = 0
		velocity.z = 0
		
		if _waypoint_wait_timer >= waypoint_wait_time:
			_waypoint_wait_timer = 0
			_advance_waypoint()
	else:
		_move_towards(_target_position, patrol_speed, delta)


func _advance_waypoint() -> void:
	_current_waypoint_index = (_current_waypoint_index + 1) % patrol_path.curve.point_count
	_target_position = patrol_path.curve.get_point_position(_current_waypoint_index) + patrol_path.global_position


func _process_idle(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	_waypoint_wait_timer += delta
	
	if _waypoint_wait_timer >= waypoint_wait_time:
		_waypoint_wait_timer = 0
		if patrol_path:
			_change_state(State.PATROL)


func _process_investigate(delta: float) -> void:
	var distance = global_position.distance_to(_target_position)
	
	if distance < 0.5:
		_investigate_timer += delta
		velocity.x = 0
		velocity.z = 0
		
		if _investigate_timer >= investigate_duration:
			_investigate_timer = 0
			_change_state(State.RETURN)
	else:
		_move_towards(_target_position, patrol_speed, delta)


func _process_chase(delta: float) -> void:
	_move_towards(_target_position, chase_speed, delta)


func _process_search(delta: float) -> void:
	_search_timer += delta
	
	# Look around
	var look_direction = Vector3(sin(_search_timer * 2), 0, cos(_search_timer * 2))
	_rotate_towards(global_position + look_direction, delta)
	
	velocity.x = 0
	velocity.z = 0
	
	if _search_timer >= search_duration:
		_search_timer = 0
		_change_state(State.RETURN)
		player_lost.emit()


func _process_return(delta: float) -> void:
	if not patrol_path:
		_change_state(State.IDLE)
		return
	
	var nearest_waypoint = _find_nearest_waypoint()
	_target_position = nearest_waypoint
	
	if global_position.distance_to(_target_position) < 0.5:
		_change_state(State.PATROL)
	else:
		_move_towards(_target_position, patrol_speed, delta)


func _find_nearest_waypoint() -> Vector3:
	if not patrol_path:
		return global_position
	
	var nearest_pos = patrol_path.curve.get_point_position(0) + patrol_path.global_position
	var nearest_dist = global_position.distance_to(nearest_pos)
	var nearest_idx = 0
	
	for i in range(1, patrol_path.curve.point_count):
		var pos = patrol_path.curve.get_point_position(i) + patrol_path.global_position
		var dist = global_position.distance_to(pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_pos = pos
			nearest_idx = i
	
	_current_waypoint_index = nearest_idx
	return nearest_pos


func _move_towards(target: Vector3, speed: float, delta: float) -> void:
	var direction = (target - global_position)
	direction.y = 0
	direction = direction.normalized()
	
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
	_rotate_towards(target, delta)


func _rotate_towards(target: Vector3, delta: float) -> void:
	var direction = (target - global_position)
	direction.y = 0
	
	if direction.length_squared() > 0.01:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)


func _change_state(new_state: State) -> void:
	current_state = new_state
	state_changed.emit(State.keys()[new_state])


func investigate_position(pos: Vector3) -> void:
	_target_position = pos
	_change_state(State.INVESTIGATE)


func get_state_name() -> String:
	return State.keys()[current_state]
