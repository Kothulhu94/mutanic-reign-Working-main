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
