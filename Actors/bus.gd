extends CharacterBody2D
class_name Bus

## Emitted when the bus collides with a chase target
signal encounter_initiated(attacker: Node2D, defender: Node2D)
## Emitted when chase starts
signal chase_started()

@export var move_speed := 200.0
var charactersheet: CharacterSheet
var _is_paused: bool = false
# inventory is now managed by charactersheet
var inventory: Dictionary:
	get:
		if charactersheet:
			return charactersheet.inventory
		return {}

var pacs: int = 1000
var _health_visual: Control
var _chase_target: Node2D = null
const ENCOUNTER_DISTANCE: float = 60.0
var _safe_velocity: Vector2 = Vector2.ZERO
var _repath_timer: float = 0.0
const REPATH_INTERVAL: float = 0.2

# Trading skill tracking
var _trade_session_value: float = 0.0 # Total PACs traded in current session
var _hubs_traded_at: Dictionary = {} # hub_name -> trade_count
var _last_wealth_check: int = 0 # For EconomicDominance tracking

## Checks if a specific amount of an item can be added without exceeding limits.
func can_add_item(item_id: StringName, amount: int) -> bool:
	if charactersheet:
		return charactersheet.can_add_item(item_id, amount)
	return false


## Adds a specified amount of an item to the inventory, respecting limits.
## Returns true if successful, false otherwise.
func add_item(item_id: StringName, amount: int) -> bool:
	if charactersheet:
		var result = charactersheet.add_item(item_id, amount)
		if result:
			print("Added %d %s. New total: %d" % [amount, item_id, charactersheet.inventory.get(item_id, 0)])
		return result
	return false


## Removes a specified amount of an item from the inventory.
## Returns true if successful, false otherwise (e.g., not enough items).
func remove_item(item_id: StringName, amount: int) -> bool:
	if charactersheet:
		var result = charactersheet.remove_item(item_id, amount)
		if result:
			print("Removed %d %s. Remaining: %d" % [amount, item_id, charactersheet.inventory.get(item_id, 0)])
		return result
	return false

###########################################################
# Pathfinding Migration
###########################################################
@export var map_manager: MapManager
var _current_path: PackedVector2Array = []
var _path_index: int = 0

func _ready() -> void:
	charactersheet = CharacterSheet.new()
	charactersheet.initialize_health()

	# Initialize Trading skills
	_initialize_trading_skills()

	# Create and add health visual
	var health_visual_scene: PackedScene = preload("res://UI/ActorHealthVisual.tscn")
	_health_visual = health_visual_scene.instantiate() as Control
	if _health_visual != null:
		add_child(_health_visual)
		_health_visual.position = Vector2(-18, -35)
		charactersheet.health_changed.connect(_on_health_changed)
		_on_health_changed(charactersheet.current_health, charactersheet.get_effective_health())

	# Connect to Timekeeper pause/resume signals
	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null:
		if timekeeper.has_signal("paused"):
			timekeeper.paused.connect(_on_timekeeper_paused)
		if timekeeper.has_signal("resumed"):
			timekeeper.resumed.connect(_on_timekeeper_resumed)
			
	if map_manager == null:
		push_warning("Bus: MapManager not assigned on startup. Waiting for injection...")

func move_to(target_pos: Vector2):
	if map_manager == null:
		push_warning("Bus: No MapManager assigned!")
		return
		
	# Ask the MapManager for a path
	var new_path = map_manager.get_path_world(global_position, target_pos)
	if new_path.is_empty():
		_current_path = []
		return

	_current_path = new_path
	_path_index = 0
	
	# Smooth repathing: Skip the first point if we are already ahead of it
	if _current_path.size() > 1:
		var p0 = _current_path[0]
		var p1 = _current_path[1]
		var vec_path = p1 - p0
		var vec_me = global_position - p0
		
		# If we are effectively "past" p0 in the direction of travel, skip it
		if vec_me.dot(vec_path) > 0:
			_path_index = 1

