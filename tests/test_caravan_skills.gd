# test_caravan_skills.gd
extends Node

func _ready() -> void:
	print("--- Running Caravan Skill Tests ---")
	test_bonus_calculations()
	print("--- All Tests Completed ---")
	get_tree().quit()

func test_bonus_calculations() -> void:
	var sheet = CharacterSheet.new()
	var state = CaravanState.new(StringName("Home"), StringName("Dest"), 1000)
	var type = CaravanType.new()
	type.base_capacity = 1000
	state.caravan_type = type
	state.leader_sheet = sheet
	
	var skill_system = CaravanSkillSystem.new()
	add_child(skill_system)
	skill_system.setup(state)
	
	# Initial check (no skills)
	skill_system.recalculate_bonuses()
	assert(state.bonus_capacity_multiplier == 1.0, "Base multiplier should be 1.0")
	assert(state.get_max_capacity() == 1000, "Base capacity should be 1000")
	
	# Mock trading state with perks
	var trading_domain = Skills.get_domain(&"Trading")
	if not trading_domain:
		print("Warning: Trading domain not found in SkillDatabase. Skipping domain tests.")
		return
		
	var _trading_state = sheet.initialize_domain(trading_domain)
	
	# Tests for old perks (Caravan Logistics, Economic Dominance) disabled during refactor
	# TODO: Implement tests for new perks (Efficient Packing, etc.) when logic is added to CaravanSkillSystem.
	
	print("Bonus calculation tests passed! (Perk tests skipped pending new implementation)")
	
	print("Bonus calculation tests passed!")
