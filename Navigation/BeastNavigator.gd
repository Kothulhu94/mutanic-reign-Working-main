class_name BeastNavigator extends Node

## Manages navigation and movement for a Beast.
## Handles MapManager grid pathfinding, boundary crossing, and abstract movement.

var map_manager: MapManager
var movement_speed: float = 80.0
var _parent_node: Node2D

# Pathfinding state
var _current_path: PackedVector2Array = []
var _path_index: int = 0
var _target_pos: Vector2 = Vector2.ZERO
var _navigation_layers: int = 1 # Default to Land

# Abstract Movement State (for off-screen/flight/void travel)
var _is_using_abstract_movement: bool = false
var _final_abstract_target: Vector2 = Vector2.ZERO
var _abstract_repath_timer: float = 0.0
const ABSTRACT_REPATH_INTERVAL: float = 0.5
const ARRIVAL_DISTANCE: float = 30.0 # Distance to consider "arrived" and stop early

func setup(parent: Node2D, map_mgr: MapManager, speed: float) -> void:
	_parent_node = parent
	map_manager = map_mgr
	movement_speed = speed
	
	if map_manager == null:
		push_error("BeastNavigator: MapManager is null! Pathfinding will fail.")

func set_target_position(target_pos: Vector2) -> void:
	if map_manager == null:
		push_warning("BeastNavigator: Cannot set target, MapManager is null.")
		return
		
	_final_abstract_target = target_pos
	
	var in_bounds = map_manager.is_point_in_active_region(_parent_node.global_position)
	
	if in_bounds:
		# 1. Try direct path
		_current_path = map_manager.get_path_world(_parent_node.global_position, target_pos, _navigation_layers)
		
		if not _current_path.is_empty():
			_is_using_abstract_movement = false
			_target_pos = target_pos
			
			# Append exact target if the path ends VERY near it (small adjustment only)
			# Reduced from 100.0 to 20.0 to prevent long straight-line snapping
			var last_pt = _current_path[_current_path.size() - 1]
			if last_pt.distance_to(target_pos) > 1.0 and last_pt.distance_to(target_pos) < 20.0:
				_current_path.append(target_pos)
			
			_prune_path_start()
		else:
			# Path failed. Check edge cases.
			if map_manager.is_in_same_active_grid(_parent_node.global_position, target_pos):
				# Blocked local path within valid grid.
				stop()
				return
				
			# Target unreachable/OOB: Path to edge
			var edge_exit = map_manager.get_nav_boundary_exit(_parent_node.global_position, target_pos)
			var edge_path = map_manager.get_path_world(_parent_node.global_position, edge_exit, _navigation_layers)
			
			if not edge_path.is_empty():
				_current_path = edge_path
				_is_using_abstract_movement = false
				_target_pos = edge_exit
				_prune_path_start()
			else:
				# Edge path logic failed.
				# Only switch to abstract if we are ALREADY at the edge.
				if _parent_node.global_position.distance_to(edge_exit) < 40.0:
					_is_using_abstract_movement = true
					_target_pos = map_manager.get_nav_boundary_entry(target_pos, _parent_node.global_position)
				else:
					# Trapped inside grid
					stop()
	else:
		# We are in the void. Abstract movement.
		_is_using_abstract_movement = true
		_current_path = []
		_target_pos = map_manager.get_nav_boundary_entry(target_pos, _parent_node.global_position)
		
	_path_index = 0

func set_navigation_layers(layers: int) -> void:
	_navigation_layers = layers

func stop() -> void:
	_current_path = []
	_path_index = 0
	_is_using_abstract_movement = false
	_target_pos = Vector2.ZERO

func is_navigation_finished() -> bool:
	if _is_using_abstract_movement:
		return false
	
	if not _is_local_path_finished():
		return false
		
	if _final_abstract_target != Vector2.ZERO:
		if _parent_node.global_position.distance_to(_final_abstract_target) > ARRIVAL_DISTANCE:
			return false
			
	return true

