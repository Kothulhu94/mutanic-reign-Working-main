extends Resource
class_name CharacterSheet

## Universal character data container for player, NPCs, caravan leaders, and enemies.
## Stores dynamic progression data including attributes, skills, and character metadata.
## Uses CharacterAttributes for attribute management and SkillSpec instances for skill tracking.

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
## Dictionary of learned skills: { skill_id (StringName) -> SkillSpec instance }
var skills: Dictionary = {}

## Dictionary of domain states: { domain_id (StringName) -> DomainState instance }
var domain_states: Dictionary = {}

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

## Equips an item to a specific slot
## Returns the previously equipped item_id, or StringName() if empty
func equip_item(slot: EquipmentSlot, item_id: StringName) -> StringName:
	var previous: StringName = StringName()
	if equipment.has(slot):
		previous = equipment[slot]
	
	equipment[slot] = item_id
	return previous

## Unequips an item from a specific slot
## Returns the unequipped item_id, or StringName() if empty
func unequip_item(slot: EquipmentSlot) -> StringName:
	if not equipment.has(slot):
		return StringName()
		
	var item_id: StringName = equipment[slot]
	equipment.erase(slot)
	return item_id

## Get item in a specific slot
func get_equipped_item(slot: EquipmentSlot) -> StringName:
	return equipment.get(slot, StringName())


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
# Example for speed - Needs base speed source (like CaravanType or player base speed)
# func get_effective_speed(base_speed : float) -> float:
# 	var speed_mod = attributes.get_modifier("agility") # Example attribute
# 	return base_speed * (1.0 + speed_mod / 100.0) # Example modifier logic
# 	return base_speed # Placeholder if no logic yet

# --- Combat Modifiers ---

func get_melee_damage_modifier() -> float:
	var mod: float = 1.0
	var melee_state: DomainState = get_domain_state(&"Melee")
	if melee_state:
		mod += float(melee_state.current_level) * 0.01
	return mod

func get_ranged_damage_modifier() -> float:
	var mod: float = 1.0
	var ranged_state: DomainState = get_domain_state(&"Ranged")
	if ranged_state:
		mod += float(ranged_state.current_level) * 0.01
	return mod

func get_artifact_damage_modifier() -> float:
	var mod: float = 1.0
	var artifact_state: DomainState = get_domain_state(&"ArtifactWeapons")
	if artifact_state:
		mod += float(artifact_state.current_level) * 0.01
	return mod

# --- Troop Management Functions ---

## Calculates total bonuses from all recruited troops
## Loads troop definitions directly from resources to avoid autoload dependency
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
	var resource_path: String = "res://data/troops/%s.tres" % troop_id
	if ResourceLoader.exists(resource_path):
		return load(resource_path) as TroopType
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

## Adds a new skill to the character's skill list.
## Skills start at rank 1 with 0 XP (rank 0 would mean "not learned").
func add_skill(skill_id: StringName, skill_db: SkillDatabase) -> void:
	# Check if skill already exists
	if skills.has(skill_id):
		push_warning("CharacterSheet.add_skill: Skill '%s' already exists for character '%s'" % [skill_id, character_name])
		return

	# Validate skill database
	if not skill_db:
		push_error("CharacterSheet.add_skill: Invalid SkillDatabase provided")
		return

	# Verify skill exists in database
	var skill_definition: Skill = skill_db.get_skill_by_id(skill_id)
	if not skill_definition:
		push_error("CharacterSheet.add_skill: Skill '%s' not found in SkillDatabase" % skill_id)
		return

	# Create new skill instance
	var new_skill_spec: SkillSpec = SkillSpec.new()
	new_skill_spec.skill_id = skill_id
	new_skill_spec.current_rank = 1 # Skills start at rank 1 (learned)
	new_skill_spec.current_xp = 0.0

	# Store in skills dictionary
	skills[skill_id] = new_skill_spec


## Gets the current level of a specific attribute.
func get_attribute_level(attribute_id: StringName) -> int:
	if not attributes:
		push_warning("CharacterSheet.get_attribute_level: No attributes instance")
		return 0
	return attributes.get_attribute_level(attribute_id)


## Gets the current rank of a specific skill.
## Returns 0 if the skill is not learned.
func get_skill_rank(skill_id: StringName) -> int:
	if not skills.has(skill_id):
		return 0

	var skill_spec: SkillSpec = skills[skill_id]
	return skill_spec.current_rank


## Gets the SkillSpec instance for a specific skill.
## Returns null if the skill is not learned.
func get_skill_spec(skill_id: StringName) -> SkillSpec:
	if not skills.has(skill_id):
		return null
	return skills[skill_id]


## Gets the DomainState instance for a specific domain.
## Creates it if it doesn't exist.
func get_domain_state(domain_id: StringName) -> DomainState:
	if not domain_states.has(domain_id):
		# Try to find the domain resource to initialize it
		# This requires access to the SkillDatabase, which we don't have directly here
		# So we return null or create a blank one. 
		# Ideally, domains should be initialized via CharacterProgression.
		return null
	return domain_states[domain_id]

## Initialize a domain state from a resource
func initialize_domain(domain_res: SkillDomain) -> DomainState:
	if not domain_res:
		return null
		
	if domain_states.has(domain_res.domain_id):
		return domain_states[domain_res.domain_id]
		
	var state = DomainState.new()
	state.configure(domain_res)
	domain_states[domain_res.domain_id] = state
	return state


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

	# Store skills as array of dictionaries
	var skills_list: Array = []
	for skill_id in skills.keys():
		var skill_spec: SkillSpec = skills[skill_id]
		if skill_spec:
			skills_list.append(skill_spec.to_dict())
	save_data["skills"] = skills_list

	# Store domain states
	var domains_list: Array = []
	for domain_id in domain_states.keys():
		var state: DomainState = domain_states[domain_id]
		if state:
			domains_list.append(state.to_dict())
	save_data["domain_states"] = domains_list
	
	# Store equipment
	var equipment_data: Dictionary = {}
	for slot in equipment.keys():
		equipment_data[str(slot)] = equipment[slot]
	save_data["equipment"] = equipment_data


	return save_data


## Loads character sheet data from a Dictionary (for save games).
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

	# Clear existing skills
	skills.clear()

	# Load skills
	if data.has("skills") and data["skills"] is Array:
		var skills_list: Array = data["skills"]
		for skill_data in skills_list:
			if skill_data is Dictionary:
				var new_skill_spec: SkillSpec = SkillSpec.new()
				new_skill_spec.from_dict(skill_data)
				# Use the loaded skill_id as the key
				skills[new_skill_spec.skill_id] = new_skill_spec

	# Load domain states
	if data.has("domain_states") and data["domain_states"] is Array:
		var domains_list: Array = data["domain_states"]
		for domain_data in domains_list:
			if domain_data is Dictionary:
				var state = DomainState.new()
				state.from_dict(domain_data)
				domain_states[state.domain_id] = state

	# Load equipment
	if data.has("equipment") and data["equipment"] is Dictionary:
		var equipment_data: Dictionary = data["equipment"]
		for slot_str in equipment_data.keys():
			var slot: int = int(slot_str)
			var item_id: StringName = StringName(equipment_data[slot_str])
			equipment[slot] = item_id


## Initializes current health to maximum effective health
func initialize_health() -> void:
	current_health = get_effective_health()


## Applies damage to the character and emits health_changed signal
func apply_damage(damage: int) -> void:
	current_health -= damage
	current_health = maxi(current_health, 0)
	health_changed.emit(current_health, get_effective_health())
