extends Resource
class_name Perk

## Represents a buyable bonus within a Skill Tree.
## Unlocked by spending Perk Points gained from leveling the parent Skill.

@export_group("Identity")
@export var id: StringName = StringName()
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Requirements")
## The tier of this perk (1, 2, or 3).
## Higher tiers require a certain number of perks to be unlocked in this skill tree.
@export var tier: int = 1
## The level of the parent Skill required to purchase this perk.
@export var required_skill_level: int = 0
## Cost in Perk Points (default 1).
@export var cost: int = 1
## List of Perk IDs that must be unlocked before this one can be purchased.
@export var prerequisite_perks: Array[StringName] = []

@export_group("Effects")
## Optional ID for valid logic hooks (e.g. "logistics_expert" checked in code).
@export var effect_id: StringName = StringName()
## Optional value for generic effects (e.g. 0.1 for 10% bonus).
@export var effect_value: float = 0.0
