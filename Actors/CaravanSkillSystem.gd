# CaravanSkillSystem.gd
extends Node
class_name CaravanSkillSystem

## Manages skills, XP awards, and bonuses for a Caravan.
## Handles interaction with the leader's CharacterSheet.

var caravan_state: CaravanState

# Calculated bonuses
var price_modifier_bonus: float = 0.0
var speed_bonus: float = 0.0
var capacity_bonus: float = 0.0

func setup(state: CaravanState) -> void:
	caravan_state = state
	if caravan_state != null and caravan_state.leader_sheet != null:
		# In new system, skills should already be initialized on the sheet
		# or initialized here if not present.
		_ensure_skill_exists(&"Trading")
		recalculate_bonuses()

func recalculate_bonuses() -> void:
	if caravan_state == null or caravan_state.leader_sheet == null:
		return
		
	var sheet: CharacterSheet = caravan_state.leader_sheet
	var trading_skill: Skill = sheet.get_skill(&"Trading")
	
	# Reset
	price_modifier_bonus = 0.0
	speed_bonus = 0.0
	capacity_bonus = 0.0
	
	if trading_skill == null:
		return
		
	# Base Trading Level Bonus: +/- 0.005 per level (0.5%)
	price_modifier_bonus = float(trading_skill.current_level) * 0.005
	
	# Perks
	# CaravanLogistics
	if trading_skill.has_perk(&"caravan_logistics"):
		speed_bonus += 0.25
		capacity_bonus += 0.25
			
	# EstablishedRoutes
	if trading_skill.has_perk(&"established_routes"):
		capacity_bonus += 0.25
			
	# EconomicDominance
	if trading_skill.has_perk(&"economic_dominance"):
		speed_bonus += 0.5
		capacity_bonus += 0.5
		price_modifier_bonus += 0.1
		
	# MarketMonopoly
	if trading_skill.has_perk(&"market_monopoly"):
		price_modifier_bonus += 0.1

	# --- Exploration Skill ---
	var exploration_skill: Skill = sheet.get_skill(&"Exploration")
	if exploration_skill:
		# +1% Movement Speed per level
		speed_bonus += float(exploration_skill.current_level) * 0.01
		
	# --- Leadership Skill ---
	var leadership_skill: Skill = sheet.get_skill(&"Leadership")
	if leadership_skill:
		# +1% Party Size (Capacity) per level
		capacity_bonus += float(leadership_skill.current_level) * 0.01

	# Sync to caravan state
	caravan_state.bonus_capacity_multiplier = 1.0 + capacity_bonus

func award_xp(skill_id: StringName, value: float) -> void:
	if caravan_state == null or caravan_state.leader_sheet == null:
		return
		
	var sheet: CharacterSheet = caravan_state.leader_sheet
	var skill: Skill = sheet.get_skill(skill_id)
	
	if skill == null:
		# Try to init if missing
		if _ensure_skill_exists(skill_id):
			skill = sheet.get_skill(skill_id)
	
	if skill == null:
		return
		
	# 1 XP per 100 PACs (Value)
	var xp: float = value / 100.0
	if xp > 0.0:
		skill.add_xp(xp)
		recalculate_bonuses()

func _ensure_skill_exists(skill_id: StringName) -> bool:
	if caravan_state == null or caravan_state.leader_sheet == null:
		return false
		
	var sheet: CharacterSheet = caravan_state.leader_sheet
	if sheet.get_skill(skill_id) != null:
		return true
		
	# Look up in global DB (via Autoload if available, or direct load)
	var domain_res = Skills.get_domain(skill_id) # The Autoload likely still calls it get_domain, need to check Skills.gd
	# If Skills.gd is not updated, we might have issues. 
	# Assuming Skills.gd is acting as the DB provider.
	
	# For now, if we can't find it easily, we fail gracefully or implement a fallback
	# Ideally Skills.gd should be refactored too.
	if domain_res and domain_res is Skill:
		sheet.add_skill(domain_res)
		return true
		
	return false
