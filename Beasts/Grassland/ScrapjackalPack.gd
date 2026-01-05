class_name ScrapjackalPack extends Beast

## T1 Grassland - Scrapjackal Pack
## Fast nippers with modest damage and low staying power
## Future: +25% resource detection radius (scrap, parts)

const BASE_HEALTH: int = 15
const BASE_DAMAGE: int = 6
const BASE_DEFENSE: int = 2

const WANDER_RADIUS: float = 1200.0
const AGGRO_RADIUS: float = 300.0
const WANDER_WAIT_TIME: float = 3.0
const RETURN_TICKS: int = 30


enum State {SPAWN_WAIT, IDLE, WANDER, CHASE, RETURN_HOME}
var current_state: State = State.SPAWN_WAIT
var state_timer: float = 0.0

# Debug
var _debug_line_target: Vector2 = Vector2.ZERO

var home_position: Vector2 = Vector2.ZERO
var current_target: Node2D = null

func _ready() -> void:
	super._ready()
	initialize_charactersheet(BASE_HEALTH, BASE_DAMAGE, BASE_DEFENSE)
	movement_speed = 90.0
	ai_behavior = "roam"
	home_position = Vector2.ZERO
	current_state = State.SPAWN_WAIT
	# print("[Scrapjackal] %s Spawned. Waiting for positioning." % name)

func _update_ai(delta: float) -> void:
	state_timer -= delta
	queue_redraw() # Debug lines

	match current_state:
		State.SPAWN_WAIT:
			if global_position != Vector2.ZERO:
				home_position = global_position
				current_state = State.IDLE
				state_timer = 1.0 # Brief pause before acting
				# print("[Scrapjackal] %s Home Set: %s" % [name, home_position])
			
		State.IDLE:
			_check_for_enemies()
			if state_timer <= 0.0:
				current_state = State.WANDER
				_pick_wander_target()
		
		State.WANDER:
			_check_for_enemies()
			update_movement(delta)
			if not has_valid_path() or is_navigation_finished():
				current_state = State.IDLE
				state_timer = WANDER_WAIT_TIME

		State.CHASE:
			if current_target == null or not is_instance_valid(current_target):
				current_state = State.IDLE
				return
				
			var dist = global_position.distance_to(current_target.global_position)
			if dist > AGGRO_RADIUS * 1.5:
				current_target = null
				current_state = State.RETURN_HOME
				return
			
			if dist < 50.0:
				if current_target.is_in_group("player"):
					player_initiated_chase.emit(self)
				elif current_target.is_in_group("caravans"):
					_attack_target(current_target)
				
				current_target = null
				current_state = State.IDLE
				return
			
			# Re-path periodically
			if state_timer <= 0.0:
				move_to(current_target.global_position)
				state_timer = 0.5
			
			update_movement(delta)

		State.RETURN_HOME:
			update_movement(delta)
			if not has_valid_path() or is_navigation_finished():
				current_state = State.IDLE
				state_timer = WANDER_WAIT_TIME

func _check_for_enemies() -> void:
	# Scan for enemies
	var enemy = _find_nearby_enemy()
	if enemy:
		current_target = enemy
		current_state = State.CHASE
		state_timer = 0.0 # Path immediately

func _attack_target(target: Node2D) -> void:
	if current_state == State.CHASE:
		# Stop moving while attacking
		stop_movement()
	
	# Global Combat Manager resolution
	var combat_manager = get_node_or_null("/root/CombatManager")
	if combat_manager == null:
		# Fallback: Check if it's an autoload or singleton. 
		# If not, try find by class or group. For now assume it's an Autoload named 'CombatManager'.
		# Or try to instanciate it if missing? Better to warn.
		push_error("[Scrapjackal] CombatManager not found at /root/CombatManager")
		return

	if combat_manager.has_method("resolve_combat_round"):
		combat_manager.resolve_combat_round(self, target)
		print("[Scrapjackal] Combat round resolved against %s" % target.name)
		
		# Simple cooldown/waiting logic
		# If the target is still alive, we might want to continue chasing or attack again.
		# For now, let's just pause briefly.
		state_timer = 1.0 # Wait 1s before next action (move or attack)
		
		# If target died, return to idle (beast death handled by signal, but what about caravan?)
		# We'll let the next update loop handle target validity check.
	else:
		push_error("[Scrapjackal] CombatManager missing resolve_combat_round method!")
		
func stop_movement() -> void:
	if navigator:
		navigator.stop()

func _pick_wander_target() -> void:
	# 1. Pick random point in donut
	# 2. Try move_to
	# 3. If fail, pick another
	# 4. If all fail, IDLE
	for i in range(5):
		var angle = randf() * TAU
		var dist = randf_range(100.0, 400.0)
		var offset = Vector2(cos(angle), sin(angle)) * dist
		var tentative_pos = home_position + offset # Always wander relative to home
		
		# Validate distance from home (redundant with math above, but good for safety)
		if tentative_pos.distance_to(home_position) > WANDER_RADIUS:
			continue
			
		_debug_line_target = tentative_pos
		move_to(tentative_pos)
		
		if has_valid_path():
			return # Success
			
	# Failure
	state_timer = 1.0
	current_state = State.IDLE

func _find_nearby_enemy() -> Node2D:
	var player_bus: Node2D = get_tree().get_first_node_in_group("player")
	if player_bus != null:
		var distance: float = global_position.distance_to(player_bus.global_position)
		if distance <= AGGRO_RADIUS:
			return player_bus

	var caravans = get_tree().get_nodes_in_group("caravans") # Typed Array Check
	for caravan in caravans:
		if caravan is Node2D:
			var distance: float = global_position.distance_to(caravan.global_position)
			if distance <= AGGRO_RADIUS:
				return caravan as Node2D

	return null

func _is_at_destination() -> bool:
	return is_navigation_finished()

func _draw() -> void:
	if _debug_line_target != Vector2.ZERO:
		draw_line(Vector2.ZERO, to_local(_debug_line_target), Color(1, 0, 0, 0.5), 1.0)
