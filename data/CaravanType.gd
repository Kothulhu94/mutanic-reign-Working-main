# uid://baj5eti6c1qc7
extends Resource
class_name CaravanType

@export var type_id: String = "general"
@export var display_name: String = "Caravan"
@export var sprite: Texture2D

# Movement & capacity
@export var speed_modifier: float = 1.0
@export var capacity_modifier: float = 1.0
@export var base_capacity: int = 1000

# Navigation (bitmask - can select multiple layers)
@export_flags("Layer 1:1", "Layer 2:2", "Layer 3:4", "Layer 4:8") var navigation_layers: int = 1

# Economy
@export var starting_money_multiplier: float = 1.0  # Multiplied by home hub pop cap

# Trading preferences
@export var preferred_tags: Array[StringName] = []  # Tags this trader prioritizes buying/selling

func get_starting_money(hub_pop_cap: int) -> int:
	return int(float(hub_pop_cap) * starting_money_multiplier)
