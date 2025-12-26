# uid://0wf6j3u0re3i
extends RefCounted


## Main character progression orchestrator
## Owns attributes and skills, coordinates XP distribution
## Provides save/load functionality for persistence

# Core components
var _attributes: CharacterAttributes = CharacterAttributes.new()
var _skills: Dictionary = {} # skill_id: StringName -> SkillSpec

# Domain lookup (set externally or loaded from database)
var _domains: Dictionary = {} # domain_id: StringName -> DomainSpec

# Domain state tracking (New System)
var _domain_states: Dictionary = {} # domain_id: StringName -> DomainState


## Initialize with empty attributes and skills
func _init() -> void:
	_attributes.attribute_leveled.connect(_on_attribute_leveled)

## Grant skill XP (redirects to Domain XP)
## event: "use", "success", "failure", "challenge"
## difficulty: 0.0 to 1.0
func grant_skill_xp(skill_id: StringName, event: String, difficulty: float, base_xp: int = 100) -> void:
	# Find the skill definition to get the domain
	var skill_spec: SkillSpec = _skills.get(skill_id)
	var domain_id: StringName = StringName()
	
	if skill_spec:
		domain_id = skill_spec.domain_id
	else:
		# Try to look up in global database if we don't have the skill learned yet
		# This assumes we have access to a global lookup, but for now let's rely on _skills
		# or we can check _domains if we had a reverse lookup.
		# If the skill is not learned, we might still want to give domain XP?
		# For now, require skill to be known or at least identified.
		pass

	if domain_id == StringName():
		# Fallback: try to find domain from registered domains
		for d_id in _domains:
			var domain = _domains[d_id]
			# This is slow, but robust
			for s in domain.skills:
				if s.skill_id == skill_id:
					domain_id = d_id
					break
			if domain_id != StringName():
				break
	
	if domain_id == StringName():
		push_warning("CharacterProgression: Could not find domain for skill '%s'" % skill_id)
		return

	# Grant XP to the domain
	grant_domain_xp(domain_id, float(base_xp)) # Simplified XP calculation for now

	# We do NOT add XP to the skill anymore, as per user request.
	# But we still distribute attribute XP.
	
	# Step 3: Split XP to attributes (50/50 for now)
	# Use the base_xp or a calculated amount?
	# Let's use the calculated amount from the old system to keep attribute progression similar
	# or just use base_xp.
	var calculated_xp: int = XPCalculator.calculate_skill_xp(base_xp, event, difficulty, 1) # Rank 1 as baseline
	
	var split: Dictionary = XPCalculator.split_to_attributes(calculated_xp)
	var primary_xp: int = int(split["primary"])
	var secondary_xp: int = int(split["secondary"])

	# Step 4: Apply difficulty modifier
	primary_xp = XPCalculator.apply_difficulty_modifier(primary_xp, difficulty)
	secondary_xp = XPCalculator.apply_difficulty_modifier(secondary_xp, difficulty)

	# Step 5: Distribute to attributes
	_distribute_attribute_xp(primary_xp, secondary_xp)

## Grant XP to a specific domain
func grant_domain_xp(domain_id: StringName, amount: float) -> void:
	var state: DomainState = _get_or_create_domain_state(domain_id)
	if state:
		state.add_xp(amount)

func _get_or_create_domain_state(domain_id: StringName) -> DomainState:
	if _domain_states.has(domain_id):
		return _domain_states[domain_id]
	
	# Create new state
	# We need the domain resource to configure it
	var domain_res = _domains.get(domain_id)
	if not domain_res:
		# Try to load from global database if possible, or just create blank
		# Assuming _domains is populated.
		return null
		
	var state = DomainState.new()
	state.configure(domain_res)
	_domain_states[domain_id] = state
	# Connect signals
	state.domain_leveled_up.connect(_on_domain_leveled_up)
	state.perk_unlocked.connect(_on_perk_unlocked)
	
	return state

## Distribute attribute XP (placeholder - will use domain lookup in phase 2)
func _distribute_attribute_xp(primary_xp: int, secondary_xp: int) -> void:
	# Placeholder: distribute to Might and Guile
	# Phase 2: lookup skill's domain, use primary/secondary attributes
	_attributes.add_attribute_xp(&"Might", float(primary_xp))
	_attributes.add_attribute_xp(&"Guile", float(secondary_xp))

## Add a skill to this character
func add_skill(skill: SkillSpec) -> void:
	if skill == null or not skill.is_valid():
		push_error("CharacterProgression: Cannot add invalid skill")
		return

	_skills[skill.skill_id] = skill
	skill.skill_ranked_up.connect(_on_skill_ranked_up)

## Register a domain (for attribute lookup in phase 2)
func register_domain(domain: DomainSpec) -> void:
	if domain == null or not domain.is_valid():
		push_error("CharacterProgression: Cannot register invalid domain")
		return

	_domains[domain.domain_id] = domain

