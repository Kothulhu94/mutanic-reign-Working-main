# uid://domain_state_new_uid
extends Resource
class_name DomainState

## Runtime state for a skill domain (XP, Level, Unlocked Perks)
## Managed by CharacterSheet/CharacterProgression

signal domain_leveled_up(domain_id: StringName, new_level: int)
signal perk_unlocked(domain_id: StringName, skill_id: StringName)

@export var domain_id: StringName = StringName()
@export var display_name: String = ""

# Runtime state
@export var current_level: int = 1
@export var current_xp: float = 0.0
@export var xp_to_next_level: float = 100.0
@export var unlocked_perks: Array[StringName] = []
@export var pending_perk_choices: int = 0

# Configuration (copied from SkillDomain or defaults)
var BASE_XP_TO_LEVEL: float = 100.0
var XP_MULTIPLIER: float = 2.0
var PERK_UNLOCK_LEVELS: Array[int] = [1, 3, 6, 10, 15, 21]

func _init() -> void:
	pass

## Configure from a SkillDomain resource
func configure(domain_res: SkillDomain) -> void:
	if not domain_res:
		return
	domain_id = domain_res.domain_id
	display_name = domain_res.display_name
	
	# Load progression settings if they exist on the resource
	# We use get() to safely access properties that might not exist yet on the base class
	# if we haven't updated SkillDomain.gd yet, or if it's dynamic.
	# But we will update SkillDomain.gd next.
	if "xp_curve_base" in domain_res:
		BASE_XP_TO_LEVEL = float(domain_res.xp_curve_base)
	if "xp_curve_multiplier" in domain_res:
		XP_MULTIPLIER = float(domain_res.xp_curve_multiplier)
	if "perk_unlock_levels" in domain_res:
		PERK_UNLOCK_LEVELS = domain_res.perk_unlock_levels.duplicate()
		
	_recalculate_xp_to_next()

## Add XP to this domain, handling level-ups automatically
func add_xp(xp: float) -> void:
	if xp <= 0.0:
		return

	current_xp += xp

	# Check for level-up(s)
	while current_xp >= xp_to_next_level:
		_level_up()

## Internal level-up handler
func _level_up() -> void:
	current_xp -= xp_to_next_level
	current_level += 1
	_recalculate_xp_to_next()
	
	# Check if we get a perk choice at this level
	if current_level in PERK_UNLOCK_LEVELS:
		pending_perk_choices += 1
	
	domain_leveled_up.emit(domain_id, current_level)

## Recalculate XP needed for next level based on current level
func _recalculate_xp_to_next() -> void:
	# Geometric progression: Base * (Multiplier ^ (Level - 1))
	xp_to_next_level = BASE_XP_TO_LEVEL * pow(XP_MULTIPLIER, float(current_level - 1))

## Get progress towards next level as percentage (0.0 to 1.0)
func get_progress_percent() -> float:
	if xp_to_next_level <= 0.0:
		return 1.0
	return current_xp / xp_to_next_level

## Unlock a perk (skill)
func unlock_perk(skill_id: StringName) -> bool:
	if skill_id in unlocked_perks:
		return false # Already unlocked
		
	if pending_perk_choices <= 0:
		return false # No choices available
		
	unlocked_perks.append(skill_id)
	pending_perk_choices -= 1
	perk_unlocked.emit(domain_id, skill_id)
	return true

## Check if a perk is unlocked
func has_perk(skill_id: StringName) -> bool:
	return skill_id in unlocked_perks

## Serialize to dictionary (for save game)
func to_dict() -> Dictionary:
	return {
		"domain_id": domain_id,
		"display_name": display_name,
		"current_level": current_level,
		"current_xp": current_xp,
		"xp_to_next_level": xp_to_next_level,
		"unlocked_perks": unlocked_perks,
		"pending_perk_choices": pending_perk_choices
	}

## Load from dictionary (for load game)
func from_dict(data: Dictionary) -> void:
	if data.is_empty():
		return

	domain_id = data.get("domain_id", StringName())
	display_name = data.get("display_name", "")
	current_level = int(data.get("current_level", 1))
	current_xp = float(data.get("current_xp", 0.0))
	xp_to_next_level = float(data.get("xp_to_next_level", BASE_XP_TO_LEVEL))
	
	var perks_data = data.get("unlocked_perks", [])
	unlocked_perks.clear()
	for p in perks_data:
		unlocked_perks.append(StringName(p))
		
	pending_perk_choices = int(data.get("pending_perk_choices", 0))
