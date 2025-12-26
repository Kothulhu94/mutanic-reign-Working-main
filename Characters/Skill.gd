# uid://bcwtul4idcrmu
extends Resource
class_name Skill

## Complete skill definition with progression, effects, and XP tracking
## Extends the base SkillSpec with full mechanical properties for gameplay integration

signal skill_ranked_up(skill_id: StringName, new_rank: int)

# ============================================================
# CORE IDENTITY
# ============================================================
@export var skill_id: StringName = StringName()
@export var display_name: String = ""
@export var description: String = ""
@export var domain_id: StringName = StringName()

# ============================================================
# TIER & PROGRESSION
# ============================================================
@export_range(1, 3) var tier: int = 1
@export var max_rank: int = 10

# Runtime state (not exported, managed internally)
var current_rank: int = 0
var current_xp: float = 0.0

# ============================================================
# ATTRIBUTE SCALING
# ============================================================
@export var primary_attribute: StringName = StringName()
@export var secondary_attribute: StringName = StringName()
@export var primary_attr_scale: float = 0.75
@export var secondary_attr_scale: float = 0.25

# ============================================================
# EFFECT SYSTEM
# ============================================================
@export var effect_type: StringName = StringName()  # e.g., &"build_speed", &"worker_productivity"
@export var is_multiplicative: bool = true  # true for %, false for flat bonus
@export var is_passive: bool = true  # false for active abilities

# Per-rank effect values (10 elements for ranks 1-10)
@export var base_effect_per_rank: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
@export var effect_cap_per_rank: Array[float] = []  # Optional caps
@export var effect_multiplier_per_rank: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]

# ============================================================
# XP SYSTEM
# ============================================================
## XP required to reach each rank (10 elements: rank 0->1, 1->2, ..., 9->10)
## Standard progression: [0, 100, 100, 100, 500, 500, 500, 1000, 1000, 2000]
@export var xp_per_rank: Array[int] = [0, 100, 100, 100, 500, 500, 500, 1000, 1000, 2000]

@export var xp_trigger: StringName = StringName()  # e.g., &"melee_combat", &"building_construction"
@export var xp_trigger_description: String = ""
@export var uses_difficulty_multiplier: bool = true

# ============================================================
# ACTIVE SKILL RESOURCES
# ============================================================
## Cooldown in game cycles (empty for passive skills)
@export var cooldown_cycles_per_rank: Array[int] = []

## Resource cost per activation (empty for no cost)
@export var resource_cost_per_rank: Array[int] = []

# Runtime state for active skills
var current_cooldown: int = 0  # Cycles remaining

# ============================================================
# PREREQUISITES & UNLOCKS
# ============================================================
@export var prerequisite_skill_ids: Array[StringName] = []
@export var unlocks_system: String = ""  # e.g., "spy_networks", "fast_travel"

# ============================================================
# METHODS
# ============================================================

func _init() -> void:
	_validate_arrays()

## Validate that all arrays have correct length
func _validate_arrays() -> void:
	if base_effect_per_rank.size() != 10:
		push_warning("Skill '%s': base_effect_per_rank must have 10 elements" % skill_id)
	if effect_multiplier_per_rank.size() != 10:
		push_warning("Skill '%s': effect_multiplier_per_rank must have 10 elements" % skill_id)
	if xp_per_rank.size() != 10:
		push_warning("Skill '%s': xp_per_rank must have 10 elements" % skill_id)

## Get the effective bonus at a specific rank
func get_effect_at_rank(rank: int) -> float:
	if rank < 1 or rank > max_rank:
		return 0.0

	var idx: int = rank - 1  # Array is 0-indexed
	var base: float = base_effect_per_rank[idx] if idx < base_effect_per_rank.size() else 0.0
	var mult: float = effect_multiplier_per_rank[idx] if idx < effect_multiplier_per_rank.size() else 1.0
	var result: float = base * mult

	# Apply cap if defined
	if not effect_cap_per_rank.is_empty() and idx < effect_cap_per_rank.size():
		result = minf(result, effect_cap_per_rank[idx])

	return result

