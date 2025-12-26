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
	
	# Wait for scene tree
	await get_tree().physics_frame
	
	# Carve navigation hole
	_carve_navigation_hole(radius)

func _carve_navigation_hole(radius: float) -> void:
	var nav_region: NavigationRegion2D = _find_containing_navigation_region()
	
	if nav_region != null:
		# Backup original geometry first (only once per region)
		NavigationBackup.backup_region(nav_region)
		
		# Carve the hole
		var success := NavigationCarver.carve_circle(
			nav_region,
			global_position,
			radius
		)
		
		if success:
			print("[BeastDen] Carved navigation hole at: ", global_position, " with radius: ", radius)
		else:
			print("[BeastDen] Failed to carve navigation hole")
	else:
		print("[BeastDen] No NavigationRegion2D found for position: ", global_position)

func _find_containing_navigation_region() -> NavigationRegion2D:
	# Get all NavigationRegion2D nodes in the scene
	var regions: Array[NavigationRegion2D] = []
	if overworld != null:
		_find_all_nav_regions(overworld, regions)
	
	# Find the one that actually contains our position
	for region in regions:
		if region.navigation_polygon == null:
			continue
			
		var local_pos := region.to_local(global_position)
		var poly := region.navigation_polygon
		
		# Check if point is inside any of the outlines
		# Note: This assumes the outer boundary is the containment check. 
		# Complex polygons with holes might require more robust checks, 
		# but usually checking the largest outline or any outline is a good start.
		for i in range(poly.get_outline_count()):
			var outline := poly.get_outline(i)
			if Geometry2D.is_point_in_polygon(local_pos, outline):
				return region
				
	return null

func _find_all_nav_regions(node: Node, result: Array[NavigationRegion2D]) -> void:
	if node is NavigationRegion2D:
		result.append(node)
	
	for child in node.get_children():
		_find_all_nav_regions(child, result)

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
			player_initiated_chase.emit(self)
			get_viewport().set_input_as_handled()

func _remove_den() -> void:
	# Restore navigation when den is destroyed
	var nav_region: NavigationRegion2D = _find_containing_navigation_region()
	if nav_region != null:
		NavigationBackup.restore_region(nav_region)
	
	den_destroyed.emit(self)
	queue_free()
