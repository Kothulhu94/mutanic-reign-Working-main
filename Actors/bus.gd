extends CharacterBody2D
class_name Bus

## Emitted when the bus collides with a chase target
signal encounter_initiated(attacker: Node2D, defender: Node2D)
## Emitted when chase starts
signal chase_started()

@export var move_speed := 200.0
var charactersheet: CharacterSheet
var _is_paused: bool = false
var inventory: Dictionary = {}
var money: int = 1000
@export var max_unique_stacks: int = 16
@export var max_stack_size: int = 100
var _health_visual: Control
var _chase_target: Node2D = null
const ENCOUNTER_DISTANCE: float = 60.0
var _safe_velocity: Vector2 = Vector2.ZERO

# Trading skill tracking
var _trade_session_value: float = 0.0 # Total PACs traded in current session
var _hubs_traded_at: Dictionary = {} # hub_name -> trade_count
var _last_wealth_check: int = 0 # For EconomicDominance tracking

## Checks if a specific amount of an item can be added without exceeding limits.
func can_add_item(item_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return true # Adding zero or negative is always "possible" logically

	var current_amount: int = inventory.get(item_id, 0)
	var is_new_stack: bool = not inventory.has(item_id) or current_amount == 0

	# Check 1: Max stack size for this specific item
	if current_amount + amount > max_stack_size:
		print("Cannot add %d %s: Exceeds max stack size (%d)." % [amount, item_id, max_stack_size])
		return false

	# Check 2: Max unique stacks if this is a new item type
	if is_new_stack and inventory.size() >= max_unique_stacks:
		print("Cannot add %s: Exceeds max unique stacks (%d)." % [item_id, max_unique_stacks])
		return false

	# If checks pass, it's possible to add
	return true


## Adds a specified amount of an item to the inventory, respecting limits.
## Returns true if successful, false otherwise.
func add_item(item_id: StringName, amount: int) -> bool:
	if amount <= 0:
		push_warning("add_item: Cannot add zero or negative amount.")
		return false # Or true? Depends on desired behavior for zero/negative.

	if can_add_item(item_id, amount):
		inventory[item_id] = inventory.get(item_id, 0) + amount
		print("Added %d %s. New total: %d" % [amount, item_id, inventory[item_id]])
		# TODO: Emit a signal if UI needs to update inventory display
		# inventory_changed.emit()
		return true
	else:
		# can_add_item already printed the reason
		return false


## Removes a specified amount of an item from the inventory.
## Returns true if successful, false otherwise (e.g., not enough items).
func remove_item(item_id: StringName, amount: int) -> bool:
	if amount <= 0:
		push_warning("remove_item: Cannot remove zero or negative amount.")
		return false

	var current_amount: int = inventory.get(item_id, 0)

	if current_amount < amount:
		print("Cannot remove %d %s: Only have %d." % [amount, item_id, current_amount])
		return false
	else:
		inventory[item_id] = current_amount - amount
		print("Removed %d %s. Remaining: %d" % [amount, item_id, inventory[item_id]])
		# Remove the key if the amount becomes zero (optional, keeps inventory clean)
		if inventory[item_id] == 0:
			inventory.erase(item_id)
		# TODO: Emit a signal if UI needs to update inventory display
		# inventory_changed.emit()
		return true

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
			
	# Attempt to find MapManager if not assigned
	if map_manager == null:
		map_manager = get_node_or_null("/root/Overworld/MapManager")
		if map_manager == null:
			# Try to find it in the parent (Overworld)
			var p = get_parent()
			if p and p.has_node("MapManager"):
				map_manager = p.get_node("MapManager")

func move_to(target_pos: Vector2):
	if map_manager == null:
		push_warning("Bus: No MapManager assigned!")
		return
		
	# Ask the MapManager for a path
	_current_path = map_manager.get_path_world(global_position, target_pos)
	_path_index = 0

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
		# For grid movement, we might want to repath occasionally, but for now let's just 
		# periodically call move_to(_chase_target.global_position) or similar logic if needed.
		pass

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

	var skill_spec: SkillSpec = charactersheet.get_skill_spec(skill_id)
	if skill_spec == null:
		return

	# Load the skill definition
	var skill_def: Skill = Skills.get_skill(skill_id)
	if skill_def == null:
		return

	# Calculate XP: 1 XP per 100 PACs
	var xp_amount: float = value / 100.0
	if xp_amount > 0.0:
		# Update the SkillSpec's runtime values
		skill_spec.current_xp += xp_amount

		# Check for rank-up
		while skill_spec.current_rank < skill_def.max_rank:
			var xp_needed: int = skill_def.get_xp_for_rank(skill_spec.current_rank + 1)
			if xp_needed <= 0 or skill_spec.current_xp < float(xp_needed):
				break
			# Rank up
			skill_spec.current_xp -= float(xp_needed)
			skill_spec.current_rank += 1

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
	var current_wealth: int = money
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
		charactersheet.add_skill(skill_id, Skills.database)