## Get attribute level
func get_attribute(name: StringName) -> int:
	return _attributes.get_attribute_level(name)

## Get skill by ID
func get_skill(skill_id: StringName) -> SkillSpec:
	return _skills.get(skill_id, null)

## Get all skills in a specific domain
func get_skills_by_domain(domain_id: StringName) -> Array[SkillSpec]:
	var result: Array[SkillSpec] = []
	for skill: SkillSpec in _skills.values():
		if skill.domain_id == domain_id:
			result.append(skill)
	return result

## Get all skills
func get_all_skills() -> Array[SkillSpec]:
	var result: Array[SkillSpec] = []
	for skill: SkillSpec in _skills.values():
		result.append(skill)
	return result

## Get attribute progress percentage
func get_attribute_progress(name: StringName) -> float:
	return _attributes.get_progress_percent(name)

## Serialize to dictionary (for save game)
func to_dict() -> Dictionary:
	var skills_data: Dictionary = {}
	for skill_id: StringName in _skills.keys():
		var skill: SkillSpec = _skills[skill_id]
		skills_data[skill_id] = skill.to_dict()

	return {
		"attributes": _attributes.to_dict(),
		"skills": skills_data,
		"domain_states": _serialize_domain_states()
	}

func _serialize_domain_states() -> Dictionary:
	var data: Dictionary = {}
	for id in _domain_states:
		if _domain_states[id]:
			data[id] = _domain_states[id].to_dict()
	return data

## Load from dictionary (for load game)
func from_dict(data: Dictionary) -> void:
	if data.is_empty():
		return

	# Load attributes
	if data.has("attributes"):
		_attributes.from_dict(data["attributes"])

	# Load skills
	if data.has("skills"):
		var skills_data: Dictionary = data["skills"]
		for skill_id: StringName in skills_data.keys():
			var skill_data: Dictionary = skills_data[skill_id]

			# Create or get existing skill
			var skill: SkillSpec
			if _skills.has(skill_id):
				skill = _skills[skill_id]
			else:
				skill = SkillSpec.new()
				_skills[skill_id] = skill
				skill.skill_ranked_up.connect(_on_skill_ranked_up)

			skill.from_dict(skill_data)

	# Load domain states
	if data.has("domain_states"):
		var domains_data: Dictionary = data["domain_states"]
		for id in domains_data:
			# We need to ensure the domain resource is available to configure properly
			# But for loading, we might just load the raw data first
			# Ideally we call _get_or_create_domain_state to link it to the resource
			var state = DomainState.new()
			state.from_dict(domains_data[id])
			_domain_states[id] = state
			# Re-connect signals
			state.domain_leveled_up.connect(_on_domain_leveled_up)
			state.perk_unlocked.connect(_on_perk_unlocked)


## Signal handlers
func _on_attribute_leveled(_attribute_name: StringName, _new_level: int) -> void:
	pass # Can be used for notifications later

func _on_skill_ranked_up(_skill_id: StringName, _new_rank: int) -> void:
	pass # Can be used for notifications later

func _on_domain_leveled_up(domain_id: StringName, new_level: int) -> void:
	print("Domain %s leveled up to %d!" % [domain_id, new_level])
	# Here we could trigger a UI notification or check for perk unlocks

func _on_perk_unlocked(domain_id: StringName, skill_id: StringName) -> void:
	print("Perk %s unlocked in domain %s!" % [skill_id, domain_id])
	
	# Ensure the skill is marked as learned in the skills dictionary
	var skill_spec: SkillSpec = _skills.get(skill_id)
	if skill_spec == null:
		skill_spec = SkillSpec.new()
		skill_spec.skill_id = skill_id
		skill_spec.domain_id = domain_id
		skill_spec.current_rank = 1 # Unlocked
		add_skill(skill_spec)
	else:
		if skill_spec.current_rank < 1:
			skill_spec.current_rank = 1
			skill_spec.skill_ranked_up.emit(skill_id, 1)


