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
var _navigation_layers: int = 1 # Default to Land

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
		# 1. Try direct path
		_current_path = map_manager.get_path_world(_parent_node.global_position, target_pos, _navigation_layers)
		
		if not _current_path.is_empty():
			_is_using_abstract_movement = false
			_target_pos = target_pos
			_prune_path_start() # Fix for jerky movement (Backtracking)
		else:
			# Path failed. 
			# Check if both Start and End are in the SAME active grid.
			# If so, the failure is due to obstacles (Walls, Water, Dens) in the grid.
			if map_manager.is_in_same_active_grid(_parent_node.global_position, target_pos):
				# BRIDGING LOGIC:
				# If blocked by water, try to build a bridge?
				# Request a "Builder Path" (Layer 3)
				var builder_path = map_manager.get_bridging_path(_parent_node.global_position, target_pos)
				
				if not builder_path.is_empty():
					print("CaravanNavigator: Standard path blocked. Builder path found! Constructing bridge...")
					_current_path = builder_path
					_is_using_abstract_movement = false
					_target_pos = target_pos
					_prune_path_start()
					return
				
				# Blocked local path within valid grid. Stop.
				print("CaravanNavigator: Local path blocked to %s. Stopping." % target_pos)
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
				# Only fly if we are ALREADY at the edge.
				if _parent_node.global_position.distance_to(edge_exit) < 40.0:
					_is_using_abstract_movement = true
					_target_pos = map_manager.get_nav_boundary_entry(target_pos, _parent_node.global_position)
				else:
					print("CaravanNavigator: trapped inside grid (dist to exit: %.1f). Stopping." % _parent_node.global_position.distance_to(edge_exit))
					stop()
	else:
		# We are in the void. FLIGHT MODE.
		_is_using_abstract_movement = true
		_current_path = []
		_target_pos = map_manager.get_nav_boundary_entry(target_pos, _parent_node.global_position)
		
	_path_index = 0

func set_navigation_layers(layers: int) -> void:
	_navigation_layers = layers

## Smooths the path start by skipping nodes we've already passed.
## Aligns with Bus.gd behavior to prevent "jerky" backtracking.
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
			if t <= 1.0: break # On this segment
		else:
			break # Behind segment 'a'

func update_movement(delta: float) -> void:
	if map_manager == null or _parent_node == null:
		return
		
	# Abstract Movement Logic (Off-Screen / Void)
	if _is_using_abstract_movement:
		if _target_pos == Vector2.ZERO:
			return
			
		var distance = _parent_node.global_position.distance_to(_target_pos)
		if distance < 10.0:
			# Arrived at flight target (Edge or Hub)
			_is_using_abstract_movement = false
			return
			
		var abstract_dir = _parent_node.global_position.direction_to(_target_pos)
		_parent_node.global_position += abstract_dir * movement_speed * delta
		
		_abstract_repath_timer += delta
		if _abstract_repath_timer >= ABSTRACT_REPATH_INTERVAL:
			_abstract_repath_timer = 0.0
			# Check if we accidentally entered a valid region during flight
			if map_manager.is_point_in_active_region(_parent_node.global_position):
				set_target_position(_final_abstract_target)
		
		var fly_angle = abstract_dir.angle()
		_parent_node.rotation = lerp_angle(_parent_node.rotation, fly_angle, 5.0 * delta)
		return

	# Standard Grid Movement Logic (On-Screen)
	if _is_local_path_finished():
		if _final_abstract_target != Vector2.ZERO and _parent_node.global_position.distance_to(_final_abstract_target) > 20.0:
			# We finished our local path (e.g. at edge), but are still far from final target.
			# CRITICAL: Check if we are in a valid grid.
			if map_manager.is_point_in_active_region(_parent_node.global_position):
				# We are in a grid (e.g. just landed at destination edge).
				# We should NOT fly. We should pathfind to the center.
				# Trigger re-pathing to final target now that we are in range.
				set_target_position(_final_abstract_target)
			else:
				# We are at the edge of the void. Switch to flight.
				# print("CaravanNavigator: At void edge. Switching to Abstract Flight.")
				_is_using_abstract_movement = true
				_target_pos = map_manager.get_nav_boundary_entry(_final_abstract_target, _parent_node.global_position)
		return

	if _path_index >= _current_path.size():
		return

	var next_point = _current_path[_path_index]
	var dist_to_node = _parent_node.global_position.distance_to(next_point)

	if dist_to_node < 5.0:
		_path_index += 1
		# CHECK FOR BRIDGE CONSTRUCTION
		# If we just walked onto a node, ensure it is built if it was water.
		map_manager.build_bridge_if_water(_parent_node.global_position)
		return
		
	var direction = _parent_node.global_position.direction_to(next_point)
	_parent_node.global_position += direction * movement_speed * delta
	
	# CONTINUOUS BRIDGE BUILDING (for robustness)
	# Check point underfoot slightly ahead or current?
	# Using 'build_bridge_at' is safe to call repeatedly.
	map_manager.build_bridge_if_water(_parent_node.global_position)
	
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
	
func get_current_path_points() -> PackedVector2Array:
	if _current_path.is_empty():
		return []
		
	# Return slice from current index to end
	if _path_index < _current_path.size():
		return _current_path.slice(_path_index)
	return []

func is_navigation_finished() -> bool:
	# 1. If flying, we are not finished
	if _is_using_abstract_movement:
		return false
		
	# 2. If local path is not done, we are not finished
	if not _is_local_path_finished():
		return false
		
	# 3. Path is done, but are we at the destination?
	# If we are far from the target (and not using abstract yet), acts as "not finished"
	# to allow update_movement to trigger the switch to abstract.
	if _final_abstract_target != Vector2.ZERO:
		if _parent_node.global_position.distance_to(_final_abstract_target) > 25.0:
			return false
			
	return true

func _is_local_path_finished() -> bool:
	return _current_path.is_empty() or _path_index >= _current_path.size()

func is_using_abstract_movement() -> bool:
	return _is_using_abstract_movement

func get_final_target() -> Vector2:
	return _final_abstract_target

func stop() -> void:
	_current_path = []
	_path_index = 0
	_is_using_abstract_movement = false