func _is_local_path_finished() -> bool:
	return _current_path.is_empty() or _path_index >= _current_path.size()

func update_movement(delta: float) -> void:
	if map_manager == null or _parent_node == null:
		return
		
	# Abstract Movement Logic
	if _is_using_abstract_movement:
		if _target_pos == Vector2.ZERO:
			return
			
		var distance = _parent_node.global_position.distance_to(_target_pos)
		if distance < 10.0:
			_is_using_abstract_movement = false
			return
			
		var abstract_dir = _parent_node.global_position.direction_to(_target_pos)
		_parent_node.global_position += abstract_dir * movement_speed * delta
		
		# Simple rotation for beasts
		var target_angle_abstract = abstract_dir.angle()
		_parent_node.rotation = lerp_angle(_parent_node.rotation, target_angle_abstract, 5.0 * delta)
		
		_abstract_repath_timer += delta
		if _abstract_repath_timer >= ABSTRACT_REPATH_INTERVAL:
			_abstract_repath_timer = 0.0
			if map_manager.is_point_in_active_region(_parent_node.global_position):
				set_target_position(_final_abstract_target)
		return

	# Standard Grid Movement Logic
	
	# Check "Close Enough" logic for organic movement
	if not _current_path.is_empty():
		var final_dest = _current_path[_current_path.size() - 1]
		if _parent_node.global_position.distance_to(final_dest) < ARRIVAL_DISTANCE:
			stop()
			return

	if _is_local_path_finished():
		if _final_abstract_target != Vector2.ZERO and _parent_node.global_position.distance_to(_final_abstract_target) > ARRIVAL_DISTANCE:
			if map_manager.is_point_in_active_region(_parent_node.global_position):
				set_target_position(_final_abstract_target)
			else:
				# Switch to abstract
				_is_using_abstract_movement = true
				_target_pos = map_manager.get_nav_boundary_entry(_final_abstract_target, _parent_node.global_position)
		return

	if _path_index >= _current_path.size():
		return

	# ROBUST MOVEMENT LOOP (Prevents bouncing/overshooting)
	var distance_to_travel = movement_speed * delta
	var current_pos = _parent_node.global_position
	var moved = false
	
	while distance_to_travel > 0.0 and _path_index < _current_path.size():
		var next_point = _current_path[_path_index]
		var dist = current_pos.distance_to(next_point)
		
		if dist <= distance_to_travel:
			# Reached waypoint
			current_pos = next_point
			distance_to_travel -= dist
			_path_index += 1
			moved = true
		else:
			# Move towards waypoint and stop
			current_pos = current_pos.move_toward(next_point, distance_to_travel)
			distance_to_travel = 0.0
			moved = true
	
	# Apply final position
	if moved:
		_parent_node.global_position = current_pos
	
	# Rotation smoothing (Look ahead)
	var look_ahead_pos = _get_look_ahead_point(100.0)
	var rotation_angle = (look_ahead_pos - _parent_node.global_position).angle()
	_parent_node.rotation = lerp_angle(_parent_node.rotation, rotation_angle, 5.0 * delta)

func _prune_path_start() -> void:
	if _current_path.size() <= 1:
		return
		
	var current_pos = _parent_node.global_position
	
	for i in range(min(_current_path.size() - 1, 4)):
		var a = _current_path[i]
		var b = _current_path[i + 1]
		var v_seg = b - a
		var len2 = v_seg.length_squared()
		
		if len2 < 0.001: continue
		
		var t = (current_pos - a).dot(v_seg) / len2
		
		if t > 0.0:
			_path_index = i + 1
			if t <= 1.0: break
		else:
			break

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

func get_current_path_points() -> PackedVector2Array:
	if _current_path.is_empty():
		return []
	if _path_index < _current_path.size():
		return _current_path.slice(_path_index)
	return []
