class_name BeastDen extends Area2D

## Beast spawning building with health, emergency spawning, and combat integration
## Blocks caravan/bus movement via NavigationObstacle2D avoidance
## Spawns beasts on a tick-based interval

@export var den_type: BeastDenType
@export var obstacle_radius: float = 45.0 # Circular obstacle for smooth agent sliding (< 60 to allow encounters)

## Combat integration - allows dens to be attacked
var charactersheet: CharacterSheet

## Spawn progress accumulator (like ProcessorBuilding's work_progress)
var spawn_progress: float = 0.0

## Track spawned beasts for cleanup and max limit enforcement
var active_beasts: Array[Node] = []

## Track if emergency spawn has been triggered for current health tier
var emergency_triggered: bool = false

## Reference to overworld for spawning beasts into scene
var overworld: Node = null

signal den_destroyed(den: BeastDen)
signal player_initiated_chase(den_actor: BeastDen)

func _ready() -> void:
	input_pickable = true
	input_event.connect(_on_input_event)
	add_to_group("beast_den")
	_initialize_charactersheet()

	if charactersheet != null:
		charactersheet.health_changed.connect(_on_health_changed)

	overworld = get_tree().current_scene

	var tk: Node = get_node_or_null("/root/Timekeeper")
	if tk != null and tk.has_signal("tick"):
		if not tk.is_connected("tick", Callable(self, "_on_timekeeper_tick")):
			tk.connect("tick", Callable(self, "_on_timekeeper_tick"))

	if overworld == null:
		push_warning("BeastDen: Overworld not found in current_scene, searching root...")
		overworld = get_tree().root.get_node_or_null("Overworld")

	if overworld != null and overworld.has_method("_on_chase_initiated"):
		if not player_initiated_chase.is_connected(overworld._on_chase_initiated):
			player_initiated_chase.connect(overworld._on_chase_initiated)
			print("BeastDen: Connected to Overworld chase signal.")
	else:
		push_error("BeastDen: Could not find Overworld or _on_chase_initiated method!")

	_setup_navigation_blocking()


func _initialize_charactersheet() -> void:
	if den_type == null:
		return

	charactersheet = CharacterSheet.new()
	charactersheet.base_health = den_type.base_health
	charactersheet.base_damage = -59 # Negative damage so den can never harm player (even with max roll)
	charactersheet.base_defense = den_type.base_defense
	charactersheet.initialize_health()

func _setup_navigation_blocking() -> void:
	# Determine radius from type or fallback to local export
	var radius := obstacle_radius
	if den_type != null:
		radius = den_type.obstacle_radius

	# Create StaticBody2D for physical collision
	var static_body := StaticBody2D.new()
	static_body.name = "NavigationBlocker"
	add_child(static_body)
	
	var collision_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	collision_shape.shape = circle
	static_body.add_child(collision_shape)
	
	# Block MapManager AStar
	_update_map_manager_obstacle(true)

func _update_map_manager_obstacle(is_solid: bool) -> void:
	var mm = get_node_or_null("/root/Overworld/MapManager")
	if mm == null:
		# Fallback: try to find in current scene
		mm = get_tree().current_scene.find_child("MapManager", true, false)
	
	if mm != null:
		# Register as grid source to ensure nav mesh exists around den even if off-screen
		# Radius 3 = 7x7 chunks = ~3500px radius, covers 1200px wander + 800px spawn offset easily
		if mm.has_method("register_grid_source"):
			mm.register_grid_source("den_%s" % name, global_position, 3)
		
		var obs_id = "den_" + str(get_instance_id())
		if is_solid:
			var radius := obstacle_radius
			if den_type != null:
				radius = den_type.obstacle_radius
			if mm.has_method("set_dynamic_obstacle"):
				mm.set_dynamic_obstacle(obs_id, global_position, radius, true)
		else:
			if mm.has_method("remove_dynamic_obstacle"):
				mm.remove_dynamic_obstacle(obs_id)


## Called automatically by Timekeeper each game tick
func _on_timekeeper_tick(_dt: float) -> void:
	if den_type == null:
		return

	if den_type.normal_beast_scene == null:
		return

	if charactersheet == null or charactersheet.current_health <= 0:
		_remove_den()
		return

	if _at_max_capacity():
		return

	spawn_progress += 1.0 / den_type.spawn_interval_ticks

	if spawn_progress >= 1.0:
		spawn_progress = 0.0
		_spawn_beast(den_type.normal_beast_scene)

func _at_max_capacity() -> bool:
	if den_type.max_active_beasts <= 0:
		return false

	_cleanup_dead_beasts()
	return active_beasts.size() >= den_type.max_active_beasts

func _spawn_beast(beast_scene: PackedScene) -> void:
	if beast_scene == null:
		return

	if overworld == null:
		overworld = get_tree().current_scene

	var beast: Node2D = beast_scene.instantiate() as Node2D
	if beast == null:
		return

	beast.name = "%s_Beast_%d" % [name, active_beasts.size()]

	var spawn_distance: float = randf_range(650.0, 800.0)
	var spawn_angle: float = randf_range(0.0, TAU)
	var spawn_offset: Vector2 = Vector2(cos(spawn_angle), sin(spawn_angle)) * spawn_distance

	overworld.add_child(beast)
	beast.global_position = global_position + spawn_offset
	
	# Inject MapManager for navigation
	var mm = get_node_or_null("/root/Overworld/MapManager")
	if mm == null:
		mm = overworld.find_child("MapManager", true, false)
		
	if mm != null and beast.has_method("setup"):
		beast.setup(mm)
	
	active_beasts.append(beast)

	if beast.has_signal("tree_exited"):
		beast.tree_exited.connect(_on_beast_removed.bind(beast))

	if beast.has_signal("player_initiated_chase"):
		if overworld.has_method("_on_chase_initiated"):
			beast.player_initiated_chase.connect(overworld._on_chase_initiated)

func _on_beast_removed(beast: Node) -> void:
	var idx: int = active_beasts.find(beast)
	if idx >= 0:
		active_beasts.remove_at(idx)

func _cleanup_dead_beasts() -> void:
	var to_remove: Array[int] = []

	for i: int in range(active_beasts.size()):
		var beast: Node = active_beasts[i]
		if not is_instance_valid(beast) or not beast.is_inside_tree():
			to_remove.append(i)

	for i: int in range(to_remove.size() - 1, -1, -1):
		active_beasts.remove_at(to_remove[i])

func _on_health_changed(new_health: int, max_health: int) -> void:
	if den_type == null:
		return

	if new_health <= 0:
		_remove_den()
		return

	var health_percent: float = float(new_health) / float(max_health)

	if health_percent <= den_type.emergency_health_threshold and not emergency_triggered:
		_trigger_emergency_spawn()
		emergency_triggered = true
	elif health_percent > den_type.emergency_health_threshold:
		emergency_triggered = false

func _trigger_emergency_spawn() -> void:
	if den_type == null:
		return

	var spawn_scene: PackedScene = den_type.emergency_beast_scene
	if spawn_scene == null:
		spawn_scene = den_type.normal_beast_scene

	if spawn_scene == null:
		return

	var spawn_count: int = den_type.emergency_spawn_count

	for i: int in range(spawn_count):
		if _at_max_capacity():
			break
		_spawn_beast(spawn_scene)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			print("BeastDen: Clicked! Emitting chase signal.")
			player_initiated_chase.emit(self)
			get_viewport().set_input_as_handled()

func _remove_den() -> void:
	# Restore navigation when den is destroyed
	_update_map_manager_obstacle(false)
	
	den_destroyed.emit(self)
	queue_free()
