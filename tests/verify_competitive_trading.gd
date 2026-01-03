@tool
extends SceneTree

func _init() -> void:
	print("Verifying Competitive Trading Logic...")
	
	# Load Classes
	var market_script = load("res://UI/MarketUI.gd")
	var market = market_script.new()
	
	var bus_scn = load("res://Actors/Bus.tscn")
	var bus = bus_scn.instantiate()
	
	var caravan_scn = load("res://Actors/Caravan.tscn")
	var caravan = caravan_scn.instantiate()
	
	# === Setup Player (Lvl 10 -> 5% Bonus) ===
	if bus.charactersheet == null:
		bus.charactersheet = CharacterSheet.new()
	
	# Manually inject skill since initialize might not work without singletons
	# CharacterSheet usually relies on Skills singleton for definitions.
	# We can manually create a Skill resource.
	var p_skill = Skill.new()
	p_skill.skill_name = "Trading"
	p_skill.id = "Trading"
	p_skill._level = 10
	p_skill._xp = 0
	bus.charactersheet._skills["Trading"] = p_skill
	print("- Player Skill Setup: Lvl 10 (Target Bonus: +5%)")
	
	# === Setup Caravan (Lvl 20 -> 10% Bonus) ===
	var c_sheet = CharacterSheet.new()
	var c_skill = Skill.new()
	c_skill.skill_name = "Trading"
	c_skill.id = "Trading"
	c_skill._level = 20
	c_sheet._skills["Trading"] = c_skill
	
	var c_state = CaravanState.new()
	c_state.leader_sheet = c_sheet
	caravan.caravan_state = c_state
	
	# Manually run setup on skill system to calc bonuses
	# CaravanSkillSystem is a child node usually.
	if caravan.skill_system == null:
		print("❌ Caravan skill_system is null!")
		quit(1)
		
	caravan.skill_system.setup(c_state)
	print("- Caravan Skill Setup: Lvl 20 (Target Bonus: +10%)")
	print("  - Actual Caravan Bonus: ", caravan.skill_system.price_modifier_bonus)
	
	# === Configure Market ===
	market.current_bus = bus
	market.current_merchant = caravan
	
	# Base price is 1.0 (default fallback in Caravan.gd)
	var item_id = "test_item"
	
	# === Test Case 1: Player (5%) vs Caravan (10%) ===
	# Net = 0.05 - 0.10 = -0.05
	# Buy (from hub): Base * (1.0 - (-0.05)) = 1.05
	# Sell (to hub): Base * (1.0 + (-0.05)) = 0.95
	
	var buy_price_1 = market._get_item_price(item_id, caravan, "hub")
	var sell_price_1 = market._get_item_price(item_id, caravan, "player")
	
	print("\nTest Case 1 (Player < Caravan):")
	print("Buy Price (Exp: 1.05): ", buy_price_1)
	print("Sell Price (Exp: 0.95): ", sell_price_1)
	
	var success_1 = is_equal_approx(buy_price_1, 1.05) and is_equal_approx(sell_price_1, 0.95)
	
	# === Test Case 2: Player (30%) vs Caravan (10%) ===
	# Update Player to Lvl 60 -> 30% Bonus
	p_skill._level = 60
	# Net = 0.30 - 0.10 = +0.20
	# Buy: Base * (1.0 - 0.20) = 0.80
	# Sell: Base * (1.0 + 0.20) = 1.20
	
	var buy_price_2 = market._get_item_price(item_id, caravan, "hub")
	var sell_price_2 = market._get_item_price(item_id, caravan, "player")
	
	print("\nTest Case 2 (Player > Caravan):")
	print("Buy Price (Exp: 0.80): ", buy_price_2)
	print("Sell Price (Exp: 1.20): ", sell_price_2)
	
	var success_2 = is_equal_approx(buy_price_2, 0.80) and is_equal_approx(sell_price_2, 1.20)
	
	if success_1 and success_2:
		print("\n✅ VERIFICATION SUCCESS")
		quit(0)
	else:
		print("\n❌ VERIFICATION FAILED")
		quit(1)

func is_equal_approx(a: float, b: float) -> bool:
	return abs(a - b) < 0.001
