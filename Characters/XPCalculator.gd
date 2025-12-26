# uid://uvxisf70jx0o
extends Node
class_name XPCalculator

## Pure math utility for XP calculations
## All functions are static and do not reference game state
## Handles skill XP calculation, attribute splitting, difficulty modifiers, and soft caps

# Event multipliers
const EVENT_USE: float = 0.25
const EVENT_SUCCESS: float = 0.75
const EVENT_FAILURE: float = 0.5
const EVENT_CHALLENGE: float = 1.2

# Attribute split (50/50 for now, will be domain-aware in phase 2)
const PRIMARY_ATTRIBUTE_SPLIT: float = 0.5
const SECONDARY_ATTRIBUTE_SPLIT: float = 0.5

# Difficulty scaling
const MIN_DIFFICULTY: float = 0.0
const MAX_DIFFICULTY: float = 1.0

# Challenge modifier parameters
const CHALLENGE_SWEET_SPOT: float = 0.8  # Task difficulty / attribute level sweet spot
const CHALLENGE_BONUS_MAX: float = 1.5   # Max bonus for challenging tasks
const CHALLENGE_PENALTY_MAX: float = 0.5 # Min penalty for trivial tasks

## Calculate skill XP based on event type, difficulty, and current skill rank
## event: "use", "success", "failure", "challenge"
## difficulty: 0.0 to 1.0 (task difficulty)
## skill_rank: Current rank of the skill
## Returns: Skill XP amount
static func calculate_skill_xp(base_xp: int, event: String, difficulty: float, skill_rank: int) -> int:
	var multiplier: float = _get_event_multiplier(event)
	var difficulty_clamped: float = clampf(difficulty, MIN_DIFFICULTY, MAX_DIFFICULTY)

	# Base calculation: base_xp * event_multiplier * difficulty
	var skill_xp: float = float(base_xp) * multiplier * (1.0 + difficulty_clamped)

	# Optional: Scale down XP as skill rank increases (diminishing returns)
	# For now, keeping it simple - can add later if needed

	return int(round(skill_xp))

## Get event multiplier based on event type
static func _get_event_multiplier(event: String) -> float:
	match event:
		"use":
			return EVENT_USE
		"success":
			return EVENT_SUCCESS
		"failure":
			return EVENT_FAILURE
		"challenge":
			return EVENT_CHALLENGE
		_:
			push_warning("XPCalculator: Unknown event type '%s', defaulting to 'use'" % event)
			return EVENT_USE

## Split skill XP to attributes (50/50 for now)
## Returns: {"primary": X, "secondary": Y}
## Note: In phase 2, this will use domain primary/secondary attributes
static func split_to_attributes(skill_xp: int) -> Dictionary:
	var primary_xp: int = int(round(float(skill_xp) * PRIMARY_ATTRIBUTE_SPLIT))
	var secondary_xp: int = int(round(float(skill_xp) * SECONDARY_ATTRIBUTE_SPLIT))

	return {
		"primary": primary_xp,
		"secondary": secondary_xp
	}

## Apply difficulty modifier to attribute XP
## difficulty: 0.0 to 1.0 (how difficult the task was)
## Returns: Modified XP amount
static func apply_difficulty_modifier(attribute_xp: int, difficulty: float) -> int:
	var difficulty_clamped: float = clampf(difficulty, MIN_DIFFICULTY, MAX_DIFFICULTY)

	# Difficulty acts as a multiplier: 0.0 = no bonus, 1.0 = 100% bonus
	var modifier: float = 1.0 + difficulty_clamped

	return int(round(float(attribute_xp) * modifier))

