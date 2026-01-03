# uid://b2iyabtka0f3x
# Godot 4.5 — Caravan Trading AI (Refactored)
# Spawns when home hub has surplus (200+ items over need)
# Buys preferred items at home, travels to other hubs to sell for profit
# Returns home to pay 10% tax and restock if surplus exists
extends Area2D
class_name Caravan

## Emitted when player clicks on this caravan to initiate chase
signal player_initiated_chase(caravan_actor: Caravan)

# Core state
var caravan_state: CaravanState = null
var home_hub: Hub = null
var current_target_hub: Hub = null
var _is_paused: bool = false

# Components
var navigator: CaravanNavigator
var skill_system: CaravanSkillSystem
var trading_system: CaravanTradingSystem

# Health visual
var _health_visual: Control

# AI State machine
enum State {
	IDLE, # Waiting at home hub
	BUYING_AT_HOME, # Purchasing goods from home hub
	TRAVELING, # Moving to destination
	EVALUATING_TRADE, # At destination, checking prices
	SELLING, # Selling goods at destination
	WAITING_TO_SELL, # Waiting at hub before selling at loss
	SEEKING_NEXT_HUB, # Looking for another profitable hub
	RETURNING_HOME # Going back to home hub
}
var current_state: State = State.IDLE
var _wait_timer: float = 0.0
const WAIT_TIMEOUT: float = 60.0

# Configuration (set from EconomyConfig)
@export var surplus_threshold: float = 200.0 # Items over need to trigger spawn
@export var home_tax_rate: float = 0.1 # 10% of carried money goes to hub

# Navigation
@export var movement_speed: float = 100.0

# References
var item_db: ItemDB = null
var all_hubs: Array[Hub] = []

## Computed property for combat system compatibility
var charactersheet: CharacterSheet:
	get:
		if caravan_state != null:
			return caravan_state.leader_sheet
		return null

func _ready() -> void:
	add_to_group("caravans")

	# Initialize components
	navigator = CaravanNavigator.new()
	add_child(navigator)
	
	skill_system = CaravanSkillSystem.new()
	add_child(skill_system)
	
	trading_system = CaravanTradingSystem.new()
	add_child(trading_system)

	# Connect input event signal for clicking
	input_event.connect(_on_input_event)

	# Connect to Timekeeper pause/resume signals
	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null:
		if timekeeper.has_signal("paused"):
			timekeeper.paused.connect(_on_timekeeper_paused)
		if timekeeper.has_signal("resumed"):
			timekeeper.resumed.connect(_on_timekeeper_resumed)

func setup(home: Hub, state: CaravanState, db: ItemDB, hubs: Array[Hub], map_mgr: MapManager) -> void:
	home_hub = home
	caravan_state = state
	item_db = db
	all_hubs = hubs
	
	if map_mgr == null:
		push_error("Caravan: MapManager passed to setup() is null!")

	# Initialize health for combat
	if caravan_state != null and caravan_state.leader_sheet != null:
		caravan_state.leader_sheet.initialize_health()

		# Set up health visual
		var health_visual_scene: PackedScene = preload("res://UI/ActorHealthVisual.tscn")
		_health_visual = health_visual_scene.instantiate() as Control
		if _health_visual != null:
			add_child(_health_visual)
			_health_visual.position = Vector2(-18, -35)
			caravan_state.leader_sheet.health_changed.connect(_on_health_changed)
			_on_health_changed(caravan_state.leader_sheet.current_health, caravan_state.leader_sheet.get_effective_health())

	# Setup components
	skill_system.setup(caravan_state)
	trading_system.setup(caravan_state, item_db, skill_system, all_hubs, surplus_threshold)
	
	# Apply speed bonuses
	var final_speed: float = movement_speed
	if caravan_state.caravan_type != null:
		final_speed *= caravan_state.caravan_type.speed_modifier
	if skill_system:
		final_speed *= (1.0 + skill_system.speed_bonus)
	
	# Inject MapManager
	navigator.setup(self, map_mgr, final_speed)
	
	if caravan_state.caravan_type != null:
		navigator.set_navigation_layers(caravan_state.caravan_type.navigation_layers)

	# Position at home hub
	global_position = home.global_position

	# Start the AI
	_transition_to(State.BUYING_AT_HOME)

func _process(delta: float) -> void:
	# Don't process AI if paused
	if _is_paused:
		return

	match current_state:
		State.IDLE:
			_state_idle()
		State.BUYING_AT_HOME:
			_state_buying_at_home()
		State.TRAVELING:
			_state_traveling(delta)
		State.EVALUATING_TRADE:
			_state_evaluating_trade()
		State.SELLING:
			_state_selling()
		State.WAITING_TO_SELL:
			_state_waiting_to_sell(delta)
		State.SEEKING_NEXT_HUB:
			_state_seeking_next_hub()
		State.RETURNING_HOME:
			_state_returning_home(delta)

