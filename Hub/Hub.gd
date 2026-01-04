# Hub.gd — Godot 4.5 (Refactored with component architecture)
@tool
extends Node2D
class_name Hub

## Central hub coordinator, delegating functionality to specialized components.
## Refactored from 692-line monolith to component-based architecture.

@export var state: HubStates

# Component instances (created at runtime)
var economy_manager: HubEconomyManager
var trading_system: HubTradingSystem
var troop_production: HubTroopProduction
var ui_controller: HubUIController
var building_manager: HubBuildingManager

# Fleet Management (The Garage)
var fleet: Array[Caravan] = []
var idle_fleet: Array[Caravan] = []

signal caravan_spawn_requested(hub: Hub, type: CaravanType)

# UI references (assigned in editor)
@export var hub_menu_ui: HubMenuUI = null
@export var market_ui: MarketUI = null
@export var recruitment_ui: RecruitmentUI = null

# Debug
@export var debug_draw_grid: bool = false:
	set(value):
		debug_draw_grid = value
		queue_redraw()

# Backing fields for exported props with setters
var _item_db: ItemDB
var _economy_config: EconomyConfig

# Exported properties with setters so runtime/editor changes rewire the engine
@export var item_db: ItemDB:
	set(value):
		_item_db = value
		_on_item_db_changed()
	get:
		return _item_db

@export var economy_config: EconomyConfig:
	set(value):
		_economy_config = value
		_on_economy_config_changed()
	get:
		return _economy_config

@onready var click_and_fade: Area2D = get_node_or_null("ClickAndFade") as Area2D
@onready var slots: BuildSlots = get_node_or_null("BuildSlots") as BuildSlots

# Resource level accessors (delegate to economy_manager)
var food_level: float:
	get: return economy_manager.food_level if economy_manager else 0.0

var infrastructure_level: float:
	get: return economy_manager.infrastructure_level if economy_manager else 0.0

var medical_level: float:
	get: return economy_manager.medical_level if economy_manager else 0.0

var luxury_level: float:
	get: return economy_manager.luxury_level if economy_manager else 0.0

# Price accessor (delegate to trading_system)
var item_prices: Dictionary:
	get: return trading_system.item_prices if trading_system else {}

