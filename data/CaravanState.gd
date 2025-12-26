# uid://chnq3gchtj8gn
extends RefCounted
class_name CaravanState

# Type definition (shared template)
var caravan_type: CaravanType = null

# Leader character sheet (for skill bonuses)
@export var leader_sheet: CharacterSheet = null

# Route definition
var home_hub_id: StringName = StringName()
var destination_hub_id: StringName = StringName()

# Trade state
var inventory: Dictionary = {} # item_id (StringName) -> count (int)
var money: int = 0 # PACs available for purchasing
var profit_this_trip: int = 0 # Track earnings for this round trip

# Current journey
enum Leg {OUTBOUND, RETURN}
var current_leg: Leg = Leg.OUTBOUND

# Bonus multiplier set by CaravanSkillSystem
@export var bonus_capacity_multiplier: float = 1.0

func _init(home: StringName = StringName(), dest: StringName = StringName(), starting_money: int = 0, type: CaravanType = null, p_leader_sheet: CharacterSheet = null) -> void:
	home_hub_id = home
	destination_hub_id = dest
	money = starting_money
	caravan_type = type
	leader_sheet = p_leader_sheet

func get_total_cargo_weight() -> int:
	var total: int = 0
	for count in inventory.values():
		total += int(count)
	return total

func get_max_capacity() -> int:
	if caravan_type == null:
		return 1000
	var base: int = caravan_type.base_capacity

	# Apply capacity bonus multiplier (calculated by CaravanSkillSystem)
	return int(float(base) * bonus_capacity_multiplier)

func can_carry_more() -> bool:
	return get_total_cargo_weight() < get_max_capacity()

func add_item(item_id: StringName, amount: int) -> void:
	inventory[item_id] = inventory.get(item_id, 0) + amount

func remove_item(item_id: StringName, amount: int) -> bool:
	var current: int = inventory.get(item_id, 0)
	if current < amount:
		return false
	inventory[item_id] = current - amount
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	return true

func clear_inventory() -> void:
	inventory.clear()

func flip_leg() -> void:
	current_leg = Leg.RETURN if current_leg == Leg.OUTBOUND else Leg.OUTBOUND
