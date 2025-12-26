# Hub.gd — Godot 4.5 (Refactored with component architecture)
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

# UI references (assigned in editor)
@export var hub_menu_ui: HubMenuUI = null
@export var market_ui: MarketUI = null
@export var recruitment_ui: RecruitmentUI = null

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
	# Ensure hub state
	if state == null:
		state = HubStates.new()
	state.ensure_slots(9)
	
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
	
	# Realize placed buildings from state
	if slots != null:
		slots.realize_from_state(state)
		building_manager.inject_item_db()
	
	# Wire Timekeeper
	_connect_timekeeper()
	
	# Wire proximity signals
	_connect_proximity_signals()

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

# -------------------------------------------------------------------
# Public API (delegates to components)
# -------------------------------------------------------------------
func get_item_price(item_id: StringName) -> float:
	return trading_system.get_item_price(item_id)

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
