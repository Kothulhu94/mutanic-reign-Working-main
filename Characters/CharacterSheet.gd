extends Resource
class_name CharacterSheet

## Universal character data container for player, NPCs, caravan leaders, and enemies.
## Stores dynamic progression data including attributes, skills, and character metadata.
## Uses CharacterAttributes for attribute management and unique Skill instances for progression.

## Character metadata
@export var character_name: String = "Nameless"
@export var character_description: String = ""
@export var level: int = 1
@export_group("Base Combat Stats")
@export var base_health: int = 100
@export var base_damage: int = 10
@export var base_defense: int = 5
@export var attribute_health_multiplier: int = 5
@export var attribute_damage_multiplier: int = 5
@export var attribute_defense_multiplier: int = 5

## Core progression components
@export var attributes: CharacterAttributes

## Dictionary of learned skills: { skill_id (StringName) -> Skill instance }
## IMPORTANT: Skill resources here must be unique instances (created via duplicate()).
var skills: Dictionary = {}

## Troop inventory system
## Dictionary of recruited troops: { troop_id (StringName) -> count (int) }
var troop_inventory: Dictionary = {}
## Maximum number of troops that can be recruited
@export var max_troop_capacity: int = 10

## Equipment System
enum EquipmentSlot {
	HEAD,
	BODY,
	LEGS,
	FEET,
	WEAPON_1,
	WEAPON_2,
	WEAPON_3,
	WEAPON_4
}

## Dictionary mapping EquipmentSlot (int) -> item_id (StringName)
## Stores currently equipped items
var equipment: Dictionary = {}

## Current health tracking for combat
var current_health: int = 0

## Emitted when health changes during combat
signal health_changed(new_health: int, max_health: int)

func _init() -> void:
	attributes = CharacterAttributes.new()

# --- Stat Calculation Functions ---

func get_effective_health() -> int:
	var might_level: int = attributes.get_attribute_level(&"Might")
	var willpower_level: int = attributes.get_attribute_level(&"Willpower")
	var base: int = base_health + (might_level * attribute_health_multiplier) + (willpower_level * attribute_health_multiplier)
	var troop_bonuses: Dictionary = get_total_troop_bonuses()
	return base + int(troop_bonuses.get("health", 0))

func get_effective_damage() -> int:
	var might_level: int = attributes.get_attribute_level(&"Might")
	var guile_level: int = attributes.get_attribute_level(&"Guile")
	var base: int = base_damage + (might_level * attribute_damage_multiplier) + (guile_level * attribute_damage_multiplier)
	var troop_bonuses: Dictionary = get_total_troop_bonuses()
	return base + int(troop_bonuses.get("damage", 0))

func get_effective_defense() -> int:
	var guile_level: int = attributes.get_attribute_level(&"Guile")
	var intellect_level: int = attributes.get_attribute_level(&"Intellect")
	var base: int = base_defense + (guile_level * attribute_defense_multiplier) + (intellect_level * attribute_defense_multiplier)
	var troop_bonuses: Dictionary = get_total_troop_bonuses()
	return base + int(troop_bonuses.get("defense", 0))

# --- Combat Modifiers (Example using Skills) ---

func get_skill_modifier(skill_id: StringName, factor: float = 0.01) -> float:
	var mod: float = 1.0
	if skills.has(skill_id):
		var skill = skills[skill_id]
		# +1% per level
		mod += float(skill.current_level) * factor
	return mod

func get_melee_damage_modifier() -> float:
	return get_skill_modifier(&"Melee", 0.01)

func get_ranged_damage_modifier() -> float:
	return get_skill_modifier(&"Ranged", 0.01)

# --- Troop Management Functions ---

## Calculates total bonuses from all recruited troops
func get_total_troop_bonuses() -> Dictionary:
	var total_health: int = 0
	var total_damage: int = 0
	var total_defense: int = 0

	for troop_id: StringName in troop_inventory.keys():
		var count: int = troop_inventory.get(troop_id, 0)
		if count <= 0:
			continue

		var troop_type: TroopType = _load_troop_type(troop_id)
		if troop_type != null:
			total_health += troop_type.health_bonus * count
			total_damage += troop_type.damage_bonus * count
			total_defense += troop_type.defense_bonus * count

	return {
		"health": total_health,
		"damage": total_damage,
		"defense": total_defense
	}

## Loads a troop type resource by ID
func _load_troop_type(troop_id: StringName) -> TroopType:
	var res_path: String = "res://data/troops/%s.tres" % troop_id
	if ResourceLoader.exists(res_path):
		return load(res_path) as TroopType
	return null

## Gets the total number of troops recruited
func get_total_troop_count() -> int:
	var total: int = 0
	for count: int in troop_inventory.values():
		total += count
	return total

## Gets the count of a specific troop type
func get_troop_count(troop_id: StringName) -> int:
	return troop_inventory.get(troop_id, 0)

