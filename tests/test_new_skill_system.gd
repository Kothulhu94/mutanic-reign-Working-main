extends SceneTree

func _init():
	print("Starting New Skill System Test...")
	_test_skill_progression()
	_test_perk_purchasing()
	quit()

func _test_skill_progression():
	print("\n--- Testing Skill Progression ---")
	
	var skill = Skill.new()
	skill.id = &"Trading"
	skill.xp_curve_base = 100
	skill.xp_curve_multiplier = 1.0 # Linear for easy testing
	skill.setup()
	
	# 1. Test basic XP add
	# Level 1 -> 2 needs 100 XP
	skill.add_xp(50.0)
	assert_eq(skill.current_level, 1, "Should still be level 1")
	assert_eq(skill.current_xp, 50.0, "XP should be 50")
	
	skill.add_xp(60.0) # Total 110
	assert_eq(skill.current_level, 2, "Should be level 2")
	assert_eq(skill.current_xp, 10.0, "Should have 10 overflow XP")
	print("PASS: Basic Progression")
	
	# 2. Test Perk Point Award (Every 25 levels)
	# Cheat to level 24
	skill.current_level = 24
	skill.current_xp = 0.0
	skill.perk_points = 0
	
	# Calc XP needed for 24->25 (100 * 1^23 = 100)
	skill.add_xp(100.0)
	
	assert_eq(skill.current_level, 25, "Should be level 25")
	assert_eq(skill.perk_points, 1, "Should have gained 1 Perk Point")
	print("PASS: Perk Point Allocation")

func _test_perk_purchasing():
	print("\n--- Testing Perk Purchasing ---")
	
	var skill = Skill.new()
	skill.id = &"Trading"
	skill.current_level = 30
	skill.perk_points = 2
	
	# Define test perks
	var perk_a = Perk.new()
	perk_a.id = &"basic_logistics"
	perk_a.cost = 1
	perk_a.required_skill_level = 1
	
	var perk_b = Perk.new()
	perk_b.id = &"advanced_logistics"
	perk_b.cost = 1
	perk_b.required_skill_level = 50 # High requirement
	
	var perk_c = Perk.new()
	perk_c.id = &"master_logistics"
	perk_c.cost = 1
	perk_c.required_skill_level = 1
	perk_c.prerequisite_perks = [&"basic_logistics"]
	
	skill.available_perks = [perk_a, perk_b, perk_c]
	skill.setup()
	
	# 1. Buy valid perk
	var success = skill.buy_perk(&"basic_logistics")
	assert_true(success, "Should satisfy all requirements")
	assert_true(skill.has_perk(&"basic_logistics"), "Should own perk")
	assert_eq(skill.perk_points, 1, "Should have spent 1 point")
	
	# 2. Buy unlocked perk
	success = skill.buy_perk(&"basic_logistics")
	assert_false(success, "Cannot buy owned perk")
	
	# 3. Buy perk with too high level requirement
	success = skill.buy_perk(&"advanced_logistics")
	assert_false(success, "Level too low")
	assert_false(skill.has_perk(&"advanced_logistics"), "Should not own perk")
	
	# 4. Buy perk with prerequisites
	# We have basic_logistics now.
	success = skill.buy_perk(&"master_logistics")
	assert_true(success, "Prerequisites met")
	assert_eq(skill.perk_points, 0, "Should have spent 1 point")
	
	print("PASS: Perk Purchasing Logic")

# Simple assert helpers for manual script
func assert_eq(a, b, msg):
	if a != b:
		print("FAIL: %s. Expected %s, got %s" % [msg, str(b), str(a)])
	else:
		pass

func assert_true(a, msg):
	if not a:
		print("FAIL: %s. Expected true" % msg)

func assert_false(a, msg):
	if a:
		print("FAIL: %s. Expected false" % msg)