func _physics_process(_delta: float) -> void:
	# Don't move if paused
	if _is_paused:
		return

	# Check if we've reached the chase target
	if _chase_target != null:
		var distance_to_target: float = global_position.distance_to(_chase_target.global_position)
		if distance_to_target <= ENCOUNTER_DISTANCE:
			var target: Node2D = _chase_target
			_chase_target = null
			_current_path = [] # Stop moving
			print("[Bus] Encounter triggered! Distance: %.1f" % distance_to_target)
			encounter_initiated.emit(self, target)
			return

		# Update navigation target if chasing
		_repath_timer -= _delta
		if _repath_timer <= 0.0:
			_repath_timer = REPATH_INTERVAL
			move_to(_chase_target.global_position)

	# Movement Logic
	if _current_path.is_empty():
		return

	if _path_index >= _current_path.size():
		_current_path = [] # Path finished
		return

	var next_point = _current_path[_path_index]
	var distance = global_position.distance_to(next_point)

	# Check if we reached the point
	if distance < 5.0:
		_path_index += 1
		return

	# Move towards point
	velocity = global_position.direction_to(next_point) * move_speed
	move_and_slide()

func _on_timekeeper_paused() -> void:
	_is_paused = true

func _on_timekeeper_resumed() -> void:
	_is_paused = false

func _on_health_changed(new_health: int, max_health: int) -> void:
	if _health_visual != null:
		_health_visual.update_health(new_health, max_health)

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	_safe_velocity = safe_velocity

## Initiates chase of a target node
func chase_target(target: Node2D) -> void:
	_chase_target = target
	chase_started.emit()

## Returns the current chase target, or null if not chasing
func get_chase_target() -> Node2D:
	return _chase_target

## Award XP to a skill based on transaction value (1 XP per 100 PACs)
func award_skill_xp(skill_id: StringName, value: float) -> void:
	if charactersheet == null:
		return

	# Load the active skill from the sheet
	var skill: Skill = charactersheet.get_skill(skill_id)
	if skill == null:
		return

	# Calculate XP: 1 XP per 100 PACs
	var xp_amount: float = value / 100.0
	if xp_amount > 0.0:
		skill.add_xp(xp_amount)

## Track a trade transaction for session-based XP awards
func track_trade_transaction(hub_name: String, transaction_value: float) -> void:
	# Accumulate total trading volume for CaravanLogistics
	_trade_session_value += transaction_value

	# Track which hubs we've traded at for EstablishedRoutes
	_hubs_traded_at[hub_name] = _hubs_traded_at.get(hub_name, 0) + 1

## Finalize trading session and award session-based XP
func finalize_trade_session(hub_name: String) -> void:
	# Award CaravanLogistics XP based on total trading volume this session
	if _trade_session_value > 0.0:
		award_skill_xp(&"caravan_logistics", _trade_session_value)

	# Award EstablishedRoutes XP for trading at established hubs (2+ visits)
	var trade_count: int = _hubs_traded_at.get(hub_name, 0)
	if trade_count >= 2:
		# Bonus XP for repeat trading at same hub (building relationships)
		award_skill_xp(&"established_routes", _trade_session_value * 0.5)

	# Award EconomicDominance XP when wealth increases significantly
	var current_wealth: int = pacs
	if current_wealth > _last_wealth_check + 1000:
		var wealth_gain: float = float(current_wealth - _last_wealth_check)
		award_skill_xp(&"economic_dominance", wealth_gain)
		_last_wealth_check = current_wealth
	elif current_wealth > 1000 and _last_wealth_check == 0:
		# First time exceeding 1000 PACs
		award_skill_xp(&"economic_dominance", float(current_wealth))
		_last_wealth_check = current_wealth

	# Reset session tracking
	_trade_session_value = 0.0

## Initialize all Trading domain skills for this bus
func _initialize_trading_skills() -> void:
	if charactersheet == null:
		push_error("Bus._initialize_trading_skills: CharacterSheet is null")
		return

	# Add all 7 Trading skills at rank 1
	var trading_skills: Array[StringName] = [
		&"market_analysis",
		&"caravan_logistics",
		&"negotiation_tactics",
		&"market_monopoly",
		&"established_routes",
		&"master_merchant",
		&"economic_dominance"
	]

	for skill_id: StringName in trading_skills:
		var skill_res = Skills.get_skill(skill_id)
		if skill_res:
			charactersheet.add_skill(skill_res)
		else:
			push_warning("Bus: Could not find skill resource for '%s'" % skill_id)
