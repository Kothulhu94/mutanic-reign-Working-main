# uid://cg7v4inyg6hlh
extends Resource
class_name SkillDatabase

## Root container for all Skills (formerly Domains).
## Provides centralized access to the skill system.

# ============================================================
# SKILL REFERENCES
# ============================================================
## List of all major skills in the game (e.g. Melee, Trading)
@export var skills: Array[Skill] = []

# ============================================================
# CACHED DATA
# ============================================================
var _skills_by_id: Dictionary = {} # skill_id -> Skill
var _all_perks_cache: Dictionary = {} # perk_id -> Perk (Optional, for global lookup)
var _cache_built: bool = false

# ============================================================
# PUBLIC API
# ============================================================

## Get a specific skill by ID
func get_skill_by_id(skill_id: StringName) -> Skill:
	if not _cache_built:
		_build_cache()
	return _skills_by_id.get(skill_id, null)

## Get a specific perk by ID (Global lookup)
func get_perk_by_id(perk_id: StringName) -> Perk:
	if not _cache_built:
		_build_cache()
	return _all_perks_cache.get(perk_id, null)

# ============================================================
# INTERNAL METHODS
# ============================================================

func _build_cache() -> void:
	_skills_by_id.clear()
	_all_perks_cache.clear()

	for skill: Skill in skills:
		if skill == null:
			continue

		# Cache Skill
		if _skills_by_id.has(skill.id):
			push_error("SkillDatabase: Duplicate skill ID '%s'" % skill.id)
		else:
			_skills_by_id[skill.id] = skill
			
		# Cache Perks from this Skill
		skill.setup() # Ensure skill's internal map is built
		for perk in skill.available_perks:
			if perk:
				_all_perks_cache[perk.id] = perk

	_cache_built = true

## Validate data
func validate() -> bool:
	_build_cache()
	return true
