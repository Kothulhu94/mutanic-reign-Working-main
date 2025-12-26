class_name ScrapjackalPack extends Beast

## T1 Grassland - Scrapjackal Pack
## Fast nippers with modest damage and low staying power
## Future: +25% resource detection radius (scrap, parts)

const BASE_HEALTH: int = 15
const BASE_DAMAGE: int = 6
const BASE_DEFENSE: int = 2

const WANDER_RADIUS: float = 400.0
const AGGRO_RADIUS: float = 300.0
const WANDER_WAIT_TIME: float = 3.0

var home_position: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var current_target: Node2D = null

enum AIState {WANDERING, CHASING}
var ai_state: AIState = AIState.WANDERING

func _ready() -> void:
	super._ready()
	initialize_charactersheet(BASE_HEALTH, BASE_DAMAGE, BASE_DEFENSE)
	movement_speed = 90.0
	ai_behavior = "roam"
	home_position = global_position

func _update_ai(delta: float) -> void:
	wander_timer -= delta

	match ai_state:
		AIState.WANDERING:
			_ai_wander(delta)
		AIState.CHASING:
			_ai_chase(delta)

func _ai_wander(_delta: float) -> void:
	var nearby_enemy: Node2D = _find_nearby_enemy()
	if nearby_enemy != null:
		current_target = nearby_enemy
		ai_state = AIState.CHASING
		return

	if wander_timer <= 0.0:
		_set_new_wander_target()
		wander_timer = WANDER_WAIT_TIME

	_move_toward_nav_target()

func _ai_chase(_delta: float) -> void:
	if current_target == null or not is_instance_valid(current_target):
		current_target = null
		ai_state = AIState.WANDERING
		return

	var distance: float = global_position.distance_to(current_target.global_position)

	if distance > AGGRO_RADIUS * 1.5:
		current_target = null
		ai_state = AIState.WANDERING
		return

	if distance < 50.0:
		player_initiated_chase.emit(self)
		current_target = null
		ai_state = AIState.WANDERING
		return

	move_to(current_target.global_position)

	update_movement(_delta)

func _find_nearby_enemy() -> Node2D:
	var player_bus: Node2D = get_tree().get_first_node_in_group("player")
	if player_bus != null:
		var distance: float = global_position.distance_to(player_bus.global_position)
		if distance <= AGGRO_RADIUS:
			return player_bus

	var caravans: Array[Node] = get_tree().get_nodes_in_group("caravans")
	for caravan in caravans:
		if caravan is Node2D:
			var distance: float = global_position.distance_to(caravan.global_position)
			if distance <= AGGRO_RADIUS:
				return caravan as Node2D

	return null

func _set_new_wander_target() -> void:
	var random_angle: float = randf_range(0.0, TAU)
	var random_distance: float = randf_range(100.0, WANDER_RADIUS)
	var offset: Vector2 = Vector2(cos(random_angle), sin(random_angle)) * random_distance
	var target_pos: Vector2 = home_position + offset

	move_to(target_pos)

func _move_toward_nav_target() -> void:
	# Deprecated helper, but kept redirecting to update_movement just in case
	update_movement(get_physics_process_delta_time())
