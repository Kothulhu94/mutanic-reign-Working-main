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
	scale = Vector2(4, 4)
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
	# Ask the MapManager for a path
	_current_path = map_manager.get_path_world(global_position, target_pos)
	_path_index = 0

	# Smoothing: Fast-forward through path nodes we've already passed
	# This prevents "backing up" to the center of the current grid cell
	if _current_path.size() > 1:
		# Check first few segments (usually just 1-2 needed)
		for i in range(min(_current_path.size() - 1, 4)):
			var a = _current_path[i]
			var b = _current_path[i + 1]
			var v_seg = b - a
			var len2 = v_seg.length_squared()
			
			if len2 < 0.001:
				continue
				
			var t = (global_position - a).dot(v_seg) / len2
			
			# If t > 0, we have passed 'a' towards 'b'
			if t > 0.0:
				_path_index = i + 1
				# If t <= 1.0, we are strictly between a and b. Target b is correct. Stop.
				if t <= 1.0:
					break
				# If t > 1.0, we passed b as well, so continue loop to check b->c
			else:
				# We are "behind" 'a' (or perfectly at it), so we must go to 'a' first.
				break

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
	
	# Rotation Logic: Look ahead 150 pixels on the path for smooth turning
	var look_ahead_pos = _get_look_ahead_point(150.0)
	var target_angle = (look_ahead_pos - global_position).angle()
	# Lerp rotation for smoothness (adjust weight 5.0 * delta as needed)
	rotation = lerp_angle(rotation, target_angle, 5.0 * _delta)
	
	# Keep health visual upright and floating above
	if _health_visual != null:
		_health_visual.rotation = - rotation
		# Counter-rotate position so it stays "North" on screen
		# (0, -40) local * 4x parent scale = ~160px global offset
		_health_visual.position = Vector2(0, -40).rotated(-rotation)
	
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

## Returns the current movement path points
func get_current_path_points() -> PackedVector2Array:
	if _current_path.is_empty():
		return PackedVector2Array()
	
	# Only return points from current index onwards
	if _path_index >= _current_path.size():
		return PackedVector2Array()
		
	return _current_path.slice(_path_index)

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


## Initialize the central Trading skill
func _initialize_trading_skills() -> void:
	if charactersheet == null:
		push_error("Bus._initialize_trading_skills: CharacterSheet is null")
		return

	# Add the single Trading skill
	var skill_res = Skills.get_skill(&"trading")
	if skill_res:
		charactersheet.add_skill(skill_res)
	else:
		push_warning("Bus: Could not find skill resource for 'Trading'")

## Calculates a point a certain distance ahead along the path for smooth steering
func _get_look_ahead_point(distance: float) -> Vector2:
	if _current_path.is_empty() or _path_index >= _current_path.size():
		# If no path, just look ahead in current direction
		return global_position + Vector2.RIGHT.rotated(rotation) * distance

	var remaining_dist = distance
	var current_pos = global_position
	
	# 1. Check distance to the immediate next waypoint
	var next_path_pos = _current_path[_path_index]
	var dist_to_next = current_pos.distance_to(next_path_pos)
	
	if dist_to_next > remaining_dist:
		# Target is on the current segment
		return current_pos.move_toward(next_path_pos, remaining_dist)
	
	# 2. Advance past the immediate waypoint
	remaining_dist -= dist_to_next
	current_pos = next_path_pos
	
	# 3. Iterate through subsequent waypoints
	for i in range(_path_index + 1, _current_path.size()):
		var p = _current_path[i]
		var d = current_pos.distance_to(p)
		if d > remaining_dist:
			return current_pos.move_toward(p, remaining_dist)
		remaining_dist -= d
		current_pos = p
		
	# 4. If we run out of path, look at the final destination
	return current_pos
