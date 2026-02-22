extends Area3D
class_name HidingSpot

signal player_hidden(player: Node3D)
signal player_revealed(player: Node3D)

@export var spot_name: String = "Hiding Spot"
@export var hide_position_offset: Vector3 = Vector3.ZERO
@export var is_enclosed: bool = true  # True for boxes, false for under furniture

var _players_inside: Array[Node3D] = []
var _hidden_players: Array[Node3D] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Set collision to detect players
	collision_layer = 0
	collision_mask = 4  # Player layer


func _on_body_entered(body: Node3D) -> void:
	if body is CatController:
		_players_inside.append(body)


func _on_body_exited(body: Node3D) -> void:
	if body is CatController:
		_players_inside.erase(body)
		
		# If player was hidden here, reveal them
		if body in _hidden_players:
			_reveal_player(body)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		for player in _players_inside:
			if player not in _hidden_players:
				_hide_player(player)
				break
			else:
				_reveal_player(player)
				break


func _hide_player(player: Node3D) -> void:
	if player in _hidden_players:
		return
	
	_hidden_players.append(player)
	
	if player.has_method("set_hidden"):
		player.set_hidden(true)
	
	# Move player to hide position
	if hide_position_offset != Vector3.ZERO:
		var target_pos = global_position + hide_position_offset
		player.global_position = target_pos
	
	player_hidden.emit(player)


func _reveal_player(player: Node3D) -> void:
	if player not in _hidden_players:
		return
	
	_hidden_players.erase(player)
	
	if player.has_method("set_hidden"):
		player.set_hidden(false)
	
	player_revealed.emit(player)


func has_hidden_player() -> bool:
	return _hidden_players.size() > 0


func get_hidden_players() -> Array[Node3D]:
	return _hidden_players


func is_player_nearby(player: Node3D) -> bool:
	return player in _players_inside
