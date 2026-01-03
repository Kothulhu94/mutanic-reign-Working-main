# uid://kvutokt2hc02
extends Resource
class_name CharacterAttributes

## Manages the 4 core character attributes: Might, Guile, Intellect, Willpower
## Each attribute tracks level, current XP, and XP needed for next level
## Handles soft caps: 1-5 normal, 6-10 at 80%, 11+ at 30% with decay

signal attribute_leveled(attribute_name: StringName, new_level: int)

# Attribute data structure: {level, current_xp, xp_to_next}
var _attributes: Dictionary = {}

# Base XP requirements
const BASE_XP_TO_LEVEL: float = 1000.0
const XP_SCALING_PER_LEVEL: float = 2.25

# Soft cap modifiers
const SOFT_CAP_1: int = 5 # Levels 1-5: no penalty
const SOFT_CAP_2: int = 10 # Levels 6-10: 80% XP gain
const SOFT_CAP_2_RATE: float = 0.8
const SOFT_CAP_3_BASE_RATE: float = 0.3 # Levels 11+: 30% * decay
const SOFT_CAP_3_DECAY: float = 0.9

# Attribute names
const ATTRIBUTE_MIGHT: StringName = &"Might"
const ATTRIBUTE_GUILE: StringName = &"Guile"
const ATTRIBUTE_INTELLECT: StringName = &"Intellect"
const ATTRIBUTE_WILLPOWER: StringName = &"Willpower"

func _init() -> void:
	_initialize_attributes()

func _initialize_attributes() -> void:
	_attributes[ATTRIBUTE_MIGHT] = _create_attribute_data(1)
	_attributes[ATTRIBUTE_GUILE] = _create_attribute_data(1)
	_attributes[ATTRIBUTE_INTELLECT] = _create_attribute_data(1)
	_attributes[ATTRIBUTE_WILLPOWER] = _create_attribute_data(1)

func _create_attribute_data(level: int) -> Dictionary:
	return {
		"level": level,
		"current_xp": 0.0,
		"xp_to_next": _calculate_xp_to_next(level)
	}

## Calculate XP needed to reach the next level
func _calculate_xp_to_next(current_level: int) -> float:
	return BASE_XP_TO_LEVEL * pow(XP_SCALING_PER_LEVEL, float(current_level - 1))

## Add XP to an attribute, handling levelups and soft caps
func add_attribute_xp(attribute_name: StringName, xp: float) -> void:
	if not _attributes.has(attribute_name):
		push_error("CharacterAttributes: Unknown attribute '%s'" % attribute_name)
		return

	if xp <= 0.0:
		return

	var attr: Dictionary = _attributes[attribute_name]
	var current_level: int = int(attr["level"])

	# Apply soft cap penalty to incoming XP
	var modified_xp: float = _apply_soft_cap_penalty(xp, current_level)

	attr["current_xp"] = float(attr["current_xp"]) + modified_xp

	# Check for levelup(s)
	while attr["current_xp"] >= attr["xp_to_next"]:
		_levelup_attribute(attribute_name, attr)

## Apply soft cap penalty based on current level
func _apply_soft_cap_penalty(xp: float, level: int) -> float:
	if level <= SOFT_CAP_1:
		# Levels 1-5: no penalty
		return xp
	elif level <= SOFT_CAP_2:
		# Levels 6-10: 80% rate
		return xp * SOFT_CAP_2_RATE
	else:
		# Levels 11+: 30% * 0.9^(level-10)
		var levels_above_10: int = level - SOFT_CAP_2
		var decay: float = pow(SOFT_CAP_3_DECAY, float(levels_above_10))
		return xp * SOFT_CAP_3_BASE_RATE * decay

## Handle attribute levelup
func _levelup_attribute(attribute_name: StringName, attr: Dictionary) -> void:
	attr["current_xp"] = float(attr["current_xp"]) - float(attr["xp_to_next"])
	attr["level"] = int(attr["level"]) + 1
	attr["xp_to_next"] = _calculate_xp_to_next(int(attr["level"]))

	attribute_leveled.emit(attribute_name, int(attr["level"]))

## Get the current level of an attribute
func get_attribute_level(attribute_name: StringName) -> int:
	if not _attributes.has(attribute_name):
		push_error("CharacterAttributes: Unknown attribute '%s'" % attribute_name)
		return 0
	return int(_attributes[attribute_name]["level"])

## Get current XP in an attribute
func get_attribute_xp(attribute_name: StringName) -> float:
	if not _attributes.has(attribute_name):
		return 0.0
	return float(_attributes[attribute_name]["current_xp"])

## Get XP needed for next level
func get_xp_to_next(attribute_name: StringName) -> float:
	if not _attributes.has(attribute_name):
		return 0.0
	return float(_attributes[attribute_name]["xp_to_next"])

## Get progress percentage to next level (0.0 to 1.0)
func get_progress_percent(attribute_name: StringName) -> float:
	if not _attributes.has(attribute_name):
		return 0.0
	var attr: Dictionary = _attributes[attribute_name]
	var xp_to_next: float = float(attr["xp_to_next"])
	if xp_to_next <= 0.0:
		return 1.0
	return float(attr["current_xp"]) / xp_to_next

## Serialize to dictionary (for save game)
func to_dict() -> Dictionary:
	var result: Dictionary = {}
	for attr_name: StringName in _attributes.keys():
		var attr: Dictionary = _attributes[attr_name]
		result[attr_name] = {
			"level": int(attr["level"]),
			"current_xp": float(attr["current_xp"]),
			"xp_to_next": float(attr["xp_to_next"])
		}
	return result

## Load from dictionary (for load game)
func from_dict(data: Dictionary) -> void:
	if data.is_empty():
		return

	for attr_name: StringName in [ATTRIBUTE_MIGHT, ATTRIBUTE_GUILE, ATTRIBUTE_INTELLECT, ATTRIBUTE_WILLPOWER]:
		if data.has(attr_name):
			var saved: Dictionary = data[attr_name]
			_attributes[attr_name] = {
				"level": int(saved.get("level", 1)),
				"current_xp": float(saved.get("current_xp", 0.0)),
				"xp_to_next": float(saved.get("xp_to_next", BASE_XP_TO_LEVEL))
			}
		else:
			_attributes[attr_name] = _create_attribute_data(1)
