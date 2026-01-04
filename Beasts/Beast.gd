class_name Beast extends Area2D

## Base class for all spawned beasts
## Specific beast types should extend this and implement their own behavior logic

signal player_initiated_chase(beast: Beast)

## Combat integration - set by spawner or specific beast type
var charactersheet: CharacterSheet = null

## Navigation for movement AI

var map_manager: MapManager
var _current_path: PackedVector2Array = []
var _path_index: int = 0

## Movement configuration
@export var movement_speed: float = 80.0
@export var navigation_layers: int = 1

## AI behavior type (specific beasts override this)
@export_enum("roam", "hunt_caravans", "hunt_player", "territorial") var ai_behavior: String = "roam"

## Reference to spawning den (optional)
var source_den: BeastDen = null

## Pause state
var _is_paused: bool = false

func _ready() -> void:
	add_to_group("beasts")

	# Find MapManager
	map_manager = get_node_or_null("/root/Overworld/MapManager")
	if map_manager == null:
		# Fallback search
		var p = get_parent()
		while p != null:
			if p.has_node("MapManager"):
				map_manager = p.get_node("MapManager")
				break
			p = p.get_parent()

	input_event.connect(_on_input_event)

	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null:
		if timekeeper.has_signal("paused"):
			timekeeper.paused.connect(_on_timekeeper_paused)
		if timekeeper.has_signal("resumed"):
			timekeeper.resumed.connect(_on_timekeeper_resumed)

	if charactersheet != null:
		charactersheet.health_changed.connect(_on_health_changed)

func _physics_process(delta: float) -> void:
	if _is_paused:
		return

	_update_ai(delta)

func _update_ai(_delta: float) -> void:
	pass

# --- Movement API for subclasses ---
func move_to(target_pos: Vector2) -> void:
	if map_manager == null:
		print("[Beast] %s: MapManager is null!" % name)
		return
	_current_path = map_manager.get_path_world(global_position, target_pos)
	
	if _current_path.is_empty():
		print("[Beast] %s: Path to %s failed! (Start: %s)" % [name, target_pos, global_position])
		var start_cell = map_manager.global_to_map(global_position)
		var end_cell = map_manager.global_to_map(target_pos)
		print("[Beast] Grid Coords - Start: %s, End: %s" % [start_cell, end_cell])
	else:
		# print("[Beast] %s: Path found with %d points" % [name, _current_path.size()])
		pass
		
	_path_index = 0

	# OPTIMIZATION: path smoothing
	# If the first point in the path is the cell we are currently in, skip it 
	# to avoid backtracking to the exact center of the current cell.
	if _current_path.size() > 1:
		var current_cell = map_manager.local_to_map(global_position)
		var start_path_cell = map_manager.local_to_map(_current_path[0])
		if current_cell == start_path_cell:
			_path_index = 1

func update_movement(delta: float) -> void:
	if _current_path.is_empty():
		return

	if _path_index >= _current_path.size():
		return

	var next_point = _current_path[_path_index]
	var distance = global_position.distance_to(next_point)

	if distance < 5.0:
		_path_index += 1
		return

	var direction = global_position.direction_to(next_point)
	global_position += direction * movement_speed * delta

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			player_initiated_chase.emit(self)

func _on_timekeeper_paused() -> void:
	_is_paused = true

func _on_timekeeper_resumed() -> void:
	_is_paused = false

func _on_health_changed(new_health: int, _max_health: int) -> void:
	if new_health <= 0:
		_on_death()

func _on_death() -> void:
	queue_free()

func initialize_charactersheet(base_health: int, base_damage: int, base_defense: int) -> void:
	charactersheet = CharacterSheet.new()
	charactersheet.base_health = base_health
	charactersheet.base_damage = base_damage
	charactersheet.base_defense = base_defense
	charactersheet.initialize_health()
	charactersheet.health_changed.connect(_on_health_changed)
