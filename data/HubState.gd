extends Resource
class_name HubStates

@export var hub_id: StringName
@export var display_name: String = "Settlement"
@export var governor_id: StringName = StringName() # Character ID of assigned governor
@export var governor_sheet: CharacterSheet # The actual sheet for the governor (skills, stats)

@export var pacs: int = 0

# Inventory: item -> count (ints). You can swap to floats later if needed.
@export var inventory: Dictionary = {}

# Troop stock: troop_id -> available count for recruitment
# Troop stock: troop_id -> available count for recruitment
@export var troop_stock: Dictionary = {}

# Starvation Penalty (reduces population cap)
@export var starvation_cap_penalty: float = 0.0

# Population state
@export var base_population_cap: int = 100

@export var trade_prices: Dictionary = {} # item_id -> current_price

# Troop production settings
@export var troop_production_interval: float = 300.0 # 5 minutes default
@export var archetype_spawn_pity: Array[String] = [] # Pity system: tracks spawned archetypes

# Slot states (length 9 for a 3x3 grid; center is ignored by BuildSlots)
@export var slots: Array[BuildSlotState] = [] # Array[BuildSlotState]

func ensure_slots(lens: int = 9) -> void:
	while slots.size() < lens:
		slots.append(null)

# --- Serialization ---

func to_dict() -> Dictionary:
	var data: Dictionary = {}
	data["hub_id"] = str(hub_id)
	data["display_name"] = display_name
	data["governor_id"] = str(governor_id)
	data["pacs"] = pacs
	data["inventory"] = inventory.duplicate(true)
	data["troop_stock"] = troop_stock.duplicate(true)
	data["base_population_cap"] = base_population_cap
	data["starvation_cap_penalty"] = starvation_cap_penalty
	data["trade_prices"] = trade_prices.duplicate(true)
	data["troop_production_interval"] = troop_production_interval
	data["archetype_spawn_pity"] = archetype_spawn_pity.duplicate()

	if governor_sheet:
		data["governor_sheet"] = governor_sheet.to_dict()
		
	var slots_data: Array = []
	for slot in slots:
		if slot:
			slots_data.append(slot.to_dict())
		else:
			slots_data.append(null)
	data["slots"] = slots_data
	
	return data

func from_dict(data: Dictionary) -> void:
	hub_id = StringName(data.get("hub_id", ""))
	display_name = data.get("display_name", "Settlement")
	governor_id = StringName(data.get("governor_id", ""))
	pacs = data.get("pacs", 0)
	inventory = data.get("inventory", {}).duplicate(true)
	troop_stock = data.get("troop_stock", {}).duplicate(true)
	base_population_cap = data.get("base_population_cap", 100)
	starvation_cap_penalty = data.get("starvation_cap_penalty", 0.0)
	trade_prices = data.get("trade_prices", {}).duplicate(true)
	troop_production_interval = data.get("troop_production_interval", 300.0)
	# Cast to Array[String] manually loop if needed, but implicit cast might work or simple assign
	var pity_data = data.get("archetype_spawn_pity", [])
	archetype_spawn_pity.clear()
	for p in pity_data:
		archetype_spawn_pity.append(str(p))
	
	var gov_data = data.get("governor_sheet")
	if gov_data and gov_data is Dictionary:
		if not governor_sheet: governor_sheet = CharacterSheet.new()
		governor_sheet.from_dict(gov_data)
		
	var slots_data = data.get("slots", [])
	if slots_data is Array:
		slots.clear()
		for s_data in slots_data:
			if s_data is Dictionary:
				var s = BuildSlotState.new()
				s.from_dict(s_data)
				slots.append(s)
			else:
				slots.append(null)
		ensure_slots(9)
