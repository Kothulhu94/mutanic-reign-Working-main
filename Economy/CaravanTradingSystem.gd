# CaravanTradingSystem.gd
extends Node
class_name CaravanTradingSystem

## Manages trading logic for a Caravan.
## Handles buying, selling, price evaluation, and destination selection.

var caravan_state: CaravanState
var item_db: ItemDB
var skill_system: CaravanSkillSystem
var all_hubs: Array[Hub] = []
var visited_hubs: Array[Hub] = []
var purchase_prices: Dictionary = {} # item_id -> price paid
var mission_override: CaravanType = null

var surplus_threshold: float = 200.0

func setup(state: CaravanState, db: ItemDB, skills: CaravanSkillSystem, hubs: Array[Hub], threshold: float) -> void:
	caravan_state = state
	item_db = db
	skill_system = skills
	all_hubs = hubs
	surplus_threshold = threshold

func set_mission_override(type: CaravanType) -> void:
	mission_override = type

func reset_trip() -> void:
	visited_hubs.clear()
	purchase_prices.clear()
	mission_override = null
	caravan_state.profit_this_trip = 0
	caravan_state.flip_leg()

func get_effective_max_capacity() -> int:
	if caravan_state == null or caravan_state.caravan_type == null:
		return 1000
	var base: int = caravan_state.caravan_type.base_capacity
	var bonus: float = 0.0
	if skill_system != null:
		bonus = skill_system.capacity_bonus
	if skill_system != null:
		bonus = skill_system.capacity_bonus
	# Apply CaravanType modifier (previously ignored)
	# base_capacity is 1000. modifier is e.g. 0.8 or 1.5.
	var type_mod: float = caravan_state.caravan_type.capacity_modifier
	return int(float(base) * type_mod * (1.0 + bonus))

func home_has_available_preferred_items(home_hub: Hub) -> bool:
	if home_hub == null or caravan_state.pacs <= 0:
		return false
	var items: Dictionary = _get_available_preferred_items(home_hub)
	
	# Filter by affordability to prevent infinite loop (Buy -> Fail -> Idle -> Buy)
	var affordable_count: int = 0
	for item_id in items.keys():
		var price: float = home_hub.get_item_price(item_id)
		# Skill discount
		var discount: float = 0.0
		if skill_system:
			discount = skill_system.get_price_modifier(item_id, item_db)
		var final_price: float = maxf(price * (1.0 - discount), 0.1)
		
		if caravan_state.pacs >= final_price:
			affordable_count += 1
			break
			
	# print("CaravanTrading: checking items at home. Found: ", items.size(), " Affordable: ", affordable_count)
	return affordable_count > 0

func buy_items_at_home(home_hub: Hub) -> int:
	var total_bought: int = 0
	
	# Phase 1: Mission/Preferred Items
	var preferred_items: Dictionary = _get_available_preferred_items(home_hub)
	print("CaravanTrading: Found %d preferred items at %s: %s" % [preferred_items.size(), home_hub.name, preferred_items.keys()])
	
	for item_id: StringName in preferred_items.keys():
		var amount: int = _try_buy_item(home_hub, item_id, preferred_items[item_id])
		total_bought += amount

	return total_bought

func _try_buy_item(hub: Hub, item_id: StringName, available_stock: int) -> int:
	var base_price: float = hub.get_item_price(item_id)
	
	# Apply buy price reduction (bonus)
	var price_modifier: float = 0.0
	if skill_system:
		price_modifier = skill_system.get_price_modifier(item_id, item_db)
		
	var price: float = base_price * (1.0 - price_modifier)
	price = maxf(price, 0.1)
	
	var max_affordable: int = int(floor(float(caravan_state.pacs) / price))
	# Debug Price/Affordability
	print("  > Buying %s. Price: %.2f. Cash: %d. MaxAffordable: %d. Stock: %d" % [item_id, price, caravan_state.pacs, max_affordable, available_stock])
	
	var amount: int = mini(available_stock, max_affordable)
	
	# Volume Check (User: Support multiple stacks)
	if caravan_state.leader_sheet:
		var sheet = caravan_state.leader_sheet
		var stack_limit: int = sheet.get_max_stack_size()
		var slots_total: int = sheet.get_max_slots()
		var slots_used: int = sheet.get_occupied_slots()
		var slots_free: int = slots_total - slots_used
		
		var current_stock: int = sheet.inventory.get(item_id, 0)
		var remainder: int = current_stock % stack_limit
		var space_in_current: int = 0
		if remainder > 0:
			space_in_current = stack_limit - remainder
			
		var max_fit: int = (slots_free * stack_limit) + space_in_current
		
		if amount > max_fit:
			amount = max_fit
	
	# Capacity check
	var current_weight: int = caravan_state.get_total_cargo_weight()
	var max_cap: int = get_effective_max_capacity()
	var space_avail: int = max_cap - current_weight
	
	if space_avail < amount:
		print("  > Capacity constrained. Space: %d vs Desired: %d" % [space_avail, amount])
		amount = space_avail
	
	if amount <= 0:
		print("  > Purchase skipped. Amount 0. (Affordable: %d, Space: %d)" % [max_affordable, space_avail])
		return 0
	
	if amount > 0:
		var cost: int = int(ceil(price * float(amount)))
		if hub.buy_from_hub(item_id, amount, caravan_state):
			caravan_state.pacs -= cost
			
			# Critical Fix: Verify item was added before committing transaction
			if caravan_state.add_item(item_id, amount):
				purchase_prices[item_id] = price
				print("CaravanTrading: Bought %d of %s for %d" % [amount, item_id, cost])
				if skill_system:
					skill_system.award_xp(&"trading", float(cost))
				return amount
			else:
				# REFUND LOGIC
				print("CaravanTrading: CRITICAL - Failed to stow %d %s! Refunding %d pacs." % [amount, item_id, cost])
				caravan_state.pacs += cost
				# Also return item to hub? (Ideally yes, but simple refund saves the run)
				# For robustness we effectively 'cancel' the buy.
				# hub.sell_to_hub(item_id, amount) equivalent
				# But since we already 'bought' it from hub, it's gone from hub.
				# We should technically put it back.
				_refund_to_hub(hub, item_id, amount)
				return 0
		else:
			push_warning("CaravanTrading: Hub refused sale of %s" % item_id)
			
	return 0

