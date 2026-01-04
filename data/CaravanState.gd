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
# inventory is now managed by leader_sheet
var inventory: Dictionary:
	get:
		if leader_sheet:
			return leader_sheet.inventory
		return {}

var pacs: int = 0 # PACs available for purchasing
var profit_this_trip: int = 0 # Track earnings for this round trip

# Current journey
enum Leg {OUTBOUND, RETURN}
var current_leg: Leg = Leg.OUTBOUND

# Bonus multiplier set by CaravanSkillSystem
# Deprecated: Capacity is now handled by CharacterSheet slots/stacks
@export var bonus_capacity_multiplier: float = 1.0

func _init(home: StringName = StringName(), dest: StringName = StringName(), starting_money: int = 0, type: CaravanType = null, p_leader_sheet: CharacterSheet = null) -> void:
	home_hub_id = home
	destination_hub_id = dest
	pacs = starting_money
	caravan_type = type
	leader_sheet = p_leader_sheet
	
	# Ensure leader sheet exists (fallback)
	if leader_sheet == null:
		leader_sheet = CharacterSheet.new()

# Deprecated: Weight system replaced by Stack/Slot system in CharacterSheet
func get_total_cargo_weight() -> int:
	return 0

# Deprecated: Capacity handled by CharacterSheet
func get_max_capacity() -> int:
	if leader_sheet:
		return leader_sheet.get_max_slots() * leader_sheet.get_max_stack_size()
	return 100

func can_add_item(item_id: StringName, amount: int) -> bool:
	if leader_sheet:
		return leader_sheet.can_add_item(item_id, amount)
	return false

func add_item(item_id: StringName, amount: int) -> bool:
	if leader_sheet:
		var success: bool = leader_sheet.add_item(item_id, amount)
		if not success:
			print("CaravanState: FAILED to add %d %s to leader sheet! Slots: %d/%d. StackLimit: %d" % [amount, item_id, leader_sheet.inventory.size(), leader_sheet.get_max_slots(), leader_sheet.get_max_stack_size()])
		return success
	return false

func remove_item(item_id: StringName, amount: int) -> bool:
	if leader_sheet:
		return leader_sheet.remove_item(item_id, amount)
	return false

func clear_inventory() -> void:
	if leader_sheet:
		leader_sheet.inventory.clear()
		leader_sheet.inventory_changed.emit(StringName(), 0)

func flip_leg() -> void:
	current_leg = Leg.RETURN if current_leg == Leg.OUTBOUND else Leg.OUTBOUND

# --- Serialization ---

func to_dict() -> Dictionary:
	var data: Dictionary = {}
	data["home_hub_id"] = str(home_hub_id)
	data["destination_hub_id"] = str(destination_hub_id)
	# Inventory is stored in leader_sheet, so we don't need to duplicate it here
	# unless for legacy reasons, but cleaner to rely on leader_sheet.
	data["pacs"] = pacs
	data["profit_this_trip"] = profit_this_trip
	data["current_leg"] = current_leg
	
	if leader_sheet != null:
		data["leader_sheet"] = leader_sheet.to_dict()
	
	if caravan_type != null:
		data["caravan_type_path"] = caravan_type.resource_path
		
	return data

func from_dict(data: Dictionary) -> void:
	home_hub_id = StringName(data.get("home_hub_id", ""))
	destination_hub_id = StringName(data.get("destination_hub_id", ""))
	pacs = data.get("pacs", 0)
	profit_this_trip = data.get("profit_this_trip", 0)
	current_leg = data.get("current_leg", Leg.OUTBOUND)
	
	var leader_data: Variant = data.get("leader_sheet", null)
	if leader_data != null and leader_data is Dictionary:
		if leader_sheet == null:
			leader_sheet = CharacterSheet.new()
		leader_sheet.from_dict(leader_data)
		
	var caravan_type_path: String = data.get("caravan_type_path", "")
	if not caravan_type_path.is_empty():
		caravan_type = load(caravan_type_path)