func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
		return

	# Ensure hub state
	if state == null:
		state = HubStates.new()
	state.ensure_slots(9)
	
	# Initialize Governor Sheet
	if state.governor_sheet == null:
		state.governor_sheet = CharacterSheet.new()
		state.governor_sheet.character_name = "Governor " + state.display_name
		
	# Ensure Trading Skill
	if state.governor_sheet.get_skill(&"Trading") == null:
		var skill_res = Skills.get_skill(&"Trading")
		if skill_res:
			state.governor_sheet.add_skill(skill_res)
	
	# Initialize troop stock if empty
	if state.troop_stock.is_empty():
		var troop_db: TroopDatabase = get_node_or_null("/root/TroopDatabase")
		if troop_db != null:
			for i in range(5):
				_spawn_random_t1_pity(troop_db)
	
	# Ensure per-instance config (duplicate if a .tres)
	_ensure_unique_economy_config()
	
	# Initialize components
	_initialize_components()
	
	# Ensure starter inventory (must be after components are initialized)
	_initialize_starter_inventory()
	
	# Realize placed buildings from state
	if slots != null:
		slots.realize_from_state(state)
		building_manager.inject_item_db()
		
	# Wire Timekeeper
	_connect_timekeeper()
	
	# Wire proximity signals
	_connect_proximity_signals()
	
	# Register as Map Chunk source (Visuals)
	# Path: Hub -> Overworld -> MapScenery -> MapLoader
	var map_loader = get_tree().get_root().find_child("MapLoader", true, false)
	if map_loader and map_loader.has_method("register_source"):
		map_loader.register_source(self)

	# Register as Pathfinding Grid source (Logic)
	# Path: Hub -> Overworld -> MapScenery -> MapManager
	var map_manager = get_tree().get_root().find_child("MapManager", true, false)
	if map_manager and map_manager.has_method("register_grid_source"):
		# Radius 1 with PLUS shape (Center + Up/Down/Left/Right)
		map_manager.register_grid_source(name, global_position, 1, 1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		if debug_draw_grid:
			queue_redraw()

func _draw() -> void:
	if not debug_draw_grid:
		return

	# Replicate MapManager logic for visualization
	var base_chunk_size = 1024 # MapManager.CHUNK_SIZE
	var radius = 1
	
	# Auto-detect Map Scale from sibling MapScenery (standard architecture)
	# MapManager is a child of MapScenery, so its local 1024 units = 1024 * Scale global units.
	var map_scale = 1.0
	var parent = get_parent()
	if parent:
		var scenery = parent.get_node_or_null("MapScenery")
		if scenery:
			map_scale = scenery.scale.x
			
	var chunk_size = base_chunk_size * map_scale
	
	# Current Logic uses GridShape.PLUS (Diamond/Star shape)
	# This includes the Center Chunk + Up, Down, Left, Right chunks (Manhattan Dist <= radius)
	var center_chunk = (global_position / chunk_size).floor()
	var color = Color.BLUE
	
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			# Filter for PLUS shape (Manhattan Distance)
			if abs(x) + abs(y) > radius:
				continue
			
			var offset = Vector2(x, y)
			var chunk_pos = (center_chunk + offset) * float(chunk_size)
			
			# Draw each active A* chunk boundary
			var rect = Rect2(to_local(chunk_pos), Vector2(chunk_size, chunk_size))
			
			# Thick blue border for each valid navigation chunk
			draw_rect(rect, color, false, 8.0)
			
			# Cross to show center of chunk
			var center = rect.get_center()
			draw_line(center - Vector2(20, 0), center + Vector2(20, 0), color, 2.0)
			draw_line(center - Vector2(0, 20), center + Vector2(0, 20), color, 2.0)

func _initialize_components() -> void:
	# Create components in dependency order
	# 1. Building Manager (no component dependencies)
	building_manager = HubBuildingManager.new()
	add_child(building_manager)
	building_manager.setup(state, _item_db, slots)
	
	# 2. Economy Manager (needs building_manager)
	economy_manager = HubEconomyManager.new()
	add_child(economy_manager)
	economy_manager.setup(state, _item_db, _economy_config, building_manager)
	
	# 3. Trading System (needs economy_manager)
	trading_system = HubTradingSystem.new()
	add_child(trading_system)
	trading_system.setup(state, _item_db, economy_manager)
	
	# 4. Troop Production (needs economy_manager + building_manager)
	troop_production = HubTroopProduction.new()
	add_child(troop_production)
	troop_production.setup(state, economy_manager, building_manager)
	
	# 5. UI Controller (needs trading_system)
	ui_controller = HubUIController.new()
	add_child(ui_controller)
	ui_controller.setup(self, state, hub_menu_ui, market_ui, recruitment_ui, trading_system)

func _initialize_starter_inventory() -> void:
	# Starter inventory logic removed to restore natural economy.
	pass

func _connect_timekeeper() -> void:
	var tk: Node = get_node_or_null("/root/Timekeeper")
	if tk == null:
		push_error("Timekeeper autoload not found at /root/Timekeeper")
	elif not tk.is_connected("tick", Callable(self, "_on_timekeeper_tick")):
		tk.connect("tick", Callable(self, "_on_timekeeper_tick"))

func _connect_proximity_signals() -> void:
	if click_and_fade != null:
		if click_and_fade.has_signal("actor_entered"):
			click_and_fade.actor_entered.connect(_on_actor_entered)
		if click_and_fade.has_signal("actor_exited"):
			click_and_fade.actor_exited.connect(_on_actor_exited)

func _on_timekeeper_tick(dt: float) -> void:
	# Delegate to components
	economy_manager.process_tick(dt, state.governor_id)
	troop_production.process(dt)
	trading_system.process_tick(dt)

# -------------------------------------------------------------------
# Fleet Management API
# -------------------------------------------------------------------
func request_trade_run(caravan_type: CaravanType) -> void:
	var caravan: Caravan = null
	
	# Pass 1: Specialist Check (Perfect Match)
	for c in idle_fleet:
		if c.caravan_state.caravan_type == caravan_type:
			caravan = c
			break
			
	# Pass 2: Warm Body Check (Fallback)
	if caravan == null and not idle_fleet.is_empty():
		caravan = idle_fleet[0]
		# Do NOT change the type. A Food Merchant can try to run Luxury (and suck at it).
			
	if caravan != null:
		# Veteran Found
		idle_fleet.erase(caravan)
		caravan.visible = true
		caravan.start_mission(caravan_type)
		# print("Hub %s: Deployed veteran caravan %s for %s run" % [name, caravan.name, caravan_type.type_id])
	else:
		# No veteran, request new spawn
		caravan_spawn_requested.emit(self, caravan_type)

func register_caravan(c: Caravan) -> void:
	if not fleet.has(c):
		fleet.append(c)
		c.mission_complete.connect(_on_caravan_mission_complete)


func _on_caravan_mission_complete(c: Caravan) -> void:
	# Clock Out Logic
	if not idle_fleet.has(c):
		idle_fleet.append(c)
		# c.visible = false # DEBUG: Keep visible so we can see if they are just failing immediately
		# print("Hub %s: Caravan %s clocked out." % [name, c.name])

# -------------------------------------------------------------------
# Public API (delegates to components)
# -------------------------------------------------------------------
func get_item_price(item_id: StringName) -> float:
	return trading_system.get_item_price(item_id)

func set_export_cooldown(item_id: StringName, time: float) -> void:
	trading_system.set_export_cooldown(item_id, time)

func get_export_cooldown(item_id: StringName) -> float:
	return trading_system.get_export_cooldown(item_id)

func buy_from_hub(item_id: StringName, amount: int, caravan_state: CaravanState) -> bool:
	return trading_system.buy_from_hub(item_id, amount, caravan_state)

func sell_to_hub(item_id: StringName, amount: int, caravan_state: CaravanState) -> bool:
	return trading_system.sell_to_hub(item_id, amount, caravan_state)

func place_building(slot_id: int, ps: PackedScene, s: BuildSlotState) -> Node:
	return building_manager.place_building(slot_id, ps, s)

func clear_building(slot_id: int) -> void:
	building_manager.clear_building(slot_id)

# -------------------------------------------------------------------
# Area callbacks (delegate to UI controller)
# -------------------------------------------------------------------
func _on_actor_entered(actor: Node) -> void:
	# Show hub menu when Bus enters proximity area
	if _is_bus(actor):
		ui_controller.show_hub_menu()

func _on_actor_exited(_actor: Node) -> void:
	pass

func _is_bus(node: Node) -> bool:
	if node == null:
		return false
	return node.get_scene_file_path() == "res://Actors/Bus.tscn"

# -------------------------------------------------------------------
# Config management
# -------------------------------------------------------------------
func _ensure_unique_economy_config() -> void:
	if _economy_config == null:
		_economy_config = EconomyConfig.new()
		return
	# If referencing a .tres on disk, duplicate so this Hub owns a private copy.
	if _economy_config.resource_path != "":
		_economy_config = _economy_config.duplicate(true)
		_economy_config.resource_name = "%s_LocalEconomy" % name

func _on_item_db_changed() -> void:
	if economy_manager != null:
		economy_manager.refresh_item_db()

func _on_economy_config_changed() -> void:
	if economy_manager != null:
		economy_manager.refresh_config()

# -------------------------------------------------------------------
# Helper for initial troop spawning (temporary, until components created)
# -------------------------------------------------------------------
func _spawn_random_t1_pity(troop_db: TroopDatabase) -> void:
	var all_archetypes: Array[String] = troop_db.get_all_archetypes()
	
	# Reset pity if all 7 spawned
	if state.archetype_spawn_pity.size() >= 7:
		state.archetype_spawn_pity.clear()
	
	# Find archetypes not yet spawned
	var available: Array[String] = []
	for arch: String in all_archetypes:
		if not state.archetype_spawn_pity.has(arch):
			available.append(arch)
	
	# Pick random from available
	if available.size() > 0:
		var chosen: String = available[randi() % available.size()]
		var t1_id: StringName = troop_db.get_t1_troop_for_archetype(chosen)
		if t1_id != StringName():
			state.troop_stock[t1_id] = state.troop_stock.get(t1_id, 0) + 1
			state.archetype_spawn_pity.append(chosen)
