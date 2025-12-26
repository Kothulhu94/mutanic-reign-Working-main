extends SceneTree

func _init():
	print("Starting Domain Progression Test...")
	_test_domain_initialization()
	_test_xp_gain_and_level_up()
	_test_perk_unlocking()
	_test_passive_bonuses()
	_test_equipment()
	quit()

func _test_equipment():
	print("\n--- Testing Equipment ---")
	var sheet = CharacterSheet.new()
	
	# Equip item
	var prev = sheet.equip_item(CharacterSheet.EquipmentSlot.HEAD, &"IronHelmet")
	if sheet.get_equipped_item(CharacterSheet.EquipmentSlot.HEAD) == &"IronHelmet":
		print("PASS: Equipped IronHelmet to HEAD")
	else:
		print("FAIL: Failed to equip IronHelmet")
		
	if prev == StringName():
		print("PASS: Previous item was empty")
	else:
		print("FAIL: Previous item was not empty: %s" % prev)
		
	# Replace item
	prev = sheet.equip_item(CharacterSheet.EquipmentSlot.HEAD, &"GoldHelmet")
	if sheet.get_equipped_item(CharacterSheet.EquipmentSlot.HEAD) == &"GoldHelmet":
		print("PASS: Replaced with GoldHelmet")
	else:
		print("FAIL: Failed to replace with GoldHelmet")
		
	if prev == &"IronHelmet":
		print("PASS: Previous item returned correctly (IronHelmet)")
	else:
		print("FAIL: Previous item incorrect: %s" % prev)
		
	# Unequip
	var unequipped = sheet.unequip_item(CharacterSheet.EquipmentSlot.HEAD)
	if unequipped == &"GoldHelmet":
		print("PASS: Unequipped GoldHelmet")
	else:
		print("FAIL: Unequipped item incorrect: %s" % unequipped)
		
	if sheet.get_equipped_item(CharacterSheet.EquipmentSlot.HEAD) == StringName():
		print("PASS: Slot is empty after unequip")
	else:
		print("FAIL: Slot not empty after unequip")
		
	# Test serialization
	sheet.equip_item(CharacterSheet.EquipmentSlot.WEAPON_1, &"Sword")
	var data = sheet.to_dict()
	
	var new_sheet = CharacterSheet.new()
	new_sheet.from_dict(data)
	
	if new_sheet.get_equipped_item(CharacterSheet.EquipmentSlot.WEAPON_1) == &"Sword":
		print("PASS: Equipment serialization successful")
	else:
		print("FAIL: Equipment serialization failed")

func _test_domain_initialization():
	print("\n--- Testing Domain Initialization ---")
	var sheet = CharacterSheet.new()
	
	# Mock a SkillDomain resource
	var domain_res = SkillDomain.new()
	domain_res.domain_id = &"TestDomain"
	domain_res.display_name = "Test Domain"
	domain_res.xp_curve_base = 100
	domain_res.xp_curve_multiplier = 2.0
	domain_res.perk_unlock_levels = [1, 2, 3] # Simplified for test
	
	var state = sheet.initialize_domain(domain_res)
	
	if state.domain_id == &"TestDomain":
		print("PASS: Domain initialized with correct ID")
	else:
		print("FAIL: Domain ID mismatch")
		
	if state.current_level == 1:
		print("PASS: Initial level is 1")
	else:
		print("FAIL: Initial level is %d" % state.current_level)

func _test_xp_gain_and_level_up():
	print("\n--- Testing XP Gain and Level Up ---")
	var sheet = CharacterSheet.new()
	var domain_res = SkillDomain.new()
	domain_res.domain_id = &"TestDomain"
	domain_res.xp_curve_base = 100
	domain_res.xp_curve_multiplier = 2.0
	domain_res.perk_unlock_levels = [2]
	
	var state = sheet.initialize_domain(domain_res)
	
	# Add 50 XP (Level 1, 0/100)
	state.add_xp(50.0)
	if state.current_level == 1 and state.current_xp == 50.0:
		print("PASS: Added 50 XP correctly")
	else:
		print("FAIL: XP addition failed. Level: %d, XP: %f" % [state.current_level, state.current_xp])
		
	# Add 60 XP (Total 110, should level up to 2, remainder 10)
	# Level 1 needs 100 XP.
	state.add_xp(60.0)
	if state.current_level == 2:
		print("PASS: Leveled up to 2")
	else:
		print("FAIL: Level up failed. Level: %d" % state.current_level)
		
	if state.current_xp == 10.0:
		print("PASS: XP carryover correct")
	else:
		print("FAIL: XP carryover incorrect. XP: %f" % state.current_xp)
		
	# Check perk choices
	if state.pending_perk_choices == 1:
		print("PASS: Perk choice granted at level 2")
	else:
		print("FAIL: Perk choice not granted. Choices: %d" % state.pending_perk_choices)

func _test_perk_unlocking():
	print("\n--- Testing Perk Unlocking ---")
	var sheet = CharacterSheet.new()
	var domain_res = SkillDomain.new()
	domain_res.domain_id = &"TestDomain"
	domain_res.perk_unlock_levels = [1] # Grant choice at level 1
	
	var state = sheet.initialize_domain(domain_res)
	# Should have 1 choice because level 1 is in unlock levels
	
	if state.pending_perk_choices == 1:
		print("PASS: Initial perk choice granted")
	else:
		print("FAIL: Initial perk choice missing")
		
	var success = state.unlock_perk(&"TestSkill")
	if success and state.has_perk(&"TestSkill"):
		print("PASS: Perk unlocked successfully")
	else:
		print("FAIL: Perk unlock failed")
		
	if state.pending_perk_choices == 0:
		print("PASS: Perk choice consumed")
	else:
		print("FAIL: Perk choice not consumed")
		
	# Try to unlock again
	success = state.unlock_perk(&"AnotherSkill")
	if not success:
		print("PASS: Cannot unlock without choices")
	else:
		print("FAIL: Unlocked without choices")

func _test_passive_bonuses():
	print("\n--- Testing Passive Bonuses ---")
	var sheet = CharacterSheet.new()
	
	# Setup Melee Domain
	var melee_res = SkillDomain.new()
	melee_res.domain_id = &"Melee"
	var melee_state = sheet.initialize_domain(melee_res)
	melee_state.current_level = 10 # +10% bonus
	
	var modifier = sheet.get_melee_damage_modifier()
	# 1.0 + (10 * 0.01) = 1.1
	if is_equal_approx(modifier, 1.1):
		print("PASS: Melee damage modifier correct (1.1)")
	else:
		print("FAIL: Melee damage modifier incorrect: %f" % modifier)
