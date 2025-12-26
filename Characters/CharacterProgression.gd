# uid://0wf6j3u0re3i
extends RefCounted


## Main character progression orchestrator
## Owns attributes and skills, coordinates XP distribution
## Provides save/load functionality for persistence

# Core components
var _attributes: CharacterAttributes = CharacterAttributes.new()
var _skills: Dictionary = {} # skill_id: StringName -> Skill


## Initialize with empty attributes and skills
func _init() -> void:
	_attributes.attribute_leveled.connect(_on_attribute_leveled)

## Grant skill XP 
## event: "use", "success", "failure", "challenge"
## difficulty: 0.0 to 1.0
func grant_skill_xp(skill_id: StringName, event: String, difficulty: float, base_xp: int = 100) -> void:
	# Find the skill 
	var skill: Skill = _skills.get(skill_id)
	
	if not skill:
		return

	# Grant XP to the skill
	skill.add_xp(float(base_xp))

	# Distribute attribute XP (simplified for now)
	var calculated_xp: int = XPCalculator.calculate_skill_xp(base_xp, event, difficulty, 1)
	var split: Dictionary = XPCalculator.split_to_attributes(calculated_xp)
	var primary_xp: int = int(split["primary"])
	var secondary_xp: int = int(split["secondary"])

	primary_xp = XPCalculator.apply_difficulty_modifier(primary_xp, difficulty)
	secondary_xp = XPCalculator.apply_difficulty_modifier(secondary_xp, difficulty)

	_distribute_attribute_xp(primary_xp, secondary_xp)


## Distribute attribute XP (placeholder - will use domain lookup in phase 2)
func _distribute_attribute_xp(primary_xp: int, secondary_xp: int) -> void:
	# Placeholder: distribute to Might and Guile
	# Phase 2: lookup skill's domain, use primary/secondary attributes
	_attributes.add_attribute_xp(&"Might", float(primary_xp))
	_attributes.add_attribute_xp(&"Guile", float(secondary_xp))

## Add a skill to this character
func add_skill(skill: Skill) -> void:
	if skill == null:
		push_error("CharacterProgression: Cannot add invalid skill")
		return

	if not _skills.has(skill.id):
		var unique_skill = skill.duplicate()
		unique_skill.setup()
		_skills[skill.id] = unique_skill
		unique_skill.leveled_up.connect(func(lvl): _on_skill_ranked_up(skill.id, lvl))
		unique_skill.perk_unlocked.connect(func(p_id): _on_perk_unlocked(skill.id, p_id))


## Get attribute level
func get_attribute(name: StringName) -> int:
	return _attributes.get_attribute_level(name)

## Get skill by ID
func get_skill(skill_id: StringName) -> Skill:
	return _skills.get(skill_id, null)

## Get all skills
func get_all_skills() -> Array[Skill]:
	var result: Array[Skill] = []
	for skill: Skill in _skills.values():
		result.append(skill)
	return result

## Get attribute progress percentage
func get_attribute_progress(name: StringName) -> float:
	return _attributes.get_progress_percent(name)

## Serialize to dictionary (for save game)
func to_dict() -> Dictionary:
	var skills_data: Dictionary = {}
	for skill_id: StringName in _skills.keys():
		var skill: Skill = _skills[skill_id]
		skills_data[skill_id] = skill.to_dict()

	return {
		"attributes": _attributes.to_dict(),
		"skills": skills_data
	}

## Load from dictionary (for load game)
func from_dict(data: Dictionary) -> void:
	if data.is_empty():
		return

	# Load attributes
	if data.has("attributes"):
		_attributes.from_dict(data["attributes"])

	# Load skills
	if data.has("skills"):
		var skills_data: Dictionary = data["skills"]
		for skill_id: StringName in skills_data.keys():
			var skill_data: Dictionary = skills_data[skill_id]

			# Create or update existing skill
			if _skills.has(skill_id):
				_skills[skill_id].from_dict(skill_data)
			else:
				# Cannot reconstruct full Skill resource from dict alone easily
				# Need valid base resource first. 
				# For now, assume we can fetch base from DB if ID is known
				if Skills.database:
					var base = Skills.get_skill(skill_id)
					if base:
						add_skill(base)
						_skills[skill_id].from_dict(skill_data)


## Signal handlers
func _on_attribute_leveled(_attribute_name: StringName, _new_level: int) -> void:
	pass # Can be used for notifications later

func _on_skill_ranked_up(_skill_id: StringName, _new_rank: int) -> void:
	pass # Can be used for notifications later

func _on_perk_unlocked(skill_id: StringName, perk_id: StringName) -> void:
	print("Perk %s unlocked in skill %s!" % [perk_id, skill_id])


## Test method removed as it relied on obsolete SkillSpec class
# func _test_progression() -> void:
# 	pass
