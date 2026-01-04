# uid://b1n4rym4th00
class_name TradingMath
extends RefCounted

static func calculate_skill_bonus(sheet: CharacterSheet, item_id: StringName, item_db: ItemDB) -> float:
	if sheet == null:
		return 0.0
		
	var skill = sheet.get_skill(&"trading")
	if skill == null:
		return 0.0
		
	# 0.5% per level
	var bonus: float = float(skill.current_level) * 0.005
	
	if item_id == StringName() or item_db == null:
		return bonus

	# Food Market Expertise (+5% / +15% / +25% / +45% if item is Food)
	var food_rank: int = skill.get_perk_rank(&"food_market_expertise")
	if food_rank > 0 and item_db.has_tag(item_id, "food"):
		if food_rank >= 1: bonus += 0.05
		if food_rank >= 2: bonus += 0.10
		if food_rank >= 3: bonus += 0.10
		if food_rank >= 4: bonus += 0.20
		
	# Materials Expertise
	var mat_rank: int = skill.get_perk_rank(&"materials_expertise")
	if mat_rank > 0 and item_db.has_tag(item_id, "material"):
		if mat_rank >= 1: bonus += 0.05
		if mat_rank >= 2: bonus += 0.10
		if mat_rank >= 3: bonus += 0.10
		if mat_rank >= 4: bonus += 0.20

	# Medicine Expertise
	var med_rank: int = skill.get_perk_rank(&"medicine_expertise")
	if med_rank > 0 and item_db.has_tag(item_id, "medical"):
		if med_rank >= 1: bonus += 0.05
		if med_rank >= 2: bonus += 0.10
		if med_rank >= 3: bonus += 0.10
		if med_rank >= 4: bonus += 0.20

	# Luxury Expertise
	var lux_rank: int = skill.get_perk_rank(&"luxury_expertise")
	if lux_rank > 0 and item_db.has_tag(item_id, "luxury"):
		if lux_rank >= 1: bonus += 0.05
		if lux_rank >= 2: bonus += 0.10
		if lux_rank >= 3: bonus += 0.10
		if lux_rank >= 4: bonus += 0.20

	return bonus

static func get_buy_price(base_price: float, net_modifier: float) -> int:
	# Discount (positive net_modifier reduces price)
	# Buying prices rounded UP
	return int(ceil(maxf(0.1, base_price * (1.0 - net_modifier))))

static func get_sell_price(base_price: float, net_modifier: float) -> int:
	# Premium (positive net_modifier increases yield)
	# Selling prices rounded DOWN
	return int(floor(base_price * (1.0 + net_modifier)))
