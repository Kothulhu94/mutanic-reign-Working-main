# uid://bq5yu7o2fefpv
extends Node

## Global singleton for accessing the SkillDatabase
## Provides centralized access to all skills across the game

var database: SkillDatabase

func _ready() -> void:
	if ResourceLoader.exists("res://data/SkillDatabase.tres"):
		database = load("res://data/SkillDatabase.tres")
	
	if database == null:
		push_warning("Skills: Failed to load SkillDatabase.tres (Migration required)")
	else:
		var is_valid: bool = database.validate()
		if not is_valid:
			push_error("Skills: SkillDatabase validation failed")

## Get a skill by ID
func get_skill(skill_id: StringName) -> Skill:
	if not database: return null
	return database.get_skill_by_id(skill_id)

## Legacy alias: Domains are now Skills
func get_domain(domain_id: StringName) -> Skill:
	return get_skill(domain_id)

## Get a perk by ID (if needed globally)
func get_perk(perk_id: StringName) -> Perk:
	if not database: return null
	return database.get_perk_by_id(perk_id)
