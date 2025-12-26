extends Node
class_name CaravanNavigator

## Manages navigation and movement for a Caravan.
## Handles MapManager grid pathfinding.

var map_manager: MapManager
var movement_speed: float = 100.0
var _parent_node: Node2D

# Pathfinding state
var _current_path: PackedVector2Array = []
var _path_index: int = 0
var _target_pos: Vector2 = Vector2.ZERO

func setup(parent: Node2D, _nav_agent_ignored: NavigationAgent2D, speed: float) -> void:
	_parent_node = parent
	movement_speed = speed
	
	# Find MapManager
	map_manager = parent.get_node_or_null("/root/Overworld/MapManager")
	if map_manager == null and parent.get_parent():
		if parent.get_parent().has_node("MapManager"):
			map_manager = parent.get_parent().get_node("MapManager")

func set_target_position(target_pos: Vector2) -> void:
	if map_manager == null:
		return
		
	_target_pos = target_pos
	# Request path
	_current_path = map_manager.get_path_world(_parent_node.global_position, target_pos)
	_path_index = 0

func set_navigation_layers(_layers: int) -> void:
	# Grid pathfinding doesn't strictly use layers in this simple implementation
	pass

func update_movement(delta: float) -> void:
	if map_manager == null or _parent_node == null:
		return
		
	if is_navigation_finished():
		return

	if _path_index >= _current_path.size():
		return

	var next_point = _current_path[_path_index]
	var distance = _parent_node.global_position.distance_to(next_point)

	# Check arrival at waypoint
	if distance < 5.0:
		_path_index += 1
		return
		
	# Move
	var direction = _parent_node.global_position.direction_to(next_point)
	_parent_node.global_position += direction * movement_speed * delta

func is_navigation_finished() -> bool:
	return _current_path.is_empty() or _path_index >= _current_path.size()

func stop() -> void:
	_current_path = []
	_path_index = 0

func _on_velocity_computed(_safe_velocity: Vector2) -> void:
	# Deprecated
	pass