## Test method (commented, not executed by default)
## Demonstrates the XP system with all modifiers
#func _test_progression() -> void:
#	print("\n=== Character Progression Test ===\n")
#
#	# Create test attributes
#	print("Initial Attributes:")
#	print("  Might: Level %d" % get_attribute(&"Might"))
#	print("  Guile: Level %d" % get_attribute(&"Guile"))
#	print("  Intellect: Level %d" % get_attribute(&"Intellect"))
#	print("  Willpower: Level %d" % get_attribute(&"Willpower"))
#
#	# Create test skill
#	var test_skill: SkillSpec = SkillSpec.new()
#	test_skill.skill_id = &"Swordplay"
#	test_skill.display_name = "Swordplay"
#	test_skill.domain_id = &"Melee"
#	add_skill(test_skill)
#
#	print("\nCreated skill: %s (Rank %d)" % [test_skill.display_name, test_skill.current_rank])
#
#	# Example 1: Basic use
#	print("\n--- Example 1: Basic Use (event='use', difficulty=0.5) ---")
#	grant_skill_xp(&"Swordplay", "use", 0.5, 100)
#	print("  Skill Rank: %d (XP: %.1f/%.1f)" % [test_skill.current_rank, test_skill.current_xp, test_skill.xp_to_next_rank])
#	print("  Might Level: %d (%.1f%%)" % [get_attribute(&"Might"), get_attribute_progress(&"Might") * 100])
#	print("  Guile Level: %d (%.1f%%)" % [get_attribute(&"Guile"), get_attribute_progress(&"Guile") * 100])
#
#	# Example 2: Successful action
#	print("\n--- Example 2: Success (event='success', difficulty=0.8) ---")
#	grant_skill_xp(&"Swordplay", "success", 0.8, 100)
#	print("  Skill Rank: %d (XP: %.1f/%.1f)" % [test_skill.current_rank, test_skill.current_xp, test_skill.xp_to_next_rank])
#	print("  Might Level: %d (%.1f%%)" % [get_attribute(&"Might"), get_attribute_progress(&"Might") * 100])
#	print("  Guile Level: %d (%.1f%%)" % [get_attribute(&"Guile"), get_attribute_progress(&"Guile") * 100])
#
#	# Example 3: Challenge (high multiplier)
#	print("\n--- Example 3: Challenge (event='challenge', difficulty=1.0) ---")
#	grant_skill_xp(&"Swordplay", "challenge", 1.0, 100)
#	print("  Skill Rank: %d (XP: %.1f/%.1f)" % [test_skill.current_rank, test_skill.current_xp, test_skill.xp_to_next_rank])
#	print("  Might Level: %d (%.1f%%)" % [get_attribute(&"Might"), get_attribute_progress(&"Might") * 100])
#	print("  Guile Level: %d (%.1f%%)" % [get_attribute(&"Guile"), get_attribute_progress(&"Guile") * 100])
#
#	# Example 4: Difficulty modifier demonstration
#	print("\n--- Example 4: Difficulty Modifier Comparison ---")
#	var easy_xp: int = XPCalculator.apply_difficulty_modifier(100, 0.1)
#	var medium_xp: int = XPCalculator.apply_difficulty_modifier(100, 0.5)
#	var hard_xp: int = XPCalculator.apply_difficulty_modifier(100, 1.0)
#	print("  Easy task (0.1): %d XP" % easy_xp)
#	print("  Medium task (0.5): %d XP" % medium_xp)
#	print("  Hard task (1.0): %d XP" % hard_xp)
#
#	# Example 5: Challenge modifier demonstration
#	print("\n--- Example 5: Challenge Modifier (task vs. attribute level) ---")
#	var trivial: int = XPCalculator.apply_challenge_modifier(100, 5, 2.0)
#	var sweet_spot: int = XPCalculator.apply_challenge_modifier(100, 5, 4.0)
#	var very_hard: int = XPCalculator.apply_challenge_modifier(100, 5, 8.0)
#	print("  Trivial (level 5 doing diff 2): %d XP" % trivial)
#	print("  Sweet spot (level 5 doing diff 4): %d XP" % sweet_spot)
#	print("  Very hard (level 5 doing diff 8): %d XP" % very_hard)
#
#	# Example 6: Soft cap demonstration
#	print("\n--- Example 6: Soft Cap Penalties ---")
#	var level_3: int = XPCalculator.apply_attribute_level_penalty(100, 3)
#	var level_7: int = XPCalculator.apply_attribute_level_penalty(100, 7)
#	var level_12: int = XPCalculator.apply_attribute_level_penalty(100, 12)
#	print("  Level 3 (no cap): %d XP" % level_3)
#	print("  Level 7 (80%% cap): %d XP" % level_7)
#	print("  Level 12 (30%% + decay): %d XP" % level_12)
#
#	# Example 7: Save/Load test
#	print("\n--- Example 7: Save/Load Test ---")
#	var save_data: Dictionary = to_dict()
#	print("  Saved data keys: %s" % save_data.keys())
#	print("  Attributes in save: %s" % save_data["attributes"].keys())
#	print("  Skills in save: %s" % save_data["skills"].keys())
#
#	# Create new character and load
#	var loaded_char: CharacterProgression = CharacterProgression.new()
#	loaded_char.from_dict(save_data)
#	print("  Loaded Might Level: %d" % loaded_char.get_attribute(&"Might"))
#	print("  Loaded Skill Rank: %d" % loaded_char.get_skill(&"Swordplay").current_rank)
#
#	print("\n=== Test Complete ===\n")
