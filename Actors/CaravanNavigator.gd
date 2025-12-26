# CaravanNavigator.gd
extends Node
class_name CaravanNavigator

## Manages navigation and movement for a Caravan.
## Handles NavigationAgent2D integration and avoidance.

var agent: NavigationAgent2D
var movement_speed: float = 100.0
var _safe_velocity: Vector2 = Vector2.ZERO
var _parent_node: Node2D

func setup(parent: Node2D, nav_agent: NavigationAgent2D, speed: float) -> void:
	_parent_node = parent
	agent = nav_agent
	movement_speed = speed
	
	if agent != null:
		agent.max_speed = movement_speed
		# Connect to avoidance system if not already connected
		if not agent.velocity_computed.is_connected(_on_velocity_computed):
			agent.velocity_computed.connect(_on_velocity_computed)

func set_target_position(target_pos: Vector2) -> void:
	if agent != null:
		agent.target_position = target_pos

func set_navigation_layers(layers: int) -> void:
	if agent != null:
		agent.navigation_layers = layers

func update_movement(delta: float) -> void:
	if agent == null or _parent_node == null:
		return
		
	if is_navigation_finished():
		return

	# Calculate desired velocity
	var next_pos: Vector2 = agent.get_next_path_position()
	var direction: Vector2 = (next_pos - _parent_node.global_position).normalized()
	var desired_velocity: Vector2 = direction * movement_speed
	
	# Pass to avoidance system
	agent.set_velocity(desired_velocity)
	
	# Apply safe velocity (updated via signal)
	_parent_node.global_position += _safe_velocity * delta

func is_navigation_finished() -> bool:
	if agent == null:
		return true
	return agent.is_navigation_finished()

func stop() -> void:
	if agent != null:
		agent.set_velocity(Vector2.ZERO)
	_safe_velocity = Vector2.ZERO

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	_safe_velocity = safe_velocity