func _refund_to_hub(hub: Hub, item_id: StringName, amount: int) -> void:
	# Put items back in hub inventory without triggering 'Production' telemetry if possible
	# But sell_to_hub is the standard API.
	# We can just manually modify state to be silent?
	# Hub.sell_to_hub handles logic.
	# Let's just use sell_to_hub but ignore money logic (since we already refunded pacs manually)
	# Wait, sell_to_hub gives MONEY to Caravan.
	# We refunded Caravan pacs manually.
	# So we just need to add items to Hub.
	if hub and hub.state:
		hub.state.inventory[item_id] = hub.state.inventory.get(item_id, 0) + amount
		# And reverse the consumption telemetry? A bit complex.
		# For valid "Transaction Cancelled", we accept minor telemetry drift.

func evaluate_trade_at_hub(hub: Hub) -> bool:
	if hub != null and not visited_hubs.has(hub):
		visited_hubs.append(hub)
		
	var has_profit: bool = false
	for item_id: StringName in caravan_state.inventory.keys():
		var buy_price: float = purchase_prices.get(item_id, 0.0)
		var base_sell: float = hub.get_item_price(item_id)
		
		# Calculate dynamic bonus
		var bonus: float = 0.0
		if skill_system:
			bonus = skill_system.get_price_modifier(item_id, item_db)
			
		# Sell price increase
		var sell_price: float = base_sell * (1.0 + bonus)
		
		# Revised Logic: Check for > 10% profit margin
		if sell_price > (buy_price * 1.1):
			has_profit = true
			break
			
	return has_profit

func sell_items_at_hub(hub: Hub, home_hub: Hub, force_sell: bool = false) -> void:
	var items: Array[StringName] = []
	for k in caravan_state.inventory.keys():
		items.append(k)
		
	for item_id in items:
		var amount: int = caravan_state.inventory.get(item_id, 0)
		if amount <= 0: continue
		
		var buy_price: float = purchase_prices.get(item_id, 0.0)
		var base_sell: float = hub.get_item_price(item_id)
		
		# Calculate dynamic bonus
		var bonus: float = 0.0
		if skill_system:
			bonus = skill_system.get_price_modifier(item_id, item_db)
			
		# Sell price increase
		var sell_price: float = base_sell * (1.0 + bonus)
		
		if force_sell or sell_price > buy_price:
			var revenue: int = int(floor(sell_price * float(amount)))
			if hub.sell_to_hub(item_id, amount, caravan_state):
				var profit: int = revenue - int(buy_price * float(amount))
				caravan_state.pacs += revenue
				caravan_state.profit_this_trip += profit
				caravan_state.remove_item(item_id, amount)
				
				if skill_system:
					skill_system.award_xp(&"trading", float(revenue))
					if profit > 0:
						skill_system.award_xp(&"trading", float(profit))
						skill_system.award_xp(&"trading", float(profit) * 0.5) # Bonus for profit
					if amount > 50:
						skill_system.award_xp(&"trading", float(revenue) * 0.2) # Bonus for bulk

	# Post-Sale: Check for Return Cargo (Opportunistic)
	if home_hub != null and hub != home_hub:
		buy_return_cargo(hub, home_hub)

	if hub != null and not visited_hubs.has(hub):
		visited_hubs.append(hub)

