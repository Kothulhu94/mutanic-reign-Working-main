class_name Beast extends Area2D

## Base class for all spawned beasts
## Specific beast types should extend this and implement their own behavior logic

signal player_initiated_chase(beast: Beast)

## Combat integration - set by spawner or specific beast type
var charactersheet: CharacterSheet = null

## Navigation for movement AI
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

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

	if nav_agent != null:
		nav_agent.navigation_layers = navigation_layers

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
