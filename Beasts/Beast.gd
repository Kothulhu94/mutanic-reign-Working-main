class_name Beast extends Area2D

## Base class for all spawned beasts
## Specific beast types should extend this and implement their own behavior logic

signal player_initiated_chase(beast: Beast)

## Combat integration - set by spawner or specific beast type
var charactersheet: CharacterSheet = null

## Navigation for movement AI
var navigator: BeastNavigator
var map_manager: MapManager

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

	# Initialize Navigator
	navigator = BeastNavigator.new()
	add_child(navigator)

	# Find MapManager fallback
	if map_manager == null:
		map_manager = get_node_or_null("/root/Overworld/MapManager")
		if map_manager == null:
			# Fallback search
			var p = get_parent()
			while p != null:
				if p.has_node("MapManager"):
					map_manager = p.get_node("MapManager")
					break
				p = p.get_parent()
	
	if map_manager != null:
		navigator.setup(self, map_manager, movement_speed)
		navigator.set_navigation_layers(navigation_layers)

	input_event.connect(_on_input_event)

	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null:
		if timekeeper.has_signal("paused"):
			timekeeper.paused.connect(_on_timekeeper_paused)
		if timekeeper.has_signal("resumed"):
			timekeeper.resumed.connect(_on_timekeeper_resumed)

	if charactersheet != null:
		charactersheet.health_changed.connect(_on_health_changed)

func setup(map_mgr: MapManager) -> void:
	map_manager = map_mgr
	if navigator != null:
		navigator.setup(self, map_mgr, movement_speed)
		navigator.set_navigation_layers(navigation_layers)

func _physics_process(delta: float) -> void:
	if _is_paused:
		return

	_update_ai(delta)

func _update_ai(_delta: float) -> void:
	pass

# --- Movement API for subclasses ---
func move_to(target_pos: Vector2) -> void:
	if navigator:
		navigator.set_target_position(target_pos)

func update_movement(delta: float) -> void:
	if navigator:
		navigator.update_movement(delta)

# --- Navigation Helpers ---
func is_navigation_finished() -> bool:
	if navigator:
		return navigator.is_navigation_finished()
	return true

func has_valid_path() -> bool:
	if navigator:
		return not navigator._current_path.is_empty()
	return false

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
