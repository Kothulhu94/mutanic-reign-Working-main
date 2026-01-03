@tool
extends SceneTree

func _init() -> void:
	print("Verifying Trading XP Curve...")
	
	var skill_script = load("res://Characters/Skill.gd")
	var skill = skill_script.new()
	skill.id = "Trading"
	skill.current_level = 0
	skill.current_xp = 0.0
	
	# Test 1: Level 0 -> 1 (Exp: 500)
	var needed_0 = skill.get_xp_for_next_level()
	print("Lvl 0 Needed: %.1f (Exp: 500.0)" % needed_0)
	if not is_equal_approx(needed_0, 500.0):
		print("❌ Failed Lvl 0 check")
		quit(1)
		
	# Level Up
	skill.add_xp(500.0)
	print("Added 500 XP. New Level: %d (Exp: 1)" % skill.current_level)
	if skill.current_level != 1:
		print("❌ Failed Level Up to 1")
		quit(1)
		
	# Test 2: Level 1 -> 2 (Exp: 1000)
	var needed_1 = skill.get_xp_for_next_level()
	print("Lvl 1 Needed: %.1f (Exp: 1000.0)" % needed_1)
	if not is_equal_approx(needed_1, 1000.0):
		print("❌ Failed Lvl 1 check")
		quit(1)
		
	# Level Up
	skill.add_xp(1000.0)
	print("Added 1000 XP. New Level: %d (Exp: 2)" % skill.current_level)
	if skill.current_level != 2:
		print("❌ Failed Level Up to 2")
		quit(1)

	# Test 3: Level 2 -> 3 (Exp: 500)
	var needed_2 = skill.get_xp_for_next_level()
	print("Lvl 2 Needed: %.1f (Exp: 500.0)" % needed_2)
	if not is_equal_approx(needed_2, 500.0):
		print("❌ Failed Lvl 2 check")
		quit(1)
		
	print("✅ VERIFICATION SUCCESS")
	quit(0)

func is_equal_approx(a: float, b: float) -> bool:
	return abs(a - b) < 0.001
