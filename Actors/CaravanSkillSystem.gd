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
		_initialize_trading_skills()
		recalculate_bonuses()

func recalculate_bonuses() -> void:
	if caravan_state == null or caravan_state.leader_sheet == null:
		return
		
	var sheet: CharacterSheet = caravan_state.leader_sheet
	var trading_state: DomainState = sheet.get_domain_state(&"Trading")
	
	# Reset
	price_modifier_bonus = 0.0
	speed_bonus = 0.0
	capacity_bonus = 0.0
	
	if trading_state == null:
		return
		
	# Base Trading Level Bonus: +/- 0.05 per level
	# We store this as a single value, but usage depends on context (buy vs sell)
	# For now, let's store the raw level multiplier
	price_modifier_bonus = float(trading_state.current_level) * 0.05
	
	# Perks (Skills)
	# CaravanLogistics
	if trading_state.has_perk(&"caravan_logistics"):
		# Fixed bonus for the perk (e.g. 25%)
		speed_bonus += 0.25
		capacity_bonus += 0.25
			
	# EstablishedRoutes
	if trading_state.has_perk(&"established_routes"):
		capacity_bonus += 0.25
			
	# EconomicDominance
	if trading_state.has_perk(&"economic_dominance"):
		# Big bonus
		speed_bonus += 0.5
		capacity_bonus += 0.5
		# Extra price bonus (Selling)
		price_modifier_bonus += 0.1
		
	# MarketMonopoly
	if trading_state.has_perk(&"market_monopoly"):
		price_modifier_bonus += 0.1

	# --- Exploration Domain ---
	var exploration_state: DomainState = sheet.get_domain_state(&"Exploration")
	if exploration_state:
		# +1% Movement Speed per level
		speed_bonus += float(exploration_state.current_level) * 0.01
		
	# --- Leadership Domain ---
	var leadership_state: DomainState = sheet.get_domain_state(&"Leadership")
	if leadership_state:
		# +1% Party Size (Capacity) per level
		capacity_bonus += float(leadership_state.current_level) * 0.01

	# Support for simplified speed bonus if we add it to CaravanState later,
	# but for now we sync the capacity multiplier.
	caravan_state.bonus_capacity_multiplier = 1.0 + capacity_bonus

func award_xp(_skill_id: StringName, value: float) -> void:
	if caravan_state == null or caravan_state.leader_sheet == null:
		return
		
	var sheet: CharacterSheet = caravan_state.leader_sheet
	var trading_state: DomainState = sheet.get_domain_state(&"Trading")
	
	if trading_state == null:
		# Try to init
		var domain_res = Skills.get_domain(&"Trading")
		if domain_res:
			trading_state = sheet.initialize_domain(domain_res)
	
	if trading_state == null:
		return
		
	# 1 XP per 100 PACs (Value)
	var xp: float = value / 100.0
	if xp > 0.0:
		trading_state.add_xp(xp)
		recalculate_bonuses()

func _initialize_trading_skills() -> void:
	if caravan_state == null or caravan_state.leader_sheet == null:
		return
		
	# Initialize Trading Domain
	var domain_res = Skills.get_domain(&"Trading")
	if domain_res:
		caravan_state.leader_sheet.initialize_domain(domain_res)
