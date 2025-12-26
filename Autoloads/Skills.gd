# uid://bq5yu7o2fefpv
extends Node

## Global singleton for accessing the SkillDatabase
## Provides centralized access to all skills and domains across the game

const database: SkillDatabase = preload("res://data/SkillDatabase.tres")

func _ready() -> void:
	if database == null:
		push_error("Skills: Failed to load SkillDatabase.tres")
	else:
		var is_valid: bool = database.validate()
		if not is_valid:
			push_error("Skills: SkillDatabase validation failed")

## Get a skill by ID from any domain
func get_skill(skill_id: StringName) -> Skill:
	return database.get_skill_by_id(skill_id)

## Get all skills with a specific effect type
func get_skills_by_effect(effect_type: StringName) -> Array[Skill]:
	return database.get_skills_by_effect_type(effect_type)

## Get a domain by ID
func get_domain(domain_id: StringName) -> SkillDomain:
	return database.get_domain_by_id(domain_id)
