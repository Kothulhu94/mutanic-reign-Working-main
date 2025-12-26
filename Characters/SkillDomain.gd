# uid://kj506ua3it00
extends Resource
class_name SkillDomain

## Skill domain grouping with attribute mapping and domain-wide bonuses
## Contains all skills belonging to a specific domain (e.g., Melee, Craftsmanship)
## Provides domain-level progression bonuses at milestone ranks

# ============================================================
# CORE IDENTITY
# ============================================================
@export var domain_id: StringName = StringName()
@export var display_name: String = ""
@export var description: String = ""

# ============================================================
# ATTRIBUTE MAPPING
# ============================================================
@export var primary_attribute: StringName = StringName()
@export var secondary_attribute: StringName = StringName()

# ============================================================
# SKILLS
# ============================================================
@export var skills: Array[Skill] = []

# ============================================================
# DOMAIN BONUSES
# ============================================================
## Bonus description granted when total domain ranks reach 5
@export var bonus_at_rank_5: String = ""

## Bonus description granted when total domain ranks reach 10
@export var bonus_at_rank_10: String = ""

# ============================================================
# PROGRESSION CONFIGURATION (New System)
# ============================================================
@export var xp_curve_base: int = 100
@export var xp_curve_multiplier: float = 2.0
@export var perk_unlock_levels: Array[int] = [1, 3, 6, 10, 15, 21]
@export var passive_bonus_description: String = ""


# ============================================================
# METHODS
# ============================================================

## Get total ranks across all skills in this domain
func get_total_domain_ranks() -> int:
	var total: int = 0
	for skill: Skill in skills:
		if skill != null:
			total += skill.current_rank
	return total

## Get domain bonus multiplier based on total ranks
## Returns bonus multiplier (e.g., 1.1 for 10% bonus)
func get_domain_bonus_multiplier() -> float:
	var total_ranks: int = get_total_domain_ranks()

	if total_ranks >= 10:
		return 1.20 # 20% bonus at rank 10+
	elif total_ranks >= 5:
		return 1.10 # 10% bonus at rank 5-9
	else:
		return 1.0 # No bonus below rank 5

## Check if domain bonus at rank 5 is active
func has_bonus_rank_5() -> bool:
	return get_total_domain_ranks() >= 5

## Check if domain bonus at rank 10 is active
func has_bonus_rank_10() -> bool:
	return get_total_domain_ranks() >= 10

## Get all skills of a specific tier
func get_skills_by_tier(tier: int) -> Array[Skill]:
	var result: Array[Skill] = []
	for skill: Skill in skills:
		if skill != null and skill.tier == tier:
			result.append(skill)
	return result

## Get skill by ID within this domain
func get_skill_by_id(skill_id: StringName) -> Skill:
	for skill: Skill in skills:
		if skill != null and skill.skill_id == skill_id:
			return skill
	return null

## Get all skills with a specific effect type
func get_skills_by_effect_type(effect_type: StringName) -> Array[Skill]:
	var result: Array[Skill] = []
	for skill: Skill in skills:
		if skill != null and skill.effect_type == effect_type:
			result.append(skill)
	return result

## Calculate total effect bonus from all skills with matching effect_type
## Returns the sum of all active skill effects of that type
func get_total_effect_bonus(effect_type: StringName) -> float:
	var total: float = 0.0
	for skill: Skill in skills:
		if skill != null and skill.effect_type == effect_type and skill.current_rank > 0:
			total += skill.get_current_effect()
	return total

## Validate that the domain has all required fields
func is_valid() -> bool:
	return domain_id != StringName() and \
		   display_name != "" and \
		   primary_attribute != StringName() and \
		   secondary_attribute != StringName()

## Get count of skills by tier
func get_tier_counts() -> Dictionary:
	var counts: Dictionary = {1: 0, 2: 0, 3: 0}
	for skill: Skill in skills:
		if skill != null:
			counts[skill.tier] = int(counts.get(skill.tier, 0)) + 1
	return counts
