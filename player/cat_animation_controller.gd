extends Node
class_name CatAnimationController

## Simplified animation controller for cat locomotion

@export var animation_player_path: NodePath
@export var idle_animation: StringName = &"Arm_Cat|Idle_1"
@export var walk_animation: StringName = &"Arm_Cat|Walk_F_IP"
@export var run_animation: StringName = &"Arm_Cat|Run_F_IP"
@export var jump_animation: StringName = &"Arm_Cat|JumpAir_horiz"
@export var fall_animation: StringName = &"Arm_Cat|JumpAir_low_F"
@export var land_animation: StringName = &"Arm_Cat|JumpLand"
@export var attack_animation: StringName = &"Arm_Cat|Attack_F"

signal attack_triggered

var _animation_player: AnimationPlayer
var _current_state: StringName = &""
var _was_on_floor: bool = true
var _looping_anims: Array[StringName] = []
var _is_attacking: bool = false


func _ready() -> void:
	if animation_player_path:
		_animation_player = get_node_or_null(animation_player_path) as AnimationPlayer
	
	# Define which animations should loop
	_looping_anims = [idle_animation, walk_animation, run_animation]
	
	if _animation_player:
		# Set loop mode for locomotion animations
		_setup_looping_animations()
		_play_animation(idle_animation)


func _setup_looping_animations() -> void:
	if not _animation_player:
		return
	
	var anim_lib := _animation_player.get_animation_library(&"")
	if anim_lib == null:
		# Try to find the library with animations
		for lib_name in _animation_player.get_animation_library_list():
			anim_lib = _animation_player.get_animation_library(lib_name)
			if anim_lib:
				break
	
	if anim_lib == null:
		return
	
	# Set looping for locomotion animations
	for anim_name in _looping_anims:
		var clean_name := anim_name
		# Handle library prefix if present
		if &"|" in String(anim_name):
			clean_name = StringName(String(anim_name).split("|")[1])
		
		if _animation_player.has_animation(anim_name):
			var anim := _animation_player.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR


## Called by MovementController - we don't use AnimationTree, so this is a no-op
func initialize(_animation_tree: AnimationTree) -> void:
	pass


func update_locomotion(is_on_floor: bool, velocity: Vector3, is_sprinting: bool, _delta: float = 0.0) -> void:
	if not _animation_player:
		return
	
	# Don't interrupt attack animation
	if _is_attacking:
		return
	
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	
	# Detect landing
	if not _was_on_floor and is_on_floor:
		_play_animation(land_animation)
		_was_on_floor = true
		# After land, transition back to idle/walk
		await get_tree().create_timer(0.2).timeout
		if is_on_floor:
			_update_ground_state(horizontal_speed, is_sprinting)
		return
	
	_was_on_floor = is_on_floor
	
	# Airborne
	if not is_on_floor:
		if velocity.y > 0.5:
			_play_animation(jump_animation)
		else:
			_play_animation(fall_animation)
		return
	
	# Ground movement
	_update_ground_state(horizontal_speed, is_sprinting)


func _update_ground_state(horizontal_speed: float, is_sprinting: bool) -> void:
	if horizontal_speed < 0.1:
		_play_animation(idle_animation)
	elif is_sprinting:
		_play_animation(run_animation)
	else:
		_play_animation(walk_animation)


func _play_animation(anim_name: StringName) -> void:
	if _current_state == anim_name:
		return
	
	if _animation_player.has_animation(anim_name):
		_animation_player.play(anim_name)
		_current_state = anim_name
	else:
		push_warning("CatAnimationController: Animation '%s' not found" % anim_name)


func play_attack() -> void:
	if _is_attacking:
		return
	
	_is_attacking = true
	_current_state = &""  # Reset so we can play attack
	
	if _animation_player.has_animation(attack_animation):
		_animation_player.play(attack_animation)
		_current_state = attack_animation
		attack_triggered.emit()
		
		# Wait for animation to finish
		await _animation_player.animation_finished
	
	_is_attacking = false
