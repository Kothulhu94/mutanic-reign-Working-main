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

func setup(parent: Node2D, map_mgr: MapManager, speed: float) -> void:
	_parent_node = parent
	map_manager = map_mgr
	movement_speed = speed
	
	if map_manager == null:
		push_error("CaravanNavigator: MapManager is null! Pathfinding will fail.")

# Abstract Movement State (for off-screen/distant travel)
var _is_using_abstract_movement: bool = false
var _final_abstract_target: Vector2 = Vector2.ZERO # The true goal
var _abstract_repath_timer: float = 0.0
const ABSTRACT_REPATH_INTERVAL: float = 0.5 # Check more frequently (0.5s) for re-entry

func set_target_position(target_pos: Vector2) -> void:
	if map_manager == null:
		push_warning("CaravanNavigator: Cannot set target, MapManager is null.")
		return
		
	_final_abstract_target = target_pos
	
	var in_bounds = map_manager.is_point_in_active_region(_parent_node.global_position)
	
	if in_bounds:
		_current_path = map_manager.get_path_world(_parent_node.global_position, target_pos)
		
		if not _current_path.is_empty():
			_is_using_abstract_movement = false
			_target_pos = target_pos
		else:
			# Target unreachable/OOB: Path to edge
			var edge_exit = map_manager.get_nav_boundary_exit(_parent_node.global_position, target_pos)
			var edge_path = map_manager.get_path_world(_parent_node.global_position, edge_exit)
			
			if not edge_path.is_empty():
				_current_path = edge_path
				_is_using_abstract_movement = false
				_target_pos = edge_exit
			else:
				_is_using_abstract_movement = true
				_target_pos = target_pos
	else:
		_is_using_abstract_movement = true
		_current_path = []
		_target_pos = target_pos
		
	_path_index = 0

func set_navigation_layers(_layers: int) -> void:
	pass

func update_movement(delta: float) -> void:
	if map_manager == null or _parent_node == null:
		return
		
	# Abstract Movement Logic (Off-Screen)
	if _is_using_abstract_movement:
		if _target_pos == Vector2.ZERO:
			return
			
		var distance = _parent_node.global_position.distance_to(_target_pos)
		if distance < 10.0:
			_is_using_abstract_movement = false
			return
			
		var abstract_dir = _parent_node.global_position.direction_to(_target_pos)
		_parent_node.global_position += abstract_dir * movement_speed * delta
		
		_abstract_repath_timer += delta
		if _abstract_repath_timer >= ABSTRACT_REPATH_INTERVAL:
			_abstract_repath_timer = 0.0
			if map_manager.is_point_in_active_region(_parent_node.global_position):
				set_target_position(_final_abstract_target)
		
		var fly_angle = abstract_dir.angle()
		_parent_node.rotation = lerp_angle(_parent_node.rotation, fly_angle, 5.0 * delta)
		return

	# Standard Grid Movement Logic (On-Screen)
	if is_navigation_finished():
		if _parent_node.global_position.distance_to(_final_abstract_target) > 20.0:
			_is_using_abstract_movement = true
			_target_pos = _final_abstract_target
		return

	if _path_index >= _current_path.size():
		return

	var next_point = _current_path[_path_index]
	var dist_to_node = _parent_node.global_position.distance_to(next_point)

	if dist_to_node < 5.0:
		_path_index += 1
		return
		
	var direction = _parent_node.global_position.direction_to(next_point)
	_parent_node.global_position += direction * movement_speed * delta
	
	var look_ahead_pos = _get_look_ahead_point(150.0)
	var target_angle = (look_ahead_pos - _parent_node.global_position).angle()
	_parent_node.rotation = lerp_angle(_parent_node.rotation, target_angle, 5.0 * delta)

func _get_look_ahead_point(distance: float) -> Vector2:
	if _current_path.is_empty() or _path_index >= _current_path.size():
		return _parent_node.global_position + Vector2.RIGHT.rotated(_parent_node.rotation) * distance

	var remaining_dist = distance
	var current_pos = _parent_node.global_position
	
	var next_path_pos = _current_path[_path_index]
	var dist_to_next = current_pos.distance_to(next_path_pos)
	
	if dist_to_next > remaining_dist:
		return current_pos.move_toward(next_path_pos, remaining_dist)
	
	remaining_dist -= dist_to_next
	current_pos = next_path_pos
	
	for i in range(_path_index + 1, _current_path.size()):
		var p = _current_path[i]
		var d = current_pos.distance_to(p)
		if d > remaining_dist:
			return current_pos.move_toward(p, remaining_dist)
		remaining_dist -= d
		current_pos = p
		
	return current_pos

func is_navigation_finished() -> bool:
	return _current_path.is_empty() or _path_index >= _current_path.size()

func stop() -> void:
	_current_path = []
	_path_index = 0
	_is_using_abstract_movement = false