func buy_return_cargo(current_hub: Hub, home_hub: Hub) -> int:
	var total: int = 0
	# Only if we have space and money
	if caravan_state.pacs <= 10 or caravan_state.get_total_cargo_weight() >= get_effective_max_capacity():
		return 0
		
	var inventory: Dictionary = current_hub.state.inventory
	for item_id: StringName in inventory.keys():
		var stock: int = inventory.get(item_id, 0)
		if stock <= 0: continue
		
		# Price Check: Buy Here < (Home Sell / 1.1)
		# i.e. Estimated Home Sell > Buy Here * 1.1
		
		var local_buy_price: float = current_hub.get_item_price(item_id)
		# Apply buy discount
		var discount: float = 0.0
		if skill_system:
			discount = skill_system.get_price_modifier(item_id, item_db)
		var my_buy_price: float = maxf(local_buy_price * (1.0 - discount), 0.1)
		
		var home_sell_base: float = home_hub.get_item_price(item_id)
		# Apply sell bonus
		# (Use same modifier? usually skill gives bonus to sell and discount to buy. 
		# get_price_modifier seems to be generic positive number. 
		# In buy_items logic it did (1.0 - mod). In sell logic it did (1.0 + mod).
		# So assuming mod is "Trading Capability".
		var home_sell_price: float = home_sell_base * (1.0 + discount)
		
		if home_sell_price > (my_buy_price * 1.1):
			var amount: int = _try_buy_item(current_hub, item_id, stock)
			total += amount
			
			if caravan_state.pacs <= 10 or caravan_state.get_total_cargo_weight() >= get_effective_max_capacity():
				break
				
	return total

func find_next_destination(home_hub: Hub) -> Hub:
	# Filter available destinations
	var available: Array[Hub] = []
	for h in all_hubs:
		if h == null: continue
		if h == home_hub: continue
		if visited_hubs.has(h): continue
		available.append(h)
	
	if available.is_empty():
		return null
		
	# Sort by distance from current location (or home if first leg)
	# "Greedy TSP": always go to the nearest unvisited node.
	
	var current_pos: Vector2 = Vector2.ZERO
	if visited_hubs.is_empty():
		current_pos = home_hub.global_position
	else:
		current_pos = visited_hubs.back().global_position
		
	available.sort_custom(func(a: Hub, b: Hub):
		var dist_a = current_pos.distance_squared_to(a.global_position)
		var dist_b = current_pos.distance_squared_to(b.global_position)
		return dist_a < dist_b
	)
	
	print("CaravanTrading: at %s. Found %d candidates. Nearest: %s" % [current_pos, available.size(), available[0].state.display_name])
	
	# Return the closest one
	return available[0]

func get_visited_count_excluding(home_hub: Hub) -> int:
	var count: int = 0
	for h in visited_hubs:
		if h != home_hub:
			count += 1
	return count

func get_total_hubs_excluding(home_hub: Hub) -> int:
	var count: int = 0
	for h in all_hubs:
		if h != home_hub:
			count += 1
	return count

func _get_available_preferred_items(hub: Hub) -> Dictionary:
	var result: Dictionary = {}
	if hub == null or item_db == null or caravan_state == null or caravan_state.caravan_type == null:
		return result
		
	var type_to_use: CaravanType = caravan_state.caravan_type
	if mission_override != null:
		type_to_use = mission_override
		
	var tags: Array[StringName] = type_to_use.preferred_tags
	if tags.is_empty():
		return result
		
	for item_id: StringName in hub.state.inventory.keys():
		var stock: int = hub.state.inventory.get(item_id, 0)
		if stock <= 10: continue # User: Trade based on capacity loop (safety margin only)
		
		var match_tag: bool = false
		for t in tags:
			if item_db.has_tag(item_id, t):
				match_tag = true
				break
		
		if match_tag:
			result[item_id] = stock
			
	return result

func deposit_all_at_home(home_hub: Hub) -> void:
	if home_hub == null or caravan_state == null:
		return
		
	# Copy keys to avoid concurrent mod issues (though GDS arrays are usually safe-ish for keys)
	var keys: Array[StringName] = []
	for k in caravan_state.inventory.keys():
		keys.append(k)
		
	for item_id in keys:
		var amount: int = caravan_state.inventory[item_id]
		if amount > 0:
			# Directly add to hub inventory (bypassing economy tracking to avoid polluting "produced" stats with returns)
			# Or check if Hub has a specific method for "returns". 
			# For now, direct state manipulation to ensure it gets back in.
			if home_hub.state and home_hub.state.inventory != null:
				home_hub.state.inventory[item_id] = home_hub.state.inventory.get(item_id, 0) + amount
			
			if home_hub.has_method("set_export_cooldown"):
				# 5 minutes (300s) cooldown on retrying this export
				home_hub.set_export_cooldown(item_id, 300.0)
				
			caravan_state.remove_item(item_id, amount)
			# print("CaravanTrading: Returned %d %s to home grid due to lack of buyers." % [amount, item_id])
