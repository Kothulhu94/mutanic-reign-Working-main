# uid://cg7v4inyg6hlh
extends Resource
class_name SkillDatabase

## Root container for all skill domains and skills
## Provides centralized access to the complete skill system
## Load this resource once and query all skills/domains through it

# ============================================================
# DOMAIN REFERENCES (12 total)
# ============================================================
@export var melee_domain: SkillDomain
@export var ranged_domain: SkillDomain
@export var artifact_domain: SkillDomain
@export var exploration_domain: SkillDomain
@export var craftsmanship_domain: SkillDomain
@export var trading_domain: SkillDomain
@export var governance_domain: SkillDomain
@export var leadership_domain: SkillDomain
@export var diplomacy_domain: SkillDomain
@export var criminality_domain: SkillDomain
@export var espionage_domain: SkillDomain
@export var religion_domain: SkillDomain

# ============================================================
# CACHED DATA (populated on first access)
# ============================================================
var _all_skills_cache: Dictionary = {}  # skill_id -> Skill
var _domains_by_id_cache: Dictionary = {}  # domain_id -> SkillDomain
var _cache_built: bool = false

# ============================================================
# PUBLIC API
# ============================================================

## Get all skills from all domains as a dictionary (skill_id -> Skill)
func get_all_skills() -> Dictionary:
	if not _cache_built:
		_build_cache()
	return _all_skills_cache

## Get a specific skill by ID
func get_skill_by_id(skill_id: StringName) -> Skill:
	if not _cache_built:
		_build_cache()
	return _all_skills_cache.get(skill_id, null)

## Get a specific domain by ID
func get_domain_by_id(domain_id: StringName) -> SkillDomain:
	if not _cache_built:
		_build_cache()
	return _domains_by_id_cache.get(domain_id, null)

## Get all skills with a specific effect type across all domains
func get_skills_by_effect_type(effect_type: StringName) -> Array[Skill]:
	if not _cache_built:
		_build_cache()

	var result: Array[Skill] = []
	for skill: Skill in _all_skills_cache.values():
		if skill.effect_type == effect_type:
			result.append(skill)
	return result

## Get all domains as an array
func get_all_domains() -> Array[SkillDomain]:
	return [
		melee_domain,
		ranged_domain,
		artifact_domain,
		exploration_domain,
		craftsmanship_domain,
		trading_domain,
		governance_domain,
		leadership_domain,
		diplomacy_domain,
		criminality_domain,
		espionage_domain,
		religion_domain
	]

## Get total skill count across all domains
func get_total_skill_count() -> int:
	if not _cache_built:
		_build_cache()
	return _all_skills_cache.size()

## Get skill count per domain
func get_skill_counts_by_domain() -> Dictionary:
	var counts: Dictionary = {}
	for domain: SkillDomain in get_all_domains():
		if domain != null:
			counts[domain.domain_id] = domain.skills.size()
	return counts

## Clear cache (call if domains/skills are modified at runtime)
func invalidate_cache() -> void:
	_cache_built = false
	_all_skills_cache.clear()
	_domains_by_id_cache.clear()

# ============================================================
# INTERNAL METHODS
# ============================================================

## Build internal cache of all skills and domains
func _build_cache() -> void:
	_all_skills_cache.clear()
	_domains_by_id_cache.clear()

	var domains: Array[SkillDomain] = get_all_domains()

	for domain: SkillDomain in domains:
		if domain == null:
			continue

		# Cache domain by ID
		_domains_by_id_cache[domain.domain_id] = domain

		# Cache all skills in this domain
		for skill: Skill in domain.skills:
			if skill == null:
				continue

			if _all_skills_cache.has(skill.skill_id):
				push_error("SkillDatabase: Duplicate skill_id '%s' found!" % skill.skill_id)
			else:
				_all_skills_cache[skill.skill_id] = skill

	_cache_built = true

## Validate database integrity
func validate() -> bool:
	var is_valid: bool = true

	# Check all domains are assigned
	var domain_names: Array[String] = [
		"melee_domain", "ranged_domain", "artifact_domain", "exploration_domain",
		"craftsmanship_domain", "trading_domain", "governance_domain", "leadership_domain",
		"diplomacy_domain", "criminality_domain", "espionage_domain", "religion_domain"
	]

	for domain_name: String in domain_names:
		var domain: SkillDomain = get(domain_name)
		if domain == null:
			push_error("SkillDatabase: Missing domain '%s'" % domain_name)
			is_valid = false
		elif not domain.is_valid():
			push_error("SkillDatabase: Invalid domain '%s'" % domain_name)
			is_valid = false

	# Check for duplicate skill IDs
	_build_cache()
	var expected_count: int = 0
	for domain: SkillDomain in get_all_domains():
		if domain != null:
			expected_count += domain.skills.size()

	if _all_skills_cache.size() != expected_count:
		push_error("SkillDatabase: Duplicate skill IDs detected! Expected %d, got %d" % [expected_count, _all_skills_cache.size()])
		is_valid = false

	return is_valid