## Adds troops to the inventory if capacity allows
func add_troop(troop_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return false

	var current_total: int = get_total_troop_count()
	if current_total + amount > max_troop_capacity:
		return false

	troop_inventory[troop_id] = troop_inventory.get(troop_id, 0) + amount
	return true

## Removes troops from the inventory
func remove_troop(troop_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return false

	var current: int = troop_inventory.get(troop_id, 0)
	if current < amount:
		return false

	troop_inventory[troop_id] = current - amount
	if troop_inventory[troop_id] <= 0:
		troop_inventory.erase(troop_id)

	return true

# --- Equipment Functions ---

func equip_item(slot: EquipmentSlot, item_id: StringName) -> StringName:
	var previous: StringName = StringName()
	if equipment.has(slot):
		previous = equipment[slot]
	
	equipment[slot] = item_id
	return previous

func unequip_item(slot: EquipmentSlot) -> StringName:
	if not equipment.has(slot):
		return StringName()
		
	var item_id: StringName = equipment[slot]
	equipment.erase(slot)
	return item_id

func get_equipped_item(slot: EquipmentSlot) -> StringName:
	return equipment.get(slot, StringName())

# --- Skill Management ---

## Adds a new skill to the character.
## IMPORTANT: This creates a UNIQUE INSTANCE of the skill resource for this character.
func add_skill(skill_res: Skill) -> void:
	if not skill_res:
		push_error("CharacterSheet: Attempted to add null skill.")
		return
		
	if skills.has(skill_res.id):
		# Already exists, do nothing (or maybe log warning)
		return
		
	# Create a unique instance for this character so we track own Level/XP
	var unique_skill = skill_res.duplicate()
	unique_skill.setup() # Initialize internal maps
	skills[skill_res.id] = unique_skill

## Gets a specific Skill instance.
func get_skill(skill_id: StringName) -> Skill:
	return skills.get(skill_id, null)

## Helper to check if a perk is unlocked in a specific skill
func has_perk(skill_id: StringName, perk_id: StringName) -> bool:
	var s = get_skill(skill_id)
	if s:
		return s.has_perk(perk_id)
	return false

# --- Attribute Management ---

func get_attribute_level(attribute_id: StringName) -> int:
	if not attributes:
		return 0
	return attributes.get_attribute_level(attribute_id)

# --- Serialization ---

## Serializes character sheet data to a Dictionary for save games.
func to_dict() -> Dictionary:
	var save_data: Dictionary = {}

	# Store basic character data
	save_data["character_name"] = character_name
	save_data["character_description"] = character_description
	save_data["level"] = level

	# Store attributes
	if attributes:
		save_data["attributes"] = attributes.to_dict()
	else:
		save_data["attributes"] = {}

	# Store skills
	var skills_data: Dictionary = {}
	for skill_id in skills.keys():
		var skill_obj: Skill = skills[skill_id]
		skills_data[skill_id] = skill_obj.to_dict()
	save_data["skills"] = skills_data

	# Store equipment
	var equipment_data: Dictionary = {}
	for slot in equipment.keys():
		equipment_data[str(slot)] = equipment[slot]
	save_data["equipment"] = equipment_data

	return save_data


## Loads character sheet data from a Dictionary (for save games).
## Note: This assumes Skills are already KNOWN (i.e. from a database)
## but since we don't have the database passed in here easily, this usually
## requires a hydration step or we just assume we load state into existing instances.
## For now, we will perform a basic load. Ideally, the game loader refills the 
## 'skills' dictionary with fresh resources from DB, and THEN calls this to load state.
func from_dict(data: Dictionary) -> void:
	# Load basic character data
	character_name = data.get("character_name", "Nameless")
	character_description = data.get("character_description", "")
	level = data.get("level", 1)

	# Load attributes
	if data.has("attributes"):
		if not attributes:
			attributes = CharacterAttributes.new()
		attributes.from_dict(data["attributes"])

	# Load skills
	# Warning: If skills dictionary is empty (new session), we can't load partial state
	# without the original resource definition.
	# The SkillDatabase should typically be used to re-instantiate skills.
	# For this implementation, we assume the 'skills' dictionary is populated 
	# OR we might miss data if not initialized. 
	# A robust system would inject the SkillDatabase. 
	if data.has("skills") and data["skills"] is Dictionary:
		var saved_skills = data["skills"]
		for skill_id in saved_skills.keys():
			# If we have the skill instance already (initialized by game logic), update it
			if skills.has(skill_id):
				skills[skill_id].from_dict(saved_skills[skill_id])
			else:
				# If we don't have it, we can't easily recreate the full Perk Tree structure
				# without the Resource. This is a common pattern issue.
				# We will skip for now, assuming initialization happens elsewhere.
				pass

	# Load equipment
	if data.has("equipment") and data["equipment"] is Dictionary:
		var equipment_data: Dictionary = data["equipment"]
		for slot_str in equipment_data.keys():
			var slot: int = int(slot_str)
			var item_id: StringName = StringName(equipment_data[slot_str])
			equipment[slot] = item_id

# --- Health ---

func initialize_health() -> void:
	current_health = get_effective_health()

func apply_damage(damage: int) -> void:
	current_health -= damage
	current_health = maxi(current_health, 0)
	health_changed.emit(current_health, get_effective_health())
