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
var _abstract_repath_timer: float = 0.0
const ABSTRACT_REPATH_INTERVAL: float = 2.0

func set_target_position(target_pos: Vector2) -> void:
	if map_manager == null:
		push_warning("CaravanNavigator: Cannot set target, MapManager is null.")
		return
		
	_target_pos = target_pos
	
	# Check if we are in the loaded world region
	var in_bounds = map_manager.is_point_in_active_region(_parent_node.global_position)
	
	if in_bounds:
		# We are loaded! Use high-res pathfinding
		_is_using_abstract_movement = false
		_current_path = map_manager.get_path_world(_parent_node.global_position, target_pos)
		
		# If path failed but we are in bounds (e.g. target is far away), fallback to abstract?
		# For now, if grid path is empty, we might be stuck or target is OOB. 
		# If target is OOB, get_path_world returns empty.
		if _current_path.is_empty():
			# Fallback to abstract if grid failed (likely target OOB)
			_is_using_abstract_movement = true
	else:
		# We are far away (Off-screen). Use Abstract Movement.
		_is_using_abstract_movement = true
		_current_path = [] # No grid path
		
	_path_index = 0
	
	# Update visual
	if not _is_using_abstract_movement:
		_debug_line.points = _current_path
	else:
		_debug_line.points = PackedVector2Array() # No debug line for abstract

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
				set_target_position(_target_pos)
		return

	# Standard Grid Movement Logic (On-Screen)
	if is_navigation_finished():
		_debug_line.points = PackedVector2Array() # Clear line when done
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

func is_navigation_finished() -> bool:
	return _current_path.is_empty() or _path_index >= _current_path.size()

func stop() -> void:
	_current_path = []
	_path_index = 0
	if _debug_line:
		_debug_line.points = PackedVector2Array()

func _exit_tree() -> void:
	if _debug_line != null:
		_debug_line.queue_free()

func _on_velocity_computed(_safe_velocity: Vector2) -> void:
	# Deprecated
	pass