## Get the current effective bonus based on current_rank
func get_current_effect() -> float:
	return get_effect_at_rank(current_rank)

## Get XP required to reach a specific rank from the previous rank
func get_xp_for_rank(target_rank: int) -> int:
	if target_rank < 1 or target_rank > max_rank:
		return 0
	var idx: int = target_rank - 1
	return xp_per_rank[idx] if idx < xp_per_rank.size() else 0

## Get total XP required to reach a rank from rank 0
func get_total_xp_for_rank(target_rank: int) -> int:
	var total: int = 0
	for r in range(1, target_rank + 1):
		total += get_xp_for_rank(r)
	return total

## Get XP needed for next rank
func get_xp_to_next_rank() -> int:
	if current_rank >= max_rank:
		return 0
	return get_xp_for_rank(current_rank + 1)

## Add XP to this skill, handling rank-ups automatically
func add_xp(xp: float) -> void:
	if xp <= 0.0 or current_rank >= max_rank:
		return

	current_xp += xp

	# Check for rank-up(s)
	while current_rank < max_rank:
		var xp_needed: int = get_xp_to_next_rank()
		if xp_needed <= 0 or current_xp < float(xp_needed):
			break
		_rank_up()

## Internal rank-up handler
func _rank_up() -> void:
	var xp_needed: int = get_xp_to_next_rank()
	current_xp -= float(xp_needed)
	current_rank += 1

	skill_ranked_up.emit(skill_id, current_rank)

## Check if this skill is unlocked (prerequisites met)
func is_unlocked(character_skills: Dictionary) -> bool:
	if prerequisite_skill_ids.is_empty():
		return true

	for prereq_id: StringName in prerequisite_skill_ids:
		if not character_skills.has(prereq_id):
			return false
		var prereq_skill: Skill = character_skills[prereq_id]
		if prereq_skill == null or prereq_skill.current_rank < 1:
			return false

	return true

## Check if skill can be activated (for active skills)
func can_activate() -> bool:
	if is_passive:
		return false
	if current_rank < 1:
		return false
	if current_cooldown > 0:
		return false
	# TODO: Check resource costs when resource system is implemented
	return true

## Activate skill (for active skills)
func activate() -> bool:
	if not can_activate():
		return false

	# Set cooldown
	if not cooldown_cycles_per_rank.is_empty():
		var idx: int = current_rank - 1
		if idx < cooldown_cycles_per_rank.size():
			current_cooldown = cooldown_cycles_per_rank[idx]

	# TODO: Deduct resource costs when resource system is implemented

	return true

## Tick cooldown (call each game cycle)
func tick_cooldown() -> void:
	if current_cooldown > 0:
		current_cooldown -= 1

## Get progress percentage to next rank (0.0 to 1.0)
func get_progress_percent() -> float:
	if current_rank >= max_rank:
		return 1.0
	var xp_needed: int = get_xp_to_next_rank()
	if xp_needed <= 0:
		return 1.0
	return current_xp / float(xp_needed)

## Validate that the skill has all required fields
func is_valid() -> bool:
	return skill_id != StringName() and \
		   display_name != "" and \
		   domain_id != StringName() and \
		   effect_type != StringName() and \
		   primary_attribute != StringName() and \
		   secondary_attribute != StringName()

## Serialize to dictionary (for save game)
func to_dict() -> Dictionary:
	return {
		"skill_id": skill_id,
		"display_name": display_name,
		"domain_id": domain_id,
		"current_rank": current_rank,
		"current_xp": current_xp,
		"current_cooldown": current_cooldown
	}

## Load from dictionary (for load game)
func from_dict(data: Dictionary) -> void:
	if data.is_empty():
		return

	skill_id = data.get("skill_id", StringName())
	display_name = data.get("display_name", "")
	domain_id = data.get("domain_id", StringName())
	current_rank = int(data.get("current_rank", 0))
	current_xp = float(data.get("current_xp", 0.0))
	current_cooldown = int(data.get("current_cooldown", 0))
