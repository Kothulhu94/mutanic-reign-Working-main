extends Resource
class_name Skill

## A major proficiency area (formerly "Domain") that levels up and grants Perk Points.
## Examples: Trading, Melee, Leadership.

signal leveled_up(new_level: int)
signal perk_point_gained(total_points: int)
signal perk_unlocked(perk_id: StringName)

# ============================================================
# CONFIGURATION
# ============================================================
@export_group("Identity")
@export var id: StringName = StringName()
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Progression")
@export var max_level: int = 100
## Base XP needed for level 1 -> 2
@export var xp_curve_base: int = 100
## Multiplier for XP requirements per level
@export var xp_curve_multiplier: float = 1.15

@export_group("Attributes")
## The primary attribute this skill contributes to (e.g. "Might", "Guile")
@export var primary_attribute: StringName = StringName()
## The secondary attribute this skill contributes to
@export var secondary_attribute: StringName = StringName()

@export_group("Perks")
## The skill tree available for this skill.
@export var available_perks: Array[Perk] = []

# ============================================================
# RUNTIME STATE
# ============================================================
# Notes: In a full architecture, this might be separated into a SkillState object.
# For simplicity and given the user's codebase pattern, we'll encapsulate state here 
# but expect it to be managed/serialized by the CharacterSheet using to_dict/from_dict.
var current_level: int = 1
var current_xp: float = 0.0
var perk_points: int = 0
var perk_ranks: Dictionary = {} # perk_id (StringName) -> rank (int)

# Cache for quick lookups
var _perk_map: Dictionary = {}

# ============================================================
# PUBLIC API
# ============================================================

func _init() -> void:
	pass

## Initialize helper maps. Call this after loading resources.
func setup() -> void:
	_perk_map.clear()
	for perk in available_perks:
		if perk:
			_perk_map[perk.id] = perk

## Adds XP to the skill. Handles leveling up and awarding Perk Points.
func add_xp(amount: float) -> void:
	if amount <= 0:
		return
		
	current_xp += amount
	
	var leveled: bool = false
	while true:
		var xp_needed = get_xp_for_next_level()
		if current_xp >= xp_needed and current_level < max_level:
			current_xp -= xp_needed
			_level_up()
			leveled = true
		else:
			break
			
	if leveled:
		leveled_up.emit(current_level)

## Returns true if the character has the specific perk unlocked (rank >= 1).
func has_perk(perk_id: StringName) -> bool:
	return perk_ranks.get(perk_id, 0) > 0

## Returns the current rank of a perk.
func get_perk_rank(perk_id: StringName) -> int:
	return perk_ranks.get(perk_id, 0)

## Attempts to purchase a perk. Returns true if successful.
func buy_perk(perk_id: StringName) -> bool:
	var current_rank: int = get_perk_rank(perk_id)
	
	var perk = _get_perk_resource(perk_id)
	if not perk:
		push_warning("Skill: Attempted to buy unknown perk '%s' in skill '%s'" % [perk_id, id])
		return false
		
	# Check if we are at max rank
	if current_rank >= perk.max_ranks:
		return false
		
	# Check costs
	if perk_points < perk.cost:
		return false
		
	# Check level requirements
	if current_level < perk.required_skill_level:
		return false
	
	# Tier Gating Logic (uses total unique perks owned)
	var owned_count = perk_ranks.size()
	if perk.tier == 2:
		if owned_count < 5:
			return false
	elif perk.tier == 3:
		if owned_count < 10:
			return false
		
	for req_id in perk.prerequisite_perks:
		if not has_perk(req_id):
			return false
			
	# Transaction
	perk_points -= perk.cost
	perk_ranks[perk_id] = current_rank + 1
	perk_unlocked.emit(perk_id)
	return true

## Returns the XP required to go from current_level to current_level + 1
func get_xp_for_next_level() -> float:
	if current_level >= max_level:
		return 999999.0
	
	# Custom Curve for Trading
	if id == &"trading":
		# Level 0 -> 1: 500 XP (Start)
		if current_level == 0:
			return 500.0
		# Level 1 -> 2 (Even target): 1000 XP
		# Level 2 -> 3 (Odd target): 500 XP
		# Pattern: Even Levels (0, 2, 4...) need 500 to reach Odd.
		# Odd Levels (1, 3, 5...) need 1000 to reach Even.
		if current_level % 2 == 0:
			return 500.0
		else:
			return 1000.0
			
	# Simple geometric curve: Base * (Mult ^ (Level-1))
	return float(xp_curve_base) * pow(xp_curve_multiplier, float(max(0, current_level - 1)))

## Returns percent progress to next level (0.0 to 1.0)
func get_progress_percent() -> float:
	if current_level >= max_level:
		return 1.0
	return current_xp / get_xp_for_next_level()

# ============================================================
# INTERNAL
# ============================================================

func _level_up() -> void:
	current_level += 1
	
	# Award 1 Perk Point every level
	perk_points += 1
	perk_point_gained.emit(perk_points)

func _get_perk_resource(perk_id: StringName) -> Perk:
	if _perk_map.is_empty() and not available_perks.is_empty():
		setup()
	return _perk_map.get(perk_id)

# ============================================================
# SERIALIZATION
# ============================================================

func to_dict() -> Dictionary:
	return {
		"id": id, # Sanity check in saves
		"current_level": current_level,
		"current_xp": current_xp,
		"perk_points": perk_points,
		"perk_ranks": perk_ranks
	}

func from_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	
	# We optionally check 'id' matches, but usually the parent container handles mapping
	current_level = int(data.get("current_level", 1))
	current_xp = float(data.get("current_xp", 0.0))
	perk_points = int(data.get("perk_points", 0))
	
	perk_ranks.clear()
	
	# Handle new format (dictionary)
	if data.has("perk_ranks"):
		var ranks = data["perk_ranks"]
		for p_id in ranks:
			perk_ranks[StringName(p_id)] = int(ranks[p_id])
	
	# Handle legacy format (array of IDs) - backward compatibility
	elif data.has("unlocked_perk_ids"):
		var unlocked = data["unlocked_perk_ids"]
		for p_id in unlocked:
			perk_ranks[StringName(p_id)] = 1
	
	setup() # Refresh map after load
