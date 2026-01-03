# HubBuildingManager.gd
extends Node
class_name HubBuildingManager

## Manages building placement, removal, and queries for a Hub.
## Extracted from Hub.gd to reduce complexity.

var state: HubStates
var item_db: ItemDB
var slots: BuildSlots

func setup(s: HubStates, db: ItemDB, build_slots: BuildSlots) -> void:
	state = s
	item_db = db
	slots = build_slots

func place_building(slot_id: int, ps: PackedScene, slot_state: BuildSlotState) -> Node:
	if slots == null:
		return null
	var node: Node = slots.place_building(slot_id, ps, slot_state)
	if node != null:
		state.slots[slot_id] = slot_state
		# Inject DB for newly placed processors
		if item_db != null and (node.is_in_group("processor") or node.has_method("refine_tick")):
			node.set("item_db", item_db)
	return node

func clear_building(slot_id: int) -> void:
	if slots == null:
		return
	slots.clear_slot(slot_id)
	state.slots[slot_id] = null

func get_buildings() -> Array[Node]:
	if slots == null:
		return []
	return slots.iter_buildings()

func get_population_cap() -> int:
	var cap: int = state.base_population_cap
	if slots != null:
		for n: Node in slots.iter_buildings():
			if n.has_method("get_population_cap_bonus"):
				cap += int(n.call("get_population_cap_bonus"))
	
	# Apply Starvation Penalty
	# Reduce effective cap based on starvation
	var penalty: int = int(floor(state.starvation_cap_penalty))
	cap = max(0, cap - penalty)
				
	return cap

func inject_item_db() -> void:
	# Give processors access to the ItemDB for tag lookups.
	if slots == null or item_db == null:
		return
	for n: Node in slots.iter_buildings():
		if n == null:
			continue
		if n.is_in_group("processor") or n.has_method("refine_tick"):
			n.set("item_db", item_db)