## Apply challenge modifier based on how well-matched the task is to the character's level
## task_difficulty: 0 to 10 (how much of the attribute is required)
## attribute_level: Current level of the attribute
## Returns: Modified XP amount with challenge bonus/penalty
static func apply_challenge_modifier(attribute_xp: int, attribute_level: int, task_difficulty: float) -> int:
	if attribute_level <= 0:
		return attribute_xp

	# Calculate how challenging the task is relative to character's level
	var challenge_ratio: float = task_difficulty / float(attribute_level)

	# Calculate modifier: tasks near sweet spot get bonus, too easy/hard get penalty
	# Sweet spot is around 0.8x attribute level (e.g., level 5 doing difficulty 4 tasks)
	var modifier: float
	if challenge_ratio < CHALLENGE_SWEET_SPOT:
		# Task is too easy - apply penalty
		var penalty_factor: float = challenge_ratio / CHALLENGE_SWEET_SPOT
		modifier = lerpf(CHALLENGE_PENALTY_MAX, 1.0, penalty_factor)
	else:
		# Task is challenging - apply bonus
		var excess: float = challenge_ratio - CHALLENGE_SWEET_SPOT
		var bonus_factor: float = clampf(excess / CHALLENGE_SWEET_SPOT, 0.0, 1.0)
		modifier = lerpf(1.0, CHALLENGE_BONUS_MAX, bonus_factor)

	return int(round(float(attribute_xp) * modifier))

## Apply soft cap penalty based on attribute level
## Soft caps: 1-5 no penalty, 6-10 at 80%, 11+ at 30% with decay
## Returns: Modified XP amount
static func apply_attribute_level_penalty(attribute_xp: int, attribute_level: int) -> int:
	const SOFT_CAP_1: int = 5
	const SOFT_CAP_2: int = 10
	const SOFT_CAP_2_RATE: float = 0.8
	const SOFT_CAP_3_BASE_RATE: float = 0.3
	const SOFT_CAP_3_DECAY: float = 0.9

	var modifier: float

	if attribute_level <= SOFT_CAP_1:
		# Levels 1-5: no penalty
		modifier = 1.0
	elif attribute_level <= SOFT_CAP_2:
		# Levels 6-10: 80% rate
		modifier = SOFT_CAP_2_RATE
	else:
		# Levels 11+: 30% * 0.9^(level-10)
		var levels_above_10: int = attribute_level - SOFT_CAP_2
		var decay: float = pow(SOFT_CAP_3_DECAY, float(levels_above_10))
		modifier = SOFT_CAP_3_BASE_RATE * decay

	return int(round(float(attribute_xp) * modifier))

## Full XP pipeline: Calculate skill XP, split to attributes, apply all modifiers
## Returns: {"skill_xp": int, "primary_xp": int, "secondary_xp": int}
static func calculate_full_xp_pipeline(
	base_xp: int,
	event: String,
	difficulty: float,
	skill_rank: int,
	primary_attribute_level: int,
	secondary_attribute_level: int,
	task_difficulty: float
) -> Dictionary:
	# Step 1: Calculate skill XP
	var skill_xp: int = calculate_skill_xp(base_xp, event, difficulty, skill_rank)

	# Step 2: Split to attributes
	var split: Dictionary = split_to_attributes(skill_xp)
	var primary_xp: int = int(split["primary"])
	var secondary_xp: int = int(split["secondary"])

	# Step 3: Apply difficulty modifier
	primary_xp = apply_difficulty_modifier(primary_xp, difficulty)
	secondary_xp = apply_difficulty_modifier(secondary_xp, difficulty)

	# Step 4: Apply challenge modifier
	primary_xp = apply_challenge_modifier(primary_xp, primary_attribute_level, task_difficulty)
	secondary_xp = apply_challenge_modifier(secondary_xp, secondary_attribute_level, task_difficulty)

	# Step 5: Apply soft cap penalty
	primary_xp = apply_attribute_level_penalty(primary_xp, primary_attribute_level)
	secondary_xp = apply_attribute_level_penalty(secondary_xp, secondary_attribute_level)

	return {
		"skill_xp": skill_xp,
		"primary_xp": primary_xp,
		"secondary_xp": secondary_xp
	}
