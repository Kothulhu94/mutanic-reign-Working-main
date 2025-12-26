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
		
	var trading_state = sheet.initialize_domain(trading_domain)
	
	# Add Caravan Logistics (25% speed/capacity)
	trading_state.pending_perk_choices = 1
	trading_state.unlock_perk(&"caravan_logistics")
	skill_system.recalculate_bonuses()
	
	assert(skill_system.capacity_bonus == 0.25, "Capacity bonus should be 0.25")
	assert(state.bonus_capacity_multiplier == 1.25, "Multiplier should be 1.25")
	assert(state.get_max_capacity() == 1250, "Capacity should be 1250")
	
	# Add Economic Dominance (Extra 50% speed/capacity)
	trading_state.pending_perk_choices = 1
	trading_state.unlock_perk(&"economic_dominance")
	skill_system.recalculate_bonuses()
	
	# Total bonus: 0.25 (Logistics) + 0.5 (Dominance) = 0.75
	assert(skill_system.capacity_bonus == 0.75, "Total capacity bonus should be 0.75")
	assert(state.bonus_capacity_multiplier == 1.75, "Multiplier should be 1.75")
	assert(state.get_max_capacity() == 1750, "Total capacity should be 1750")
	
	print("Bonus calculation tests passed!")