# ============================================================
# State Machine
# ============================================================
func _transition_to(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.TRAVELING:
			if current_target_hub:
				navigator.set_target_position(current_target_hub.global_position)
		State.RETURNING_HOME:
			if home_hub:
				navigator.set_target_position(home_hub.global_position)

func _state_idle() -> void:
	if trading_system.home_has_available_preferred_items(home_hub):
		_transition_to(State.BUYING_AT_HOME)

func _state_buying_at_home() -> void:
	var _bought: int = trading_system.buy_items_at_home(home_hub)
	
	if caravan_state.inventory.size() > 0:
		current_target_hub = trading_system.find_next_destination(home_hub)
		if current_target_hub != null:
			_transition_to(State.TRAVELING)
		else:
			_transition_to(State.IDLE)
	else:
		_transition_to(State.IDLE)

func _state_traveling(delta: float) -> void:
	if navigator.is_navigation_finished():
		if current_target_hub != null:
			_transition_to(State.EVALUATING_TRADE)
		return
		
	navigator.update_movement(delta)

func _state_evaluating_trade() -> void:
	var profitable: bool = trading_system.evaluate_trade_at_hub(current_target_hub)
	
	if profitable:
		_transition_to(State.SELLING)
	else:
		_wait_timer = 0.0
		_transition_to(State.WAITING_TO_SELL)

func _state_selling() -> void:
	trading_system.sell_items_at_hub(current_target_hub, false)
	_transition_to(State.RETURNING_HOME)

func _state_waiting_to_sell(delta: float) -> void:
	_wait_timer += delta
	if _wait_timer >= WAIT_TIMEOUT:
		trading_system.sell_items_at_hub(current_target_hub, true) # Force sell
		_transition_to(State.RETURNING_HOME)

func _state_seeking_next_hub() -> void:
	# This state seems redundant if we always return home after selling (as per original logic line 291)
	# But original code had logic for it.
	# Original logic: check if visited all hubs. If so, return home. Else find next.
	var visited_count: int = trading_system.get_visited_count_excluding(home_hub)
	var total_hubs: int = trading_system.get_total_hubs_excluding(home_hub)
	
	if visited_count >= total_hubs:
		_transition_to(State.RETURNING_HOME)
		return
		
	current_target_hub = trading_system.find_next_destination(home_hub)
	if current_target_hub != null:
		_transition_to(State.TRAVELING)
	else:
		_transition_to(State.RETURNING_HOME)

func _state_returning_home(delta: float) -> void:
	if navigator.is_navigation_finished():
		_arrive_at_home()
		return
		
	navigator.update_movement(delta)

func _arrive_at_home() -> void:
	# Awards and tax
	var trip_profit: int = caravan_state.profit_this_trip
	var route_value: float = float(caravan_state.pacs + trip_profit)
	
	skill_system.award_xp(&"established_routes", route_value)
	skill_system.award_xp(&"caravan_logistics", route_value)
	
	if trip_profit > 1000:
		skill_system.award_xp(&"economic_dominance", float(trip_profit))
		
	if caravan_state.pacs > 0:
		var tax: int = int(ceil(float(caravan_state.pacs) * home_tax_rate))
		caravan_state.pacs -= tax
		home_hub.state.pacs += tax
		
	trading_system.reset_trip()
	_transition_to(State.IDLE)

# ============================================================
# Public API
# ============================================================
func get_state_name() -> String:
	match current_state:
		State.IDLE: return "Idle"
		State.BUYING_AT_HOME: return "Buying"
		State.TRAVELING: return "Traveling"
		State.EVALUATING_TRADE: return "Evaluating"
		State.SELLING: return "Selling"
		State.WAITING_TO_SELL: return "Waiting"
		State.SEEKING_NEXT_HUB: return "Seeking"
		State.RETURNING_HOME: return "Returning"
	return "Unknown"

func get_item_price(item_id: StringName) -> float:
	if item_db == null:
		return 1.0
	# Use standard item DB price
	if item_db.has_method("price_of"):
		return item_db.price_of(item_id)
	return 1.0

# ============================================================
# Input & Health Handlers
# ============================================================
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			player_initiated_chase.emit(self)
			get_viewport().set_input_as_handled()

func _on_health_changed(new_health: int, max_health: int) -> void:
	if _health_visual != null:
		_health_visual.update_health(new_health, max_health)

func _on_timekeeper_paused() -> void:
	_is_paused = true
	navigator.stop()

func _on_timekeeper_resumed() -> void:
	_is_paused = false
	# Restart navigation if we were moving
	if current_state == State.TRAVELING or current_state == State.RETURNING_HOME:
		_transition_to(current_state)
