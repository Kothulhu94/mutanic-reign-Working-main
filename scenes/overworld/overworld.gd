extends Node2D

@export var bus_scene: PackedScene = preload("uid://c14uenn8n47fb")
@export var camera_scene: PackedScene = preload("uid://ckanwjybdtmp4")
@export var caravan_scene: PackedScene = preload("uid://bgbook0avqvjl")

@export var map_origin: Vector2 = Vector2.ZERO
@export var map_size: Vector2 = Vector2(16384, 16384)

@export var bus_spawn_point: Vector2 = Vector2(6000, 10830)

const NAV_LAYERS: int = 1 # keep in lockstep with the NavigationAgent2D

# How close to a waypoint counts as "consumed"
@export var path_trim_tolerance: float = 2.0

# Caravan system
@export var item_db: ItemDB
@export var caravan_types: Array[CaravanType] = []
@export var caravan_spawn_interval: float = 1.0

var bus: CharacterBody2D
var cam: Camera2D

var _is_paused: bool = false
@onready var path_line: Line2D = get_node_or_null("PathLine")

var _player_bus: Bus

# Grid-Based Pathfinding
var map_manager: MapManager

# Managers
const CaravanManagerScript = preload("res://scenes/overworld/components/CaravanManager.gd")
const UIManagerScript = preload("res://scenes/overworld/components/OverworldUIManager.gd")

var caravan_manager: Node
var ui_manager: Node

func _process(_delta: float) -> void:
	if _is_paused:
		return
	
	# Update PathLine from Bus Path
	if _player_bus != null:
		var points = _player_bus.get_current_path_points()
		if points.size() > 0:
			var pts = PackedVector2Array([_player_bus.global_position])
			pts.append_array(points)
			if path_line:
				path_line.points = pts
				path_line.visible = true
		else:
			if path_line and path_line.visible:
				path_line.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _player_bus == null:
		return
		
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			# Movement Command
			var target_pos = get_global_mouse_position()
			
			# Stop chasing any target
			if _player_bus.has_method("chase_target"):
				_player_bus.chase_target(null)
			
			# Move to position
			if _player_bus.has_method("move_to"):
				_player_bus.move_to(target_pos)
			
			get_viewport().set_input_as_handled()

func _ready() -> void:
	# Robustness: Reload defaults if Inspector overrides set them to null
	if bus_scene == null:
		bus_scene = load("uid://c14uenn8n47fb")
	if camera_scene == null:
		camera_scene = load("uid://ckanwjybdtmp4")
	if caravan_scene == null:
		caravan_scene = load("uid://bgbook0avqvjl")

	# Initialize MapLoader to load chunked map
	var map_loader = MapLoader.new()
	if map_loader:
		map_loader.name = "MapLoader"
		
		var map_scenery = get_node_or_null("MapScenery")
		if map_scenery:
			map_scenery.add_child(map_loader)
		else:
			add_child(map_loader)
			
		map_loader.get_parent().move_child(map_loader, 0)


	# Find MapManager (Now potentially inside MapScenery)
	map_manager = get_node_or_null("MapScenery/MapManager") as MapManager
	if map_manager == null:
		# Fallback checking root
		map_manager = get_node_or_null("MapManager") as MapManager
		
	if map_manager == null:
		push_warning("Overworld: MapManager node not found! Please create it.")

	if path_line == null:
		path_line = Line2D.new()
		path_line.name = "PathLine"
		path_line.width = 3.0
		add_child(path_line)
	path_line.visible = false

	# 1. Check for Bus in scene (Editor-placed) accounting for user placing it in MapScenery
	var existing_bus = get_node_or_null("Bus")
	if not existing_bus:
		existing_bus = get_node_or_null("MapScenery/Bus")
	if not existing_bus:
		existing_bus = get_node_or_null("CharacterBody2D")
	if not existing_bus:
		existing_bus = get_node_or_null("MapScenery/CharacterBody2D")
		
	var final_position: Vector2
	
	if existing_bus:
		bus = existing_bus as CharacterBody2D
		_player_bus = bus as Bus
		
		if bus.get_parent() != self:
			push_warning("Overworld: Bus found in %s, should be in Root." % bus.get_parent().name)
			bus.reparent(self, true)
			
		final_position = bus.global_position
	else:
		# 2. Fallback: Spawn Bus programmatically
		bus = bus_scene.instantiate() as CharacterBody2D
		
		bus = bus_scene.instantiate() as CharacterBody2D
		
		var map_scenery = get_node_or_null("MapScenery")
		if map_scenery:
			map_scenery.add_child(bus)
		else:
			add_child(bus)
			
		_player_bus = bus as Bus
		
		# Set position
		final_position = map_origin + bus_spawn_point
		bus.global_position = final_position
	
	if _player_bus != null:
		_player_bus.map_manager = map_manager

	# Connect bus signals
	if _player_bus != null:
		_player_bus.chase_started.connect(_on_chase_started)

	# Spawn Camera
	cam = camera_scene.instantiate() as Camera2D
	cam.set("bus", bus)
	cam.set("map_origin", map_origin)
	cam.set("map_size", map_size)
	# Inject MapManager into Camera if it needs it (optional, but good practice)
	# cam.set("map_manager", map_manager) 
	cam.global_position = final_position
	cam.global_position = final_position
	add_child(cam)
	cam.enabled = true

	# Load default ItemDB if not set
	if item_db == null:
		item_db = load("uid://dpu7dor4326r3")

	# Load default caravan types if not set
	if caravan_types.is_empty():
		caravan_types = [
			load("uid://d0kksk2xxwyvv"),
			load("uid://bl0n1whf7nvp5"),
			load("uid://cey8s0xhonm0l"),
			load("uid://calnlbpqgqy7v")
		]

	# Connect to Timekeeper pause/resume signals
	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null:
		if timekeeper.has_signal("paused"):
			timekeeper.paused.connect(_on_timekeeper_paused)
		if timekeeper.has_signal("resumed"):
			timekeeper.resumed.connect(_on_timekeeper_resumed)

	# -------------------------------------------------------------
	# Initialize Managers
	# -------------------------------------------------------------
	
	# UI Manager
	ui_manager = UIManagerScript.new()
	ui_manager.name = "OverworldUIManager"
	add_child(ui_manager)
	ui_manager.setup(self, _player_bus)
	
	# Caravan Manager
	caravan_manager = CaravanManagerScript.new()
	caravan_manager.name = "OverworldCaravanManager"
	add_child(caravan_manager)
	caravan_manager.setup(self, map_manager, item_db, caravan_scene, caravan_types, caravan_spawn_interval)

# -------------------------------------------------------------------
# Pause/Resume Callbacks
# -------------------------------------------------------------------
func _on_timekeeper_paused() -> void:
	_is_paused = true

func _on_timekeeper_resumed() -> void:
	_is_paused = false

# -------------------------------------------------------------------
# Combat/Path Interactions
# -------------------------------------------------------------------
func _on_chase_started() -> void:
	pass # Pathline will update automatically during chase

func _on_chase_initiated(target_actor: Node2D) -> void:
	if _player_bus != null and bus != null:
		# Set up pathline to show route to target (caravan or beast den)
		if map_manager != null:
			var world_path: PackedVector2Array = map_manager.get_path_world(bus.global_position, target_actor.global_position)
			_set_path_line(world_path)

		# Start the chase
		_player_bus.chase_target(target_actor)

func _set_path_line(points: PackedVector2Array) -> void:
	if path_line:
		path_line.points = points
		path_line.visible = true
