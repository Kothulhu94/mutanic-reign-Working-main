# uid://b7ilx6vi5am45
extends Resource
class_name SkillSpec

## Defines a skill with XP tracking and rank progression
## Skills belong to a domain and can be leveled up through use
## Emits signals when ranking up

signal skill_ranked_up(skill_id: StringName, new_rank: int)

@export var skill_id: StringName = StringName()
@export var display_name: String = ""
@export var domain_id: StringName = StringName()

# Runtime state (not exported, managed internally)
var current_rank: int = 0
var current_xp: float = 0.0
var xp_to_next_rank: float = 100.0

# XP scaling constants
const BASE_XP_TO_RANK: float = 100.0
const XP_SCALING_PER_RANK: float = 1.2

func _init() -> void:
	_recalculate_xp_to_next()

## Add XP to this skill, handling rank-ups automatically
func add_xp(xp: float) -> void:
	if xp <= 0.0:
		return

	current_xp += xp

	# Check for rank-up(s)
	while current_xp >= xp_to_next_rank:
		_rank_up()

## Internal rank-up handler
func _rank_up() -> void:
	current_xp -= xp_to_next_rank
	current_rank += 1
	_recalculate_xp_to_next()

	skill_ranked_up.emit(skill_id, current_rank)

## Recalculate XP needed for next rank based on current rank
func _recalculate_xp_to_next() -> void:
	xp_to_next_rank = BASE_XP_TO_RANK * pow(XP_SCALING_PER_RANK, float(current_rank))

## Get progress towards next rank as percentage (0.0 to 1.0)
func get_progress_percent() -> float:
	if xp_to_next_rank <= 0.0:
		return 1.0
	return current_xp / xp_to_next_rank

## Validate that the skill has all required fields
func is_valid() -> bool:
	return skill_id != StringName() and \
		   display_name != "" and \
		   domain_id != StringName()

## Serialize to dictionary (for save game)
func to_dict() -> Dictionary:
	return {
		"skill_id": skill_id,
		"display_name": display_name,
		"domain_id": domain_id,
		"current_rank": current_rank,
		"current_xp": current_xp,
		"xp_to_next_rank": xp_to_next_rank
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
	xp_to_next_rank = float(data.get("xp_to_next_rank", BASE_XP_TO_RANK))
