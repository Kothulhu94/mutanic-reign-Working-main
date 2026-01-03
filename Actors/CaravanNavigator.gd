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

# Debug Visual
var _debug_line: Line2D

func setup(parent: Node2D, map_mgr: MapManager, speed: float) -> void:
	_parent_node = parent
	map_manager = map_mgr
	movement_speed = speed
	
	if map_manager == null:
		push_error("CaravanNavigator: MapManager is null! Pathfinding will fail.")
		
	# Setup Debug Line
	_debug_line = Line2D.new()
	_debug_line.width = 2.0
	_debug_line.default_color = Color(0, 1, 0, 0.5) # Semi-transparent green
	_debug_line.top_level = true # Draw in world space, ignoring parent rotation/scale
	add_child(_debug_line)

# Abstract Movement State (for off-screen/distant travel)
var _is_using_abstract_movement: bool = false
var _final_abstract_target: Vector2 = Vector2.ZERO # The true goal
var _abstract_repath_timer: float = 0.0
const ABSTRACT_REPATH_INTERVAL: float = 0.5 # Check more frequently (0.5s) for re-entry

func set_target_position(target_pos: Vector2) -> void:
	if map_manager == null:
		push_warning("CaravanNavigator: Cannot set target, MapManager is null.")
		return
		
	# Store true target
	_final_abstract_target = target_pos
	
	# Check if we are in the loaded world region at all
	var in_bounds = map_manager.is_point_in_active_region(_parent_node.global_position)
	
	if in_bounds:
		# we are loaded, try pathfinding directly
		_current_path = map_manager.get_path_world(_parent_node.global_position, target_pos)
		
		if not _current_path.is_empty():
			# Success, target is reachable in current grid (or merged grids)
			_is_using_abstract_movement = false
			_target_pos = target_pos # Use direct target
		else:
			# Target unreachable/OOB: Path to edge
			# Ask MapManager where the line to target exits our current grid
			var edge_exit = map_manager.get_nav_boundary_exit(_parent_node.global_position, target_pos)
			
			# Pathfind to that edge
			var edge_path = map_manager.get_path_world(_parent_node.global_position, edge_exit)
			
			if not edge_path.is_empty():
				_current_path = edge_path
				_is_using_abstract_movement = false # We are grid moving towards edge
				_target_pos = edge_exit # Immediate target is edge
			else:
				# Even edge is unreachable? Fallback to flying immediately.
				_is_using_abstract_movement = true
				_target_pos = target_pos
	else:
		# We are far away (Off-screen). Use Abstract Movement.
		_is_using_abstract_movement = true
		_current_path = [] # No grid path
		_target_pos = target_pos
		
	_path_index = 0
	
	# Update visual
	if _debug_line:
		if not _is_using_abstract_movement:
			_debug_line.points = _current_path
			_debug_line.default_color = Color(0, 1, 0, 0.5) # Green
		else:
			# Visual for flying
			_debug_line.points = PackedVector2Array([_parent_node.global_position, _target_pos])
			_debug_line.default_color = Color(1, 1, 0, 0.5) # Yellow for flying

func set_navigation_layers(_layers: int) -> void:
	# Grid pathfinding doesn't strictly use layers in this simple implementation
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
			# Arrived at target (Abstract)
			_is_using_abstract_movement = false
			return
			
		# Linear move
		var abstract_dir = _parent_node.global_position.direction_to(_target_pos)
		_parent_node.global_position += abstract_dir * movement_speed * delta
		
		# Periodically check if we have entered the valid grid region
		_abstract_repath_timer += delta
		if _abstract_repath_timer >= ABSTRACT_REPATH_INTERVAL:
			_abstract_repath_timer = 0.0
			if map_manager.is_point_in_active_region(_parent_node.global_position):
				# We entered the world! Switch to real pathfinding
				set_target_position(_final_abstract_target)
		
		# Also update rotation while flying
		var fly_angle = abstract_dir.angle()
		_parent_node.rotation = lerp_angle(_parent_node.rotation, fly_angle, 5.0 * delta)
		return

	# Standard Grid Movement Logic (On-Screen)
	if is_navigation_finished():
		_debug_line.points = PackedVector2Array() # Clear line when done
		
		# If we finished a grid path but haven't reached the FINAL target (e.g. we just reached the edge)
		# switching to abstract movement
		if _parent_node.global_position.distance_to(_final_abstract_target) > 20.0:
			# We are not there yet. Start flying!
			_is_using_abstract_movement = true
			_target_pos = _final_abstract_target
			# Visual for flying
			if _debug_line:
				_debug_line.points = PackedVector2Array([_parent_node.global_position, _target_pos])
				_debug_line.default_color = Color(1, 1, 0, 0.5)
		return

	if _path_index >= _current_path.size():
		return

	var next_point = _current_path[_path_index]
	var dist_to_node = _parent_node.global_position.distance_to(next_point)

	# Check arrival at waypoint
	if dist_to_node < 5.0:
		_path_index += 1
		return
		
	# Move
	var direction = _parent_node.global_position.direction_to(next_point)
	_parent_node.global_position += direction * movement_speed * delta
	
	# Rotation Logic: Look ahead 150 pixels for smooth turning
	var look_ahead_pos = _get_look_ahead_point(150.0)
	var target_angle = (look_ahead_pos - _parent_node.global_position).angle()
	# Lerp rotation for smoothness
	_parent_node.rotation = lerp_angle(_parent_node.rotation, target_angle, 5.0 * delta)

func _get_look_ahead_point(distance: float) -> Vector2:
	if _current_path.is_empty() or _path_index >= _current_path.size():
		return _parent_node.global_position + Vector2.RIGHT.rotated(_parent_node.rotation) * distance

	var remaining_dist = distance
	var current_pos = _parent_node.global_position
	
	# 1. Check distance to immediate next waypoint
	var next_path_pos = _current_path[_path_index]
	var dist_to_next = current_pos.distance_to(next_path_pos)
	
	if dist_to_next > remaining_dist:
		return current_pos.move_toward(next_path_pos, remaining_dist)
	
	# 2. Advance past immediate waypoint
	remaining_dist -= dist_to_next
	current_pos = next_path_pos
	
	# 3. Iterate subsequent waypoints
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
	if _debug_line:
		_debug_line.points = PackedVector2Array()

func _exit_tree() -> void:
	if _debug_line != null:
		_debug_line.queue_free()

func _on_velocity_computed(_safe_velocity: Vector2) -> void:
	# Deprecated
	pass
