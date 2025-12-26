# uid://crqrvswudtp31
extends Node

## Global singleton for managing all character progression instances
## Maps character IDs to their CharacterSheet resources
## Provides centralized access for hubs, caravans, and other systems

# Dictionary mapping character_id (StringName) -> CharacterSheet
var character_sheets: Dictionary = {}

## Load or register a character's sheet
func register_character(character_id: StringName, sheet: CharacterSheet) -> void:
	if character_id == StringName():
		push_error("ProgressionManager: Cannot register character with empty ID")
		return

	if sheet == null:
		push_error("ProgressionManager: Cannot register null CharacterSheet")
		return

	character_sheets[character_id] = sheet


## Get a character's progression sheet by ID
func get_character_sheet(character_id: StringName) -> CharacterSheet:
	return character_sheets.get(character_id, null)

## Check if a character is registered
func has_character(character_id: StringName) -> bool:
	return character_sheets.has(character_id)

## Remove a character (e.g., on death)
func unregister_character(character_id: StringName) -> void:
	if character_sheets.has(character_id):
		character_sheets.erase(character_id)


## Get all registered character IDs
func get_all_character_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id in character_sheets.keys():
		result.append(id)
	return result

## Save all characters to dictionary (for save game)
func save_all_to_dict() -> Dictionary:
	var save_data: Dictionary = {}
	for character_id: StringName in character_sheets.keys():
		var sheet: CharacterSheet = character_sheets[character_id]
		if sheet != null:
			save_data[character_id] = sheet.to_dict()
	return save_data

## Load all characters from dictionary (for load game)
func load_all_from_dict(data: Dictionary) -> void:
	character_sheets.clear()
	for character_id: String in data.keys():
		var sheet_data: Dictionary = data[character_id]
		var sheet: CharacterSheet = CharacterSheet.new()
		sheet.from_dict(sheet_data)
		character_sheets[StringName(character_id)] = sheet
